--  The STM32H7 image so far: a banner on UART1 at 115200 baud, every byte
--  received there sent back, and the board's first LED blinking at 1 Hz,
--  with the caches on and the D2 RAM uncached.
with Ada.Real_Time; use Ada.Real_Time;
with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.STM32.CCM_Clear; pragma Unreferenced (Adaflight.STM32.CCM_Clear);
with Adaflight.STM32.Cache; pragma Unreferenced (Adaflight.STM32.Cache);
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
with Adaflight.STM32.USART; use Adaflight.STM32.USART;

procedure Adaflight_Stm32h7 is
   pragma Compile_Time_Error (Adaflight.STM32.Platform.F4, "an STM32H7 image with the F4 platform");
   Line  : Port := (Which => UART1);
   Data  : Byte_Array (1 .. 64);
   Count : Natural;
   Ticks : Natural := 0;
   Next  : Time := Clock;
begin
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
   Init (UART1, 115_200);
   Put (Line, "adaflight STM32H7" & ASCII.CR & ASCII.LF);
   loop
      Take (UART1, Data, Count);
      if Count > 0 then
         Put (Line, Data (Data'First .. Data'First + Count - 1));
      end if;
      Ticks := (Ticks + 1) mod 50;
      if Ticks = 0 then
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
      end if;
      Next := Next + Milliseconds (10);
      delay until Next;
   end loop;
end Adaflight_Stm32h7;
