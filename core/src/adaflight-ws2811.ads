--  The WS2811 LED strip's timing and bits: the strip timer's prescaler for a
--  48 MHz count rounded to the nearest, its period at the 800 kHz carrier,
--  the compare values of a one and a zero at two thirds and one third of the
--  period, and a LED's color packed for its format, sent most significant bit
--  first. The SK6812's white channel is the smallest of the three colors.
with Interfaces; use Interfaces;

package Adaflight.WS2811 with SPARK_Mode is

   Timer_Hz   : constant := 48_000_000;
   Carrier_Hz : constant := 800_000;

   --  The LED formats by their numbers in the strip configuration.
   type Format is (GRB, RGB, GRBW);

   --  The prescaler for the 48 MHz count from the timer's clock, none when
   --  the clock is slower.
   function Prescaler (Clock : Unsigned_32) return Unsigned_16
     with Global => null;

   --  The carrier's period in the prescaled counts, in sixteen bits.
   function Period (Clock : Unsigned_32; Prescale : Unsigned_16) return Unsigned_16 is
     (Unsigned_16'Mod ((Clock / (Unsigned_32 (Prescale) + 1)) / Carrier_Hz));

   function Bit_1 (Period : Unsigned_16) return Unsigned_16 is (Period / 3 * 2);
   function Bit_0 (Period : Unsigned_16) return Unsigned_16 is (Period / 3);

   --  A LED's bit count and its color packed in sending order.
   function Bits (F : Format) return Natural is (if F = GRBW then 32 else 24);
   function Packed (F : Format; Red, Green, Blue : Unsigned_8) return Unsigned_32
     with Global => null;

end Adaflight.WS2811;
