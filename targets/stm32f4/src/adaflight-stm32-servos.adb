with Adaflight.CLI_Resources;
with Interfaces;
with System;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
package body Adaflight.STM32.Servos is
   use Interfaces;
   package GPIO renames Adaflight.STM32.GPIO;

   --  Each servo's compare register, or 0 for a servo without an output.
   CCR_Of : array (0 .. Max_Servos - 1) of Unsigned_32 := (others => 0);

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
               Allocate (Dev.Io_Tags (N), Adaflight.CLI_Resources.Servo, E, Index, Found, Ordinal => N + 1);
               exit when not Found;
               GPIO.Enable_Port (E.Where.Port);
               GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.No_Pull, Rate => GPIO.Low);
               Configure_PWM (E, 1_000_000, Adaflight.PWM_Output.Servo_Period (Dev.Servo_Pwm_Rate),
                              Dev.Servo_Center_Pulse, Inverted => False);
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
            CCR := Adaflight.PWM_Output.Servo_Pulse (Held (Value));
         end;
      end if;
   end Write;
end Adaflight.STM32.Servos;
