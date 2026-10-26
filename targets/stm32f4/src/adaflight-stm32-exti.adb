with Interfaces; use Interfaces;
with System;
package body Adaflight.STM32.EXTI is
   type Registers is record
      IMR   : Unsigned_32;
      EMR   : Unsigned_32;
      RTSR  : Unsigned_32;
      FTSR  : Unsigned_32;
      SWIER : Unsigned_32;
      PR    : Unsigned_32;
   end record with Volatile;
   for Registers use record
      IMR   at 16#00# range 0 .. 31;
      EMR   at 16#04# range 0 .. 31;
      RTSR  at 16#08# range 0 .. 31;
      FTSR  at 16#0C# range 0 .. 31;
      SWIER at 16#10# range 0 .. 31;
      PR    at 16#14# range 0 .. 31;
   end record;
   Regs : Registers with Import, Address => System'To_Address (16#4001_3C00#);

   --  The system configuration controller's four external interrupt
   --  configuration registers, four lines each, a port index per nibble.
   type Line_Sources is array (0 .. 3) of Unsigned_32 with Volatile_Components;
   EXTICR : Line_Sources with Import, Address => System'To_Address (16#4001_3808#);
   RCC_APB2ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3844#);
   SYSCFG_Bit : constant Unsigned_32 := 2 ** 14;

   procedure Enable_Rising (P : Pin) is
      Line   : constant Natural := Natural (P.Number);
      Nibble : constant Natural := 4 * (Line mod 4);
      Source : constant Unsigned_32 := Unsigned_32 (Port_Name'Pos (P.Port));
   begin
      RCC_APB2ENR := RCC_APB2ENR or SYSCFG_Bit;
      EXTICR (Line / 4) := (EXTICR (Line / 4) and not Shift_Left (15, Nibble)) or Shift_Left (Source, Nibble);
      Regs.RTSR := Regs.RTSR or Shift_Left (1, Line);
      Regs.FTSR := Regs.FTSR and not Shift_Left (1, Line);
      Regs.PR := Shift_Left (1, Line);
      Regs.IMR := Regs.IMR or Shift_Left (1, Line);
   end Enable_Rising;

   procedure Clear_Pending (Line : Pin_Number) is
   begin
      Regs.PR := Shift_Left (1, Natural (Line));
   end Clear_Pending;
end Adaflight.STM32.EXTI;
