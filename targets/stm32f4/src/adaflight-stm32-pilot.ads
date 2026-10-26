--  The pilot's side of the board: the arming logic, the modes and the RC
--  commands over the receiver's channels, as the receiver task's three
--  steps run them, with their settings from the stored configuration.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Config_Groups;
with Adaflight.Modes;
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
   --  A disarm a message asks for.
   procedure Disarm (Now_Us : Time_Us; Step : in out Adaflight.Arming.Outputs);
   function Armed return Boolean;
   function Disabled return Adaflight.Arming.Disable_Set;
   function Flight_Modes return Adaflight.Arming.Mode_Set;
   function Active_Boxes return Adaflight.Modes.Mask;
   function Box_Active (B : Adaflight.Modes.Box) return Boolean;
   function Deflections return Adaflight.Arming.Axis_Deflections;
end Adaflight.STM32.Pilot;
