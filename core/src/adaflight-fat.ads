--  The FAT file system of the SD card, its on-disk side and its sector
--  cache: the volume a partition table and a volume ID sector describe, the
--  FAT entries of FAT16 and FAT32 volumes, file names in their 8.3 form, and
--  the eleven cached sectors with their states, timestamps, locks and
--  retains. The card's read and write completions land here; the operations
--  that call the card are in Adaflight.FAT_FS.
with Interfaces;

package Adaflight.FAT with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   Sector_Size              : constant := 512;
   Cache_Sectors            : constant := 11;
   FAT_Count                : constant := 2;
   Directory_Entry_Size     : constant := 32;
   Smallest_Cluster         : constant := 2;
   FAT12_Max_Clusters       : constant := 4_084;
   FAT16_Max_Clusters       : constant := 65_524;
   Min_Multiple_Block_Write : constant := 4;
   Filename_Length          : constant := 11;
   Deleted_File_Marker      : constant := 16#E5#;
   FAT16_Entries_Per_Sector : constant := Sector_Size / 2;
   FAT32_Entries_Per_Sector : constant := Sector_Size / 4;

   subtype Sector_Offset is Natural range 0 .. Sector_Size - 1;
   type Sector_Bytes is array (Sector_Offset) of Unsigned_8;
   subtype Cache_Index is Natural range 0 .. Cache_Sectors - 1;
   subtype Cache_Slot is Integer range -1 .. Cache_Sectors - 1;
   No_Slot : constant Cache_Slot := -1;
   type Cache_Memory is array (Cache_Index) of Sector_Bytes;
   type FAT_Name is array (0 .. Filename_Length - 1) of Unsigned_8;
   type FAT_Number is range 0 .. 1;

   type Filesystem_Type is (Invalid, FAT12, FAT16, FAT32);
   type Filesystem_State is (Unknown, Fatal, Initialization, Ready);
   type Error_Kind is (None, Generic_Error, Bad_MBR, Bad_Filesystem_Header);
   type Operation_Status is (In_Progress, Success, Failure);
   type Card_Status is (In_Progress, Busy, Success, Failure);
   type Cache_State is (Empty, In_Sync, Reading, Writing, Dirty);
   type Retain_Count is mod 2 ** 6;

   --  What a sector is cached for: read from the card, written, locked
   --  against flushes and discards, discarded before other synced sectors,
   --  or retained while synced.
   type Cache_Flags is record
      Read        : Boolean := False;
      Write       : Boolean := False;
      Lock        : Boolean := False;
      Discardable : Boolean := False;
      Retain      : Boolean := False;
   end record;

   type Descriptor is record
      Sector_Index     : Unsigned_32 := 0;
      Write_Timestamp  : Unsigned_32 := 0;
      Access_Timestamp : Unsigned_32 := 0;
      Erase_Count      : Unsigned_16 := 0;
      State            : Cache_State := Empty;
      Locked           : Boolean := False;
      Retained         : Retain_Count := 0;
      Discardable      : Boolean := False;
   end record;
   type Descriptor_Array is array (Cache_Index) of Descriptor;

   --  The volume's layout in sectors and clusters. The cluster numbers
   --  start at 2, so the last one is Num_Clusters + 1.
   type Volume is record
      FS_Type                : Filesystem_Type := Invalid;
      Partition_Start_Sector : Unsigned_32 := 0;
      FAT_Start_Sector       : Unsigned_32 := 0;
      FAT_Sectors            : Unsigned_32 := 0;
      Num_Clusters           : Unsigned_32 := 0;
      Cluster_Start_Sector   : Unsigned_32 := 0;
      Sectors_Per_Cluster    : Unsigned_32 := 0;
      Byte_In_Cluster_Mask   : Unsigned_32 := 0;
      Root_Directory_Cluster : Unsigned_32 := 0;
      Root_Directory_Sectors : Unsigned_32 := 0;
   end record;

   type File_System is record
      Vol                    : Volume;
      State                  : Filesystem_State := Unknown;
      Last_Error             : Error_Kind := None;
      Full                   : Boolean := False;
      Last_Cluster_Allocated : Unsigned_32 := 0;
      Cache                  : Cache_Memory := (others => (others => 0));
      Descriptors            : Descriptor_Array;
      Cache_Timer            : Unsigned_32 := 0;
      Dirty_Entries          : Integer_32 := 0;
      Flush_In_Progress      : Boolean := False;
   end record;

   ---------------------
   -- On-disk helpers --
   ---------------------

   --  A FAT32 entry's cluster number: its low 28 bits.
   function Decode_Cluster (Cluster : Unsigned_32) return Unsigned_32 is (Cluster and 16#0FFF_FFFF#);

   function FAT16_End_Of_Chain (Cluster : Unsigned_16) return Boolean is (Cluster >= 16#FFF8#);

   function FAT32_End_Of_Chain (Cluster : Unsigned_32) return Boolean is (Cluster >= 16#0FFF_FFF8#);

   function Is_Free_Space (Cluster : Unsigned_32) return Boolean is (Cluster = 0);

   --  Whether a directory entry with this first name byte ends the
   --  directory, or marks a deleted file.
   function Is_Entry_Terminator (First : Unsigned_8) return Boolean is (First = 0);
   function Is_Entry_Empty (First : Unsigned_8) return Boolean is (First = Deleted_File_Marker);

   function Is_Power_Of_Two (X : Unsigned_32) return Boolean is (X /= 0 and then (X and ((not X) + 1)) = X);

   --  Little-endian fields of a sector.
   function Read_U16 (S : Sector_Bytes; At_Byte : Sector_Offset) return Unsigned_16 is
     (Unsigned_16 (S (At_Byte)) or Interfaces.Shift_Left (Unsigned_16 (S (At_Byte + 1)), 8))
   with Pre => At_Byte <= Sector_Size - 2;

   function Read_U32 (S : Sector_Bytes; At_Byte : Sector_Offset) return Unsigned_32 is
     (Unsigned_32 (S (At_Byte)) or Interfaces.Shift_Left (Unsigned_32 (S (At_Byte + 1)), 8)
      or Interfaces.Shift_Left (Unsigned_32 (S (At_Byte + 2)), 16)
      or Interfaces.Shift_Left (Unsigned_32 (S (At_Byte + 3)), 24))
   with Pre => At_Byte <= Sector_Size - 4;

   procedure Write_U16 (S : in out Sector_Bytes; At_Byte : Sector_Offset; Value : Unsigned_16)
     with Global => null,
          Pre    => At_Byte <= Sector_Size - 2;

   procedure Write_U32 (S : in out Sector_Bytes; At_Byte : Sector_Offset; Value : Unsigned_32)
     with Global => null,
          Pre    => At_Byte <= Sector_Size - 4;

   function Round_Up_To (Value : Unsigned_32; Rounding : Unsigned_32) return Unsigned_32 is
     (if Value mod Rounding > 0 then Value + (Rounding - Value mod Rounding) else Value)
   with Pre => Rounding > 0;

   --  The name in the 8.3 form a directory entry stores: eight characters
   --  of the base name, then three of the extension, upper case, padded with
   --  spaces. A base name longer than eight characters runs on into the
   --  extension.
   function To_FAT_Name (Name : String) return FAT_Name;

   ---------------------
   -- Volume geometry --
   ---------------------

   function FAT_Entries_Per_Sector (V : Volume) return Unsigned_32 is
     (if V.FS_Type = FAT32 then FAT32_Entries_Per_Sector else FAT16_Entries_Per_Sector);

   function Cluster_Size (V : Volume) return Unsigned_32 is (V.Sectors_Per_Cluster * Sector_Size);

   function Byte_Index_In_Cluster (V : Volume; Offset : Unsigned_32) return Unsigned_32 is
     (V.Byte_In_Cluster_Mask and Offset);

   function Sector_Index_In_Cluster (V : Volume; Offset : Unsigned_32) return Unsigned_32 is
     (Byte_Index_In_Cluster (V, Offset) / Sector_Size);

   function FAT_Sector_To_Physical (V : Volume; FAT : FAT_Number; FAT_Sector : Unsigned_32) return Unsigned_32 is
     (V.FAT_Start_Sector + (if FAT = 1 then V.FAT_Sectors else 0) + FAT_Sector);

   function File_Cluster_To_Physical (V : Volume; Cluster : Unsigned_32; Sector : Unsigned_32) return Unsigned_32 is
     (V.Cluster_Start_Sector + (Cluster - 2) * V.Sectors_Per_Cluster + Sector);

   function FAT_End_Of_Chain (V : Volume; Cluster : Unsigned_32) return Boolean is
     (if V.FS_Type = FAT32 then FAT32_End_Of_Chain (Cluster)
      else FAT16_End_Of_Chain (Unsigned_16 (Cluster and 16#FFFF#)));

   --  The FAT sector that holds a cluster's entry, and the entry's index in
   --  it. A volume that is not FAT16 takes the FAT32 layout.
   procedure FAT_Position
     (V : Volume; Cluster : Unsigned_32; FAT_Sector : out Unsigned_32; Entry_Index : out Unsigned_32)
     with Global => null,
          Post   => Entry_Index < (if V.FS_Type = FAT16 then FAT16_Entries_Per_Sector else FAT32_Entries_Per_Sector);

   --  The first FAT partition of the partition table, by its start sector,
   --  when the sector has the boot signature.
   procedure Parse_MBR (Sector : Sector_Bytes; V : in out Volume; Found : out Boolean)
     with Global => null;

   --  The volume's layout from its volume ID sector: 512-byte sectors, two
   --  FATs, the boot signature and a cluster of 1 to 128 sectors, a power of
   --  two. The cluster count makes the volume FAT12, which is refused, FAT16
   --  or FAT32. A refused sector leaves the fields it got to.
   procedure Parse_Volume_ID (Sector : Sector_Bytes; V : in out Volume; Valid : out Boolean)
     with Global => null,
          Post   => (if Valid then V.FS_Type in FAT16 | FAT32 and then V.Sectors_Per_Cluster in 1 .. 128);

   ------------------
   -- Sector cache --
   ------------------

   --  A file system that has yet to read its card.
   procedure Init (FS : out File_System)
     with Global => null;

   --  A failed check marks the file system fatal, with a generic error
   --  unless one is already set.
   procedure Check (FS : in out File_System; Condition : Boolean)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   procedure Mark_Dirty (FS : in out File_System; Index : Cache_Index)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   procedure Init_Sector (FS : in out File_System; Index : Cache_Index; Sector : Unsigned_32; Locked : Boolean)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The count of dirty entries, one up or one down.
   procedure Add_Dirty (FS : in out File_System)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old and then FS.Descriptors = FS.Descriptors'Old;

   procedure Remove_Dirty (FS : in out File_System)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old and then FS.Descriptors = FS.Descriptors'Old;

   --  The card's end of a read into a cache buffer: the data when the read
   --  succeeded, then the state of the sector's entry.
   procedure Read_Complete
     (FS : in out File_System; Buffer : Cache_Index; Sector : Unsigned_32; Data : Sector_Bytes; Succeeded : Boolean)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The card's end of a write from a cache buffer.
   procedure Write_Complete (FS : in out File_System; Buffer : Cache_Index; Sector : Unsigned_32; Succeeded : Boolean)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  Whether every sector that may be flushed is on the card.
   function Cache_In_Sync (FS : File_System) return Boolean is
     (for all D of FS.Descriptors => D.State /= Writing and then (D.State /= Dirty or else D.Locked));

   --  The entry of a sector in any state, the first one found.
   function Find_Cache_Sector (FS : File_System; Sector : Unsigned_32) return Cache_Slot
     with Post => (if Find_Cache_Sector'Result /= No_Slot
                   then FS.Descriptors (Find_Cache_Sector'Result).Sector_Index = Sector);

   --  The entry for a sector: the one that holds it, else an empty one, a
   --  synced discardable one or the oldest synced one, set up afresh. None
   --  when every entry is busy, or when the sector lies past the volume.
   procedure Allocate_Cache_Sector (FS : in out File_System; Sector : Unsigned_32; Slot : out Cache_Slot)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The space a writer can fill now without waiting: the unlocked empty
   --  and synced sectors.
   function Free_Buffer_Space (FS : File_System) return Unsigned_32;

   procedure Unlock_Sector (FS : in out File_System; Index : Cache_Index)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   procedure Release_Sector (FS : in out File_System; Index : Cache_Index)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

end Adaflight.FAT;
