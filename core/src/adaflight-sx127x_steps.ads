--  An SX127x radio's receiver bus, pins and interrupt line as steps that
--  do nothing, the shape the radio driver's proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.SX127x_Steps with SPARK_Mode is

   type Radio_Line is null record;

   procedure Step_Exti_Configured (D : in out Radio_Line; Configured : out Boolean)
     with Global => null;

   procedure Step_Pin (D : in out Radio_Line)
     with Global => null;

   procedure Step_Delay_Ms (D : in out Radio_Line; Ms : Natural)
     with Global => null;

   procedure Step_Last_Exti_Time (D : in out Radio_Line; Time : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Bus_Write_Command (D : in out Radio_Line; Command : Byte; Value : Byte)
     with Global => null;

   procedure Step_Bus_Write_Command_Multi (D : in out Radio_Line; Command : Byte; Data : Byte_Array)
     with Global => null;

   procedure Step_Bus_Read_Command (D : in out Radio_Line; Command : Byte; Value : out Byte)
     with Global => null;

   procedure Step_Bus_Read_Command_Multi (D : in out Radio_Line; Command : Byte; Data : out Byte_Array)
     with Global => null;

end Adaflight.SX127x_Steps;
