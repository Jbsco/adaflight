with Ada.Interrupts.Names;
with Interfaces.STM32.RCC;
with Interfaces.STM32.USART;
with System;
with Adaflight.STM32.GPIO;

package body Adaflight.STM32.USART is

   use type Interfaces.STM32.Bit;
   use type Interfaces.STM32.UInt9;

   Regs : Interfaces.STM32.USART.USART1_Peripheral renames Interfaces.STM32.USART.USART1_Periph;

   Ring_Size : constant := 256;
   subtype Ring_Index is Natural range 0 .. Ring_Size - 1;

   --  The received bytes: the interrupt appends while the ring has room and
   --  drops the rest, the take removes from the head.
   protected Receiver with Interrupt_Priority => System.Interrupt_Priority'First is
      procedure Take (Into : out Byte_Array; Count : out Natural);
   private
      procedure Handler with Attach_Handler => Ada.Interrupts.Names.USART1_Interrupt;
      Ring : Byte_Array (0 .. Ring_Size - 1) := (others => 0);
      Head : Ring_Index := 0;
      Fill : Natural range 0 .. Ring_Size := 0;
   end Receiver;

   protected body Receiver is

      procedure Handler is
         Value : Interfaces.STM32.UInt9;
      begin
         while Regs.SR.RXNE = 1 loop
            Value := Regs.DR.DR;
            if Fill < Ring_Size then
               Ring ((Head + Fill) mod Ring_Size) := Byte (Value and 16#FF#);
               Fill := Fill + 1;
            end if;
         end loop;
      end Handler;

      procedure Take (Into : out Byte_Array; Count : out Natural) is
      begin
         Count := Natural'Min (Into'Length, Fill);
         Into := (others => 0);
         for K in 0 .. Count - 1 loop
            Into (Into'First + K) := Ring ((Head + K) mod Ring_Size);
         end loop;
         Head := (Head + Count) mod Ring_Size;
         Fill := Fill - Count;
      end Take;

   end Receiver;

   procedure Init (TX, RX : Pin; Baud : Positive) is
      --  Sixteen times the baud rate divider, rounded.
      Divider : constant Natural := (PCLK2_Hz + Baud / 2) / Baud;
   begin
      GPIO.Enable_Port (TX.Port);
      GPIO.Enable_Port (RX.Port);
      GPIO.Set_Alternate (TX, 7);
      GPIO.Set_Alternate (RX, 7, GPIO.Up);
      Interfaces.STM32.RCC.RCC_Periph.APB2ENR.USART1EN := 1;
      Regs.CR1 := (others => <>);
      Regs.BRR := (DIV_Mantissa => Interfaces.STM32.UInt12 (Divider / 16),
                   DIV_Fraction => Interfaces.STM32.UInt4 (Divider mod 16),
                   others       => <>);
      Regs.CR1 := (UE => 1, TE => 1, RE => 1, RXNEIE => 1, others => <>);
   end Init;

   procedure Put (Into : in out Port; Text : String) is
      pragma Unreferenced (Into);
   begin
      for C of Text loop
         loop
            exit when Regs.SR.TXE = 1;
         end loop;
         Regs.DR.DR := Interfaces.STM32.UInt9 (Character'Pos (C));
      end loop;
   end Put;

   procedure Put (Into : in out Port; Data : Byte_Array) is
      pragma Unreferenced (Into);
   begin
      for D of Data loop
         loop
            exit when Regs.SR.TXE = 1;
         end loop;
         Regs.DR.DR := Interfaces.STM32.UInt9 (D);
      end loop;
   end Put;

   procedure Take (Into : out Byte_Array; Count : out Natural) is
   begin
      Receiver.Take (Into, Count);
   end Take;

end Adaflight.STM32.USART;
