--  The host image: the STM32F4 image's flight software over the host bodies
--  of the board's hardware packages.
with Adaflight.STM32.Flight;

procedure Adaflight_Host is
begin
   Adaflight.STM32.Flight.Init;
   loop
      Adaflight.STM32.Flight.Pass;
   end loop;
end Adaflight_Host;
