pragma SPARK_Mode (On);
--  The menu navigation over counting menus, hooks, actions and display
--  writes, the shape the proof covers.
with Adaflight.Counting_Steps;
with Adaflight.Menu_Nav;

package Adaflight.Menu_Nav_Shape is new Adaflight.Menu_Nav
  (Hooks_Of          => Adaflight.Counting_Steps.Step_Hooks,
   Load              => Adaflight.Counting_Steps.Step_Load,
   On_Enter          => Adaflight.Counting_Steps.Step_Enter,
   On_Leave          => Adaflight.Counting_Steps.Step_Leave,
   On_Display_Update => Adaflight.Counting_Steps.Step_Update,
   Line_Call         => Adaflight.Counting_Steps.Step_Call,
   Set_Value         => Adaflight.Counting_Steps.Step_Set_Value,
   Lookup            => Adaflight.Counting_Steps.Step_Lookup,
   Act               => Adaflight.Counting_Steps.Step_Act,
   Write             => Adaflight.Counting_Steps.Step_Write,
   Write_Char        => Adaflight.Counting_Steps.Step_Write_Char);
