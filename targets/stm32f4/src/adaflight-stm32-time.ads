--  The time base of the STM32F405 at 168 MHz: milliseconds since boot from
--  the runtime clock, the core's cycle counter for microsecond intervals, and
--  the two delays the drivers take.
with Interfaces;
package Adaflight.STM32.Time is
   use type Interfaces.Unsigned_32;
   Core_Clock_Hz : constant := 168_000_000;
   Cycles_Per_Us : constant := Core_Clock_Hz / 1_000_000;
   --  Starts the cycle counter.
   procedure Init;
   function Millis return Interfaces.Unsigned_32;
   function Cycle_Count return Interfaces.Unsigned_32;
   function Micros_To_Cycles (Micros : Interfaces.Unsigned_32) return Interfaces.Unsigned_32 is
     (Micros * Cycles_Per_Us);
   procedure Delay_Ms (Ms : Natural);
   --  A busy wait on the cycle counter.
   procedure Delay_Us (Us : Natural);
end Adaflight.STM32.Time;
