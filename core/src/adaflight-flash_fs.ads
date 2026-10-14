--  The flash filesystem: one volume from the start of the flash written
--  through a 128-byte ring buffer at a tail address, the erase of the volume
--  by sectors or of the whole chip, the search for the start of the free
--  space, and the reads. The unit hands the flash its operations in order:
--  the ready checks and waits, the page programs trimmed at the page
--  boundary, the erases, the reads, the flush and the status LED. The caller
--  reports the end of a program the flash completes in the background.
with Interfaces;
with Adaflight.Bytes;

package Adaflight.Flash_FS with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Buffer_Size       : constant := 128;
   Buffer_Usable     : constant := Buffer_Size - 1;
   Auto_Flush_Length : constant := 64;
   Free_Block_Size   : constant := 2_048;
   Free_Test_Bytes   : constant := 16;

   subtype Buffer_Index is Natural range 0 .. Buffer_Size - 1;
   subtype Buffer_Count is Natural range 0 .. Buffer_Size;
   type Ring is array (Buffer_Index) of Unsigned_8;

   type Flash_Kind is (NOR, NAND);

   --  The flash's geometry, the filesystem partition with the count of all
   --  partitions, and whether a page program ends inside the program call,
   --  as on a bus without transfers in the background.
   type Layout is record
      Kind              : Flash_Kind := NOR;
      Sectors           : Unsigned_16 := 0;
      Page_Size         : Positive range 1 .. 2_048 := 256;
      Sector_Size       : Unsigned_32 := 0;
      Partition_Count   : Natural range 0 .. 16 := 0;
      Has_Partition     : Boolean := False;
      Start_Sector      : Unsigned_16 := 0;
      End_Sector        : Unsigned_16 := 0;
      Inline_Completion : Boolean := False;
   end record;

   type File_System is record
      Map          : Layout;
      Size         : Unsigned_32 := 0;
      Erasing      : Boolean := False;
      Erase_Sector : Unsigned_16 := 0;
      Chip_Erase   : Boolean := False;
      Buffer       : Ring := (others => 0);
      Head         : Buffer_Index := 0;
      Tail         : Buffer_Index := 0;
      Data_Written : Boolean := True;
      Tail_Address : Unsigned_32 := 0;
   end record;

   --  A ready check reads the readiness the call was given, a ready wait
   --  leaves the flash ready. A program lists its bytes in the output's data
   --  from Data_At, and Report says the caller reports its end.
   type Op_Kind is (Ready_Check, Ready_Wait, Program, Erase_Sector, Erase_Chip, Read, Flush, LED_Toggle, LED_Off);
   type Op is record
      Kind    : Op_Kind := Ready_Check;
      Address : Unsigned_32 := 0;
      First   : Buffer_Count := 0;
      Second  : Buffer_Count := 0;
      Length  : Natural := 0;
      Data_At : Natural := 0;
      Report  : Boolean := False;
   end record;

   Max_Ops   : constant := 600;
   Data_Size : constant := 1_024;
   type Op_List is array (1 .. Max_Ops) of Op;
   type Data_Bytes is array (0 .. Data_Size - 1) of Unsigned_8;
   type Output is record
      Ops       : Op_List;
      Count     : Natural range 0 .. Max_Ops := 0;
      Data      : Data_Bytes := (others => 0);
      Data_Used : Natural range 0 .. Data_Size := 0;
   end record;

   function Is_Supported (FS : File_System) return Boolean is (FS.Size > 0);
   function Is_EOF (FS : File_System) return Boolean is (FS.Tail_Address >= FS.Size);
   function Is_Empty (FS : File_System) return Boolean is (FS.Head = FS.Tail);

   --  The buffered bytes not yet handed to the flash.
   function Used (FS : File_System) return Buffer_Index is
     (if FS.Head >= FS.Tail then FS.Head - FS.Tail else Buffer_Size - FS.Tail + FS.Head);

   function Free_Space (FS : File_System) return Buffer_Index is (Buffer_Usable - Used (FS));

   --  The volume offset after the buffered bytes.
   function Offset (FS : File_System) return Unsigned_32 is (FS.Tail_Address + Unsigned_32 (Used (FS)));

   function Is_Ready (FS : File_System; Device_Ready : Boolean) return Boolean is
     (Is_Supported (FS) and then not FS.Erasing and then Device_Ready);

   --  The volume over the filesystem partition, empty without one. The
   --  caller then searches for the start of the free space and seeks there.
   procedure Init (FS : out File_System; Map : Layout)
     with Global => null, Pre => Map.End_Sector >= Map.Start_Sector;

   --  A page program the flash completed in the background, with the bytes
   --  it wrote.
   procedure Program_Complete (FS : in out File_System; Bytes : Buffer_Count)
     with Global => null;

   procedure Erase_Completely (FS : in out File_System; O : in out Output)
     with Global => null;

   --  One step of a sector erase, or the end of a chip erase.
   procedure Erase_Async (FS : in out File_System; Device_Ready : Boolean; O : in out Output)
     with Global => null;

   --  A byte into the buffer, then an asynchronous flush once half of it is
   --  in use. A byte past a full buffer empties it.
   procedure Write_Byte (FS : in out File_System; B : Unsigned_8; Device_Ready : Boolean; O : in out Output)
     with Global => null;

   --  The bytes one at a time, then a write of the buffer once half of it is
   --  in use. A synchronous write needs a flash that completes its programs
   --  inside the call.
   procedure Write (FS : in out File_System; Data : Bytes.Byte_Array; Sync : Boolean; Device_Ready : Boolean;
                    O : in out Output)
     with Global => null,
          Pre    => Data'Length <= 256 and then (if Sync then FS.Map.Inline_Completion);

   --  A write of the buffer when forced or half full; Done when it is empty.
   procedure Flush_Async (FS : in out File_System; Force : Boolean; Device_Ready : Boolean; O : in out Output;
                          Done : out Boolean)
     with Global => null;

   --  A write of the buffer that waits for the flash before and after.
   procedure Flush_Sync (FS : in out File_System; O : in out Output)
     with Global => null, Pre => FS.Data_Written or else Is_Empty (FS);

   procedure Seek_Abs (FS : in out File_System; Offset : Unsigned_32; O : in out Output)
     with Global => null, Pre => FS.Data_Written or else Is_Empty (FS);

   --  A read of up to Length bytes inside the volume after a synchronous
   --  flush; Length_Read is the length handed to the flash.
   procedure Read_Abs (FS : in out File_System; Address : Unsigned_32; Length : Natural; O : in out Output;
                       Length_Read : out Natural)
     with Global => null, Pre => FS.Data_Written or else Is_Empty (FS);

   --  The end of a log: the flash's flush on NAND with the tail on the next
   --  page, then the tail on the next 2048-byte boundary.
   procedure Close (FS : in out File_System; O : in out Output)
     with Global => null;

   --  The binary search over 2048-byte blocks for the first one whose first
   --  sixteen bytes read erased. A short read stops it.
   subtype Block_Number is Natural range 0 .. 2 ** 21;
   type Search is record
      Left    : Block_Number := 0;
      Right   : Block_Number := 0;
      Result  : Block_Number := 0;
      Stopped : Boolean := False;
   end record;

   type Test_Block is array (0 .. Free_Test_Bytes - 1) of Unsigned_8;

   function Search_Done (S : Search) return Boolean is (S.Stopped or else S.Left >= S.Right);

   procedure Search_Start (S : out Search; FS : File_System)
     with Global => null;

   function Search_Address (S : Search) return Unsigned_32 is
     (Unsigned_32 ((S.Left + S.Right) / 2) * Free_Block_Size);

   --  The read of the block at Search_Address with the count the flash gave.
   procedure Search_Next (S : in out Search; Count : Integer; Block : Test_Block)
     with Global => null, Pre => not Search_Done (S);

   function Search_Offset (S : Search) return Unsigned_32 is
     (Unsigned_32 (S.Result) * Free_Block_Size);

end Adaflight.Flash_FS;
