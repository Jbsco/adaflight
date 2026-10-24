--  The CC2500 radio's register access for the SPI receivers: FIFO reads and
--  writes, register and burst reads and writes, strobes, the output power
--  table and the reset, which disables DMA, strobes the reset, waits 1 ms
--  and checks the first frequency register for its reset value.
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Radio_Device is limited private;
   with procedure Bus_Write_Command (D : in out Radio_Device; Command : Byte; Value : Byte);
   with procedure Bus_Write_Command_Multi (D : in out Radio_Device; Command : Byte; Data : Byte_Array);
   with procedure Bus_Read_Command (D : in out Radio_Device; Command : Byte; Value : out Byte);
   with procedure Bus_Read_Command_Multi (D : in out Radio_Device; Command : Byte; Data : out Byte_Array);
   with procedure Bus_Write_Byte (D : in out Radio_Device; Value : Byte);
   with procedure Bus_DMA_Enable (D : in out Radio_Device; Enable : Boolean);
   with procedure Delay_Us (D : in out Radio_Device; Us : Natural);
package Adaflight.CC2500 with SPARK_Mode is

   Max_Power_Level : constant := 7;

   procedure Read_FIFO (D : in out Radio_Device; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Write_FIFO (D : in out Radio_Device; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Read_Register_Multi (D : in out Radio_Device; Address : Byte; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Write_Register_Multi (D : in out Radio_Device; Address : Byte; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Read_Register (D : in out Radio_Device; Register : Byte; Value : out Byte);

   procedure Strobe (D : in out Radio_Device; Command : Byte);

   procedure Write_Register (D : in out Radio_Device; Address : Byte; Value : Byte);

   --  The power amplifier table entry of a level, levels past 7 as 7.
   procedure Set_Power (D : in out Radio_Device; Power : Byte);

   procedure Reset (D : in out Radio_Device; OK : out Boolean);

end Adaflight.CC2500;
