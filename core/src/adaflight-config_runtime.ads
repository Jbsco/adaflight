--  The runtime records built from the stored configuration. Each field is
--  held to its runtime range, which a stored value leaves only through a
--  foreign image, and each code to its names. The order rules the runtime
--  predicates need come from the configuration fix.
with Interfaces; use Interfaces;
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;

package Adaflight.Config_Runtime with SPARK_Mode is

   function PID_Profile_Of (P : Pid_Profile_Record) return PID_Profile.Profile
     with Pre => Config_Fix.Fixed_PID_Profile (P);

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

end Adaflight.Config_Runtime;
