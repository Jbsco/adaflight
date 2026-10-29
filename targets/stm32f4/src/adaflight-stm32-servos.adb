with System;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
package body Adaflight.STM32.Servos is
   package GPIO renames Adaflight.STM32.GPIO;

   RCC_APB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   RCC_APB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3844#);

   --  Each servo's compare register, or 0 for a servo without an output.
   CCR_Of : array (0 .. Max_Servos - 1) of Unsigned_32 := (others => 0);

   --  A servo's channel as the reference configures it: the timer counting
   --  up at 1 MHz over the period, the channel in PWM mode 1 at the center
   --  pulse with its output on at high polarity and its preload, the outputs
   --  and the timer on, then the compare register cleared.
   procedure Configure (E : Timer_Entry; Period : Unsigned_16; Center : Unsigned_16) is
      Regs    : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      CCR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Value (E.Timer, E.Channel));
      Byte    : constant Natural := (if E.Channel mod 2 = 1 then 0 else 8);
      Base    : constant Natural := 4 * (E.Channel - 1);
      Idle    : constant Natural := 8 + 2 * (E.Channel - 1);
      Mode    : Unsigned_32;
      Enables : Unsigned_32;
      Control : Unsigned_32;
   begin
      if On_APB2 (E.Timer) then
         RCC_APB2ENR := RCC_APB2ENR or Shift_Left (1, Enable_Bit (E.Timer));
      else
         RCC_APB1ENR := RCC_APB1ENR or Shift_Left (1, Enable_Bit (E.Timer));
      end if;
      if E.Timer in TIM1 | TIM2 | TIM3 | TIM4 | TIM5 | TIM8 then
         Regs.CR1 := Regs.CR1 and not 2#111_0000#;
      end if;
      Regs.CR1 := Regs.CR1 and not (2 ** 8 or 2 ** 9);
      Regs.ARR := Unsigned_32 (Period - 1);
      Regs.PSC := Timer_Clock_Hz (E.Timer) / 1_000_000 - 1;
      if Advanced (E.Timer) then
         Regs.RCR := 0;
      end if;
      Regs.EGR := UG;
      Regs.CCER := Regs.CCER and not Shift_Left (2#0001#, Base);
      Enables := Regs.CCER and not Shift_Left (2#0010#, Base);
      Control := Regs.CR2;
      Mode := (if E.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2);
      Mode := (Mode and not Shift_Left (16#73#, Byte)) or Shift_Left (16#60#, Byte);
      if not E.N then
         Enables := Enables or Shift_Left (2#0001#, Base);
      end if;
      if Advanced (E.Timer) then
         if E.Channel < 4 then
            Enables := Enables and not Shift_Left (2#1100#, Base);
            if E.N then
               Enables := Enables or Shift_Left (2#0100#, Base);
            end if;
            Control := Control and not Shift_Left (2#11#, Idle);
         else
            Control := Control and not Shift_Left (2#01#, Idle);
         end if;
         if not E.N then
            Control := Control or Shift_Left (1, Idle);
         end if;
      end if;
      Regs.CR2 := Control;
      if E.Channel <= 2 then
         Regs.CCMR1 := Mode;
      else
         Regs.CCMR2 := Mode;
      end if;
      CCR := Unsigned_32 (Center);
      Regs.CCER := Enables;
      if E.Channel <= 2 then
         Regs.CCMR1 := Regs.CCMR1 or Shift_Left (16#08#, Byte);
      else
         Regs.CCMR2 := Regs.CCMR2 or Shift_Left (16#08#, Byte);
      end if;
      if Advanced (E.Timer) then
         Regs.BDTR := Regs.BDTR or MOE;
      end if;
      Regs.CR1 := Regs.CR1 or CEN;
      CCR := 0;
   end Configure;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      Dev : Adaflight.Config_Groups.Servo_Dev_Config_Record renames C.Servo_Config.Dev;
   begin
      for N in 0 .. Max_Servos - 1 loop
         if Dev.Io_Tags (N) /= 0 then
            declare
               E     : Timer_Entry;
               Index : Natural;
               Found : Boolean;
            begin
               Allocate (Dev.Io_Tags (N), Servo, E, Index, Found);
               exit when not Found;
               GPIO.Enable_Port (E.Where.Port);
               GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.No_Pull, Rate => GPIO.Low);
               Configure (E, Period_Of (Dev.Servo_Pwm_Rate), Dev.Servo_Center_Pulse);
               CCR_Of (N) := CCR_Value (E.Timer, E.Channel);
            end;
         end if;
      end loop;
   end Init;

   procedure Write (Index : Natural; Value : Float) is
   begin
      if Index < Max_Servos and then CCR_Of (Index) /= 0 then
         declare
            CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Of (Index));
         begin
            CCR := Pulse_Of (Value);
         end;
      end if;
   end Write;
end Adaflight.STM32.Servos;
