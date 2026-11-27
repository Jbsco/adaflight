with Interfaces; use Interfaces;
with System;
--  The STM32H743's USB clock: the 48 MHz internal oscillator as the USB
--  kernel clock, trimmed by the clock recovery unit from the full-speed
--  controller's start of frame, and the USB supply's voltage detector on.
package body Adaflight.STM32.USB_Clock is
   RCC_CR       : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4400#);
   RCC_D2CCIP2R : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_4454#);
   RCC_APB1HENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44EC#);
   CRS_CR       : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_8400#);
   CRS_CFGR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_8404#);
   PWR_CR3      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_480C#);

   HSI48_On       : constant Unsigned_32 := 2 ** 12;
   HSI48_Ready    : constant Unsigned_32 := 2 ** 13;
   USB_Select     : constant Unsigned_32 := 2#11# * 2 ** 20;
   CRS_Enable     : constant Unsigned_32 := 2 ** 1;
   Counter_On     : constant Unsigned_32 := 2 ** 5;
   Auto_Trim      : constant Unsigned_32 := 2 ** 6;
   Sync_From_USB2 : constant Unsigned_32 := 2#11# * 2 ** 28;
   Detector_On    : constant Unsigned_32 := 2 ** 24;
   Supply_Ready   : constant Unsigned_32 := 2 ** 26;

   procedure Start is
   begin
      RCC_CR := RCC_CR or HSI48_On;
      for Count in 1 .. 100_000 loop
         exit when (RCC_CR and HSI48_Ready) /= 0;
      end loop;
      RCC_D2CCIP2R := RCC_D2CCIP2R or USB_Select;
      RCC_APB1HENR := RCC_APB1HENR or CRS_Enable;
      CRS_CFGR := CRS_CFGR or Sync_From_USB2;
      CRS_CR := CRS_CR or Auto_Trim or Counter_On;
      PWR_CR3 := PWR_CR3 or Detector_On;
      for Count in 1 .. 100_000 loop
         exit when (PWR_CR3 and Supply_Ready) /= 0;
      end loop;
   end Start;
end Adaflight.STM32.USB_Clock;
