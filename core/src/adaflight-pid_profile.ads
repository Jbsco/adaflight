--  The tunable settings of a PID profile, bounded as the configuration
--  interface bounds them.

with Adaflight.Axes; use Adaflight.Axes;

package Adaflight.PID_Profile with SPARK_Mode, Pure is

   Gain_Max : constant := 250;
   F_Gain_Max : constant := 1000;
   subtype Gain is Natural range 0 .. Gain_Max;
   subtype F_Gain is Natural range 0 .. F_Gain_Max;

   type Axis_Gains is record
      P : Gain := 0;
      I : Gain := 0;
      D : Gain := 0;
      F : F_Gain := 0;
      S : Gain := 0;
   end record;

   type Axis_Gain_Set is array (Axis) of Axis_Gains;
   type Axis_Gain_Values is array (Axis) of Gain;

   type Level_Gains is record
      P : Natural range 0 .. 200 := 50;
      I : Natural range 0 .. 100 := 50;
      D : Natural range 10 .. 200 := 75;
      F : Natural range 0 .. 200 := 50;
   end record;

   type Iterm_Relax_Mode is (Off, RP, RPY, RP_Inc, RPY_Inc);
   type Iterm_Relax_Source is (Gyro, Setpoint);
   type Lowpass_Kind is (PT1, SVF, PT2, PT3);
   type Launch_Control_Mode is (Normal, Pitch_Only, Full);
   type Feedforward_Averaging is (Off, Two_Point, Three_Point, Four_Point);
   type Crash_Recovery_Mode is (Off, On, Beep, Disarm);
   type TPA_Mode is (PD, D);
   type TPA_Curve_Kind is (Classic, Hyperbolic);

   subtype Percent is Natural range 0 .. 100;
   subtype Milliseconds is Natural range 0 .. 65535;
   subtype Hertz is Natural range 0 .. 1000;
   subtype PWM_Value is Natural range 1000 .. 2000;

   type Profile is record
      Gains                    : Axis_Gain_Set;
      D_Max                    : Axis_Gain_Values := (others => 0);
      Level                    : Level_Gains;
      Angle_Earth_Ref          : Percent := 100;
      Horizon_Ignore_Sticks    : Boolean := False;
      Horizon_Limit_Degrees    : Natural range 10 .. 250 := 135;
      Horizon_Delay_Ms         : Natural range 10 .. 5000 := 500;
      Rate_Accel_Limit         : Natural range 0 .. 500 := 0;
      Yaw_Rate_Accel_Limit     : Natural range 0 .. 500 := 0;
      Anti_Gravity_Gain        : Gain := 80;
      Anti_Gravity_P_Gain      : Gain := 100;
      Crash_Time               : Natural range 100 .. 5000 := 500;
      Crash_Delay              : Natural range 0 .. 500 := 0;
      Crash_Recovery_Angle     : Natural range 5 .. 30 := 10;
      Crash_Recovery_Rate      : Natural range 50 .. 255 := 100;
      Crash_Gyro_Threshold     : Natural range 100 .. 2000 := 400;
      Crash_Dterm_Threshold    : Natural range 10 .. 2000 := 50;
      Crash_Setpoint_Threshold : Natural range 50 .. 2000 := 350;
      Crash_Limit_Yaw          : Natural range 0 .. 1000 := 200;
      Crash_Recovery           : Crash_Recovery_Mode := Off;
      Iterm_Windup             : Natural range 20 .. 100 := 85;
      PID_Sum_Limit            : Natural range 100 .. 1000 := 500;
      PID_Sum_Limit_Yaw        : Natural range 100 .. 1000 := 400;
      Iterm_Rotation           : Boolean := False;
      Iterm_Relax              : Iterm_Relax_Mode := RP;
      Iterm_Relax_Type         : Iterm_Relax_Source := Setpoint;
      Iterm_Relax_Cutoff       : Natural range 1 .. 50 := 15;
      Acro_Trainer_Angle_Limit : Natural range 10 .. 80 := 20;
      Acro_Trainer_Lookahead_Ms : Natural range 10 .. 200 := 50;
      Acro_Trainer_Debug_Axis  : Natural range 0 .. 1 := 0;
      Acro_Trainer_Gain        : Natural range 25 .. 255 := 75;
      Dterm_LPF1_Dyn_Min_Hz    : Hertz := 75;
      Dterm_LPF1_Dyn_Max_Hz    : Hertz := 150;
      Dterm_LPF1_Dyn_Expo      : Natural range 0 .. 10 := 5;
      Dterm_LPF1_Type          : Lowpass_Kind := PT1;
      Dterm_LPF1_Static_Hz     : Hertz := 75;
      Dterm_LPF2_Static_Hz     : Hertz := 150;
      Dterm_LPF2_Type          : Lowpass_Kind := PT1;
      Dterm_Notch_Hz           : Hertz := 0;
      Dterm_Notch_Cutoff       : Hertz := 160;
      Yaw_Lowpass_Hz           : Natural range 0 .. 500 := 100;
      Anti_Gravity_Cutoff_Hz   : Natural range 2 .. 50 := 5;
      Throttle_Boost_Cutoff    : Natural range 5 .. 50 := 15;
      Angle_Feedforward_Smoothing_Ms : Natural range 10 .. 250 := 80;
      Launch_Control           : Launch_Control_Mode := Normal;
      Launch_Control_Angle_Limit : Natural range 0 .. 80 := 0;
      Launch_Control_Gain      : Natural range 0 .. 200 := 40;
      Thrust_Linearization     : Natural range 0 .. 150 := 0;
      D_Max_Gain               : Percent := 37;
      D_Max_Advance            : Natural range 0 .. 200 := 20;
      Feedforward_Transition   : Percent := 0;
      Feedforward_Average      : Feedforward_Averaging := Off;
      Feedforward_Smooth_Factor : Natural range 0 .. 95 := 25;
      Feedforward_Jitter_Factor : Natural range 0 .. 20 := 7;
      Feedforward_Boost        : Natural range 0 .. 50 := 15;
      Feedforward_Max_Rate_Limit : Natural range 0 .. 200 := 90;
      Feedforward_Yaw_Hold_Gain : Percent := 15;
      Feedforward_Yaw_Hold_Time : Natural range 10 .. 250 := 100;
      Level_Race_Mode          : Boolean := False;
      TPA_Rate                 : Percent := 65;
      TPA_Breakpoint           : PWM_Value := 1350;
      TPA_Low_Rate             : Integer range -100 .. 100 := 20;
      TPA_Low_Breakpoint       : PWM_Value := 1050;
      TPA_Low_Always           : Boolean := False;
      TPA_Terms                : TPA_Mode := D;
      TPA_Curve_Type           : TPA_Curve_Kind := Classic;
      TPA_Curve_Stall_Throttle : Percent := 30;
      TPA_Curve_PID_Thr0       : Natural range 1 .. 1000 := 200;
      TPA_Curve_PID_Thr100     : Natural range 1 .. 1000 := 70;
      TPA_Curve_Expo           : Integer range -100 .. 100 := 20;
      Throttle_Boost           : Percent := 5;
      Ez_Landing_Threshold     : Natural range 0 .. 200 := 25;
      Ez_Landing_Limit         : Natural range 0 .. 75 := 15;
      Ez_Landing_Speed         : Natural range 0 .. 250 := 50;
      Landing_Disarm_Threshold : Natural range 0 .. 250 := 0;
      Angle_Limit              : Natural range 10 .. 90 := 60;
   end record
     with Dynamic_Predicate =>
       (Profile.Dterm_LPF1_Dyn_Min_Hz = 0
          or else Profile.Dterm_LPF1_Dyn_Min_Hz <= Profile.Dterm_LPF1_Dyn_Max_Hz)
       and then (Profile.Dterm_Notch_Hz = 0
                   or else Profile.Dterm_Notch_Cutoff < Profile.Dterm_Notch_Hz);

end Adaflight.PID_Profile;
