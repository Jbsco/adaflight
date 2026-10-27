pragma SPARK_Mode (On);
--  The blocking DShot command over a motor table that does nothing, the
--  shape the proof covers.
with Adaflight.DShot_Command.Blocking_Run;
with Adaflight.DShot_Table_Steps;

package Adaflight.DShot_Blocking_Shape is new Adaflight.DShot_Command.Blocking_Run
  (Motor_Table       => Adaflight.DShot_Table_Steps.Table,
   Delay_Us          => Adaflight.DShot_Table_Steps.Step_Delay_Us,
   Decode_Telemetry  => Adaflight.DShot_Table_Steps.Step_Decode,
   Request_Telemetry => Adaflight.DShot_Table_Steps.Step_Request,
   Write_Int         => Adaflight.DShot_Table_Steps.Step_Write,
   Update_Complete   => Adaflight.DShot_Table_Steps.Step_Complete);
