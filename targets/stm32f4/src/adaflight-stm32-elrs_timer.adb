with Ada.Interrupts.Names;
with System;
with Adaflight.Board;
with Adaflight.STM32.Memory;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.ELRS_Timer is
   use type Interfaces.Unsigned_32;
   package T renames Adaflight.STM32.Timers;
   package Names renames Ada.Interrupts.Names;

   --  The board's timer when this unit drives it, else TIM5.
   Driven : constant Natural := (if Adaflight.Board.ELRS_Timer in 3 | 6 then Adaflight.Board.ELRS_Timer else 5);

   TIM6_Base : constant := 16#4000_1000#;
   TIM6_Bit  : constant Interfaces.Unsigned_32 := 2 ** 4;

   Regs : T.Timer_Registers
     with Import,
       Address =>
         (case Driven is
            when 3      => T.Timer_Base (T.TIM3),
            when 6      => System'To_Address (TIM6_Base),
            when others => T.Timer_Base (T.TIM5));
   APB1_Enable : Interfaces.Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_APB1_Enable);

   Vector : constant Ada.Interrupts.Interrupt_ID :=
     (case Driven is
        when 3      => Names.TIM3_Interrupt,
        when 6      => Names.TIM6_DAC_Interrupt,
        when others => Names.TIM5_Interrupt);

   UIE : constant Interfaces.Unsigned_32 := 2 ** 0;
   UIF : constant Interfaces.Unsigned_32 := 2 ** 0;

   On_Update : Handler := null with Atomic;

   protected Update with Interrupt_Priority => System.Interrupt_Priority'First is
   private
      procedure Timer_Update with Attach_Handler => Vector;
   end Update;

   protected body Update is
      procedure Timer_Update is
      begin
         Regs.SR := not UIF;
         if On_Update /= null then
            On_Update.all;
         end if;
      end Timer_Update;
   end Update;

   procedure Init (Number : Natural; H : Handler; Ok : out Boolean) is
   begin
      Ok := Number = Driven;
      if not Ok then
         return;
      end if;
      On_Update := H;
      case Driven is
         when 3      => T.Enable_Clock (T.TIM3);
         when 6      => APB1_Enable := APB1_Enable or TIM6_Bit;
         when others => T.Enable_Clock (T.TIM5);
      end case;
      Regs.DIER := Regs.DIER and not UIE;
      Regs.CR1 := Regs.CR1 and not T.CEN;
      Regs.CNT := 0;
   end Init;

   procedure Set_Time_Base (Max_Period : Natural) is
   begin
      Regs.CR1 := Regs.CR1 and not (2#111_0000# or 2 ** 8 or 2 ** 9);
      Regs.ARR := Interfaces.Unsigned_32 (Max_Period) - 1;
      Regs.PSC := T.Timer_Clock_Hz (T.TIM5) / 1_000_000 - 1;
      Regs.EGR := T.UG;
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
