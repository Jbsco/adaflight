--  The SPI buses of the STM32F405 as masters in mode 3, eight bits, most
--  significant bit first, with the select pins driven by the devices: a
--  polled full duplex transfer, and the clock divisor from a clock of 84 MHz.
--  SPI2 and SPI3 run from a bus clock of half that, so their divisor is
--  halved to give the same SPI clock.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.STM32.SPI is
   type Bus is (SPI1, SPI2, SPI3);
   Bus_Clock_Hz : constant := 84_000_000;
   procedure Init (B : Bus; SCK, SDI, SDO : Pin);
   --  Whether the bus was started.
   function Started (B : Bus) return Boolean;
   --  The smallest power of two from 2 to 256 that brings the clock to Hz
   --  or below.
   function Divider (Hz : Interfaces.Unsigned_32) return Interfaces.Unsigned_16;
   --  The SPI clock of a divisor.
   function Clock_Of (Divisor : Interfaces.Unsigned_16) return Interfaces.Unsigned_32;
   procedure Set_Divisor (B : Bus; Divisor : Interfaces.Unsigned_16);
   --  Every byte of Tx out, each byte in to Rx from its first index.
   procedure Transfer (B : Bus; Tx : Byte_Array; Rx : out Byte_Array)
     with Pre => Rx'Length >= Tx'Length;
end Adaflight.STM32.SPI;
