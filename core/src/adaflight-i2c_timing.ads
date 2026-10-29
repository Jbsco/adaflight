--  The I2C timing register of the F7's I2C: the prescaler, the data setup
--  and hold delays and the clock's high and low periods for a bus clock,
--  a target speed and a digital filter length, from the fast mode and fast
--  mode plus limits of the specification and the analog filter's delay,
--  with the first prescaler whose fields fit. The arithmetic is the
--  reference's, in single precision.
with Interfaces; use Interfaces;

package Adaflight.I2C_Timing with SPARK_Mode is

   subtype Clock_Hz is Unsigned_32 range 1_000_000 .. 300_000_000;
   subtype Speed_KHz is Positive range 10 .. 1000;
   subtype Filter_Length is Natural range 0 .. 15;

   function Timing (Clock : Clock_Hz; Speed : Speed_KHz; Filter : Filter_Length) return Unsigned_32
     with Global => null;

end Adaflight.I2C_Timing;
