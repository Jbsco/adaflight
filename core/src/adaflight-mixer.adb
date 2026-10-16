with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.PID_Filters;

package body Adaflight.Mixer with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   --  The clamp as the reference writes it, which also admits a lower bound
   --  above the upper one after rounding.
   function Clamp (Value : Float; Low : Float; High : Float) return Float
     with Post => Clamp'Result = Low or else Clamp'Result = High or else Clamp'Result = Value
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
      if C.Throttle_Limit_Percent < 100 then
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

   procedure Update
     (S   : in out State; C : Config; Ctl : in out PID_Controller.State;
      R   : Runtime; P : Profile; Inp : Inputs)
   is
      Airmode  : constant Boolean := Inp.Airmode or else Inp.Launch_Control_Active;
      Active   : constant Mix_Table :=
        (if Inp.Launch_Control_Active and then R.Launch_Control = Pitch_Only then C.Launch_Table else C.Table);
      Throttle : Float := (Inp.RC_Throttle - 1000.0) + Float (Inp.Throttle_Angle_Correction);
      Range_Min : constant Motor_Value := C.Output_Low;
      Range_Max : constant Motor_Value := C.Output_High;
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
                  S.Motors (M) := Constrain_F (Output, C.Disarm_Output, Range_Max);
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
