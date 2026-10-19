pragma SPARK_Mode (On);
--  The SX1280 driver over a receiver that does nothing, the shape the proof
--  covers.
with Adaflight.SX1280;
with Adaflight.Radio_Steps;

package Adaflight.SX1280_Shape is new Adaflight.SX1280
  (Radio_Device         => Adaflight.Radio_Steps.Radio_Line,
   Read_Busy            => Adaflight.Radio_Steps.Step_Read_Busy,
   Micros               => Adaflight.Radio_Steps.Step_Micros,
   Exti_Configured      => Adaflight.Radio_Steps.Step_Exti_Configured,
   Set_Normal_Speed     => Adaflight.Radio_Steps.Step_Set_Normal_Speed,
   Init_Reset_Pin       => Adaflight.Radio_Steps.Step_Pin,
   Init_Busy_Pin        => Adaflight.Radio_Steps.Step_Pin,
   Reset_Low            => Adaflight.Radio_Steps.Step_Pin,
   Reset_Float          => Adaflight.Radio_Steps.Step_Pin,
   Delay_Ms             => Adaflight.Radio_Steps.Step_Delay_Ms,
   Busy_Exti_Config     => Adaflight.Radio_Steps.Step_Pin,
   Busy_Exti_Arm        => Adaflight.Radio_Steps.Step_Pin,
   Busy_Exti_Disable    => Adaflight.Radio_Steps.Step_Pin,
   Enable_Receiver_Exti => Adaflight.Radio_Steps.Step_Pin,
   Last_Exti_Time       => Adaflight.Radio_Steps.Step_Last_Exti_Time,
   Bus_Write_Command    => Adaflight.Radio_Steps.Step_Bus_Write_Command,
   Bus_Transfer         => Adaflight.Radio_Steps.Step_Bus_Transfer,
   Bus_Write            => Adaflight.Radio_Steps.Step_Bus_Write,
   Run_Transfer         => Adaflight.Radio_Steps.Step_Run_Transfer,
   Run_Write            => Adaflight.Radio_Steps.Step_Run_Write,
   Run_Pair             => Adaflight.Radio_Steps.Step_Run_Pair,
   Run_Pair_Write       => Adaflight.Radio_Steps.Step_Run_Pair_Write,
   Hop_Requested        => Adaflight.Radio_Steps.Step_Answer,
   Current_Frequency    => Adaflight.Radio_Steps.Step_Current_Frequency,
   Telemetry_Requested  => Adaflight.Radio_Steps.Step_Answer,
   Do_Telemetry         => Adaflight.Radio_Steps.Step_Pin,
   Telemetry_Buffer     => Adaflight.Radio_Steps.Step_Telemetry_Buffer,
   Process_Packet       => Adaflight.Radio_Steps.Step_Process_Packet,
   Set_Packet_Status    => Adaflight.Radio_Steps.Step_Set_Packet_Status);
