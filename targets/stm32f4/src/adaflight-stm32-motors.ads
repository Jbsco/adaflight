--  The board's motor outputs in DShot from the timers. Each motor's pin
--  comes from the stored configuration through its output order, its timer
--  channel from the board's timer map and the processor's timer table, and
--  its DMA stream from the map's option. The timer counts at the protocol's
--  bit clock, twenty counts a bit, and the stream writes the frame's sixteen
--  bits and two zero slots into the channel's compare register at each
--  compare event. A write loads each motor's frame and arms its stream, then
--  each timer restarts and asks for the transfers.
with Adaflight.Config_Groups;
with Adaflight.Mixer;
with Adaflight.MSP_Motor_In;
package Adaflight.STM32.Motors is
   --  The outputs of the mixer's motors from the configuration; every motor
   --  needs its timer channel and stream, or none is driven.
   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural);
   --  The writes start once the start of the flight software is done.
   procedure Enable;
   function Enabled return Boolean;
   function Motor_Enabled (Index : Natural) return Boolean;
   --  The motor count and the output device the MSP replies report.
   function Count return Natural;
   function Device return Adaflight.MSP_Motor_In.Device_Kind;
   --  Each motor's value as its frame, then the transfers.
   procedure Write_All (Values : Adaflight.Mixer.Motor_Outputs);
end Adaflight.STM32.Motors;
