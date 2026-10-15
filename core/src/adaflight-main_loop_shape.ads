pragma SPARK_Mode (On);
--  The PID loop's pass over counting units, the shape the proof covers.
with Adaflight.Counting_Steps;
with Adaflight.Main_Loop;

package Adaflight.Main_Loop_Shape is new Adaflight.Main_Loop
  (Reset_Yaw       => Adaflight.Counting_Steps.Step,
   RC_Command      => Adaflight.Counting_Steps.Step,
   Launch_Wing     => Adaflight.Counting_Steps.Step,
   PID_Controller  => Adaflight.Counting_Steps.Step,
   Runaway_Check   => Adaflight.Counting_Steps.Step,
   PID_Audio       => Adaflight.Counting_Steps.Step,
   Mix_Table       => Adaflight.Counting_Steps.Step,
   Write_Servos    => Adaflight.Counting_Steps.Step,
   Write_Motors    => Adaflight.Counting_Steps.Step,
   Blackbox_Update => Adaflight.Counting_Steps.Step);
