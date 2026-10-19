pragma SPARK_Mode (On);
--  The SX127x driver over a receiver that does nothing, the shape the proof
--  covers.
with Adaflight.SX127x;
with Adaflight.SX127x_Steps;

package Adaflight.SX127x_Shape is new Adaflight.SX127x
  (Radio_Device            => Adaflight.SX127x_Steps.Radio_Line,
   Exti_Configured         => Adaflight.SX127x_Steps.Step_Exti_Configured,
   Init_Reset_Pin          => Adaflight.SX127x_Steps.Step_Pin,
   Reset_Low               => Adaflight.SX127x_Steps.Step_Pin,
   Reset_Float             => Adaflight.SX127x_Steps.Step_Pin,
   Delay_Ms                => Adaflight.SX127x_Steps.Step_Delay_Ms,
   Reset_Exti              => Adaflight.SX127x_Steps.Step_Pin,
   Last_Exti_Time          => Adaflight.SX127x_Steps.Step_Last_Exti_Time,
   Bus_Write_Command       => Adaflight.SX127x_Steps.Step_Bus_Write_Command,
   Bus_Write_Command_Multi => Adaflight.SX127x_Steps.Step_Bus_Write_Command_Multi,
   Bus_Read_Command        => Adaflight.SX127x_Steps.Step_Bus_Read_Command,
   Bus_Read_Command_Multi  => Adaflight.SX127x_Steps.Step_Bus_Read_Command_Multi);
