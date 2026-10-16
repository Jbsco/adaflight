pragma SPARK_Mode (On);
--  The menu draw over counting display writes and hook, the shape the
--  proof covers.
with Adaflight.Counting_Steps;
with Adaflight.Menu_Draw;

package Adaflight.Menu_Draw_Shape is new Adaflight.Menu_Draw
  (Target_State   => Adaflight.Counting_Steps.Menu_Target,
   Write          => Adaflight.Counting_Steps.Step_Write,
   Write_Char     => Adaflight.Counting_Steps.Step_Write_Char,
   Display_Update => Adaflight.Counting_Steps.Step_Update,
   Refresh        => Adaflight.Counting_Steps.Step_Refresh);
