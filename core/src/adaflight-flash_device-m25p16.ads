--  The M25P16 family of SPI NOR flash chips, 40 parts from the M25P16 to
--  Winbond, Macronix, Micron, GigaDevice and other 2 to 64 MB chips with
--  256-byte pages. Identification looks the JEDEC ID up for the geometry
--  and the clocks. Configuration sets the read clock and, past 16 MB, the
--  4-byte addresses. Erases, programs and reads go to the bus as segment
--  lists that start with a status read repeated while the chip is busy,
--  which programs and reads skip when no write could have left it busy.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type SPI_Device is limited private;
   with procedure Read_Write (D : in out SPI_Device; Tx : Byte_Array; Rx : out Byte_Array);
   with procedure Write (D : in out SPI_Device; Tx : Byte_Array);
   with procedure Run
     (D : in out SPI_Device; F : in out Device; Q : Sequence; First : Segment_Index; Data_1 : Byte_Array;
      Data_2 : Byte_Array);
   with procedure Run_Read
     (D : in out SPI_Device; F : in out Device; Q : Sequence; First : Segment_Index; Received : out Byte_Array);
   with procedure Wait (D : in out SPI_Device);
   with function Uses_DMA (D : SPI_Device) return Boolean;
   with procedure Bus_Busy (D : in out SPI_Device; Busy : out Boolean);
   with procedure Divider (D : in out SPI_Device; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16);
   with procedure Set_Divisor (D : in out SPI_Device; Divisor : Interfaces.Unsigned_16);
package Adaflight.Flash_Device.M25P16 with SPARK_Mode is

   Page_Bytes    : constant := 256;
   Memory_Mapped : constant Interfaces.Unsigned_32 := 1;

   procedure Identify (F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean)
     with Global => null;

   procedure Configure (D : in out SPI_Device; F : in out Device; Flags : Interfaces.Unsigned_32);

   procedure Is_Ready (D : in out SPI_Device; F : in out Device; Ready : out Boolean);

   procedure Wait_For_Ready (D : in out SPI_Device; F : in out Device);

   procedure Erase_Sector (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32);

   procedure Erase_Completely (D : in out SPI_Device; F : in out Device);

   procedure Page_Program_Begin (F : in out Device; Address : Interfaces.Unsigned_32; Has_Callback : Boolean)
     with Global => null;

   --  One or two buffers, the bytes of which Written returns; any other
   --  count sends nothing and returns 0.
   procedure Page_Program_Continue
     (D : in out SPI_Device; F : in out Device; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32);

   procedure Page_Program
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean);

   procedure Read_Bytes
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Buffer : out Byte_Array);

   function Get_Geometry (F : Device) return Geometry is (F.Map);

end Adaflight.Flash_Device.M25P16;
