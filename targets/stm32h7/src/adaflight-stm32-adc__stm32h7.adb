with Ada.Real_Time;
with System;
with System.Storage_Elements;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Memory;
with Adaflight.STM32.Platform;
--  The STM32H743's converters: ADC1 and ADC2 and ADC3 at a quarter of the
--  200 MHz bus clock, each powered up, calibrated and enabled before use,
--  12 bits after 387.5 sample cycles, a continuous scan into a circular DMA
--  stream, and ADC3's injected sequence for the internal reference and the
--  temperature sensor. The factory calibration words are 16-bit readings,
--  shifted to 12 bits.
package body Adaflight.STM32.ADC is
   use Adaflight.STM32.Timers;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Registers is record
      ISR, CR, CFGR, SMPR1, SMPR2, PCSEL, SQR1, DR, JSQR, JDR1, JDR2 : Unsigned_32;
   end record with Volatile;
   for Registers use record
      ISR   at 16#00# range 0 .. 31;
      CR    at 16#08# range 0 .. 31;
      CFGR  at 16#0C# range 0 .. 31;
      SMPR1 at 16#14# range 0 .. 31;
      SMPR2 at 16#18# range 0 .. 31;
      PCSEL at 16#1C# range 0 .. 31;
      SQR1  at 16#30# range 0 .. 31;
      DR    at 16#40# range 0 .. 31;
      JSQR  at 16#4C# range 0 .. 31;
      JDR1  at 16#80# range 0 .. 31;
      JDR2  at 16#84# range 0 .. 31;
   end record;

   subtype Device_Number is Natural range 0 .. 2;
   Base : constant array (Device_Number) of Unsigned_32 := (16#4002_2000#, 16#4002_2100#, 16#5802_6000#);
   Internal : Registers with Import, Address => System'To_Address (16#5802_6000#);
   CCR_12 : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_2308#);
   CCR_3  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_6308#);
   RCC_AHB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44D8#);
   RCC_AHB4ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44E0#);
   DBGMCU_IDCODE : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5C00_1000#);
   Vrefint_Cal : Interfaces.Unsigned_16
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.Calibration_Address);
   Ts_Cal1 : Interfaces.Unsigned_16 with Volatile, Import, Address => System'To_Address (16#1FF1_E820#);
   Ts_Cal2 : Interfaces.Unsigned_16 with Volatile, Import, Address => System'To_Address (16#1FF1_E840#);

   ADC12_Enable : constant Unsigned_32 := 2 ** 5;
   ADC3_Enable  : constant Unsigned_32 := 2 ** 24;
   Clock_Quarter : constant Unsigned_32 := 2#11# * 2 ** 16;
   Reference_On  : constant Unsigned_32 := 2 ** 22;
   Sensor_On     : constant Unsigned_32 := 2 ** 23;

   Enable        : constant Unsigned_32 := 2 ** 0;
   Regular_Start : constant Unsigned_32 := 2 ** 2;
   Injected_Start : constant Unsigned_32 := 2 ** 3;
   Boost_Mask    : constant Unsigned_32 := 2#11# * 2 ** 8;
   Regulator_On  : constant Unsigned_32 := 2 ** 28;
   Deep_Power_Down : constant Unsigned_32 := 2 ** 29;
   Calibrate     : constant Unsigned_32 := 2 ** 31;
   Ready         : constant Unsigned_32 := 2 ** 0;
   Injected_End  : constant Unsigned_32 := 2 ** 6;

   Circular_DMA : constant Unsigned_32 := 2#11#;
   Bits_12      : constant Unsigned_32 := 2#010# * 2 ** 2;
   Overwrite    : constant Unsigned_32 := 2 ** 12;
   Continuous   : constant Unsigned_32 := 2 ** 13;
   Cycles_387   : constant Unsigned_32 := 2#110#;

   Reference_Channel   : constant := 19;
   Temperature_Channel : constant := 18;

   Circular : constant Unsigned_32 := 2 ** 8;
   Sizes_16 : constant Unsigned_32 := 2 ** 11 or 2 ** 13;

   --  The boost range for a 50 MHz converter clock: revision Y up to the
   --  revision identifier 16#1003# takes its one boost bit above 20 MHz,
   --  revision V halves the clock inside and takes the 12.5 to 25 MHz range.
   function Boost return Unsigned_32 is
     (if Interfaces.Shift_Right (DBGMCU_IDCODE, 16) <= 16#1003# then 2#01# * 2 ** 8 else 2#10# * 2 ** 8);

   In_Progress : Boolean := False;
   Powered     : array (Device_Number) of Boolean := (others => False);

   type Result_Buffer is array (0 .. Max_Inputs - 1) of Interfaces.Unsigned_16 with Alignment => 4;
   pragma Volatile_Components (Result_Buffer);
   Results : Result_Buffer := (others => 0) with Linker_Section => Adaflight.STM32.Platform.DMA_Section;
   Owned   : Natural := 0;

   subtype Channel is Natural range 0 .. 19;

   --  The converters a pin reaches as a mask of ADC1 to ADC3.
   function Reach (P : Pin) return Natural is
     (case P.Port is
         when Port_A => (case P.Number is when 0 | 1 => 1, when 2 .. 7 => 3, when others => 0),
         when Port_B => (if P.Number <= 1 then 3 else 0),
         when Port_C => (case P.Number is when 0 | 1 => 7, when 2 | 3 => 4, when 4 | 5 => 3, when others => 0),
         when Port_F => (if P.Number = 11 then 1 else 0),
         when others => 0);

   function Has_Channel (P : Pin; Device : Natural) return Boolean is
     (Device <= 2 and then (Reach (P) / 2 ** Device) mod 2 = 1);

   --  The pin's input channel, the same on each converter it reaches.
   function Channel_Of (P : Pin) return Channel is
     (case P.Port is
         when Port_A =>
           (case P.Number is
               when 0 => 16, when 1 => 17, when 2 => 14, when 3 => 15, when 4 => 18, when 5 => 19, when 6 => 3,
               when others => 7),
         when Port_B => (if P.Number = 0 then 9 else 5),
         when Port_C =>
           (case P.Number is when 0 => 10, when 1 => 11, when 2 => 0, when 3 => 1, when 4 => 4, when others => 8),
         when others => 2)
     with Pre => Reach (P) /= 0;

   --  The converter's clock and common clock mode, then its power up,
   --  offset calibration and enable, once.
   procedure Power_Up (Device : Device_Number) is
      R : Registers with Import, Address => System'To_Address (Base (Device));
   begin
      if Device = 2 then
         RCC_AHB4ENR := RCC_AHB4ENR or ADC3_Enable;
         CCR_3 := (CCR_3 and not Clock_Quarter) or Clock_Quarter;
      else
         RCC_AHB1ENR := RCC_AHB1ENR or ADC12_Enable;
         CCR_12 := (CCR_12 and not Clock_Quarter) or Clock_Quarter;
      end if;
      if Powered (Device) then
         return;
      end if;
      R.CR := R.CR and not Deep_Power_Down;
      R.CR := R.CR or Regulator_On;
      delay until Ada.Real_Time."+" (Ada.Real_Time.Clock, Ada.Real_Time.Microseconds (20));
      R.CR := (R.CR and not Boost_Mask) or Boost;
      R.CR := R.CR or Calibrate;
      for Spin in 1 .. 1_000_000 loop
         exit when (R.CR and Calibrate) = 0;
      end loop;
      R.ISR := Ready;
      R.CR := R.CR or Enable;
      for Spin in 1 .. 1_000_000 loop
         exit when (R.ISR and Ready) /= 0;
      end loop;
      Powered (Device) := True;
   end Power_Up;

   procedure Init is
   begin
      Power_Up (2);
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
      Power_Up (Device);
      if Count = 0 then
         return;
      end if;
      for I in 0 .. Count - 1 loop
         if Reach (Inputs (I)) /= 0 then
            declare
               C : constant Channel := Channel_Of (Inputs (I));
            begin
               GPIO.Enable_Port (Inputs (I).Port);
               GPIO.Set_Analog (Inputs (I));
               R.PCSEL := R.PCSEL or Interfaces.Shift_Left (1, C);
               if C >= 10 then
                  R.SMPR2 := (R.SMPR2 and not Interfaces.Shift_Left (7, 3 * (C - 10)))
                    or Interfaces.Shift_Left (Cycles_387, 3 * (C - 10));
               else
                  R.SMPR1 := (R.SMPR1 and not Interfaces.Shift_Left (7, 3 * C))
                    or Interfaces.Shift_Left (Cycles_387, 3 * C);
               end if;
               Ranks := Ranks or Interfaces.Shift_Left (Unsigned_32 (C), 6 * (I + 1));
            end;
         end if;
      end loop;
      R.SQR1 := Ranks or Unsigned_32 (Count - 1);
      R.CFGR := Circular_DMA or Bits_12 or Overwrite or Continuous;
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
         S.PAR := Base (Device) + 16#40#;
         S.M0AR := Unsigned_32 (System.Storage_Elements.To_Integer (Results'Address));
         S.NDTR := Unsigned_32 (Count);
         S.CR := Request_Bits (Stream) or PL_High or Sizes_16
           or (if Count > 1 then MINC else 0) or Circular;
         S.CR := S.CR or EN;
      end;
      Owned := Number;
      R.CR := R.CR or Regular_Start;
   end Start_Scan;

   function Scanned (Slot : Natural) return Sample is
     (if Slot < Max_Inputs then Sample (Results (Slot) and 16#FFF#) else 0);

   function Stream_Number return Natural is (Owned);

   procedure Init_Internal is
   begin
      Power_Up (2);
      CCR_3 := CCR_3 or Reference_On or Sensor_On;
      Internal.PCSEL := Internal.PCSEL or 2 ** Reference_Channel or 2 ** Temperature_Channel;
      Internal.SMPR2 := (Internal.SMPR2 and not (7 * 2 ** 24 or 7 * 2 ** 27)) or Cycles_387 * 2 ** 24
        or Cycles_387 * 2 ** 27;
      Internal.JSQR := 1 or Reference_Channel * 2 ** 9 or Temperature_Channel * 2 ** 15;
   end Init_Internal;

   procedure Start_Internal is
   begin
      Internal.ISR := Injected_End;
      Internal.CR := Internal.CR or Injected_Start;
      In_Progress := True;
   end Start_Internal;

   procedure Check_Internal (Busy : out Boolean) is
   begin
      if In_Progress and then (Internal.ISR and Injected_End) /= 0 then
         In_Progress := False;
      end if;
      Busy := In_Progress;
   end Check_Internal;

   function Reference_Sample return Sample is (Sample (Internal.JDR1 and 16#FFF#));
   function Temperature_Sample return Sample is (Sample (Internal.JDR2 and 16#FFF#));

   function Reference_Calibration return Interfaces.Unsigned_16 is (Interfaces.Shift_Right (Vrefint_Cal, 4));
   function Sensor_Calibration_30 return Interfaces.Unsigned_16 is (Interfaces.Shift_Right (Ts_Cal1, 4));
   function Sensor_Calibration_110 return Interfaces.Unsigned_16 is (Interfaces.Shift_Right (Ts_Cal2, 4));
end Adaflight.STM32.ADC;
