--  A CC2500's receiver bus as steps that do nothing, the shape the radio
--  driver's proof takes.
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.CC2500_Steps with SPARK_Mode is

   type Radio_Line is null record;

   procedure Step_Write_Command (D : in out Radio_Line; Command : Byte; Value : Byte)
     with Global => null;

   procedure Step_Write_Command_Multi (D : in out Radio_Line; Command : Byte; Data : Byte_Array)
     with Global => null;

   procedure Step_Read_Command (D : in out Radio_Line; Command : Byte; Value : out Byte)
     with Global => null;

   procedure Step_Read_Command_Multi (D : in out Radio_Line; Command : Byte; Data : out Byte_Array)
     with Global => null;

   procedure Step_Write_Byte (D : in out Radio_Line; Value : Byte)
     with Global => null;

   procedure Step_DMA_Enable (D : in out Radio_Line; Enable : Boolean)
     with Global => null;

   procedure Step_Delay_Us (D : in out Radio_Line; Us : Natural)
     with Global => null;

end Adaflight.CC2500_Steps;
