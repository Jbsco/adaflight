package body Adaflight.PID_Filters with SPARK_Mode is

   Two_Pi : constant Float := 2.0 * Pi;

   Limit_Max : constant := 475_000;

   procedure Lemma_Convert_Monotone (A : Natural; B : Natural)
     with Ghost, Global => null,
          Pre  => A <= B and then B <= Limit_Max,
          Post => Float (A) <= Float (B)
   is
   begin
      null;
   end Lemma_Convert_Monotone;

   procedure Lemma_Convert_Successor (N : Natural)
     with Ghost, Global => null,
          Pre  => N < Limit_Max,
          Post => Float (N + 1) = Float (N) + 1.0
   is
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

   --  Builds one lowpass stage as the controller selects it; a state-variable
   --  stage at or above the limit is left unused.
   procedure Init_Stage
     (Stage : out Lowpass_Stage; Kind : Lowpass_Kind; Cutoff : Hertz;
      Limit : Natural; Dt : Seconds)
     with Pre => Limit <= Limit_Max
   is
   begin
      Stage := (Kind => Kind, Used => Cutoff > 0, others => <>);
      if Cutoff > 0 then
         case Kind is
            when PID_Profile.PT1 =>
               PT1_Init (Stage.P1, PT1_Gain (Float (Cutoff), Dt));
            when PID_Profile.SVF =>
               if Cutoff < Limit then
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

end Adaflight.PID_Filters;
