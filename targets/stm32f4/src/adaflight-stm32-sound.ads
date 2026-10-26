--  The board's beeper: a pin driven high or low, or at a frequency a square
--  wave from the pin's timer channel at half duty, silent when the pin has
--  no channel this driver knows.
with Interfaces;
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.STM32.Sound is
   procedure Init (P : Pin; Frequency : Interfaces.Unsigned_16; Inverted, Open_Drain : Boolean);
   procedure Set (On : Boolean);
end Adaflight.STM32.Sound;
