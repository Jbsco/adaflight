--  The A7105 radio's register access for the FlySky SPI receivers: register
--  reads and writes, strobes, the radio id and the FIFO, read and written
--  behind a reset of its pointer. Which strobes use the radio's interrupt
--  line is the receiver's business.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Radio_Device is limited private;
   with procedure Bus_Write_Command (D : in out Radio_Device; Command : Byte; Value : Byte);
   with procedure Bus_Write_Command_Multi (D : in out Radio_Device; Command : Byte; Data : Byte_Array);
   with procedure Bus_Read_Command (D : in out Radio_Device; Command : Byte; Value : out Byte);
   with procedure Bus_Read_Command_Multi (D : in out Radio_Device; Command : Byte; Data : out Byte_Array);
   with procedure Bus_Write_Byte (D : in out Radio_Device; Value : Byte);
package Adaflight.A7105 with SPARK_Mode is

   FIFO_Size : constant := 64;

   subtype Register is Byte range 0 .. 16#3F#;

   procedure Read_Register (D : in out Radio_Device; Address : Register; Value : out Byte);

   procedure Write_Register (D : in out Radio_Device; Address : Register; Value : Byte);

   procedure Strobe (D : in out Radio_Device; Command : Byte);

   --  The id's four bytes, the highest first.
   procedure Write_ID (D : in out Radio_Device; Id : Interfaces.Unsigned_32);

   procedure Read_FIFO (D : in out Radio_Device; Data : out Byte_Array)
     with Pre => Data'Length <= FIFO_Size;

   procedure Write_FIFO (D : in out Radio_Device; Data : Byte_Array)
     with Pre => Data'Length <= FIFO_Size;

end Adaflight.A7105;
