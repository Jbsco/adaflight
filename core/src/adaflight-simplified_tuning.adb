with Adaflight.Axes; use Adaflight.Axes;

package body Adaflight.Simplified_Tuning with SPARK_Mode is
   use Adaflight.PID_Profile;

   Defaults : constant Axis_Gain_Set :=
     (Roll  => (P => 45, I => 80, D => 30, F => 120, S => 0),
      Pitch => (P => 47, I => 84, D => 34, F => 125, S => 0),
      Yaw   => (P => 45, I => 80, D => 0, F => 120, S => 0));

   D_Max_Defaults : constant Axis_Gain_Values := (Roll => 40, Pitch => 46, Yaw => 0);

   subtype Factor is Float range 0.0 .. 2.0;
   subtype Product is Float range -1.0e6 .. 1.0e6;
   subtype Share is Float range -256.0 .. 256.0;

   function Hundredths (V : Tuning_Factor) return Factor is (Float (V) / 100.0);

   --  The D max slider's share, with the rest at the ratio of the D default
   --  to the D max default.
   function D_Max_Share (Slider : Factor; D_Default : Gain; D_Max_Default : Positive) return Share is
      Rest   : constant Float range -1.0 .. 1.0 := 1.0 - Slider;
      Scaled : constant Float range -250.0 .. 250.0 := Rest * Float (D_Default);
   begin
      return Slider + Scaled / Float (D_Max_Default);
   end D_Max_Share;

   --  The whole part of a product, held to a gain's range.
   function Whole (V : Product; High : Positive) return Natural is
     (Integer'Min (Integer'Max (Integer (Float'Truncation (V)), 0), High))
     with Post => Whole'Result <= High;

   ----------------
   -- Apply_PIDs --
   ----------------

   procedure Apply_PIDs (P : in out PID_Profile.Profile) is
      Master  : constant Factor := Hundredths (P.Simplified_Master_Multiplier);
      PI_Gain : constant Factor := Hundredths (P.Simplified_PI_Gain);
      D_Gain  : constant Factor := Hundredths (P.Simplified_D_Gain);
      FF_Gain : constant Factor := Hundredths (P.Simplified_Feedforward_Gain);
      I_Gain  : constant Factor := Hundredths (P.Simplified_I_Gain);
      D_Max_Slider : constant Factor := Hundredths (P.Simplified_D_Max_Gain);
      Last    : constant Axis := (if P.Simplified_PIDs_Mode = RP then Pitch else Yaw);
   begin
      if P.Simplified_PIDs_Mode = Off then
         return;
      end if;
      for A in Roll .. Last loop
         declare
            Pitch_D_Gain  : constant Factor :=
              (if A = Pitch then Hundredths (P.Simplified_Roll_Pitch_Ratio) else 1.0);
            Pitch_PI_Gain : constant Factor :=
              (if A = Pitch then Hundredths (P.Simplified_Pitch_PI_Gain) else 1.0);
            P_Value : constant Product := Float (Defaults (A).P) * Master * PI_Gain * Pitch_PI_Gain;
            I_Value : constant Product :=
              Float (Defaults (A).I) * Master * PI_Gain * I_Gain * Pitch_PI_Gain;
            D_Value : constant Product := Float (Defaults (A).D) * Master * D_Gain * Pitch_D_Gain;
            F_Value : constant Product := Float (Defaults (A).F) * Master * Pitch_PI_Gain * FF_Gain;
            D_Max_Gain : constant Share :=
              (if D_Max_Defaults (A) > 0
               then D_Max_Share (D_Max_Slider, Defaults (A).D, D_Max_Defaults (A))
               else 1.0);
            D_Max_Value : constant Product :=
              Float (D_Max_Defaults (A)) * Master * D_Gain * Pitch_D_Gain * D_Max_Gain;
         begin
            P.Gains (A).P := Whole (P_Value, Gain_Max);
            P.Gains (A).I := Whole (I_Value, Gain_Max);
            P.Gains (A).D := Whole (D_Value, Gain_Max);
            P.Gains (A).F := Whole (F_Value, F_Gain_Max);
            P.D_Max (A) := Whole (D_Max_Value, Gain_Max);
         end;
      end loop;
   end Apply_PIDs;

end Adaflight.Simplified_Tuning;
