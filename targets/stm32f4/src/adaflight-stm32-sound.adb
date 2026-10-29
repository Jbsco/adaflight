with System;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
package body Adaflight.STM32.Sound is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Output is (None, Level, Square_Wave);

   type Timer_Registers is record
      CR1   : Unsigned_32;
      EGR   : Unsigned_32;
      CCMR1 : Unsigned_32;
      CCER  : Unsigned_32;
      PSC   : Unsigned_32;
      ARR   : Unsigned_32;
      CCR1  : Unsigned_32;
   end record with Volatile;
   for Timer_Registers use record
      CR1   at 16#00# range 0 .. 31;
      EGR   at 16#14# range 0 .. 31;
      CCMR1 at 16#18# range 0 .. 31;
      CCER  at 16#20# range 0 .. 31;
      PSC   at 16#28# range 0 .. 31;
      ARR   at 16#2C# range 0 .. 31;
      CCR1  at 16#34# range 0 .. 31;
   end record;
   --  TIM3 on the 84 MHz timer clock of the APB1 bus, whose channel 1 is
   --  PB4's alternate function 2.
   TIM3 : Timer_Registers with Import, Address => System'To_Address (16#4000_0400#);
   RCC_APB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   TIM3_Bit : constant Unsigned_32 := 2 ** 1;
   Timer_Clock_Hz : constant := Adaflight.STM32.Platform.APB1_Timer_Hz;
   Tick_Hz        : constant := 1_000_000;

   Kind     : Output := None;
   The_Pin  : Pin := (Port_B, 4);
   Active_High : Boolean := False;
   Half     : Unsigned_32 := 0;

   procedure Init (P : Pin; Frequency : Interfaces.Unsigned_16; Inverted, Open_Drain : Boolean) is
      Period : Unsigned_32;
   begin
      The_Pin := P;
      GPIO.Enable_Port (P.Port);
      if Frequency = 0 then
         Kind := Level;
         Active_High := Inverted;
         GPIO.Set_Output (P);
         if Open_Drain then
            GPIO.Set_Open_Drain (P);
         end if;
         Set (False);
      elsif P = (Port_B, 4) then
         Kind := Square_Wave;
         Period := Tick_Hz / Unsigned_32 (Frequency);
         Half := Period / 2;
         RCC_APB1ENR := RCC_APB1ENR or TIM3_Bit;
         GPIO.Set_Alternate (P, 2);
         TIM3.CR1 := 0;
         TIM3.PSC := Timer_Clock_Hz / Tick_Hz - 1;
         TIM3.ARR := Period - 1;
         TIM3.CCR1 := 0;
         TIM3.CCMR1 := (TIM3.CCMR1 and not 16#FF#) or 2#0110_1000#;
         TIM3.CCER := (TIM3.CCER and not 16#F#) or 1;
         TIM3.EGR := 1;
         TIM3.CR1 := 2 ** 7 or 1;
      else
         Kind := None;
      end if;
   end Init;

   procedure Set (On : Boolean) is
   begin
      case Kind is
         when None =>
            null;
         when Level =>
            if On = Active_High then
               GPIO.Set_High (The_Pin);
            else
               GPIO.Set_Low (The_Pin);
            end if;
         when Square_Wave =>
            TIM3.CCR1 := (if On then Half else 0);
      end case;
   end Set;
end Adaflight.STM32.Sound;
