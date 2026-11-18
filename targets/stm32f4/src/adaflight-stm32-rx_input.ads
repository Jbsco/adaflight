--  The board's PPM receiver input: the PPM pin's timer channel captures each
--  rising edge at 1 MHz without a filter, and the core's PPM decoder takes
--  the captures and the timer's overflows. A timer that a motor holds, or
--  one the timer interrupt dispatch does not serve, gives no input.
with Interfaces;
package Adaflight.STM32.RX_Input is

   --  The channels a PPM frame gives the receiver.
   PPM_Channel_Count : constant := 12;

   --  The input on the pin with this tag.
   procedure Start_PPM (Tag : Interfaces.Unsigned_8; Started : out Boolean);

   --  Whether a frame arrived since the last call, which clears that.
   procedure Take_Received (Received : out Boolean);

   --  A channel's last pulse width in microseconds, zero before its first.
   function Channel_Value (Channel : Natural) return Interfaces.Unsigned_16;

end Adaflight.STM32.RX_Input;
