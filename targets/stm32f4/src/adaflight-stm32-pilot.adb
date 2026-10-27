with Adaflight.Config_Runtime;
package body Adaflight.STM32.Pilot is
   use type Interfaces.Unsigned_8;
   Arm          : Adaflight.Arming.State;
   Arm_Settings : Adaflight.Arming.Settings;
   M            : Adaflight.Modes.State;
   Conds        : Adaflight.Modes.Conditions;
   RC           : Adaflight.RC_Command.State;
   RC_Config    : Adaflight.RC_Command.Config;
   Runtime      : Adaflight.PID_Config.Runtime;
   PID          : Adaflight.PID_Profile.Profile;
   Mode         : Adaflight.Mixer_Init.Mixer_Mode := Adaflight.Mixer_Init.Quad_X;

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
      PID := Adaflight.Config_Runtime.PID_Profile_Of (Config.Pid_Profiles (P));
      Adaflight.PID_Config.Configure (Runtime, PID, Loop_Time, Has_Acc => F.Sensors.Acc, Serial_Rx_Is_CRSF => F.CRSF);
      if Config.Mixer_Config.Mixer_Mode in
           1 .. Adaflight.Mixer_Init.Mixer_Mode'Pos (Adaflight.Mixer_Init.Mixer_Mode'Last) + 1
      then
         Mode := Adaflight.Mixer_Init.Mixer_Mode'Val (Config.Mixer_Config.Mixer_Mode - 1);
      end if;
   end Configure;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   F : Facts) is
   begin
      Configure (Config, Runtime_Features, F);
      Adaflight.Arming.Init (Arm, Arm_Settings, Conds);
      M := (others => <>);
      Adaflight.Modes.Analyze (M, Conds);
      Adaflight.RC_Command.Init (RC, RC_Config, Runtime);
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

   procedure Process_Commands is
   begin
      Adaflight.RC_Command.Process (RC, RC_Config, Runtime);
   end Process_Commands;

   procedure Reset_Yaw is
   begin
      RC.Command (Adaflight.Axes.Axis'Pos (Adaflight.Axes.Yaw)) := 0.0;
      RC.Setpoint_Rate (Adaflight.Axes.Yaw) := 0.0;
   end Reset_Yaw;

   procedure Runaway_Check
     (Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values; Now_Us : Time_Us;
      Step : in out Adaflight.Arming.Outputs) is
   begin
      Adaflight.Arming.Process_PID_Loop (Arm, Arm_Settings, M, Sensed, Channels, Now_Us, Step);
   end Runaway_Check;

   function Loop_Runtime return Adaflight.PID_Config.Runtime is (Runtime);

   function Profile return Adaflight.PID_Profile.Profile is (PID);

   function Mixer_Mode return Adaflight.Mixer_Init.Mixer_Mode is (Mode);

   function Sticks_Arm return Boolean is (Arm.Sticks_Arm);

   function Throttle_Raised return Boolean is (Arm.Throttle_Raised);

   function Crash_Flip_Active return Boolean is (Arm.Crash_Flip_Active);

   function Launch_Control_Active return Boolean is (Adaflight.Arming.Launch_Control_Active (Arm));

   function Airmode_Enabled return Boolean is (M.Airmode_Enabled);

   function PID_Audio_Present return Boolean is
     (Adaflight.Modes.Condition_Present (Conds, Adaflight.Modes.PID_Audio));

   function Setpoint_Rate (A : Adaflight.Axes.Axis) return Float is
     (Adaflight.RC_Command.Setpoint_Rate (RC, RC_Config, A));

   function Feedforward (A : Adaflight.Axes.Axis) return Float is (Adaflight.RC_Command.Feedforward (RC, RC_Config, A));

   function Deflection (A : Adaflight.Axes.Axis) return Float is (RC.Deflection (A));

   function Deflection_Abs (A : Adaflight.Axes.Axis) return Float is (RC.Deflection_Abs (A));

   function Max_Deflection_Abs return Float is (RC.Max_Deflection_Abs);

   function Max_Rate (A : Adaflight.Axes.Axis) return Float is (RC.Max_Rate (A));

   function Throttle_Command return Float is (RC.Command (Adaflight.RC_Command.Throttle_Channel));

   function Motors_Reversed return Boolean is (RC.Motors_Reversed);

   function Throttle_Low (Channels : Adaflight.RC_Command.Channel_Values) return Boolean is
     (Adaflight.Arming."=" (Adaflight.Arming.Throttle_Status
                              (Arm_Settings, Channels, Adaflight.Modes.Is_Active (M, Adaflight.Modes.Three_D)),
                            Adaflight.Arming.Throttle_Low));

   function Armed return Boolean is (Arm.Armed);

   function Last_Disarm_Us return Time_Us is (Arm.Last_Disarm_Us);

   function Trying_To_Arm return Boolean is (Adaflight.Arming.Trying_To_Arm (Arm));

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
