pragma SPARK_Mode (On);
--  The menu navigation over the menu contents, with counting display
--  writes and actions, the shape the proof covers.
with Adaflight.Counting_Steps;
with Adaflight.Menu_Content;
with Adaflight.Menu_Nav;

package Adaflight.Menu_Content_Shape is new Adaflight.Menu_Nav
  (Target_State      => Adaflight.Menu_Content.Target,
   Hooks_Of          => Adaflight.Menu_Content.Hooks_Of,
   Load              => Adaflight.Menu_Content.Load,
   On_Enter          => Adaflight.Menu_Content.On_Enter,
   On_Leave          => Adaflight.Menu_Content.On_Leave,
   On_Display_Update => Adaflight.Menu_Content.On_Display_Update,
   Line_Call         => Adaflight.Menu_Content.Line_Call,
   Set_Value         => Adaflight.Menu_Content.Set_Value,
   Refresh           => Adaflight.Menu_Content.Refresh,
   Lookup            => Adaflight.Menu_Content.Lookup,
   Act               => Adaflight.Counting_Steps.Step_Act,
   Write             => Adaflight.Counting_Steps.Step_Write,
   Write_Char        => Adaflight.Counting_Steps.Step_Write_Char);
