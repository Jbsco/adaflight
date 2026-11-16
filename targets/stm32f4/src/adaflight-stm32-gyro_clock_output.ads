--  The gyro clock input's pin and timer channel: the pin on its timer's
--  alternate function, and the channel as a PWM output that counts the
--  timer's clock over a period with a pulse of it high.
with Interfaces;
with Adaflight.STM32.Timers;
package Adaflight.STM32.Gyro_Clock_Output is
   procedure Start
     (E : Adaflight.STM32.Timers.Timer_Entry; Timer_Hz : Interfaces.Unsigned_32; Period : Interfaces.Unsigned_16;
      Pulse : Interfaces.Unsigned_16);
end Adaflight.STM32.Gyro_Clock_Output;
