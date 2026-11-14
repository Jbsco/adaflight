--  A FAT32 volume that exists only as answers to sector reads: a table of
--  directories and files becomes a partition table, a boot sector, a file
--  system information sector, two file allocation tables and directory
--  sectors, made as each is read. A file's data is not here: a read inside a
--  file names the file and the offset, and the caller brings the bytes. A
--  mass storage host sees a read-only disk whose files the board keeps
--  elsewhere, such as flight logs in a flash chip.
with Interfaces;
with Adaflight.Bytes;

package Adaflight.Virtual_FAT with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_64 is Interfaces.Unsigned_64;

   Sector_Size         : constant := 512;
   Cluster_Size        : constant := 4096;
   Sectors_Per_Cluster : constant := Cluster_Size / Sector_Size;
   subtype Sector is Adaflight.Bytes.Byte_Array (0 .. Sector_Size - 1);

   --  What one read of a flash's flight logs brings, for the search for
   --  each log's start.
   Read_Size : constant := 32;
   subtype Flash_Read is Adaflight.Bytes.Byte_Array (0 .. Read_Size - 1);

   Max_Entries : constant := 106;
   subtype Entry_Count is Natural range 0 .. Max_Entries;
   subtype Entry_Index is Positive range 1 .. Max_Entries;
   --  An entry's number, or zero for none.
   subtype Entry_Link is Natural range 0 .. Max_Entries;

   Max_Name : constant := 20;
   subtype Name_Length is Natural range 0 .. Max_Name;
   subtype Name_Text is String (1 .. Max_Name);

   --  An entry's attribute bits.
   Read_Only    : constant := 16#01#;
   Hidden       : constant := 16#02#;
   System       : constant := 16#04#;
   Volume_Label : constant := 16#08#;
   Directory    : constant := 16#10#;
   Archive      : constant := 16#20#;

   --  Creation, modification and access times as packed FAT dates and times.
   type Times is array (0 .. 2) of Unsigned_32;

   --  A directory or a file: its name, its level below the root, which is at
   --  level 0, a file's extra attribute bits, the offset its data starts at
   --  for its reader, its size and the size it may grow to, its times and
   --  whether it has a reader. The start sets the clusters and the links: the
   --  first and last cluster in use, the last one reserved, a directory's
   --  entry count less one, and the entry above, the first one below and the
   --  next one beside.
   type File_Entry is record
      Name          : Name_Text := (others => ' ');
      Length        : Name_Length := 0;
      Dir           : Boolean := False;
      Attr          : Unsigned_8 := 0;
      Level         : Integer := 0;
      Offset        : Unsigned_32 := 0;
      Current_Size  : Unsigned_32 := 0;
      Maximum_Size  : Unsigned_32 := 0;
      CMA           : Times := (others => 0);
      Readable      : Boolean := False;
      First_Cluster : Unsigned_32 := 0;
      Last_Cluster  : Unsigned_32 := 0;
      Last_Reserved : Unsigned_32 := 0;
      Subentries    : Unsigned_32 := 0;
      Top           : Entry_Link := 0;
      Sub           : Entry_Link := 0;
      Next          : Entry_Link := 0;
   end record;
   type Entry_Table is array (Entry_Index) of File_Entry;

   --  The volume: its entries, the root first and each directory's entries
   --  after it one level down, its label, and what the start works out: the
   --  size in bytes and sectors, the sectors of the boot sector, the
   --  information sector, the two tables and the root directory, the cluster
   --  counts, and the entry the last read found.
   type Volume is record
      Entries       : Entry_Table;
      Count         : Entry_Count := 0;
      Label         : Name_Text := (others => ' ');
      Label_Length  : Name_Length := 0;
      Size          : Unsigned_64 := 0;
      Disk_Sectors  : Unsigned_32 := 0;
      Boot_LBA      : Unsigned_32 := 0;
      FSInfo_LBA    : Unsigned_32 := 0;
      FAT1_LBA      : Unsigned_32 := 0;
      FAT2_LBA      : Unsigned_32 := 0;
      Root_LBA      : Unsigned_32 := 0;
      Clusters      : Unsigned_32 := 0;
      Free_Clusters : Unsigned_32 := 0;
      Last          : Entry_Index := 1;
   end record;

   function Ready (V : Volume) return Boolean is (V.Count >= 1 and then V.Last <= V.Count);

   --  The volume laid out from its entries and label. Refused, with the
   --  entries' links partly set, when the table is empty, when its first
   --  entry is no directory at level 0, or when an entry's level is neither
   --  its predecessor's, one below under a directory, nor one above below the
   --  root's.
   procedure Start (V : in out Volume; OK : out Boolean)
     with Global => null, Post => (if OK then Ready (V));

   --  Where a sector's bytes come from: the sector as filled here, or a
   --  file's reader at an offset.
   type Source_Kind is (Filled, From_File);
   type Source is record
      Kind   : Source_Kind := Filled;
      File   : Entry_Index := 1;
      Offset : Unsigned_32 := 0;
   end record;

   --  One sector of the volume. Inside a file with a reader the data is
   --  zeros and From names the file and the offset to read a sector's bytes
   --  at.
   procedure Read (V : in out Volume; Number : Unsigned_32; Data : out Sector; From : out Source)
     with Global => null, Pre => Ready (V), Post => Ready (V) and then V.Count = V.Count'Old;

   --  A time in seconds since 1970 as a packed FAT date and time.
   function Packed_Time (Unix : Unsigned_32) return Unsigned_32
     with Global => null;

end Adaflight.Virtual_FAT;
