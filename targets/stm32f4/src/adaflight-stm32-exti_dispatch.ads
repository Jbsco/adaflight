--  The handlers of the external interrupt vectors: each takes its enabled and
--  pending lines and calls their callbacks, the highest line first.
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.STM32.EXTI_Dispatch is
   type Callback is access procedure;

   --  The callback of a line, set before the line's interrupt is enabled.
   procedure Register (Line : Pin_Number; C : Callback);
end Adaflight.STM32.EXTI_Dispatch;
