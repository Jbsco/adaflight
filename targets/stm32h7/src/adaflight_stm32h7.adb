--  The STM32H7 image so far: a banner on UART1 at 115200 baud, every byte
--  received there sent back, a line on each rising edge counted at the first
--  gyro's interrupt pin, a line each second with the update counts of TIM1
--  and TIM15 to TIM17 at 1 kHz, whether DMA1 and DMA2 each copied a block
--  of memory, a line each second with the transfers left to ADC1's DMA
--  stream, the second gyro's identity read over SPI4, whether the
--  configuration sector's marker block was written or kept, every byte the
--  USB serial port receives sent back on it, and the board's first LED
--  blinking at 1 Hz, with the caches on and the D2 RAM uncached.
with Ada.Real_Time; use Ada.Real_Time;
with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.STM32.Bring_Up;
with Adaflight.STM32.CCM_Clear; pragma Unreferenced (Adaflight.STM32.CCM_Clear);
with Adaflight.STM32.Cache; pragma Unreferenced (Adaflight.STM32.Cache);
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
with Adaflight.STM32.Time;
with Adaflight.STM32.USART; use Adaflight.STM32.USART;
with Adaflight.STM32.USB;

procedure Adaflight_Stm32h7 is
   pragma Compile_Time_Error (Adaflight.STM32.Platform.F4, "an STM32H7 image with the F4 platform");
   Line  : Port := (Which => UART1);
   Data  : Byte_Array (1 .. 64);
   Count : Natural;
   Sent  : Natural;
   Ticks : Natural := 0;
   Seen  : Natural := 0;
   Halves : Natural := 0;
   Next  : Time := Clock;
begin
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
   Init (UART1, 115_200);
   Put (Line, "adaflight STM32H7" & ASCII.CR & ASCII.LF);
   Adaflight.STM32.Bring_Up.Watch_Gyro_Interrupt;
   Adaflight.STM32.Bring_Up.Start_Timers;
   Adaflight.STM32.Bring_Up.Copy_By_DMA;
   for C in 1 .. 2 loop
      Put (Line, "dma" & Natural'Image (C) & (if Adaflight.STM32.Bring_Up.Copied (C) then " copied" else " not copied")
           & ASCII.CR & ASCII.LF);
   end loop;
   Adaflight.STM32.Bring_Up.Start_ADC_DMA;
   Adaflight.STM32.Bring_Up.Read_Gyro_2_Identity;
   Put (Line, "spi4 gyro 2 identity" & Natural'Image (Adaflight.STM32.Bring_Up.Gyro_2_Identity) & ASCII.CR & ASCII.LF);
   Adaflight.STM32.Bring_Up.Keep_Config_Marker;
   Put (Line, "config marker" & (if Adaflight.STM32.Bring_Up.Config_Marker_Written then " written"
                                 elsif Adaflight.STM32.Bring_Up.Config_Marker_Held then " kept" else " missing")
        & ASCII.CR & ASCII.LF);
   Adaflight.STM32.Time.Init;
   Adaflight.STM32.USB.Init ("Adaflight (" & Adaflight.Board.Board_Name & ")");
   Put (Line, "usb started" & ASCII.CR & ASCII.LF);
   loop
      Take (UART1, Data, Count);
      if Count > 0 then
         Put (Line, Data (Data'First .. Data'First + Count - 1));
      end if;
      Adaflight.STM32.USB.Take (Data, Count);
      if Count > 0 then
         Adaflight.STM32.USB.Send (Data (Data'First .. Data'First + Count - 1), Sent);
      end if;
      if Adaflight.STM32.Bring_Up.Edges /= Seen then
         Seen := Adaflight.STM32.Bring_Up.Edges;
         Put (Line, "exti" & Natural'Image (Seen) & ASCII.CR & ASCII.LF);
      end if;
      Ticks := (Ticks + 1) mod 50;
      if Ticks = 0 then
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Halves := (Halves + 1) mod 2;
         if Halves = 0 then
            Put (Line, "tim");
            for T in Adaflight.STM32.Bring_Up.Counted_Timer loop
               Put (Line, Natural'Image (Adaflight.STM32.Bring_Up.Updates (T)));
            end loop;
            Put (Line, "" & ASCII.CR & ASCII.LF);
            Put (Line, "adc dma left" & Natural'Image (Adaflight.STM32.Bring_Up.ADC_Transfers_Left)
                 & ASCII.CR & ASCII.LF);
         end if;
      end if;
      Next := Next + Milliseconds (10);
      delay until Next;
   end loop;
end Adaflight_Stm32h7;
