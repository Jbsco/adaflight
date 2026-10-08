package body Adaflight.PID_Filters with SPARK_Mode is

   Two_Pi : constant Float := 2.0 * Pi;

   procedure Lemma_Convert_Monotone (A : Natural; B : Natural) is
      pragma Unreferenced (A, B);
   begin
      null;
   end Lemma_Convert_Monotone;

   procedure Lemma_Convert_Successor (N : Natural) is
      pragma Unreferenced (N);
   begin
      null;
   end Lemma_Convert_Successor;

   function Floor_Of (X : Float) return Natural
     with Pre  => X in 4.75 .. Float (Limit_Max),
          Post => Floor_Of'Result <= Limit_Max
   is
      Rounded : constant Natural := Natural (X);
   begin
      if Float (Rounded) > X then
         return Rounded - 1;
      else
         return Rounded;
      end if;
   end Floor_Of;

   -------------------
   -- Nyquist_Limit --
   -------------------

   function Nyquist_Limit (Dt : Seconds) return Natural is
      Loop_Frequency : constant PID_Config.Frequency := 1.0 / Dt;
      Limit          : constant Float := (Loop_Frequency / 2.0) * 0.95;
   begin
      pragma Assert (Limit in 4.75 .. Float (Limit_Max));
      return Floor_Of (Limit);
   end Nyquist_Limit;

   procedure Init_Stage
     (Stage : out Lowpass_Stage; Kind : Lowpass_Kind; Cutoff : Hertz;
      Limit : Natural; Dt : Seconds; Inclusive : Boolean := False)
   is
   begin
      Stage := (Kind => Kind, Used => Cutoff > 0, others => <>);
      if Cutoff > 0 then
         case Kind is
            when PID_Profile.PT1 =>
               PT1_Init (Stage.P1, PT1_Gain (Float (Cutoff), Dt));
            when PID_Profile.SVF =>
               if (if Inclusive then Cutoff <= Limit else Cutoff < Limit) then
                  SVF_Lowpass_Init (Stage.S, Float (Cutoff), Dt);
               else
                  Stage.Used := False;
               end if;
            when PID_Profile.PT2 =>
               PT2_Init (Stage.P2, PT2_Gain (Float (Cutoff), Dt));
            when PID_Profile.PT3 =>
               PT3_Init (Stage.P3, PT3_Gain (Float (Cutoff), Dt));
         end case;
      end if;
   end Init_Stage;

   procedure Apply_Stage (Stage : in out Lowpass_Stage; Input : Signal; Output : out Signal) is
   begin
      if not Stage.Used then
         Output := Input;
         return;
      end if;
      case Stage.Kind is
         when PID_Profile.PT1 => PT1_Apply (Stage.P1, Input, Output);
         when PID_Profile.SVF => SVF_Lowpass_Apply (Stage.S, Input, Output);
         when PID_Profile.PT2 => PT2_Apply (Stage.P2, Input, Output);
         when PID_Profile.PT3 => PT3_Apply (Stage.P3, Input, Output);
      end case;
   end Apply_Stage;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; P : Profile; R : Runtime) is
      Limit    : constant Natural := Nyquist_Limit (R.Dt);
      Notch_Hz : Natural := 0;
      LPF1_Hz  : Hertz := P.Dterm_LPF1_Static_Hz;
   begin
      S := (others => <>);
      if P.Dterm_Notch_Hz <= Limit then
         Notch_Hz := P.Dterm_Notch_Hz;
      elsif P.Dterm_Notch_Cutoff < Limit then
         Notch_Hz := Limit;
      end if;
      --  A cutoff at or above the center leaves the notch off.
      if Notch_Hz /= 0 and then P.Dterm_Notch_Cutoff /= 0
        and then P.Dterm_Notch_Cutoff < Notch_Hz
      then
         S.Notch_Used := True;
         Lemma_Convert_Successor (P.Dterm_Notch_Cutoff);
         Lemma_Convert_Monotone (P.Dterm_Notch_Cutoff + 1, Notch_Hz);
         declare
            Q : constant Quality := Notch_Q (Float (Notch_Hz), Float (P.Dterm_Notch_Cutoff));
         begin
            for A in Axis loop
               SVF_Notch_Init (S.Notch (A), Float (Notch_Hz), R.Dt, Q);
            end loop;
         end;
      end if;
      if P.Dterm_LPF1_Dyn_Min_Hz > 0 then
         LPF1_Hz := P.Dterm_LPF1_Dyn_Min_Hz;
      end if;
      for A in Axis loop
         Init_Stage (S.Lowpass1 (A), P.Dterm_LPF1_Type, LPF1_Hz, Limit, R.Dt);
      end loop;
      for A in Axis loop
         Init_Stage (S.Lowpass2 (A), P.Dterm_LPF2_Type, P.Dterm_LPF2_Static_Hz, Limit, R.Dt);
      end loop;
      if P.Yaw_Lowpass_Hz /= 0 then
         S.Yaw_P_Used := True;
         PT1_Init (S.Yaw_P_Lowpass, PT1_Gain (Float (P.Yaw_Lowpass_Hz), R.Dt));
      end if;
      PT1_Init (S.Throttle_Boost, PT1_Gain (Float (P.Throttle_Boost_Cutoff), R.Dt));
      if R.Iterm_Relax /= Off then
         for A in Axis loop
            PT1_Init (S.Windup (A), PT1_Gain (Float (R.Iterm_Relax_Cutoff), R.Dt));
         end loop;
      end if;
      for A in Axis loop
         PT2_Init (S.D_Max_Range (A), PT2_Gain (D_Max_Range_Hz, R.Dt));
         PT2_Init (S.D_Max_Lowpass (A), PT2_Gain (D_Max_Lowpass_Hz, R.Dt));
      end loop;
      PT2_Init (S.Anti_Gravity, PT2_Gain (Float (P.Anti_Gravity_Cutoff_Hz), R.Dt));
      declare
         Attitude_K     : constant Unit_Interval := PT3_Gain (Attitude_Cutoff_Hz, R.Dt);
         Angle_Cutoff   : constant Float :=
           1000.0 / (Two_Pi * Float (P.Angle_Feedforward_Smoothing_Ms));
         Angle_K        : constant Unit_Interval := PT3_Gain (Angle_Cutoff, R.Dt);
         Horizon_Cutoff : constant Float := 1000.0 / (Two_Pi * Float (P.Horizon_Delay_Ms));
      begin
         S.Horizon_Delay_Ms := P.Horizon_Delay_Ms;
         PT1_Init (S.Horizon_Smoothing, PT1_Gain (Horizon_Cutoff, R.Dt));
         for A in Level_Axis loop
            PT3_Init (S.Attitude (A), Attitude_K);
            PT3_Init (S.Angle_Feedforward (A), Angle_K);
         end loop;
      end;
   end Init;

   -----------------
   -- Apply_Dterm --
   -----------------

   procedure Apply_Dterm (S : in out State; A : Axis; Input : Signal; Output : out Signal) is
      After_Notch : Signal := Input;
      After_LPF1  : Signal;
   begin
      if S.Notch_Used then
         SVF_Notch_Apply (S.Notch (A), Input, After_Notch);
      end if;
      Apply_Stage (S.Lowpass1 (A), After_Notch, After_LPF1);
      Apply_Stage (S.Lowpass2 (A), After_LPF1, Output);
   end Apply_Dterm;

   -----------------
   -- Apply_Yaw_P --
   -----------------

   procedure Apply_Yaw_P (S : in out State; Input : Signal; Output : out Signal) is
   begin
      if S.Yaw_P_Used then
         PT1_Apply (S.Yaw_P_Lowpass, Input, Output);
      else
         Output := Input;
      end if;
   end Apply_Yaw_P;

   function Dynamic_Throttle (T : Unit_Interval) return Float is
     (T * (1.0 - (T * T) / 3.0) * 1.5);

   function Dynamic_Cutoff (T : Unit_Interval; Min : Hertz; Max : Hertz; Expo : Natural) return Float is
      Expo_F : constant Float := Float (Expo) / 10.0;
      Curve  : constant Float := T * (1.0 - T) * Expo_F + T;
   begin
      pragma Assert (Curve in 0.0 .. 1.3);
      return Float (Max - Min) * Curve + Float (Min);
   end Dynamic_Cutoff;

   ----------------------------
   -- Update_Dynamic_Lowpass --
   ----------------------------

   procedure Update_Dynamic_Lowpass (S : in out State; R : Runtime; Throttle : Unit_Interval) is
      Cutoff : Float;
   begin
      if R.Dyn_LPF_Filter = None then
         return;
      end if;
      if R.Dyn_LPF_Curve_Expo > 0 then
         Cutoff := Dynamic_Cutoff (Throttle, R.Dyn_LPF_Min, R.Dyn_LPF_Max, R.Dyn_LPF_Curve_Expo);
      else
         Cutoff := Float'Max (Dynamic_Throttle (Throttle) * Float (R.Dyn_LPF_Max), Float (R.Dyn_LPF_Min));
      end if;
      Cutoff := Constrain_F (Cutoff, 0.0, 2300.0);
      case R.Dyn_LPF_Filter is
         when None => null;
         when PID_Config.PT1 =>
            for A in Axis loop
               PT1_Update_Cutoff (S.Lowpass1 (A).P1, PT1_Gain (Cutoff, R.Dt));
            end loop;
         when PID_Config.SVF =>
            Cutoff := Float'Min (Cutoff, 0.475 / R.Dt);
            for A in Axis loop
               SVF_Lowpass_Update (S.Lowpass1 (A).S, Cutoff, R.Dt);
            end loop;
         when PID_Config.PT2 =>
            for A in Axis loop
               PT2_Update_Cutoff (S.Lowpass1 (A).P2, PT2_Gain (Cutoff, R.Dt));
            end loop;
         when PID_Config.PT3 =>
            for A in Axis loop
               PT3_Update_Cutoff (S.Lowpass1 (A).P3, PT3_Gain (Cutoff, R.Dt));
            end loop;
      end case;
   end Update_Dynamic_Lowpass;

end Adaflight.PID_Filters;
