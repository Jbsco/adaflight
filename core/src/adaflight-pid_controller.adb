with Adaflight.PWL;
with Adaflight.Clock;

package body Adaflight.PID_Controller with SPARK_Mode is

   use type Interfaces.Unsigned_32;

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
      Iterm_Error_Rate : in out Signal; Current_Setpoint : Rate; Angle_Mode : Boolean)
   is
      Setpoint_Lpf : Signal;
      Setpoint_Hpf : Deadband_Width_F;
      --  Angle mode relaxes at a fifth of the setpoint threshold.
      Threshold    : constant Float range 8.0 .. 40.0 :=
        (if Angle_Mode then Iterm_Relax_Setpoint_Threshold * 0.2 else Iterm_Relax_Setpoint_Threshold);
   begin
      PT1_Apply (S.Filters.Windup (A), Current_Setpoint, Setpoint_Lpf);
      Setpoint_Hpf := Constrain_F (abs (Current_Setpoint - Setpoint_Lpf), 0.0, Signal_Bound);
      if R.Iterm_Relax /= Off then
         if A /= Yaw or else R.Iterm_Relax in RPY | RPY_Inc then
            declare
               Factor : constant Unit_Interval :=
                 Float'Max (0.0, 1.0 - Setpoint_Hpf / Threshold);
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

   type Level_Kind is (Level_Off, Level_Roll, Level_Roll_Pitch);

   --  The horizon strength: full levelling flat with centered sticks, none
   --  at the angle and stick limits, held to the gain, and smoothed on the
   --  way up. The type bound is the product of the configuration bounds; the
   --  value stays within one in practice.
   subtype Strength is Float range 0.0 .. 600.0;

   procedure Horizon_Strength (S : in out State; R : Runtime; Inp : Inputs; H : out Strength) is
      Inclination : constant Float range 0.0 .. 181.0 :=
        Float (Integer'Max (abs Inp.Attitude (Roll), abs Inp.Attitude (Pitch))) * 0.1;
      Stick       : constant Float range 0.0 .. 1.0 :=
        Float'Max (abs Inp.Deflection (Roll), abs Inp.Deflection (Pitch));
      By_Angle    : constant Float range -20.0 .. 28.0 :=
        (R.Horizon_Limit_Degrees - Inclination) * R.Horizon_Limit_Degrees_Inv;
      By_Sticks   : constant Float range -10.0 .. 21.0 :=
        (R.Horizon_Limit_Sticks - Stick) * R.Horizon_Limit_Sticks_Inv;
      Level       : Float range 0.0 .. 600.0 := (if By_Angle > 0.0 then By_Angle else 0.0);
      Smoothed    : Signal;
   begin
      Level := Level * (if By_Sticks > R.Horizon_Ignore_Sticks then By_Sticks else R.Horizon_Ignore_Sticks);
      Level := Level * R.Horizon_Gain;
      PT1_Apply (S.Filters.Horizon_Smoothing, Level, Smoothed);
      --  The smoothed strength is never negative, which the filter's type
      --  cannot say; the final branch is inert.
      H := (if Level < Smoothed then Level elsif Smoothed > 0.0 then Smoothed else 0.0);
   end Horizon_Strength;

   --  The angle error rate of a level axis from the stick's angle target,
   --  or the autopilot's in GPS rescue and in position hold while it holds,
   --  the attitude less the trim, the angle feedforward, and the yaw
   --  compensation while rolled or pitched, blended into the acro setpoint
   --  by the horizon strength outside the angle and autopilot modes.
   procedure Level_Setpoint (
      S        : in out State;
      R        : Runtime;
      P        : Profile;
      Inp      : Inputs;
      A        : Level_Axis;
      H        : Strength;
      Setpoint : in out Rate
   ) is
      Angle_Limit : constant Float range 10.0 .. 90.0 := Float (P.Angle_Limit);
      Inv         : constant Float range 0.0004 .. 2.1 := 1.0 / Inp.Max_RC_Rate (A);
      Raw_FF      : constant Float range -4.0e6 .. 4.0e6 :=
        Angle_Limit * Inp.Feedforward (A) * R.Angle_Feedforward_Gain * Inv;
      Feedforward : Signal;
      Limit       : Float range 0.0 .. 90.0 := Angle_Limit;
      Wanted      : Float range -2.0e6 .. 2.0e6 := Angle_Limit * Setpoint * Inv;
      Target      : Angle_Degrees;
      Current     : constant Float range -211.0 .. 211.0 := Float (Inp.Attitude (A) - Inp.Trims (A)) / 10.0;
      Other       : constant Level_Axis := (if A = Roll then Pitch else Roll);
      Sin_Angle   : Cosine := Sin_Approx (S.Angle_Target (Other) * Rad_Per_Degree);
      Earth_Gain  : constant Float range 0.0 .. 1.0 :=
        (if Inp.GPS_Rescue_Mode or else Inp.Alt_Hold_Mode then 1.0 else R.Angle_Earth_Ref);
      Angle_Rate  : Signal;
      Filtered    : Signal;
   begin
      PT3_Apply (S.Filters.Angle_Feedforward (A), Raw_FF, Feedforward);
      if Inp.GPS_Rescue_Mode then
         Wanted := Inp.Autopilot_Angle (A);
         Limit := Float (Inp.Autopilot_Max_Angle);
         Feedforward := 0.0;
      end if;
      if Inp.Pos_Hold_Mode then
         Feedforward := 0.0;
         if Inp.Autopilot_In_Control then
            Wanted := Inp.Autopilot_Angle (A);
            Limit := 85.0;
         end if;
         Limit := Float'Min (Float (Inp.Autopilot_Max_Angle), Limit);
      end if;
      Target := Constrain_F (Wanted, -Limit, Limit);
      declare
         Error : constant Float range -302.0 .. 302.0 := Target - Current;
      begin
         Angle_Rate := Saturate (Error * R.Angle_Gain + Feedforward);
      end;
      if A = Roll then
         Sin_Angle := -Sin_Angle;
      end if;
      Angle_Rate := Saturate (Angle_Rate + S.Angle_Yaw_Setpoint * Sin_Angle * Earth_Gain);
      S.Angle_Target (A) := Target;
      PT3_Apply (S.Filters.Attitude (A), Angle_Rate, Filtered);
      if Inp.Angle_Mode or else Inp.GPS_Rescue_Mode or else Inp.Pos_Hold_Mode then
         Setpoint := Constrain_F (Filtered, -Rate_Bound, Rate_Bound);
      else
         Setpoint := Constrain_F (Setpoint * (1.0 - H) + Filtered * H, -Rate_Bound, Rate_Bound);
      end if;
   end Level_Setpoint;

   --  The yaw setpoint attenuated by the cosine of the larger angle target
   --  while the craft is levelled, and kept for the roll and pitch
   --  compensation.
   procedure Attenuate_Yaw (
      S        : in out State;
      R        : Runtime;
      Inp      : Inputs;
      H        : Strength;
      Setpoint : in out Rate
   ) with Post => (if not Inp.GPS_Rescue_Mode and then R.Angle_Earth_Ref = 0.0
                   then Setpoint = Setpoint'Old and then S = S'Old);
   procedure Attenuate_Yaw (
      S        : in out State;
      R        : Runtime;
      Inp      : Inputs;
      H        : Strength;
      Setpoint : in out Rate
   ) is
      Gain : constant Float range 0.0 .. 1.0 := (if Inp.GPS_Rescue_Mode then 1.0 else R.Angle_Earth_Ref);
   begin
      if Gain /= 0.0 then
         S.Angle_Yaw_Setpoint := Setpoint;
         declare
            Largest : Float range 0.0 .. 54_001.0 :=
              Gain * Float'Max (abs S.Angle_Target (Roll), abs S.Angle_Target (Pitch));
         begin
            if Inp.Horizon_Mode then
               Largest := Largest * H;
            end if;
            Setpoint := Setpoint * Cos_Approx (Largest * Rad_Per_Degree);
         end;
      end if;
   end Attenuate_Yaw;

   use type Interfaces.Integer_32;

   Crash_Detection_Delay_Us : constant := 1_000_000;

   --  Crash recovery once the delay after the detection has passed: the yaw
   --  error held to its limit, roll and pitch levelled through the angle gain
   --  while an accelerometer is present, the I term dropped, and the recovery
   --  ended after its time limit or once the craft is slow and, with an
   --  accelerometer, level.
   procedure Handle_Crash_Recovery
     (S : in out State; R : Runtime; Mode : Crash_Recovery_Mode; Inp : Inputs; A : Axis;
      Gyro_Rate : Rate; Setpoint : in out Rate; Error_Rate : in out Float)
     with Pre  => Error_Rate in -2.0 * Rate_Bound .. 2.0 * Rate_Bound,
          Post => Error_Rate in -2.0 * Rate_Bound .. 2.0 * Rate_Bound
   is
      Since : constant Interfaces.Integer_32 := Clock.Elapsed (Inp.Now_Us, S.Crash_Detected_Us);
   begin
      if not S.In_Crash_Recovery or else Since <= R.Crash_Time_Delay_Us then
         return;
      end if;
      if Mode = Beep then
         S.Crash_Beep := True;
      end if;
      if A = Yaw then
         Error_Rate := Constrain_F (Error_Rate, -R.Crash_Limit_Yaw, R.Crash_Limit_Yaw);
      elsif Inp.Acc_Present then
         declare
            Error_Angle : constant Float range -210.0 .. 210.0 :=
              Float (-(Inp.Attitude (A) - Inp.Trims (A))) / 10.0;
         begin
            Setpoint := Error_Angle * R.Angle_Gain;
            Error_Rate := Setpoint - Gyro_Rate;
         end;
      end if;
      S.Data (A).I := 0.0;
      if Since > R.Crash_Time_Limit_Us
        or else (Inp.Motor_Mix_Range < 1.0
                 and then abs Inp.Gyro (Roll) < R.Crash_Recovery_Rate
                 and then abs Inp.Gyro (Pitch) < R.Crash_Recovery_Rate
                 and then abs Inp.Gyro (Yaw) < R.Crash_Recovery_Rate)
      then
         if Inp.Acc_Present then
            if Interfaces.Integer_32 (abs (Inp.Attitude (Roll) - Inp.Trims (Roll))) < R.Crash_Recovery_Angle_Dd
              and then Interfaces.Integer_32 (abs (Inp.Attitude (Pitch) - Inp.Trims (Pitch)))
                       < R.Crash_Recovery_Angle_Dd
            then
               S.In_Crash_Recovery := False;
               S.Crash_Beep := False;
            end if;
         else
            S.In_Crash_Recovery := False;
            S.Crash_Beep := False;
         end if;
      end if;
   end Handle_Crash_Recovery;

   --  Crash detection while armed with the gyro in range: a saturated mixer,
   --  a D term delta and an error rate past their thresholds, and a setpoint
   --  under its threshold start the recovery, or request the disarm when so
   --  configured; a recovery still inside its delay ends when the error rate
   --  drops or the setpoint rises, and any recovery ends when disarmed.
   procedure Detect_Crash
     (S : in out State; R : Runtime; Mode : Crash_Recovery_Mode; Inp : Inputs; A : Axis;
      Delta_Rate : Signal; Error_Rate : Float)
     with Post => (if not Inp.Armed and then (Mode /= Off or else Inp.GPS_Rescue_Mode) and then not Inp.Gyro_Overflow
                   then not S.In_Crash_Recovery)
   is
   begin
      if (Mode = Off and then not Inp.GPS_Rescue_Mode) or else Inp.Gyro_Overflow then
         return;
      end if;
      if Inp.Armed then
         if Inp.Motor_Mix_Range >= 1.0 and then not S.In_Crash_Recovery
           and then abs Delta_Rate > R.Crash_Dterm_Threshold
           and then abs Error_Rate > R.Crash_Gyro_Threshold
           and then abs Inp.Setpoint (A) < R.Crash_Setpoint_Threshold
         then
            if Mode = Disarm then
               S.Crash_Disarm_Requested := True;
            else
               S.In_Crash_Recovery := True;
               S.Crash_Detected_Us := Inp.Now_Us;
            end if;
         end if;
         if S.In_Crash_Recovery
           and then Clock.Elapsed (Inp.Now_Us, S.Crash_Detected_Us) < R.Crash_Time_Delay_Us
           and then (abs Error_Rate < R.Crash_Gyro_Threshold
                     or else abs Inp.Setpoint (A) > R.Crash_Setpoint_Threshold)
         then
            S.In_Crash_Recovery := False;
            S.Crash_Beep := False;
         end if;
      elsif S.In_Crash_Recovery then
         S.In_Crash_Recovery := False;
         S.Crash_Beep := False;
      end if;
   end Detect_Crash;

   Launch_Max_Rate     : constant Float := 100.0;
   Launch_Min_Rate     : constant Float := 5.0;
   Launch_Angle_Window : constant Float := 10.0;
   Launch_Yaw_Iterm_Limit : constant Float := 50.0;

   --  The launch control setpoint: twice the stick's deflection within a
   --  half, scaled to the launch rate, on pitch alone or on every axis, and
   --  on pitch run down to the minimum rate over the last ten degrees before
   --  the angle limit, zero past it.
   function Launch_Setpoint (R : Runtime; Inp : Inputs; A : Axis) return Rate
     with Post => abs Launch_Setpoint'Result <= Launch_Max_Rate
   is
      Result : Float range -Launch_Max_Rate .. Launch_Max_Rate := 0.0;
   begin
      if A = Pitch or else R.Launch_Control /= Pitch_Only then
         declare
            Stick : constant Float range -0.5 .. 0.5 :=
              Constrain_F ((if A = Yaw then Inp.Yaw_Deflection else Inp.Deflection (A)), -0.5, 0.5);
         begin
            Result := Launch_Max_Rate * Stick * 2.0;
         end;
      end if;
      if A = Pitch and then R.Launch_Control_Angle_Limit > 0 and then Result > 0.0 then
         declare
            Current_Angle : constant Float range -210.0 .. 210.0 :=
              Float (Inp.Attitude (Pitch) - Inp.Trims (Pitch)) / 10.0;
            Limit         : constant Float range 1.0 .. 80.0 := Float (R.Launch_Control_Angle_Limit);
         begin
            if Current_Angle >= Limit then
               Result := 0.0;
            else
               declare
                  Angle_Delta : constant Float range 0.0 .. 300.0 := Limit - Current_Angle;
               begin
                  if Angle_Delta <= Launch_Angle_Window then
                     Result :=
                       Constrain_F (Scale_Range_F (Angle_Delta, 0.0, Launch_Angle_Window, Launch_Min_Rate, Result),
                                    -Launch_Max_Rate, Launch_Max_Rate);
                  end if;
               end;
            end if;
         end;
      end if;
      return Result;
   end Launch_Setpoint;

   --  The terms held while launch control is active: the yaw I term within
   --  its launch limit, and in the pitch-only mode the roll P and I terms
   --  and the yaw P term at zero and the pitch I term at or above zero.
   procedure Hold_Launch_Terms (S : in out State; Mode : Launch_Control_Mode)
     with Post => S.Previous_Gyro_Dterm = S.Previous_Gyro_Dterm'Old
                  and then S.Level_Mode_Start_Us = S.Level_Mode_Start_Us'Old
   is
      Yaw_Limit : constant Float := (if Mode = Full then Launch_Yaw_Iterm_Limit else 0.0);
   begin
      S.Data (Yaw).I := Constrain_F (S.Data (Yaw).I, -Yaw_Limit, Yaw_Limit);
      if Mode = Pitch_Only then
         S.Data (Roll).P := 0.0;
         S.Data (Roll).I := 0.0;
         S.Data (Yaw).P := 0.0;
         S.Data (Pitch).I := (if 0.0 > S.Data (Pitch).I then 0.0 else S.Data (Pitch).I);
      end if;
   end Hold_Launch_Terms;

   --  The landing disarm: once the throttle has risen, with the sticks
   --  centred and the RC throttle low, or below the landing altitude while
   --  altitude hold or GPS rescue owns the throttle, a jerk past the
   --  threshold requests the disarm, half again as sensitive below that
   --  altitude under the autopilot.
   procedure Disarm_On_Impact (S : in out State; R : Runtime; Inp : Inputs)
     with Global => null
   is
      Autopilot   : constant Boolean := Inp.Alt_Hold_Mode or else Inp.GPS_Rescue_Mode;
      Sensitivity : constant Float range 1.0 .. 1.5 :=
        (if Autopilot and then Inp.Below_Landing_Altitude then 1.5 else 1.0);
   begin
      if Inp.Throttle_Raised
        and then (if Autopilot then Inp.Below_Landing_Altitude
                  else Inp.Max_Deflection < 0.05 and then Inp.RC_Throttle < 0.05)
        and then Inp.Jerk_Magnitude * Sensitivity > R.Landing_Disarm_Threshold
      then
         S.Landing_Disarm_Requested := True;
      end if;
   end Disarm_On_Impact;

   procedure Update (S : in out State; R : Runtime; P : Profile; Inp : Inputs) is
      External   : constant Boolean := Inp.GPS_Rescue_Mode or else Inp.Alt_Hold_Mode or else Inp.Pos_Hold_Mode;
      Gyro_Dterm : Axis_Signals;
      Level      : Level_Kind := Level_Off;
      H          : Strength := 0.0;
   begin
      S.Crash_Disarm_Requested := False;
      S.Landing_Disarm_Requested := False;
      if Inp.Angle_Mode or else Inp.Horizon_Mode or else Inp.GPS_Rescue_Mode then
         Level := (if R.Level_Race_Mode and then not External then Level_Roll else Level_Roll_Pitch);
         if S.Level_Mode_Start_Us = 0 or else (External and then not S.Previous_External) then
            S.Level_Mode_Start_Us := Inp.Now_Us;
         end if;
         if Inp.Horizon_Mode then
            Horizon_Strength (S, R, Inp, H);
         end if;
      else
         S.Level_Mode_Start_Us := 0;
      end if;
      S.Previous_External := External;
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
      if R.Landing_Disarm_Threshold > 0.0 then
         Disarm_On_Impact (S, R, Inp);
      end if;
      for A in Axis loop
         declare
            Setpoint       : Rate := Inp.Setpoint (A);
            Gyro_Rate      : constant Rate := Inp.Gyro (A);
            Previous_Iterm : Iterm;
            Error_Rate     : Float;
            Iterm_Error    : Signal;
            Ki             : Float;
            Iterm_Limit    : Float;
            Iterm_Change   : Float;
            Setpoint_Delta : Rate := Inp.Feedforward (A);
            Term           : Float;
         begin
            if R.Max_Velocity (A) /= 0.0 then
               Acceleration_Limit (S, A, R, Setpoint);
            end if;
            S.Axis_In_Angle_Mode (A) := False;
            if A /= Yaw then
               if Level = Level_Roll_Pitch or else (Level = Level_Roll and then A = Roll) then
                  S.Axis_In_Angle_Mode (A) := True;
                  Level_Setpoint (S, R, P, Inp, A, H, Setpoint);
               end if;
            elsif Level = Level_Roll_Pitch then
               Attenuate_Yaw (S, R, Inp, H, Setpoint);
            end if;
            if Inp.Angle_Mode and then S.Axis_In_Angle_Mode (A) then
               Setpoint_Delta := 0.0;
            end if;
            if Inp.Launch_Control_Active then
               Setpoint := Launch_Setpoint (R, Inp, A);
            end if;
            if A = Yaw and then Inp.Yaw_Spin_Detected then
               Setpoint := 0.0;
            end if;
            Error_Rate := Setpoint - Gyro_Rate;
            Handle_Crash_Recovery (S, R, P.Crash_Recovery, Inp, A, Gyro_Rate, Setpoint, Error_Rate);
            Previous_Iterm := S.Data (A).I;
            Iterm_Error := Error_Rate;
            if not Inp.Launch_Control_Active and then not S.In_Crash_Recovery then
               Apply_Iterm_Relax (S, A, R, Previous_Iterm, Gyro_Rate, Iterm_Error, Setpoint, Inp.Angle_Mode);
               Error_Rate := Setpoint - Gyro_Rate;
            end if;
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
            if Inp.Launch_Control_Active then
               Ki := R.Launch_Control_Ki;
            elsif A = Yaw then
               Iterm_Limit := R.Iterm_Limit_Yaw;
               S.Iterm_Accelerator := 0.0;
            end if;
            Iterm_Change := (Ki + S.Iterm_Accelerator) * R.Dt;
            Iterm_Change := Iterm_Change * Iterm_Error;
            S.Data (A).I := Constrain_F (Previous_Iterm + Iterm_Change, -Iterm_Limit, Iterm_Limit);
            S.Previous_PID_Setpoint (A) := Setpoint;
            if R.Coefficient (A).Kd > 0.0 and then not Inp.Launch_Control_Active then
               declare
                  Gyro_Delta : constant Signal :=
                    Saturate ((-(Gyro_Dterm (A) - S.Previous_Gyro_Dterm (A))) * R.PID_Frequency);
                  Pre_TPA_D  : Float := R.Coefficient (A).Kd * Gyro_Delta;
                  Multiplier : Float := 1.0;
                  Range_Out  : Signal;
                  Smoothed   : Signal;
               begin
                  if Clock.Elapsed (Inp.Now_Us, S.Level_Mode_Start_Us) > Crash_Detection_Delay_Us then
                     Detect_Crash (S, R, P.Crash_Recovery, Inp, A, Gyro_Delta, Error_Rate);
                  end if;
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
            S.Data (A).F := (if Inp.Launch_Control_Active then 0.0 else R.Coefficient (A).Kf) * Setpoint_Delta;
            if Inp.Yaw_Spin_Detected then
               S.Data (A).I := 0.0;
               if A /= Yaw then
                  S.Data (A).P := 0.0;
                  S.Data (A).D := 0.0;
                  S.Data (A).F := 0.0;
               end if;
            end if;
            if Inp.Launch_Control_Active then
               Hold_Launch_Terms (S, R.Launch_Control);
            end if;
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
      if not S.Stabilisation_Enabled or else Inp.Gyro_Overflow then
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
