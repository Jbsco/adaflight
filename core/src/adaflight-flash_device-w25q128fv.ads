--  The W25Q128FV family of NOR flash chips on a quad SPI controller, nine
--  parts from 2 to 32 MB with 256-byte pages and 64 KB sectors.
--  Identification looks the JEDEC ID up for the sectors. Configuration
--  resets the chip: it waits for the chip, sends the reset pair, waits a
--  millisecond and for the chip again, then reads the second status register
--  and, when its quad enable bit is clear, reads it again and writes it back
--  with the bit set after a volatile write enable. Erases wait for the chip,
--  enable writes, send the block or chip erase and start the erase timeout. A
--  program goes to the bus as a segment list: the status read repeated while
--  the chip is busy, the write enable, the quad program command with its
--  address and one or two buffers on four lines, the last of which releases
--  the chip and ends the program; no buffer reports zero bytes to a program
--  with a report, and any other count sends nothing and returns 0 after the
--  written bytes take the first buffer's length. A read waits for the chip
--  within its timeout, reads on four lines after eight dummy cycles and
--  starts the read timeout; a read the chip or the bus refuses returns 0.
--  A wait for the chip ends when the chip reads ready or its timeout, kept
--  from the last operation, passes, after which the timeout clears.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Quad_Device is limited private;
   --  An instruction with data bytes on one line, none when Data is empty.
   with procedure Transmit (D : in out Quad_Device; Instruction : Byte; Data : Byte_Array);
   --  An instruction answered with bytes on one line.
   with procedure Receive (D : in out Quad_Device; Instruction : Byte; Data : out Byte_Array);
   --  An instruction with a 24-bit address on one line and no data.
   with procedure Instruction_With_Address
     (D : in out Quad_Device; Instruction : Byte; Address : Interfaces.Unsigned_32);
   --  An instruction with a 24-bit address on one line, Dummy clock cycles,
   --  and the answer on four lines.
   with procedure Receive_With_Address
     (D       : in out Quad_Device;
      Instruction : Byte;
      Dummy   : Natural;
      Address : Interfaces.Unsigned_32;
      Data    : out Byte_Array;
      OK      : out Boolean);
   --  A segment list, its buffers on four lines.
   with procedure Run
     (D : in out Quad_Device; F : in out Device; Q : Sequence; First : Segment_Index; Data_1 : Byte_Array;
      Data_2 : Byte_Array);
   with procedure Wait (D : in out Quad_Device);
   with procedure Millis (D : in out Quad_Device; Now : out Interfaces.Unsigned_32);
   with procedure Report_Written (D : in out Quad_Device; Bytes : Interfaces.Unsigned_32);
package Adaflight.Flash_Device.W25Q128FV with SPARK_Mode is

   Page_Bytes    : constant := 256;
   Memory_Mapped : constant Interfaces.Unsigned_32 := 1;

   procedure Identify (F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean)
     with Global => null;

   procedure Configure (D : in out Quad_Device; F : in out Device; Flags : Interfaces.Unsigned_32);

   procedure Is_Ready (D : in out Quad_Device; Ready : out Boolean);

   procedure Wait_For_Ready (D : in out Quad_Device; F : in out Device; Ready : out Boolean);

   procedure Erase_Sector (D : in out Quad_Device; F : in out Device; Address : Interfaces.Unsigned_32);

   procedure Erase_Completely (D : in out Quad_Device; F : in out Device);

   procedure Page_Program_Begin (F : in out Device; Address : Interfaces.Unsigned_32; Has_Callback : Boolean)
     with Global => null;

   --  One or two buffers, the bytes of which Written returns; none reports
   --  0 to a program with a report, and any other count returns 0.
   procedure Page_Program_Continue
     (D : in out Quad_Device; F : in out Device; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32);

   procedure Page_Program
     (D : in out Quad_Device; F : in out Device; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean);

   --  Count is the buffer's length, or 0 when the chip stays busy past its
   --  timeout or the bus refuses the read.
   procedure Read_Bytes
     (D : in out Quad_Device; F : in out Device; Address : Interfaces.Unsigned_32; Buffer : in out Byte_Array;
      Count : out Natural);

   function Get_Geometry (F : Device) return Geometry is (F.Map);

end Adaflight.Flash_Device.W25Q128FV;
