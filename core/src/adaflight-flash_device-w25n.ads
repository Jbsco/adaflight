--  The W25N family of SPI NAND flash chips: the W25N01GV, the W25N02KV and
--  the MX35LF2GE4AD, with 64 pages of 2048 bytes per block. Identification
--  looks the JEDEC ID up for the block count, the read clock, the status
--  register instructions, the page address form, the buffer read mode and the
--  replacement blocks, and names the last blocks for bad block management.
--  Configuration resets the chip, clears its protection, turns on ECC with the
--  buffer read mode and sets the read clock. Programs load the chip's data
--  buffer, and a page is programmed when a load reaches its end or a flush or
--  read asks for it. Reads move the page into the buffer, read from it and
--  reset the chip on an uncorrectable ECC result. Waits for the chip end at a
--  millisecond timeout.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The chip's SPI device: single sent or exchanged transfers, segment lists
--  that send a caller's buffer or receive into one, the wait for the bus, its
--  DMA and busy answer, the clock divisor, the millisecond clock and the
--  report of a program's bytes.
generic
   type SPI_Device is limited private;
   with procedure Send (D : in out SPI_Device; Tx : Byte_Array);
   with procedure Exchange (D : in out SPI_Device; Tx : Byte_Array; Rx : out Byte_Array);
   with procedure Run
     (D : in out SPI_Device; F : in out Device; Q : Sequence; First : Segment_Index; Data : Byte_Array);
   with procedure Run_Read
     (D : in out SPI_Device; F : in out Device; Q : Sequence; First : Segment_Index; Received : out Byte_Array);
   with procedure Wait (D : in out SPI_Device);
   with function Uses_DMA (D : SPI_Device) return Boolean;
   with procedure Bus_Busy (D : in out SPI_Device; Busy : out Boolean);
   with procedure Divider (D : in out SPI_Device; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16);
   with procedure Set_Divisor (D : in out SPI_Device; Divisor : Interfaces.Unsigned_16);
   with procedure Millis (D : in out SPI_Device; Now : out Interfaces.Unsigned_32);
   with procedure Report_Written (D : in out SPI_Device; Bytes : Interfaces.Unsigned_32);
package Adaflight.Flash_Device.W25N with SPARK_Mode is

   Page_Bytes      : constant := 2048;
   Pages_Per_Block : constant := 64;
   Memory_Mapped   : constant Interfaces.Unsigned_32 := 1;

   procedure Identify (F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean)
     with Global => null;

   procedure Configure (D : in out SPI_Device; F : in out Device; Flags : Interfaces.Unsigned_32);

   procedure Is_Ready (D : in out SPI_Device; F : in out Device; Ready : out Boolean);

   procedure Wait_For_Ready (D : in out SPI_Device; F : in out Device; Ready : out Boolean);

   procedure Erase_Sector (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32);

   procedure Erase_Completely (D : in out SPI_Device; F : in out Device);

   procedure Page_Program_Begin (F : in out Device; Address : Interfaces.Unsigned_32; Has_Callback : Boolean)
     with Global => null;

   --  The first buffer only, the bytes of which Written returns; a count of
   --  0 reports 0 bytes when the program has a callback and returns 0.
   procedure Page_Program_Continue
     (D : in out SPI_Device; F : in out Device; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32);

   procedure Page_Program
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean);

   procedure Flush (D : in out SPI_Device; F : in out Device);

   --  Reads up to the end of the address's page; Count is the bytes read, 0
   --  when a wait for the chip timed out.
   procedure Read_Bytes
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Buffer : in out Byte_Array;
      Count : out Natural);

   function Get_Geometry (F : Device) return Geometry is (F.Map);

end Adaflight.Flash_Device.W25N;
