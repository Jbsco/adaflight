with Adaflight.STM32.MCU;
with Adaflight.STM32.Sound;
with Adaflight.STM32.Status_LED;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Failure_Flashes is
   procedure Flash (Count : Natural; Duration_Ms : Natural) is
   begin
      if Count = 0 then
         return;
      end if;
      Adaflight.STM32.Status_LED.Set (1, True);
      Adaflight.STM32.Status_LED.Set (0, False);
      for I in 1 .. Count loop
         Adaflight.STM32.Status_LED.Toggle (1);
         Adaflight.STM32.Status_LED.Toggle (0);
         Adaflight.STM32.Sound.Set (True);
         Adaflight.STM32.Time.Delay_Ms (Duration_Ms);
         Adaflight.STM32.Status_LED.Toggle (1);
         Adaflight.STM32.Status_LED.Toggle (0);
         Adaflight.STM32.Sound.Set (False);
         Adaflight.STM32.Time.Delay_Ms (Duration_Ms);
      end loop;
   end Flash;

   procedure Indicate (Code : Natural; Repeats : Natural) is
   begin
      for I in 1 .. Repeats loop
         Flash (5, 50);
         Adaflight.STM32.Time.Delay_Ms (500);
         Flash (Code + 1, 250);
         Adaflight.STM32.Time.Delay_Ms (1000);
      end loop;
   end Indicate;

   procedure Mode (Code : Natural) is
   begin
      Indicate (Code, 10);
      Adaflight.STM32.MCU.Reset_To_Bootloader;
   end Mode;
end Adaflight.STM32.Failure_Flashes;
