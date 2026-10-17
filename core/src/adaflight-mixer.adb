with Adaflight.PID_Filters;

package body Adaflight.Mixer with SPARK_Mode is
   use Adaflight.Filters;

   use type Interfaces.Unsigned_32;

   --  The clamp as the reference writes it, which also admits a lower bound
   --  above the upper one after rounding.
   function Clamp (Value : Float; Low : Float; High : Float) return Float
     with Post =>
       (if Value < Low then Clamp'Result = Low elsif Value > High then Clamp'Result = High else Clamp'Result = Value)
   is
   begin
      if Value < Low then
         return Low;
      elsif Value > High then
         return High;
      else
         return Value;
      end if;
   end Clamp;

   subtype Throttle_Step is Integer range 0 .. Dyn_LPF_Throttle_Steps;

   --  Rounds to the nearest integer with ties to even, as the C library's
   --  lrintf does in its default mode.
   function Round_Half_Even (X : Float) return Throttle_Step
     with Pre => X in 0.0 .. Float (Dyn_LPF_Throttle_Steps)
   is
      R : Integer := Integer (X);
   begin
      if abs (X - Float (R)) = 0.5 and then R mod 2 /= 0 then
         R := R - 1;
      end if;
      return R;
   end Round_Half_Even;

   subtype Mix_Value is Float range -64.0 .. 64.0;
   type Mix_Values is array (Motor_Index) of Mix_Value;
   subtype Mix_Span is Float range 0.0 .. 128.0;

   --  The throttle after an adjustment, which the clamps can carry beyond
   --  the unit interval only through a mix the weights cannot produce.
   subtype Adjusted_Throttle is Float range -100.0 .. 100.0;

   subtype Scaled_Sum is Float range -1.0 .. 1.0;

   function Scale_Sum (Sum : Signal; Limit : Float) return Scaled_Sum
     with Pre => Limit in 100.0 .. 1000.0
   is
   begin
      return Constrain_F (Sum, -Limit, Limit) / PID_Mixer_Scaling;
   end Scale_Sum;

   function Mix_Of (W : Motor_Weights; R : Scaled_Sum; P : Scaled_Sum; Y : Scaled_Sum) return Mix_Value
     with Post => abs Mix_Of'Result <= 6.0
   is
   begin
      return R * W.Roll + P * W.Pitch + Y * W.Yaw;
   end Mix_Of;

   subtype Shaped_Throttle is Float range -1.0 .. 1.0;

   function Airmode_Transition (Throttle : Shaped_Throttle) return Float is
     (Throttle * 1.0 + 0.5)
     with Post => Airmode_Transition'Result in -0.5 .. 1.5;

   function Throttle_Limited (Throttle : Unit_Interval; C : Config) return Unit_Interval is
      Factor : constant Unit_Interval := Float (C.Throttle_Limit_Percent) / 100.0;
   begin
      if C.Throttle_Limit_Percent < 100 and then not C.RPM_Limit then
         case C.Throttle_Limit is
            when Scale => return Throttle * Factor;
            when Clip  => return Float'Min (Throttle, Factor);
            when Off   => return Throttle;
         end case;
      end if;
      return Throttle;
   end Throttle_Limited;

   ----------------------
   -- Adjustment paths --
   ----------------------

   procedure Adjust_Legacy
     (Mix : in out Mix_Values; C : Config; Mix_Min : Mix_Value; Mix_Max : Mix_Value;
      Mix_Range : Mix_Span; Airmode : Boolean; Throttle : in out Float)
     with Pre => Throttle in -1.0 .. 1.0, Post => Throttle in Adjusted_Throttle
   is
      Transition : Float := 1.0;
      Normalization : Float;
   begin
      if not Airmode and then Throttle < 0.5 then
         Transition := Airmode_Transition (Throttle);
      end if;
      Normalization := (if Mix_Range > 1.0 then Transition / Mix_Range else Transition);
      pragma Assert (Normalization in -0.5 .. 1.5);
      for M in 0 .. C.Count - 1 loop
         Mix (M) := Constrain_F (Mix (M) * Normalization, -64.0, 64.0);
      end loop;
      declare
         Norm_Min : constant Float := Mix_Min * Normalization;
         Norm_Max : constant Float := Mix_Max * Normalization;
      begin
         pragma Assert (Norm_Min in -96.0 .. 96.0 and then Norm_Max in -96.0 .. 96.0);
         Throttle := Clamp (Throttle, -Norm_Min, 1.0 - Norm_Max);
      end;
   end Adjust_Legacy;

   procedure Adjust_Linear
     (Mix : in out Mix_Values; C : Config; Mix_Range : Mix_Span; Airmode : Boolean;
      Throttle : in out Float)
     with Pre => Throttle in -1.0 .. 1.0, Post => Throttle in Adjusted_Throttle
   is
      Transition  : Float := 1.0;
      Delta_Scale : Float := 0.5;
      Normalization : Float;
      Mix_Delta : Float;
      Min_Motor : Float := Float'Last;
      Max_Motor : Float := 2.0 ** (-126);
   begin
      if not Airmode and then Throttle < 0.5 then
         Transition := Airmode_Transition (Throttle);
         Delta_Scale := Delta_Scale * Transition;
      end if;
      Normalization := (if Mix_Range > 1.0 then Transition / Mix_Range else Transition);
      pragma Assert (Normalization in -0.5 .. 1.5);
      Mix_Delta := Delta_Scale * Mix_Range;
      pragma Assert (Mix_Delta in -64.0 .. 96.0);
      for M in 0 .. C.Count - 1 loop
         pragma Loop_Invariant (Min_Motor in -64.0 .. Float'Last and then Max_Motor in -64.0 .. 64.0);
         if C.Kind = Linear then
            Mix (M) := Constrain_F
              (Scale_Range_F (Throttle, 0.0, 1.0, Mix (M) + Mix_Delta, Mix (M) - Mix_Delta), -64.0, 64.0);
         else
            Mix (M) := Constrain_F
              (Scale_Range_F (Throttle, 0.0, 1.0, Mix (M) + abs Mix (M), Mix (M) - abs Mix (M)), -64.0, 64.0);
         end if;
         Mix (M) := Constrain_F (Mix (M) * Normalization, -64.0, 64.0);
         Max_Motor := Float'Max (Mix (M), Max_Motor);
         Min_Motor := Float'Min (Mix (M), Min_Motor);
      end loop;
      pragma Assert (Min_Motor in -64.0 .. 64.0);
      Throttle := Clamp (Throttle, -Min_Motor, 1.0 - Max_Motor);
   end Adjust_Linear;

   procedure Adjust_Ez_Landing
     (Mix : in out Mix_Values; C : Config; P : Profile; Mix_Min : Mix_Value; Mix_Max : Mix_Value;
      Mix_Range : Mix_Span; Range_Out : out Signal; Max_Deflection : Unit_Interval; Speed : Float;
      Throttle : in out Float)
     with Pre => Throttle in -1.0 .. 1.0 and then Speed in 0.0 .. 1000.0,
          Post => Throttle in Adjusted_Throttle
   is
      Ez_Threshold : constant Float := 2.0 * Float (P.Ez_Landing_Threshold) / 100.0;
      Ez_Limit     : constant Float := Float (P.Ez_Landing_Limit) / 100.0;
      Ez_Speed     : constant Float := 2.0 * Float (P.Ez_Landing_Speed) / 10.0;
      Base : constant Float := (if Mix_Range > 1.0 then 1.0 / Mix_Range else 1.0);
      Norm_Min : constant Float := Mix_Min * Base;
      Norm_Max : constant Float := Mix_Max * Base;
      Deflection_Limit : constant Float :=
        (if Ez_Threshold > 0.0 then Float'Min (1.0, Max_Deflection / Ez_Threshold) else 0.0);
      Speed_Limit : constant Float := (if Ez_Speed > 0.0 then Float'Min (1.0, Speed / Ez_Speed) else 0.0);
      Ez_Land_Limit : constant Float :=
        Float'Max (Ez_Limit, Float'Max (Deflection_Limit, Speed_Limit));
      Upper : Float := Float'Max (Ez_Land_Limit, Throttle);
      Abs_Min : Float;
      Lower : Float;
      Factor : Float;
      Normalization : Float;
   begin
      Upper := Float'Min (Upper, 1.0 - Norm_Max);
      Abs_Min := abs Norm_Min + 1.0e-6;
      Lower := Float'Min (Upper, Abs_Min);
      Factor := Upper / Abs_Min;
      Normalization := Base * Float'Min (1.0, Factor);
      pragma Assert (Norm_Min in -64.0 .. 64.0 and then Norm_Max in -64.0 .. 64.0);
      pragma Assert (Upper in -65.0 .. 1.0 and then Abs_Min in 0.0 .. 65.0 and then Lower in -65.0 .. 65.0);
      for M in 0 .. C.Count - 1 loop
         Mix (M) := Constrain_F (Mix (M) * Normalization, -64.0, 64.0);
      end loop;
      Range_Out := Constrain_F (Mix_Range * Base, 0.0, Signal_Bound);
      --  A vanishing factor leaves the reference's range infinite; it saturates here (D6).
      if Factor > 0.0 then
         Range_Out := Constrain_F (Float'Max (Range_Out, 1.0 / Float'Max (Factor, 2.0 ** (-100))), 0.0, Signal_Bound);
      else
         Range_Out := Signal_Bound;
      end if;
      Throttle := Clamp (Throttle, Lower, Upper);
   end Adjust_Ez_Landing;

   ------------
   -- Update --
   ------------

   --  The motors' top RPM from the KV and the battery voltage, derated for
   --  the load of the propellers.
   function Estimated_Max_RPM (C : Config; Battery_Voltage : Interfaces.Unsigned_16) return Float is
     ((0.01 * Float (Battery_Voltage) * Float (C.Motor_KV))
      * (-5.44E-6 * (0.01 * Float (Battery_Voltage) * Float (C.Motor_KV)) + 0.944))
     with Global => null;

   --  The limit over the estimated top RPM within zero and one; an estimate
   --  under a thousandth, where the quotient passes one, gives one.
   function Limit_Scale (C : Config; Battery_Voltage : Interfaces.Unsigned_16) return Unit_Interval
     with Global => null
   is
      Estimate : constant Float := Estimated_Max_RPM (C, Battery_Voltage);
   begin
      if Estimate >= 1.0E-3 then
         return Constrain_F (Float (C.RPM_Limit_Value) / Estimate, 0.0, 1.0);
      elsif Estimate >= 0.0 then
         return 1.0;
      else
         return 0.0;
      end if;
   end Limit_Scale;

   ------------------------
   -- Reset_RPM_Limiter --
   ------------------------

   procedure Reset_RPM_Limiter (S : in out State; C : Config; Battery_Voltage : Interfaces.Unsigned_16) is
   begin
      S.Limiter_I := 0.0;
      S.Limiter_Scale := Limit_Scale (C, Battery_Voltage);
      S.Limiter_Initial_Scale := S.Limiter_Scale;
   end Reset_RPM_Limiter;

   ----------------------
   -- Init_RPM_Limiter --
   ----------------------

   procedure Init_RPM_Limiter
     (S : in out State; C : Config; R : Runtime; Battery_Voltage : Interfaces.Unsigned_16)
   is
   begin
      S.Limiter_P_Gain := Float (C.RPM_Limit_P) * 15.0E-6;
      S.Limiter_I_Gain := Float (C.RPM_Limit_I) * 1.0E-3 * R.Dt;
      S.Limiter_D_Gain := Float (C.RPM_Limit_D) * 3.0E-7 * R.PID_Frequency;
      S.Limiter_I := 0.0;
      PT1_Init (S.Limiter_Average, PT1_Gain (6.0, R.Dt));
      PT1_Init (S.Limiter_Offset, PT1_Gain (2.0, R.Dt));
      Reset_RPM_Limiter (S, C, Battery_Voltage);
   end Init_RPM_Limiter;

   --  The RPM limiter: a PID on the averaged RPM over the limit, whose
   --  output comes off the throttle, and a throttle scale that falls while
   --  the RPM is over the limit below the maximum check and rises while the
   --  output is negative at the maximum check with no motor saturated.
   procedure Apply_RPM_Limiter
     (S : in out State; C : Config; R : Runtime; Inp : Inputs; Throttle : in out Float)
     with Global => null,
          Pre    => Throttle in -1.0 .. 1.0,
          Post   => Throttle in 0.0 .. 1.0
   is
      subtype Error_Value is Float range -2.0 ** 33 .. 2.0 ** 33;
      Average   : Signal;
      Error     : Error_Value;
      P_Term    : Float range -2.0 ** 24 .. 2.0 ** 24;
      D_Term    : Float range -2.0 ** 40 .. 2.0 ** 40;
      Output    : Float;
      Offset    : Signal;
      Saturated : Boolean := False;
   begin
      PT1_Apply (S.Limiter_Average, Inp.RPM_Average, Average);
      Error := Average - Float (C.RPM_Limit_Value);
      P_Term := Error * S.Limiter_P_Gain;
      D_Term := (Error - S.Limiter_Previous_Error) * S.Limiter_D_Gain;
      S.Limiter_I := Float'Min (1.0E30, Float'Max (0.0, S.Limiter_I + Error * S.Limiter_I_Gain));
      Output := P_Term + S.Limiter_I + D_Term;
      for M in 0 .. C.Count - 1 loop
         if S.Motors (M) >= Float (C.Max_Throttle) then
            Saturated := True;
         end if;
      end loop;
      if Error > 0.0 and then Inp.RC_Throttle < Float (C.Max_Check) then
         S.Limiter_Scale := Constrain_F (S.Limiter_Scale * (1.0 - 4.8 * R.Dt), 0.01, 1.0);
      elsif Output < -400.0 * R.Dt
        and then Adaflight.Maths.Round_Half_Even (Inp.RC_Throttle) >= C.Max_Check - 5
        and then not Saturated
      then
         S.Limiter_Scale := Constrain_F (S.Limiter_Scale * (1.0 + 3.2 * R.Dt), 0.01, 1.0);
      else
         S.Limiter_Scale := Constrain_F (S.Limiter_Scale, 0.01, 1.0);
      end if;
      PT1_Apply (S.Limiter_Offset, Limit_Scale (C, Inp.Battery_Voltage) - S.Limiter_Initial_Scale, Offset);
      Throttle := Throttle * Constrain_F (S.Limiter_Scale + Offset, 0.0, 1.0);
      Throttle := Constrain_F (Throttle - Float'Max (0.0, Output), 0.0, 1.0);
      S.Limiter_Previous_Error := Error;
   end Apply_RPM_Limiter;

   Flip_Stick_Deadband : constant := 0.15;
   Flip_Motor_Deadband : constant := 0.02;
   Flip_Half_Complete  : constant := 0.5;
   Sqrt_Two            : constant Float := 1.414_213_562_373_095;
   Cos_Thirty_Degrees  : constant Float := 0.866_025_403_784_438_6;

   --  The motor output at a crash flip drive: the low end plus the drive's
   --  share of the output range.
   function Flip_Output (Low : Motor_Value; High : Motor_Value; Drive : Float) return Motor_Value
     with Global => null,
          Pre    => Low < High and then Drive in 0.0 .. 1.0,
          Post   => Flip_Output'Result >= Low
   is
      Span : constant Float := High - Low;
   begin
      pragma Assert (Drive * Span <= Span);
      pragma Assert (Low + Drive * Span <= Low + Span);
      pragma Assert (Low + Span <= Motor_Value'Last);
      return Low + Drive * Span;
   end Flip_Output;

   --  The crash flip: the motors drive the craft over in the direction of
   --  the roll or pitch stick, of the diagonal between them, or of the yaw
   --  stick when it leads, with less drive as the craft turns.
   procedure Apply_Crash_Flip
     (S : in out State; C : Config; Inp : Inputs; Output_Min : Motor_Value; Range_Max : Motor_Value)
     with Global => null,
          Pre    => C.Output_Low <= Output_Min and then Output_Min < Range_Max,
          Post   =>
            (for all M in 0 .. C.Count - 1 => S.Motors (M) >= Float'Min (C.Disarm_Output, C.Output_Low))
   is
      Pitch_Abs  : constant Unit_Interval := Inp.Deflection_Abs (Pitch);
      Roll_Abs   : constant Unit_Interval := Inp.Deflection_Abs (Roll);
      Yaw_Abs    : constant Unit_Interval := Inp.Deflection_Abs (Yaw);
      Sign_Pitch : Float range -1.0 .. 1.0 := (if Inp.Deflection (Pitch) < 0.0 then 1.0 else -1.0);
      Sign_Roll  : Float range -1.0 .. 1.0 := (if Inp.Deflection (Roll) < 0.0 then 1.0 else -1.0);
      Sign_Yaw   : Float range -1.0 .. 1.0 :=
        (if Inp.Deflection (Yaw) < 0.0 then 1.0 else -1.0) * (if C.Yaw_Reversed then 1.0 else -1.0);
      Length     : Root_Signal := Sqrt_Bounded (Pitch_Abs * Pitch_Abs + Roll_Abs * Roll_Abs);
      Cos_Phi    : Float;
      Power      : Root_Signal;
      Rate_Limit : constant Float := Float (C.Crashflip_Rate) * 10.0;
   begin
      if Yaw_Abs > Float'Max (Pitch_Abs, Roll_Abs) then
         Length := Yaw_Abs;
         Sign_Roll := 0.0;
         Sign_Pitch := 0.0;
      else
         Sign_Yaw := 0.0;
      end if;
      Cos_Phi := (if Length > 1.0E-30 then (Pitch_Abs + Roll_Abs) / (Sqrt_Two * Length) else 0.0);
      if Cos_Phi < Cos_Thirty_Degrees then
         if Roll_Abs > Pitch_Abs then
            Sign_Pitch := 0.0;
         else
            Sign_Roll := 0.0;
         end if;
      end if;
      Power := (if Length > Flip_Stick_Deadband then Length else 0.0);
      if Rate_Limit > 0.0 then
         declare
            Attitude_Attenuator : Unit_Interval := 1.0;
            Rate_Change         : Unit_Interval;
            Rate_Attenuator     : Unit_Interval;
         begin
            if Inp.Acc_Present then
               if not S.Flip_Tilt_Set then
                  S.Flip_Tilt_Start := Inp.Cos_Tilt;
                  S.Flip_Tilt_Set := True;
               end if;
               declare
                  Change_Needed : constant Unit_Interval :=
                    Float'Max (1.0 - abs (Inp.Cos_Tilt - S.Flip_Tilt_Start), 0.0);
               begin
                  Attitude_Attenuator :=
                    (if Change_Needed > Flip_Half_Complete then 1.0 else Change_Needed / Flip_Half_Complete);
               end;
            end if;
            Rate_Change := Float'Min (Float'Max (abs Inp.Gyro (Roll), abs Inp.Gyro (Pitch)) / Rate_Limit, 1.0);
            Rate_Attenuator :=
              (if Rate_Change < Flip_Half_Complete then 1.0 else (1.0 - Rate_Change) / Flip_Half_Complete);
            Power := Power * (Attitude_Attenuator * Rate_Attenuator);
         end;
      end if;
      for M in 0 .. C.Count - 1 loop
         pragma Loop_Invariant
           (for all J in 0 .. M - 1 => S.Motors (J) >= Float'Min (C.Disarm_Output, C.Output_Low));
         declare
            Drive : Float :=
              Sign_Pitch * C.Table (M).Pitch + Sign_Roll * C.Table (M).Roll + Sign_Yaw * C.Table (M).Yaw;
         begin
            if Drive < 0.0 then
               if C.Crashflip_Motor_Percent > 0 then
                  Drive := (-Drive) * Float (C.Crashflip_Motor_Percent) / 100.0;
               else
                  Drive := 0.0;
               end if;
            end if;
            Drive := Float'Min (1.0, Power * Drive);
            S.Motors (M) :=
              (if Drive < Flip_Motor_Deadband then C.Disarm_Output else Flip_Output (Output_Min, Range_Max, Drive));
         end;
      end loop;
   end Apply_Crash_Flip;

   --  The top of the motor range: the high end, lowered by the sag
   --  compensation the fuller the battery is, except in the crash flip. A
   --  lowering past the low end holds at the low end (D6).
   function Top_Of_Range (C : Config; Inp : Inputs) return Motor_Value
     with Global => null,
          Post   =>
            Top_Of_Range'Result in C.Output_Low .. C.Output_High
            and then (if Inp.Crash_Flip_Active then Top_Of_Range'Result = C.Output_High)
   is
      Attenuation : Float range 0.0 .. 1.2 := 0.0;
   begin
      if Sag_Factor (C) > 0.0 then
         declare
            Goodness : constant Unit_Interval :=
              1.0 - Constrain_F ((Float (Sag_Full_Cell_Voltage) - Float (Inp.Sag_Cell_Voltage)) / Sag_Range (C),
                                 0.0, 1.0);
         begin
            Attenuation := Sag_Range (C) / Float (Sag_Full_Cell_Voltage) * Goodness * Sag_Factor (C);
         end;
      end if;
      if Inp.Crash_Flip_Active then
         return C.Output_High;
      end if;
      return Float'Max (C.Output_Low, C.Output_High - Attenuation * (C.Output_High - C.Output_Low));
   end Top_Of_Range;

   procedure Update
     (S   : in out State; C : Config; Ctl : in out PID_Controller.State;
      R   : Runtime; P : Profile; Inp : Inputs)
   is
      Airmode  : constant Boolean := Inp.Airmode or else Inp.Launch_Control_Active;
      Active   : constant Mix_Table :=
        (if Inp.Launch_Control_Active and then R.Launch_Control = Pitch_Only then C.Launch_Table else C.Table);
      Throttle : Float := (Inp.RC_Throttle - 1000.0) + Float (Inp.Throttle_Angle_Correction);
      Range_Min : constant Motor_Value := C.Output_Low;
      Range_Max : constant Motor_Value := Top_Of_Range (C, Inp);
      Output_Min : constant Motor_Value := Range_Min;
      Output_Range : constant Float := Range_Max - Range_Min;
      Scaled_Roll : constant Scaled_Sum := Scale_Sum (Ctl.Data (Roll).Sum, Float (P.PID_Sum_Limit));
      Scaled_Pitch : constant Scaled_Sum := Scale_Sum (Ctl.Data (Pitch).Sum, Float (P.PID_Sum_Limit));
      Scaled_Yaw : Scaled_Sum :=
        Scale_Sum (Ctl.Data (Yaw).Sum, (if Inp.Yaw_Spin_Detected then 1000.0 else Float (P.PID_Sum_Limit_Yaw)));
      Mix : Mix_Values := (others => 0.0);
      Mix_Min : Mix_Value := 0.0;
      Mix_Max : Mix_Value := 0.0;
      Mix_Range : Mix_Span;
      Range_Out : Signal;
   begin
      Throttle := Constrain_F (Throttle / 1000.0, 0.0, 1.0);
      S.RC_Throttle := Throttle;
      if Inp.Crash_Flip_Active then
         Apply_Crash_Flip (S, C, Inp, Output_Min, Range_Max);
         return;
      end if;
      S.Flip_Tilt_Set := False;
      if not C.Yaw_Reversed then
         Scaled_Yaw := -Scaled_Yaw;
      end if;
      if C.Throttle_Limit /= Off then
         Throttle := Throttle_Limited (Throttle, C);
      end if;
      PID_Controller.Update_Throttle_Terms (Ctl, R, Throttle);
      if Inp.Time_Us - S.Dyn_LPF_Last_Update_Us >= Dyn_LPF_Update_Delay_Us then
         declare
            Quantized : constant Throttle_Step :=
              Round_Half_Even (Throttle * Float (Dyn_LPF_Throttle_Steps));
         begin
            if Quantized /= S.Dyn_LPF_Previous_Step then
               PID_Filters.Update_Dynamic_Lowpass
                 (Ctl.Filters, R, Float (Quantized) / Float (Dyn_LPF_Throttle_Steps));
               S.Dyn_LPF_Previous_Step := Quantized;
               S.Dyn_LPF_Last_Update_Us := Inp.Time_Us;
            end if;
         end;
      end if;
      if R.Throttle_Boost > 0.0 then
         declare
            Lowpassed : Signal;
         begin
            PT1_Apply (Ctl.Filters.Throttle_Boost, Throttle, Lowpassed);
            Throttle := Constrain_F (Throttle + R.Throttle_Boost * (Throttle - Lowpassed), 0.0, 1.0);
         end;
      end if;
      S.Throttle := Throttle;
      Throttle := PID_Controller.Compensate_Thrust_Linearization (R, Throttle);
      if C.RPM_Limit and then Inp.DShot_Telemetry and then Inp.Armed then
         Apply_RPM_Limiter (S, C, R, Inp, Throttle);
      end if;
      for M in 0 .. C.Count - 1 loop
         pragma Loop_Invariant (Mix_Max in 0.0 .. 64.0 and then Mix_Min in -64.0 .. 0.0);
         declare
            Value : constant Mix_Value := Mix_Of (Active (M), Scaled_Roll, Scaled_Pitch, Scaled_Yaw);
         begin
            if Value > Mix_Max then
               Mix_Max := Value;
            elsif Value < Mix_Min then
               Mix_Min := Value;
            end if;
            Mix (M) := Value;
         end;
      end loop;
      if Inp.Yaw_Spin_Detected and then not Airmode then
         Throttle := 0.5;
      end if;
      if Inp.Launch_Control_Active then
         Throttle := 0.0;
      end if;
      if Inp.Alt_Hold_Mode and then Inp.Autopilot_Throttle_Valid then
         Throttle := Inp.Autopilot_Throttle;
      end if;
      if Inp.GPS_Rescue_Mode and then Inp.Autopilot_Throttle_Valid then
         Throttle := Inp.Autopilot_Throttle;
      end if;
      Mix_Range := Mix_Max - Mix_Min;
      Range_Out := Mix_Range;
      case C.Kind is
         when Legacy =>
            Adjust_Legacy (Mix, C, Mix_Min, Mix_Max, Mix_Range, Airmode, Throttle);
         when Linear | Dynamic =>
            Adjust_Linear (Mix, C, Mix_Range, Airmode, Throttle);
         when Ez_Landing =>
            Adjust_Ez_Landing
              (Mix, C, P, Mix_Min, Mix_Max, Mix_Range, Range_Out, Inp.Max_Deflection, Inp.Speed, Throttle);
      end case;
      S.Mix_Range := Range_Out;
      if C.Motor_Stop and then Inp.Armed and then not Airmode
        and then not (Inp.GPS_Rescue_Mode or else Inp.Alt_Hold_Mode or else Inp.Pos_Hold_Mode)
        and then Inp.RC_Throttle < Float (C.Min_Check)
      then
         for M in 0 .. C.Count - 1 loop
            pragma Loop_Invariant
              (for all J in 0 .. M - 1 =>
                 S.Motors (J) in Float'Min (C.Disarm_Output, C.Output_Low) .. C.Output_High);
            S.Motors (M) := C.Disarm_Output;
         end loop;
      else
         for M in 0 .. C.Count - 1 loop
            pragma Loop_Invariant
              (for all J in 0 .. M - 1 =>
                 S.Motors (J) in Float'Min (C.Disarm_Output, C.Output_Low) .. C.Output_High);
            declare
               Command : constant PID_Controller.Motor_Command := Mix (M) + Throttle * Active (M).Throttle;
               Shaped  : constant Float := PID_Controller.Apply_Thrust_Linearization (R, Command);
               Output  : constant Float := Output_Min + Output_Range * Shaped;
            begin
               if Inp.Failsafe then
                  S.Motors (M) :=
                    Clamp ((if C.DShot and then Output < Range_Min then C.Disarm_Output else Output),
                           C.Disarm_Output, Range_Max);
               else
                  S.Motors (M) := Constrain_F (Output, Range_Min, Range_Max);
               end if;
            end;
         end loop;
         if not Inp.Armed then
            for M in 0 .. C.Count - 1 loop
               pragma Loop_Invariant
                 (for all J in 0 .. M - 1 =>
                    S.Motors (J) in Float'Min (C.Disarm_Output, C.Output_Low) .. C.Output_High);
               S.Motors (M) := C.Disarm_Output;
            end loop;
         end if;
      end if;
   end Update;

end Adaflight.Mixer;
