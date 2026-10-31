--  The STM32F4 image. Milestone 4: the gyro and accelerometer over SPI1,
--  the scheduler with the sensor, attitude and serial tasks, MSP and the
--  command line on UART1 at 115200 baud, and the board's LED at 1 Hz.
with Adaflight.STM32.CCM_Clear; pragma Unreferenced (Adaflight.STM32.CCM_Clear);
with Adaflight.STM32.Flight;

procedure Adaflight_Stm32f4 is
begin
   Adaflight.STM32.Flight.Init;
   loop
      Adaflight.STM32.Flight.Pass;
   end loop;
end Adaflight_Stm32f4;
