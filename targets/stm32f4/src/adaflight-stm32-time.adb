with Ada.Real_Time; use Ada.Real_Time;
with Interfaces; use Interfaces;
with System;
package body Adaflight.STM32.Time is
   --  The debug exception and monitor control register enables the trace
   --  unit whose cycle counter the data watchpoint block keeps.
   DEMCR : Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#E000_EDFC#);
   DWT_CTRL : Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#E000_1000#);
   DWT_CYCCNT : Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#E000_1004#);
   Trace_Enable         : constant Unsigned_32 := 2 ** 24;
   Cycle_Counter_Enable : constant Unsigned_32 := 1;

   procedure Init is
   begin
      DEMCR := DEMCR or Trace_Enable;
      DWT_CYCCNT := 0;
      DWT_CTRL := DWT_CTRL or Cycle_Counter_Enable;
   end Init;

   --  The clock since boot as whole seconds and the rest, which keeps the
   --  conversions within the integer range at any uptime.
   procedure Since_Boot (Seconds : out Unsigned_64; Rest : out Time_Span) is
      Count : Seconds_Count;
   begin
      Split (Clock, Count, Rest);
      Seconds := Unsigned_64 (Count);
   end Since_Boot;

   function Millis return Unsigned_32 is
      Seconds : Unsigned_64;
      Rest    : Time_Span;
   begin
      Since_Boot (Seconds, Rest);
      return Unsigned_32 ((Seconds * 1_000 + Unsigned_64 (Rest / Milliseconds (1))) mod 2 ** 32);
   end Millis;

   function Micros return Unsigned_32 is
      Seconds : Unsigned_64;
      Rest    : Time_Span;
   begin
      Since_Boot (Seconds, Rest);
      return Unsigned_32 ((Seconds * 1_000_000 + Unsigned_64 (Rest / Microseconds (1))) mod 2 ** 32);
   end Micros;

   function Cycle_Count return Unsigned_32 is (DWT_CYCCNT);

   procedure Delay_Ms (Ms : Natural) is
   begin
      delay until Clock + Milliseconds (Ms);
   end Delay_Ms;

   procedure Delay_Us (Us : Natural) is
      Start  : constant Unsigned_32 := DWT_CYCCNT;
      Cycles : constant Unsigned_32 := Unsigned_32 (Us) * Cycles_Per_Us;
   begin
      while DWT_CYCCNT - Start < Cycles loop
         null;
      end loop;
   end Delay_Us;
end Adaflight.STM32.Time;
