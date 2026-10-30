--  The motors' output: DShot with its command queue, or the analog
--  protocols' pulses. A DShot motor update sends the mix's values, a queued
--  command going out in their place, and starts the transfers once the
--  queue's output gate opens. Commands come from the command line and MSP,
--  blocking while the motors are disabled, and from the arming logic and the
--  beeper, queued while the motors stream. An analog update writes each
--  value's pulse, then completes the update.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.DShot;
with Adaflight.DShot_Command;
with Adaflight.Mixer;
package Adaflight.STM32.DShot_Output is
   --  Whether the configured protocol is a DShot one.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  The motors enabled, the time noted for the first streaming command.
   procedure Enable;
   procedure Disable;
   procedure Set_Loop_Time (Us : Adaflight.DShot_Command.Loop_Time_Us);
   function Protocol_Is_DShot return Boolean;
   --  Whether streaming commands go out: the motors enabled, the first
   --  command past the protocol detection delay.
   procedure Streaming_Enabled (Enabled : out Boolean);
   --  A command to a motor or to all of them, queued or sent at once.
   procedure Write_Command
     (Index   : Interfaces.Unsigned_8;
      Motors  : Natural;
      Command : Interfaces.Unsigned_8;
      Kind    : Adaflight.DShot_Command.Command_Type);
   --  A telemetry request in the motor's next frame.
   procedure Request_Telemetry (Index : Natural);
   --  The command line's command, sent at once.
   procedure Write_Blocking (Index : Natural; Motors : Natural; Command : Interfaces.Unsigned_8);
   --  The mix's values to the motors while they are enabled, after the
   --  telemetry read of the last frame's replies.
   procedure Write_All (Values : Adaflight.Mixer.Motor_Outputs);
   --  The telemetry's rates from the pole count, the forced extended decode
   --  and the frequency filters from their cutoff and the loop time, as the
   --  start of the flight software sets them when DShot telemetry or the ESC
   --  sensor runs.
   procedure Init_Telemetry (C : Adaflight.Config_Groups.Configuration; Looptime_Us : Positive);
   --  The replies read after a frame: the deadtime check, the decode of each
   --  motor's captured edges, the counts and the reply quality, the motors
   --  back to output; Done is false when the deadtime has not passed.
   procedure Read_Telemetry (Done : out Boolean);
   --  The raw values of the last replies decoded into the motors' kinds,
   --  rates and filtered frequencies, once per read, with bidirectional
   --  DShot on.
   procedure Update_Telemetry;
   --  The telemetry state, its read counts and the motors' reply quality.
   function Telemetry return Adaflight.DShot.Telemetry;
   function Counts return Adaflight.DShot.Read_Counts;
   function Qualities return Adaflight.DShot.Qualities;
end Adaflight.STM32.DShot_Output;
