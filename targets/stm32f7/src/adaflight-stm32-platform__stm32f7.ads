--  The STM32F7's clocks as the generated run-time library sets them, 216
--  MHz with the peripheral buses at a quarter and a half, the timers at
--  twice their bus, and the section the DMA buffers go to: the data tightly
--  coupled memory, which the DMA reaches and the data cache does not cover.
package Adaflight.STM32.Platform is
   Core_Hz       : constant := 216_000_000;
   APB1_Hz       : constant := 54_000_000;
   APB2_Hz       : constant := 108_000_000;
   APB1_Timer_Hz : constant := 108_000_000;
   APB2_Timer_Hz : constant := 216_000_000;
   DMA_Section   : constant String := ".bss.ccm";
end Adaflight.STM32.Platform;
