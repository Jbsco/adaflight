--  The STM32F4's clocks as the run-time library sets them, 168 MHz with the
--  peripheral buses at a quarter and a half, the timers at twice their bus,
--  and the section the DMA buffers go to, the main RAM on the F4, whose
--  core coupled memory the DMA cannot reach.
package Adaflight.STM32.Platform is
   Core_Hz       : constant := 168_000_000;
   APB1_Hz       : constant := 42_000_000;
   APB2_Hz       : constant := 84_000_000;
   APB1_Timer_Hz : constant := 84_000_000;
   APB2_Timer_Hz : constant := 168_000_000;
   DMA_Section   : constant String := ".bss";
end Adaflight.STM32.Platform;
