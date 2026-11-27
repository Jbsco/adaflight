--  Bring-up checks of the STM32H7 image: rising edges on the first gyro's
--  interrupt pin, counted from its external interrupt line, update
--  interrupts of TIM1 and TIM15 to TIM17, each counting at 1 kHz, memory
--  copies by DMA1 and DMA2, ADC1 conversions to DMA1 through DMAMUX1, and
--  the second gyro's identity read over SPI4, a marker block kept in the
--  configuration sector, and a barometer's chip identifier read over I2C4.
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

   --  The second gyro's identity register read over SPI4 at 1 MHz.
   procedure Read_Gyro_2_Identity;
   function Gyro_2_Identity return Natural;

   --  A marker block written to the configuration sector when the sector
   --  lacks it, whether this start wrote it, and whether the sector holds it.
   procedure Keep_Config_Marker;
   function Config_Marker_Written return Boolean;
   function Config_Marker_Held return Boolean;

   --  A BMP180's chip identifier register read over I2C4 on PB6 and PB7,
   --  zero when the read failed.
   procedure Read_Barometer_Identity;
   function Barometer_Identity return Natural;
end Adaflight.STM32.Bring_Up;
