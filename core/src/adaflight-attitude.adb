with Interfaces; use type Interfaces.Integer_32;
with Adaflight.Clock;

package body Adaflight.Attitude with SPARK_Mode is
   use Vectors;

   Spin_Rate_Limit        : constant Float := 20.0 * Rad_Per_Degree;
   Reset_Quiet_Time       : constant Time_Us := 250_000;
   Reset_Gyro_Limit       : constant Float := 15.0;
   Reset_Active_Time      : constant Time_Us := 500_000;
   Decidegrees_Per_Radian : constant Float := 1_800.0 / Pi;
   Angle_Divisor          : constant Float := 900.0 * Pi / 2.0;

   function Saturate_Signal (X : Float) return Signal is
     (Constrain_F (X, -Signal_Bound, Signal_Bound));

   function Saturate_Component (X : Float) return Component is
     (Constrain_F (X, -Component_Bound, Component_Bound));

   function Cosine_Of (X : Float) return Cosine is
     (Constrain_F (X, -1.0, 1.0));

   --  The reciprocal of the root of a sum of squares; zero where the sum is
   --  zero, where the reference's reciprocal is infinite. A nonzero binary32
   --  root is at least 2 ** (-74.5), so the guard is inert elsewhere.
   Min_Root : constant := 2.0 ** (-75);
   subtype Reciprocal is Float range 0.0 .. 2.0 ** 75;
   function Inverse_Root (Sum : Float) return Reciprocal
     with Pre => Sum in 0.0 .. 2.0 ** 100
   is
      Root : constant Float := Sqrt_Non_Negative (Sum);
   begin
      if Root >= Min_Root then
         return 1.0 / Root;
      else
         return 0.0;
      end if;
   end Inverse_Root;

   --  A rounded value held to the range of its decidegree or correction
   --  type, which the rounding of a bounded argument cannot leave.
   function Clamp (V : Rounded_Integer; Low : Integer; High : Integer) return Integer is
     (Integer'Max (Low, Integer'Min (V, High)))
     with Pre  => Low <= High,
          Post => Clamp'Result in Low .. High;

   ---------------
   -- Configure --
   ---------------

   function Configure (S : Settings) return Config is
      Kp    : constant Float := Float (S.DCM_Kp) / 10_000.0;
      Ki    : constant Float := Float (S.DCM_Ki) / 10_000.0;
      Scale : constant Float := Decidegrees_Per_Radian * (900.0 / Float (S.Throttle_Correction_Angle));
      Declination : constant Float := Float (S.Mag_Declination) / 10.0 * Rad_Per_Degree;
      Sin_D : Cosine;
      Cos_D : Cosine;
   begin
      Sin_Cos_Approx (Declination, Sin_D, Cos_D);
      return (Kp                   => Kp,
              Ki                   => Ki,
              Small_Angle_Cos      => Cos_Approx (Float (S.Small_Angle) * Rad_Per_Degree),
              Throttle_Angle_Scale => Scale,
              Throttle_Angle_Value => S.Throttle_Correction_Value,
              North                => (X => Cos_D, Y => -Sin_D));
   end Configure;

   -----------------
   -- Mag_Error --
   -----------------

   subtype Heading_Error is Float range -4.0 .. 4.0;

   --  The heading error from the compass: the field in the earth frame,
   --  normalized, against magnetic north in the ground plane; the sine of
   --  the angle between them while the field points forward, else the full
   --  norm toward the shorter turn. Zero for a field within a tenth of a
   --  count. The result is held to four, outside the one a unit field
   --  reaches (DESIGN.md D31).
   Earth_Field_Bound : constant := 2.0 ** 30;

   --  The field turned into the earth frame by a rotation within the matrix
   --  bound: three products of an entry and a count per component.
   function Earth_Field (R : Matrix33; Mag : Vector3) return Vector3
     with Pre  => Bounded (R, Matrix_Bound) and then Bounded (Mag, Mag_Bound),
          Post => Bounded (Earth_Field'Result, Earth_Field_Bound)
   is
      subtype Term is Float range -2.0 ** 27 .. 2.0 ** 27;
      subtype Pair is Float range -2.0 ** 28 .. 2.0 ** 28;
   begin
      return (X => Pair'(Term'(R (X, X) * Mag.X) + Term'(R (X, Y) * Mag.Y)) + Term'(R (X, Z) * Mag.Z),
              Y => Pair'(Term'(R (Y, X) * Mag.X) + Term'(R (Y, Y) * Mag.Y)) + Term'(R (Y, Z) * Mag.Z),
              Z => Pair'(Term'(R (Z, X) * Mag.X) + Term'(R (Z, Y) * Mag.Y)) + Term'(R (Z, Z) * Mag.Z));
   end Earth_Field;

   function Mag_Error (S : State; C : Config; Mag : Vector3) return Heading_Error
     with Pre => Bounded (Mag, Mag_Bound) and then Bounded (S.Rotation, Matrix_Bound)
   is
      subtype Mag_Square is Float range 0.0 .. 2.0 ** 46;
      subtype Mag_Reciprocal is Float range 0.0 .. 10.0;
      subtype Plane_Component is Float range -2.0 ** 34 .. 2.0 ** 34;
      Norm_Sq : constant Mag_Square := Mag_Square'(Mag_Square'(Mag.X * Mag.X + Mag.Y * Mag.Y) + Mag.Z * Mag.Z);
      Root    : constant Float := Sqrt_Non_Negative (Norm_Sq);
   begin
      --  A squared norm above a hundredth has a root of at least a tenth.
      if Norm_Sq > 0.01 and then Root >= 0.1 then
         declare
            Ef    : constant Vector3 := Earth_Field (S.Rotation, Mag);
            Recip : constant Mag_Reciprocal := 1.0 / Root;
            Px    : constant Plane_Component := Ef.X * Recip;
            Py    : constant Plane_Component := Ef.Y * Recip;
            Plane : constant Vector2 := (X => Px, Y => Py);
            D     : constant Float := Dot (Plane, C.North);
            Cr    : constant Float := Cross (Plane, C.North);
         begin
            if D > 0.0 then
               return Constrain_F (Cr, -4.0, 4.0);
            else
               return Constrain_F ((if Cr < 0.0 then -1.0 else 1.0) * Norm (Plane), -4.0, 4.0);
            end if;
         end;
      else
         return 0.0;
      end if;
   end Mag_Error;

   ----------------------
   -- Compute_Rotation --
   ----------------------

   procedure Compute_Rotation (S : in out State)
     with Post => S.Q = S.Q'Old and then S.Integral = S.Integral'Old
                  and then S.Previous_Time = S.Previous_Time'Old
                  and then S.Reset_Phase = S.Reset_Phase'Old and then S.Phase_Timeout = S.Phase_Timeout'Old
                  and then S.Euler = S.Euler'Old and then S.Established = S.Established'Old
                  and then S.Throttle_Correction = S.Throttle_Correction'Old
                  and then S.Course_Set = S.Course_Set'Old and then S.GPS_Heading = S.GPS_Heading'Old
   is
      subtype Product is Float range -4.0 .. 4.0;
      WX : constant Product := S.Q.W * S.Q.X;
      WY : constant Product := S.Q.W * S.Q.Y;
      WZ : constant Product := S.Q.W * S.Q.Z;
      XX : constant Product := S.Q.X * S.Q.X;
      XY : constant Product := S.Q.X * S.Q.Y;
      XZ : constant Product := S.Q.X * S.Q.Z;
      YY : constant Product := S.Q.Y * S.Q.Y;
      YZ : constant Product := S.Q.Y * S.Q.Z;
      ZZ : constant Product := S.Q.Z * S.Q.Z;
      subtype Entry_Value is Float range -Matrix_Bound .. Matrix_Bound;
      R : constant Matrix33 :=
        (X => (Entry_Value'(1.0 - 2.0 * YY - 2.0 * ZZ), Entry_Value'(2.0 * (XY - WZ)), Entry_Value'(2.0 * (XZ + WY))),
         Y => (Entry_Value'(2.0 * (XY + WZ)), Entry_Value'(1.0 - 2.0 * XX - 2.0 * ZZ), Entry_Value'(2.0 * (YZ - WX))),
         Z => (Entry_Value'(2.0 * (XZ - WY)), Entry_Value'(2.0 * (YZ + WX)), Entry_Value'(1.0 - 2.0 * XX - 2.0 * YY)));
   begin
      S.Rotation := R;
   end Compute_Rotation;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State) is
   begin
      S := (Q                   => Identity,
            Rotation            => Vectors.Identity,
            Integral            => (X => 0.0, Y => 0.0, Z => 0.0),
            Previous_Time       => 0,
            Reset_Phase         => Disarmed,
            Phase_Timeout       => 0,
            Euler               => (Roll => 0, Pitch => 0, Yaw => 0),
            Established         => False,
            Throttle_Correction => 0,
            Headfree_Offset     => Identity,
            Headfree            => Identity,
            Reported            => Identity,
            Course_Set          => False,
            Yaw_Suppression     => 0.0,
            Heading_Confidence  => 0.0,
            GPS_Heading         => False,
            Taps                => <>);
      Compute_Rotation (S);
   end Init;

   -------------------
   -- Schedule_Gain --
   -------------------

   --  The proportional gain: the configured gain while armed and through the
   --  quiet period after a disarm, one hundred times it while the attitude
   --  reconverges, and ten times it while disarmed otherwise.
   subtype Scheduled_Gain is Float range 0.0 .. 400.0;

   procedure Schedule_Gain (
      S       : in out State;
      C       : Config;
      Now     : Time_Us;
      Use_Acc : Boolean;
      Gyro    : Vector3;
      Armed   : Boolean;
      Gain    : out Scheduled_Gain
   ) with Pre  => Bounded (Gyro, Rate_Bound),
          Post => S.Q = S.Q'Old and then S.Rotation = S.Rotation'Old and then S.Integral = S.Integral'Old
                  and then S.Previous_Time = S.Previous_Time'Old and then S.Euler = S.Euler'Old
                  and then S.Established = S.Established'Old
                  and then S.Throttle_Correction = S.Throttle_Correction'Old
   is
      procedure Quiet_Step is
      begin
         if Clock.Elapsed (Now, S.Phase_Timeout) >= 0 then
            S.Phase_Timeout := Now + Reset_Active_Time;
            S.Reset_Phase := Reset;
         end if;
      end Quiet_Step;
   begin
      if Armed then
         S.Reset_Phase := Attitude.Armed;
         Gain := C.Kp;
         return;
      end if;
      if abs Gyro.X > Reset_Gyro_Limit or else abs Gyro.Y > Reset_Gyro_Limit
        or else abs Gyro.Z > Reset_Gyro_Limit or else not Use_Acc
      then
         S.Reset_Phase := Restart;
      end if;
      case S.Reset_Phase is
         when Attitude.Armed | Restart =>
            S.Phase_Timeout := Now + Reset_Quiet_Time;
            S.Reset_Phase := Quiet;
            Quiet_Step;
            Gain := C.Kp;
         when Quiet =>
            Quiet_Step;
            Gain := C.Kp;
         when Reset =>
            if Clock.Elapsed (Now, S.Phase_Timeout) >= 0 then
               S.Reset_Phase := Disarmed;
            end if;
            Gain := C.Kp * 100.0;
         when Disarmed =>
            Gain := C.Kp * 10.0;
      end case;
   end Schedule_Gain;

   -------------------
   -- Mahony_Update --
   -------------------

   subtype Delta_Seconds is Float range -2_200.0 .. 2_200.0;

   --  The GPS course's share of the heading error is held at a bound no
   --  update interval within a second reaches (DESIGN.md D435); the compass's
   --  share adds to it.
   Course_Error_Bound : constant := 2.0 ** 14;
   subtype Course_Error is Float range -Course_Error_Bound .. Course_Error_Bound;
   subtype Total_Heading_Error is Float range -(Course_Error_Bound + 4.0) .. Course_Error_Bound + 4.0;

   procedure Mahony_Update (
      S       : in out State;
      C       : Config;
      Dt      : Delta_Seconds;
      Gyro    : Vector3;
      Use_Acc : Boolean;
      Acc     : Vector3;
      Heading_Err : Total_Heading_Error;
      Kp_Gain : Scheduled_Gain
   ) with Pre  => Bounded (Gyro, Rate_Bound) and then Bounded (Acc, Acc_Bound)
                  and then Bounded (S.Integral, Signal_Bound) and then Bounded (S.Rotation, Matrix_Bound),
          Post => S.Previous_Time = S.Previous_Time'Old and then S.Reset_Phase = S.Reset_Phase'Old
                  and then S.Phase_Timeout = S.Phase_Timeout'Old and then S.Euler = S.Euler'Old
                  and then S.Throttle_Correction = S.Throttle_Correction'Old
   is
      subtype Rad_Rate is Float range -200.0 .. 200.0;
      subtype Rate_Square is Float range 0.0 .. 2.0 ** 17;
      subtype Error is Float range -3.0e5 .. 3.0e5;
      subtype Acc_Square is Float range 0.0 .. 2.0 ** 35;
      subtype Ki_Error is Float range -1.2e6 .. 1.2e6;
      subtype Integral_Step is Float range -2.7e9 .. 2.7e9;
      subtype Kp_Error is Float range -1.2e8 .. 1.2e8;
      subtype Corrected_Rate is Float range -2.0 ** 33 .. 2.0 ** 33;
      --  The rate with the proportional and integral feedback added, in a
      --  context of its own so the bound is checked on the three operands.
      function Corrected (G : Rad_Rate; P : Kp_Error; I : Signal) return Corrected_Rate
        with Post => Corrected'Result = G + (P + I);
      function Corrected (G : Rad_Rate; P : Kp_Error; I : Signal) return Corrected_Rate is
      begin
         return G + (P + I);
      end Corrected;
      subtype Half_Step is Float range -2.0 ** 44 .. 2.0 ** 44;
      subtype Raw_Component is Float range -2.0 ** 48 .. 2.0 ** 48;
      subtype Norm_Square is Float range 0.0 .. 2.0 ** 99;
      Gx : constant Rad_Rate := Gyro.X * Rad_Per_Degree;
      Gy : constant Rad_Rate := Gyro.Y * Rad_Per_Degree;
      Gz : constant Rad_Rate := Gyro.Z * Rad_Per_Degree;
      Spin_Rate : constant Float := Sqrt_Non_Negative (Rate_Square'(Rate_Square'(Gx * Gx + Gy * Gy) + Gz * Gz));
      Ex : Error := 0.0;
      Ey : Error := 0.0;
      Ez : Error := 0.0;
      Acc_Norm_Sq : constant Acc_Square := Acc_Square'(Acc_Square'(Acc.X * Acc.X + Acc.Y * Acc.Y) + Acc.Z * Acc.Z);
      R : Matrix33 renames S.Rotation;
   begin
      Ex := Ex + R (Z, X) * Heading_Err;
      Ey := Ey + R (Z, Y) * Heading_Err;
      Ez := Ez + R (Z, Z) * Heading_Err;
      if Use_Acc and then Acc_Norm_Sq > 0.01 then
         declare
            Recip : constant Reciprocal := Inverse_Root (Acc_Norm_Sq);
            Ax    : constant Component := Saturate_Component (Acc.X * Recip);
            Ay    : constant Component := Saturate_Component (Acc.Y * Recip);
            Az    : constant Component := Saturate_Component (Acc.Z * Recip);
         begin
            Ex := Ex + (Ay * R (Z, Z) - Az * R (Z, Y));
            Ey := Ey + (Az * R (Z, X) - Ax * R (Z, Z));
            Ez := Ez + (Ax * R (Z, Y) - Ay * R (Z, X));
         end;
      end if;
      if C.Ki > 0.0 then
         if Spin_Rate < Spin_Rate_Limit then
            declare
               Sx : constant Integral_Step := Ki_Error'(C.Ki * Ex) * Dt;
               Sy : constant Integral_Step := Ki_Error'(C.Ki * Ey) * Dt;
               Sz : constant Integral_Step := Ki_Error'(C.Ki * Ez) * Dt;
            begin
               S.Integral.X := Saturate_Signal (S.Integral.X + Sx);
               S.Integral.Y := Saturate_Signal (S.Integral.Y + Sy);
               S.Integral.Z := Saturate_Signal (S.Integral.Z + Sz);
            end;
         end if;
      else
         S.Integral := (X => 0.0, Y => 0.0, Z => 0.0);
      end if;
      declare
         Fx : constant Corrected_Rate := Corrected (Gx, Kp_Error'(Kp_Gain * Ex), S.Integral.X);
         Fy : constant Corrected_Rate := Corrected (Gy, Kp_Error'(Kp_Gain * Ey), S.Integral.Y);
         Fz : constant Corrected_Rate := Corrected (Gz, Kp_Error'(Kp_Gain * Ez), S.Integral.Z);
         Hx : constant Half_Step := Fx * (0.5 * Dt);
         Hy : constant Half_Step := Fy * (0.5 * Dt);
         Hz : constant Half_Step := Fz * (0.5 * Dt);
         B  : constant Quaternion := S.Q;
         Qw : constant Raw_Component := B.W + ((-B.X) * Hx - B.Y * Hy - B.Z * Hz);
         Qx : constant Raw_Component := B.X + (B.W * Hx + B.Y * Hz - B.Z * Hy);
         Qy : constant Raw_Component := B.Y + (B.W * Hy - B.X * Hz + B.Z * Hx);
         Qz : constant Raw_Component := B.Z + (B.W * Hz + B.X * Hy - B.Y * Hx);
         Norm_Sq : constant Norm_Square :=
           Norm_Square'(Norm_Square'(Norm_Square'(Qw * Qw + Qx * Qx) + Qy * Qy) + Qz * Qz);
         Recip : constant Reciprocal := Inverse_Root (Norm_Sq);
      begin
         if Recip > 0.0 then
            S.Q := (W => Saturate_Component (Qw * Recip),
                    X => Saturate_Component (Qx * Recip),
                    Y => Saturate_Component (Qy * Recip),
                    Z => Saturate_Component (Qz * Recip));
         else
            S.Q := Identity;
         end if;
      end;
      Compute_Rotation (S);
      S.Established := True;
   end Mahony_Update;

   ------------------
   -- Update_Euler --
   ------------------

   procedure Update_Euler (S : in out State; Headfree_Mode : Boolean)
     with Post => S.Q = S.Q'Old and then S.Rotation = S.Rotation'Old and then S.Integral = S.Integral'Old
                  and then S.Previous_Time = S.Previous_Time'Old and then S.Reset_Phase = S.Reset_Phase'Old
                  and then S.Phase_Timeout = S.Phase_Timeout'Old and then S.Established = S.Established'Old
                  and then S.Throttle_Correction = S.Throttle_Correction'Old
   is
      R : Matrix33 renames S.Rotation;
      H : Quaternion renames S.Headfree;
      subtype Product is Float range -4.0 .. 4.0;
      WX : constant Product := H.W * H.X;
      WY : constant Product := H.W * H.Y;
      WZ : constant Product := H.W * H.Z;
      XX : constant Product := H.X * H.X;
      XY : constant Product := H.X * H.Y;
      XZ : constant Product := H.X * H.Z;
      YY : constant Product := H.Y * H.Y;
      YZ : constant Product := H.Y * H.Z;
      ZZ : constant Product := H.Z * H.Z;
      Roll  : constant Half_Turn :=
        (if Headfree_Mode then Atan2_Approx (2.0 * (WX + YZ), 1.0 - 2.0 * (XX + YY))
         else Atan2_Approx (R (Z, Y), R (Z, Z)));
      Pitch : constant Quarter_Turn :=
        Pi / 2.0 - Acos_Approx (Cosine_Of (if Headfree_Mode then 2.0 * (WY - XZ) else -R (Z, X)));
      Yaw   : constant Half_Turn :=
        (if Headfree_Mode then -Atan2_Approx (2.0 * (WZ + XY), 1.0 - 2.0 * (YY + ZZ))
         else -Atan2_Approx (R (Y, X), R (X, X)));
      Yaw_Raw : constant Decidegrees := Clamp (Round_Half_Even (Yaw * Decidegrees_Per_Radian), -1_800, 1_800);
   begin
      S.Euler.Roll := Clamp (Round_Half_Even (Roll * Decidegrees_Per_Radian), -1_800, 1_800);
      S.Euler.Pitch := Clamp (Round_Half_Even (Pitch * Decidegrees_Per_Radian), -900, 900);
      S.Reported := (if Headfree_Mode then S.Headfree else S.Q);
      if Yaw_Raw < 0 then
         S.Euler.Yaw := Yaw_Raw + 3_600;
      else
         S.Euler.Yaw := Yaw_Raw;
      end if;
   end Update_Euler;

   ----------------------------
   -- Throttle_Correction_Of --
   ----------------------------

   --  Zero when inverted, vertical, or within a small angle of level. The
   --  contract keeps the rounding checks out of the update's context.
   function Throttle_Correction_Of (S : State; C : Config) return Correction
     with Post => (if Cos_Tilt (S) <= 0.015 then Throttle_Correction_Of'Result = 0);
   function Throttle_Correction_Of (S : State; C : Config) return Correction is
      Tilt : constant Float := Cos_Tilt (S);
   begin
      if Tilt <= 0.015 then
         return 0;
      end if;
      declare
         Angle : Integer range 0 .. 2_000_000 :=
           Clamp (Round_Half_Even (Acos_Approx (Cosine_Of (Tilt)) * C.Throttle_Angle_Scale), 0, 2_000_000);
      begin
         if Angle > 900 then
            Angle := 900;
         end if;
         return Clamp (Round_Half_Even (Float (C.Throttle_Angle_Value) * Sin_Approx (Float (Angle) / Angle_Divisor)),
                       -150, 150);
      end;
   end Throttle_Correction_Of;

   ----------------------
   -- Groundspeed_Gain --
   ----------------------

   --  The weight of the GPS course: the ground speed's share, the yaw rate
   --  suppression that decays back over about a second, the roll's and,
   --  for a multirotor, the pitch's suppressions, and a tenth with a
   --  calibrated compass.
   Course_Speed : constant := 100;
   Gain_Bound   : constant := 2.0 ** 32;
   subtype Course_Gain is Float range -Gain_Bound .. Gain_Bound;

   procedure Groundspeed_Gain
     (S : in out State; Course : Course_Inputs; Use_Mag : Boolean; Dt : Delta_Seconds; Gain : out Course_Gain)
     with Post => S.Q = S.Q'Old and then S.Rotation = S.Rotation'Old and then S.Integral = S.Integral'Old
                  and then S.Euler = S.Euler'Old and then S.Established = S.Established'Old
                  and then S.Course_Set = S.Course_Set'Old and then S.GPS_Heading = S.GPS_Heading'Old
   is
      subtype Ratio is Float range 0.0 .. 400.0;
      subtype Spread is Float range -(Suppression_Bound + 1.0) .. Suppression_Bound + 1.0;
      subtype Suppressed is Float range -2.0 ** 26 .. 2.0 ** 26;
      Speed_Ratio : constant Ratio := 0.5 * Float (Course.Ground_Speed) / Float (Course_Speed);
      Speed_Gain  : constant Float range 0.0 .. 10.0 :=
        (if Speed_Ratio > 1.0 then Float'Min (Speed_Ratio, 10.0) else Speed_Ratio * Speed_Ratio);
      Rate_Factor : constant Float range 0.0 .. 1.0 := Float'Min (abs (Course.Yaw_Rate * 0.1), 1.0);
      Yaw_Factor  : constant Float range 0.0 .. 1.0 := 1.0 - Rate_Factor * Rate_Factor;
      K           : constant Delta_Seconds := 1.0 * Dt;
      Yaw_Supp    : constant Suppressed := S.Yaw_Suppression + K * Spread'(Yaw_Factor - S.Yaw_Suppression);
      Roll_Abs    : constant Float range 0.0 .. 200.0 := abs (Float (S.Euler.Roll) * 0.1);
      Roll_Max    : constant Float range 10.0 .. 25.0 := (if Course.Fixed_Wing then 25.0 else 10.0);
      Roll_Supp   : constant Float range 0.0 .. 1.0 :=
        (if Roll_Abs < Roll_Max then (Roll_Max - Roll_Abs) / Roll_Max else 0.0);
      Pitch_Supp  : Float range 0.0 .. 5.0 := 1.0;
      Mag_Supp    : constant Float range 0.0 .. 1.0 := (if Use_Mag then 0.1 else 1.0);
   begin
      S.Yaw_Suppression := Float'Max (-Suppression_Bound, Float'Min (Yaw_Supp, Yaw_Factor));
      if not Course.Fixed_Wing then
         declare
            Pitch_Factor : constant Float range -10.0 .. 10.0 := Float (S.Euler.Pitch) * 0.1 / 10.0;
            Held         : constant Float range -10.0 .. 5.0 := Float'Min (Pitch_Factor, 5.0);
         begin
            Pitch_Supp := (if Held >= 0.0 then Held else 0.0);
         end;
      end if;
      Gain := Speed_Gain * Yaw_Supp * Roll_Supp * Pitch_Supp * Mag_Supp;
   end Groundspeed_Gain;

   ---------------------
   -- Course_Error_Of --
   ---------------------

   --  The heading error against the GPS course: the course as a unit vector
   --  north and west, the nose in the ground plane normalized, and the sine
   --  of the angle between them within a quarter turn, else one toward the
   --  shorter turn.
   function Course_Error_Of (North, West : Float; Course : Heading_Decidegrees) return Float
     with Global => null,
          Pre    => North in -Matrix_Bound .. Matrix_Bound and then West in -Matrix_Bound .. Matrix_Bound,
          Post   => Course_Error_Of'Result in -2.0 .. 2.0
   is
      Tenths : constant Float range 0.0 .. 400.0 := Float (Course) / 10.0;
      Cog    : constant Float range 0.0 .. 8.0 := Tenths * Rad_Per_Degree;
      Nose   : constant Vector2 := Normalize (Vector2'(X => North, Y => West));
      Sin_C  : Cosine;
      Cos_C  : Cosine;
   begin
      Sin_Cos_Approx (-Cog, Sin_C, Cos_C);
      declare
         Cr : constant Float range -2.0 .. 2.0 := Nose.X * Sin_C - Nose.Y * Cos_C;
         D  : constant Float range -2.0 .. 2.0 := Nose.X * Cos_C + Nose.Y * Sin_C;
      begin
         if D > 0.0 then
            return Cr;
         elsif Cr < 0.0 then
            return -1.0;
         else
            return 1.0;
         end if;
      end;
   end Course_Error_Of;

   ---------------------------
   -- Update_Heading_Usable --
   ---------------------------

   --  The GPS heading's confidence follows the course's weight while the
   --  heading lines up within about fifteen degrees, with a time constant of
   --  two seconds, and makes the heading good to fly by above one and a half;
   --  once it is, the confidence rests at zero.
   procedure Update_Heading_Usable (S : in out State; Gain : Course_Gain; Error : Float; Dt : Delta_Seconds)
     with Pre  => Error in -2.0 .. 2.0,
          Post => S.Q = S.Q'Old and then S.Rotation = S.Rotation'Old and then S.Integral = S.Integral'Old
                  and then S.Euler = S.Euler'Old and then S.Established = S.Established'Old
                  and then S.Course_Set = S.Course_Set'Old
   is
   begin
      if not S.GPS_Heading then
         declare
            subtype Step is Float range -2.0 ** 72 .. 2.0 ** 72;
            Alignment : constant Float range 0.0 .. 1.0 := Float'Max (1.0 - abs Error * 4.0, 0.0);
            Target    : constant Course_Gain := Gain * Alignment;
            Next      : constant Float := S.Heading_Confidence + Step'(0.5 * Dt * (Target - S.Heading_Confidence));
         begin
            S.Heading_Confidence := Float'Max (-Confidence_Bound, Float'Min (Confidence_Bound, Next));
            S.GPS_Heading := S.Heading_Confidence > 1.5;
         end;
      else
         S.Heading_Confidence := 0.0;
      end if;
      S.Taps.Confidence := S.Heading_Confidence;
      S.Taps.Usable := S.GPS_Heading;
   end Update_Heading_Usable;

   -------------------------
   -- Quaternion_From_RPY --
   -------------------------

   --  The attitude set from Euler angles in decidegrees, the yaw turned
   --  clockwise as the GPS course runs; the attitude counts as established.
   procedure Quaternion_From_RPY (S : in out State; Roll : Decidegrees; Pitch : Pitch_Decidegrees; Yaw : Natural)
     with Pre  => Yaw <= 3_599,
          Post => S.Integral = S.Integral'Old and then S.Euler = S.Euler'Old
                  and then S.Course_Set = S.Course_Set'Old and then S.GPS_Heading = S.GPS_Heading'Old
   is
      Turn  : constant Integer range -1_800 .. 1_800 := (if Yaw > 1_800 then Yaw - 3_600 else Yaw);
      Sin_R : Cosine;
      Cos_R : Cosine;
      Sin_P : Cosine;
      Cos_P : Cosine;
      Sin_Y : Cosine;
      Cos_Y : Cosine;
   begin
      Sin_Cos_Approx (Float (Roll) / 10.0 * Rad_Per_Degree * 0.5, Sin_R, Cos_R);
      Sin_Cos_Approx (Float (Pitch) / 10.0 * Rad_Per_Degree * 0.5, Sin_P, Cos_P);
      Sin_Cos_Approx (Float (-Turn) / 10.0 * Rad_Per_Degree * 0.5, Sin_Y, Cos_Y);
      S.Q := (W => Cos_R * Cos_P * Cos_Y + Sin_R * Sin_P * Sin_Y,
              X => Sin_R * Cos_P * Cos_Y - Cos_R * Sin_P * Sin_Y,
              Y => Cos_R * Sin_P * Cos_Y + Sin_R * Cos_P * Sin_Y,
              Z => Cos_R * Cos_P * Sin_Y - Sin_R * Sin_P * Cos_Y);
      Compute_Rotation (S);
      S.Established := True;
   end Quaternion_From_RPY;

   ------------
   -- Update --
   ------------

   procedure Update (
      S             : in out State;
      C             : Config;
      Now           : Time_Us;
      Gyro          : Vectors.Vector3;
      Acc           : Vectors.Vector3;
      Acc_Magnitude : Float;
      Mag           : Vectors.Vector3;
      Use_Mag       : Boolean;
      Armed         : Boolean;
      Angle_Mode    : Boolean;
      Headfree_Mode : Boolean;
      Course        : Course_Inputs := (others => <>)
   ) is
      Dt      : constant Delta_Seconds := Float (Clock.Elapsed (Now, S.Previous_Time)) * 1.0e-6;
      Use_Acc : constant Boolean := 0.9 < Acc_Magnitude and then Acc_Magnitude < 1.1;
      Heading : constant Heading_Error := (if Use_Mag then Mag_Error (S, C, Mag) else 0.0);
      Cog_Err : Course_Error := 0.0;
      Kp_Gain : Scheduled_Gain;
   begin
      S.Previous_Time := Now;
      if Course.Usable then
         if S.Course_Set then
            declare
               Error : constant Float := Course_Error_Of (S.Rotation (X, X), S.Rotation (Y, X), Course.Course);
               Gain  : Course_Gain;
            begin
               S.Taps.Course_Err_Set := True;
               S.Taps.Course_Error := Error;
               Groundspeed_Gain (S, Course, Use_Mag, Dt, Gain);
               Cog_Err := Float'Max (-Course_Error_Bound, Float'Min (Course_Error_Bound, Error * Gain));
               Update_Heading_Usable (S, Gain, Error, Dt);
            end;
         elsif Course.Ground_Speed > Course_Speed then
            if not Use_Mag then
               Quaternion_From_RPY (S, S.Euler.Roll, S.Euler.Pitch, Course.Course);
            end if;
            S.Course_Set := True;
         end if;
      end if;
      Schedule_Gain (S, C, Now, Use_Acc, Gyro, Armed, Kp_Gain);
      Mahony_Update (S, C, Dt, Gyro, Use_Acc, Acc, Heading + Cog_Err, Kp_Gain);
      Update_Euler (S, Headfree_Mode);
      if C.Throttle_Angle_Value /= 0 and then Angle_Mode and then Armed then
         S.Throttle_Correction := Throttle_Correction_Of (S, C);
      else
         S.Throttle_Correction := 0;
      end if;
   end Update;

   ------------------------
   -- Set_From_Simulator --
   ------------------------

   procedure Set_From_Simulator (S : in out State; Q : Quaternion; Legacy_Bridge : Boolean; Headfree_Mode : Boolean) is
   begin
      S.Q := Q;
      Compute_Rotation (S);
      if Legacy_Bridge then
         S.Rotation (Y, X) := -S.Rotation (Y, X);
         S.Rotation (Z, X) := -S.Rotation (Z, X);
      end if;
      S.Established := True;
      Update_Euler (S, Headfree_Mode);
   end Set_From_Simulator;

   ----------------------
   -- Update_Simulated --
   ----------------------

   procedure Update_Simulated (S : in out State; C : Config; Armed : Boolean; Angle_Mode : Boolean) is
   begin
      S.GPS_Heading := True;
      if C.Throttle_Angle_Value /= 0 and then Angle_Mode and then Armed then
         S.Throttle_Correction := Throttle_Correction_Of (S, C);
      else
         S.Throttle_Correction := 0;
      end if;
   end Update_Simulated;

   -------------------------
   -- Set_Headfree_Offset --
   -------------------------

   procedure Set_Headfree_Offset (S : in out State; Set : out Boolean) is
      subtype Product is Float range -4.0 .. 4.0;
      WZ : constant Product := S.Q.W * S.Q.Z;
      XY : constant Product := S.Q.X * S.Q.Y;
      YY : constant Product := S.Q.Y * S.Q.Y;
      ZZ : constant Product := S.Q.Z * S.Q.Z;
   begin
      Set := abs S.Euler.Roll < 450 and then abs S.Euler.Pitch < 450;
      if Set then
         declare
            Yaw : constant Half_Turn := -Atan2_Approx (2.0 * (WZ + XY), 1.0 - 2.0 * (YY + ZZ));
            Sin : Cosine;
            Cos : Cosine;
         begin
            Sin_Cos_Approx (Yaw / 2.0, Sin, Cos);
            S.Headfree_Offset := (W => Cos, X => 0.0, Y => 0.0, Z => Sin);
         end;
      end if;
   end Set_Headfree_Offset;

   ----------------------
   -- Headfree_To_Body --
   ----------------------

   procedure Headfree_To_Body (S : in out State; V : in out Vectors.Vector3) is
      O : constant Quaternion := S.Headfree_Offset;
      Q : constant Quaternion := S.Q;
      subtype Sum is Float range -4.0 .. 4.0;
      subtype Term is Float range -16.0 .. 16.0;
      A : constant Term := Sum'(O.W + O.X) * Sum'(Q.W + Q.X);
      B : constant Term := Sum'(O.Z - O.Y) * Sum'(Q.Y - Q.Z);
      C : constant Term := Sum'(O.W - O.X) * Sum'(Q.Y + Q.Z);
      D : constant Term := Sum'(O.Y + O.Z) * Sum'(Q.W - Q.X);
      E : constant Term := Sum'(O.X + O.Z) * Sum'(Q.X + Q.Y);
      F : constant Term := Sum'(O.X - O.Z) * Sum'(Q.X - Q.Y);
      G : constant Term := Sum'(O.W + O.Y) * Sum'(Q.W - Q.Z);
      H : constant Term := Sum'(O.W - O.Y) * Sum'(Q.W + Q.Z);
   begin
      S.Headfree := (W => Saturate_Component (B + (-E - F + G + H) / 2.0),
                     X => Saturate_Component (A - (+E + F + G + H) / 2.0),
                     Y => Saturate_Component (C + (+E - F + G - H) / 2.0),
                     Z => Saturate_Component (D + (+E - F - G + H) / 2.0));
      declare
         P  : Quaternion renames S.Headfree;
         subtype Product is Float range -4.0 .. 4.0;
         WW : constant Product := P.W * P.W;
         WX : constant Product := P.W * P.X;
         WY : constant Product := P.W * P.Y;
         WZ : constant Product := P.W * P.Z;
         XX : constant Product := P.X * P.X;
         XY : constant Product := P.X * P.Y;
         XZ : constant Product := P.X * P.Z;
         YY : constant Product := P.Y * P.Y;
         YZ : constant Product := P.Y * P.Z;
         ZZ : constant Product := P.Z * P.Z;
         New_X : constant Float := (WW + XX - YY - ZZ) * V.X + 2.0 * (XY + WZ) * V.Y + 2.0 * (XZ - WY) * V.Z;
         New_Y : constant Float := 2.0 * (XY - WZ) * V.X + (WW - XX + YY - ZZ) * V.Y + 2.0 * (YZ + WX) * V.Z;
         New_Z : constant Float := 2.0 * (XZ + WY) * V.X + 2.0 * (YZ - WX) * V.Y + (WW - XX - YY + ZZ) * V.Z;
      begin
         V := (X => New_X, Y => New_Y, Z => New_Z);
      end;
   end Headfree_To_Body;

end Adaflight.Attitude;
