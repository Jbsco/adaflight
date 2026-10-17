package body Adaflight.FAT with SPARK_Mode is

   ---------------
   -- Write_U16 --
   ---------------

   procedure Write_U16 (S : in out Sector_Bytes; At_Byte : Sector_Offset; Value : Unsigned_16) is
   begin
      S (At_Byte) := Unsigned_8 (Value and 16#FF#);
      S (At_Byte + 1) := Unsigned_8 (Interfaces.Shift_Right (Value, 8));
   end Write_U16;

   ---------------
   -- Write_U32 --
   ---------------

   procedure Write_U32 (S : in out Sector_Bytes; At_Byte : Sector_Offset; Value : Unsigned_32) is
   begin
      for K in 0 .. 3 loop
         S (At_Byte + K) := Unsigned_8 (Interfaces.Shift_Right (Value, 8 * K) and 16#FF#);
      end loop;
   end Write_U32;

   -----------------
   -- To_FAT_Name --
   -----------------

   function To_FAT_Name (Name : String) return FAT_Name is
      Result : FAT_Name := (others => Character'Pos (' '));
      Used   : Natural := 0;

      function Upper (C : Character) return Unsigned_8 is
        (if C in 'a' .. 'z' then Unsigned_8 (Character'Pos (C) - 32) else Unsigned_8 (Character'Pos (C)));
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Used <= I);
         if Used < Name'Length and then Name (Name'First + Used) not in ASCII.NUL | '.' then
            Result (I) := Upper (Name (Name'First + Used));
            Used := Used + 1;
         end if;
      end loop;
      if Used < Name'Length and then Name (Name'First + Used) = '.' then
         Used := Used + 1;
      end if;
      for I in 8 .. 10 loop
         pragma Loop_Invariant (Used <= I + 1);
         if Used < Name'Length and then Name (Name'First + Used) /= ASCII.NUL then
            Result (I) := Upper (Name (Name'First + Used));
            Used := Used + 1;
         end if;
      end loop;
      return Result;
   end To_FAT_Name;

   ------------------
   -- FAT_Position --
   ------------------

   procedure FAT_Position
     (V : Volume; Cluster : Unsigned_32; FAT_Sector : out Unsigned_32; Entry_Index : out Unsigned_32)
   is
   begin
      if V.FS_Type = FAT16 then
         FAT_Sector := Cluster / FAT16_Entries_Per_Sector;
         Entry_Index := Cluster and (FAT16_Entries_Per_Sector - 1);
      else
         FAT_Sector := Decode_Cluster (Cluster) / FAT32_Entries_Per_Sector;
         Entry_Index := Cluster and (FAT32_Entries_Per_Sector - 1);
      end if;
   end FAT_Position;

   ---------------
   -- Parse_MBR --
   ---------------

   procedure Parse_MBR (Sector : Sector_Bytes; V : in out Volume; Found : out Boolean) is
   begin
      Found := False;
      if Sector (510) /= 16#55# or else Sector (511) /= 16#AA# then
         return;
      end if;
      for I in 0 .. 3 loop
         declare
            Base  : constant Sector_Offset := 446 + 16 * I;
            Start : constant Unsigned_32 := Read_U32 (Sector, Base + 8);
         begin
            if Start > 0 and then Sector (Base + 4) in 16#06# | 16#0B# | 16#0C# | 16#0E# then
               V.Partition_Start_Sector := Start;
               Found := True;
               return;
            end if;
         end;
      end loop;
   end Parse_MBR;

   ---------------------
   -- Parse_Volume_ID --
   ---------------------

   procedure Parse_Volume_ID (Sector : Sector_Bytes; V : in out Volume; Valid : out Boolean) is
      Reserved     : constant Unsigned_32 := Unsigned_32 (Read_U16 (Sector, 14));
      Root_Entries : constant Unsigned_32 := Unsigned_32 (Read_U16 (Sector, 17));
      Total_16     : constant Unsigned_16 := Read_U16 (Sector, 19);
      FAT_Size_16  : constant Unsigned_16 := Read_U16 (Sector, 22);
      Total        : Unsigned_32;
   begin
      V.FS_Type := Invalid;
      Valid := False;
      if Read_U16 (Sector, 11) /= Sector_Size or else Sector (16) /= FAT_Count
        or else Sector (510) /= 16#55# or else Sector (511) /= 16#AA#
      then
         return;
      end if;
      V.FAT_Start_Sector := V.Partition_Start_Sector + Reserved;
      V.Sectors_Per_Cluster := Unsigned_32 (Sector (13));
      if V.Sectors_Per_Cluster < 1 or else V.Sectors_Per_Cluster > 128
        or else not Is_Power_Of_Two (V.Sectors_Per_Cluster)
      then
         return;
      end if;
      V.Byte_In_Cluster_Mask := Sector_Size * V.Sectors_Per_Cluster - 1;
      V.FAT_Sectors := (if FAT_Size_16 /= 0 then Unsigned_32 (FAT_Size_16) else Read_U32 (Sector, 36));
      V.Root_Directory_Sectors := (Root_Entries * Directory_Entry_Size + (Sector_Size - 1)) / Sector_Size;
      Total := (if Total_16 /= 0 then Unsigned_32 (Total_16) else Read_U32 (Sector, 32));
      V.Num_Clusters :=
        (Total - (Reserved + FAT_Count * V.FAT_Sectors + V.Root_Directory_Sectors)) / V.Sectors_Per_Cluster;
      if V.Num_Clusters <= FAT12_Max_Clusters then
         V.FS_Type := FAT12;
         return;
      elsif V.Num_Clusters <= FAT16_Max_Clusters then
         V.FS_Type := FAT16;
      else
         V.FS_Type := FAT32;
      end if;
      V.Root_Directory_Cluster := (if V.FS_Type = FAT32 then Read_U32 (Sector, 44) else 0);
      V.Cluster_Start_Sector := V.FAT_Start_Sector + FAT_Count * V.FAT_Sectors + V.Root_Directory_Sectors;
      Valid := True;
   end Parse_Volume_ID;

   ----------
   -- Init --
   ----------

   procedure Init (FS : out File_System) is
   begin
      FS := (State => Initialization, Last_Cluster_Allocated => Smallest_Cluster, others => <>);
   end Init;

   -----------
   -- Check --
   -----------

   procedure Check (FS : in out File_System; Condition : Boolean) is
   begin
      if not Condition then
         if FS.Last_Error = None then
            FS.Last_Error := Generic_Error;
         end if;
         FS.State := Fatal;
      end if;
   end Check;

   ---------------
   -- Add_Dirty --
   ---------------

   procedure Add_Dirty (FS : in out File_System) is
   begin
      if FS.Dirty_Entries < Integer_32'Last then
         FS.Dirty_Entries := FS.Dirty_Entries + 1;
      end if;
   end Add_Dirty;

   ------------------
   -- Remove_Dirty --
   ------------------

   procedure Remove_Dirty (FS : in out File_System) is
   begin
      if FS.Dirty_Entries > Integer_32'First then
         FS.Dirty_Entries := FS.Dirty_Entries - 1;
      end if;
   end Remove_Dirty;

   ----------------
   -- Mark_Dirty --
   ----------------

   procedure Mark_Dirty (FS : in out File_System; Index : Cache_Index) is
   begin
      if FS.Descriptors (Index).State /= Dirty then
         FS.Cache_Timer := FS.Cache_Timer + 1;
         FS.Descriptors (Index).Write_Timestamp := FS.Cache_Timer;
         FS.Descriptors (Index).State := Dirty;
         Add_Dirty (FS);
      end if;
   end Mark_Dirty;

   -----------------
   -- Init_Sector --
   -----------------

   procedure Init_Sector (FS : in out File_System; Index : Cache_Index; Sector : Unsigned_32; Locked : Boolean) is
   begin
      FS.Cache_Timer := FS.Cache_Timer + 1;
      FS.Descriptors (Index) := (Sector_Index     => Sector,
                                 Write_Timestamp  => FS.Cache_Timer,
                                 Access_Timestamp => FS.Cache_Timer,
                                 Erase_Count      => 0,
                                 State            => Empty,
                                 Locked           => Locked,
                                 Retained         => 0,
                                 Discardable      => False);
   end Init_Sector;

   -------------------
   -- Read_Complete --
   -------------------

   procedure Read_Complete
     (FS : in out File_System; Buffer : Cache_Index; Sector : Unsigned_32; Data : Sector_Bytes; Succeeded : Boolean)
   is
   begin
      if Succeeded then
         FS.Cache (Buffer) := Data;
      end if;
      for I in Cache_Index loop
         if FS.Descriptors (I).State /= Empty and then FS.Descriptors (I).Sector_Index = Sector then
            if Succeeded then
               Check (FS, I = Buffer and then FS.Descriptors (I).State = Reading);
               FS.Descriptors (I).State := In_Sync;
            else
               FS.Descriptors (I).State := Empty;
            end if;
            exit;
         end if;
      end loop;
   end Read_Complete;

   --------------------
   -- Write_Complete --
   --------------------

   procedure Write_Complete (FS : in out File_System; Buffer : Cache_Index; Sector : Unsigned_32; Succeeded : Boolean)
   is
   begin
      FS.Flush_In_Progress := False;
      for I in Cache_Index loop
         if FS.Descriptors (I).Sector_Index = Sector and then FS.Descriptors (I).State = Writing then
            if Succeeded then
               Check (FS, I = Buffer);
               FS.Descriptors (I).State := In_Sync;
            else
               FS.Descriptors (I).State := Dirty;
               Add_Dirty (FS);
            end if;
            exit;
         end if;
      end loop;
   end Write_Complete;

   -----------------------
   -- Find_Cache_Sector --
   -----------------------

   function Find_Cache_Sector (FS : File_System; Sector : Unsigned_32) return Cache_Slot is
   begin
      for I in Cache_Index loop
         if FS.Descriptors (I).Sector_Index = Sector then
            return I;
         end if;
      end loop;
      return No_Slot;
   end Find_Cache_Sector;

   ---------------------------
   -- Allocate_Cache_Sector --
   ---------------------------

   procedure Allocate_Cache_Sector (FS : in out File_System; Sector : Unsigned_32; Slot : out Cache_Slot) is
      In_Volume         : constant Boolean :=
        FS.Vol.Num_Clusters = 0
        or else Sector < FS.Vol.Cluster_Start_Sector + FS.Vol.Num_Clusters * FS.Vol.Sectors_Per_Cluster;
      Empty_Index       : Cache_Slot := No_Slot;
      Discardable_Index : Cache_Slot := No_Slot;
      Oldest_Use        : Unsigned_32 := Unsigned_32'Last;
      Oldest_Index      : Cache_Slot := No_Slot;
   begin
      Check (FS, In_Volume);
      if not In_Volume then
         Slot := No_Slot;
         return;
      end if;
      for I in Cache_Index loop
         if FS.Descriptors (I).Sector_Index = Sector then
            --  An empty entry that held the sector is set up afresh.
            if FS.Descriptors (I).State = Empty then
               Empty_Index := I;
               exit;
            end if;
            FS.Cache_Timer := FS.Cache_Timer + 1;
            FS.Descriptors (I).Access_Timestamp := FS.Cache_Timer;
            Slot := I;
            return;
         end if;
         case FS.Descriptors (I).State is
            when Empty =>
               Empty_Index := I;
            when In_Sync =>
               if not FS.Descriptors (I).Locked and then FS.Descriptors (I).Retained = 0 then
                  if FS.Descriptors (I).Discardable then
                     Discardable_Index := I;
                  elsif FS.Descriptors (I).Access_Timestamp < Oldest_Use then
                     Oldest_Use := FS.Descriptors (I).Access_Timestamp;
                     Oldest_Index := I;
                  end if;
               end if;
            when Reading | Writing | Dirty =>
               null;
         end case;
      end loop;
      Slot := (if Empty_Index /= No_Slot then Empty_Index
               elsif Discardable_Index /= No_Slot then Discardable_Index
               else Oldest_Index);
      if Slot /= No_Slot then
         Init_Sector (FS, Slot, Sector, False);
      end if;
   end Allocate_Cache_Sector;

   -----------------------
   -- Free_Buffer_Space --
   -----------------------

   function Free_Buffer_Space (FS : File_System) return Unsigned_32 is
      Result : Unsigned_32 := 0;
   begin
      for D of FS.Descriptors loop
         if not D.Locked and then D.State in Empty | In_Sync then
            Result := Result + Sector_Size;
         end if;
      end loop;
      return Result;
   end Free_Buffer_Space;

   -------------------
   -- Unlock_Sector --
   -------------------

   procedure Unlock_Sector (FS : in out File_System; Index : Cache_Index) is
   begin
      FS.Descriptors (Index).Locked := False;
   end Unlock_Sector;

   --------------------
   -- Release_Sector --
   --------------------

   procedure Release_Sector (FS : in out File_System; Index : Cache_Index) is
   begin
      if FS.Descriptors (Index).Retained > 0 then
         FS.Descriptors (Index).Retained := FS.Descriptors (Index).Retained - 1;
      end if;
   end Release_Sector;

   ----------------------
   -- Update_File_Size --
   ----------------------

   procedure Update_File_Size (F : in out File_Handle) is
   begin
      if F.Cursor_Offset > F.Logical_Size then
         F.Logical_Size := F.Cursor_Offset;
      end if;
   end Update_File_Size;

   ------------------------
   -- Unlock_File_Sector --
   ------------------------

   procedure Unlock_File_Sector (FS : in out File_System; Id : File_Id) is
   begin
      if FS.Files (Id).Write_Locked /= No_Slot then
         Unlock_Sector (FS, FS.Files (Id).Write_Locked);
         FS.Files (Id).Write_Locked := No_Slot;
      end if;
      if FS.Files (Id).Read_Retained /= No_Slot then
         Release_Sector (FS, FS.Files (Id).Read_Retained);
         FS.Files (Id).Read_Retained := No_Slot;
      end if;
   end Unlock_File_Sector;

   ----------
   -- Tell --
   ----------

   procedure Tell (F : File_Handle; Position : in out Unsigned_32; Done : out Boolean) is
   begin
      Done := not Is_Busy (F);
      if Done then
         Position := F.Cursor_Offset;
      end if;
   end Tell;

   -----------------------------
   -- Begin_Free_Space_Search --
   -----------------------------

   procedure Begin_Free_Space_Search (FS : in out File_System) is
   begin
      --  The first FAT sector holds the two reserved entries, so the search
      --  starts at the second.
      FS.Search := (Candidate_Start => FAT_Entries_Per_Sector (FS.Vol),
                    Candidate_End   => FAT_Entries_Per_Sector (FS.Vol),
                    Best_Gap_Start  => 0,
                    Best_Gap_Length => 0,
                    Phase           => Find_Hole);
   end Begin_Free_Space_Search;

   ------------
   -- Notify --
   ------------

   procedure Notify (FS : in out File_System; Tag : Callback_Tag; File : File_Ref) is
   begin
      if Tag /= No_Callback and then FS.Notice_Count < Max_Notices then
         FS.Notice_Count := FS.Notice_Count + 1;
         FS.Notices (FS.Notice_Count) := (Tag => Tag, File => File);
      end if;
   end Notify;

   --------------------------
   -- Load_Directory_Entry --
   --------------------------

   procedure Load_Directory_Entry (FS : in out File_System; Id : File_Id; Slot : Cache_Index; Index : Entry_Slot) is
      Base : constant Sector_Offset := Natural (Index) * Directory_Entry_Size;
      Size : constant Unsigned_32 := Read_U32 (FS.Cache (Slot), Base + 28);
   begin
      FS.Files (Id).First_Cluster :=
        Interfaces.Shift_Left (Unsigned_32 (Read_U16 (FS.Cache (Slot), Base + 20)), 16)
        or Unsigned_32 (Read_U16 (FS.Cache (Slot), Base + 26));
      FS.Files (Id).Logical_Size := Size;
      --  A zero cluster size rounds to zero, as the Cortex-M divide makes it.
      FS.Files (Id).Physical_Size :=
        (if Cluster_Size (FS.Vol) = 0 then 0 else Round_Up_To (Size, Cluster_Size (FS.Vol)));
      FS.Files (Id).Attrib := FS.Cache (Slot) (Base + 11);
   end Load_Directory_Entry;

end Adaflight.FAT;
