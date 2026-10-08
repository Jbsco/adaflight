package body Adaflight.Filters with SPARK_Mode is

   Two_Pi : constant Float := 2.0 * Pi;

   --  Cutoff correction for an n-stage PT filter: 1 / sqrt (2 ** (1 / n) - 1).
   Cutoff_Correction_PT2 : constant Float := 1.553773974;
   Cutoff_Correction_PT3 : constant Float := 1.961459177;

   subtype Omega is Float range 0.0 .. 2.0 ** 60;

   function Gain_From_Omega (W : Omega) return Unit_Interval is
     (Float'Min (1.0, W / (W + 1.0)))
     with Inline;

   function Gain_From_Delay (Scaled_Delay : Delay_Seconds; Dt : Period) return Unit_Interval is
     (if Scaled_Delay <= 0.0 then 1.0 else Float'Min (1.0, Dt / (Dt + Scaled_Delay)))
     with Inline;

   procedure Saturate (V : in out Float)
     with Inline, Post => V in Signal
   is
   begin
      V := Constrain_F (V, -Signal_Bound, Signal_Bound);
   end Saturate;

   --------------
   -- PT1_Gain --
   --------------

   function PT1_Gain (Cutoff : Frequency; Dt : Period) return Unit_Interval is
     (Gain_From_Omega (Two_Pi * Cutoff * Dt));

   -------------------------
   -- PT1_Gain_From_Delay --
   -------------------------

   function PT1_Gain_From_Delay (Delay_S : Delay_Seconds; Dt : Period) return Unit_Interval is
     (Gain_From_Delay (Delay_S, Dt));

   --------------
   -- PT1_Init --
   --------------

   procedure PT1_Init (F : out PT1; K : Unit_Interval) is
   begin
      F := (State => 0.0, K => K);
   end PT1_Init;

   -----------------------
   -- PT1_Update_Cutoff --
   -----------------------

   procedure PT1_Update_Cutoff (F : in out PT1; K : Unit_Interval) is
   begin
      F.K := K;
   end PT1_Update_Cutoff;

   ---------------
   -- PT1_Apply --
   ---------------

   procedure PT1_Apply (F : in out PT1; Input : Signal; Output : out Signal) is
   begin
      F.State := Lerp (F.State, Input, F.K);
      Output := F.State;
   end PT1_Apply;

   --------------
   -- PT2_Gain --
   --------------

   function PT2_Gain (Cutoff : Frequency; Dt : Period) return Unit_Interval is
     (Gain_From_Omega (Two_Pi * (Cutoff * Cutoff_Correction_PT2) * Dt));

   -------------------------
   -- PT2_Gain_From_Delay --
   -------------------------

   function PT2_Gain_From_Delay (Delay_S : Delay_Seconds; Dt : Period) return Unit_Interval is
   begin
      if Delay_S <= 0.0 then
         return 1.0;
      else
         return Float'Min (1.0, Dt / (Dt + Delay_S * Cutoff_Correction_PT2));
      end if;
   end PT2_Gain_From_Delay;

   --------------
   -- PT2_Init --
   --------------

   procedure PT2_Init (F : out PT2; K : Unit_Interval) is
   begin
      F := (State => 0.0, State1 => 0.0, K => K);
   end PT2_Init;

   -----------------------
   -- PT2_Update_Cutoff --
   -----------------------

   procedure PT2_Update_Cutoff (F : in out PT2; K : Unit_Interval) is
   begin
      F.K := K;
   end PT2_Update_Cutoff;

   ---------------
   -- PT2_Apply --
   ---------------

   procedure PT2_Apply (F : in out PT2; Input : Signal; Output : out Signal) is
   begin
      F.State1 := Lerp (F.State1, Input, F.K);
      F.State := Lerp (F.State, F.State1, F.K);
      Output := F.State;
   end PT2_Apply;

   --------------
   -- PT3_Gain --
   --------------

   function PT3_Gain (Cutoff : Frequency; Dt : Period) return Unit_Interval is
     (Gain_From_Omega (Two_Pi * (Cutoff * Cutoff_Correction_PT3) * Dt));

   -------------------------
   -- PT3_Gain_From_Delay --
   -------------------------

   function PT3_Gain_From_Delay (Delay_S : Delay_Seconds; Dt : Period) return Unit_Interval is
   begin
      if Delay_S <= 0.0 then
         return 1.0;
      else
         return Float'Min (1.0, Dt / (Dt + Delay_S * Cutoff_Correction_PT3));
      end if;
   end PT3_Gain_From_Delay;

   --------------
   -- PT3_Init --
   --------------

   procedure PT3_Init (F : out PT3; K : Unit_Interval) is
   begin
      F := (State => 0.0, State1 => 0.0, State2 => 0.0, K => K);
   end PT3_Init;

   -----------------------
   -- PT3_Update_Cutoff --
   -----------------------

   procedure PT3_Update_Cutoff (F : in out PT3; K : Unit_Interval) is
   begin
      F.K := K;
   end PT3_Update_Cutoff;

   ---------------
   -- PT3_Apply --
   ---------------

   procedure PT3_Apply (F : in out PT3; Input : Signal; Output : out Signal) is
   begin
      F.State1 := Lerp (F.State1, Input, F.K);
      F.State2 := Lerp (F.State2, F.State1, F.K);
      F.State := Lerp (F.State, F.State2, F.K);
      Output := F.State;
   end PT3_Apply;

   -------------
   -- Notch_Q --
   -------------

   function Notch_Q (Center : Frequency; Cutoff : Frequency) return Quality is
      Denominator : constant Float := Float'Max (1.0, Center * Center - Cutoff * Cutoff);
   begin
      return Constrain_F (Center * Cutoff / Denominator, Quality'First, Quality'Last);
   end Notch_Q;

   ------------------------
   -- SVF_Lowpass_Update --
   ------------------------

   procedure SVF_Lowpass_Update
     (Filt : in out SVF_Lowpass; Cutoff : Frequency; Dt : Period)
   is
      Inv_Butterworth_Q : constant Float := 1.41421356237;
      F         : constant Warped_Frequency := Tan_Approx (Constrain_F (Pi * Cutoff * Dt, 0.0, Max_Tan_Argument));
      Inv_Denom : constant Float := 1.0 / (1.0 + F * (F + Inv_Butterworth_Q));
   begin
      Filt.A1 := Inv_Denom;
      Filt.A2 := F * Inv_Denom;
      Filt.F := F;
   end SVF_Lowpass_Update;

   ----------------------
   -- SVF_Lowpass_Init --
   ----------------------

   procedure SVF_Lowpass_Init
     (Filt : out SVF_Lowpass; Cutoff : Frequency; Dt : Period)
   is
   begin
      Filt := (others => <>);
      SVF_Lowpass_Update (Filt, Cutoff, Dt);
   end SVF_Lowpass_Init;

   -----------------------
   -- SVF_Lowpass_Apply --
   -----------------------

   procedure SVF_Lowpass_Apply
     (Filt : in out SVF_Lowpass; Input : Signal; Output : out Signal)
   is
      V3 : constant Float := Input - Filt.IC2;
      V1 : constant Float := Filt.A1 * Filt.IC1 + Filt.A2 * V3;
      V2 : constant Float := Filt.IC2 + Filt.F * V1;
      N1 : Float := 2.0 * V1 - Filt.IC1;
      N2 : Float := 2.0 * V2 - Filt.IC2;
      O  : Float := V2;
   begin
      Saturate (N1);
      Saturate (N2);
      Saturate (O);
      Filt.IC1 := N1;
      Filt.IC2 := N2;
      Output := O;
   end SVF_Lowpass_Apply;

   ----------------------
   -- SVF_Notch_Update --
   ----------------------

   procedure SVF_Notch_Update
     (Filt : in out SVF_Notch; Center : Frequency; Dt : Period; Q : Quality)
   is
      F         : constant Warped_Frequency := Tan_Approx (Constrain_F (Pi * Center * Dt, 0.0, Max_Tan_Argument));
      Inv_Q     : constant Float := 1.0 / Q;
      Inv_Denom : constant Float := 1.0 / (1.0 + F * (F + Inv_Q));
   begin
      Filt.A1 := Inv_Denom;
      Filt.A2Q := (F * Inv_Denom) * Inv_Q;
      Filt.FQ := F * Q;
   end SVF_Notch_Update;

   --------------------
   -- SVF_Notch_Init --
   --------------------

   procedure SVF_Notch_Init
     (Filt : out SVF_Notch; Center : Frequency; Dt : Period; Q : Quality)
   is
   begin
      Filt := (others => <>);
      SVF_Notch_Update (Filt, Center, Dt, Q);
   end SVF_Notch_Init;

   ---------------------
   -- SVF_Notch_Apply --
   ---------------------

   procedure SVF_Notch_Apply
     (Filt : in out SVF_Notch; Input : Signal; Output : out Signal)
   is
      V3  : constant Float := Input - Filt.IC2;
      V1Q : constant Float := Filt.A1 * Filt.IC1Q + Filt.A2Q * V3;
      V2  : constant Float := Filt.IC2 + Filt.FQ * V1Q;
      N1  : Float := 2.0 * V1Q - Filt.IC1Q;
      N2  : Float := 2.0 * V2 - Filt.IC2;
      O   : Float := Input - V1Q;
   begin
      Saturate (N1);
      Saturate (N2);
      Saturate (O);
      Filt.IC1Q := N1;
      Filt.IC2 := N2;
      Output := O;
   end SVF_Notch_Apply;

   ---------------------------
   -- Weighted_Notch_Update --
   ---------------------------

   procedure Weighted_Notch_Update
     (Filt : in out Weighted_Notch; Center : Frequency; Dt : Period;
      Q : Quality; Weight : Unit_Interval)
   is
      F     : constant Warped_Frequency := Tan_Approx (Constrain_F (Pi * Center * Dt, 0.0, Max_Tan_Argument));
      Inv_Q : constant Float := 1.0 / Q;
      A1    : constant Float := 1.0 / (1.0 + F * (F + Inv_Q));
   begin
      Filt.F := F;
      Filt.A1 := A1;
      Filt.A2 := F * A1;
      Filt.WQ := Inv_Q * Weight;
   end Weighted_Notch_Update;

   -------------------------
   -- Weighted_Notch_Init --
   -------------------------

   procedure Weighted_Notch_Init
     (Filt : out Weighted_Notch; Center : Frequency; Dt : Period;
      Q : Quality; Weight : Unit_Interval)
   is
   begin
      Filt := (others => <>);
      Weighted_Notch_Update (Filt, Center, Dt, Q, Weight);
   end Weighted_Notch_Init;

   --------------------------
   -- Weighted_Notch_Apply --
   --------------------------

   procedure Weighted_Notch_Apply (Filt : in out Weighted_Notch; Values : in out Axis_Signals) is
   begin
      for A in Axis loop
         declare
            V3 : constant Float := Values (A) - Filt.IC2 (A);
            V1 : constant Float := Filt.A1 * Filt.IC1 (A) + Filt.A2 * V3;
            V2 : constant Float := Filt.IC2 (A) + Filt.F * V1;
            N1 : Float := 2.0 * V1 - Filt.IC1 (A);
            N2 : Float := 2.0 * V2 - Filt.IC2 (A);
            O  : Float := Values (A) - Filt.WQ * V1;
         begin
            Saturate (N1);
            Saturate (N2);
            Saturate (O);
            Filt.IC1 (A) := N1;
            Filt.IC2 (A) := N2;
            Values (A) := O;
         end;
      end loop;
   end Weighted_Notch_Apply;

   -----------------------
   -- Phase_Comp_Update --
   -----------------------

   procedure Phase_Comp_Update
     (Filt : in out Phase_Comp; Center : Frequency; Phase : Phase_Degrees;
      Loop_Time : Loop_Time_Us)
   is
      W     : constant Float := Two_Pi * Center * Float (Loop_Time) * 1.0e-6;
      SN    : constant Cosine := Sin_Approx (Phase * Rad_Per_Degree);
      Gain  : constant Float := Float'Max (0.0, 1.0 + SN) / Float'Max (1.0e-4, 1.0 - SN);
      Root  : constant Float := Float'Max (1.0e-3, Sqrt_Bounded (Gain));
      Alpha : constant Float := (12.0 - W * W) / (6.0 * W * Root);
      B0    : constant Float := 1.0 + Alpha * Gain;
      B1    : constant Float := 2.0 - B0;
      A1    : constant Float := 1.0 - Alpha;
      A0    : constant Float := 1.0 / (1.0 + Alpha);
   begin
      Filt.B0 := Constrain_F (B0 * A0, Comp_Coefficient'First, Comp_Coefficient'Last);
      Filt.B1 := Constrain_F (B1 * A0, Comp_Coefficient'First, Comp_Coefficient'Last);
      Filt.A1 := Constrain_F (A1 * A0, Comp_Coefficient'First, Comp_Coefficient'Last);
   end Phase_Comp_Update;

   ---------------------
   -- Phase_Comp_Init --
   ---------------------

   procedure Phase_Comp_Init
     (Filt : out Phase_Comp; Center : Frequency; Phase : Phase_Degrees;
      Loop_Time : Loop_Time_Us)
   is
   begin
      Filt := (others => <>);
      Phase_Comp_Update (Filt, Center, Phase, Loop_Time);
   end Phase_Comp_Init;

   ----------------------
   -- Phase_Comp_Apply --
   ----------------------

   procedure Phase_Comp_Apply (Filt : in out Phase_Comp; Input : Signal; Output : out Signal) is
      Result : Float := Filt.B0 * Input + Filt.B1 * Filt.X1 - Filt.A1 * Filt.Y1;
   begin
      Saturate (Result);
      Filt.X1 := Input;
      Filt.Y1 := Result;
      Output := Result;
   end Phase_Comp_Apply;

   ----------------------
   -- Phase_Comp_Reset --
   ----------------------

   procedure Phase_Comp_Reset (Filt : in out Phase_Comp) is
   begin
      Filt.X1 := 0.0;
      Filt.Y1 := 0.0;
   end Phase_Comp_Reset;

   ---------------
   -- Slew_Init --
   ---------------

   procedure Slew_Init (Filt : out Slew_Filter; Slew_Limit : Slew_Bound; Threshold : Slew_Bound) is
   begin
      Filt := (State => 0.0, Slew_Limit => Slew_Limit, Threshold => Threshold);
   end Slew_Init;

   ----------------
   -- Slew_Apply --
   ----------------

   procedure Slew_Apply (Filt : in out Slew_Filter; Input : Signal; Output : out Signal) is
   begin
      if Filt.State >= Filt.Threshold then
         if Input >= Filt.State - Filt.Slew_Limit then
            Filt.State := Input;
         end if;
      elsif Filt.State <= -Filt.Threshold then
         if Input <= Filt.State + Filt.Slew_Limit then
            Filt.State := Input;
         end if;
      else
         Filt.State := Input;
      end if;
      Output := Filt.State;
   end Slew_Apply;

   -------------------------
   -- Moving_Average_Init --
   -------------------------

   procedure Moving_Average_Init (Filt : out Moving_Average; Size : Window_Size) is
   begin
      Filt := (Index => 0, Size => Size, Buffer => (others => 0.0), Primed => False);
   end Moving_Average_Init;

   ---------------------------
   -- Moving_Average_Update --
   ---------------------------

   procedure Moving_Average_Update
     (Filt : in out Moving_Average; Input : Signal; Output : out Signal)
   is
      Sum   : Float := 0.0;
      Denom : Window_Size;
   begin
      Filt.Buffer (Filt.Index) := Input;
      if Filt.Index + 1 = Filt.Size then
         Filt.Index := 0;
         Filt.Primed := True;
      else
         Filt.Index := Filt.Index + 1;
      end if;
      Denom := (if Filt.Primed then Filt.Size else Filt.Index);
      for I in 0 .. Denom - 1 loop
         pragma Loop_Invariant (abs Sum <= Float (I) * Signal_Bound);
         Sum := Sum + Filt.Buffer (I);
      end loop;
      Output := Constrain_F (Sum / Float (Denom), -Signal_Bound, Signal_Bound);
   end Moving_Average_Update;

   -------------------------
   -- Simple_Lowpass_Init --
   -------------------------

   procedure Simple_Lowpass_Init
     (Filt : out Simple_Lowpass; Beta : Shift_Amount; FP_Shift : Shift_Amount)
   is
   begin
      Filt := (FP => 0, Beta_Scale => Shift_Scales (Beta), Input_Scale => Shift_Scales (FP_Shift));
   end Simple_Lowpass_Init;

   --  Floor division of a 64-bit value by a positive power of two, matching
   --  an arithmetic shift right.
   function Floor_Div (V : Integer_64; D : Integer_64) return Integer_64 is
     ((V - V mod D) / D)
     with Pre  => D in 1 .. 2 ** 15 and then V in -(2 ** 62) .. 2 ** 62,
          Post => Floor_Div'Result * D <= V and then V < Floor_Div'Result * D + D;

   ---------------------------
   -- Simple_Lowpass_Update --
   ---------------------------

   procedure Simple_Lowpass_Update
     (Filt : in out Simple_Lowpass; Input : Simple_Input; Output : out Simple_Input)
   is
      Bound : constant Integer_64 := 2 ** 15 * Integer_64 (Filt.Input_Scale);
      Wide  : constant Integer_64 :=
        Integer_64 (Filt.FP) * Integer_64 (Filt.Beta_Scale) - Integer_64 (Filt.FP)
        + Integer_64 (Input) * Integer_64 (Filt.Input_Scale);
      Next  : constant Integer_64 := Floor_Div (Wide, Integer_64 (Filt.Beta_Scale));
   begin
      Filt.FP := Integer_32 (Integer_64'Max (-Bound, Integer_64'Min (Bound, Next)));
      Output := Simple_Input (Floor_Div (Integer_64 (Filt.FP), Integer_64 (Filt.Input_Scale)));
   end Simple_Lowpass_Update;

   ---------------
   -- Mean_Init --
   ---------------

   procedure Mean_Init (Acc : out Mean_Accumulator) is
   begin
      Acc := (Sum => 0, Count => 0);
   end Mean_Init;

   --------------
   -- Mean_Add --
   --------------

   procedure Mean_Add (Acc : in out Mean_Accumulator; Value : Integer_8) is
   begin
      Acc := (Sum => Acc.Sum + Integer_32 (Value), Count => Acc.Count + 1);
   end Mean_Add;

   ---------------
   -- Mean_Calc --
   ---------------

   procedure Mean_Calc
     (Acc : in out Mean_Accumulator; Default : Integer_8; Result : out Integer_8)
   is
   begin
      if Acc.Count > 0 then
         Result := Integer_8 (Acc.Sum / Integer_32 (Acc.Count));
      else
         Result := Default;
      end if;
      Acc := (Sum => 0, Count => 0);
   end Mean_Calc;

end Adaflight.Filters;
