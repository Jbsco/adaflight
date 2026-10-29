--  The board's servo outputs from the timers. Each servo with a pin in the
--  configuration takes its timer channel through the timer pin map's owners
--  in servo order, and the first servo refused ends the setup. The timer
--  counts at 1 MHz over the servo rate's period, and a write sets the
--  channel's compare register to the pulse in microseconds.
with Adaflight.Config_Groups;
with Adaflight.PWM_Output;
package Adaflight.STM32.Servos is
   --  The outputs of the configuration's servo pins.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  A servo's pulse in microseconds; a servo without an output, or an
   --  index past the servos, takes nothing.
   procedure Write (Index : Natural; Value : Float);
private
   Max_Servos : constant := 8;

   --  A write's value within the range the compare value takes.
   function Held (Value : Float) return Adaflight.PWM_Output.Write_Value is
     (Float'Max (Adaflight.PWM_Output.Write_Value'First, Float'Min (Adaflight.PWM_Output.Write_Value'Last, Value)));
end Adaflight.STM32.Servos;
