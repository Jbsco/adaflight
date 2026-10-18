pragma SPARK_Mode (On);
--  The BLHeli bootloader protocol over a pin and clocks that do nothing, the
--  shape the proof covers.
with Adaflight.BLHeli_Bootloader;
with Adaflight.ESC_Pin_Steps;

package Adaflight.BLHeli_Bootloader_Shape is new Adaflight.BLHeli_Bootloader
  (Line        => Adaflight.ESC_Pin_Steps.Pin_Line,
   Read_Micros => Adaflight.ESC_Pin_Steps.Step_Read_Micros,
   Read_Millis => Adaflight.ESC_Pin_Steps.Step_Read_Millis,
   Read_Pin    => Adaflight.ESC_Pin_Steps.Step_Read_Pin,
   Pin_Low     => Adaflight.ESC_Pin_Steps.Step_Pin_Low,
   Pin_High    => Adaflight.ESC_Pin_Steps.Step_Pin_High,
   Pin_Input   => Adaflight.ESC_Pin_Steps.Step_Pin_Input,
   Pin_Output  => Adaflight.ESC_Pin_Steps.Step_Pin_Output);
