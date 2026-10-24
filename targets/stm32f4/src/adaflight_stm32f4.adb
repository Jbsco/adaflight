--  The STM32F4 image. Milestone 1: the board's LED blinks at 1 Hz.
with Ada.Real_Time; use Ada.Real_Time;
with Adaflight.Board;
with Adaflight.STM32.GPIO;

procedure Adaflight_Stm32f4 is
   Next : Time := Clock;
begin
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
   loop
      Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
      Next := Next + Milliseconds (500);
      delay until Next;
   end loop;
end Adaflight_Stm32f4;
