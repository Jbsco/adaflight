--  The board's motor outputs in DShot from the timers. Each motor's pin
--  comes from the stored configuration through its output order, its timer
--  channel from the board's timer map and the processor's timer table, and
--  its DMA stream from the map's option. The timer counts at the protocol's
--  bit clock, twenty counts a bit, and the stream writes the frame's sixteen
--  bits and two zero slots into the channel's compare register at each
--  compare event. A frame loads into its motor's buffer and arms its stream,
--  then each timer restarts and asks for the transfers.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.MSP_Motor_In;
package Adaflight.STM32.Motors is
   --  The outputs of the mixer's motors from the configuration; every motor
   --  needs its timer channel and stream, or none is driven.
   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural);
   --  The writes start once the start of the flight software is done, and
   --  stop while the command line or MSP sends blocking DShot commands.
   procedure Enable;
   procedure Disable;
   function Enabled return Boolean;
   function Motor_Enabled (Index : Natural) return Boolean;
   --  The DMA stream a motor's frames go out on, numbered from 1 for the
   --  first controller's stream 0 to 16 for the second's stream 7, or 0 for
   --  a motor without an output.
   function Stream_Of (Index : Natural) return Natural
     with Post => Stream_Of'Result <= 16;
   --  The motor count and the output device the MSP replies report.
   function Count return Natural;
   function Device return Adaflight.MSP_Motor_In.Device_Kind;
   --  A motor's frame of a value and its telemetry request, its stream armed.
   procedure Send_Frame (Index : Natural; Value : Interfaces.Unsigned_16; Request : Boolean);
   --  Each timer used restarts and asks for the transfers its motors armed.
   procedure Start_Transfers;
end Adaflight.STM32.Motors;
