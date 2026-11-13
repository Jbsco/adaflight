--  The host has no timer interrupts: a registration is kept by nobody.
package body Adaflight.STM32.Timer_Dispatch is

   procedure Register (T : Timers.Timer_Name; C : Callback) is null;

end Adaflight.STM32.Timer_Dispatch;
