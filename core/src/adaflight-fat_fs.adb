package body Adaflight.FAT_FS with SPARK_Mode is
   use type Unsigned_16;
   use type Unsigned_32;
   use type Integer_32;

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

end Adaflight.FAT_FS;
