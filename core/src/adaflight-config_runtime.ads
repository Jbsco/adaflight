--  The runtime records built from the stored configuration. Each field is
--  held to its runtime range, which a stored value leaves only through a
--  foreign image, and each code to its names. The order rules the runtime
--  predicates need come from the configuration fix.
with Interfaces; use Interfaces;
with Adaflight.Adjustments;
with Adaflight.Arming;
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.Dyn_Notch;
with Adaflight.Failsafe;
with Adaflight.Gyro_Filters;
with Adaflight.Mixer;
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.PID_Config;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.Rates;
with Adaflight.RC_Command;
with Adaflight.Receiver;
with Adaflight.RPM_Filter;
with Adaflight.Sensor_Alignment;

package Adaflight.Config_Runtime with SPARK_Mode is

   function PID_Profile_Of (P : Pid_Profile_Record) return PID_Profile.Profile
     with Pre => Config_Fix.Fixed_PID_Profile (P);

   --  The rate profile from a stored rate profile; the rates have no order
   --  rule, so nothing is asked of the fix.
   function Rate_Profile_Of (R : Control_Rate_Config_Record) return Rates.Profile;

   --  The arming settings from the stored arming, system, receiver, 3D,
   --  mixer and PID loop groups, the current PID profile, the features in
   --  use and the sensors found at boot.
   function Arming_Settings_Of
     (A : Arming_Config_Record; Sys : System_Config_Record; R : Rx_Config_Record;
      Flight_3D : Flight3_D_Config_Record; Mixer_Mode : Unsigned_8; Loop_Rate : Pid_Config_Record;
      P : Pid_Profile_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set) return Arming.Settings;

   --  The mode conditions from the stored ones. A mode outside the box
   --  table makes a condition that is never active, and a link outside it
   --  no link (D6).
   function Conditions_Of (C : Mode_Activation_Condition_Record_List_20) return Modes.Conditions;

   --  The failsafe settings from the stored failsafe group and the
   --  autopilot's loss policy.
   function Failsafe_Settings_Of (F : Failsafe_Config_Record; A : Autopilot_Config_Record) return Failsafe.Settings;

   --  The receiver settings from the stored receiver, channel range,
   --  channel failsafe, 3D and failsafe groups, the features in use, which
   --  name the source as the reference's receiver setup does, and the
   --  channel count the protocol reports. An equal channel range is widened
   --  by one step and a zero frame period reads as one (D6).
   function Receiver_Settings_Of
     (R : Rx_Config_Record; Ranges : Rx_Channel_Range_Config_Record_List_4;
      Failsafes : Rx_Failsafe_Channel_Config_Record_List_18; Flight_3D : Flight3_D_Config_Record;
      F : Failsafe_Config_Record; Features : Unsigned_32; Reported_Channels : Natural)
      return Receiver.Settings
     with Pre => Reported_Channels <= Receiver.Channel_Count;

   --  The gyro settings from the stored gyro, dynamic notch, RPM filter,
   --  gyro device, board alignment, motor and PID loop groups, with what the
   --  hardware gives: the sample time, whose product with the loop ratio is
   --  the loop time, the gyro's scale, the motors in use, and whether the
   --  gyro protects against overflow.
   function Gyro_Settings_Of
     (G : Gyro_Config_Record; N : Dyn_Notch_Config_Record; R : Rpm_Filter_Config_Record;
      Device : Gyro_Device_Config_Record; Board : Board_Alignment_Record; Motor : Motor_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us; Scale : Float;
      Motors : Mixer.Motor_Count; Overflow_Protected : Boolean) return Gyro_Filters.Settings
     with Pre => Config_Fix.Fixed_Gyro_Filters (G) and then Loop_Rate.Pid_Process_Denom >= 1
                 and then Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom) <= PID_Config.Loop_Time_Us'Last
                 and then Scale in 2.0 ** (-10) .. 1.0;

   --  The RC command settings from the stored receiver, RC controls and
   --  PID loop groups and the current rate profile, with the sample time
   --  whose product with the loop ratio is the loop time.
   function RC_Config_Of
     (R : Rx_Config_Record; Controls : Rc_Controls_Config_Record; Rate : Control_Rate_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us) return RC_Command.Config
     with Pre => Loop_Rate.Pid_Process_Denom >= 1
                 and then Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom) <= PID_Config.Loop_Time_Us'Last;

   --  The adjustment settings from the stored receiver and system groups.
   function Adjustment_Settings_Of (R : Rx_Config_Record; Sys : System_Config_Record) return Adjustments.Settings;

private

   function Held (V : Integer; Low : Integer; High : Integer) return Integer is
     (Integer'Min (High, Integer'Max (Low, V)))
     with Pre  => Low <= High,
          Post => Held'Result in Low .. High;

   --  A code held to the last of its names.
   function Code (V : Unsigned_8; Last : Natural) return Natural is (Natural'Min (Natural (V), Last))
     with Post => Code'Result <= Last;

   function Axis_Gains_Of (G : Pidf_Record) return Axis_Gains is
     (P => Held (Integer (G.P), 0, Gain_Max),
      I => Held (Integer (G.I), 0, Gain_Max),
      D => Held (Integer (G.D), 0, Gain_Max),
      F => Held (Integer (G.F), 0, F_Gain_Max),
      S => Held (Integer (G.S), 0, Gain_Max));

   --  The level gains are the fourth PID entry, with the angle feedforward
   --  in the low byte of its feedforward gain.
   function Level_Gains_Of (G : Pidf_Record) return Level_Gains is
     (P => Held (Integer (G.P), 0, 200),
      I => Held (Integer (G.I), 0, 100),
      D => Held (Integer (G.D), 10, 200),
      F => Held (Integer (G.F and 16#FF#), 0, 200));

   function PID_Profile_Of (P : Pid_Profile_Record) return PID_Profile.Profile is
     (Gains                    => (Roll => Axis_Gains_Of (P.Pid (0)), Pitch => Axis_Gains_Of (P.Pid (1)),
                                   Yaw => Axis_Gains_Of (P.Pid (2))),
      D_Max                    => (Roll  => Held (Integer (P.D_Max (0)), 0, Gain_Max),
                                   Pitch => Held (Integer (P.D_Max (1)), 0, Gain_Max),
                                   Yaw   => Held (Integer (P.D_Max (2)), 0, Gain_Max)),
      Level                    => Level_Gains_Of (P.Pid (3)),
      Angle_Earth_Ref          => Held (Integer (P.Angle_Earth_Ref), 0, 100),
      Horizon_Ignore_Sticks    => P.Horizon_Ignore_Sticks /= 0,
      Horizon_Limit_Degrees    => Held (Integer (P.Horizon_Limit_Degrees), 10, 250),
      Horizon_Delay_Ms         => Held (Integer (P.Horizon_Delay_Ms), 10, 5000),
      Rate_Accel_Limit         => Held (Integer (P.Rate_Accel_Limit), 0, 500),
      Yaw_Rate_Accel_Limit     => Held (Integer (P.Yaw_Rate_Accel_Limit), 0, 500),
      Anti_Gravity_Gain        => Held (Integer (P.Anti_Gravity_Gain), 0, Gain_Max),
      Anti_Gravity_P_Gain      => Held (Integer (P.Anti_Gravity_P_Gain), 0, Gain_Max),
      Crash_Time               => Held (Integer (P.Crash_Time), 100, 5000),
      Crash_Delay              => Held (Integer (P.Crash_Delay), 0, 500),
      Crash_Recovery_Angle     => Held (Integer (P.Crash_Recovery_Angle), 5, 30),
      Crash_Recovery_Rate      => Held (Integer (P.Crash_Recovery_Rate), 50, 255),
      Crash_Gyro_Threshold     => Held (Integer (P.Crash_Gthreshold), 100, 2000),
      Crash_Dterm_Threshold    => Held (Integer (P.Crash_Dthreshold), 10, 2000),
      Crash_Setpoint_Threshold => Held (Integer (P.Crash_Setpoint_Threshold), 50, 2000),
      Crash_Limit_Yaw          => Held (Integer (P.Crash_Limit_Yaw), 0, 1000),
      Crash_Recovery           =>
        Crash_Recovery_Mode'Val (Code (P.Crash_Recovery, Crash_Recovery_Mode'Pos (Crash_Recovery_Mode'Last))),
      Iterm_Windup             => Held (Integer (P.Iterm_Windup), 20, 100),
      PID_Sum_Limit            => Held (Integer (P.Pid_Sum_Limit), 100, 1000),
      PID_Sum_Limit_Yaw        => Held (Integer (P.Pid_Sum_Limit_Yaw), 100, 1000),
      Iterm_Rotation           => P.Iterm_Rotation /= 0,
      Iterm_Relax              =>
        Iterm_Relax_Mode'Val (Code (P.Iterm_Relax, Iterm_Relax_Mode'Pos (Iterm_Relax_Mode'Last))),
      Iterm_Relax_Type         =>
        Iterm_Relax_Source'Val (Code (P.Iterm_Relax_Type, Iterm_Relax_Source'Pos (Iterm_Relax_Source'Last))),
      Iterm_Relax_Cutoff       => Held (Integer (P.Iterm_Relax_Cutoff), 1, 50),
      Acro_Trainer_Angle_Limit => Held (Integer (P.Acro_Trainer_Angle_Limit), 10, 80),
      Acro_Trainer_Lookahead_Ms => Held (Integer (P.Acro_Trainer_Lookahead_Ms), 10, 200),
      Acro_Trainer_Debug_Axis  => Held (Integer (P.Acro_Trainer_Debug_Axis), 0, 1),
      Acro_Trainer_Gain        => Held (Integer (P.Acro_Trainer_Gain), 25, 255),
      Dterm_LPF1_Dyn_Min_Hz    => Held (Integer (P.Dterm_Lpf1_Dyn_Min_Hz), 0, 1000),
      Dterm_LPF1_Dyn_Max_Hz    => Held (Integer (P.Dterm_Lpf1_Dyn_Max_Hz), 0, 1000),
      Dterm_LPF1_Dyn_Expo      => Held (Integer (P.Dterm_Lpf1_Dyn_Expo), 0, 10),
      Dterm_LPF1_Type          => Lowpass_Kind'Val (Code (P.Dterm_Lpf1_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      Dterm_LPF1_Static_Hz     => Held (Integer (P.Dterm_Lpf1_Static_Hz), 0, 1000),
      Dterm_LPF2_Static_Hz     => Held (Integer (P.Dterm_Lpf2_Static_Hz), 0, 1000),
      Dterm_LPF2_Type          => Lowpass_Kind'Val (Code (P.Dterm_Lpf2_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      Dterm_Notch_Hz           => Held (Integer (P.Dterm_Notch_Hz), 0, 1000),
      Dterm_Notch_Cutoff       => Held (Integer (P.Dterm_Notch_Cutoff), 0, 1000),
      Yaw_Lowpass_Hz           => Held (Integer (P.Yaw_Lowpass_Hz), 0, 500),
      Anti_Gravity_Cutoff_Hz   => Held (Integer (P.Anti_Gravity_Cutoff_Hz), 2, 50),
      Throttle_Boost_Cutoff    => Held (Integer (P.Throttle_Boost_Cutoff), 5, 50),
      Angle_Feedforward_Smoothing_Ms => Held (Integer (P.Angle_Feedforward_Smoothing_Ms), 10, 250),
      Launch_Control           =>
        Launch_Control_Mode'Val (Code (P.Launch_Control_Mode, Launch_Control_Mode'Pos (Launch_Control_Mode'Last))),
      Launch_Control_Angle_Limit => Held (Integer (P.Launch_Control_Angle_Limit), 0, 80),
      Launch_Control_Gain      => Held (Integer (P.Launch_Control_Gain), 0, 200),
      Thrust_Linearization     => Held (Integer (P.Thrust_Linearization), 0, 150),
      D_Max_Gain               => Held (Integer (P.D_Max_Gain), 0, 100),
      D_Max_Advance            => Held (Integer (P.D_Max_Advance), 0, 200),
      Feedforward_Transition   => Held (Integer (P.Feedforward_Transition), 0, 100),
      Feedforward_Average      =>
        Feedforward_Averaging'Val
          (Code (P.Feedforward_Averaging, Feedforward_Averaging'Pos (Feedforward_Averaging'Last))),
      Feedforward_Smooth_Factor => Held (Integer (P.Feedforward_Smooth_Factor), 0, 95),
      Feedforward_Jitter_Factor => Held (Integer (P.Feedforward_Jitter_Factor), 0, 20),
      Feedforward_Boost        => Held (Integer (P.Feedforward_Boost), 0, 50),
      Feedforward_Max_Rate_Limit => Held (Integer (P.Feedforward_Max_Rate_Limit), 0, 200),
      Feedforward_Yaw_Hold_Gain => Held (Integer (P.Feedforward_Yaw_Hold_Gain), 0, 100),
      Feedforward_Yaw_Hold_Time => Held (Integer (P.Feedforward_Yaw_Hold_Time), 10, 250),
      Level_Race_Mode          => P.Level_Race_Mode /= 0,
      TPA_Rate                 => Held (Integer (P.Tpa_Rate), 0, 100),
      TPA_Breakpoint           => Held (Integer (P.Tpa_Breakpoint), 1000, 2000),
      TPA_Low_Rate             => Held (Integer (P.Tpa_Low_Rate), -100, 100),
      TPA_Low_Breakpoint       => Held (Integer (P.Tpa_Low_Breakpoint), 1000, 2000),
      TPA_Low_Always           => P.Tpa_Low_Always /= 0,
      TPA_Terms                => TPA_Mode'Val (Code (P.Tpa_Mode, TPA_Mode'Pos (TPA_Mode'Last))),
      TPA_Curve_Type           =>
        TPA_Curve_Kind'Val (Code (P.Tpa_Curve_Type, TPA_Curve_Kind'Pos (TPA_Curve_Kind'Last))),
      TPA_Curve_Stall_Throttle => Held (Integer (P.Tpa_Curve_Stall_Throttle), 0, 100),
      TPA_Curve_PID_Thr0       => Held (Integer (P.Tpa_Curve_Pid_Thr0), 1, 1000),
      TPA_Curve_PID_Thr100     => Held (Integer (P.Tpa_Curve_Pid_Thr100), 1, 1000),
      TPA_Curve_Expo           => Held (Integer (P.Tpa_Curve_Expo), -100, 100),
      Throttle_Boost           => Held (Integer (P.Throttle_Boost), 0, 100),
      Ez_Landing_Threshold     => Held (Integer (P.Ez_Landing_Threshold), 0, 200),
      Ez_Landing_Limit         => Held (Integer (P.Ez_Landing_Limit), 0, 75),
      Ez_Landing_Speed         => Held (Integer (P.Ez_Landing_Speed), 0, 250),
      Landing_Disarm_Threshold => Held (Integer (P.Landing_Disarm_Threshold), 0, 250),
      Angle_Limit              => Held (Integer (P.Angle_Limit), 10, 90),
      Simplified_PIDs_Mode     =>
        Simplified_Mode'Val (Code (P.Simplified_Pids_Mode, Simplified_Mode'Pos (Simplified_Mode'Last))),
      Simplified_Master_Multiplier => Held (Integer (P.Simplified_Master_Multiplier), 0, 200),
      Simplified_Roll_Pitch_Ratio => Held (Integer (P.Simplified_Roll_Pitch_Ratio), 0, 200),
      Simplified_I_Gain        => Held (Integer (P.Simplified_I_Gain), 0, 200),
      Simplified_D_Gain        => Held (Integer (P.Simplified_D_Gain), 0, 200),
      Simplified_PI_Gain       => Held (Integer (P.Simplified_Pi_Gain), 0, 200),
      Simplified_D_Max_Gain    => Held (Integer (P.Simplified_D_Max_Gain), 0, 200),
      Simplified_Feedforward_Gain => Held (Integer (P.Simplified_Feedforward_Gain), 0, 200),
      Simplified_Pitch_PI_Gain => Held (Integer (P.Simplified_Pitch_Pi_Gain), 0, 200),
      Simplified_Dterm_Filter  => P.Simplified_Dterm_Filter /= 0,
      Simplified_Dterm_Filter_Multiplier => Held (Integer (P.Simplified_Dterm_Filter_Multiplier), 10, 200));

   function Rate_Profile_Of (R : Control_Rate_Config_Record) return Rates.Profile is
     (Kind           => Rates.Curve_Kind'Val (Code (R.Rates_Type, Rates.Curve_Kind'Pos (Rates.Curve_Kind'Last))),
      RC_Rates       => (Roll  => Held (Integer (R.Rc_Rates (0)), 1, 255),
                         Pitch => Held (Integer (R.Rc_Rates (1)), 1, 255),
                         Yaw   => Held (Integer (R.Rc_Rates (2)), 1, 255)),
      RC_Expo        => (Roll  => Held (Integer (R.Rc_Expo (0)), 0, 100),
                         Pitch => Held (Integer (R.Rc_Expo (1)), 0, 100),
                         Yaw   => Held (Integer (R.Rc_Expo (2)), 0, 100)),
      Super_Rates    => (Roll => Integer (R.Rates (0)), Pitch => Integer (R.Rates (1)), Yaw => Integer (R.Rates (2))),
      Limits         => (Roll  => Held (Integer (R.Rate_Limit (0)), 0, Rates.Max_Rate_Limit),
                         Pitch => Held (Integer (R.Rate_Limit (1)), 0, Rates.Max_Rate_Limit),
                         Yaw   => Held (Integer (R.Rate_Limit (2)), 0, Rates.Max_Rate_Limit)),
      Quick_Expo     => R.Quick_Rates_Rc_Expo /= 0,
      Throttle_Mid   => Held (Integer (R.Thr_Mid8), 0, 100),
      Throttle_Expo  => Held (Integer (R.Thr_Expo8), 0, 100),
      Throttle_Hover => Held (Integer (R.Thr_Hover8), 0, 100));

   function Arming_Settings_Of
     (A : Arming_Config_Record; Sys : System_Config_Record; R : Rx_Config_Record;
      Flight_3D : Flight3_D_Config_Record; Mixer_Mode : Unsigned_8; Loop_Rate : Pid_Config_Record;
      P : Pid_Profile_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set) return Arming.Settings is
     (Gyro_Cal_On_First_Arm      => A.Gyro_Cal_On_First_Arm /= 0,
      Auto_Disarm_Delay          => Integer (A.Auto_Disarm_Delay),
      Prearm_Allow_Rearm         => A.Prearm_Allow_Rearm /= 0,
      Boot_Grace_Time            => Integer (Sys.Power_On_Arming_Grace_Time),
      Stick_Arming               => Sys.Enable_Stick_Arming /= 0,
      Mid_RC                     => Held (Integer (R.Midrc), 1_200, 1_700),
      Min_Check                  => Held (Integer (R.Mincheck), 750, 2_250),
      Max_Check                  => Held (Integer (R.Maxcheck), 750, 2_250),
      Airmode_Threshold          => Held (Integer (R.Air_Mode_Activate_Threshold), 0, 100),
      Three_D                    => (Features and Config_Fix.Feature_3D) /= 0,
      Switched_Mode_3D           => Flight_3D.Switched_Mode3d /= 0,
      Deadband_3D_Throttle       => Held (Integer (Flight_3D.Deadband3d_Throttle), 0, 1_000),
      Motor_Stop                 => (Features and Config_Fix.Feature_Motor_Stop) /= 0,
      Airmode_Feature            => (Features and Config_Fix.Feature_Airmode) /= 0,
      Anti_Gravity_Feature       => (Features and Config_Fix.Feature_Anti_Gravity) /= 0,
      Fixed_Wing                 =>
        Mixer_Mode in 1 .. Mixer_Init.Mixer_Mode'Pos (Mixer_Init.Mixer_Mode'Last) + 1
        and then Mixer_Init.Is_Fixed_Wing (Mixer_Init.Mixer_Mode'Val (Mixer_Mode - 1)),
      PID_At_Min_Throttle        => P.Pid_At_Min_Throttle /= 0,
      Launch_Control_Angle_Limit => Held (Integer (P.Launch_Control_Angle_Limit), 0, 90),
      Launch_Trigger_Throttle    => Held (Integer (P.Launch_Control_Throttle_Percent), 0, 100),
      Launch_Trigger_Reset       => P.Launch_Control_Allow_Trigger_Reset /= 0,
      Runaway_Prevention         => Loop_Rate.Runaway_Takeoff_Prevention /= 0,
      Runaway_Deactivate_Delay   => Held (Integer (Loop_Rate.Runaway_Takeoff_Deactivate_Delay), 100, 1_000),
      Runaway_Deactivate_Throttle => Held (Integer (Loop_Rate.Runaway_Takeoff_Deactivate_Throttle), 0, 100),
      Sensors                    => Sensors);

   function Failsafe_Settings_Of (F : Failsafe_Config_Record; A : Autopilot_Config_Record) return Failsafe.Settings is
     (Throttle_Low_Delay => Held (Integer (F.Failsafe_Throttle_Low_Delay), 0, 300),
      Signal_Delay       => Held (Integer (F.Failsafe_Delay), 1, 200),
      Landing_Time       => Held (Integer (F.Failsafe_Landing_Time), 0, 250),
      Switch             => Failsafe.Switch_Mode'Val (Code (F.Failsafe_Switch_Mode, 2)),
      Action             => Failsafe.Procedure_Kind'Val (Code (F.Failsafe_Procedure, 2)),
      Recovery_Delay     => Held (Integer (F.Failsafe_Recovery_Delay), 1, 200),
      Policy             => Failsafe.Loss_Policy'Val (Code (A.Rx_Loss_Policy, 2)));

   --  The receiver source the features name, in the setup's order of
   --  precedence; the UDP source needs a build the boards do not have.
   function Source_Of (Features : Unsigned_32) return Receiver.Provider is
     (if (Features and Config_Fix.Feature_RX_Parallel_PWM) /= 0 then Receiver.Parallel_PWM
      elsif (Features and Config_Fix.Feature_RX_PPM) /= 0 then Receiver.PPM
      elsif (Features and Config_Fix.Feature_RX_Serial) /= 0 then Receiver.Serial
      elsif (Features and Config_Fix.Feature_RX_MSP) /= 0 then Receiver.MSP
      elsif (Features and Config_Fix.Feature_RX_SPI) /= 0 then Receiver.SPI
      else Receiver.None);

   function Map_Of (Rcmap : Bytes_8) return Receiver.Channel_Map;
   function Ranges_Of (Ranges : Rx_Channel_Range_Config_Record_List_4) return Receiver.Range_Configs;
   function Failsafes_Of (Failsafes : Rx_Failsafe_Channel_Config_Record_List_18) return Receiver.Failsafe_Channels;
   function Channels_Of (Mask : Unsigned_32) return Receiver.Channel_Set;

   function Receiver_Settings_Of
     (R : Rx_Config_Record; Ranges : Rx_Channel_Range_Config_Record_List_4;
      Failsafes : Rx_Failsafe_Channel_Config_Record_List_18; Flight_3D : Flight3_D_Config_Record;
      F : Failsafe_Config_Record; Features : Unsigned_32; Reported_Channels : Natural)
      return Receiver.Settings is
     (Source            => Source_Of (Features),
      Reported_Channels => Reported_Channels,
      Map               => Map_Of (R.Rcmap),
      Ranges            => Ranges_Of (Ranges),
      Failsafe          => Failsafes_Of (Failsafes),
      Min_Usec          => Held (Integer (R.Rx_Min_Usec), Receiver.Pulse_Min, Receiver.Pulse_Max),
      Max_Usec          => Held (Integer (R.Rx_Max_Usec), Receiver.Pulse_Min, Receiver.Pulse_Max),
      Mid_RC            => Held (Integer (R.Midrc), 1200, 1700),
      Max_Aux           =>
        Held (Integer (R.Max_Aux_Channel), 0, Receiver.Channel_Count - Receiver.Flight_Channel_Count),
      RSSI_ADC          => (Features and Config_Fix.Feature_RSSI_ADC) /= 0,
      RSSI_Channel      => Held (Integer (R.Rssi_Channel), 0, Receiver.Channel_Count),
      RSSI_Scale        => Held (Integer (R.Rssi_Scale), 1, 255),
      RSSI_Offset       => Held (Integer (R.Rssi_Offset), -100, 100),
      RSSI_Invert       => R.Rssi_Invert /= 0,
      RSSI_Smoothing    => Integer (R.Rssi_Smoothing),
      Frame_LPF_Period  => Held (Integer (R.Rssi_Src_Frame_Lpf_Period), 1, 255),
      Feature_3D        => (Features and Config_Fix.Feature_3D) /= 0,
      Switched_Mode_3D  => Flight_3D.Switched_Mode3d /= 0,
      Failsafe_Throttle => Held (Integer (F.Failsafe_Throttle), Receiver.Pulse_Min, Receiver.Pulse_Max),
      Override_Channels => Channels_Of (R.Msp_Override_Channels_Mask),
      Override_Failsafe => R.Msp_Override_Failsafe /= 0);

   function RC_Config_Of
     (R : Rx_Config_Record; Controls : Rc_Controls_Config_Record; Rate : Control_Rate_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us) return RC_Command.Config is
     (Rates     => Rate_Profile_Of (Rate),
      Receiver  => (Mid_RC               => Held (Integer (R.Midrc), 1200, 1700),
                    Min_Check            => Held (Integer (R.Mincheck), 750, 1999),
                    Smoothing            => R.Rc_Smoothing /= 0,
                    Auto_Factor_Setpoint => Held (Integer (R.Rc_Smoothing_Auto_Factor_Rpy), 0, 250),
                    Auto_Factor_Throttle => Held (Integer (R.Rc_Smoothing_Auto_Factor_Throttle), 0, 250),
                    Setpoint_Cutoff      => Integer (R.Rc_Smoothing_Setpoint_Cutoff),
                    Throttle_Cutoff      => Integer (R.Rc_Smoothing_Throttle_Cutoff)),
      Controls  => (Deadband     => Held (Integer (Controls.Deadband), 0, 32),
                    Yaw_Deadband => Held (Integer (Controls.Yaw_Deadband), 0, 100),
                    Yaw_Reversed => Controls.Yaw_Control_Reversed),
      Loop_Time => Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom));

   function Adjustment_Settings_Of (R : Rx_Config_Record; Sys : System_Config_Record) return Adjustments.Settings is
     (Mid_RC                  => Held (Integer (R.Midrc), 1200, 1700),
      Rate_Profile_6_Position => Sys.Rate_Profile6_Pos_Switch /= 0);

   function Gyro_Settings_Of
     (G : Gyro_Config_Record; N : Dyn_Notch_Config_Record; R : Rpm_Filter_Config_Record;
      Device : Gyro_Device_Config_Record; Board : Board_Alignment_Record; Motor : Motor_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us; Scale : Float;
      Motors : Mixer.Motor_Count; Overflow_Protected : Boolean) return Gyro_Filters.Settings is
     (LPF1_Type          => Lowpass_Kind'Val (Code (G.Gyro_Lpf1_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      LPF1_Static_Hz     => Held (Integer (G.Gyro_Lpf1_Static_Hz), 0, 1000),
      LPF1_Dyn_Min_Hz    => Held (Integer (G.Gyro_Lpf1_Dyn_Min_Hz), 0, 1000),
      LPF1_Dyn_Max_Hz    => Held (Integer (G.Gyro_Lpf1_Dyn_Max_Hz), 0, 1000),
      LPF1_Dyn_Expo      => Held (Integer (G.Gyro_Lpf1_Dyn_Expo), 0, 10),
      LPF2_Type          => Lowpass_Kind'Val (Code (G.Gyro_Lpf2_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      LPF2_Static_Hz     => Held (Integer (G.Gyro_Lpf2_Static_Hz), 0, 1000),
      Notch1_Hz          => Held (Integer (G.Gyro_Soft_Notch_Hz_1), 0, 1000),
      Notch1_Cutoff      => Held (Integer (G.Gyro_Soft_Notch_Cutoff_1), 0, 1000),
      Notch2_Hz          => Held (Integer (G.Gyro_Soft_Notch_Hz_2), 0, 1000),
      Notch2_Cutoff      => Held (Integer (G.Gyro_Soft_Notch_Cutoff_2), 0, 1000),
      Sample_Time_Us     => Sample_Time_Us,
      Loop_Time_Us       => Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom),
      Scale              => Scale,
      Alignment          =>
        Sensor_Alignment.Standard_Alignment'Val
          (Code (Device.Alignment, Sensor_Alignment.Standard_Alignment'Pos (Sensor_Alignment.Standard_Alignment'Last))),
      Custom_Angles      =>
        (Roll  => Sensor_Alignment.Decidegrees (Held (Integer (Device.Custom_Alignment (0)), -3600, 3600)),
         Pitch => Sensor_Alignment.Decidegrees (Held (Integer (Device.Custom_Alignment (1)), -3600, 3600)),
         Yaw   => Sensor_Alignment.Decidegrees (Held (Integer (Device.Custom_Alignment (2)), -3600, 3600))),
      Board              =>
        (Roll  => Held (Integer (Board.Roll_Degrees), -180, 360),
         Pitch => Held (Integer (Board.Pitch_Degrees), -180, 360),
         Yaw   => Held (Integer (Board.Yaw_Degrees), -180, 360)),
      Calibration_Duration => Held (Integer (G.Gyro_Calibration_Duration), 1, 3_000),
      Movement_Threshold => Held (Integer (G.Gyro_Movement_Calibration_Threshold), 0, 200),
      Offset_Yaw         => Held (Integer (G.Gyro_Offset_Yaw), -1_000, 1_000),
      Check_Overflow     =>
        Gyro_Filters.Overflow_Check'Val
          (Code (G.Check_Overflow, Gyro_Filters.Overflow_Check'Pos (Gyro_Filters.Overflow_Check'Last))),
      Overflow_Protected => Overflow_Protected,
      Yaw_Spin           =>
        Gyro_Filters.Spin_Recovery'Val
          (Code (G.Yaw_Spin_Recovery, Gyro_Filters.Spin_Recovery'Pos (Gyro_Filters.Spin_Recovery'Last))),
      Yaw_Spin_Threshold => Held (Integer (G.Yaw_Spin_Threshold), 500, 1_950),
      Dynamic_Notch      =>
        (Count  => Held (Integer (N.Dyn_Notch_Count), 0, Dyn_Notch.Max_Notches),
         Q      => Held (Integer (N.Dyn_Notch_Q), 1, 1_000),
         Min_Hz => Held (Integer (N.Dyn_Notch_Min_Hz), 20, 250),
         Max_Hz => Held (Integer (N.Dyn_Notch_Max_Hz), 200, 1_000)),
      RPM                =>
        (Harmonics     => Held (Integer (R.Rpm_Filter_Harmonics), 0, RPM_Filter.Max_Harmonics),
         Weights       => (0 => Integer (R.Rpm_Filter_Weights (0)), 1 => Integer (R.Rpm_Filter_Weights (1)),
                           2 => Integer (R.Rpm_Filter_Weights (2))),
         Min_Hz        => Held (Integer (R.Rpm_Filter_Min_Hz), 30, 200),
         Fade_Range_Hz => Held (Integer (R.Rpm_Filter_Fade_Range_Hz), 0, 1_000),
         Q             => Held (Integer (R.Rpm_Filter_Q), 250, 3_000)),
      Motors             => Motors,
      Motor_Telemetry    => Motor.Dev.Use_Dshot_Telemetry /= 0,
      Simplified_Filter  => G.Simplified_Gyro_Filter /= 0,
      Simplified_Filter_Multiplier => Held (Integer (G.Simplified_Gyro_Filter_Multiplier), 10, 200));

end Adaflight.Config_Runtime;
