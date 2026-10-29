--  The time base of the STM32F405 at 168 MHz: milliseconds and microseconds
--  since boot from the runtime clock, the core's cycle counter for the
--  scheduler and the microsecond intervals, and the two delays the drivers
--  take.
with Interfaces;
with Adaflight.STM32.Platform;
package Adaflight.STM32.Time is
   use type Interfaces.Unsigned_32;
   Core_Clock_Hz : constant := Adaflight.STM32.Platform.Core_Hz;
   Cycles_Per_Us : constant := Core_Clock_Hz / 1_000_000;
   --  Starts the cycle counter.
   procedure Init;
   function Millis return Interfaces.Unsigned_32;
   function Micros return Interfaces.Unsigned_32;
   function Cycle_Count return Interfaces.Unsigned_32;
   function Micros_To_Cycles (Micros : Interfaces.Unsigned_32) return Interfaces.Unsigned_32 is
     (Micros * Cycles_Per_Us);
   procedure Delay_Ms (Ms : Natural);
   --  A busy wait on the cycle counter.
   procedure Delay_Us (Us : Natural);
end Adaflight.STM32.Time;
