--  The board's PPM and parallel PWM receiver inputs, each pin on a timer
--  channel counting at 1 MHz. A PPM pin's channel captures each rising edge
--  without a filter, and the core's PPM decoder takes the captures and the
--  timer's overflows. A PWM pin's channel captures the edge its port's
--  decoder asks for next, through the noise filter when input filtering is
--  on. A pin on a timer that a motor holds, or on one the timer interrupt
--  dispatch does not serve, gives no input.
with Interfaces;
with Adaflight.Config_Groups;
package Adaflight.STM32.RX_Input is

   --  The channels a PPM frame and the PWM pins give the receiver.
   PPM_Channel_Count : constant := 12;
   PWM_Channel_Count : constant := 8;

   --  The PPM input on the pin with this tag.
   procedure Start_PPM (Tag : Interfaces.Unsigned_8; Started : out Boolean);

   --  The PWM inputs on the pins with these tags, a channel each.
   procedure Start_PWM (Tags : Adaflight.Config_Groups.Bytes_8; Filtering : Boolean);

   --  Whether a PPM frame arrived since the last call, which clears that, or
   --  whether a PWM channel has a pulse width.
   procedure Take_Received (Received : out Boolean);

   --  A channel's last pulse width in microseconds, zero before its first and
   --  without a signal.
   function Channel_Value (Channel : Natural) return Interfaces.Unsigned_16;

end Adaflight.STM32.RX_Input;
