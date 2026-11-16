--  The gyro clock input: a 32 kHz square wave on the pin a gyro's stored
--  configuration names, from that pin's timer channel, which an ICM-42688-P
--  takes in place of its own oscillator. One clock serves every gyro.
with Interfaces;
package Adaflight.STM32.Gyro_Clock is
   Clock_Hz : constant := 32_000;

   --  The first gyro's clock pin as its stored configuration names it,
   --  zero for none, before that gyro starts.
   procedure Set_Pin (Tag : Interfaces.Unsigned_8);

   --  The clock for a gyro by its ordinal from one. It starts on that pin's
   --  timer channel, taken for the gyro clock input's owner, at the timer
   --  clock over 32 kHz with half of that period high. No pin, no free
   --  timer channel and a period outside 2 .. 65535 start none. Once a
   --  clock runs, a later call succeeds on that clock's pin alone.
   procedure Start (Ordinal : Positive; Started : out Boolean);
end Adaflight.STM32.Gyro_Clock;
