with System;
with System.Address_To_Access_Conversions;
with Adaflight.STM32.GPIO;
package body Adaflight.STM32.SPI is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   function Shift_Left (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Left;
   type Registers is record
      CR1     : Unsigned_32;
      CR2     : Unsigned_32;
      SR      : Unsigned_32;
      DR      : Unsigned_32;
      CRCPR   : Unsigned_32;
      RXCRCR  : Unsigned_32;
      TXCRCR  : Unsigned_32;
      I2SCFGR : Unsigned_32;
      I2SPR   : Unsigned_32;
   end record with Volatile;
   for Registers use record
      CR1     at 16#00# range 0 .. 31;
      CR2     at 16#04# range 0 .. 31;
      SR      at 16#08# range 0 .. 31;
      DR      at 16#0C# range 0 .. 31;
      CRCPR   at 16#10# range 0 .. 31;
      RXCRCR  at 16#14# range 0 .. 31;
      TXCRCR  at 16#18# range 0 .. 31;
      I2SCFGR at 16#1C# range 0 .. 31;
      I2SPR   at 16#20# range 0 .. 31;
   end record;

   package Conversions is new System.Address_To_Access_Conversions (Registers);
   Base : constant array (Bus) of System.Address :=
     (SPI1 => System'To_Address (16#4001_3000#),
      SPI2 => System'To_Address (16#4000_3800#),
      SPI3 => System'To_Address (16#4000_3C00#));
   function Regs (B : Bus) return Conversions.Object_Pointer is (Conversions.To_Pointer (Base (B)));

   RCC_APB1RSTR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3820#);
   RCC_APB2RSTR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3824#);
   RCC_APB1ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   RCC_APB2ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3844#);
   Clock_Bit : constant array (Bus) of Unsigned_32 := (SPI1 => 2 ** 12, SPI2 => 2 ** 14, SPI3 => 2 ** 15);

   Clock_Phase_Second : constant Unsigned_32 := 2 ** 0;
   Clock_Idle_High    : constant Unsigned_32 := 2 ** 1;
   Master             : constant Unsigned_32 := 2 ** 2;
   Rate_Shift         : constant := 3;
   Rate_Mask          : constant Unsigned_32 := 7 * 2 ** Rate_Shift;
   Enable             : constant Unsigned_32 := 2 ** 6;
   Internal_Select    : constant Unsigned_32 := 2 ** 8;
   Software_Select    : constant Unsigned_32 := 2 ** 9;
   Receive_Not_Empty  : constant Unsigned_32 := 2 ** 0;
   Transmit_Empty     : constant Unsigned_32 := 2 ** 1;
   Busy               : constant Unsigned_32 := 2 ** 7;

   Function_Of : constant array (Bus) of GPIO.Alternate_Function := (SPI1 | SPI2 => 5, SPI3 => 6);

   Running : array (Bus) of Boolean := (others => False);

   procedure Init (B : Bus; SCK, SDI, SDO : Pin) is
   begin
      case B is
         when SPI1 =>
            RCC_APB2ENR := RCC_APB2ENR or Clock_Bit (B);
            RCC_APB2RSTR := RCC_APB2RSTR or Clock_Bit (B);
            RCC_APB2RSTR := RCC_APB2RSTR and not Clock_Bit (B);
         when SPI2 | SPI3 =>
            RCC_APB1ENR := RCC_APB1ENR or Clock_Bit (B);
            RCC_APB1RSTR := RCC_APB1RSTR or Clock_Bit (B);
            RCC_APB1RSTR := RCC_APB1RSTR and not Clock_Bit (B);
      end case;
      GPIO.Enable_Port (SCK.Port);
      GPIO.Enable_Port (SDI.Port);
      GPIO.Enable_Port (SDO.Port);
      GPIO.Set_Alternate (SCK, Function_Of (B), GPIO.Down);
      GPIO.Set_Alternate (SDI, Function_Of (B), GPIO.Up);
      GPIO.Set_Alternate (SDO, Function_Of (B));
      Regs (B).CR2 := 0;
      Regs (B).CR1 := Master or Clock_Idle_High or Clock_Phase_Second or Software_Select or Internal_Select
        or Shift_Left (2, Rate_Shift);
      Regs (B).CR1 := Regs (B).CR1 or Enable;
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
      Halved  : constant Unsigned_16 := (if B = SPI1 then Divisor else Divisor / 2);
      Bounded : constant Unsigned_16 := Unsigned_16'Max (2, Unsigned_16'Min (256, Halved));
      Bits    : Unsigned_32 := 0;
      Rest    : Unsigned_16 := Bounded / 4;
   begin
      while Rest > 0 loop
         Bits := Bits + 1;
         Rest := Rest / 2;
      end loop;
      Regs (B).CR1 := (Regs (B).CR1 and not Rate_Mask) or Shift_Left (Bits, Rate_Shift);
   end Set_Divisor;

   procedure Transfer (B : Bus; Tx : Byte_Array; Rx : out Byte_Array) is
      R : constant Conversions.Object_Pointer := Regs (B);
   begin
      Rx := (others => 0);
      for I in Tx'Range loop
         while (R.SR and Transmit_Empty) = 0 loop
            null;
         end loop;
         R.DR := Unsigned_32 (Tx (I));
         while (R.SR and Receive_Not_Empty) = 0 loop
            null;
         end loop;
         Rx (Rx'First + (I - Tx'First)) := Byte (R.DR and 16#FF#);
      end loop;
      while (R.SR and Busy) /= 0 loop
         null;
      end loop;
   end Transfer;
end Adaflight.STM32.SPI;
