--  The host has no interrupt vectors, so a line's callback is never called.
package body Adaflight.STM32.EXTI_Dispatch is
   procedure Register (Line : Pin_Number; C : Callback) is null;
end Adaflight.STM32.EXTI_Dispatch;
