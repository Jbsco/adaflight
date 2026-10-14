with Adaflight.Axes; use Adaflight.Axes;

package body Adaflight.Simplified_Tuning with SPARK_Mode is
   use Adaflight.PID_Profile;

   Defaults : constant Axis_Gain_Set :=
     (Roll  => (P => 45, I => 80, D => 30, F => 120, S => 0),
      Pitch => (P => 47, I => 84, D => 34, F => 125, S => 0),
      Yaw   => (P => 45, I => 80, D => 0, F => 120, S => 0));

   D_Max_Defaults : constant Axis_Gain_Values := (Roll => 40, Pitch => 46, Yaw => 0);

   subtype Product is Float range -1.0e7 .. 1.0e7;
   subtype Share is Float range -512.0 .. 512.0;

   --  The D max slider's share, with the rest at the ratio of the D default
   --  to the D max default.
   function D_Max_Share (Slider : Factor; D_Default : Gain; D_Max_Default : Positive) return Share is
      Rest   : constant Float range -2.0 .. 1.0 := 1.0 - Slider;
      Scaled : constant Float range -500.0 .. 500.0 := Rest * Float (D_Default);
   begin
      return Slider + Scaled / Float (D_Max_Default);
   end D_Max_Share;

   --  The whole part of a product, held to a gain's range.
   function Whole (V : Product; High : Positive) return Natural is
     (Integer'Min (Integer'Max (Integer (Float'Truncation (V)), 0), High))
     with Post => Whole'Result <= High;

   -----------
   -- Tuned --
   -----------

   function Tuned (S : Sliders; A : Axis) return Tuned_Gains is
      P_Value : constant Product := Float (Defaults (A).P) * S.Master * S.PI_Gain * S.Pitch_PI_Gain;
      I_Value : constant Product := Float (Defaults (A).I) * S.Master * S.PI_Gain * S.I_Gain * S.Pitch_PI_Gain;
      D_Value : constant Product := Float (Defaults (A).D) * S.Master * S.D_Gain * S.Pitch_D_Gain;
      F_Value : constant Product := Float (Defaults (A).F) * S.Master * S.Pitch_PI_Gain * S.FF_Gain;
      D_Max_Gain : constant Share :=
        (if D_Max_Defaults (A) > 0
         then D_Max_Share (S.D_Max_Slider, Defaults (A).D, D_Max_Defaults (A))
         else 1.0);
      D_Max_Value : constant Product :=
        Float (D_Max_Defaults (A)) * S.Master * S.D_Gain * S.Pitch_D_Gain * D_Max_Gain;
   begin
      return (P     => Whole (P_Value, Gain_Max),
              I     => Whole (I_Value, Gain_Max),
              D     => Whole (D_Value, Gain_Max),
              F     => Whole (F_Value, F_Gain_Max),
              D_Max => Whole (D_Max_Value, Gain_Max));
   end Tuned;

   ----------------
   -- Apply_PIDs --
   ----------------

   procedure Apply_PIDs (P : in out PID_Profile.Profile) is
      Last : constant Axis := (if P.Simplified_PIDs_Mode = RP then Pitch else Yaw);
   begin
      if P.Simplified_PIDs_Mode = Off then
         return;
      end if;
      for A in Roll .. Last loop
         declare
            T : constant Tuned_Gains :=
              Tuned ((Master        => Hundredths (P.Simplified_Master_Multiplier),
                      PI_Gain       => Hundredths (P.Simplified_PI_Gain),
                      D_Gain        => Hundredths (P.Simplified_D_Gain),
                      FF_Gain       => Hundredths (P.Simplified_Feedforward_Gain),
                      I_Gain        => Hundredths (P.Simplified_I_Gain),
                      D_Max_Slider  => Hundredths (P.Simplified_D_Max_Gain),
                      Pitch_D_Gain  => (if A = Pitch then Hundredths (P.Simplified_Roll_Pitch_Ratio) else 1.0),
                      Pitch_PI_Gain => (if A = Pitch then Hundredths (P.Simplified_Pitch_PI_Gain) else 1.0)),
                     A);
         begin
            P.Gains (A).P := T.P;
            P.Gains (A).I := T.I;
            P.Gains (A).D := T.D;
            P.Gains (A).F := T.F;
            P.D_Max (A) := T.D_Max;
         end;
      end loop;
   end Apply_PIDs;

   -------------------------
   -- Apply_Dterm_Filters --
   -------------------------

   procedure Apply_Dterm_Filters (P : in out PID_Profile.Profile) is
      M : constant Natural := P.Simplified_Dterm_Filter_Multiplier;
   begin
      if not P.Simplified_Dterm_Filter then
         return;
      end if;
      if P.Dterm_LPF1_Dyn_Min_Hz /= 0 then
         declare
            New_Min : constant PID_Profile.Hertz := Scaled (75, M, Dyn_LPF_Max_Hz);
            New_Max : constant PID_Profile.Hertz := Scaled (150, M, Dyn_LPF_Max_Hz);
         begin
            if P.Dterm_LPF1_Dyn_Min_Hz <= New_Max then
               P.Dterm_LPF1_Dyn_Max_Hz := New_Max;
               P.Dterm_LPF1_Dyn_Min_Hz := New_Min;
            else
               P.Dterm_LPF1_Dyn_Min_Hz := New_Min;
               P.Dterm_LPF1_Dyn_Max_Hz := New_Max;
            end if;
         end;
      end if;
      if P.Dterm_LPF1_Static_Hz /= 0 then
         P.Dterm_LPF1_Static_Hz := Scaled (75, M, Dyn_LPF_Max_Hz);
      end if;
      if P.Dterm_LPF2_Static_Hz /= 0 then
         P.Dterm_LPF2_Static_Hz := Scaled (150, M, LPF_Max_Hz);
      end if;
   end Apply_Dterm_Filters;

   ------------------------
   -- Apply_Gyro_Filters --
   ------------------------

   procedure Apply_Gyro_Filters (G : in out Gyro_Filters.Settings) is
      M : constant Natural := G.Simplified_Filter_Multiplier;
   begin
      if not G.Simplified_Filter then
         return;
      end if;
      if G.LPF1_Dyn_Min_Hz /= 0 then
         declare
            New_Min : constant PID_Profile.Hertz := Scaled (250, M, Dyn_LPF_Max_Hz);
            New_Max : constant PID_Profile.Hertz := Scaled (500, M, Dyn_LPF_Max_Hz);
         begin
            if G.LPF1_Dyn_Min_Hz <= New_Max then
               G.LPF1_Dyn_Max_Hz := New_Max;
               G.LPF1_Dyn_Min_Hz := New_Min;
            else
               G.LPF1_Dyn_Min_Hz := New_Min;
               G.LPF1_Dyn_Max_Hz := New_Max;
            end if;
         end;
      end if;
      if G.LPF1_Static_Hz /= 0 then
         G.LPF1_Static_Hz := Scaled (250, M, Dyn_LPF_Max_Hz);
      end if;
      if G.LPF2_Static_Hz /= 0 then
         G.LPF2_Static_Hz := Scaled (500, M, LPF_Max_Hz);
      end if;
   end Apply_Gyro_Filters;

   -----------
   -- Apply --
   -----------

   procedure Apply (P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings) is
   begin
      Apply_PIDs (P);
      Apply_Dterm_Filters (P);
      Apply_Gyro_Filters (G);
   end Apply;

   -------------
   -- Disable --
   -------------

   procedure Disable (P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings) is
   begin
      P.Simplified_PIDs_Mode := Off;
      P.Simplified_Dterm_Filter := False;
      G.Simplified_Filter := False;
   end Disable;

end Adaflight.Simplified_Tuning;
