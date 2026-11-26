--  The STM32H7 image so far: the board's first LED blinks at 1 Hz through
--  the GPIO unit, with the caches on and the D2 RAM uncached, which shows
--  start-up, clock setup, timing and the peripheral map working on a board
--  or an emulator.
with Ada.Real_Time; use Ada.Real_Time;
with Adaflight.Board;
with Adaflight.STM32.CCM_Clear; pragma Unreferenced (Adaflight.STM32.CCM_Clear);
with Adaflight.STM32.Cache; pragma Unreferenced (Adaflight.STM32.Cache);
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;

procedure Adaflight_Stm32h7 is
   pragma Compile_Time_Error (Adaflight.STM32.Platform.F4, "an STM32H7 image with the F4 platform");
   Next : Time := Clock;
begin
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
   loop
      Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
      Next := Next + Milliseconds (500);
      delay until Next;
   end loop;
end Adaflight_Stm32h7;
