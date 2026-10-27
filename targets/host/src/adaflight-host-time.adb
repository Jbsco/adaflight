with Ada.Real_Time;
package body Adaflight.STM32.Time is
   use type Ada.Real_Time.Time;
   use type Interfaces.Unsigned_64;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_64 is Interfaces.Unsigned_64;

   Epoch : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   --  The microseconds since the image started.
   function Elapsed_Us return Unsigned_64 is
     (Unsigned_64 (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Epoch) * 1_000_000));

   procedure Init is null;

   function Millis return Unsigned_32 is (Unsigned_32 ((Elapsed_Us / 1_000) mod 2 ** 32));

   function Micros return Unsigned_32 is (Unsigned_32 (Elapsed_Us mod 2 ** 32));

   --  A counter at the board's core clock, wrapping as the board's does.
   function Cycle_Count return Unsigned_32 is (Unsigned_32 ((Elapsed_Us * Cycles_Per_Us) mod 2 ** 32));

   procedure Delay_Ms (Ms : Natural) is
   begin
      delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (Ms);
   end Delay_Ms;

   procedure Delay_Us (Us : Natural) is
   begin
      delay until Ada.Real_Time.Clock + Ada.Real_Time.Microseconds (Us);
   end Delay_Us;
end Adaflight.STM32.Time;
