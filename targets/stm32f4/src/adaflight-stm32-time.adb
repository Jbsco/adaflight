with Ada.Real_Time; use Ada.Real_Time;
with Ada.Unchecked_Conversion;
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

   --  The runtime clock counts ticks from zero at boot, in the 64-bit word
   --  of the pinned toolchain's runtime.
   pragma Warnings (Off, "representation of ""Time"" values may change between GNAT versions");
   function Ticks is new Ada.Unchecked_Conversion (Ada.Real_Time.Time, Unsigned_64);
   pragma Warnings (On, "representation of ""Time"" values may change between GNAT versions");
   Ticks_Per_Us : constant Unsigned_32 := Unsigned_32 (Microseconds (1) / Time_Span_Unit);

   --  N divided by D below 2 ** 16: a long division in 16-bit digits, each
   --  step one 32-bit hardware divide.
   function Divide (N : Unsigned_64; D : Unsigned_32) return Unsigned_64 is
      Q : Unsigned_64 := 0;
      R : Unsigned_32 := 0;
   begin
      for K in reverse 0 .. 3 loop
         declare
            Digit : constant Unsigned_32 := Unsigned_32 (Shift_Right (N, 16 * K) and 16#FFFF#);
            Part  : constant Unsigned_32 := Shift_Left (R, 16) or Digit;
         begin
            Q := Shift_Left (Q, 16) or Unsigned_64 (Part / D);
            R := Part mod D;
         end;
      end loop;
      return Q;
   end Divide;

   function Millis return Unsigned_32 is
     (Unsigned_32 (Divide (Divide (Ticks (Clock), Ticks_Per_Us), 1_000) mod 2 ** 32));

   function Micros return Unsigned_32 is (Unsigned_32 (Divide (Ticks (Clock), Ticks_Per_Us) mod 2 ** 32));

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
