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
   use type Interfaces.Integer_64;
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
   Entries_Per_Sector       : constant := Sector_Size / Directory_Entry_Size;
   Max_Open_Files           : constant := 3;
   Maximum_File_Size        : constant := 16#FFFF_FFFF#;

   --  The ways a file is open, as bits.
   Mode_Read             : constant Unsigned_8 := 1;
   Mode_Write            : constant Unsigned_8 := 2;
   Mode_Append           : constant Unsigned_8 := 4;
   Mode_Contiguous       : constant Unsigned_8 := 8;
   Mode_Create           : constant Unsigned_8 := 16;
   Mode_Retain_Directory : constant Unsigned_8 := 32;

   subtype Sector_Offset is Natural range 0 .. Sector_Size - 1;

   --  The largest write or read in one call.
   Max_Transfer : constant := 2 ** 16;
   type Data_Bytes is array (Natural range <>) of Unsigned_8;
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
   type Find_Status is (Find_In_Progress, Found, Find_Fatal, Not_Found);
   type Search_Condition is (Free_At_Sector_Start, Free_Cluster, Taken_Cluster);
   type FAT_Pattern is (Open_Chain, Closed_Chain, Free_Clusters);
   type Save_Mode is (Save_Normal, Save_For_Close, Save_Deleted);
   type Seek_Origin is (From_Start, From_Current, From_End);

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

   type File_Kind is (Unused, Normal, FAT16_Root, Directory);
   type File_Operation is
     (Idle, Create_File, Seek, Close, Truncate, Unlink, Append_Supercluster, Locked, Append_Free_Cluster,
      Extend_Subdirectory);
   type Create_Phase is (Create_Start, Find_File, Create_New_File, Create_Success, Create_Failure);
   type Truncate_Phase is
     (Update_Directory, Erase_Chain, Erase_Contiguous_Chain, Prepend_To_Free_File, Truncate_Success);
   type Extend_Phase is (Add_Free_Cluster, Write_Sectors, Extend_Success, Extend_Failure);

   --  The caller's callbacks, by a number the caller picks; 0 is none, and
   --  15 is the file system's own for the free-space file.
   type Callback_Tag is range 0 .. 15;
   No_Callback       : constant Callback_Tag := 0;
   Free_File_Created : constant Callback_Tag := 15;

   --  The steps from the partition table to a file system ready for files.
   type Init_Phase is
     (Read_MBR, Read_Volume_ID, Free_File_Create, Free_File_Creating, Free_File_FAT_Search, Free_File_Update_FAT,
      Free_File_Save_Entry, Init_Done);

   --  The free-space file leaves this many free clusters to other files.
   Free_File_Leave_Clusters : constant := 100;
   type Free_Cluster_Phase is (Find_Free_Space, Update_FAT_1, Update_FAT_2, Update_File_Entry, Complete, Failed);
   type Supercluster_Phase is (Take_Supercluster, Update_Free_File_Entry, Update_Supercluster_FAT, Save_File_Entry);
   subtype Entry_Slot is Integer range -1 .. Entries_Per_Sector - 1;

   --  A directory entry's place: its sector and its index there.
   type Entry_Position is record
      Sector : Unsigned_32 := 0;
      Index  : Entry_Slot := 0;
   end record;

   type Free_Cluster_Append is record
      Previous : Unsigned_32 := 0;
      Search   : Unsigned_32 := 0;
      Phase    : Free_Cluster_Phase := Find_Free_Space;
   end record;

   type Supercluster_Append is record
      Previous      : Unsigned_32 := 0;
      Rewrite_Start : Unsigned_32 := 0;
      Rewrite_End   : Unsigned_32 := 0;
      Phase         : Supercluster_Phase := Take_Supercluster;
   end record;

   type File_Creation is record
      Phase : Create_Phase := Create_Start;
      Name  : FAT_Name := (others => 0);
   end record;

   type File_Truncation is record
      Start_Cluster   : Unsigned_32 := 0;
      Current_Cluster : Unsigned_32 := 0;
      End_Cluster     : Unsigned_32 := 0;
      Phase           : Truncate_Phase := Update_Directory;
   end record;

   type Directory_Extension is record
      Phase          : Extend_Phase := Add_Free_Cluster;
      Parent_Cluster : Unsigned_32 := 0;
   end record;

   --  The operation a file has queued, with the state of each kind: the
   --  callback a creation, seek, truncation or extension ends with, and the
   --  ones a close and a delete end with.
   type Operation_State is record
      Kind            : File_Operation := Idle;
      Callback        : Callback_Tag := No_Callback;
      Close_Callback  : Callback_Tag := No_Callback;
      Unlink_Callback : Callback_Tag := No_Callback;
      Create          : File_Creation;
      Seek_Offset     : Unsigned_32 := 0;
      Free_Append     : Free_Cluster_Append;
      Super_Append    : Supercluster_Append;
      Truncation      : File_Truncation;
      Extension       : Directory_Extension;
   end record;

   --  An open file: the cursor's offset, cluster and the cluster before it,
   --  the size written and the size of its clusters, its mode bits, the
   --  cache sectors it holds at the cursor, and its directory entry.
   type File_Handle is record
      Kind                    : File_Kind := Unused;
      Cursor_Offset           : Unsigned_32 := 0;
      Logical_Size            : Unsigned_32 := 0;
      Physical_Size           : Unsigned_32 := 0;
      Cursor_Cluster          : Unsigned_32 := 0;
      Cursor_Previous_Cluster : Unsigned_32 := 0;
      Mode                    : Unsigned_8 := 0;
      Attrib                  : Unsigned_8 := 0;
      Write_Locked            : Cache_Slot := 0;
      Read_Retained           : Cache_Slot := 0;
      Entry_At                : Entry_Position;
      First_Cluster           : Unsigned_32 := 0;
      Operation               : Operation_State;
   end record;

   --  A handle set up for a new file. A handle never set up holds cache
   --  index 0, as a zeroed one does.
   Fresh_Handle : constant File_Handle := (Write_Locked => No_Slot, Read_Retained => No_Slot, others => <>);

   --  The open files, then the free-space file, then the working directory.
   type File_Id is range 0 .. Max_Open_Files + 1;
   subtype Open_File is File_Id range 0 .. Max_Open_Files - 1;
   Free_File         : constant File_Id := Max_Open_Files;
   Current_Directory : constant File_Id := Max_Open_Files + 1;
   type File_Array is array (File_Id) of File_Handle;

   --  A handle or none, as the callbacks name it.
   subtype File_Ref is Integer range -1 .. Integer (Current_Directory);
   No_File : constant File_Ref := -1;

   --  A callback the caller takes after the call: its number and its file.
   type Notice is record
      Tag  : Callback_Tag := No_Callback;
      File : File_Ref := No_File;
   end record;
   Max_Notices : constant := 16;
   type Notice_List is array (1 .. Max_Notices) of Notice;

   --  The local time a new file's entry takes when the clock is set.
   type Clock_Reading is record
      Year    : Unsigned_16 := 0;
      Month   : Unsigned_8 := 0;
      Day     : Unsigned_8 := 0;
      Hours   : Unsigned_8 := 0;
      Minutes : Unsigned_8 := 0;
      Seconds : Unsigned_8 := 0;
   end record;

   --  The search for the longest run of free clusters that starts a FAT
   --  sector, for the free-space file.
   type Search_Phase is (Find_Hole, Grow_Hole);
   type Free_Space_Search is record
      Candidate_Start : Unsigned_32 := 0;
      Candidate_End   : Unsigned_32 := 0;
      Best_Gap_Start  : Unsigned_32 := 0;
      Best_Gap_Length : Unsigned_32 := 0;
      Phase           : Search_Phase := Find_Hole;
   end record;

   type File_System is record
      Vol                    : Volume;
      State                  : Filesystem_State := Unknown;
      Phase                  : Init_Phase := Read_MBR;
      Last_Error             : Error_Kind := None;
      Full                   : Boolean := False;
      Last_Cluster_Allocated : Unsigned_32 := 0;
      Cache                  : Cache_Memory := (others => (others => 0));
      Descriptors            : Descriptor_Array;
      Cache_Timer            : Unsigned_32 := 0;
      Dirty_Entries          : Integer_32 := 0;
      Flush_In_Progress      : Boolean := False;
      Files                  : File_Array;
      Search                 : Free_Space_Search;
      Notices                : Notice_List;
      Notice_Count           : Natural range 0 .. Max_Notices := 0;
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

   --  32-bit values as C converts them between signed and unsigned.
   function To_U32 (X : Integer_32) return Unsigned_32 is
     (if X >= 0 then Unsigned_32 (X) else Unsigned_32 (Interfaces.Integer_64 (X) + 2 ** 32));

   function To_I32 (X : Unsigned_32) return Integer_32 is
     (if X <= 16#7FFF_FFFF# then Integer_32 (X) else Integer_32 (Interfaces.Integer_64 (X) - 2 ** 32));

   --  A division that gives zero for a zero divisor, as the Cortex-M
   --  divide does.
   function Divide (A : Unsigned_32; B : Unsigned_32) return Unsigned_32 is (if B = 0 then 0 else A / B);

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

   --  A file system set to read its card, from the partition table on. The
   --  other fields stay as they are: zero at start, or after a shutdown.
   procedure Init (FS : in out File_System)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

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

   -----------
   -- Files --
   -----------

   function Is_Busy (F : File_Handle) return Boolean is (F.Operation.Kind /= Idle);

   --  The logical size brought up to the cursor.
   procedure Update_File_Size (F : in out File_Handle)
     with Global => null;

   --  The cache sectors a file holds at its cursor, let go.
   procedure Unlock_File_Sector (FS : in out File_System; Id : File_Id)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   function Supercluster_Size (V : Volume) return Unsigned_32 is (FAT_Entries_Per_Sector (V) * Cluster_Size (V));

   --  The sector under a file's cursor: the FAT16 root directory sits after
   --  the FATs, a file in its cluster.
   function Cursor_Sector (FS : File_System; Id : File_Id) return Unsigned_32 is
     (if FS.Files (Id).Kind = FAT16_Root
      then FS.Vol.FAT_Start_Sector + FAT_Count * FS.Vol.FAT_Sectors + FS.Files (Id).Cursor_Offset / Sector_Size
      else File_Cluster_To_Physical
             (FS.Vol, FS.Files (Id).Cursor_Cluster, Sector_Index_In_Cluster (FS.Vol, FS.Files (Id).Cursor_Offset)));

   --  Whether a file's cursor lies past its last cluster.
   function End_Of_Allocation (FS : File_System; Id : File_Id) return Boolean is
     (if FS.Files (Id).Kind = FAT16_Root then FS.Files (Id).Cursor_Offset >= Sector_Size * FS.Vol.Root_Directory_Sectors
      else FS.Files (Id).Cursor_Cluster = 0 or else FAT_End_Of_Chain (FS.Vol, FS.Files (Id).Cursor_Cluster));

   function At_End_Of_File (F : File_Handle) return Boolean is (F.Cursor_Offset >= F.Logical_Size);

   --  A file's cursor offset, when no operation is queued on the file.
   procedure Tell (F : File_Handle; Position : in out Unsigned_32; Done : out Boolean)
     with Global => null;

   function Contiguous_Free_Space (FS : File_System) return Unsigned_32 is (FS.Files (Free_File).Logical_Size);

   procedure Begin_Free_Space_Search (FS : in out File_System)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   ----------------------------
   -- Directories and notices --
   ----------------------------

   Attribute_Read_Only : constant Unsigned_8 := 16#01#;
   Attribute_System    : constant Unsigned_8 := 16#04#;
   Attribute_Volume_ID : constant Unsigned_8 := 16#08#;
   Attribute_Directory : constant Unsigned_8 := 16#10#;
   Attribute_Archive   : constant Unsigned_8 := 16#20#;

   --  The date and time a new entry takes without the clock: 2015-12-01 at
   --  midnight.
   Default_Date : constant Unsigned_16 := 1 + 12 * 2 ** 5 + (2015 - 1980) * 2 ** 9;
   Default_Time : constant Unsigned_16 := 0;

   --  The FAT date and time of a clock reading, bit fields as C packs them.
   function FAT_Date (C : Clock_Reading) return Unsigned_16 is
     (Unsigned_16 ((Unsigned_32 (C.Day) or Interfaces.Shift_Left (Unsigned_32 (C.Month), 5)
                    or Interfaces.Shift_Left (To_U32 (Integer_32 (C.Year) - 1980), 9)) and 16#FFFF#));

   function FAT_Time (C : Clock_Reading) return Unsigned_16 is
     (Unsigned_16 ((Unsigned_32 (C.Seconds / 2) or Interfaces.Shift_Left (Unsigned_32 (C.Minutes), 5)
                    or Interfaces.Shift_Left (Unsigned_32 (C.Hours), 11)) and 16#FFFF#));

   --  A callback for the caller to take: dropped when the list is full or
   --  the callback is none.
   procedure Notify (FS : in out File_System; Tag : Callback_Tag; File : File_Ref)
     with Global => null,
          Post   => FS.Vol = FS.Vol'Old;

   --  The first open file not in use, or none.
   function Free_Handle (FS : File_System) return File_Ref is
     (if FS.Files (0).Kind = Unused then 0
      elsif FS.Files (1).Kind = Unused then 1
      elsif FS.Files (2).Kind = Unused then 2
      else No_File);

   --  A file's first cluster, sizes and attributes from a directory entry.
   procedure Load_Directory_Entry (FS : in out File_System; Id : File_Id; Slot : Cache_Index; Index : Entry_Slot)
     with Global => null,
          Pre    => Index >= 0,
          Post   => FS.Vol = FS.Vol'Old;

end Adaflight.FAT;
