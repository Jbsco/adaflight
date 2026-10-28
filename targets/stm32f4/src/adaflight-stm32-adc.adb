with System;
with Adaflight.STM32.GPIO;
package body Adaflight.STM32.ADC is
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
   CCR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4001_2304#);
   RCC_APB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3844#);
   Vrefint_Cal : Interfaces.Unsigned_16 with Volatile, Import, Address => System'To_Address (16#1FFF_7A2A#);
   Ts_Cal1     : Interfaces.Unsigned_16 with Volatile, Import, Address => System'To_Address (16#1FFF_7A2C#);
   Ts_Cal2     : Interfaces.Unsigned_16 with Volatile, Import, Address => System'To_Address (16#1FFF_7A2E#);

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

   In_Progress : Boolean := False;

   subtype Channel is Natural range 0 .. 15;

   function Has_Channel (P : Pin) return Boolean is
     (case P.Port is
         when Port_A => P.Number <= 7,
         when Port_B => P.Number <= 1,
         when Port_C => P.Number <= 5,
         when others => False);

   --  The pin's channel: PA0 to PA7 are 0 to 7, PB0 and PB1 are 8 and 9,
   --  PC0 to PC5 are 10 to 15.
   function Channel_Of (P : Pin) return Channel is
     (case P.Port is
         when Port_A => Channel (P.Number),
         when Port_B => 8 + Channel (P.Number),
         when others => 10 + Channel (P.Number))
     with Pre => Has_Channel (P);

   procedure Init is
   begin
      RCC_APB2ENR := RCC_APB2ENR or ADC1_Bit;
      CCR := (CCR and not (3 * 2 ** 16)) or Prescaler_Div8;
      Regs.CR1 := 0;
      Regs.CR2 := Converter_On;
      Regs.SQR1 := 0;
   end Init;

   procedure Enable (P : Pin) is
      C : constant Channel := Channel_Of (P);
   begin
      GPIO.Enable_Port (P.Port);
      GPIO.Set_Analog (P);
      if C >= 10 then
         Regs.SMPR1 := (Regs.SMPR1 and not Interfaces.Shift_Left (7, 3 * (C - 10)))
           or Interfaces.Shift_Left (Cycles_480, 3 * (C - 10));
      else
         Regs.SMPR2 := (Regs.SMPR2 and not Interfaces.Shift_Left (7, 3 * C))
           or Interfaces.Shift_Left (Cycles_480, 3 * C);
      end if;
   end Enable;

   function Read (P : Pin) return Sample is
   begin
      Regs.SQR3 := Unsigned_32 (Channel_Of (P));
      Regs.SR := not End_Of_Conversion;
      Regs.CR2 := Regs.CR2 or Start;
      while (Regs.SR and End_Of_Conversion) = 0 loop
         null;
      end loop;
      return Sample (Regs.DR and 16#FFF#);
   end Read;

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
