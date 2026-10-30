--  The board's LED strip on a timer channel: the channel the strip's pin
--  holds through the timer pin map's owners, the timer at 48 MHz over the
--  800 kHz carrier, and the stream of the map's DMA option, which writes one
--  compare value per bit into the channel's compare register, each LED's
--  color packed for the strip's format, then a low tail that latches the
--  colors.
with Adaflight.Config_Groups;
with Adaflight.LED_Strip;
package Adaflight.STM32.LED_Strip is
   --  The strip's channel and stream from the configuration, or none when
   --  the pin has no channel or stream.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  Whether the strip has its channel and the last transfer is done.
   function Ready return Boolean;
   --  The strip's DMA stream, numbered from 1 for the first controller's
   --  stream 0, or 0 without a strip.
   function Stream_Number return Natural;
   --  The LEDs' colors written to the strip.
   procedure Send (Colors : Adaflight.LED_Strip.Led_Output);
end Adaflight.STM32.LED_Strip;
