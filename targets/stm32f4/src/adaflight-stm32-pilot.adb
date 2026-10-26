with Adaflight.Axes;
with Adaflight.Config_Runtime;
with Adaflight.PID_Config;
package body Adaflight.STM32.Pilot is
   Arm          : Adaflight.Arming.State;
   Arm_Settings : Adaflight.Arming.Settings;
   M            : Adaflight.Modes.State;
   Conds        : Adaflight.Modes.Conditions;
   RC           : Adaflight.RC_Command.State;
   RC_Config    : Adaflight.RC_Command.Config;
   Loop_Runtime : Adaflight.PID_Config.Runtime;

   --  The selected PID and rate profiles, within their four.
   function Profile_Index (Setting : Interfaces.Unsigned_8) return Natural is
     (Natural'Min (3, Natural (Setting)));

   procedure Configure (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                        F : Facts) is
      P : constant Natural := Profile_Index (Config.System_Config.Pid_Profile_Index);
      R : constant Natural := Profile_Index (Config.System_Config.Active_Rate_Profile);
      Sample : constant Adaflight.PID_Config.Loop_Time_Us :=
        Adaflight.PID_Config.Loop_Time_Us'Max (100, Adaflight.PID_Config.Loop_Time_Us'Min (100_000, F.Sample_Time_Us));
      Loop_Time : constant Adaflight.PID_Config.Loop_Time_Us :=
        Adaflight.PID_Config.Loop_Time_Us'Min (100_000, Sample * F.Loop_Ratio);
   begin
      Conds := Adaflight.Config_Runtime.Conditions_Of (Config.Mode_Activation_Conditions);
      Arm_Settings := Adaflight.Config_Runtime.Arming_Settings_Of
        (Config.Arming_Config, Config.System_Config, Config.Rx_Config, Config.Flight3_D_Config,
         Config.Mixer_Config, Config.Pid_Config, Config.Scheduler_Config, Config.Motor_Config,
         Config.Failsafe_Config, Config.Gps_Rescue_Config, Config.Pid_Profiles (P), Runtime_Features, F.Sensors);
      RC_Config := Adaflight.Config_Runtime.RC_Config_Of
        (Config.Rx_Config, Config.Rc_Controls_Config, Config.Control_Rate_Profiles (R), Config.Pid_Config, Sample,
         Config.Flight3_D_Config, Runtime_Features);
      Adaflight.PID_Config.Configure
        (Loop_Runtime, Adaflight.Config_Runtime.PID_Profile_Of (Config.Pid_Profiles (P)), Loop_Time,
         Has_Acc => F.Sensors.Acc, Serial_Rx_Is_CRSF => F.CRSF);
   end Configure;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   F : Facts) is
   begin
      Configure (Config, Runtime_Features, F);
      Adaflight.Arming.Init (Arm, Arm_Settings, Conds);
      M := (others => <>);
      Adaflight.Modes.Analyze (M, Conds);
      Adaflight.RC_Command.Init (RC, RC_Config, Loop_Runtime);
   end Init;

   procedure Reload_Modes (Config : Adaflight.Config_Groups.Configuration) is
   begin
      Conds := Adaflight.Config_Runtime.Conditions_Of (Config.Mode_Activation_Conditions);
      Adaflight.Modes.Analyze (M, Conds);
   end Reload_Modes;

   procedure Receiver_Pass
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values; Now_Us : Time_Us;
      Step : in out Adaflight.Arming.Outputs) is
   begin
      Adaflight.Arming.Process_Rx (Arm, Arm_Settings, M, Sensed, Channels, Now_Us, Step);
   end Receiver_Pass;

   procedure Modes_Pass
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values;
      Aux : Adaflight.Modes.Aux_Values; Now_Us : Time_Us; Delta_Us : Natural;
      Step : in out Adaflight.Arming.Outputs) is
   begin
      Adaflight.Arming.Process_Rx_Modes (Arm, Arm_Settings, M, Conds, Aux, Sensed, Channels, Now_Us, Delta_Us, Step);
   end Modes_Pass;

   procedure Update_Pass
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values;
      Inp : Adaflight.RC_Command.Command_Inputs; Now_Us : Time_Us; Step : in out Adaflight.Arming.Outputs) is
   begin
      Adaflight.RC_Command.Update_Commands (RC, RC_Config, Channels, Inp);
      Adaflight.Arming.Update_Status (Arm, Arm_Settings, M, Conds, Sensed, Channels, Now_Us, Step);
   end Update_Pass;

   procedure Update_Refresh_Rate (Now_Us : Time_Us; Receiving : Boolean; Frame_Time_Us : Time_Us) is
   begin
      Adaflight.RC_Command.Update_Refresh_Rate (RC, Now_Us, Receiving, Frame_Time_Us);
   end Update_Refresh_Rate;

   procedure Disarm (Now_Us : Time_Us; Step : in out Adaflight.Arming.Outputs) is
   begin
      Adaflight.Arming.Disarm (Arm, Arm_Settings, M, Adaflight.Arming.Serial_Command, Now_Us, Step);
   end Disarm;

   function Armed return Boolean is (Arm.Armed);

   function Disabled return Adaflight.Arming.Disable_Set is (Arm.Disabled);

   function Flight_Modes return Adaflight.Arming.Mode_Set is (Arm.Flight_Modes);

   function Active_Boxes return Adaflight.Modes.Mask is (M.Active_Mask);

   function Box_Active (B : Adaflight.Modes.Box) return Boolean is (Adaflight.Modes.Is_Active (M, B));

   function Deflections return Adaflight.Arming.Axis_Deflections is
      D : Adaflight.Arming.Axis_Deflections := (others => 0.0);
   begin
      for A in Adaflight.Axes.Axis loop
         D (A) := Float'Max (0.0, Float'Min (1.0, RC.Deflection_Abs (A)));
      end loop;
      return D;
   end Deflections;
end Adaflight.STM32.Pilot;
