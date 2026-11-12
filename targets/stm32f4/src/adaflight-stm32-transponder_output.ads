--  The race transponder's output on a timer channel: the channel the
--  transponder's pin holds through the timer pin map's owners, the timer at
--  a coding's counting rate over its carrier, and the stream of the map's
--  DMA option, which writes one compare value per toggle into the channel's
--  compare register.
with Interfaces;
with Adaflight.Transponder;
package Adaflight.STM32.Transponder_Output is
   --  The pin's channel and stream taken: Found is false when the pin has no
   --  channel, its DMA option names no stream, or the motors, the LED strip
   --  or the analog inputs hold that stream.
   procedure Take (Tag : Interfaces.Unsigned_8; Found : out Boolean);
   --  The taken channel's timer stopped and set to a coding's counting rate
   --  and carrier, the channel in PWM mode 1 at zero with its output on, and
   --  the stream from the toggles to the compare register.
   procedure Configure (P : Adaflight.Transponder.Provider);
   --  Whether the last transmission is done.
   function Ready return Boolean;
   --  A code's toggles in the configured coding, once the last transmission
   --  is done or 30 ms have passed.
   procedure Load (Data : Adaflight.Transponder.Code);
   --  One transmission of the loaded toggles.
   procedure Transmit;
   --  The stream, numbered from 1 for the first controller's stream 0, or 0
   --  when none is taken.
   function Stream_Number return Natural;
end Adaflight.STM32.Transponder_Output;
