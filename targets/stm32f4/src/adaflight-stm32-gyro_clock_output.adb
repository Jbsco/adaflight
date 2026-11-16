with System;
with Adaflight.STM32.GPIO;
package body Adaflight.STM32.Gyro_Clock_Output is
   procedure Start
     (E : Adaflight.STM32.Timers.Timer_Entry; Timer_Hz : Interfaces.Unsigned_32; Period : Interfaces.Unsigned_16;
      Pulse : Interfaces.Unsigned_16)
   is
      use Adaflight.STM32.Timers;
      package GPIO renames Adaflight.STM32.GPIO;
      CCR : Interfaces.Unsigned_32
        with Volatile, Import, Address => System'To_Address (CCR_Value (E.Timer, E.Channel));
   begin
      GPIO.Enable_Port (E.Where.Port);
      GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.No_Pull, Rate => GPIO.Low);
      Configure_PWM (E, Timer_Hz, Period, Pulse, Inverted => False);
      CCR := Interfaces.Unsigned_32 (Pulse);
   end Start;
end Adaflight.STM32.Gyro_Clock_Output;
