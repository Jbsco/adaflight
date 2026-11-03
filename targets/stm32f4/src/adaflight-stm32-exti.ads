--  The external interrupt lines of the STM32F405: a pin's line armed on its
--  rising edge, or set to its falling edge and left masked, a line masked
--  and unmasked, and a vector's enabled and pending lines taken with their
--  pending flags cleared.
with Adaflight.EXTI_Lines;
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.STM32.EXTI is
   procedure Enable_Rising (P : Pin);
   procedure Configure_Falling (P : Pin);
   procedure Unmask (P : Pin);
   procedure Mask (P : Pin);
   procedure Take_Pending (Mask : Adaflight.EXTI_Lines.Line_Mask; Active : out Adaflight.EXTI_Lines.Line_Mask);
end Adaflight.STM32.EXTI;
