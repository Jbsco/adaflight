--  The SPI flash device the chip drivers share: the chip's geometry, the
--  write address, whether the chip could be busy, the segment lists a driver
--  hands the bus, and the callbacks the bus runs after a segment. A segment
--  of length 0 ends a list. A callback answering busy has the bus repeat its
--  segment, and one answering abort has it skip the rest.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Flash_Device with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   type Flash_Type is (NOR, NAND);

   type Geometry is record
      Sectors          : Interfaces.Unsigned_16 := 0;
      Page_Size        : Interfaces.Unsigned_16 := 0;
      Sector_Size      : Interfaces.Unsigned_32 := 0;
      Total_Size       : Interfaces.Unsigned_32 := 0;
      Pages_Per_Sector : Interfaces.Unsigned_16 := 0;
      Kind             : Flash_Type := NOR;
      JEDEC_Id         : Interfaces.Unsigned_32 := 0;
   end record;

   --  The geometry, the address the next program writes, whether the chip
   --  takes 4-byte addresses, whether a write could have left it busy,
   --  whether a program reports its end, the bytes of the last program, and
   --  the chip's clocks for writes and reads.
   type Device is record
      Map                   : Geometry;
      Current_Write_Address : Interfaces.Unsigned_32 := 0;
      Large                 : Boolean := False;
      Could_Be_Busy         : Boolean := False;
      Has_Callback          : Boolean := False;
      Bytes_Written         : Interfaces.Unsigned_32 := 0;
      Max_Clock_Hz          : Interfaces.Unsigned_32 := 0;
      Max_Read_Clock_Hz     : Interfaces.Unsigned_32 := 0;
   end record;

   type Callback is (None, Ready_Poll, Write_Enabled, Write_Done);
   type Payload is (Command, Buffer_1, Buffer_2, Read_Data);
   subtype Command_Bytes is Byte_Array (0 .. 4);

   --  The bytes a segment sends, from its command or a caller's buffer, or
   --  none for a read, and whether it keeps what it receives.
   type Segment is record
      Source    : Payload := Command;
      Bytes     : Command_Bytes := (others => 0);
      Length    : Natural := 0;
      Receive   : Boolean := False;
      Negate_CS : Boolean := True;
      After     : Callback := None;
   end record;

   type Segment_Index is range 0 .. 5;
   type Sequence is array (Segment_Index) of Segment;

   type Bus_Result is (Ready, Busy, Skip_Rest);

   Write_In_Progress : constant Byte := 16#01#;

   --  A status read: busy while a write is in progress.
   procedure Ready_Poll_Done (F : in out Device; Status : Byte; Result : out Bus_Result)
     with Global => null;

   --  A write enable: the write that follows could leave the chip busy.
   procedure Write_Enable_Done (F : in out Device)
     with Global => null;

   --  The end of a program: the write address moves past it, and Notify asks
   --  for the report of its bytes when the program has one.
   procedure Write_Done (F : in out Device; Notify : out Boolean)
     with Global => null;

end Adaflight.Flash_Device;
