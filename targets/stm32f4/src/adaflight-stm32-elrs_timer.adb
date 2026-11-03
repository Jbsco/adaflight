with Ada.Interrupts.Names;
with System;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.ELRS_Timer is
   use type Interfaces.Unsigned_32;
   package T renames Adaflight.STM32.Timers;

   Regs : T.Timer_Registers with Import, Address => T.Timer_Base (T.TIM5);
   UIE  : constant Interfaces.Unsigned_32 := 2 ** 0;
   UIF  : constant Interfaces.Unsigned_32 := 2 ** 0;

   On_Update : Handler := null with Atomic;

   protected Update with Interrupt_Priority => System.Interrupt_Priority'First is
   private
      procedure TIM5_Update with Attach_Handler => Ada.Interrupts.Names.TIM5_Interrupt;
   end Update;

   protected body Update is
      procedure TIM5_Update is
      begin
         Regs.SR := not UIF;
         if On_Update /= null then
            On_Update.all;
         end if;
      end TIM5_Update;
   end Update;

   procedure Init (Number : Natural; H : Handler; Ok : out Boolean) is
   begin
      Ok := Number = 5;
      if not Ok then
         return;
      end if;
      On_Update := H;
      T.Enable_Clock (T.TIM5);
      Regs.DIER := Regs.DIER and not UIE;
      Regs.CR1 := Regs.CR1 and not T.CEN;
      Regs.CNT := 0;
   end Init;

   procedure Set_Time_Base (Max_Period : Natural) is
   begin
      T.Set_Time_Base (T.TIM5, Interfaces.Unsigned_32 (Max_Period) - 1, T.Timer_Clock_Hz (T.TIM5) / 1_000_000 - 1);
      Regs.SR := not UIF;
   end Set_Time_Base;

   procedure Set_Period (Period : Interfaces.Unsigned_32) is
   begin
      Regs.ARR := Period;
   end Set_Period;

   procedure Reset_Counter is
   begin
      Regs.CNT := 0;
   end Reset_Counter;

   procedure Set_Running (Running : Boolean) is
   begin
      if Running then
         Regs.CR1 := Regs.CR1 or T.CEN;
      else
         Regs.CR1 := Regs.CR1 and not T.CEN;
      end if;
   end Set_Running;

   procedure Enable_Interrupt is
   begin
      Regs.SR := not UIF;
      Regs.DIER := Regs.DIER or UIE;
   end Enable_Interrupt;
end Adaflight.STM32.ELRS_Timer;
