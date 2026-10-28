--  The motors' DShot output with its command queue: each motor update sends
--  the mix's values, a queued command going out in their place, and starts
--  the transfers once the queue's output gate opens. Commands come from the
--  command line and MSP, blocking while the motors are disabled, and from
--  the arming logic and the beeper, queued while the motors stream.
with Interfaces;
with Adaflight.Config_Groups;
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
   --  The command line's command, sent at once.
   procedure Write_Blocking (Index : Natural; Motors : Natural; Command : Interfaces.Unsigned_8);
   --  The mix's values to the motors while they are enabled.
   procedure Write_All (Values : Adaflight.Mixer.Motor_Outputs);
end Adaflight.STM32.DShot_Output;
