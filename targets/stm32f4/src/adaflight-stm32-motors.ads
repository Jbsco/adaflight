--  The board's motor outputs in DShot or the analog protocols from the
--  timers. Each motor's pin comes from the stored configuration through its
--  output order, and its timer channel from the board's timer map and the
--  processor's timer table. In DShot the stream of the map's DMA option
--  writes a frame's sixteen bits and two zero slots into the channel's
--  compare register at each compare event, twenty counts a bit at the
--  protocol's bit clock: a frame loads into its motor's buffer and arms its
--  stream, then each timer restarts and asks for the transfers. In PWM,
--  OneShot, MultiShot and brushed a write sets the compare register to the
--  motor value's pulse, and without continuous updates each timer's first
--  motor forces an overflow that starts the pulses before the registers
--  clear.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.DShot;
with Adaflight.MSP_Motor_In;
package Adaflight.STM32.Motors is
   --  The outputs of the mixer's motors from the configuration; every motor
   --  needs its timer channel, and its stream in DShot, or none is driven.
   --  The analog protocols' idle pulse is the 3D neutral pulse when 3D runs.
   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural; Three_D : Boolean);
   --  The writes start once the start of the flight software is done, and
   --  stop while the command line or MSP sends blocking DShot commands; the
   --  stop clears the analog pulses.
   procedure Enable;
   procedure Disable;
   --  The outputs stopped before a reboot: the analog pulses cleared, the
   --  writes stopped, and a wait of 1.5 ms, half a second more for PWM,
   --  OneShot and MultiShot so their ESCs disarm.
   procedure Shutdown;
   --  The configured outputs' pins driven high as plain outputs, the level an
   --  ESC's serial link idles at.
   procedure Hold_Idle;
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
   --  An analog motor's value as its pulse, and the end of an update: without
   --  continuous updates each timer's first motor forces its overflow and
   --  every compare register clears.
   procedure Write_Pulse (Index : Natural; Value : Float);
   procedure Complete_Pulses;
   --  Whether the motors run bidirectional DShot: the configured telemetry
   --  with a DShot protocol on an output that captures the replies, from the
   --  configuration before the outputs start, and once they have.
   function Telemetry_Configured (C : Adaflight.Config_Groups.Configuration) return Boolean;
   function Telemetry_On return Boolean;
   --  Each motor's capture after its last frame for the telemetry read, and
   --  the time the first motor switched to input, zero before.
   procedure Captures (C : out Adaflight.DShot.Captures; Stamp_Us : out Interfaces.Unsigned_32);
   --  The first Processed motors leave input, in order, and with Done the
   --  channels go back to output and the switch time clears.
   procedure Leave_Input (Processed : Natural; Done : Boolean);
end Adaflight.STM32.Motors;
