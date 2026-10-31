with Adaflight.STM32.Memory;
with System;
with System.Storage_Elements;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
package body Adaflight.STM32.ADC is
   use Adaflight.STM32.Timers;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Registers is record
      SR    : Unsigned_32;
      CR1   : Unsigned_32;
      CR2   : Unsigned_32;
      SMPR1 : Unsigned_32;
      SMPR2 : Unsigned_32;
      SQR1  : Unsigned_32;
      SQR3  : Unsigned_32;
      JSQR  : Unsigned_32;
      JDR1  : Unsigned_32;
      JDR2  : Unsigned_32;
      DR    : Unsigned_32;
   end record with Volatile;
   for Registers use record
      SR    at 16#00# range 0 .. 31;
      CR1   at 16#04# range 0 .. 31;
      CR2   at 16#08# range 0 .. 31;
      SMPR1 at 16#0C# range 0 .. 31;
      SMPR2 at 16#10# range 0 .. 31;
      SQR1  at 16#2C# range 0 .. 31;
      SQR3  at 16#34# range 0 .. 31;
      JSQR  at 16#38# range 0 .. 31;
      JDR1  at 16#3C# range 0 .. 31;
      JDR2  at 16#40# range 0 .. 31;
      DR    at 16#4C# range 0 .. 31;
   end record;
   Regs : Registers with Import, Address => System'To_Address (16#4001_2000#);
   function Base (Device : Natural) return Unsigned_32 is (16#4001_2000# + 16#100# * Unsigned_32 (Device));
   CCR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4001_2304#);
   RCC_APB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3844#);
   Vrefint_Cal : Interfaces.Unsigned_16
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.Calibration_Address);
   Ts_Cal1     : Interfaces.Unsigned_16
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.Calibration_Address + 2);
   Ts_Cal2     : Interfaces.Unsigned_16
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.Calibration_Address + 4);

   ADC1_Bit       : constant Unsigned_32 := 2 ** 8;
   Prescaler_Div8 : constant Unsigned_32 := 3 * 2 ** 16;
   Converter_On   : constant Unsigned_32 := 2 ** 0;
   Start          : constant Unsigned_32 := 2 ** 30;
   End_Of_Conversion : constant Unsigned_32 := 2 ** 1;
   Cycles_480     : constant Unsigned_32 := 7;
   Scan           : constant Unsigned_32 := 2 ** 8;
   Injected_Discontinuous : constant Unsigned_32 := 2 ** 12;
   Injected_Start : constant Unsigned_32 := 2 ** 22;
   Injected_End   : constant Unsigned_32 := 2 ** 2;
   Sensor_Enable  : constant Unsigned_32 := 2 ** 23;
   Reference_Channel   : constant := 17;
   Temperature_Channel : constant := 16;

   Continuous : constant Unsigned_32 := 2 ** 1;
   DMA_On     : constant Unsigned_32 := 2 ** 8;
   DMA_Repeat : constant Unsigned_32 := 2 ** 9;
   Circular   : constant Unsigned_32 := 2 ** 8;
   Sizes_16   : constant Unsigned_32 := 2 ** 11 or 2 ** 13;

   In_Progress : Boolean := False;

   --  The scan's results, one slot an input, and the stream it owns.
   type Result_Buffer is array (0 .. Max_Inputs - 1) of Interfaces.Unsigned_16 with Alignment => 4;
   pragma Volatile_Components (Result_Buffer);
   Results : Result_Buffer := (others => 0) with Linker_Section => Adaflight.STM32.Platform.DMA_Section;
   Owned   : Natural := 0;

   subtype Channel is Natural range 0 .. 15;

   --  ADC1 and ADC2 reach PA0 to PA7, PB0, PB1 and PC0 to PC5, ADC3 only
   --  PA0 to PA3 and PC0 to PC3.
   function Has_Channel (P : Pin; Device : Natural) return Boolean is
     (case P.Port is
         when Port_A => P.Number <= (if Device = 2 then 3 else 7),
         when Port_B => Device <= 1 and then P.Number <= 1,
         when Port_C => P.Number <= (if Device = 2 then 3 else 5),
         when others => False);

   --  The pin's channel: PA0 to PA7 are 0 to 7, PB0 and PB1 are 8 and 9,
   --  PC0 to PC5 are 10 to 15.
   function Channel_Of (P : Pin) return Channel is
     (case P.Port is
         when Port_A => Channel (P.Number),
         when Port_B => 8 + Channel (P.Number),
         when others => 10 + Channel (P.Number))
     with Pre => Has_Channel (P, 0);

   procedure Init is
   begin
      RCC_APB2ENR := RCC_APB2ENR or ADC1_Bit;
      CCR := (CCR and not (3 * 2 ** 16)) or Prescaler_Div8;
      Regs.CR1 := 0;
      Regs.CR2 := Converter_On;
      Regs.SQR1 := 0;
   end Init;

   procedure Start_Scan
     (Device : Natural; Inputs : Input_Pins; Count : Input_Count; Stream : Adaflight.STM32.Timers.DMA_Stream;
      Has_Stream : Boolean; Taken : Stream_Flags)
   is
      R      : Registers with Import, Address => System'To_Address (Base (Device));
      Number : constant Natural := (Stream.Controller - 1) * 8 + Stream.Stream + 1;
      Ranks  : Unsigned_32 := 0;
   begin
      Owned := 0;
      RCC_APB2ENR := RCC_APB2ENR or Interfaces.Shift_Left (ADC1_Bit, Device);
      CCR := (CCR and not (3 * 2 ** 16)) or Prescaler_Div8;
      if Count = 0 then
         return;
      end if;
      for I in 0 .. Count - 1 loop
         declare
            C : constant Channel := Channel_Of (Inputs (I));
         begin
            GPIO.Enable_Port (Inputs (I).Port);
            GPIO.Set_Analog (Inputs (I));
            if C >= 10 then
               R.SMPR1 := (R.SMPR1 and not Interfaces.Shift_Left (7, 3 * (C - 10)))
                 or Interfaces.Shift_Left (Cycles_480, 3 * (C - 10));
            else
               R.SMPR2 := (R.SMPR2 and not Interfaces.Shift_Left (7, 3 * C)) or Interfaces.Shift_Left (Cycles_480, 3 * C);
            end if;
            Ranks := Ranks or Interfaces.Shift_Left (Unsigned_32 (C), 5 * I);
         end;
      end loop;
      R.CR1 := (R.CR1 and not (3 * 2 ** 24)) or Scan;
      R.CR2 := (R.CR2 and not (2 ** 11 or 16#3F# * 2 ** 24 or Continuous)) or Continuous;
      R.SQR1 := (R.SQR1 and not (16#F# * 2 ** 20)) or Unsigned_32 (Count - 1) * 2 ** 20;
      R.SQR3 := Ranks;
      R.CR2 := R.CR2 or DMA_Repeat;
      R.CR2 := R.CR2 or DMA_On;
      R.CR2 := R.CR2 or Converter_On;
      if not Has_Stream or else Taken (Number) then
         return;
      end if;
      declare
         S : Stream_Registers with Import, Address => Stream_Address (Stream);
      begin
         Enable_DMA (Stream);
         S.CR := 0;
         for Spin in 1 .. 1_000 loop
            exit when (S.CR and EN) = 0;
         end loop;
         Clear_Flags (Stream);
         S.NDTR := 0;
         S.FCR := 0;
         S.PAR := Base (Device) + 16#4C#;
         S.M0AR := Unsigned_32 (System.Storage_Elements.To_Integer (Results'Address));
         S.NDTR := Unsigned_32 (Count);
         S.CR := Interfaces.Shift_Left (Unsigned_32 (Stream.Channel), 25) or PL_High or Sizes_16
           or (if Count > 1 then MINC else 0) or Circular;
         S.CR := S.CR or EN;
      end;
      Owned := Number;
      R.CR2 := R.CR2 or Start;
   end Start_Scan;

   function Scanned (Slot : Natural) return Sample is
     (if Slot < Max_Inputs then Sample (Results (Slot) and 16#FFF#) else 0);

   function Stream_Number return Natural is (Owned);

   procedure Init_Internal is
   begin
      Regs.CR1 := (Regs.CR1 or Scan) and not Injected_Discontinuous;
      CCR := CCR or Sensor_Enable;
      Regs.JSQR := 1 * 2 ** 20 or Temperature_Channel * 2 ** 15 or Reference_Channel * 2 ** 10;
      Regs.SMPR1 := (Regs.SMPR1 and not (7 * 2 ** 18 or 7 * 2 ** 21)) or Cycles_480 * 2 ** 18 or Cycles_480 * 2 ** 21;
   end Init_Internal;

   procedure Start_Internal is
   begin
      Regs.SR := not Injected_End;
      Regs.CR2 := Regs.CR2 or Injected_Start;
      In_Progress := True;
   end Start_Internal;

   procedure Check_Internal (Busy : out Boolean) is
   begin
      if In_Progress and then (Regs.SR and Injected_End) /= 0 then
         In_Progress := False;
      end if;
      Busy := In_Progress;
   end Check_Internal;

   function Reference_Sample return Sample is (Sample (Regs.JDR1 and 16#FFF#));
   function Temperature_Sample return Sample is (Sample (Regs.JDR2 and 16#FFF#));

   function Reference_Calibration return Interfaces.Unsigned_16 is (Vrefint_Cal);
   function Sensor_Calibration_30 return Interfaces.Unsigned_16 is (Ts_Cal1);
   function Sensor_Calibration_110 return Interfaces.Unsigned_16 is (Ts_Cal2);
end Adaflight.STM32.ADC;
