with System;
with System.Storage_Elements;
with System.Address_To_Access_Conversions;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Memory;
--  The STM32H7's SPI: eight-bit frames with one frame per FIFO threshold,
--  the pins held by their alternate function while the bus is off, and each
--  transfer started for its length and ended once the bus reports it sent.
--  Every bus runs from a 100 MHz kernel clock, so no divisor is halved.
package body Adaflight.STM32.SPI is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   function Shift_Left (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Left;
   type Registers is record
      CR1  : Unsigned_32;
      CR2  : Unsigned_32;
      CFG1 : Unsigned_32;
      CFG2 : Unsigned_32;
      IER  : Unsigned_32;
      SR   : Unsigned_32;
      IFCR : Unsigned_32;
   end record with Volatile;
   for Registers use record
      CR1  at 16#00# range 0 .. 31;
      CR2  at 16#04# range 0 .. 31;
      CFG1 at 16#08# range 0 .. 31;
      CFG2 at 16#0C# range 0 .. 31;
      IER  at 16#10# range 0 .. 31;
      SR   at 16#14# range 0 .. 31;
      IFCR at 16#18# range 0 .. 31;
   end record;

   package Conversions is new System.Address_To_Access_Conversions (Registers);
   Base : constant array (Bus) of System.Address :=
     (SPI1 => System'To_Address (16#4001_3000#),
      SPI2 => System'To_Address (16#4000_3800#),
      SPI3 => System'To_Address (16#4000_3C00#),
      SPI4 => System'To_Address (16#4001_3400#),
      SPI5 => System'To_Address (16#4001_5000#),
      SPI6 => System'To_Address (16#5800_1400#));
   function Regs (B : Bus) return Conversions.Object_Pointer is (Conversions.To_Pointer (Base (B)));

   RCC_APB1RSTR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_APB1_Reset);
   RCC_APB2RSTR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_APB2_Reset);
   RCC_APB4RSTR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_449C#);
   RCC_APB1ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_APB1_Enable);
   RCC_APB2ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_APB2_Enable);
   RCC_APB4ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44F4#);
   Clock_Bit : constant array (Bus) of Unsigned_32 :=
     (SPI1 => 2 ** 12, SPI2 => 2 ** 14, SPI3 => 2 ** 15, SPI4 => 2 ** 13, SPI5 => 2 ** 20, SPI6 => 2 ** 5);

   Bus_On          : constant Unsigned_32 := 2 ** 0;
   Start           : constant Unsigned_32 := 2 ** 9;
   Internal_Select : constant Unsigned_32 := 2 ** 12;
   Data_Size_8     : constant Unsigned_32 := 7;
   Rate_Shift      : constant := 28;
   Rate_Mask       : constant Unsigned_32 := 7 * 2 ** Rate_Shift;
   Master          : constant Unsigned_32 := 2 ** 22;
   Clock_Phase_Second : constant Unsigned_32 := 2 ** 24;
   Clock_Idle_High : constant Unsigned_32 := 2 ** 25;
   Software_Select : constant Unsigned_32 := 2 ** 26;
   Keep_Pins       : constant Unsigned_32 := 2 ** 31;
   Receive_Ready   : constant Unsigned_32 := 2 ** 0;
   Transmit_Ready  : constant Unsigned_32 := 2 ** 1;
   Transfer_Ended  : constant Unsigned_32 := 2 ** 3;
   Clear_Ended     : constant Unsigned_32 := 2 ** 3;
   Clear_Filled    : constant Unsigned_32 := 2 ** 4;
   Most_Per_Start  : constant := 16#FFFF#;

   --  A bus pin's alternate function: SPI3's data out takes AF7 on PB2 and
   --  PB5 and AF5 on PD6, and SPI6 takes AF5 on port G and AF8 elsewhere.
   function Function_Of (B : Bus; P : Pin) return GPIO.Alternate_Function is
     (case B is
         when SPI3 =>
           (if P = (Port_B, 2) or else P = (Port_B, 5) then 7 elsif P = (Port_D, 6) then 5 else 6),
         when SPI6 => (if P.Port = Port_G then 5 else 8),
         when SPI1 | SPI2 | SPI4 | SPI5 => 5);

   --  The data registers accessed as one byte, since a word access would
   --  move four frames.
   Transmit_Offset : constant System.Storage_Elements.Storage_Offset := 16#20#;
   Receive_Offset  : constant System.Storage_Elements.Storage_Offset := 16#30#;
   function Data_Byte (Regs_Address : System.Address) return Byte is
      D : Byte with Import, Volatile, Address => System.Storage_Elements."+" (Regs_Address, Receive_Offset);
   begin
      return D;
   end Data_Byte;
   procedure Set_Data_Byte (Regs_Address : System.Address; Value : Byte) is
      D : Byte with Import, Volatile, Address => System.Storage_Elements."+" (Regs_Address, Transmit_Offset);
   begin
      D := Value;
   end Set_Data_Byte;

   Running : array (Bus) of Boolean := (others => False);

   procedure Init (B : Bus; SCK, SDI, SDO : Pin) is
   begin
      case B is
         when SPI1 | SPI4 | SPI5 =>
            RCC_APB2ENR := RCC_APB2ENR or Clock_Bit (B);
            RCC_APB2RSTR := RCC_APB2RSTR or Clock_Bit (B);
            RCC_APB2RSTR := RCC_APB2RSTR and not Clock_Bit (B);
         when SPI2 | SPI3 =>
            RCC_APB1ENR := RCC_APB1ENR or Clock_Bit (B);
            RCC_APB1RSTR := RCC_APB1RSTR or Clock_Bit (B);
            RCC_APB1RSTR := RCC_APB1RSTR and not Clock_Bit (B);
         when SPI6 =>
            RCC_APB4ENR := RCC_APB4ENR or Clock_Bit (B);
            RCC_APB4RSTR := RCC_APB4RSTR or Clock_Bit (B);
            RCC_APB4RSTR := RCC_APB4RSTR and not Clock_Bit (B);
      end case;
      GPIO.Enable_Port (SCK.Port);
      GPIO.Enable_Port (SDI.Port);
      GPIO.Enable_Port (SDO.Port);
      GPIO.Set_Alternate (SCK, Function_Of (B, SCK), GPIO.Down);
      GPIO.Set_Alternate (SDI, Function_Of (B, SDI), GPIO.Up);
      GPIO.Set_Alternate (SDO, Function_Of (B, SDO));
      Regs (B).CR1 := Internal_Select;
      Regs (B).CFG1 := Data_Size_8 or Shift_Left (2, Rate_Shift);
      Regs (B).CFG2 := Keep_Pins or Master or Software_Select or Clock_Idle_High or Clock_Phase_Second;
      Running (B) := True;
   end Init;

   function Started (B : Bus) return Boolean is (Running (B));

   function Divider (Hz : Unsigned_32) return Unsigned_16 is
      Clock   : Unsigned_32 := Bus_Clock_Hz / 2;
      Divisor : Unsigned_16 := 2;
   begin
      while Clock > Hz and then Divisor < 256 loop
         Divisor := Divisor * 2;
         Clock := Clock / 2;
      end loop;
      return Divisor;
   end Divider;

   function Clock_Of (Divisor : Unsigned_16) return Unsigned_32 is
     (Bus_Clock_Hz / Unsigned_32 (Unsigned_16'Max (1, Divisor)));

   procedure Set_Divisor (B : Bus; Divisor : Unsigned_16) is
      Bounded : constant Unsigned_16 := Unsigned_16'Max (2, Unsigned_16'Min (256, Divisor));
      Bits    : Unsigned_32 := 0;
      Rest    : Unsigned_16 := Bounded / 4;
   begin
      while Rest > 0 loop
         Bits := Bits + 1;
         Rest := Rest / 2;
      end loop;
      Regs (B).CFG1 := (Regs (B).CFG1 and not Rate_Mask) or Shift_Left (Bits, Rate_Shift);
   end Set_Divisor;

   procedure Set_Mode (B : Bus; Leading_Edge : Boolean) is
      Bits : constant Unsigned_32 := Clock_Idle_High or Clock_Phase_Second;
   begin
      Regs (B).CFG2 := (if Leading_Edge then Regs (B).CFG2 and not Bits else Regs (B).CFG2 or Bits);
   end Set_Mode;

   procedure Transfer (B : Bus; Tx : Byte_Array; Rx : out Byte_Array) is
      R     : constant Conversions.Object_Pointer := Regs (B);
      First : Integer := Tx'First;
   begin
      Rx := (others => 0);
      while First <= Tx'Last loop
         declare
            Last : constant Integer :=
              (if Tx'Last - First >= Most_Per_Start then First + Most_Per_Start - 1 else Tx'Last);
         begin
            R.CR2 := Unsigned_32 (Last - First + 1);
            R.CR1 := R.CR1 or Bus_On;
            R.CR1 := R.CR1 or Start;
            for I in First .. Last loop
               while (R.SR and Transmit_Ready) = 0 loop
                  null;
               end loop;
               Set_Data_Byte (R.all'Address, Tx (I));
               while (R.SR and Receive_Ready) = 0 loop
                  null;
               end loop;
               Rx (Rx'First + (I - Tx'First)) := Data_Byte (R.all'Address);
            end loop;
            while (R.SR and Transfer_Ended) = 0 loop
               null;
            end loop;
            R.IFCR := Clear_Ended or Clear_Filled;
            R.CR1 := R.CR1 and not Bus_On;
            First := Last + 1;
         end;
      end loop;
   end Transfer;
end Adaflight.STM32.SPI;
