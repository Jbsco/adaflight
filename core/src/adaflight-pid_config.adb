with Adaflight.Maths; use Adaflight.Maths;

package body Adaflight.PID_Config with SPARK_Mode is

   subtype Loop_Dt is Float range 1.0e-4 .. 0.1;

   function Coefficients_Of (G : Axis_Gains) return Coefficients
     with Post => Coefficients_Of'Result.Kp <= 8.1 and then Coefficients_Of'Result.Ki <= 61.2
       and then Coefficients_Of'Result.Kd <= 0.14 and then Coefficients_Of'Result.Kf <= 0.14
   is
   begin
      return (Kp => P_Term_Scale * Float (G.P),
              Ki => I_Term_Scale * Float (G.I),
              Kd => D_Term_Scale * Float (G.D),
              Kf => Feedforward_Scale * (Float (G.F) * 0.01));
   end Coefficients_Of;

   function Yaw_Ki (Ki : Float) return Float
     with Pre => Ki in 0.0 .. 61.2, Post => Yaw_Ki'Result in 0.0 .. 153.0
   is
   begin
      return Ki * 2.5;
   end Yaw_Ki;

   function Max_Velocity_Of (Limit : Natural; Dt : Loop_Dt) return Float
     with Pre => Limit <= 500, Post => Max_Velocity_Of'Result in 0.0 .. 5000.0
   is
   begin
      return Float (Limit * 100) * Dt;
   end Max_Velocity_Of;

   function Inverse_Or_One (X : Float) return Float
     with Pre  => X in 0.0 .. 250.0,
          Post => Inverse_Or_One'Result in 0.0039 .. 10.1
            and then (if X <= 2.0 then Inverse_Or_One'Result >= 0.49)
            and then (if X >= 10.0 then Inverse_Or_One'Result <= 0.11)
   is
   begin
      if X >= 0.1 then
         return 1.0 / X;
      else
         return 1.0;
      end if;
   end Inverse_Or_One;

   function Iterm_Limit_Of (Windup : Natural; Sum_Limit : Natural) return Float
     with Pre => Windup in 20 .. 100 and then Sum_Limit in 100 .. 1000,
          Post => Iterm_Limit_Of'Result in 0.0 .. 1001.0
   is
   begin
      return 0.01 * Float (Windup) * Float (Sum_Limit);
   end Iterm_Limit_Of;

   function D_Max_Percent_Of (D : Gain; D_Max : Gain) return Float
     with Post => D_Max_Percent_Of'Result in 1.0 .. 250.0
   is
   begin
      if D > 0 and then D_Max > D then
         return Float (D_Max) / Float (D);
      else
         return 1.0;
      end if;
   end D_Max_Percent_Of;

   function D_Max_Gain_Of (Setting : Natural) return Float
     with Pre  => Setting <= 200,
          Post => D_Max_Gain_Of'Result in 0.0 .. 0.00046
            and then (if Setting <= 100 then D_Max_Gain_Of'Result <= 0.00023)
   is
      LPF_Inv : constant Float := 1.0 / D_Max_Lowpass_Hz;
   begin
      return D_Max_Gain_Factor * Float (Setting) * LPF_Inv;
   end D_Max_Gain_Of;

   function Smooth_Factor_Of (Setting : Natural) return Float
     with Pre => Setting <= 95, Post => Smooth_Factor_Of'Result in 0.0 .. 0.08
   is
      Scaled : constant Float := 0.01 * Float (Setting);
   begin
      pragma Assert (Scaled in 0.0 .. 0.95);
      return (Feedforward_Rx_Dt * Scaled) / (1.0 - Scaled);
   end Smooth_Factor_Of;

   function Yaw_Hold_Gain_Of (Gain_Setting : Natural; Time_Setting : Natural) return Float
     with Pre => Gain_Setting <= 100 and then Time_Setting in 10 .. 250,
          Post => Yaw_Hold_Gain_Of'Result in 0.0 .. 250.0
   is
      G : Float := Float (Gain_Setting);
   begin
      if Time_Setting < 100 then
         G := G * (150.0 / Float (Time_Setting + 50));
      end if;
      return G;
   end Yaw_Hold_Gain_Of;

   function Breakpoint_Of (PWM : PWM_Value; Low : Float; High : Float) return Float
     with Pre  => Low in 0.0 .. 0.01 and then High in 0.99 .. 1.0,
          Post => Breakpoint_Of'Result in Low .. High
            and then (Breakpoint_Of'Result = Low or else Breakpoint_Of'Result >= 0.001)
   is
      Fraction : constant Float := Float (PWM - 1000) / 1000.0;
   begin
      pragma Assert (if PWM > 1000 then Fraction >= 0.001);
      return Constrain_F (Fraction, Low, High);
   end Breakpoint_Of;

   function TPA_Multiplier_Of (Rate : Percent; Breakpoint : Float) return Float
     with Pre => Breakpoint in 0.0 .. 0.99, Post => TPA_Multiplier_Of'Result in 0.0 .. 101.0
   is
   begin
      return (Float (Rate) / 100.0) / (1.0 - Breakpoint);
   end TPA_Multiplier_Of;

   function TPA_Low_Multiplier_Of (Rate : Integer; Breakpoint : Float) return Float
     with Pre  => Rate in -100 .. 100
            and then (Breakpoint = 0.0 or else Breakpoint in 0.001 .. 1.0),
          Post => TPA_Low_Multiplier_Of'Result in -1001.0 .. 1001.0
   is
   begin
      --  A zero breakpoint has no finite multiplier in the reference and the
      --  branch that would use it never runs; it is zero here.
      if Breakpoint = 0.0 then
         return 0.0;
      else
         return Float (Rate) / (100.0 * Breakpoint);
      end if;
   end TPA_Low_Multiplier_Of;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (R : out Runtime; P : Profile; Loop_Time : Loop_Time_Us;
      Has_Acc : Boolean; Serial_Rx_Is_CRSF : Boolean)
   is
      Dt : constant Loop_Dt := Float (Loop_Time) * 1.0e-6;
   begin
      R := (others => <>);
      R.Dt := Dt;
      R.PID_Frequency := 1.0 / Dt;
      for A in Axis loop
         R.Coefficient (A) := Coefficients_Of (P.Gains (A));
      end loop;
      R.Coefficient (Yaw).Ki := Yaw_Ki (R.Coefficient (Yaw).Ki);
      R.Angle_Gain := Float (P.Level.P) / 10.0;
      R.Angle_Feedforward_Gain := Float (P.Level.F) / 100.0;
      R.Angle_Earth_Ref := Float (P.Angle_Earth_Ref) / 100.0;
      R.Horizon_Gain := Float'Min (Float (P.Level.I) / 100.0, 1.0);
      R.Horizon_Ignore_Sticks := (if P.Horizon_Ignore_Sticks then 1.0 else 0.0);
      R.Horizon_Limit_Sticks := Float (P.Level.D) / 100.0;
      R.Horizon_Limit_Sticks_Inv := Inverse_Or_One (R.Horizon_Limit_Sticks);
      R.Horizon_Limit_Degrees := Float (P.Horizon_Limit_Degrees);
      R.Horizon_Limit_Degrees_Inv := Inverse_Or_One (R.Horizon_Limit_Degrees);
      R.Max_Velocity (Roll) := Max_Velocity_Of (P.Rate_Accel_Limit, Dt);
      R.Max_Velocity (Pitch) := R.Max_Velocity (Roll);
      R.Max_Velocity (Yaw) := Max_Velocity_Of (P.Yaw_Rate_Accel_Limit, Dt);
      R.Anti_Gravity_Gain := P.Anti_Gravity_Gain;
      R.Crash_Time_Limit_Us := Integer_32 (P.Crash_Time) * 1000;
      R.Crash_Time_Delay_Us := Integer_32 (P.Crash_Delay) * 1000;
      R.Crash_Recovery_Angle_Dd := Integer_32 (P.Crash_Recovery_Angle) * 10;
      R.Crash_Recovery_Rate := Float (P.Crash_Recovery_Rate);
      R.Crash_Gyro_Threshold := Float (P.Crash_Gyro_Threshold);
      R.Crash_Dterm_Threshold := Float (P.Crash_Dterm_Threshold) * 1000.0;
      R.Crash_Setpoint_Threshold := Float (P.Crash_Setpoint_Threshold);
      R.Crash_Limit_Yaw := Float (P.Crash_Limit_Yaw);
      R.Iterm_Limit := Iterm_Limit_Of (P.Iterm_Windup, P.PID_Sum_Limit);
      R.Iterm_Limit_Yaw := Iterm_Limit_Of (P.Iterm_Windup, P.PID_Sum_Limit_Yaw);
      R.Iterm_Rotation := P.Iterm_Rotation;
      R.Anti_Gravity_Osd_Cutoff := (Float (P.Anti_Gravity_Gain) / 10.0) * 0.25;
      R.Anti_Gravity_P_Gain := (Float (P.Anti_Gravity_P_Gain) / 100.0) * Anti_Gravity_KP;
      R.Iterm_Relax := P.Iterm_Relax;
      R.Iterm_Relax_Type := P.Iterm_Relax_Type;
      R.Iterm_Relax_Cutoff := P.Iterm_Relax_Cutoff;
      R.Acro_Trainer_Angle_Limit := Float (P.Acro_Trainer_Angle_Limit);
      R.Acro_Trainer_Lookahead := Float (P.Acro_Trainer_Lookahead_Ms) / 1000.0;
      R.Acro_Trainer_Debug_Axis := P.Acro_Trainer_Debug_Axis;
      R.Acro_Trainer_Gain := Float (P.Acro_Trainer_Gain) / 10.0;
      if P.Dterm_LPF1_Dyn_Min_Hz > 0 then
         R.Dyn_LPF_Filter :=
           (case P.Dterm_LPF1_Type is
              when PID_Profile.PT1 => PT1,
              when PID_Profile.SVF => SVF,
              when PID_Profile.PT2 => PT2,
              when PID_Profile.PT3 => PT3);
      else
         R.Dyn_LPF_Filter := None;
      end if;
      R.Dyn_LPF_Min := P.Dterm_LPF1_Dyn_Min_Hz;
      R.Dyn_LPF_Max := P.Dterm_LPF1_Dyn_Max_Hz;
      R.Dyn_LPF_Curve_Expo := P.Dterm_LPF1_Dyn_Expo;
      R.Launch_Control := P.Launch_Control;
      R.Launch_Control_Angle_Limit := (if Has_Acc then P.Launch_Control_Angle_Limit else 0);
      R.Launch_Control_Ki := I_Term_Scale * Float (P.Launch_Control_Gain);
      R.Thrust_Linearization := Float (P.Thrust_Linearization) / 100.0;
      for A in Axis loop
         R.D_Max_Percent (A) := D_Max_Percent_Of (P.Gains (A).D, P.D_Max (A));
      end loop;
      R.D_Max_Gyro_Gain := D_Max_Gain_Of (P.D_Max_Gain);
      R.D_Max_Setpoint_Gain := D_Max_Gain_Of (P.D_Max_Advance);
      R.Feedforward_Transition := Float (P.Feedforward_Transition) / 100.0;
      R.Feedforward_Transition_Inv :=
        (if P.Feedforward_Transition = 0 then 0.0 else 100.0 / Float (P.Feedforward_Transition));
      R.Feedforward_Average := P.Feedforward_Average;
      R.Feedforward_Smooth_Factor := Smooth_Factor_Of (P.Feedforward_Smooth_Factor);
      R.Feedforward_Jitter_Factor := P.Feedforward_Jitter_Factor;
      R.Feedforward_Jitter_Factor_Inv := 1.0 / (1.0 + Float (P.Feedforward_Jitter_Factor));
      R.Feedforward_Boost_Factor := 0.001 * Float (P.Feedforward_Boost);
      R.Feedforward_Max_Rate_Limit := P.Feedforward_Max_Rate_Limit;
      R.Feedforward_Interpolate := not Serial_Rx_Is_CRSF;
      R.Feedforward_Yaw_Hold_Time := 0.001 * Float (P.Feedforward_Yaw_Hold_Time);
      R.Feedforward_Yaw_Hold_Gain :=
        Yaw_Hold_Gain_Of (P.Feedforward_Yaw_Hold_Gain, P.Feedforward_Yaw_Hold_Time);
      R.Level_Race_Mode := P.Level_Race_Mode;
      R.TPA_Breakpoint := Breakpoint_Of (P.TPA_Breakpoint, 0.0, 0.99);
      R.TPA_Multiplier := TPA_Multiplier_Of (P.TPA_Rate, R.TPA_Breakpoint);
      R.TPA_Low_Breakpoint :=
        Float'Min (Breakpoint_Of (P.TPA_Low_Breakpoint, 0.01, 1.0), R.TPA_Breakpoint);
      pragma Assert (R.TPA_Low_Breakpoint = 0.0 or else R.TPA_Low_Breakpoint >= 0.001);
      R.TPA_Low_Multiplier := TPA_Low_Multiplier_Of (P.TPA_Low_Rate, R.TPA_Low_Breakpoint);
      R.TPA_Low_Always := P.TPA_Low_Always;
      R.Use_Ez_Disarm := P.Landing_Disarm_Threshold > 0;
      R.Landing_Disarm_Threshold := Float (P.Landing_Disarm_Threshold) * 10.0;
   end Configure;

end Adaflight.PID_Config;
