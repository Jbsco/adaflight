--  SPI1 of the STM32F405 as a master in mode 3, eight bits, most significant
--  bit first, with the select pins driven by the devices: a polled full
--  duplex transfer, and the clock divisor from a bus clock of 84 MHz.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.STM32.SPI is
   Bus_Clock_Hz : constant := 84_000_000;
   procedure Init (SCK, SDI, SDO : Pin);
   --  The smallest power of two from 2 to 256 that brings the bus clock to
   --  Hz or below.
   function Divider (Hz : Interfaces.Unsigned_32) return Interfaces.Unsigned_16;
   procedure Set_Divisor (Divisor : Interfaces.Unsigned_16);
   --  Every byte of Tx out, each byte in to Rx from its first index.
   procedure Transfer (Tx : Byte_Array; Rx : out Byte_Array)
     with Pre => Rx'Length >= Tx'Length;
end Adaflight.STM32.SPI;
