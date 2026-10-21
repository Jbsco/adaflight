--  The FAT file system's operations that call the card: a sector cached for
--  a read, a write, a lock or a retain, the flush of the dirty sector written
--  first, and the reads and writes of FAT entries. The card comes in as the
--  instantiation's state and procedures: a read the card accepts or refuses,
--  a write with the card's answer, and the start of a run of writes the card
--  may erase ahead of. The card ends an accepted read or write later, through
--  Adaflight.FAT.Read_Complete and Write_Complete.
with Adaflight.FAT; use Adaflight.FAT;

generic
   type Card_State is private;
   with procedure Read_Block
     (Card : in out Card_State; Sector : Unsigned_32; Buffer : Cache_Index; Accepted : out Boolean);
   with procedure Write_Block
     (Card   : in out Card_State;
      Sector : Unsigned_32;
      Buffer : Cache_Index;
      Data   : Sector_Bytes;
      Status : out Card_Status);
   with procedure Begin_Write_Blocks (Card : in out Card_State; Sector : Unsigned_32; Count : Unsigned_16);
package Adaflight.FAT_FS with SPARK_Mode is

   --  A write of a dirty sector to the card, after the start of a run of
   --  writes when the sector heads one.
   procedure Flush_Sector (FS : in out File_System; Card : in out Card_State; Index : Cache_Index)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The flush of the unlocked dirty sector written first; Done when no
   --  such sector is left.
   procedure Flush (FS : in out File_System; Card : in out Card_State; Done : out Boolean)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  A sector in the cache for the flags: read from the card first when
   --  asked and not yet there, marked dirty for a write, locked, retained.
   --  In progress while the card reads or the cache has no room; a failure
   --  for a write to the partition table.
   procedure Cache_Sector
     (FS          : in out File_System;
      Card        : in out Card_State;
      Sector      : Unsigned_32;
      Flags       : Cache_Flags;
      Erase_Count : Unsigned_32;
      Status      : out Operation_Status;
      Buffer      : out Cache_Slot)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old and then (Status = Success) = (Buffer /= No_Slot);

   --  The cluster after Cluster in a FAT, when the FAT sector is cached.
   procedure FAT_Get_Next_Cluster
     (FS      : in out File_System;
      Card    : in out Card_State;
      FAT     : FAT_Number;
      Cluster : Unsigned_32;
      Status  : out Operation_Status;
      Next    : in out Unsigned_32)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The entry of Start in the first FAT set to Next, the whole word on
   --  FAT32 and its low half on FAT16.
   procedure FAT_Set_Next_Cluster
     (FS     : in out File_System;
      Card   : in out Card_State;
      Start  : Unsigned_32;
      Next   : Unsigned_32;
      Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --------------
   -- Clusters --
   --------------

   --  From Cluster on, the first cluster below Limit that is free, free at
   --  the start of its FAT sector, or taken. The search skips the
   --  free-space file's clusters; Cluster stays where it is while the card
   --  reads, and ends at Limit when nothing is found.
   procedure Find_Cluster
     (FS        : in out File_System;
      Card      : in out Card_State;
      Condition : Search_Condition;
      Cluster   : in out Unsigned_32;
      Limit     : Unsigned_32;
      Status    : out Find_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The cluster after Current in a file: the next one for a contiguous
   --  file, up to the free-space file's start, else from the FAT.
   procedure File_Next_Cluster
     (FS      : in out File_System;
      Card    : in out Card_State;
      Id      : File_Id;
      Current : Unsigned_32;
      Next    : in out Unsigned_32;
      Status  : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The FAT entries of Start up to Finish chained in order, chained and
   --  ended, or freed, with Start where the fill stopped.
   procedure FAT_Fill
     (FS      : in out File_System;
      Card    : in out Card_State;
      Pattern : FAT_Pattern;
      Start   : in out Unsigned_32;
      Finish  : Unsigned_32;
      Status  : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  A file's directory entry: its size (the size of its clusters while
   --  open, the size written on close or delete), the deleted mark, and its
   --  first cluster. Root directories have no entry.
   procedure Save_Directory_Entry
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Mode : Save_Mode; Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  One more free cluster on a file, found from the last one allocated,
   --  ended in the FAT and linked after the file's last cluster. A volume
   --  with no free cluster left is full.
   procedure Append_Free_Cluster_Continue
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   procedure Append_Regular_Free_Cluster
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The free-space file's first supercluster moved to the end of a
   --  contiguous file: the free-space file's entry first, then the FAT, then
   --  the file's entry. A free-space file shorter than a supercluster leaves
   --  the volume full.
   procedure Append_Supercluster_Continue
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   procedure Append_Supercluster
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   procedure Append_Cluster
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   ------------
   -- Cursor --
   ------------

   --  The sector under the cursor retained for a read, or none at the end
   --  of the file's clusters or while the card reads.
   procedure Retain_Cursor_Sector
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Slot : out Cache_Slot)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The sector under the cursor locked for a write, after a cluster is
   --  appended at the end of the file's clusters, read first when the write
   --  leaves some of it, and with the rest of the supercluster to erase
   --  ahead for a contiguous file that appends.
   procedure Lock_Cursor_Sector
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Slot : out Cache_Slot)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  A move of the cursor within its sector, or up to a cluster forward,
   --  or back within its cluster, that waits for at most one FAT read.
   procedure Seek_Atomic
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Offset : Integer_32; Done : out Boolean)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   procedure Seek_Continue (FS : in out File_System; Card : in out Card_State; Id : File_Id; Done : out Boolean)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The cursor moved forward by Offset, or the move queued on the file.
   procedure Seek_Forward
     (FS     : in out File_System;
      Card   : in out Card_State;
      Id     : File_Id;
      Offset : Unsigned_32;
      Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The cursor moved as a C seek moves it, up to the end of the file.
   procedure Seek
     (FS     : in out File_System;
      Card   : in out Card_State;
      Id     : File_Id;
      Offset : Integer_32;
      Origin : Seek_Origin;
      Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  A byte at the cursor, straight into the locked sector when it does
   --  not end the sector.
   procedure Put_Byte (FS : in out File_System; Card : in out Card_State; Id : File_Id; Value : Unsigned_8)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The bytes written from the cursor, sector by sector, until the cache
   --  or the card makes a sector wait.
   procedure Write
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Data : Data_Bytes; Written : out Natural)
     with Global => null,
          Pre    => Data'Length <= Max_Transfer,
          Post   => FS.Vol = FS.Vol'Old and then Written <= Data'Length;

   --  The bytes read from the cursor up to the end of the file, sector by
   --  sector, into the start of Data.
   procedure Read
     (FS : in out File_System; Card : in out Card_State; Id : File_Id; Data : in out Data_Bytes; Count : out Natural)
     with Global => null,
          Pre    => Data'Length <= Max_Transfer,
          Post   => FS.Vol = FS.Vol'Old and then Count <= Data'Length;

   --  The operation queued on a file, carried on.
   procedure Operation_Continue (FS : in out File_System; Card : in out Card_State; Id : File_Id)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The working directory's and the open files' operations, carried on.
   procedure Operations_Poll (FS : in out File_System; Card : in out Card_State)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The free-space search carried on, done when the volume's end is
   --  reached, failed on a fatal read.
   procedure Free_Space_Search_Continue
     (FS : in out File_System; Card : in out Card_State; Status : out Operation_Status)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

end Adaflight.FAT_FS;
