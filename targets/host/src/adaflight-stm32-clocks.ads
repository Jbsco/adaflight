--  The clocks the host image stands in for: an STM32F405's, as the board
--  crates read them from their generated package.
package Adaflight.STM32.Clocks is
   Core_Hz : constant := 168_000_000;
   APB1_Hz : constant := 42_000_000;
   APB2_Hz : constant := 84_000_000;
end Adaflight.STM32.Clocks;
