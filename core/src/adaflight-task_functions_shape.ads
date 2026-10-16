pragma SPARK_Mode (On);
--  The task functions over counting units, the shape the proof covers.
with Adaflight.Counting_Steps;
with Adaflight.Task_Functions;

package Adaflight.Task_Functions_Shape is new Adaflight.Task_Functions
  (Flash_Erase            => Adaflight.Counting_Steps.Step,
   MSP_Serial             => Adaflight.Counting_Steps.Step_Flag,
   Battery_Presence       => Adaflight.Counting_Steps.Step,
   Battery_States         => Adaflight.Counting_Steps.Step_At,
   Battery_Alarms         => Adaflight.Counting_Steps.Step,
   Acc_Update             => Adaflight.Counting_Steps.Step_At,
   GPS_Rescue_Update      => Adaflight.Counting_Steps.Step,
   Baro_Update            => Adaflight.Counting_Steps.Step_Period,
   Pitot_Update           => Adaflight.Counting_Steps.Step_Period,
   Compass_Update         => Adaflight.Counting_Steps.Step_Period,
   Position_Update        => Adaflight.Counting_Steps.Step,
   Rangefinder_Update     => Adaflight.Counting_Steps.Step,
   Rangefinder_Process    => Adaflight.Counting_Steps.Step_Tilt,
   Optical_Flow_Update    => Adaflight.Counting_Steps.Step,
   Optical_Flow_Process   => Adaflight.Counting_Steps.Step,
   Telemetry_Poll_Sensors => Adaflight.Counting_Steps.Step_At,
   Telemetry_Process      => Adaflight.Counting_Steps.Step_At,
   Camera_Control_Process => Adaflight.Counting_Steps.Step_At);
