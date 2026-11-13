with Ada.Interrupts.Names;
with System;
package body Adaflight.STM32.Timer_Dispatch is
   use Timers;

   Callbacks : array (Timer_Name) of Callback := (others => null) with Atomic_Components;

   procedure Register (T : Timer_Name; C : Callback) is
   begin
      Callbacks (T) := C;
   end Register;

   procedure Call (T : Timer_Name) is
      C : constant Callback := Callbacks (T);
   begin
      if C /= null then
         C.all (T);
      end if;
   end Call;

   --  TIM1's update and capture interrupts by number: the STM32F7 run time's
   --  names give the update the break's number and leave the capture out.
   TIM1_Update_ID  : constant Ada.Interrupts.Interrupt_ID := 25;
   TIM1_Capture_ID : constant Ada.Interrupts.Interrupt_ID := 27;

   protected Handlers with Interrupt_Priority => System.Interrupt_Priority'Last is
   private
      procedure TIM1_Update with Attach_Handler => TIM1_Update_ID;
      procedure TIM1_Capture with Attach_Handler => TIM1_Capture_ID;
      procedure TIM9_Any with Attach_Handler => Ada.Interrupts.Names.TIM1_BRK_TIM9_Interrupt;
      procedure TIM11_Any with Attach_Handler => Ada.Interrupts.Names.TIM1_TRG_COM_TIM11_Interrupt;
      procedure TIM2_Any with Attach_Handler => Ada.Interrupts.Names.TIM2_Interrupt;
      procedure TIM3_Any with Attach_Handler => Ada.Interrupts.Names.TIM3_Interrupt;
      procedure TIM4_Any with Attach_Handler => Ada.Interrupts.Names.TIM4_Interrupt;
      procedure TIM8_Update with Attach_Handler => Ada.Interrupts.Names.TIM8_UP_TIM13_Interrupt;
      procedure TIM8_Capture with Attach_Handler => Ada.Interrupts.Names.TIM8_CC_Interrupt;
      procedure TIM12_Any with Attach_Handler => Ada.Interrupts.Names.TIM8_BRK_TIM12_Interrupt;
      procedure TIM14_Any with Attach_Handler => Ada.Interrupts.Names.TIM8_TRG_COM_TIM14_Interrupt;
   end Handlers;

   protected body Handlers is

      procedure TIM1_Update is
      begin
         Call (TIM1);
         Call (TIM10);
      end TIM1_Update;

      procedure TIM1_Capture is
      begin
         Call (TIM1);
      end TIM1_Capture;

      procedure TIM9_Any is
      begin
         Call (TIM9);
      end TIM9_Any;

      procedure TIM11_Any is
      begin
         Call (TIM11);
      end TIM11_Any;

      procedure TIM2_Any is
      begin
         Call (TIM2);
      end TIM2_Any;

      procedure TIM3_Any is
      begin
         Call (TIM3);
      end TIM3_Any;

      procedure TIM4_Any is
      begin
         Call (TIM4);
      end TIM4_Any;

      procedure TIM8_Update is
      begin
         Call (TIM8);
         Call (TIM13);
      end TIM8_Update;

      procedure TIM8_Capture is
      begin
         Call (TIM8);
      end TIM8_Capture;

      procedure TIM12_Any is
      begin
         Call (TIM12);
      end TIM12_Any;

      procedure TIM14_Any is
      begin
         Call (TIM14);
      end TIM14_Any;

   end Handlers;

end Adaflight.STM32.Timer_Dispatch;
