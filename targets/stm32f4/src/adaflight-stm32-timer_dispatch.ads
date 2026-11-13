--  The timer interrupts a unit may take for a while: one protected object
--  attaches the vectors of TIM1 to TIM4 and TIM8 to TIM14 and calls the
--  procedure registered for the timer that interrupts. Its handlers run above
--  the board's other interrupt handlers, so a UART's or the USB port's work
--  does not delay a bit clock's tick. TIM5's vector is the ExpressLRS
--  timer's.
with Adaflight.STM32.Timers;
package Adaflight.STM32.Timer_Dispatch is
   package Timers renames Adaflight.STM32.Timers;
   use type Timers.Timer_Name;

   type Callback is access procedure (T : Timers.Timer_Name);

   --  Whether a timer's interrupts can be registered for.
   function Served (T : Timers.Timer_Name) return Boolean is (T /= Timers.TIM5);

   --  A timer's interrupts given to a procedure, which runs in the handler
   --  and clears the flags it serves, or to none. One procedure per timer.
   procedure Register (T : Timers.Timer_Name; C : Callback);

end Adaflight.STM32.Timer_Dispatch;
