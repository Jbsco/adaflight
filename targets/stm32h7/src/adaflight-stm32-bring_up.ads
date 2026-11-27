--  Bring-up checks of the STM32H7 image: rising edges on the first gyro's
--  interrupt pin, counted from its external interrupt line, and update
--  interrupts of TIM1 and TIM15 to TIM17, each counting at 1 kHz.
with Adaflight.STM32.Timers;
package Adaflight.STM32.Bring_Up is
   procedure Watch_Gyro_Interrupt;
   function Edges return Natural;

   subtype Counted_Timer is Adaflight.STM32.Timers.Timer_Name
     with Static_Predicate => Counted_Timer in Adaflight.STM32.Timers.TIM1 | Adaflight.STM32.Timers.TIM15
       | Adaflight.STM32.Timers.TIM16 | Adaflight.STM32.Timers.TIM17;

   procedure Start_Timers;
   function Updates (T : Counted_Timer) return Natural;
end Adaflight.STM32.Bring_Up;
