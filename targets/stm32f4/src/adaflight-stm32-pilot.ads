--  The pilot's side of the board: the arming logic, the modes and the RC
--  commands over the receiver's channels, as the receiver task's three
--  steps run them, with their settings from the stored configuration.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Axes;
with Adaflight.Config_Groups;
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.PID_Config;
with Adaflight.PID_Profile;
with Adaflight.RC_Command;
package Adaflight.STM32.Pilot is
   subtype Time_Us is Interfaces.Unsigned_32;
   --  What the settings read beside the configuration: the sensors detected,
   --  the gyro's sample period with the loop ratio, and a CRSF receiver.
   type Facts is record
      Sensors        : Adaflight.Arming.Sensor_Set;
      Sample_Time_Us : Natural := 125;
      Loop_Ratio     : Positive := 1;
      CRSF           : Boolean := False;
   end record;
   --  The settings from the configuration and the facts, over the selected
   --  profiles; the states start over.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   F : Facts);
   --  The settings again after a profile selection or a message changed
   --  them; the states stay.
   procedure Configure (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                        F : Facts);
   --  The mode conditions read again after a message changed them.
   procedure Reload_Modes (Config : Adaflight.Config_Groups.Configuration);
   --  The receiver task's steps over what the board senses and the flight
   --  and auxiliary channels.
   procedure Receiver_Pass
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values; Now_Us : Time_Us;
      Step : in out Adaflight.Arming.Outputs);
   procedure Modes_Pass
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values;
      Aux : Adaflight.Modes.Aux_Values; Now_Us : Time_Us; Delta_Us : Natural;
      Step : in out Adaflight.Arming.Outputs);
   procedure Update_Pass
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values;
      Inp : Adaflight.RC_Command.Command_Inputs; Now_Us : Time_Us; Step : in out Adaflight.Arming.Outputs);
   --  The receiver's frame rate tracked for the RC command smoothing.
   procedure Update_Refresh_Rate (Now_Us : Time_Us; Receiving : Boolean; Frame_Time_Us : Time_Us);
   --  A disarm a message or the failsafe asks for.
   procedure Disarm
     (Reason : Adaflight.Arming.Disarm_Reason; Now_Us : Time_Us; Step : in out Adaflight.Arming.Outputs);
   --  The failsafe's flight mode, set as the failsafe has it; Changed says it
   --  changed.
   procedure Set_Failsafe_Mode (On : Boolean; Changed : out Boolean);
   --  The PID loop's RC command pass, the yaw command reset before it, and
   --  the arming's controller pass with the runaway check.
   procedure Process_Commands;
   procedure Reset_Yaw;
   procedure Runaway_Check
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values; Now_Us : Time_Us;
      Step : in out Adaflight.Arming.Outputs);
   function Loop_Runtime return Adaflight.PID_Config.Runtime;
   function Profile return Adaflight.PID_Profile.Profile;
   function Mixer_Mode return Adaflight.Mixer_Init.Mixer_Mode;
   function Sticks_Arm return Boolean;
   function Throttle_Raised return Boolean;
   function Crash_Flip_Active return Boolean;
   function Launch_Control_Active return Boolean;
   function Airmode_Enabled return Boolean;
   function PID_Audio_Present return Boolean;
   --  The RC command's values the controller and the mixer read.
   function Setpoint_Rate (A : Adaflight.Axes.Axis) return Float;
   function Feedforward (A : Adaflight.Axes.Axis) return Float;
   function Deflection (A : Adaflight.Axes.Axis) return Float;
   function Deflection_Abs (A : Adaflight.Axes.Axis) return Float;
   function Max_Deflection_Abs return Float;
   function Max_Rate (A : Adaflight.Axes.Axis) return Float;
   function Throttle_Command return Float;
   function Motors_Reversed return Boolean;
   --  Whether the throttle is low, as the virtual current meter reads it.
   function Throttle_Low (Channels : Adaflight.RC_Command.Channel_Values) return Boolean;
   --  An arming disable reason the arming logic does not decide itself:
   --  the missing gyro, the failsafe's two, the command line, the MSP and the
   --  reboot request.
   procedure Set_Reason (Reason : Adaflight.Arming.Disable_Reason; On : Boolean);
   function Armed return Boolean;
   function Was_Ever_Armed return Boolean;
   --  The time of the last disarm and whether an arming waits, which the
   --  beeper reads.
   function Last_Disarm_Us return Time_Us;
   function Trying_To_Arm return Boolean;
   function Disabled return Adaflight.Arming.Disable_Set;
   function Flight_Modes return Adaflight.Arming.Mode_Set;
   function Active_Boxes return Adaflight.Modes.Mask;
   function Box_Active (B : Adaflight.Modes.Box) return Boolean;
   function Deflections return Adaflight.Arming.Axis_Deflections;
end Adaflight.STM32.Pilot;
