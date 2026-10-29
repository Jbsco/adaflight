--  The STM32F405's timers: the timer table and each timer's registers,
--  clock, alternate function and enable bit.
with Interfaces;
with System;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
package Adaflight.STM32.Timers is
   use Interfaces;

   type Timer_Name is (TIM1, TIM2, TIM3, TIM4, TIM5, TIM8, TIM9, TIM10, TIM11, TIM12, TIM13, TIM14);
   subtype Channel_Number is Positive range 1 .. 4;

   --  An entry of the processor's timer table: the timer, the channel,
   --  whether the pin is the complementary output, and the pin.
   type Timer_Entry is record
      Timer   : Timer_Name;
      Channel : Channel_Number;
      N       : Boolean;
      Where   : Pin;
   end record;

   --  The STM32F405's timer outputs in the order the reference's timer table
   --  lists them, which the board map's occurrence numbers count.
   Timer_Table : constant array (Positive range <>) of Timer_Entry :=
     ((TIM2, 1, False, (Port_A, 0)),
      (TIM2, 2, False, (Port_A, 1)),
      (TIM2, 3, False, (Port_A, 2)),
      (TIM2, 4, False, (Port_A, 3)),
      (TIM2, 1, False, (Port_A, 5)),
      (TIM1, 1, True, (Port_A, 7)),
      (TIM1, 1, False, (Port_A, 8)),
      (TIM1, 2, False, (Port_A, 9)),
      (TIM1, 3, False, (Port_A, 10)),
      (TIM1, 4, False, (Port_A, 11)),
      (TIM2, 1, False, (Port_A, 15)),
      (TIM5, 1, False, (Port_A, 0)),
      (TIM5, 2, False, (Port_A, 1)),
      (TIM5, 3, False, (Port_A, 2)),
      (TIM5, 4, False, (Port_A, 3)),
      (TIM3, 1, False, (Port_A, 6)),
      (TIM3, 2, False, (Port_A, 7)),
      (TIM9, 1, False, (Port_A, 2)),
      (TIM9, 2, False, (Port_A, 3)),
      (TIM8, 1, True, (Port_A, 5)),
      (TIM8, 1, True, (Port_A, 7)),
      (TIM13, 1, False, (Port_A, 6)),
      (TIM14, 1, False, (Port_A, 7)),
      (TIM1, 2, True, (Port_B, 0)),
      (TIM1, 3, True, (Port_B, 1)),
      (TIM2, 2, False, (Port_B, 3)),
      (TIM2, 3, False, (Port_B, 10)),
      (TIM2, 4, False, (Port_B, 11)),
      (TIM1, 1, True, (Port_B, 13)),
      (TIM1, 2, True, (Port_B, 14)),
      (TIM1, 3, True, (Port_B, 15)),
      (TIM3, 3, False, (Port_B, 0)),
      (TIM3, 4, False, (Port_B, 1)),
      (TIM3, 1, False, (Port_B, 4)),
      (TIM3, 2, False, (Port_B, 5)),
      (TIM4, 1, False, (Port_B, 6)),
      (TIM4, 2, False, (Port_B, 7)),
      (TIM4, 3, False, (Port_B, 8)),
      (TIM4, 4, False, (Port_B, 9)),
      (TIM8, 2, True, (Port_B, 0)),
      (TIM8, 3, True, (Port_B, 1)),
      (TIM10, 1, False, (Port_B, 8)),
      (TIM11, 1, False, (Port_B, 9)),
      (TIM8, 2, True, (Port_B, 14)),
      (TIM8, 3, True, (Port_B, 15)),
      (TIM12, 1, False, (Port_B, 14)),
      (TIM12, 2, False, (Port_B, 15)),
      (TIM3, 1, False, (Port_C, 6)),
      (TIM3, 2, False, (Port_C, 7)),
      (TIM3, 3, False, (Port_C, 8)),
      (TIM3, 4, False, (Port_C, 9)),
      (TIM8, 1, False, (Port_C, 6)),
      (TIM8, 2, False, (Port_C, 7)),
      (TIM8, 3, False, (Port_C, 8)),
      (TIM8, 4, False, (Port_C, 9)),
      (TIM4, 1, False, (Port_D, 12)),
      (TIM4, 2, False, (Port_D, 13)),
      (TIM4, 3, False, (Port_D, 14)),
      (TIM4, 4, False, (Port_D, 15)),
      (TIM1, 1, True, (Port_E, 8)),
      (TIM1, 1, False, (Port_E, 9)),
      (TIM1, 2, True, (Port_E, 10)),
      (TIM1, 2, False, (Port_E, 11)),
      (TIM1, 3, True, (Port_E, 12)),
      (TIM1, 3, False, (Port_E, 13)),
      (TIM1, 4, False, (Port_E, 14)),
      (TIM9, 1, False, (Port_E, 5)),
      (TIM9, 2, False, (Port_E, 6)),
      (TIM10, 1, False, (Port_F, 6)),
      (TIM11, 1, False, (Port_F, 7)));

   Timer_Base_Value : constant array (Timer_Name) of Unsigned_32 :=
     (TIM1  => 16#4001_0000#, TIM2  => 16#4000_0000#, TIM3  => 16#4000_0400#, TIM4  => 16#4000_0800#,
      TIM5  => 16#4000_0C00#, TIM8  => 16#4001_0400#, TIM9  => 16#4001_4000#, TIM10 => 16#4001_4400#,
      TIM11 => 16#4001_4800#, TIM12 => 16#4000_1800#, TIM13 => 16#4000_1C00#, TIM14 => 16#4000_2000#);

   function Timer_Base (T : Timer_Name) return System.Address is (System'To_Address (Timer_Base_Value (T)));

   --  The timers on the APB2 bus count at 168 MHz, the others at 84 MHz.
   Timer_Clock_Hz : constant array (Timer_Name) of Unsigned_32 :=
     (TIM1 | TIM8 | TIM9 | TIM10 | TIM11 => 168_000_000, others => 84_000_000);

   Alternate : constant array (Timer_Name) of Adaflight.STM32.GPIO.Alternate_Function :=
     (TIM1 | TIM2 => 1, TIM3 | TIM4 | TIM5 => 2, TIM8 | TIM9 | TIM10 | TIM11 => 3, TIM12 | TIM13 | TIM14 => 9);

   Advanced : constant array (Timer_Name) of Boolean := (TIM1 | TIM8 => True, others => False);

   --  The enable bit of each timer in RCC_APB1ENR, or in RCC_APB2ENR for
   --  the APB2 timers.
   On_APB2    : constant array (Timer_Name) of Boolean := (TIM1 | TIM8 | TIM9 | TIM10 | TIM11 => True, others => False);
   Enable_Bit : constant array (Timer_Name) of Natural :=
     (TIM2 => 0, TIM3 => 1, TIM4 => 2, TIM5 => 3, TIM12 => 6, TIM13 => 7, TIM14 => 8,
      TIM1 => 0, TIM8 => 1, TIM9 => 16, TIM10 => 17, TIM11 => 18);

   type Timer_Registers is record
      CR1, CR2, SMCR, DIER, SR, EGR, CCMR1, CCMR2, CCER, CNT, PSC, ARR, RCR : Unsigned_32;
      CCR                                                                : Unsigned_32;
      CCR2, CCR3, CCR4, BDTR                                             : Unsigned_32;
   end record with Volatile;
   for Timer_Registers use record
      CR1   at 16#00# range 0 .. 31;
      CR2   at 16#04# range 0 .. 31;
      SMCR  at 16#08# range 0 .. 31;
      DIER  at 16#0C# range 0 .. 31;
      SR    at 16#10# range 0 .. 31;
      EGR   at 16#14# range 0 .. 31;
      CCMR1 at 16#18# range 0 .. 31;
      CCMR2 at 16#1C# range 0 .. 31;
      CCER  at 16#20# range 0 .. 31;
      CNT   at 16#24# range 0 .. 31;
      PSC   at 16#28# range 0 .. 31;
      ARR   at 16#2C# range 0 .. 31;
      RCR   at 16#30# range 0 .. 31;
      CCR   at 16#34# range 0 .. 31;
      CCR2  at 16#38# range 0 .. 31;
      CCR3  at 16#3C# range 0 .. 31;
      CCR4  at 16#40# range 0 .. 31;
      BDTR  at 16#44# range 0 .. 31;
   end record;

   CEN  : constant Unsigned_32 := 2 ** 0;
   ARPE : constant Unsigned_32 := 2 ** 7;
   UG   : constant Unsigned_32 := 2 ** 0;
   MOE  : constant Unsigned_32 := 2 ** 15;

   --  The channel's compare register.
   function CCR_Value (T : Timer_Name; C : Channel_Number) return Unsigned_32 is
     (Timer_Base_Value (T) + 16#34# + 4 * Unsigned_32 (C - 1));

end Adaflight.STM32.Timers;
