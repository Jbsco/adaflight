--  The host image: the STM32F4 image's flight software over the host bodies
--  of the board's hardware packages. The environment variable
--  ADAFLIGHT_START_STALL_MS pauses the image that many milliseconds between
--  its start-up and its first scheduler pass, as a busy host can.
with Ada.Environment_Variables;
with Adaflight.STM32.Flight;

procedure Adaflight_Host is
   Stall : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_START_STALL_MS", "");
begin
   Adaflight.STM32.Flight.Init;
   if Stall'Length in 1 .. 4 and then (for all C of Stall => C in '0' .. '9') then
      delay Duration (Natural'Value (Stall)) / 1_000;
   end if;
   loop
      Adaflight.STM32.Flight.Pass;
   end loop;
end Adaflight_Host;
