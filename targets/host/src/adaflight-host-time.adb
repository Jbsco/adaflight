with Ada.Real_Time;
with Adaflight.Host_Clock;
package body Adaflight.STM32.Time is
   use type Ada.Real_Time.Time;
   use type Interfaces.Unsigned_64;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_64 is Interfaces.Unsigned_64;

   --  The microseconds since the image started, at the simulator's rate.
   function Elapsed_Us return Unsigned_64 is (Adaflight.Host_Clock.Elapsed_Ns / 1_000);

   procedure Init is null;

   function Millis return Unsigned_32 is (Unsigned_32 ((Elapsed_Us / 1_000) mod 2 ** 32));

   function Micros return Unsigned_32 is (Unsigned_32 (Elapsed_Us mod 2 ** 32));

   --  A counter at the board's core clock, wrapping as the board's does.
   function Cycle_Count return Unsigned_32 is (Unsigned_32 ((Elapsed_Us * Cycles_Per_Us) mod 2 ** 32));

   --  A delay in the image's time takes its real share at the rate.
   function Real_Span (Us : Natural) return Ada.Real_Time.Time_Span is
     (Ada.Real_Time.To_Time_Span (Duration (Float (Us) / Adaflight.Host_Clock.Rate / 1.0e6)));

   procedure Delay_Ms (Ms : Natural) is
   begin
      delay until Ada.Real_Time.Clock + Real_Span (Ms * 1_000);
   end Delay_Ms;

   procedure Delay_Us (Us : Natural) is
   begin
      delay until Ada.Real_Time.Clock + Real_Span (Us);
   end Delay_Us;
end Adaflight.STM32.Time;
