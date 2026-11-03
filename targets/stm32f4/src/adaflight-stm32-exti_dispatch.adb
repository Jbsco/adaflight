with Ada.Interrupts.Names;
with System;
with Adaflight.EXTI_Lines;
with Adaflight.STM32.EXTI;
package body Adaflight.STM32.EXTI_Dispatch is
   package Lines renames Adaflight.EXTI_Lines;
   use type Lines.Line_Mask;

   Callbacks : array (Pin_Number) of Callback := (others => null) with Atomic_Components;

   procedure Register (Line : Pin_Number; C : Callback) is
   begin
      Callbacks (Line) := C;
   end Register;

   procedure Dispatch (V : Lines.Vector) is
      Pending : Lines.Line_Mask;
      Taken   : Lines.Line;
   begin
      EXTI.Take_Pending (Lines.Lines_Of (V), Pending);
      while Pending /= 0 loop
         Lines.Take_Highest (Pending, Taken);
         if Callbacks (Pin_Number (Taken)) /= null then
            Callbacks (Pin_Number (Taken)).all;
         end if;
      end loop;
   end Dispatch;

   protected Handlers with Interrupt_Priority => System.Interrupt_Priority'First is
   private
      procedure Line_0 with Attach_Handler => Ada.Interrupts.Names.EXTI0_Interrupt;
      procedure Line_1 with Attach_Handler => Ada.Interrupts.Names.EXTI1_Interrupt;
      procedure Line_2 with Attach_Handler => Ada.Interrupts.Names.EXTI2_Interrupt;
      procedure Line_3 with Attach_Handler => Ada.Interrupts.Names.EXTI3_Interrupt;
      procedure Line_4 with Attach_Handler => Ada.Interrupts.Names.EXTI4_Interrupt;
      procedure Lines_9_5 with Attach_Handler => Ada.Interrupts.Names.EXTI9_5_Interrupt;
      procedure Lines_15_10 with Attach_Handler => Ada.Interrupts.Names.EXTI15_10_Interrupt;
   end Handlers;

   protected body Handlers is
      procedure Line_0 is
      begin
         Dispatch (Lines.EXTI0);
      end Line_0;

      procedure Line_1 is
      begin
         Dispatch (Lines.EXTI1);
      end Line_1;

      procedure Line_2 is
      begin
         Dispatch (Lines.EXTI2);
      end Line_2;

      procedure Line_3 is
      begin
         Dispatch (Lines.EXTI3);
      end Line_3;

      procedure Line_4 is
      begin
         Dispatch (Lines.EXTI4);
      end Line_4;

      procedure Lines_9_5 is
      begin
         Dispatch (Lines.EXTI9_5);
      end Lines_9_5;

      procedure Lines_15_10 is
      begin
         Dispatch (Lines.EXTI15_10);
      end Lines_15_10;
   end Handlers;
end Adaflight.STM32.EXTI_Dispatch;
