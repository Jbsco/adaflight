with Interfaces;

package body Adaflight.FAT_FS with SPARK_Mode is
   use type Unsigned_8;
   use type Unsigned_16;
   use type Unsigned_32;
   use type Integer_32;
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_64;

   ------------------
   -- Flush_Sector --
   ------------------

   procedure Flush_Sector (FS : in out File_System; Card : in out Card_State; Index : Cache_Index) is
      Answer : Card_Status;
   begin
      if FS.Descriptors (Index).Erase_Count /= 0 then
         Begin_Write_Blocks (Card, FS.Descriptors (Index).Sector_Index, FS.Descriptors (Index).Erase_Count);
      end if;
      Write_Block (Card, FS.Descriptors (Index).Sector_Index, Index, FS.Cache (Index), Answer);
      case Answer is
         when In_Progress =>
            Remove_Dirty (FS);
            FS.Descriptors (Index).State := Writing;
            FS.Flush_In_Progress := True;
         when Success =>
            Remove_Dirty (FS);
            FS.Descriptors (Index).State := In_Sync;
         when Busy | Failure =>
            null;
      end case;
   end Flush_Sector;

   -----------
   -- Flush --
   -----------

   procedure Flush (FS : in out File_System; Card : in out Card_State; Done : out Boolean) is
      Earliest_Time  : Unsigned_32 := Unsigned_32'Last;
      Earliest_Index : Cache_Slot := No_Slot;
   begin
      if FS.Dirty_Entries > 0 then
         for I in Cache_Index loop
            if FS.Descriptors (I).State = Dirty and then not FS.Descriptors (I).Locked
              and then (Earliest_Index = No_Slot or else FS.Descriptors (I).Write_Timestamp < Earliest_Time)
            then
               Earliest_Index := I;
               Earliest_Time := FS.Descriptors (I).Write_Timestamp;
            end if;
         end loop;
         if Earliest_Index /= No_Slot then
            Flush_Sector (FS, Card, Earliest_Index);
            Done := False;
            return;
         end if;
      end if;
      Done := True;
   end Flush;

   ------------------
   -- Cache_Sector --
   ------------------

   procedure Cache_Sector
     (FS          : in out File_System;
      Card        : in out Card_State;
      Sector      : Unsigned_32;
      Flags       : Cache_Flags;
      Erase_Count : Unsigned_32;
      Status      : out Operation_Status;
      Buffer      : out Cache_Slot)
   is
      Slot : Cache_Slot;
   begin
      Buffer := No_Slot;
      --  The partition table is never written.
      Check (FS, not Flags.Write or else Sector /= 0);
      if Flags.Write and then Sector = 0 then
         Status := Failure;
         return;
      end if;
      Allocate_Cache_Sector (FS, Sector, Slot);
      if Slot = No_Slot then
         Status := In_Progress;
         return;
      end if;
      case FS.Descriptors (Slot).State is
         when Reading =>
            Status := In_Progress;
            return;
         when Empty =>
            if Flags.Read then
               declare
                  Accepted : Boolean;
               begin
                  Read_Block (Card, Sector, Slot, Accepted);
                  if Accepted then
                     FS.Descriptors (Slot).State := Reading;
                  end if;
               end;
               Status := In_Progress;
               return;
            end if;
            --  The first caller of a sector sets its discard hint and the
            --  run of writes the card may erase ahead of, four or more.
            FS.Descriptors (Slot).Discardable := Flags.Discardable;
            FS.Descriptors (Slot).Erase_Count :=
              (if Erase_Count < Min_Multiple_Block_Write then 0
               else Unsigned_16 (Unsigned_32'Min (Erase_Count, Unsigned_32 (Unsigned_16'Last))));
            if Flags.Write then
               Mark_Dirty (FS, Slot);
            end if;
         when Writing | In_Sync =>
            if Flags.Write then
               Mark_Dirty (FS, Slot);
            end if;
         when Dirty =>
            null;
      end case;
      if Flags.Lock then
         FS.Descriptors (Slot).Locked := True;
      end if;
      if Flags.Retain then
         FS.Descriptors (Slot).Retained := FS.Descriptors (Slot).Retained + 1;
      end if;
      Buffer := Slot;
      Status := Success;
   end Cache_Sector;

   --------------------------
   -- FAT_Get_Next_Cluster --
   --------------------------

   procedure FAT_Get_Next_Cluster
     (FS      : in out File_System;
      Card    : in out Card_State;
      FAT     : FAT_Number;
      Cluster : Unsigned_32;
      Status  : out Operation_Status;
      Next    : in out Unsigned_32)
   is
      FAT_Sector  : Unsigned_32;
      Entry_Index : Unsigned_32;
      Buffer      : Cache_Slot;
   begin
      FAT_Position (FS.Vol, Cluster, FAT_Sector, Entry_Index);
      Cache_Sector (FS, Card, FAT_Sector_To_Physical (FS.Vol, FAT, FAT_Sector), (Read => True, others => False), 0,
                    Status, Buffer);
      if Status = Success then
         if FS.Vol.FS_Type = FAT16 then
            Next := Unsigned_32 (Read_U16 (FS.Cache (Buffer), Natural (Entry_Index) * 2));
         else
            Next := Decode_Cluster (Read_U32 (FS.Cache (Buffer), Natural (Entry_Index) * 4));
         end if;
      end if;
   end FAT_Get_Next_Cluster;

   --------------------------
   -- FAT_Set_Next_Cluster --
   --------------------------

   procedure FAT_Set_Next_Cluster
     (FS     : in out File_System;
      Card   : in out Card_State;
      Start  : Unsigned_32;
      Next   : Unsigned_32;
      Status : out Operation_Status)
   is
      FAT_Sector  : Unsigned_32;
      Entry_Index : Unsigned_32;
      Buffer      : Cache_Slot;
   begin
      FAT_Position (FS.Vol, Start, FAT_Sector, Entry_Index);
      Cache_Sector (FS, Card, FAT_Sector_To_Physical (FS.Vol, 0, FAT_Sector),
                    (Read => True, Write => True, others => False), 0, Status, Buffer);
      if Status = Success then
         if FS.Vol.FS_Type = FAT16 then
            Write_U16 (FS.Cache (Buffer), Natural (Entry_Index) * 2, Unsigned_16 (Next and 16#FFFF#));
         else
            Write_U32 (FS.Cache (Buffer), Natural (Entry_Index) * 4, Next);
         end if;
      end if;
   end FAT_Set_Next_Cluster;

   ------------------
   -- Find_Cluster --
   ------------------

   procedure Find_Cluster
     (FS        : in out File_System;
      Card      : in out Card_State;
      Condition : Search_Condition;
      Cluster   : in out Unsigned_32;
      Limit     : Unsigned_32;
      Status    : out Find_Status)
   is
      Per_Sector   : constant Unsigned_32 := FAT_Entries_Per_Sector (FS.Vol);
      Looking_Free : constant Boolean := Condition /= Taken_Cluster;
      Jump         : Unsigned_32;
      FAT_Sector   : Unsigned_32;
      Entry_Index  : Unsigned_32;
      Result       : Operation_Status;
      Buffer       : Cache_Slot;
      Value        : Unsigned_32;
   begin
      FAT_Position (FS.Vol, Cluster, FAT_Sector, Entry_Index);
      case Condition is
         when Free_At_Sector_Start =>
            Jump := Per_Sector;
            --  The search starts at the first entry of a FAT sector.
            Check (FS, Entry_Index = 0);
            if Entry_Index /= 0 then
               Status := Find_Fatal;
               return;
            end if;
         when Free_Cluster | Taken_Cluster =>
            Jump := 1;
      end case;
      while Cluster < Limit loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         pragma Loop_Invariant (Entry_Index < Per_Sector);
         pragma Loop_Invariant (Jump in 1 .. Per_Sector);
         --  The free-space file holds no free cluster. The FAT sector stays
         --  where it was.
         if FS.Files (Free_File).Logical_Size > 0 and then Cluster = FS.Files (Free_File).First_Cluster then
            Cluster := Cluster
              + Divide (FS.Files (Free_File).Logical_Size + Cluster_Size (FS.Vol) - 1, Cluster_Size (FS.Vol));
            Cluster := Round_Up_To (Cluster, Jump);
         else
            Cache_Sector (FS, Card, FAT_Sector_To_Physical (FS.Vol, 0, FAT_Sector),
                          (Read => True, Discardable => True, others => False), 0, Result, Buffer);
            case Result is
               when Success =>
                  loop
                     pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
                     pragma Loop_Invariant (Entry_Index < Per_Sector);
                     case FS.Vol.FS_Type is
                        when FAT16 =>
                           Value := Unsigned_32 (Read_U16 (FS.Cache (Buffer), Natural (Entry_Index) * 2));
                        when FAT32 =>
                           Value := Decode_Cluster (Read_U32 (FS.Cache (Buffer), Natural (Entry_Index) * 4));
                        when Invalid | FAT12 =>
                           Status := Find_Fatal;
                           return;
                     end case;
                     if Is_Free_Space (Value) = Looking_Free then
                        --  The last FAT sector may hold entries past the volume.
                        if Cluster < Limit then
                           Status := Found;
                        else
                           Cluster := Limit;
                           Status := Not_Found;
                        end if;
                        return;
                     end if;
                     Cluster := Cluster + Jump;
                     Entry_Index := Entry_Index + Jump;
                     exit when Entry_Index >= Per_Sector;
                  end loop;
                  FAT_Sector := FAT_Sector + 1;
                  Entry_Index := 0;
               when Failure =>
                  Status := Find_Fatal;
                  return;
               when In_Progress =>
                  Status := Find_In_Progress;
                  return;
            end case;
         end if;
      end loop;
      Cluster := Limit;
      Status := Not_Found;
   end Find_Cluster;

   -----------------------
   -- File_Next_Cluster --
   -----------------------

   procedure File_Next_Cluster
     (FS      : in out File_System;
      Card    : in out Card_State;
      Id      : File_Id;
      Current : Unsigned_32;
      Next    : in out Unsigned_32;
      Status  : out Operation_Status)
   is
   begin
      if (FS.Files (Id).Mode and Mode_Contiguous) /= 0 then
         declare
            Free_Start : constant Unsigned_32 := FS.Files (Free_File).First_Cluster;
         begin
            Check (FS, Current + 1 <= Free_Start);
            Next := (if Current + 1 = Free_Start then 0 else Current + 1);
            Status := Success;
         end;
      else
         FAT_Get_Next_Cluster (FS, Card, 0, Current, Status, Next);
      end if;
   end File_Next_Cluster;

   --------------
   -- FAT_Fill --
   --------------

   procedure FAT_Fill
     (FS      : in out File_System;
      Card    : in out Card_State;
      Pattern : FAT_Pattern;
      Start   : in out Unsigned_32;
      Finish  : Unsigned_32;
      Status  : out Operation_Status)
   is
      Per_Sector  : constant Unsigned_32 := FAT_Entries_Per_Sector (FS.Vol);
      FAT_Sector  : Unsigned_32;
      First_Entry : Unsigned_32;
      Physical    : Unsigned_32;
      Erase       : Unsigned_32;
      Buffer      : Cache_Slot;
      Entry_Index : Unsigned_32;
   begin
      FAT_Position (FS.Vol, Start, FAT_Sector, First_Entry);
      Physical := FAT_Sector_To_Physical (FS.Vol, 0, FAT_Sector);
      Erase := (Finish - Start + First_Entry + Per_Sector - 1) / Per_Sector;
      while Start < Finish loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         pragma Loop_Invariant (First_Entry < Per_Sector);
         declare
            Last_Entry : constant Unsigned_32 := Unsigned_32'Min (First_Entry + (Finish - Start), Per_Sector);
            Next       : Unsigned_32 := Start + 1;
         begin
            Cache_Sector (FS, Card, Physical,
                          (Read        => First_Entry > 0 or else Last_Entry < Per_Sector,
                           Write       => True,
                           Discardable => True,
                           others      => False),
                          Erase, Status, Buffer);
            if Status /= Success then
               return;
            end if;
            Entry_Index := First_Entry;
            while Entry_Index < Last_Entry loop
               pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
               pragma Loop_Invariant (Entry_Index < Per_Sector);
               case Pattern is
                  when Open_Chain | Closed_Chain =>
                     case FS.Vol.FS_Type is
                        when FAT16 =>
                           Write_U16 (FS.Cache (Buffer), Natural (Entry_Index) * 2, Unsigned_16 (Next and 16#FFFF#));
                        when FAT32 =>
                           Write_U32 (FS.Cache (Buffer), Natural (Entry_Index) * 4, Next);
                        when Invalid | FAT12 =>
                           null;
                     end case;
                     Next := Next + 1;
                  when Free_Clusters =>
                     case FS.Vol.FS_Type is
                        when FAT16 =>
                           Write_U16 (FS.Cache (Buffer), Natural (Entry_Index) * 2, 0);
                        when FAT32 =>
                           Write_U32 (FS.Cache (Buffer), Natural (Entry_Index) * 4, 0);
                        when Invalid | FAT12 =>
                           null;
                     end case;
               end case;
               Entry_Index := Entry_Index + 1;
            end loop;
            Start := Start + (Last_Entry - First_Entry);
            if Pattern = Closed_Chain and then Start = Finish and then Last_Entry > 0 then
               --  The chain's last entry ends it.
               case FS.Vol.FS_Type is
                  when FAT16 =>
                     Write_U16 (FS.Cache (Buffer), Natural (Last_Entry - 1) * 2, 16#FFFF#);
                  when FAT32 =>
                     Write_U32 (FS.Cache (Buffer), Natural (Last_Entry - 1) * 4, 16#FFFF_FFFF#);
                  when Invalid | FAT12 =>
                     null;
               end case;
            end if;
         end;
         Physical := Physical + 1;
         Erase := Erase - 1;
         First_Entry := 0;
      end loop;
      Status := Success;
   end FAT_Fill;

   --------------------------
   -- Save_Directory_Entry --
   --------------------------

   procedure Save_Directory_Entry
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Mode : Save_Mode; Status : out Operation_Status)
   is
      Buffer : Cache_Slot;
   begin
      if FS.Files (Id).Entry_At.Sector = 0 then
         Status := Success;
         return;
      end if;
      Cache_Sector (FS, Card, FS.Files (Id).Entry_At.Sector, (Read => True, Write => True, others => False), 0,
                    Status, Buffer);
      if Status = Success then
         Check (FS, FS.Files (Id).Entry_At.Index >= 0);
         if FS.Files (Id).Entry_At.Index >= 0 then
            declare
               Base : constant Sector_Offset := Natural (FS.Files (Id).Entry_At.Index) * Directory_Entry_Size;
               Size : Unsigned_32 :=
                 (case Mode is
                     when Save_Normal                   => FS.Files (Id).Physical_Size,
                     when Save_For_Close | Save_Deleted => FS.Files (Id).Logical_Size);
            begin
               if Mode = Save_Deleted then
                  FS.Cache (Buffer) (Base) := Deleted_File_Marker;
               end if;
               --  Directories keep no size in their entry.
               if FS.Files (Id).Kind = Directory then
                  Size := 0;
               end if;
               Write_U32 (FS.Cache (Buffer), Base + 28, Size);
               Write_U16 (FS.Cache (Buffer), Base + 20,
                          Unsigned_16 (Interfaces.Shift_Right (FS.Files (Id).First_Cluster, 16)));
               Write_U16 (FS.Cache (Buffer), Base + 26, Unsigned_16 (FS.Files (Id).First_Cluster and 16#FFFF#));
            end;
         else
            Status := Failure;
         end if;
      end if;
   end Save_Directory_Entry;

   ----------------------------------
   -- Append_Free_Cluster_Continue --
   ----------------------------------

   procedure Append_Free_Cluster_Continue
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
   is
      Result : Operation_Status;
   begin
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         case FS.Files (Id).Operation.Free_Append.Phase is
            when Find_Free_Space =>
               declare
                  Search : Unsigned_32 := FS.Files (Id).Operation.Free_Append.Search;
                  Found_Status : Find_Status;
               begin
                  Find_Cluster (FS, Card, Free_Cluster, Search, FS.Vol.Num_Clusters + Smallest_Cluster, Found_Status);
                  FS.Files (Id).Operation.Free_Append.Search := Search;
                  case Found_Status is
                     when Found =>
                        FS.Last_Cluster_Allocated := Search;
                        --  The file may write to the cluster before the FAT
                        --  links it.
                        FS.Files (Id).Cursor_Cluster := Search;
                        FS.Files (Id).Physical_Size := FS.Files (Id).Physical_Size + Cluster_Size (FS.Vol);
                        if FS.Files (Id).Operation.Free_Append.Previous = 0 then
                           FS.Files (Id).First_Cluster := Search;
                        end if;
                        FS.Files (Id).Operation.Free_Append.Phase := Update_FAT_1;
                     when Find_Fatal | Not_Found =>
                        FS.Files (Id).Operation.Free_Append.Phase := Failed;
                     when Find_In_Progress =>
                        Status := In_Progress;
                        return;
                  end case;
               end;
            when Update_FAT_1 =>
               FAT_Set_Next_Cluster (FS, Card, FS.Files (Id).Operation.Free_Append.Search, 16#FFFF_FFFF#, Result);
               if Result /= Success then
                  Status := In_Progress;
                  return;
               end if;
               FS.Files (Id).Operation.Free_Append.Phase :=
                 (if FS.Files (Id).Operation.Free_Append.Previous /= 0 then Update_FAT_2 else Update_File_Entry);
            when Update_FAT_2 =>
               FAT_Set_Next_Cluster (FS, Card, FS.Files (Id).Operation.Free_Append.Previous,
                                     FS.Files (Id).Operation.Free_Append.Search, Result);
               if Result /= Success then
                  Status := In_Progress;
                  return;
               end if;
               FS.Files (Id).Operation.Free_Append.Phase := Update_File_Entry;
            when Update_File_Entry =>
               Save_Directory_Entry (FS, Card, Id, Save_Normal, Result);
               if Result /= Success then
                  Status := In_Progress;
                  return;
               end if;
               FS.Files (Id).Operation.Free_Append.Phase := Complete;
            when Complete =>
               if FS.Files (Id).Operation.Kind = Append_Free_Cluster then
                  FS.Files (Id).Operation.Kind := Idle;
               end if;
               Status := Success;
               return;
            when Failed =>
               if FS.Files (Id).Operation.Kind = Append_Free_Cluster then
                  FS.Files (Id).Operation.Kind := Idle;
               end if;
               FS.Full := True;
               Status := Failure;
               return;
         end case;
      end loop;
   end Append_Free_Cluster_Continue;

   ---------------------------------
   -- Append_Regular_Free_Cluster --
   ---------------------------------

   procedure Append_Regular_Free_Cluster
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
   is
   begin
      if FS.Files (Id).Operation.Kind = Append_Free_Cluster then
         Status := In_Progress;
         return;
      end if;
      if FS.Full or else Is_Busy (FS.Files (Id)) then
         Status := Failure;
         return;
      end if;
      FS.Files (Id).Operation.Kind := Append_Free_Cluster;
      FS.Files (Id).Operation.Free_Append := (Previous => FS.Files (Id).Cursor_Previous_Cluster,
                                              Search   => FS.Last_Cluster_Allocated,
                                              Phase    => Find_Free_Space);
      Append_Free_Cluster_Continue (FS, Card, Id, Status);
   end Append_Regular_Free_Cluster;

   ----------------------------------
   -- Append_Supercluster_Continue --
   ----------------------------------

   procedure Append_Supercluster_Continue
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
   is
      Per_Sector : constant Unsigned_32 := FAT_Entries_Per_Sector (FS.Vol);
      Size       : constant Unsigned_32 := Supercluster_Size (FS.Vol);
   begin
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         case FS.Files (Id).Operation.Super_Append.Phase is
            when Take_Supercluster =>
               --  The file takes the free-space file's first supercluster and
               --  may write to it before the FAT and the entries change.
               FS.Files (Id).Cursor_Cluster := FS.Files (Free_File).First_Cluster;
               FS.Files (Id).Physical_Size := FS.Files (Id).Physical_Size + Size;
               FS.Files (Free_File).First_Cluster := FS.Files (Free_File).First_Cluster + Per_Sector;
               FS.Files (Free_File).Logical_Size := FS.Files (Free_File).Logical_Size - Size;
               FS.Files (Free_File).Physical_Size := FS.Files (Free_File).Physical_Size - Size;
               FS.Files (Id).Operation.Super_Append.Rewrite_Start := FS.Files (Id).Cursor_Cluster;
               FS.Files (Id).Operation.Super_Append.Rewrite_End := FS.Files (Id).Cursor_Cluster + Per_Sector;
               if FS.Files (Id).Operation.Super_Append.Previous = 0 then
                  FS.Files (Id).First_Cluster := FS.Files (Id).Cursor_Cluster;
               else
                  --  The supercluster that ended the file no longer ends it.
                  FS.Files (Id).Operation.Super_Append.Rewrite_Start :=
                    FS.Files (Id).Operation.Super_Append.Rewrite_Start - Per_Sector;
               end if;
               FS.Files (Id).Operation.Super_Append.Phase := Update_Free_File_Entry;
            when Update_Free_File_Entry =>
               Save_Directory_Entry (FS, Card, Free_File, Save_Normal, Status);
               exit when Status /= Success;
               FS.Files (Id).Operation.Super_Append.Phase := Update_Supercluster_FAT;
            when Update_Supercluster_FAT =>
               declare
                  Start : Unsigned_32 := FS.Files (Id).Operation.Super_Append.Rewrite_Start;
               begin
                  FAT_Fill (FS, Card, Closed_Chain, Start, FS.Files (Id).Operation.Super_Append.Rewrite_End, Status);
                  FS.Files (Id).Operation.Super_Append.Rewrite_Start := Start;
               end;
               exit when Status /= Success;
               FS.Files (Id).Operation.Super_Append.Phase := Save_File_Entry;
            when Save_File_Entry =>
               Save_Directory_Entry (FS, Card, Id, Save_Normal, Status);
               exit;
         end case;
      end loop;
      if Status /= In_Progress and then FS.Files (Id).Operation.Kind = Append_Supercluster then
         FS.Files (Id).Operation.Kind := Idle;
      end if;
   end Append_Supercluster_Continue;

   -------------------------
   -- Append_Supercluster --
   -------------------------

   procedure Append_Supercluster
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
   is
   begin
      if FS.Files (Id).Operation.Kind = Append_Supercluster then
         Status := In_Progress;
         return;
      end if;
      if FS.Files (Free_File).Logical_Size < Supercluster_Size (FS.Vol) then
         FS.Full := True;
      end if;
      if FS.Full or else Is_Busy (FS.Files (Id)) then
         Status := Failure;
         return;
      end if;
      FS.Files (Id).Operation.Kind := Append_Supercluster;
      FS.Files (Id).Operation.Super_Append.Phase := Take_Supercluster;
      FS.Files (Id).Operation.Super_Append.Previous := FS.Files (Id).Cursor_Previous_Cluster;
      Append_Supercluster_Continue (FS, Card, Id, Status);
   end Append_Supercluster;

   --------------------
   -- Append_Cluster --
   --------------------

   procedure Append_Cluster
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
   is
   begin
      if (FS.Files (Id).Mode and Mode_Contiguous) /= 0 then
         Append_Supercluster (FS, Card, Id, Status);
      else
         Append_Regular_Free_Cluster (FS, Card, Id, Status);
      end if;
   end Append_Cluster;

   --------------------------
   -- Retain_Cursor_Sector --
   --------------------------

   procedure Retain_Cursor_Sector
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Slot : out Cache_Slot)
   is
      Physical : constant Unsigned_32 := Cursor_Sector (FS, Id);
      Status   : Operation_Status;
   begin
      if FS.Files (Id).Read_Retained /= No_Slot then
         declare
            Held : constant Cache_Index := FS.Files (Id).Read_Retained;
            Same : constant Boolean := Physical = FS.Descriptors (Held).Sector_Index;
         begin
            Check (FS, Same);
            Slot := (if Same then Held else No_Slot);
         end;
      elsif End_Of_Allocation (FS, Id) then
         Slot := No_Slot;
      else
         --  Files never read the partition table.
         Check (FS, Physical > 0);
         Cache_Sector (FS, Card, Physical, (Read => True, Retain => True, others => False), 0, Status, Slot);
         if Status = Success then
            FS.Files (Id).Read_Retained := Slot;
         end if;
      end if;
   end Retain_Cursor_Sector;

   ------------------------
   -- Lock_Cursor_Sector --
   ------------------------

   procedure Lock_Cursor_Sector
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Slot : out Cache_Slot)
   is
      Status : Operation_Status;
   begin
      if FS.Files (Id).Write_Locked /= No_Slot then
         declare
            Held : constant Cache_Index := FS.Files (Id).Write_Locked;
            Same : constant Boolean := Cursor_Sector (FS, Id) = FS.Descriptors (Held).Sector_Index;
         begin
            Check (FS, Same);
            Slot := (if Same then Held else No_Slot);
         end;
         return;
      end if;
      if End_Of_Allocation (FS, Id) then
         Append_Cluster (FS, Card, Id, Status);
         if Status /= Success then
            Slot := No_Slot;
            return;
         end if;
      end if;
      declare
         Offset     : constant Unsigned_32 := FS.Files (Id).Cursor_Offset;
         Sector_End : constant Unsigned_32 := (Offset and not Unsigned_32'(Sector_Size - 1)) + Sector_Size;
         Appending  : constant Unsigned_8 := Mode_Append or Mode_Contiguous;
         --  The sector is read first when the write leaves some of it.
         Flags      : constant Cache_Flags :=
           (Read   => Offset mod Sector_Size > 0 or else Sector_End < FS.Files (Id).Logical_Size,
            Write  => True,
            Lock   => True,
            others => False);
         --  A contiguous file that appends erases the rest of its supercluster
         --  ahead.
         Erase      : constant Unsigned_32 :=
           (if (FS.Files (Id).Mode and Appending) = Appending
            then FAT_Entries_Per_Sector (FS.Vol) * FS.Vol.Sectors_Per_Cluster
                 - (Offset and (Supercluster_Size (FS.Vol) - 1)) / Sector_Size
            else 0);
      begin
         Cache_Sector (FS, Card, Cursor_Sector (FS, Id), Flags, Erase, Status, Slot);
         if Status = Success then
            FS.Files (Id).Write_Locked := Slot;
         end if;
      end;
   end Lock_Cursor_Sector;

   -----------------
   -- Seek_Atomic --
   -----------------

   procedure Seek_Atomic
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Offset : Integer_32; Done : out Boolean)
   is
      Step      : constant Unsigned_32 := To_U32 (Offset);
      Remaining : Unsigned_32 := Step;
      Next      : Unsigned_32 := 0;
      Status    : Operation_Status;
   begin
      if Step + FS.Files (Id).Cursor_Offset mod Sector_Size < Sector_Size then
         FS.Files (Id).Cursor_Offset := FS.Files (Id).Cursor_Offset + Step;
         Done := True;
         return;
      end if;
      Unlock_File_Sector (FS, Id);
      --  The FAT16 root directory is one run of sectors.
      if FS.Files (Id).Kind = FAT16_Root then
         FS.Files (Id).Cursor_Offset := FS.Files (Id).Cursor_Offset + Step;
         Done := True;
         return;
      end if;
      declare
         Cluster_Bytes : constant Unsigned_32 := Cluster_Size (FS.Vol);
         In_Cluster    : constant Unsigned_32 := Byte_Index_In_Cluster (FS.Vol, FS.Files (Id).Cursor_Offset);
      begin
         if Interfaces.Integer_64 (Offset) > Interfaces.Integer_64 (To_I32 (Cluster_Bytes))
           or else Interfaces.Integer_64 (Offset) < -Interfaces.Integer_64 (To_I32 (In_Cluster))
         then
            Done := False;
            return;
         end if;
         if In_Cluster + Step >= Cluster_Bytes then
            File_Next_Cluster (FS, Card, Id, FS.Files (Id).Cursor_Cluster, Next, Status);
            if Status /= Success then
               Done := False;
               return;
            end if;
            FS.Files (Id).Cursor_Previous_Cluster := FS.Files (Id).Cursor_Cluster;
            FS.Files (Id).Cursor_Cluster := Next;
            FS.Files (Id).Cursor_Offset := FS.Files (Id).Cursor_Offset + (Cluster_Bytes - In_Cluster);
            Remaining := Remaining - (Cluster_Bytes - In_Cluster);
         end if;
      end;
      if not End_Of_Allocation (FS, Id) then
         FS.Files (Id).Cursor_Offset := FS.Files (Id).Cursor_Offset + Remaining;
      end if;
      Done := True;
   end Seek_Atomic;

   -------------------
   -- Seek_Continue --
   -------------------

   procedure Seek_Continue (FS : in out File_System; Card : in out Card_State; Id : File_Id; Done : out Boolean)
   is
      Cluster_Bytes : constant Unsigned_32 := Cluster_Size (FS.Vol);
      In_Cluster    : Unsigned_32 := Byte_Index_In_Cluster (FS.Vol, FS.Files (Id).Cursor_Offset);
      Next          : Unsigned_32;
      Status        : Operation_Status;
   begin
      while In_Cluster + FS.Files (Id).Operation.Seek_Offset >= Cluster_Bytes
        and then not End_Of_Allocation (FS, Id)
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         Next := 0;
         File_Next_Cluster (FS, Card, Id, FS.Files (Id).Cursor_Cluster, Next, Status);
         if Status /= Success then
            Done := False;
            return;
         end if;
         FS.Files (Id).Cursor_Previous_Cluster := FS.Files (Id).Cursor_Cluster;
         FS.Files (Id).Cursor_Cluster := Next;
         FS.Files (Id).Cursor_Offset := FS.Files (Id).Cursor_Offset + (Cluster_Bytes - In_Cluster);
         FS.Files (Id).Operation.Seek_Offset := FS.Files (Id).Operation.Seek_Offset - (Cluster_Bytes - In_Cluster);
         In_Cluster := 0;
      end loop;
      if not End_Of_Allocation (FS, Id) then
         FS.Files (Id).Cursor_Offset := FS.Files (Id).Cursor_Offset + FS.Files (Id).Operation.Seek_Offset;
      end if;
      Update_File_Size (FS.Files (Id));
      FS.Files (Id).Operation.Kind := Idle;
      Notify (FS, FS.Files (Id).Operation.Callback, File_Ref (Id));
      Done := True;
   end Seek_Continue;

   ------------------
   -- Seek_Forward --
   ------------------

   procedure Seek_Forward
     (FS       : in out File_System;
      Card     : in out Card_State;
      Id       : File_Id;
      Offset   : Unsigned_32;
      Status   : out Operation_Status;
      Callback : Callback_Tag := No_Callback)
   is
      Done : Boolean;
   begin
      Seek_Atomic (FS, Card, Id, To_I32 (Offset), Done);
      if Done then
         Notify (FS, Callback, File_Ref (Id));
         Status := Success;
      elsif Is_Busy (FS.Files (Id)) then
         Status := Failure;
      else
         FS.Files (Id).Operation.Kind := Seek;
         FS.Files (Id).Operation.Callback := Callback;
         FS.Files (Id).Operation.Seek_Offset := Offset;
         Status := In_Progress;
      end if;
   end Seek_Forward;

   ----------
   -- Seek --
   ----------

   procedure Seek
     (FS     : in out File_System;
      Card   : in out Card_State;
      Id     : File_Id;
      Offset : Integer_32;
      Origin : Seek_Origin;
      Status : out Operation_Status)
   is
      Target : Unsigned_32 := To_U32 (Offset);
   begin
      --  The logical size bounds the seek, so it comes up to date first.
      Update_File_Size (FS.Files (Id));
      case Origin is
         when From_Current =>
            if Offset >= 0 then
               Seek_Forward
                 (FS, Card, Id, Unsigned_32'Min (FS.Files (Id).Cursor_Offset + Target, FS.Files (Id).Logical_Size),
                  Status);
               return;
            end if;
            Target := Target + FS.Files (Id).Cursor_Offset;
         when From_End =>
            if FS.Files (Id).Logical_Size + Target = FS.Files (Id).Cursor_Offset then
               Status := Success;
               return;
            end if;
            Target := Target + FS.Files (Id).Logical_Size;
         when From_Start =>
            null;
      end case;
      Unlock_File_Sector (FS, Id);
      FS.Files (Id).Cursor_Previous_Cluster := 0;
      FS.Files (Id).Cursor_Cluster := FS.Files (Id).First_Cluster;
      FS.Files (Id).Cursor_Offset := 0;
      Seek_Forward (FS, Card, Id, Unsigned_32'Min (Target, FS.Files (Id).Logical_Size), Status);
   end Seek;

   -----------
   -- Write --
   -----------

   procedure Write
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Data : Data_Bytes; Written : out Natural)
   is
      In_Sector : Natural := Natural (FS.Files (Id).Cursor_Offset mod Sector_Size);
      Count     : Natural;
      Slot      : Cache_Slot;
      Status    : Operation_Status;
   begin
      Written := 0;
      if (FS.Files (Id).Mode and (Mode_Append or Mode_Write)) = 0 or else Is_Busy (FS.Files (Id)) then
         return;
      end if;
      while Written < Data'Length loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         pragma Loop_Invariant (In_Sector < Sector_Size and then Written < Data'Length);
         Count := Natural'Min (Sector_Size - In_Sector, Data'Length - Written);
         Lock_Cursor_Sector (FS, Card, Id, Slot);
         exit when Slot = No_Slot;
         for K in 0 .. Count - 1 loop
            FS.Cache (Slot) (In_Sector + K) := Data (Data'First + Written + K);
         end loop;
         Written := Written + Count;
         --  A seek that queues ends the write until the file is free again.
         Seek_Forward (FS, Card, Id, Unsigned_32 (Count), Status);
         exit when Status = In_Progress;
         if (FS.Files (Id).Mode and Mode_Contiguous) /= 0 then
            Check (FS, FS.Files (Id).Cursor_Cluster < FS.Files (Free_File).First_Cluster);
         end if;
         In_Sector := 0;
      end loop;
   end Write;

   --------------
   -- Put_Byte --
   --------------

   procedure Put_Byte (FS : in out File_System; Card : in out Card_State; Id : File_Id; Value : Unsigned_8) is
      In_Sector : constant Natural := Natural (FS.Files (Id).Cursor_Offset mod Sector_Size);
      Slot      : constant Cache_Slot := FS.Files (Id).Write_Locked;
      Unused    : Natural;
   begin
      if Slot /= No_Slot and then In_Sector /= Sector_Size - 1 then
         FS.Cache (Slot) (In_Sector) := Value;
         FS.Files (Id).Cursor_Offset := FS.Files (Id).Cursor_Offset + 1;
      else
         Write (FS, Card, Id, (0 => Value), Unused);
      end if;
   end Put_Byte;

   ----------
   -- Read --
   ----------

   procedure Read
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Data : in out Data_Bytes; Count : out Natural)
   is
      Wanted    : Natural;
      In_Sector : Natural;
      Part      : Natural;
      Slot      : Cache_Slot;
      Status    : Operation_Status;
   begin
      Count := 0;
      --  A write that extended the file leaves the cursor past the logical
      --  size, which is then the end.
      if (FS.Files (Id).Mode and Mode_Read) = 0 or else Is_Busy (FS.Files (Id))
        or else FS.Files (Id).Cursor_Offset >= FS.Files (Id).Logical_Size
      then
         return;
      end if;
      Wanted := Natural (Unsigned_32'Min (FS.Files (Id).Logical_Size - FS.Files (Id).Cursor_Offset,
                                          Unsigned_32 (Data'Length)));
      In_Sector := Natural (FS.Files (Id).Cursor_Offset mod Sector_Size);
      while Count < Wanted loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         pragma Loop_Invariant (In_Sector < Sector_Size and then Count < Wanted and then Wanted <= Data'Length);
         Part := Natural'Min (Sector_Size - In_Sector, Wanted - Count);
         Retain_Cursor_Sector (FS, Card, Id, Slot);
         exit when Slot = No_Slot;
         for K in 0 .. Part - 1 loop
            Data (Data'First + Count + K) := FS.Cache (Slot) (In_Sector + K);
         end loop;
         Count := Count + Part;
         Seek_Forward (FS, Card, Id, Unsigned_32 (Part), Status);
         exit when Status = In_Progress;
         In_Sector := 0;
      end loop;
   end Read;

   ----------------
   -- Find_First --
   ----------------

   procedure Find_First
     (FS : in out File_System; Card : in out Card_State; Dir : File_Id; Finder : in out Entry_Position)
   is
      Unused_Status : Operation_Status;
   begin
      Seek (FS, Card, Dir, 0, From_Start, Unused_Status);
      Finder.Index := -1;
   end Find_First;

   ---------------
   -- Find_Next --
   ---------------

   procedure Find_Next
     (FS     : in out File_System;
      Card   : in out Card_State;
      Dir    : File_Id;
      Finder : in out Entry_Position;
      Status : out Operation_Status;
      Slot   : out Cache_Slot)
   is
      Done : Boolean;
   begin
      Slot := No_Slot;
      if Finder.Index = Entries_Per_Sector - 1 then
         Seek_Atomic (FS, Card, Dir, Sector_Size, Done);
         if not Done then
            Status := In_Progress;
            return;
         end if;
         Finder.Index := -1;
      end if;
      Retain_Cursor_Sector (FS, Card, Dir, Slot);
      if Slot /= No_Slot then
         Finder.Index := Finder.Index + 1;
         Finder.Sector := Cursor_Sector (FS, Dir);
         Status := Success;
      elsif End_Of_Allocation (FS, Dir) then
         Status := Success;
      else
         Status := In_Progress;
      end if;
   end Find_Next;

   ---------------
   -- Find_Last --
   ---------------

   procedure Find_Last (FS : in out File_System; Dir : File_Id) is
   begin
      Unlock_File_Sector (FS, Dir);
   end Find_Last;

   ----------------------------------
   -- Extend_Subdirectory_Continue --
   ----------------------------------

   procedure Extend_Subdirectory_Continue
     (FS : in out File_System; Card : in out Card_State; Dir : File_Id; Status : out Operation_Status)
   is
      Result : Operation_Status;
      Done   : Boolean;
   begin
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         case FS.Files (Dir).Operation.Extension.Phase is
            when Add_Free_Cluster =>
               Append_Free_Cluster_Continue (FS, Card, Dir, Result);
               case Result is
                  when Success =>
                     FS.Files (Dir).Operation.Extension.Phase := Write_Sectors;
                  when Failure =>
                     FS.Files (Dir).Operation.Extension.Phase := Extend_Failure;
                  when In_Progress =>
                     Status := In_Progress;
                     return;
               end case;
            when Write_Sectors =>
               declare
                  In_Cluster : Unsigned_16 :=
                    Unsigned_16 ((if FS.Files (Dir).Kind = FAT16_Root then FS.Files (Dir).Cursor_Offset / Sector_Size
                                  else Sector_Index_In_Cluster (FS.Vol, FS.Files (Dir).Cursor_Offset)) and 16#FFFF#);
                  Physical   : Unsigned_32 := Cursor_Sector (FS, Dir);
                  Buffer     : Cache_Slot;
               begin
                  loop
                     pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
                     Cache_Sector (FS, Card, Physical, (Write => True, others => False), 0, Result, Buffer);
                     if Result /= Success then
                        Status := Result;
                        return;
                     end if;
                     FS.Cache (Buffer) := (others => 0);
                     --  A subdirectory's first sector starts with its "." and
                     --  ".." entries.
                     if FS.Files (Dir).Entry_At.Sector /= 0 and then FS.Files (Dir).Cursor_Offset = 0 then
                        for K in 0 .. Filename_Length - 1 loop
                           FS.Cache (Buffer) (K) := Character'Pos (' ');
                           FS.Cache (Buffer) (Directory_Entry_Size + K) := Character'Pos (' ');
                        end loop;
                        FS.Cache (Buffer) (0) := Character'Pos ('.');
                        Write_U16 (FS.Cache (Buffer), 20,
                                   Unsigned_16 (Interfaces.Shift_Right (FS.Files (Dir).First_Cluster, 16)));
                        Write_U16 (FS.Cache (Buffer), 26, Unsigned_16 (FS.Files (Dir).First_Cluster and 16#FFFF#));
                        FS.Cache (Buffer) (11) := Attribute_Directory;
                        FS.Cache (Buffer) (Directory_Entry_Size) := Character'Pos ('.');
                        FS.Cache (Buffer) (Directory_Entry_Size + 1) := Character'Pos ('.');
                        Write_U16 (FS.Cache (Buffer), Directory_Entry_Size + 20,
                                   Unsigned_16 (Interfaces.Shift_Right
                                                  (FS.Files (Dir).Operation.Extension.Parent_Cluster, 16)));
                        Write_U16 (FS.Cache (Buffer), Directory_Entry_Size + 26,
                                   Unsigned_16 (FS.Files (Dir).Operation.Extension.Parent_Cluster and 16#FFFF#));
                        FS.Cache (Buffer) (Directory_Entry_Size + 11) := Attribute_Directory;
                     end if;
                     exit when Unsigned_32 (In_Cluster) >= FS.Vol.Sectors_Per_Cluster - 1;
                     Seek_Atomic (FS, Card, Dir, Sector_Size, Done);
                     Check (FS, Done);
                     In_Cluster := In_Cluster + 1;
                     Physical := Physical + 1;
                  end loop;
               end;
               --  Back to the start of the cluster.
               Seek_Atomic (FS, Card, Dir, To_I32 (0 - Sector_Size * (FS.Vol.Sectors_Per_Cluster - 1)), Done);
               Check (FS, Done);
               FS.Files (Dir).Operation.Extension.Phase := Extend_Success;
            when Extend_Success =>
               FS.Files (Dir).Operation.Kind := Idle;
               Notify (FS, FS.Files (Dir).Operation.Callback, File_Ref (Dir));
               Status := Success;
               return;
            when Extend_Failure =>
               FS.Files (Dir).Operation.Kind := Idle;
               Notify (FS, FS.Files (Dir).Operation.Callback, No_File);
               Status := Failure;
               return;
         end case;
      end loop;
   end Extend_Subdirectory_Continue;

   -------------------------
   -- Extend_Subdirectory --
   -------------------------

   procedure Extend_Subdirectory
     (FS             : in out File_System;
      Card           : in out Card_State;
      Dir            : File_Id;
      Parent_Cluster : Unsigned_32;
      Callback       : Callback_Tag;
      Status         : out Operation_Status)
   is
   begin
      --  The FAT16 root directory cannot grow.
      if FS.Files (Dir).Kind = FAT16_Root or else Is_Busy (FS.Files (Dir)) then
         Status := Failure;
         return;
      end if;
      FS.Files (Dir).Operation.Kind := Extend_Subdirectory;
      FS.Files (Dir).Operation.Extension := (Phase => Add_Free_Cluster, Parent_Cluster => Parent_Cluster);
      FS.Files (Dir).Operation.Callback := Callback;
      FS.Files (Dir).Operation.Free_Append := (Previous => FS.Files (Dir).Cursor_Previous_Cluster,
                                               Search   => FS.Last_Cluster_Allocated,
                                               Phase    => Find_Free_Space);
      Extend_Subdirectory_Continue (FS, Card, Dir, Status);
   end Extend_Subdirectory;

   ------------------------------
   -- Allocate_Directory_Entry --
   ------------------------------

   procedure Allocate_Directory_Entry
     (FS     : in out File_System;
      Card   : in out Card_State;
      Dir    : File_Id;
      Finder : in out Entry_Position;
      Status : out Operation_Status;
      Slot   : out Cache_Slot)
   is
   begin
      Slot := No_Slot;
      if Is_Busy (FS.Files (Dir)) then
         Status := In_Progress;
         return;
      end if;
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry and then Slot = No_Slot);
         Find_Next (FS, Card, Dir, Finder, Status, Slot);
         exit when Status /= Success;
         if Slot /= No_Slot then
            declare
               First : constant Unsigned_8 := FS.Cache (Slot) (Natural (Finder.Index) * Directory_Entry_Size);
            begin
               if Is_Entry_Empty (First) or else Is_Entry_Terminator (First) then
                  Mark_Dirty (FS, Slot);
                  Find_Last (FS, Dir);
                  Status := Success;
                  return;
               end if;
            end;
            Slot := No_Slot;
         else
            --  The directory's clusters are full: one more, then the search
            --  goes on in it.
            Extend_Subdirectory (FS, Card, Dir, 0, No_Callback, Status);
            exit when Status /= Success;
         end if;
      end loop;
      Slot := No_Slot;
   end Allocate_Directory_Entry;

   -----------------------
   -- Truncate_Continue --
   -----------------------

   procedure Truncate_Continue
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Mark_Deleted : Boolean;
      Status : out Operation_Status)
   is
      Next      : Unsigned_32;
      Old_Start : Unsigned_32;
      Grow      : Unsigned_32;
      Position  : Unsigned_32;
   begin
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         case FS.Files (Id).Operation.Truncation.Phase is
            when Update_Directory =>
               Save_Directory_Entry (FS, Card, Id, (if Mark_Deleted then Save_Deleted else Save_Normal), Status);
               exit when Status /= Success;
               FS.Files (Id).Operation.Truncation.Phase :=
                 (if FS.Files (Id).Operation.Truncation.End_Cluster /= 0 then Erase_Contiguous_Chain else Erase_Chain);
            when Erase_Contiguous_Chain =>
               --  The clusters go back on the front of the free-space file.
               Position := FS.Files (Id).Operation.Truncation.Current_Cluster;
               FAT_Fill (FS, Card, Open_Chain, Position, FS.Files (Id).Operation.Truncation.End_Cluster, Status);
               FS.Files (Id).Operation.Truncation.Current_Cluster := Position;
               exit when Status /= Success;
               FS.Files (Id).Operation.Truncation.Phase := Prepend_To_Free_File;
            when Prepend_To_Free_File =>
               Old_Start := FS.Files (Free_File).First_Cluster;
               FS.Files (Free_File).First_Cluster := FS.Files (Id).Operation.Truncation.Start_Cluster;
               Grow := (Old_Start - FS.Files (Id).Operation.Truncation.Start_Cluster) * Cluster_Size (FS.Vol);
               FS.Files (Free_File).Logical_Size := FS.Files (Free_File).Logical_Size + Grow;
               FS.Files (Free_File).Physical_Size := FS.Files (Free_File).Physical_Size + Grow;
               Save_Directory_Entry (FS, Card, Free_File, Save_Normal, Status);
               exit when Status /= Success;
               FS.Files (Id).Operation.Truncation.Phase := Truncate_Success;
            when Erase_Chain =>
               --  A reserved cluster ends the walk, so an empty file frees nothing (D6).
               while FS.Files (Id).Operation.Truncation.Current_Cluster >= Smallest_Cluster
                 and then not FAT_End_Of_Chain (FS.Vol, FS.Files (Id).Operation.Truncation.Current_Cluster)
               loop
                  pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
                  Next := 0;
                  FAT_Get_Next_Cluster (FS, Card, 0, FS.Files (Id).Operation.Truncation.Current_Cluster, Status, Next);
                  if Status /= Success then
                     return;
                  end if;
                  FAT_Set_Next_Cluster (FS, Card, FS.Files (Id).Operation.Truncation.Current_Cluster, 0, Status);
                  if Status /= Success then
                     return;
                  end if;
                  FS.Files (Id).Operation.Truncation.Current_Cluster := Next;
                  --  Searches for a free cluster start no later than this one.
                  FS.Last_Cluster_Allocated := Unsigned_32'Min (FS.Last_Cluster_Allocated, Next - 1);
               end loop;
               FS.Files (Id).Operation.Truncation.Phase := Truncate_Success;
            when Truncate_Success =>
               if FS.Files (Id).Operation.Kind = Truncate then
                  FS.Files (Id).Operation.Kind := Idle;
               end if;
               Notify (FS, FS.Files (Id).Operation.Callback, File_Ref (Id));
               Status := Success;
               return;
         end case;
      end loop;
      if Status = Failure and then FS.Files (Id).Operation.Kind = Truncate then
         FS.Files (Id).Operation.Kind := Idle;
      end if;
   end Truncate_Continue;

   --------------
   -- Truncate --
   --------------

   procedure Truncate
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Callback : Callback_Tag; Queued : out Boolean)
   is
      Unused_Status : Operation_Status;
   begin
      if Is_Busy (FS.Files (Id)) then
         Queued := False;
         return;
      end if;
      FS.Files (Id).Operation.Kind := Truncate;
      FS.Files (Id).Operation.Callback := Callback;
      FS.Files (Id).Operation.Truncation :=
        (Start_Cluster   => FS.Files (Id).First_Cluster,
         Current_Cluster => FS.Files (Id).First_Cluster,
         --  A contiguous file ends where the free-space file starts.
         End_Cluster     => (if (FS.Files (Id).Mode and Mode_Contiguous) /= 0 then FS.Files (Free_File).First_Cluster
                             else 0),
         Phase           => Update_Directory);
      --  The directory entry drops the chain at once.
      FS.Files (Id).First_Cluster := 0;
      FS.Files (Id).Logical_Size := 0;
      FS.Files (Id).Physical_Size := 0;
      Seek (FS, Card, Id, 0, From_Start, Unused_Status);
      Queued := True;
   end Truncate;

   --------------------------
   -- Create_File_Continue --
   --------------------------

   procedure Create_File_Continue (FS : in out File_System; Card : in out Card_State; Id : File_Id) is
      Finder        : Entry_Position;
      Status        : Operation_Status;
      Slot          : Cache_Slot;
      Unused_Slot   : Cache_Slot;
      Unused_Status : Operation_Status;
      Unused_Queued : Boolean;
   begin
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         case FS.Files (Id).Operation.Create.Phase is
            when Create_Start =>
               Finder := FS.Files (Id).Entry_At;
               Find_First (FS, Card, Current_Directory, Finder);
               FS.Files (Id).Entry_At := Finder;
               FS.Files (Id).Operation.Create.Phase := Find_File;
            when Find_File =>
               loop
                  pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
                  Finder := FS.Files (Id).Entry_At;
                  Find_Next (FS, Card, Current_Directory, Finder, Status, Slot);
                  FS.Files (Id).Entry_At := Finder;
                  case Status is
                     when Success =>
                        if Slot = No_Slot
                          or else Is_Entry_Terminator (FS.Cache (Slot) (Natural (Finder.Index) * Directory_Entry_Size))
                        then
                           --  The end of the directory: a new entry when the
                           --  mode creates.
                           Find_Last (FS, Current_Directory);
                           if (FS.Files (Id).Mode and Mode_Create) /= 0 then
                              Finder := FS.Files (Id).Entry_At;
                              Find_First (FS, Card, Current_Directory, Finder);
                              FS.Files (Id).Entry_At := Finder;
                              FS.Files (Id).Operation.Create.Phase := Create_New_File;
                           else
                              FS.Files (Id).Operation.Create.Phase := Create_Failure;
                           end if;
                           exit;
                        end if;
                        declare
                           Base : constant Sector_Offset := Natural (Finder.Index) * Directory_Entry_Size;
                           Same : Boolean := True;
                        begin
                           if (FS.Cache (Slot) (Base + 11) and Attribute_Volume_ID) = 0 then
                              for K in 0 .. Filename_Length - 1 loop
                                 Same := Same
                                   and then FS.Cache (Slot) (Base + K) = FS.Files (Id).Operation.Create.Name (K);
                              end loop;
                              if Same then
                                 --  A file is not opened as a directory, nor the
                                 --  other way round.
                                 if ((FS.Cache (Slot) (Base + 11) xor FS.Files (Id).Attrib)
                                     and Attribute_Directory) /= 0
                                 then
                                    Find_Last (FS, Current_Directory);
                                    FS.Files (Id).Operation.Create.Phase := Create_Failure;
                                    exit;
                                 end if;
                                 Load_Directory_Entry (FS, Id, Slot, Finder.Index);
                                 Find_Last (FS, Current_Directory);
                                 FS.Files (Id).Operation.Create.Phase := Create_Success;
                                 exit;
                              end if;
                           end if;
                        end;
                     when Failure =>
                        Find_Last (FS, Current_Directory);
                        FS.Files (Id).Operation.Create.Phase := Create_Failure;
                        exit;
                     when In_Progress =>
                        return;
                  end case;
               end loop;
            when Create_New_File =>
               Finder := FS.Files (Id).Entry_At;
               Allocate_Directory_Entry (FS, Card, Current_Directory, Finder, Status, Slot);
               FS.Files (Id).Entry_At := Finder;
               case Status is
                  when Success =>
                     if Slot /= No_Slot then
                        declare
                           Base  : constant Sector_Offset := Natural (Finder.Index) * Directory_Entry_Size;
                           Valid : Boolean;
                           Local : Clock_Reading;
                           Date  : Unsigned_16;
                           Time  : Unsigned_16;
                        begin
                           for K in 0 .. Directory_Entry_Size - 1 loop
                              FS.Cache (Slot) (Base + K) := 0;
                           end loop;
                           for K in 0 .. Filename_Length - 1 loop
                              FS.Cache (Slot) (Base + K) := FS.Files (Id).Operation.Create.Name (K);
                           end loop;
                           FS.Cache (Slot) (Base + 11) := FS.Files (Id).Attrib;
                           Read_Clock (Card, Valid, Local);
                           Date := (if Valid then FAT_Date (Local) else Default_Date);
                           Time := (if Valid then FAT_Time (Local) else Default_Time);
                           Write_U16 (FS.Cache (Slot), Base + 16, Date);
                           Write_U16 (FS.Cache (Slot), Base + 14, Time);
                           Write_U16 (FS.Cache (Slot), Base + 24, Date);
                           Write_U16 (FS.Cache (Slot), Base + 22, Time);
                        end;
                     end if;
                     FS.Files (Id).Operation.Create.Phase := Create_Success;
                  when Failure =>
                     FS.Files (Id).Operation.Create.Phase := Create_Failure;
                  when In_Progress =>
                     return;
               end case;
            when Create_Success =>
               --  This kind of file keeps its entry's sector in the cache.
               if (FS.Files (Id).Mode and Mode_Retain_Directory) /= 0 then
                  Cache_Sector (FS, Card, FS.Files (Id).Entry_At.Sector,
                                (Read => True, Retain => True, others => False), 0, Status, Unused_Slot);
                  if Status /= Success then
                     return;
                  end if;
               end if;
               Seek (FS, Card, Id, 0, From_Start, Unused_Status);
               if FS.Files (Id).Cursor_Cluster = 0 then
                  --  A new contiguous file takes the free-space file for
                  --  itself, once nothing else holds it.
                  if (FS.Files (Id).Mode and Mode_Contiguous) /= 0 then
                     if Is_Busy (FS.Files (Free_File)) then
                        return;
                     end if;
                     FS.Files (Free_File).Operation.Kind := Locked;
                  end if;
               else
                  --  An existing file's clusters need not be contiguous.
                  FS.Files (Id).Mode := FS.Files (Id).Mode and not Mode_Contiguous;
                  if (FS.Files (Id).Mode and Mode_Append) /= 0 then
                     FS.Files (Id).Operation.Kind := Idle;
                     Seek_Forward (FS, Card, Id, FS.Files (Id).Logical_Size, Unused_Status,
                                   FS.Files (Id).Operation.Callback);
                     return;
                  end if;
                  if FS.Files (Id).Mode = (Mode_Create or Mode_Write) then
                     FS.Files (Id).Operation.Kind := Idle;
                     Truncate (FS, Card, Id, FS.Files (Id).Operation.Callback, Unused_Queued);
                     return;
                  end if;
               end if;
               FS.Files (Id).Operation.Kind := Idle;
               Notify (FS, FS.Files (Id).Operation.Callback, File_Ref (Id));
               return;
            when Create_Failure =>
               FS.Files (Id).Kind := Unused;
               Notify (FS, FS.Files (Id).Operation.Callback, No_File);
               return;
         end case;
      end loop;
   end Create_File_Continue;

   -----------------
   -- Create_File --
   -----------------

   procedure Create_File
     (FS       : in out File_System;
      Card     : in out Card_State;
      Id       : File_Id;
      Name     : String;
      Attrib   : Unsigned_8;
      Mode     : Unsigned_8;
      Callback : Callback_Tag)
   is
   begin
      FS.Files (Id) := Fresh_Handle;
      FS.Files (Id).Operation.Kind := Create_File;
      FS.Files (Id).Mode := Mode;
      if Name = "." then
         --  The working directory opened again: its entry is known.
         FS.Files (Id).First_Cluster := FS.Files (Current_Directory).First_Cluster;
         FS.Files (Id).Physical_Size := FS.Files (Current_Directory).Physical_Size;
         FS.Files (Id).Logical_Size := FS.Files (Current_Directory).Logical_Size;
         FS.Files (Id).Attrib := FS.Files (Current_Directory).Attrib;
         FS.Files (Id).Kind := FS.Files (Current_Directory).Kind;
      else
         FS.Files (Id).Operation.Create.Name := To_FAT_Name (Name);
         FS.Files (Id).Attrib := Attrib;
         FS.Files (Id).Kind := (if (Attrib and Attribute_Directory) /= 0 then Directory else Normal);
      end if;
      FS.Files (Id).Operation.Callback := Callback;
      FS.Files (Id).Operation.Create.Phase := (if Name = "." then Create_Success else Create_Start);
      Create_File_Continue (FS, Card, Id);
   end Create_File;

   --------------------
   -- Close_Continue --
   --------------------

   procedure Close_Continue (FS : in out File_System; Card : in out Card_State; Id : File_Id) is
      Status : Operation_Status;
      Slot   : Cache_Slot;
   begin
      --  Directories and files opened only for reading keep their entries.
      if FS.Files (Id).Kind not in Directory | FAT16_Root
        and then (FS.Files (Id).Mode and (Mode_Append or Mode_Write)) /= 0
      then
         Save_Directory_Entry (FS, Card, Id, Save_For_Close, Status);
         if Status /= Success then
            return;
         end if;
      end if;
      if (FS.Files (Id).Mode and Mode_Retain_Directory) /= 0 then
         Slot := Find_Cache_Sector (FS, FS.Files (Id).Entry_At.Sector);
         if Slot /= No_Slot then
            Release_Sector (FS, Slot);
         end if;
      end if;
      Unlock_File_Sector (FS, Id);
      if (FS.Files (Id).Mode and Mode_Contiguous) /= 0 then
         Check (FS, FS.Files (Free_File).Operation.Kind = Locked);
         FS.Files (Free_File).Operation.Kind := Idle;
      end if;
      FS.Files (Id).Kind := Unused;
      FS.Files (Id).Operation.Kind := Idle;
      Notify (FS, FS.Files (Id).Operation.Close_Callback, No_File);
   end Close_Continue;

   -----------
   -- Close --
   -----------

   procedure Close
     (FS : in out File_System; Card : in out Card_State; Ref : File_Ref; Callback : Callback_Tag; Queued : out Boolean)
   is
   begin
      if Ref = No_File then
         Queued := True;
         return;
      end if;
      declare
         Id : constant File_Id := File_Id (Ref);
      begin
         if FS.Files (Id).Kind = Unused then
            Queued := True;
         elsif Is_Busy (FS.Files (Id)) then
            Queued := False;
         else
            Update_File_Size (FS.Files (Id));
            FS.Files (Id).Operation.Kind := Close;
            FS.Files (Id).Operation.Close_Callback := Callback;
            Close_Continue (FS, Card, Id);
            Queued := True;
         end if;
      end;
   end Close;

   ---------------------
   -- Unlink_Continue --
   ---------------------

   procedure Unlink_Continue (FS : in out File_System; Card : in out Card_State; Id : File_Id) is
      Status        : Operation_Status;
      Unused_Queued : Boolean;
   begin
      Truncate_Continue (FS, Card, Id, True, Status);
      if Status = Success then
         FS.Files (Id).Operation.Kind := Idle;
         Close (FS, Card, File_Ref (Id), FS.Files (Id).Operation.Unlink_Callback, Unused_Queued);
      end if;
   end Unlink_Continue;

   ------------
   -- Unlink --
   ------------

   procedure Unlink
     (FS : in out File_System; Card : in out Card_State; Ref : File_Ref; Callback : Callback_Tag; Queued : out Boolean)
   is
   begin
      if Ref = No_File then
         Queued := True;
         return;
      end if;
      declare
         Id : constant File_Id := File_Id (Ref);
      begin
         if FS.Files (Id).Kind = Unused then
            Queued := True;
            return;
         end if;
         --  A delete is a truncation with the entry marked, then a close.
         Truncate (FS, Card, Id, No_Callback, Queued);
         if Queued then
            FS.Files (Id).Operation.Unlink_Callback := Callback;
            FS.Files (Id).Operation.Kind := Unlink;
         end if;
      end;
   end Unlink;

   --------------------
   -- Make_Directory --
   --------------------

   procedure Make_Directory
     (FS : in out File_System; Card : in out Card_State; Name : String; Callback : Callback_Tag; Started : out Boolean)
   is
      Ref : constant File_Ref := Free_Handle (FS);
   begin
      if Ref /= No_File then
         Create_File (FS, Card, File_Id (Ref), Name, Attribute_Directory, Mode_Create or Mode_Read or Mode_Write,
                      Callback);
      else
         Notify (FS, Callback, No_File);
      end if;
      Started := Ref /= No_File;
   end Make_Directory;

   ----------------------
   -- Change_Directory --
   ----------------------

   procedure Change_Directory (FS : in out File_System; Card : in out Card_State; Ref : File_Ref; Done : out Boolean) is
      Unused_Status : Operation_Status;
   begin
      if Is_Busy (FS.Files (Current_Directory)) then
         Done := False;
      elsif Ref /= No_File then
         if Is_Busy (FS.Files (File_Id (Ref))) then
            Done := False;
         else
            FS.Files (Current_Directory) := FS.Files (File_Id (Ref));
            Done := True;
         end if;
      else
         --  The root directory, which has no entry of its own.
         FS.Files (Current_Directory) := Fresh_Handle;
         FS.Files (Current_Directory).Mode := Mode_Read or Mode_Write;
         FS.Files (Current_Directory).Kind := (if FS.Vol.FS_Type = FAT16 then FAT16_Root else Directory);
         FS.Files (Current_Directory).First_Cluster := FS.Vol.Root_Directory_Cluster;
         FS.Files (Current_Directory).Attrib := Attribute_Directory;
         FS.Files (Current_Directory).Entry_At.Sector := 0;
         Seek (FS, Card, Current_Directory, 0, From_Start, Unused_Status);
         Done := True;
      end if;
   end Change_Directory;

   ----------
   -- Open --
   ----------

   procedure Open
     (FS       : in out File_System;
      Card     : in out Card_State;
      Name     : String;
      Mode     : String;
      Callback : Callback_Tag;
      Started  : out Boolean)
   is
      First  : constant Character := (if Mode'Length >= 1 then Mode (Mode'First) else ASCII.NUL);
      Second : constant Character := (if Mode'Length >= 2 then Mode (Mode'First + 1) else ASCII.NUL);
      Bits   : Unsigned_8 := 0;
      Ref    : File_Ref;
   begin
      case First is
         when 'r' =>
            Bits := Mode_Read;
         when 'w' =>
            Bits := Mode_Write or Mode_Create;
         when 'a' =>
            Bits := Mode_Append or Mode_Create;
         when others =>
            null;
      end case;
      case Second is
         when '+' =>
            Bits := Bits or Mode_Read;
            if Bits = Mode_Read then
               Bits := Bits or Mode_Write;
            end if;
         when 's' =>
            Bits := Bits or Mode_Contiguous or Mode_Retain_Directory;
         when others =>
            null;
      end case;
      Ref := Free_Handle (FS);
      if Ref /= No_File then
         Create_File (FS, Card, File_Id (Ref), Name, Attribute_Archive, Bits, Callback);
      else
         Notify (FS, Callback, No_File);
      end if;
      Started := Ref /= No_File;
   end Open;

   ------------------------
   -- Operation_Continue --
   ------------------------

   procedure Operation_Continue (FS : in out File_System; Card : in out Card_State; Id : File_Id) is
      Unused_Done   : Boolean;
      Unused_Status : Operation_Status;
   begin
      if FS.Files (Id).Kind = Unused then
         return;
      end if;
      case FS.Files (Id).Operation.Kind is
         when Create_File =>
            Create_File_Continue (FS, Card, Id);
         when Seek =>
            Seek_Continue (FS, Card, Id, Unused_Done);
         when Close =>
            Close_Continue (FS, Card, Id);
         when Unlink =>
            Unlink_Continue (FS, Card, Id);
         when Truncate =>
            Truncate_Continue (FS, Card, Id, False, Unused_Status);
         when Append_Supercluster =>
            Append_Supercluster_Continue (FS, Card, Id, Unused_Status);
         when Append_Free_Cluster =>
            Append_Free_Cluster_Continue (FS, Card, Id, Unused_Status);
         when Extend_Subdirectory =>
            Extend_Subdirectory_Continue (FS, Card, Id, Unused_Status);
         when Locked | Idle =>
            null;
      end case;
   end Operation_Continue;

   ---------------------
   -- Operations_Poll --
   ---------------------

   procedure Operations_Poll (FS : in out File_System; Card : in out Card_State) is
   begin
      Operation_Continue (FS, Card, Current_Directory);
      for Id in Open_File loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         Operation_Continue (FS, Card, Id);
      end loop;
   end Operations_Poll;

   --------------------------------
   -- Free_Space_Search_Continue --
   --------------------------------

   procedure Free_Space_Search_Continue
     (FS : in out File_System; Card : in out Card_State; Status : out Operation_Status)
   is
      Per_Sector   : constant Unsigned_32 := FAT_Entries_Per_Sector (FS.Vol);
      Found_Status : Find_Status;
      Limit        : Unsigned_32;
      Position     : Unsigned_32;
   begin
      loop
         pragma Loop_Invariant (FS.Vol = FS.Vol'Loop_Entry);
         case FS.Search.Phase is
            when Find_Hole =>
               Position := FS.Search.Candidate_Start;
               Find_Cluster (FS, Card, Free_At_Sector_Start, Position, FS.Vol.Num_Clusters + Smallest_Cluster,
                             Found_Status);
               FS.Search.Candidate_Start := Position;
               case Found_Status is
                  when Found =>
                     FS.Search.Candidate_End := FS.Search.Candidate_Start + 1;
                     FS.Search.Phase := Grow_Hole;
                  when Find_Fatal =>
                     Status := Failure;
                     return;
                  when Not_Found =>
                     Status := Success;
                     return;
                  when Find_In_Progress =>
                     Status := In_Progress;
                     return;
               end case;
            when Grow_Hole =>
               --  The hole ends at the next taken cluster, the volume's end,
               --  or the largest file size.
               Limit := Unsigned_32
                 (Interfaces.Unsigned_64'Min
                    (Interfaces.Unsigned_64 (FS.Search.Candidate_Start)
                     + Interfaces.Unsigned_64 (Divide (Maximum_File_Size, Cluster_Size (FS.Vol))),
                     Interfaces.Unsigned_64 (FS.Vol.Num_Clusters + Smallest_Cluster)));
               Position := FS.Search.Candidate_End;
               Find_Cluster (FS, Card, Taken_Cluster, Position, Limit, Found_Status);
               FS.Search.Candidate_End := Position;
               case Found_Status is
                  when Found | Not_Found =>
                     if FS.Search.Candidate_End - FS.Search.Candidate_Start > FS.Search.Best_Gap_Length then
                        FS.Search.Best_Gap_Start := FS.Search.Candidate_Start;
                        FS.Search.Best_Gap_Length := FS.Search.Candidate_End - FS.Search.Candidate_Start;
                     end if;
                     if Found_Status = Not_Found then
                        Status := Success;
                        return;
                     end if;
                     FS.Search.Candidate_Start := Round_Up_To (FS.Search.Candidate_End + 1, Per_Sector);
                     FS.Search.Phase := Find_Hole;
                  when Find_Fatal =>
                     Status := Failure;
                     return;
                  when Find_In_Progress =>
                     Status := In_Progress;
                     return;
               end case;
         end case;
      end loop;
   end Free_Space_Search_Continue;

   -------------------
   -- Init_Continue --
   -------------------

   procedure Init_Continue (FS : in out File_System; Card : in out Card_State) is
      Status         : Operation_Status;
      Slot           : Cache_Slot;
      Found          : Boolean;
      Unused_Changed : Boolean;
   begin
      loop
         case FS.Phase is
            when Read_MBR =>
               Cache_Sector (FS, Card, 0, (Read => True, Discardable => True, others => False), 0, Status, Slot);
               exit when Status /= Success;
               Parse_MBR (FS.Cache (Slot), FS.Vol, Found);
               if not Found then
                  FS.Last_Error := Bad_MBR;
                  FS.State := Fatal;
                  exit;
               end if;
               FS.Phase := Read_Volume_ID;
            when Read_Volume_ID =>
               Cache_Sector (FS, Card, FS.Vol.Partition_Start_Sector,
                             (Read => True, Discardable => True, others => False), 0, Status, Slot);
               if Status = Success then
                  Parse_Volume_ID (FS.Cache (Slot), FS.Vol, Found);
                  if Found then
                     Change_Directory (FS, Card, No_File, Unused_Changed);
                     FS.Phase := Free_File_Create;
                  else
                     FS.Last_Error := Bad_Filesystem_Header;
                     FS.State := Fatal;
                  end if;
               end if;
               exit;
            when Free_File_Create =>
               FS.Phase := Free_File_Creating;
               Create_File (FS, Card, Free_File, "FREESPAC.E", Attribute_System or Attribute_Read_Only,
                            Mode_Create or Mode_Retain_Directory, Free_File_Created);
               exit;
            when Free_File_Creating =>
               Operation_Continue (FS, Card, Free_File);
               exit;
            when Free_File_FAT_Search =>
               Free_Space_Search_Continue (FS, Card, Status);
               exit when Status /= Success;
               --  An empty free-space file only needs its entry saved.
               FS.Phase := Free_File_Save_Entry;
               if FS.Search.Best_Gap_Length > Free_File_Leave_Clusters + 1 then
                  FS.Search.Best_Gap_Length := FS.Search.Best_Gap_Length - Free_File_Leave_Clusters;
                  --  A size of one more than whole superclusters, so the file
                  --  never empties.
                  FS.Search.Best_Gap_Length :=
                    ((FS.Search.Best_Gap_Length - 1) and not (FAT_Entries_Per_Sector (FS.Vol) - 1)) + 1;
                  if FS.Search.Best_Gap_Length > FAT_Entries_Per_Sector (FS.Vol) then
                     declare
                        Start  : constant Unsigned_32 := FS.Search.Best_Gap_Start;
                        Finish : constant Unsigned_32 := FS.Search.Best_Gap_Start + FS.Search.Best_Gap_Length;
                     begin
                        Check (FS, Finish < FS.Vol.Num_Clusters + Smallest_Cluster);
                        --  The fill's range takes the place of the candidate.
                        FS.Search.Candidate_Start := Start;
                        FS.Search.Candidate_End := Finish;
                        FS.Files (Free_File).First_Cluster := Start;
                        FS.Files (Free_File).Logical_Size := FS.Search.Best_Gap_Length * Cluster_Size (FS.Vol);
                        FS.Files (Free_File).Physical_Size := FS.Files (Free_File).Logical_Size;
                        FS.Phase := Free_File_Update_FAT;
                     end;
                  end if;
               end if;
            when Free_File_Update_FAT =>
               declare
                  Start : Unsigned_32 := FS.Search.Candidate_Start;
               begin
                  FAT_Fill (FS, Card, Closed_Chain, Start, FS.Search.Candidate_End, Status);
                  FS.Search.Candidate_Start := Start;
               end;
               if Status = Failure then
                  FS.Last_Error := Generic_Error;
                  FS.State := Fatal;
               end if;
               exit when Status /= Success;
               FS.Phase := Free_File_Save_Entry;
            when Free_File_Save_Entry =>
               Save_Directory_Entry (FS, Card, Free_File, Save_Normal, Status);
               if Status = Failure then
                  FS.Last_Error := Generic_Error;
                  FS.State := Fatal;
               end if;
               exit when Status /= Success;
               FS.Phase := Init_Done;
            when Init_Done =>
               FS.State := Ready;
               exit;
         end case;
      end loop;
   end Init_Continue;

   ----------
   -- Poll --
   ----------

   procedure Poll (FS : in out File_System; Card : in out Card_State; Card_Ready : Boolean) is
      Unused_Done : Boolean;
   begin
      if Card_Ready then
         Flush (FS, Card, Unused_Done);
         case FS.State is
            when Initialization =>
               Init_Continue (FS, Card);
            when Ready =>
               Operations_Poll (FS, Card);
            when Unknown | Fatal =>
               null;
         end case;
      end if;
   end Poll;

   -------------
   -- Destroy --
   -------------

   procedure Destroy
     (FS : in out File_System; Card : in out Card_State; Dirty : Boolean; Card_Ready : Boolean; Done : out Boolean)
   is
      Open          : Natural := 0;
      Flushed       : Boolean;
      Unused_Queued : Boolean;
   begin
      if not Dirty and then FS.State = Ready then
         --  Each close may not end at once, so each open file counts.
         for Id in File_Id loop
            if FS.Files (Id).Kind /= Unused then
               Close (FS, Card, File_Ref (Id), No_Callback, Unused_Queued);
               Open := Open + 1;
            end if;
            pragma Loop_Invariant (Open <= Natural (Id) + 1);
         end loop;
         Poll (FS, Card, Card_Ready);
         Flush (FS, Card, Flushed);
         if not Flushed or else FS.Flush_In_Progress or else Open > 0 then
            Done := False;
            return;
         end if;
      end if;
      declare
         Notices : constant Notice_List := FS.Notices;
         Count   : constant Natural := FS.Notice_Count;
      begin
         FS := (others => <>);
         FS.Notices := Notices;
         FS.Notice_Count := Count;
      end;
      Done := True;
   end Destroy;

end Adaflight.FAT_FS;
