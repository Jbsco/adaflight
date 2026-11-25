pragma SPARK_Mode (On);
--  The A7105 driver over a receiver bus that does nothing, the shape the
--  proof covers.
with Adaflight.A7105;
with Adaflight.CC2500_Steps;

package Adaflight.A7105_Shape is new Adaflight.A7105
  (Radio_Device            => Adaflight.CC2500_Steps.Radio_Line,
   Bus_Write_Command       => Adaflight.CC2500_Steps.Step_Write_Command,
   Bus_Write_Command_Multi => Adaflight.CC2500_Steps.Step_Write_Command_Multi,
   Bus_Read_Command        => Adaflight.CC2500_Steps.Step_Read_Command,
   Bus_Read_Command_Multi  => Adaflight.CC2500_Steps.Step_Read_Command_Multi,
   Bus_Write_Byte          => Adaflight.CC2500_Steps.Step_Write_Byte);
