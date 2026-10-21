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

end Adaflight.FAT_FS;
