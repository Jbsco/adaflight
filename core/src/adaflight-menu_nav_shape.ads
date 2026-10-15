pragma SPARK_Mode (On);
--  The menu navigation over counting menus, hooks, actions and display
--  writes, the shape the proof covers.
with Adaflight.Counting_Steps;
with Adaflight.Menu_Nav;

package Adaflight.Menu_Nav_Shape is new Adaflight.Menu_Nav
  (Hooks_Of          => Adaflight.Counting_Steps.Step_Hooks,
   Load              => Adaflight.Counting_Steps.Step_Load,
   On_Enter          => Adaflight.Counting_Steps.Step_Hook,
   On_Leave          => Adaflight.Counting_Steps.Step_Leave,
   On_Display_Update => Adaflight.Counting_Steps.Step_Update,
   Act               => Adaflight.Counting_Steps.Step_Act,
   Write             => Adaflight.Counting_Steps.Step_Write,
   Write_Char        => Adaflight.Counting_Steps.Step_Write_Char);
