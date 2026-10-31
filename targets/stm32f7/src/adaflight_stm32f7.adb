--  The STM32F7 image: the flight software of the F4 crate on an F7 board,
--  started and run pass by pass.
with Adaflight.STM32.Data_Pack; pragma Unreferenced (Adaflight.STM32.Data_Pack);
with Adaflight.STM32.Flight;

procedure Adaflight_Stm32f7 is
begin
   Adaflight.STM32.Flight.Init;
   loop
      Adaflight.STM32.Flight.Pass;
   end loop;
end Adaflight_Stm32f7;
