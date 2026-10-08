with Adaflight.PWL;

package body Adaflight.PID_Controller with SPARK_Mode is

   function Saturate (X : Float) return Signal is
     (Constrain_F (X, -Signal_Bound, Signal_Bound));

   type Term_Kind is (Term_P, Term_D);

   function TPA_Factor_Of (S : State; Mode : TPA_Mode; Term : Term_Kind) return Float
     with Post => TPA_Factor_Of'Result in Signal
   is
   begin
      case Term is
         when Term_P => return (if Mode = PD then S.TPA_Factor else 1.0);
         when Term_D => return S.TPA_Factor;
      end case;
   end TPA_Factor_Of;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; P : Profile; R : Runtime) is
   begin
      S := (others => <>);
      PID_Filters.Init (S.Filters, P, R);
   end Init;

   procedure Set_Stabilisation (S : in out State; Enabled : Boolean) is
   begin
      S.Stabilisation_Enabled := Enabled;
   end Set_Stabilisation;

   function Apply_Thrust_Linearization (R : Runtime; Motor : Motor_Command) return Float is
      E      : constant Float := R.Thrust_Linearization;
      Inv    : constant Float := 1.0 - Motor;
      Scaled : constant Float := E * Inv;
      Inner  : constant Float := 1.0 + E * (Inv - Motor);
   begin
      pragma Assert (Inv in -511.0 .. 513.0 and then Scaled in -770.0 .. 770.0 and then Inner in -1600.0 .. 1600.0);
      return Motor * (1.0 + Scaled * Inner);
   end Apply_Thrust_Linearization;

   function Compensate_Thrust_Linearization (R : Runtime; Throttle : Unit_Interval) return Float is
      E : constant Float := R.Thrust_Linearization;
   begin
      if E /= 0.0 then
         return Throttle * (1.0 - E * (1.0 - Throttle));
      else
         return Throttle;
      end if;
   end Compensate_Thrust_Linearization;

   ---------------------------
   -- Update_Throttle_Terms --
   ---------------------------

   procedure Update_Throttle_Terms (S : in out State; R : Runtime; Throttle : Unit_Interval) is
      Throttle_Inv : constant Unit_Interval := 1.0 - Throttle;
      Derivative   : Float := abs (Throttle - S.Previous_Throttle) * R.PID_Frequency;
      Filtered     : Signal;
      TPA_Rate     : Float;
   begin
      pragma Assert (Derivative in 0.0 .. 1.0e6);
      Derivative := Derivative * (Throttle_Inv * Throttle_Inv);
      if Throttle > S.Previous_Throttle then
         Derivative := Derivative * (Throttle_Inv * 0.5);
      end if;
      S.Previous_Throttle := Throttle;
      PT2_Apply (S.Filters.Anti_Gravity, Derivative, Filtered);
      S.Anti_Gravity_Throttle_D := Constrain_F (Filtered, 0.0, Throttle_D_Bound);
      if R.TPA_Curve_Type = Hyperbolic then
         S.TPA_Factor := Saturate (PWL.Interpolate (R.TPA_Curve, Throttle));
         return;
      end if;
      if Throttle >= R.TPA_Low_Breakpoint or else R.TPA_Low_Breakpoint <= 0.01
        or else S.TPA_Low_Faded
      then
         TPA_Rate := R.TPA_Multiplier * Float'Max (Throttle - R.TPA_Breakpoint, 0.0);
         if not R.TPA_Low_Always and then not S.TPA_Low_Faded then
            S.TPA_Low_Faded := True;
         end if;
      else
         TPA_Rate := R.TPA_Low_Multiplier * (R.TPA_Low_Breakpoint - Throttle);
      end if;
      pragma Assert (TPA_Rate in -1001.0 .. 1001.0);
      S.TPA_Factor := 1.0 - TPA_Rate;
   end Update_Throttle_Terms;

   --  Limits the setpoint change per loop to the configured velocity.
   procedure Acceleration_Limit (S : in out State; A : Axis; R : Runtime; Setpoint : in out Rate)
     with Pre => R.Max_Velocity (A) in 0.0 .. 5000.0
   is
      Velocity : constant Float := Setpoint - S.Previous_Setpoint (A);
   begin
      if abs Velocity > R.Max_Velocity (A) then
         Setpoint := Constrain_F
           ((if Velocity > 0.0 then S.Previous_Setpoint (A) + R.Max_Velocity (A)
             else S.Previous_Setpoint (A) - R.Max_Velocity (A)),
            -Rate_Bound, Rate_Bound);
      end if;
      S.Previous_Setpoint (A) := Setpoint;
   end Acceleration_Limit;

   subtype Small_Angle is Float range -15.0 .. 15.0;
   type Angle_Vector is array (Axis) of Small_Angle;
   type Iterm_Vector is array (Axis) of Float;

   --  One pass of the small-angle rotation about axis I, which grows the
   --  other two components by at most the rotation angle times their size.
   procedure Rotate_Pass (V : in out Iterm_Vector; Rotation : Angle_Vector; I : Axis; Bound : Float)
     with Pre  => Bound in 1.0 .. Iterm_Bound * 289.0
            and then (for all A in Axis => abs V (A) <= Bound),
          Post => (for all A in Axis => abs V (A) <= Bound * 17.0)
   is
      I1    : constant Axis := Axis'Val ((Axis'Pos (I) + 1) mod 3);
      I2    : constant Axis := Axis'Val ((Axis'Pos (I) + 2) mod 3);
      New_V : constant Float := V (I1) + V (I2) * Rotation (I);
   begin
      V (I2) := V (I2) - V (I1) * Rotation (I);
      V (I1) := New_V;
   end Rotate_Pass;

   --  Rotates the I terms by the angle the gyro turned through this loop.
   procedure Rotate_Iterm (S : in out State; R : Runtime; Gyro : Axis_Rates)
     with Post => (for all A in Axis => abs S.Data (A).I <= Iterm_Bound)
   is
      Gyro_To_Angle : constant Float := R.Dt * Rad_Per_Degree;
      Rotation : Angle_Vector;
      V        : Iterm_Vector;
   begin
      pragma Assert (Gyro_To_Angle in 0.0 .. 0.0018);
      for A in Axis loop
         Rotation (A) := Gyro (A) * Gyro_To_Angle;
      end loop;
      for A in Axis loop
         V (A) := S.Data (A).I;
      end loop;
      Rotate_Pass (V, Rotation, Roll, Iterm_Bound);
      Rotate_Pass (V, Rotation, Pitch, Iterm_Bound * 17.0);
      Rotate_Pass (V, Rotation, Yaw, Iterm_Bound * 289.0);
      for A in Axis loop
         S.Data (A).I := Constrain_F (V (A), -Iterm_Bound, Iterm_Bound);
      end loop;
   end Rotate_Iterm;

   --  Attenuates the I term error while the setpoint moves fast.
   procedure Apply_Iterm_Relax
     (S : in out State; A : Axis; R : Runtime; Previous_Iterm : Iterm; Gyro_Rate : Rate;
      Iterm_Error_Rate : in out Signal; Current_Setpoint : Rate)
   is
      Setpoint_Lpf : Signal;
      Setpoint_Hpf : Deadband_Width_F;
   begin
      PT1_Apply (S.Filters.Windup (A), Current_Setpoint, Setpoint_Lpf);
      Setpoint_Hpf := Constrain_F (abs (Current_Setpoint - Setpoint_Lpf), 0.0, Signal_Bound);
      if R.Iterm_Relax /= Off then
         if A /= Yaw or else R.Iterm_Relax in RPY | RPY_Inc then
            declare
               Factor : constant Unit_Interval :=
                 Float'Max (0.0, 1.0 - Setpoint_Hpf / Iterm_Relax_Setpoint_Threshold);
               Decreasing : constant Boolean :=
                 (Previous_Iterm > 0.0 and then Iterm_Error_Rate < 0.0)
                 or else (Previous_Iterm < 0.0 and then Iterm_Error_Rate > 0.0);
            begin
               if R.Iterm_Relax in RP_Inc | RPY_Inc and then Decreasing then
                  null;
               elsif R.Iterm_Relax_Type = Setpoint then
                  Iterm_Error_Rate := Iterm_Error_Rate * Factor;
               else
                  Iterm_Error_Rate :=
                    Apply_Deadband_F (Saturate (Setpoint_Lpf - Gyro_Rate), Setpoint_Hpf);
               end if;
            end;
         end if;
      end if;
   end Apply_Iterm_Relax;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out State; R : Runtime; P : Profile; Inp : Inputs) is
      Gyro_Dterm : Axis_Signals;
   begin
      if Inp.Anti_Gravity_Enabled then
         S.Anti_Gravity_Throttle_D := Constrain_F
           (S.Anti_Gravity_Throttle_D * Float (R.Anti_Gravity_Gain), 0.0, Throttle_D_Bound * 251.0);
         S.Iterm_Accelerator := S.Anti_Gravity_Throttle_D * Anti_Gravity_KI;
      else
         S.Anti_Gravity_Throttle_D := 0.0;
         S.Iterm_Accelerator := 0.0;
      end if;
      for A in Axis loop
         PID_Filters.Apply_Dterm (S.Filters, A, Inp.Gyro (A), Gyro_Dterm (A));
      end loop;
      if R.Iterm_Rotation then
         Rotate_Iterm (S, R, Inp.Gyro);
      end if;
      for A in Axis loop
         declare
            Setpoint       : Rate := Inp.Setpoint (A);
            Gyro_Rate      : constant Rate := Inp.Gyro (A);
            Previous_Iterm : constant Iterm := S.Data (A).I;
            Error_Rate     : Float;
            Iterm_Error    : Signal;
            Ki             : Float;
            Iterm_Limit    : Float;
            Iterm_Change   : Float;
            Setpoint_Delta : constant Rate := Inp.Feedforward (A);
            Term           : Float;
         begin
            if R.Max_Velocity (A) /= 0.0 then
               Acceleration_Limit (S, A, R, Setpoint);
            end if;
            Error_Rate := Setpoint - Gyro_Rate;
            Iterm_Error := Error_Rate;
            Apply_Iterm_Relax (S, A, R, Previous_Iterm, Gyro_Rate, Iterm_Error, Setpoint);
            Error_Rate := Setpoint - Gyro_Rate;
            Term := R.Coefficient (A).Kp * Error_Rate;
            S.Data (A).P := Saturate (Term * TPA_Factor_Of (S, P.TPA_Terms, Term_P));
            if A = Yaw then
               declare
                  Filtered : Signal;
               begin
                  PID_Filters.Apply_Yaw_P (S.Filters, S.Data (A).P, Filtered);
                  S.Data (A).P := Filtered;
               end;
            end if;
            Ki := R.Coefficient (A).Ki;
            Iterm_Limit := R.Iterm_Limit;
            if A = Yaw then
               Iterm_Limit := R.Iterm_Limit_Yaw;
               S.Iterm_Accelerator := 0.0;
            end if;
            Iterm_Change := (Ki + S.Iterm_Accelerator) * R.Dt;
            Iterm_Change := Iterm_Change * Iterm_Error;
            S.Data (A).I := Constrain_F (Previous_Iterm + Iterm_Change, -Iterm_Limit, Iterm_Limit);
            S.Previous_PID_Setpoint (A) := Setpoint;
            if R.Coefficient (A).Kd > 0.0 then
               declare
                  Gyro_Delta : constant Signal :=
                    Saturate ((-(Gyro_Dterm (A) - S.Previous_Gyro_Dterm (A))) * R.PID_Frequency);
                  Pre_TPA_D  : Float := R.Coefficient (A).Kd * Gyro_Delta;
                  Multiplier : Float := 1.0;
                  Range_Out  : Signal;
                  Smoothed   : Signal;
               begin
                  if R.D_Max_Percent (A) > 1.0 then
                     PT2_Apply (S.Filters.D_Max_Range (A), Gyro_Delta, Range_Out);
                     declare
                        Gyro_Factor     : constant Float := abs Range_Out * R.D_Max_Gyro_Gain;
                        Setpoint_Factor : constant Float := abs Setpoint_Delta * R.D_Max_Setpoint_Gain;
                        Boost           : constant Float := Float'Max (Gyro_Factor, Setpoint_Factor);
                     begin
                        Multiplier := Multiplier + (R.D_Max_Percent (A) - 1.0) * Boost;
                        PT2_Apply (S.Filters.D_Max_Lowpass (A), Saturate (Multiplier), Smoothed);
                        Multiplier := Float'Min (Smoothed, R.D_Max_Percent (A));
                     end;
                  end if;
                  Pre_TPA_D := Pre_TPA_D * Multiplier;
                  S.Data (A).D := Saturate (Pre_TPA_D * TPA_Factor_Of (S, P.TPA_Terms, Term_D));
               end;
            else
               S.Data (A).D := 0.0;
            end if;
            S.Previous_Gyro_Dterm (A) := Gyro_Dterm (A);
            S.Data (A).F := R.Coefficient (A).Kf * Setpoint_Delta;
            if A /= Yaw then
               declare
                  Attenuator : constant Float := Float'Max (abs Setpoint / 50.0, 1.0);
                  Boost      : constant Float :=
                    1.0 + (S.Anti_Gravity_Throttle_D / Attenuator) * R.Anti_Gravity_P_Gain;
               begin
                  S.Data (A).P := Saturate (S.Data (A).P * Boost);
               end;
            end if;
            S.Data (A).Sum :=
              Saturate (S.Data (A).P + S.Data (A).I + S.Data (A).D + S.Data (A).F);
         end;
      end loop;
      if not S.Stabilisation_Enabled then
         for A in Axis loop
            S.Data (A) := (others => 0.0);
         end loop;
      elsif Inp.Zero_Throttle_Iterm_Reset then
         for A in Axis loop
            S.Data (A).I := 0.0;
         end loop;
      end if;
   end Update;

end Adaflight.PID_Controller;
