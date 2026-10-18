pragma SPARK_Mode (On);
--  The STK500v2 bootloader protocol over a pin and a clock that do nothing,
--  the shape the proof covers.
with Adaflight.ESC_Pin_Steps;
with Adaflight.STK_Bootloader;

package Adaflight.STK_Bootloader_Shape is new Adaflight.STK_Bootloader
  (Line         => Adaflight.ESC_Pin_Steps.Pin_Line,
   Read_Micros  => Adaflight.ESC_Pin_Steps.Step_Read_Micros,
   Delay_Micros => Adaflight.ESC_Pin_Steps.Step_Delay_Micros,
   Read_Pin     => Adaflight.ESC_Pin_Steps.Step_Read_Pin,
   Pin_Low      => Adaflight.ESC_Pin_Steps.Step_Pin_Low,
   Pin_High     => Adaflight.ESC_Pin_Steps.Step_Pin_High,
   Pin_Input    => Adaflight.ESC_Pin_Steps.Step_Pin_Input,
   Pin_Output   => Adaflight.ESC_Pin_Steps.Step_Pin_Output);
