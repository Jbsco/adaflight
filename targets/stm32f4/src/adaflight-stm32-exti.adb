with Interfaces; use Interfaces;
with System;
with Adaflight.STM32.Memory;
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
      IMR   at Adaflight.STM32.Memory.EXTI_IMR range 0 .. 31;
      EMR   at Adaflight.STM32.Memory.EXTI_EMR range 0 .. 31;
      RTSR  at Adaflight.STM32.Memory.EXTI_RTSR range 0 .. 31;
      FTSR  at Adaflight.STM32.Memory.EXTI_FTSR range 0 .. 31;
      SWIER at Adaflight.STM32.Memory.EXTI_SWIER range 0 .. 31;
      PR    at Adaflight.STM32.Memory.EXTI_PR range 0 .. 31;
   end record;
   Regs : Registers with Import, Address => System'To_Address (Adaflight.STM32.Memory.EXTI_Base);

   --  The system configuration controller's four external interrupt
   --  configuration registers, four lines each, a port index per nibble.
   type Line_Sources is array (0 .. 3) of Unsigned_32 with Volatile_Components;
   EXTICR : Line_Sources with Import, Address => System'To_Address (Adaflight.STM32.Memory.SYSCFG_Base + 16#08#);
   RCC_SYSCFG_ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_SYSCFG_Enable);
   SYSCFG_Bit : constant Unsigned_32 := 2 ** Adaflight.STM32.Memory.SYSCFG_Enable_Bit;

   --  The pin's port as its line's source.
   procedure Route (P : Pin) is
      Line   : constant Natural := Natural (P.Number);
      Nibble : constant Natural := 4 * (Line mod 4);
      Source : constant Unsigned_32 := Unsigned_32 (Port_Name'Pos (P.Port));
   begin
      RCC_SYSCFG_ENR := RCC_SYSCFG_ENR or SYSCFG_Bit;
      EXTICR (Line / 4) := (EXTICR (Line / 4) and not Shift_Left (15, Nibble)) or Shift_Left (Source, Nibble);
   end Route;

   procedure Enable_Rising (P : Pin) is
      Line : constant Natural := Natural (P.Number);
   begin
      Route (P);
      Regs.RTSR := Regs.RTSR or Shift_Left (1, Line);
      Regs.FTSR := Regs.FTSR and not Shift_Left (1, Line);
      Regs.PR := Shift_Left (1, Line);
      Regs.IMR := Regs.IMR or Shift_Left (1, Line);
   end Enable_Rising;

   procedure Configure_Falling (P : Pin) is
      Line : constant Natural := Natural (P.Number);
   begin
      Regs.IMR := Regs.IMR and not Shift_Left (1, Line);
      Route (P);
      Regs.FTSR := Regs.FTSR or Shift_Left (1, Line);
      Regs.RTSR := Regs.RTSR and not Shift_Left (1, Line);
      Regs.PR := Shift_Left (1, Line);
   end Configure_Falling;

   procedure Unmask (P : Pin) is
   begin
      Regs.IMR := Regs.IMR or Shift_Left (1, Natural (P.Number));
   end Unmask;

   procedure Mask (P : Pin) is
   begin
      Regs.IMR := Regs.IMR and not Shift_Left (1, Natural (P.Number));
   end Mask;

   procedure Take_Pending (Mask : Adaflight.EXTI_Lines.Line_Mask; Active : out Adaflight.EXTI_Lines.Line_Mask) is
      Lines : constant Unsigned_32 := Regs.IMR and Regs.PR and Unsigned_32 (Mask);
   begin
      Regs.PR := Lines;
      Active := Adaflight.EXTI_Lines.Line_Mask (Lines);
   end Take_Pending;
end Adaflight.STM32.EXTI;
