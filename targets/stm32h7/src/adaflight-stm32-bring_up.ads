--  Bring-up checks of the STM32H7 image: rising edges on the first gyro's
--  interrupt pin, counted from its external interrupt line, update
--  interrupts of TIM1 and TIM15 to TIM17, each counting at 1 kHz, memory
--  copies by DMA1 and DMA2, and ADC1 conversions to DMA1 through DMAMUX1.
with Adaflight.STM32.Timers;
package Adaflight.STM32.Bring_Up is
   procedure Watch_Gyro_Interrupt;
   function Edges return Natural;

   subtype Counted_Timer is Adaflight.STM32.Timers.Timer_Name
     with Static_Predicate => Counted_Timer in Adaflight.STM32.Timers.TIM1 | Adaflight.STM32.Timers.TIM15
       | Adaflight.STM32.Timers.TIM16 | Adaflight.STM32.Timers.TIM17;

   procedure Start_Timers;
   function Updates (T : Counted_Timer) return Natural;

   --  A block of words copied by each DMA controller from memory to memory,
   --  and whether each copy matches its source.
   procedure Copy_By_DMA;
   function Copied (Controller : Positive) return Boolean;

   --  ADC1 converting without pause, each result sent by its DMAMUX1 request
   --  to DMA1 stream 1, and the transfers that stream has left.
   procedure Start_ADC_DMA;
   function ADC_Transfers_Left return Natural;
end Adaflight.STM32.Bring_Up;
