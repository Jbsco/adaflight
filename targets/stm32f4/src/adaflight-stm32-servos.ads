--  The board's servo outputs from the timers. Each servo with a pin in the
--  configuration takes its timer channel through the timer pin map's owners
--  in servo order, and the first servo refused ends the setup. The timer
--  counts at 1 MHz over the servo rate's period, and a write sets the
--  channel's compare register to the pulse in microseconds.
with Interfaces;
with Adaflight.Config_Groups;
package Adaflight.STM32.Servos is
   --  The outputs of the configuration's servo pins.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  A servo's pulse in microseconds; a servo without an output, or an
   --  index past the servos, takes nothing.
   procedure Write (Index : Natural; Value : Float);
private
   use Interfaces;

   Max_Servos : constant := 8;

   --  The timer period of a servo rate in hertz, in 1 MHz counts held to
   --  sixteen bits.
   function Period_Of (Rate : Unsigned_16) return Unsigned_16 is
     (if Rate = 0 then 0 else Unsigned_16'Mod (1_000_000 / Unsigned_32 (Rate)));

   --  A pulse rounded to the nearest with ties to even, as the 32-bit signed
   --  value the compare register takes; a value past that range takes its
   --  bound.
   function Pulse_Of (Value : Float) return Unsigned_32 is
     (if Value >= -2.0 ** 31 and then Value < 2.0 ** 31
      then Unsigned_32'Mod (Integer_64 (Float'Unbiased_Rounding (Value)))
      elsif Value > 0.0 then 16#7FFF_FFFF#
      elsif Value < 0.0 then 16#8000_0000#
      else 0);
end Adaflight.STM32.Servos;
