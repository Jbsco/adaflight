with Adaflight.PID_Debug;
with Adaflight.STM32.Debug_Values;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.DShot;
with Adaflight.Main_Loop;
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.STM32.Blackbox;
with Adaflight.STM32.DShot_Output;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Pilot;
with Adaflight.STM32.Radio;
with Adaflight.STM32.Servos;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Control is
   Ctl          : Adaflight.PID_Controller.State;
   Mix          : Adaflight.Mixer.State;
   Mix_Config   : Adaflight.Mixer.Config;
   Disarmed     : Adaflight.Mixer.Motor_Outputs := (others => 0.0);
   Stabilised   : Boolean := False;
   Iterm_Reset  : Boolean := True;
   Anti_Gravity : Boolean := False;
   Current      : Inputs;
   Sensed       : Adaflight.Arming.Inputs;
   Channels     : Adaflight.RC_Command.Channel_Values := (others => 1_500.0);
   Step         : Adaflight.Arming.Outputs;
   Step_Changed : Boolean := False;
   Last_Step    : Integer range -1 .. Adaflight.Mixer.Dyn_LPF_Throttle_Steps := -1;
   Servo_Settings : Adaflight.Servo_Mixer.Settings;
   Servo_State    : Adaflight.Servo_Mixer.State;

   --  The selected profiles, within their four and three.
   function Index_Of (Setting : Interfaces.Unsigned_8; Last : Natural) return Natural is
     (Natural'Min (Last, Natural (Setting)));

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Battery_Voltage : Interfaces.Unsigned_16 := 0) is
      Options : constant Adaflight.Mixer_Init.Options := (others => <>);
      P       : constant Natural := Index_Of (Config.System_Config.Pid_Profile_Index, 3);
      R       : constant Natural := Index_Of (Config.System_Config.Active_Rate_Profile, 3);
      B       : constant Natural := Index_Of (Config.System_Config.Active_Battery_Profile, 2);
   begin
      Mix_Config := Adaflight.Config_Runtime.Mixer_Config_Of
        (Config.Mixer_Config, Config.Motor_Config, Config.Flight3_D_Config, Config.Rx_Config,
         Config.Control_Rate_Profiles (R), Config.Pid_Profiles (P), Config.Battery_Profiles (B),
         Config.Custom_Motor_Mixer, Runtime_Features, Options);
      Adaflight.PID_Controller.Init (Ctl, Adaflight.STM32.Pilot.Profile, Adaflight.STM32.Pilot.Loop_Runtime);
      Adaflight.PID_Controller.Set_Stabilisation (Ctl, Stabilised);
      Mix := (others => <>);
      Adaflight.Mixer.Init_RPM_Limiter (Mix, Mix_Config, Adaflight.STM32.Pilot.Loop_Runtime, Battery_Voltage);
      Adaflight.Mixer.Init_Dyn_Idle
        (Mix, Mix_Config, Adaflight.STM32.Pilot.Loop_Runtime, Adaflight.STM32.Pilot.Profile,
         DShot_Telemetry => Adaflight.STM32.Motors.Telemetry_Configured (Config), Motor_Idle => Natural'Min (2_000, Natural (Config.Motor_Config.Motor_Idle)));
      Last_Step := Mix.Dyn_LPF_Previous_Step;
      Step_Changed := False;
   end Init;

   procedure Set_Servo_Config (Config : Adaflight.Config_Groups.Configuration) is
      use type Interfaces.Unsigned_8;
   begin
      Servo_Settings.Params := Config.Servo_Params;
      Servo_Settings.Lowpass_Hz := Config.Servo_Config.Servo_Lowpass_Freq;
      Servo_Settings.Tri_Unarmed := Config.Servo_Config.Tri_Unarmed_Servo /= 0;
      Servo_Settings.Forward_Start := Natural (Config.Servo_Config.Channel_Forwarding_Start_Channel);
      Servo_Settings.Mixed_Tilt := Config.Gimbal_Config.Mode = 1;
      Servo_Settings.Mid_RC :=
        Interfaces.Unsigned_16'Max (1_200, Interfaces.Unsigned_16'Min (1_700, Config.Rx_Config.Midrc));
      Servo_Settings.Max_Aux_Channel := Natural (Config.Rx_Config.Max_Aux_Channel);
   end Set_Servo_Config;

   procedure Init_Servos
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Channel_Count : Natural; Loop_Time_Us : Positive)
   is
      use type Interfaces.Unsigned_32;
      Servo_Tilt         : constant Interfaces.Unsigned_32 := 16#0000_0020#;
      Channel_Forwarding : constant Interfaces.Unsigned_32 := 16#0010_0000#;
   begin
      Servo_Settings.Mode := Adaflight.STM32.Pilot.Mixer_Mode;
      Servo_Settings.Options := (others => <>);
      Servo_Settings.Servo_Tilt := (Runtime_Features and Servo_Tilt) /= 0;
      Servo_Settings.Channel_Forwarding := (Runtime_Features and Channel_Forwarding) /= 0;
      Servo_Settings.Three_D := (Runtime_Features and Adaflight.Config_Fix.Feature_3D) /= 0;
      Servo_Settings.Custom_Rules := Config.Custom_Servo_Mixers;
      Servo_Settings.Channel_Count := Natural'Min (Adaflight.Servo_Mixer.Max_Channels, Channel_Count);
      Set_Servo_Config (Config);
      Adaflight.Servo_Mixer.Init (Servo_State, Servo_Settings, Float (Loop_Time_Us) * 1.0E-6);
      if Servo_State.Uses_Servos then
         Adaflight.STM32.Servos.Init (Config);
      end if;
   end Init_Servos;

   procedure Load_Servo_Rules (Rules : Adaflight.Config_Groups.Servo_Mixer_Record_List_16) is
   begin
      Adaflight.Servo_Mixer.Load_Custom_Rules (Servo_State, Rules);
   end Load_Servo_Rules;

   function Uses_Servos return Boolean is (Servo_State.Uses_Servos);

   function Servo (Index : Adaflight.Servo_Mixer.Servo_Index) return Interfaces.Integer_16 is
     (Servo_State.Servo (Index));

   procedure Set_Stabilisation (Enabled : Boolean; Iterm_Reset : Boolean) is
   begin
      Stabilised := Enabled;
      Control.Iterm_Reset := Iterm_Reset;
      Adaflight.PID_Controller.Set_Stabilisation (Ctl, Enabled);
   end Set_Stabilisation;

   procedure Set_Anti_Gravity (Enabled : Boolean) is
   begin
      Anti_Gravity := Enabled;
   end Set_Anti_Gravity;

   procedure Nothing is null;

   --  The controller's loop over the rates, the RC command's setpoints and
   --  feedforward, the modes and the attitude.
   procedure Run_Controller is
      Inp   : Adaflight.PID_Controller.Inputs;
      Modes : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
   begin
      Inp.Gyro := Current.Gyro;
      for A in Adaflight.Axes.Axis loop
         Inp.Setpoint (A) := Float'Max (-Adaflight.PID_Controller.Rate_Bound,
                                        Float'Min (Adaflight.PID_Controller.Rate_Bound,
                                                   Adaflight.STM32.Pilot.Setpoint_Rate (A)));
         Inp.Feedforward (A) := Float'Max (-Adaflight.PID_Controller.Rate_Bound,
                                           Float'Min (Adaflight.PID_Controller.Rate_Bound,
                                                      Adaflight.STM32.Pilot.Feedforward (A)));
         Inp.Max_RC_Rate (A) := Float'Max (0.5, Float'Min (2_000.0, Adaflight.STM32.Pilot.Max_Rate (A)));
      end loop;
      Inp.Anti_Gravity_Enabled := Anti_Gravity;
      Inp.Zero_Throttle_Iterm_Reset := Iterm_Reset;
      Inp.Angle_Mode := Modes (Adaflight.Arming.Angle_Mode);
      Inp.Horizon_Mode := Modes (Adaflight.Arming.Horizon_Mode);
      Inp.Attitude := Current.Attitude;
      Inp.Trims := Current.Trims;
      for A in Adaflight.PID_Controller.Level_Axis loop
         Inp.Deflection (A) := Float'Max (-1.0, Float'Min (1.0, Adaflight.STM32.Pilot.Deflection (A)));
      end loop;
      Inp.Now_Us := Current.Now_Us;
      Inp.Armed := Current.Armed;
      Inp.Acc_Present := Current.Acc_Present;
      Inp.Gyro_Overflow := Current.Gyro_Overflow;
      Inp.Motor_Mix_Range := Mix.Mix_Range;
      Inp.Launch_Control_Active := Adaflight.STM32.Pilot.Launch_Control_Active;
      Inp.Yaw_Deflection := Float'Max (-1.0, Float'Min (1.0, Adaflight.STM32.Pilot.Deflection (Adaflight.Axes.Yaw)));
      Inp.Yaw_Spin_Detected := Current.Yaw_Spin;
      Inp.Throttle_Raised := Adaflight.STM32.Pilot.Throttle_Raised;
      Inp.Max_Deflection := Float'Max (0.0, Float'Min (1.0, Adaflight.STM32.Pilot.Max_Deflection_Abs));
      Inp.RC_Throttle := Mix.RC_Throttle;
      Inp.Jerk_Magnitude := Float'Max (0.0, Float'Min (1.0e30, Current.Jerk_Magnitude));
      Inp.Passthru_Mode := Modes (Adaflight.Arming.Passthru_Mode);
      Inp.Alt_Hold_Mode := Modes (Adaflight.Arming.Alt_Hold_Mode);
      Inp.Pos_Hold_Mode := Modes (Adaflight.Arming.Pos_Hold_Mode);
      Inp.GPS_Rescue_Mode := Modes (Adaflight.Arming.GPS_Rescue_Mode);
      Inp.Autopilot_Angle := Current.Autopilot_Angles;
      Inp.Autopilot_Max_Angle := Current.Autopilot_Max_Angle;
      Inp.Autopilot_In_Control := Current.Autopilot_Control;
      Inp.Below_Landing_Altitude := Current.Below_Landing;
      Adaflight.PID_Controller.Update (Ctl, Adaflight.STM32.Pilot.Loop_Runtime, Adaflight.STM32.Pilot.Profile, Inp);
      Adaflight.PID_Debug.Record_Loop
        (Adaflight.STM32.Debug_Values.State, Ctl, Adaflight.STM32.Pilot.Loop_Runtime, Inp, Adaflight.STM32.Debug_Values.Axis);
   end Run_Controller;

   procedure Runaway_Check is
   begin
      Sensed.PID_Sums := PID_Sums;
      Adaflight.STM32.Pilot.Runaway_Check (Sensed, Channels, Current.Now_Us, Step);
   end Runaway_Check;

   --  The mixer's loop over the throttle, the arming and the modes, the
   --  stick deflections, the rates, the tilt and the attitude, with the
   --  autopilot's throttle under altitude hold or the GPS rescue; the
   --  throttle step noted for the gyro's dynamic lowpass.
   procedure Run_Mixer is
      Inp   : Adaflight.Mixer.Inputs;
      Modes : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
   begin
      Inp.RC_Throttle := Float'Max (1_000.0, Float'Min (2_000.0, Adaflight.STM32.Pilot.Throttle_Command));
      Inp.RC_Data_Throttle := Float'Max (750.0, Float'Min (2_250.0, Current.RC_Data_Throttle));
      Inp.Box_3D := Current.Box_3D;
      Inp.Motors_Reversed := Adaflight.STM32.Pilot.Motors_Reversed;
      Inp.Throttle_Angle_Correction := Integer'Max (-1_000, Integer'Min (1_000, Current.Throttle_Correction));
      Inp.Time_Us := Current.Now_Us;
      Inp.Armed := Current.Armed;
      Inp.Airmode := Adaflight.STM32.Pilot.Airmode_Enabled;
      Inp.Failsafe := Current.Failsafe;
      Inp.Max_Deflection := Float'Max (0.0, Float'Min (1.0, Adaflight.STM32.Pilot.Max_Deflection_Abs));
      Inp.Launch_Control_Active := Adaflight.STM32.Pilot.Launch_Control_Active;
      Inp.Yaw_Spin_Detected := Current.Yaw_Spin;
      Inp.Crash_Flip_Active := Adaflight.STM32.Pilot.Crash_Flip_Active;
      Inp.Alt_Hold_Mode := Modes (Adaflight.Arming.Alt_Hold_Mode);
      Inp.Pos_Hold_Mode := Modes (Adaflight.Arming.Pos_Hold_Mode);
      Inp.GPS_Rescue_Mode := Modes (Adaflight.Arming.GPS_Rescue_Mode);
      Inp.Autopilot_Throttle_Valid := True;
      Inp.Autopilot_Throttle := Current.Autopilot_Throttle;
      for A in Adaflight.Axes.Axis loop
         Inp.Deflection (A) := Float'Max (-1.0, Float'Min (1.0, Adaflight.STM32.Pilot.Deflection (A)));
         Inp.Deflection_Abs (A) := Float'Max (0.0, Float'Min (1.0, Adaflight.STM32.Pilot.Deflection_Abs (A)));
      end loop;
      Inp.Gyro := Current.Gyro;
      Inp.Acc_Present := Current.Acc_Present;
      Inp.Cos_Tilt := Float'Max (-1.0, Float'Min (1.0, Current.Cos_Tilt));
      Inp.Attitude := Current.Attitude;
      Inp.Throttle_Raised := Adaflight.STM32.Pilot.Throttle_Raised;
      Inp.Battery_Voltage := Current.Battery_Voltage;
      Inp.Sag_Cell_Voltage := Current.Sag_Cell_Voltage;
      Inp.Battery_Voltage_Latest := Current.Battery_Latest;
      Inp.Motors_Enabled := Adaflight.STM32.Motors.Enabled;
      Inp.DShot_Telemetry := Adaflight.STM32.Motors.Telemetry_On;
      Inp.RPM_Average := Adaflight.STM32.DShot_Output.Rpm_Average;
      Inp.Min_Motor_Frequency := Float'Max (0.0, Float'Min (1.0e6, Adaflight.STM32.DShot_Output.Min_Frequency));
      for M in Inp.Motor_Enabled'Range loop
         Inp.Motor_Enabled (M) := Adaflight.STM32.Motors.Motor_Enabled (M);
      end loop;
      Adaflight.Mixer.Update
        (Mix, Mix_Config, Ctl, Adaflight.STM32.Pilot.Loop_Runtime, Adaflight.STM32.Pilot.Profile, Inp);
      if not Inp.Armed then
         for M in 0 .. Mix_Config.Count - 1 loop
            Mix.Motors (M) := Disarmed (M);
         end loop;
      end if;
      Step_Changed := Mix.Dyn_LPF_Previous_Step /= Last_Step;
      Last_Step := Mix.Dyn_LPF_Previous_Step;
   end Run_Mixer;

   --  The mix's outputs to the motors.
   procedure Write_Motors is
   begin
      Adaflight.STM32.DShot_Output.Write_All (Mix.Motors);
   end Write_Motors;

   --  The servo mixer's loop over the arming, the passthrough, the servo
   --  and camera stabilization boxes, the RC commands and the PID sums, the
   --  attitude, the first motor and the receiver's channels, then its writes
   --  to the servo outputs in their order.
   procedure Write_Servos is
      Inp   : Adaflight.Servo_Mixer.Inputs;
      W     : Adaflight.Servo_Mixer.Servo_Writes;
      Count : Adaflight.Servo_Mixer.Write_Count;
   begin
      Inp.Armed := Current.Armed;
      Inp.Passthru := Adaflight.STM32.Pilot.Flight_Modes (Adaflight.Arming.Passthru_Mode);
      Inp.Servo_Box :=
        (Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Servo_1),
         Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Servo_2),
         Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Servo_3));
      Inp.Camera_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Cam_Stab);
      for A in Adaflight.Servo_Mixer.Axis loop
         Inp.RC_Command (A) := Float'Max (-4_000.0, Float'Min (4_000.0, Adaflight.STM32.Pilot.Command (A)));
         Inp.PID_Sum (A) :=
           Float'Max (-4_000.0, Float'Min (4_000.0, Ctl.Data (Adaflight.Axes.Axis'Val (A)).Sum));
      end loop;
      Inp.Roll := Interfaces.Integer_16
        (Integer'Max (-32_768, Integer'Min (32_767, Current.Attitude (Adaflight.Axes.Roll))));
      Inp.Pitch := Interfaces.Integer_16
        (Integer'Max (-32_768, Integer'Min (32_767, Current.Attitude (Adaflight.Axes.Pitch))));
      Inp.Motor_Device := Adaflight.STM32.Motors.Count > 0;
      Inp.External_Motor :=
        Interfaces.Unsigned_16 (Adaflight.DShot.To_External (Mix.Motors (0), Servo_Settings.Three_D));
      Inp.Motor := Mix.Motors (0);
      for Ch in Adaflight.Servo_Mixer.Channel_Index loop
         Inp.RC_Data (Ch) := Float'Max (-10_000.0, Float'Min (10_000.0, Adaflight.STM32.Radio.Channel (Ch)));
      end loop;
      Adaflight.Servo_Mixer.Write_Servos (Servo_State, Servo_Settings, Inp, W, Count);
      for K in 1 .. Count loop
         Adaflight.STM32.Servos.Write (W (K).Index, W (K).Value);
      end loop;
   end Write_Servos;

   package Loop_Pass is new Adaflight.Main_Loop
     (Reset_Yaw       => Adaflight.STM32.Pilot.Reset_Yaw,
      RC_Command      => Adaflight.STM32.Pilot.Process_Commands,
      Launch_Wing     => Nothing,
      PID_Controller  => Run_Controller,
      Runaway_Check   => Runaway_Check,
      PID_Audio       => Nothing,
      Mix_Table       => Run_Mixer,
      Write_Servos    => Write_Servos,
      Write_Motors    => Write_Motors,
      Blackbox_Update => Adaflight.STM32.Blackbox.Update);

   procedure Pass
     (I : Inputs; Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values;
      Resets_Yaw, Log_Device, CLI_Open, PID_Audio : Boolean; Asked : out Adaflight.Arming.Outputs) is
   begin
      Current := I;
      Control.Sensed := Sensed;
      Control.Channels := Channels;
      Step := (others => <>);
      Step_Changed := False;
      Loop_Pass.PID_Loop
        ((Wing_Launch => False),
         (Resets_Yaw => Resets_Yaw, Uses_Servos => Servo_State.Uses_Servos, Log_Device => Log_Device,
          CLI_Open => CLI_Open, PID_Audio => PID_Audio));
      Asked := Step;
   end Pass;

   function Held (Value : Float) return Adaflight.Mixer.Motor_Value is
     (Float'Max (0.0, Float'Min (2_048.0, Value)));

   procedure Reset_Disarmed is
   begin
      Disarmed := (others => Mix_Config.Disarm_Output);
   end Reset_Disarmed;

   procedure Set_Disarmed (Values : Adaflight.MSP_Motor_In.Motor_Values) is
   begin
      for M in 0 .. Natural'Min (Mix_Config.Count, Values'Length) - 1 loop
         Disarmed (M) := Held (Values (Values'First + M));
      end loop;
   end Set_Disarmed;

   procedure Set_Disarmed_Motor (Index : Natural; Value : Float) is
   begin
      if Index in Disarmed'Range then
         Disarmed (Index) := Held (Value);
      end if;
   end Set_Disarmed_Motor;

   procedure Set_Disarmed_All (Value : Float) is
   begin
      for M in 0 .. Mix_Config.Count - 1 loop
         Disarmed (M) := Held (Value);
      end loop;
   end Set_Disarmed_All;

   function Motors_Running return Boolean is
     (Adaflight.STM32.Pilot.Armed
      or else (for some M in 0 .. Mix_Config.Count - 1 => Disarmed (M) /= Mix_Config.Disarm_Output));

   procedure Stop_Motors is
   begin
      for M in 0 .. Mix_Config.Count - 1 loop
         Mix.Motors (M) := Held (Mix_Config.Disarm_Output);
      end loop;
      Adaflight.STM32.DShot_Output.Write_All (Mix.Motors);
      Adaflight.STM32.Time.Delay_Ms (50);
   end Stop_Motors;

   procedure Reset_RPM_Limiter (Battery_Voltage : Interfaces.Unsigned_16) is
   begin
      Adaflight.Mixer.Reset_RPM_Limiter (Mix, Mix_Config, Battery_Voltage);
   end Reset_RPM_Limiter;

   function Throttle return Float is (Mix.Throttle);

   function Throttle_Step_Changed return Boolean is (Step_Changed);

   function Throttle_Step return Float is
     (Float (Integer'Max (0, Last_Step)) / Float (Adaflight.Mixer.Dyn_LPF_Throttle_Steps));

   function Motors return Adaflight.Mixer.Motor_Outputs is (Mix.Motors);

   function Motor_Count return Natural is (Mix_Config.Count);

   function Terms (A : Adaflight.Axes.Axis) return Adaflight.PID_Controller.Terms is (Ctl.Data (A));

   function Previous_Setpoint (A : Adaflight.Axes.Axis) return Float is (Ctl.Previous_PID_Setpoint (A));

   function Output_Low return Float is (Mix_Config.Output_Low);

   function Disarm_Output return Float is (Mix_Config.Disarm_Output);

   function Output_High return Float is (Mix_Config.Output_High);

   function Crash_Recovery_Active return Boolean is (Adaflight.PID_Controller.Crash_Recovery_Active (Ctl));

   function PID_Sums return Adaflight.Arming.Axis_Sums is
      Sums : Adaflight.Arming.Axis_Sums := (others => 0.0);
   begin
      for A in Adaflight.Axes.Axis loop
         Sums (A) := Float'Max (-2.0 ** 32, Float'Min (2.0 ** 32, Ctl.Data (A).Sum));
      end loop;
      return Sums;
   end PID_Sums;
end Adaflight.STM32.Control;
