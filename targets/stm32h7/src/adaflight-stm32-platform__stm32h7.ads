--  The STM32H743's clocks as the generated run-time library sets them, 400
--  MHz with the peripheral buses at 100 MHz and the timers at twice their
--  bus, and the section the DMA buffers go to: the D2 RAM, which the DMA
--  reaches and the cache unit keeps uncached.
package Adaflight.STM32.Platform is
   F4            : constant Boolean := False;
   Core_Hz       : constant := 400_000_000;
   APB1_Hz       : constant := 100_000_000;
   APB2_Hz       : constant := 100_000_000;
   APB1_Timer_Hz : constant := 200_000_000;
   APB2_Timer_Hz : constant := 200_000_000;
   DMA_Section   : constant String := ".bss.dma";
end Adaflight.STM32.Platform;
