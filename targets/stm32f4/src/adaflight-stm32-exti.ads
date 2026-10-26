--  The external interrupt lines of the STM32F405: a pin's line armed on its
--  rising edge, and the line's pending flag cleared by its handler.
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.STM32.EXTI is
   procedure Enable_Rising (P : Pin);
   procedure Clear_Pending (Line : Pin_Number);
end Adaflight.STM32.EXTI;
