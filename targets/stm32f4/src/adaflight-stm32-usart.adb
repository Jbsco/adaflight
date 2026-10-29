with Ada.Interrupts.Names;
with System;
with Adaflight.Board;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Time;
with Adaflight.STM32.Platform;
package body Adaflight.STM32.USART is
   use type Interfaces.Unsigned_32;
   type Registers is record
      SR   : Unsigned_32;
      DR   : Unsigned_32;
      BRR  : Unsigned_32;
      CR1  : Unsigned_32;
      CR2  : Unsigned_32;
      CR3  : Unsigned_32;
      GTPR : Unsigned_32;
   end record with Volatile;
   for Registers use record
      SR   at 16#00# range 0 .. 31;
      DR   at 16#04# range 0 .. 31;
      BRR  at 16#08# range 0 .. 31;
      CR1  at 16#0C# range 0 .. 31;
      CR2  at 16#10# range 0 .. 31;
      CR3  at 16#14# range 0 .. 31;
      GTPR at 16#18# range 0 .. 31;
   end record;
   Base : constant array (Number) of System.Address :=
     (UART1 => System'To_Address (16#4001_1000#),
      UART2 => System'To_Address (16#4000_4400#),
      UART3 => System'To_Address (16#4000_4800#),
      UART4 => System'To_Address (16#4000_4C00#),
      UART5 => System'To_Address (16#4000_5000#),
      UART6 => System'To_Address (16#4001_1400#));
   Bus_Hz : constant array (Number) of Positive :=
     (UART1 | UART6 => Adaflight.STM32.Platform.APB2_Hz, UART2 | UART3 | UART4 | UART5 => Adaflight.STM32.Platform.APB1_Hz);
   Func : constant array (Number) of GPIO.Alternate_Function :=
     (UART1 | UART2 | UART3 => 7, UART4 | UART5 | UART6 => 8);
   TX : constant array (Number) of Pin :=
     (UART1 => Adaflight.Board.UART1_TX_Pin, UART2 => Adaflight.Board.UART2_TX_Pin,
      UART3 => Adaflight.Board.UART3_TX_Pin, UART4 => Adaflight.Board.UART4_TX_Pin,
      UART5 => Adaflight.Board.UART5_TX_Pin, UART6 => Adaflight.Board.UART6_TX_Pin);
   RX : constant array (Number) of Pin :=
     (UART1 => Adaflight.Board.UART1_RX_Pin, UART2 => Adaflight.Board.UART2_RX_Pin,
      UART3 => Adaflight.Board.UART3_RX_Pin, UART4 => Adaflight.Board.UART4_RX_Pin,
      UART5 => Adaflight.Board.UART5_RX_Pin, UART6 => Adaflight.Board.UART6_RX_Pin);

   function TX_Pin (N : Number) return Pin is (TX (N));
   function RX_Pin (N : Number) return Pin is (RX (N));
   RCC_APB1ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   RCC_APB2ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3844#);

   Receive_Not_Empty : constant Unsigned_32 := 2 ** 5;
   Register_Empty    : constant Unsigned_32 := 2 ** 7;
   Receiver_Enable   : constant Unsigned_32 := 2 ** 2;
   Transmitter       : constant Unsigned_32 := 2 ** 3;
   Receive_Interrupt : constant Unsigned_32 := 2 ** 5;
   Transmit_Interrupt : constant Unsigned_32 := 2 ** 7;
   Enable            : constant Unsigned_32 := 2 ** 13;
   Stop_Bits_2       : constant Unsigned_32 := 2 ** 13;
   Parity_Control    : constant Unsigned_32 := 2 ** 10;
   Word_9_Bits       : constant Unsigned_32 := 2 ** 12;
   Half_Duplex_Select : constant Unsigned_32 := 2 ** 3;

   Ring_Size : constant := 256;
   subtype Ring_Index is Natural range 0 .. Ring_Size - 1;
   --  The received bytes and their times: the interrupt appends while the
   --  ring has room and drops the rest, the take removes from the head.
   type Ring is record
      Bytes : Byte_Array (Ring_Index) := (others => 0);
      Times : Time_Array (Ring_Index) := (others => 0);
      Head  : Ring_Index := 0;
      Fill  : Natural range 0 .. Ring_Size := 0;
   end record;
   type Rings is array (Number) of Ring;

   --  A transmit ring: the bytes queued, the next to send and the count.
   type Send_Ring is record
      Bytes : Byte_Array (Ring_Index) := (others => 0);
      Head  : Ring_Index := 0;
      Fill  : Natural range 0 .. Ring_Size := 0;
   end record;
   type Send_Rings is array (Number) of Send_Ring;

   protected Receivers with Interrupt_Priority => System.Interrupt_Priority'First is
      procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural);
      procedure Queue (N : Number; Data : Byte_Array; Taken : out Natural);
      function Free (N : Number) return Natural;
      function Empty (N : Number) return Boolean;
   private
      procedure Receive (N : Number);
      procedure Send (N : Number);
      procedure Handler_1 with Attach_Handler => Ada.Interrupts.Names.USART1_Interrupt;
      procedure Handler_2 with Attach_Handler => Ada.Interrupts.Names.USART2_Interrupt;
      procedure Handler_3 with Attach_Handler => Ada.Interrupts.Names.USART3_Interrupt;
      procedure Handler_4 with Attach_Handler => Ada.Interrupts.Names.UART4_Interrupt;
      procedure Handler_5 with Attach_Handler => Ada.Interrupts.Names.UART5_Interrupt;
      procedure Handler_6 with Attach_Handler => Ada.Interrupts.Names.USART6_Interrupt;
      Queues : Rings;
      Sends  : Send_Rings;
   end Receivers;

   protected body Receivers is
      procedure Receive (N : Number) is
         Regs : Registers with Import, Address => Base (N);
         Q    : Ring renames Queues (N);
         Now  : Interfaces.Unsigned_32;
         Slot : Ring_Index;
      begin
         while (Regs.SR and Receive_Not_Empty) /= 0 loop
            Now := Time.Micros;
            declare
               Value : constant Unsigned_32 := Regs.DR and 16#FF#;
            begin
               if Q.Fill < Ring_Size then
                  Slot := (Q.Head + Q.Fill) mod Ring_Size;
                  Q.Bytes (Slot) := Byte (Value);
                  Q.Times (Slot) := Now;
                  Q.Fill := Q.Fill + 1;
               end if;
            end;
         end loop;
      end Receive;

      --  The transmit register filled from the ring while the interrupt is
      --  on; an empty ring turns the interrupt off.
      procedure Send (N : Number) is
         Regs : Registers with Import, Address => Base (N);
         Q    : Send_Ring renames Sends (N);
      begin
         if (Regs.CR1 and Transmit_Interrupt) = 0 or else (Regs.SR and Register_Empty) = 0 then
            return;
         end if;
         if Q.Fill = 0 then
            Regs.CR1 := Regs.CR1 and not Transmit_Interrupt;
         else
            Regs.DR := Unsigned_32 (Q.Bytes (Q.Head));
            Q.Head := (Q.Head + 1) mod Ring_Size;
            Q.Fill := Q.Fill - 1;
            if Q.Fill = 0 then
               Regs.CR1 := Regs.CR1 and not Transmit_Interrupt;
            end if;
         end if;
      end Send;

      procedure Queue (N : Number; Data : Byte_Array; Taken : out Natural) is
         Regs : Registers with Import, Address => Base (N);
         Q    : Send_Ring renames Sends (N);
      begin
         Taken := Natural'Min (Data'Length, Ring_Size - Q.Fill);
         for K in 0 .. Taken - 1 loop
            Q.Bytes ((Q.Head + Q.Fill + K) mod Ring_Size) := Data (Data'First + K);
         end loop;
         Q.Fill := Q.Fill + Taken;
         if Q.Fill > 0 then
            Regs.CR1 := Regs.CR1 or Transmit_Interrupt;
         end if;
      end Queue;

      function Free (N : Number) return Natural is (Ring_Size - Sends (N).Fill);

      function Empty (N : Number) return Boolean is
         Regs : Registers with Import, Address => Base (N);
      begin
         return Sends (N).Fill = 0 and then (Regs.SR and Register_Empty) /= 0;
      end Empty;

      procedure Handler_1 is
      begin
         Receive (UART1);
         Send (UART1);
      end Handler_1;
      procedure Handler_2 is
      begin
         Receive (UART2);
         Send (UART2);
      end Handler_2;

      procedure Handler_3 is
      begin
         Receive (UART3);
         Send (UART3);
      end Handler_3;

      procedure Handler_4 is
      begin
         Receive (UART4);
         Send (UART4);
      end Handler_4;

      procedure Handler_5 is
      begin
         Receive (UART5);
         Send (UART5);
      end Handler_5;
      procedure Handler_6 is
      begin
         Receive (UART6);
         Send (UART6);
      end Handler_6;

      procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural) is
         Q : Ring renames Queues (N);
      begin
         Count := Natural'Min (Into'Length, Q.Fill);
         Into := (others => 0);
         Times := (others => 0);
         for K in 0 .. Count - 1 loop
            Into (Into'First + K) := Q.Bytes ((Q.Head + K) mod Ring_Size);
            Times (Times'First + K) := Q.Times ((Q.Head + K) mod Ring_Size);
         end loop;
         Q.Head := (Q.Head + Count) mod Ring_Size;
         Q.Fill := Q.Fill - Count;
      end Take;
   end Receivers;

   --  A half duplex line configures the transmit pin alone at low speed, as
   --  the reference does on the F4, and sets the half duplex selection.
   --  The inverter pins by UART, zero where the board has none.
   Inverter_Tags : constant array (Number) of Natural :=
     (UART1 => Adaflight.Board.Inverter_UART1_Tag, UART2 => Adaflight.Board.Inverter_UART2_Tag,
      UART3 => Adaflight.Board.Inverter_UART3_Tag, UART4 => Adaflight.Board.Inverter_UART4_Tag,
      UART5 => Adaflight.Board.Inverter_UART5_Tag, UART6 => Adaflight.Board.Inverter_UART6_Tag);

   procedure Set_Inverter (N : Number; On : Boolean) is
      Tag : constant Natural := Inverter_Tags (N);
   begin
      if Tag /= 0 then
         declare
            P : constant Pin := (Port => Port_Name'Val (Tag / 16 - 1), Number => Pin_Number (Tag mod 16));
         begin
            GPIO.Enable_Port (P.Port);
            GPIO.Set_Output (P);
            if On then
               GPIO.Set_High (P);
            else
               GPIO.Set_Low (P);
            end if;
         end;
      end if;
   end Set_Inverter;

   procedure Init_Inverters is
   begin
      for N in Number loop
         Set_Inverter (N, False);
      end loop;
   end Init_Inverters;

   Started_With : array (Number) of Settings;

   function Current (N : Number) return Settings is (Started_With (N));

   procedure Init
     (N : Number; Baud : Positive; Two_Stop_Bits : Boolean := False; Line : Half_Duplex := Full_Duplex;
      Even_Parity : Boolean := False; Inverted : Boolean := False)
   is
      Regs : Registers with Import, Address => Base (N);
      --  Sixteen times the baud rate divider, rounded.
      Divider : constant Natural := (Bus_Hz (N) + Baud / 2) / Baud;
   begin
      if not Present (N) then
         return;
      end if;
      Started_With (N) :=
        (Started => True, Baud => Baud, Two_Stop_Bits => Two_Stop_Bits, Line => Line, Even_Parity => Even_Parity,
         Inverted => Inverted);
      Set_Inverter (N, Inverted);
      GPIO.Enable_Port (TX (N).Port);
      if Line.On then
         GPIO.Set_Alternate (TX (N), Func (N), Line.Resistor, Rate => GPIO.Low);
         if not Line.Push_Pull then
            GPIO.Set_Open_Drain (TX (N));
         end if;
      else
         GPIO.Enable_Port (RX (N).Port);
         GPIO.Set_Alternate (TX (N), Func (N));
         GPIO.Set_Alternate (RX (N), Func (N), GPIO.Up);
      end if;
      case N is
         when UART1 => RCC_APB2ENR := RCC_APB2ENR or 2 ** 4;
         when UART6 => RCC_APB2ENR := RCC_APB2ENR or 2 ** 5;
         when UART2 => RCC_APB1ENR := RCC_APB1ENR or 2 ** 17;
         when UART3 => RCC_APB1ENR := RCC_APB1ENR or 2 ** 18;
         when UART4 => RCC_APB1ENR := RCC_APB1ENR or 2 ** 19;
         when UART5 => RCC_APB1ENR := RCC_APB1ENR or 2 ** 20;
      end case;
      Regs.CR1 := 0;
      Regs.BRR := Unsigned_32 (Divider / 16) * 16 + Unsigned_32 (Divider mod 16);
      Regs.CR2 := (if Two_Stop_Bits then Stop_Bits_2 else 0);
      Regs.CR3 := (if Line.On then Half_Duplex_Select else 0);
      Regs.CR1 := (if Even_Parity then Word_9_Bits or Parity_Control else 0)
        or Enable or Transmitter or Receiver_Enable or Receive_Interrupt;
   end Init;

   procedure Put (Into : in out Port; Text : String) is
      Data : Byte_Array (0 .. Text'Length - 1);
   begin
      for I in Data'Range loop
         Data (I) := Byte (Character'Pos (Text (Text'First + I)));
      end loop;
      Put (Into, Data);
   end Put;

   --  Every byte queued, waiting for room while the interrupt drains the ring.
   procedure Put (Into : in out Port; Data : Byte_Array) is
      Next  : Natural := Data'First;
      Taken : Natural;
   begin
      while Next <= Data'Last loop
         Receivers.Queue (Into.Which, Data (Next .. Data'Last), Taken);
         Next := Next + Taken;
      end loop;
   end Put;

   procedure Queue (N : Number; Data : Byte_Array; Taken : out Natural) is
   begin
      Receivers.Queue (N, Data, Taken);
   end Queue;

   function Free (N : Number) return Natural is (Receivers.Free (N));

   function Transmit_Empty (N : Number) return Boolean is (Receivers.Empty (N));

   procedure Take (N : Number; Into : out Byte_Array; Count : out Natural) is
      Times : Time_Array (0 .. Into'Length - 1);
   begin
      Receivers.Take (N, Into, Times, Count);
   end Take;

   procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural) is
   begin
      Receivers.Take (N, Into, Times, Count);
   end Take;

   function Present_Set return Number_List is
      Set   : Number_List (1 .. Number'Pos (Number'Last) + 1);
      Count : Natural := 0;
   begin
      for N in Number loop
         if Present (N) then
            Count := Count + 1;
            Set (Count) := N;
         end if;
      end loop;
      return Set (1 .. Count);
   end Present_Set;
end Adaflight.STM32.USART;
