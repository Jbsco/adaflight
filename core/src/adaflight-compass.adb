with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;

package body Adaflight.Compass with SPARK_Mode is
   use Vectors;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_16;
   use type Sensor_Alignment.Standard_Alignment;

   Bus_Busy_Interval_Us : constant := 500;
   Recheck_Interval_Us  : constant := 1_000;
   Task_Rate_Hz         : constant := 40;

   Calibration_Wait_Us : constant := 15_000_000;
   Calibration_Time_Us : constant := 30_000_000;
   Movement_Rate_Dps   : constant Float := 350.0;

   function Norm_Threshold (Rate_Dps : Float) return Float is
     ((Rate_Dps * Rad_Per_Degree) * (Rate_Dps * Rad_Per_Degree))
     with Pre => Rate_Dps in 0.0 .. 1_000.0;

   function Movement_Threshold return Float is (Norm_Threshold (Movement_Rate_Dps));

   function Has_Calibration (Offsets : Zero_Offsets) return Boolean is
     (Offsets (X) /= 0 or else Offsets (Y) /= 0 or else Offsets (Z) /= 0);

   --  The nearest whole count of a bias, held to the offset range.
   function Offset (B : Bias) return Zero_Count is
     (Integer'Max (Zero_Count'First, Integer'Min (Zero_Count'Last, Round_Half_Even (B))));

   --  The raw counts aligned to the body frame: the sensor's standard or
   --  custom alignment, then the board rotation when the board is not level.
   procedure Align_Sample (S : State; C : Settings; Sample : Raw_Vector; V : out Aligned_Vector)
     with Post => (for all A in Coordinate => abs V (A) <= Aligned_Bound)
   is
      Raw_V : constant Vector3 := (X => Float (Sample (X)), Y => Float (Sample (Y)), Z => Float (Sample (Z)));
      Rotated : constant Vector3 :=
        (if S.Alignment = Sensor_Alignment.Custom then Apply_Rotation (Raw_V, S.Rotation)
         else Sensor_Alignment.Align (Raw_V, S.Alignment));
      --  A sensor-aligned count is within 2 ** 18; the bound is stated for
      --  the board rotation's precondition.
      Sensor_V : constant Vector3 :=
        (X => Constrain_F (Rotated.X, -2.0 ** 18, 2.0 ** 18),
         Y => Constrain_F (Rotated.Y, -2.0 ** 18, 2.0 ** 18),
         Z => Constrain_F (Rotated.Z, -2.0 ** 18, 2.0 ** 18));
      Aligned_V : constant Vector3 :=
        (if Sensor_Alignment.Standard_Board (C.Board) then Sensor_V
         else Apply_Rotation (Sensor_V, S.Board_Rotation));
   begin
      V := (X => Constrain_F (Aligned_V.X, -Aligned_Bound, Aligned_Bound),
            Y => Constrain_F (Aligned_V.Y, -Aligned_Bound, Aligned_Bound),
            Z => Constrain_F (Aligned_V.Z, -Aligned_Bound, Aligned_Bound));
   end Align_Sample;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
      Negated : constant Sensor_Alignment.Alignment_Angles :=
        (Roll => -C.Custom_Angles.Roll, Pitch => -C.Custom_Angles.Pitch, Yaw => -C.Custom_Angles.Yaw);
   begin
      S := (others => <>);
      S.Alignment := C.Alignment;
      S.Rotation := Sensor_Alignment.Rotation_Matrix (Negated);
      S.Board_Rotation := Sensor_Alignment.Board_Rotation (C.Board);
      S.Zero := C.Zero;
      S.Calibrated := Has_Calibration (C.Zero);
      if C.Odr_Hz /= 0 then
         declare
            Odr_Interval : constant Natural range 0 .. 62_500 := 1_000_000 / C.Odr_Hz;
         begin
            S.Read_Interval_Us := Odr_Interval - 2 * Recheck_Interval_Us - Odr_Interval / 20;
         end;
      else
         S.Read_Interval_Us := 1_000_000 / Task_Rate_Hz;
      end if;
   end Init;

   -----------------------
   -- Start_Calibration --
   -----------------------

   procedure Start_Calibration (S : in out State; Now_Us : Time_Us) is
   begin
      S.Beeper := Calibration_Start;
      S.Calibrating := True;
      S.Calibration_End_Us := Now_Us + Calibration_Wait_Us;
      S.Movement_Started := False;
      S.Estimator.D := (others => Initial_Covariance);
   end Start_Calibration;

   ------------
   -- Update --
   ------------

   --  The sphere fit's intermediates: the regressor from the squared norm
   --  and the components, its projection through the factor, the gains from
   --  the diagonal, the scales of the update, the residual, and the weighted
   --  sums of the innovation. Each range holds a field within the aligned
   --  range by a wide margin (DESIGN.md D30).
   subtype Regressor is Float range -2.0 ** 44 .. 2.0 ** 44;
   type Regressors is array (Parameter_Index) of Regressor;
   subtype Projection is Float range -2.0 ** 52 .. 2.0 ** 52;
   type Projections is array (Parameter_Index) of Projection;
   subtype Gain is Float range -2.0 ** 62 .. 2.0 ** 62;
   type Gains is array (Parameter_Index) of Gain;
   subtype Scale is Float range 0.9 .. 2.0 ** 117;
   subtype Residual is Float range -2.0 ** 63 .. 2.0 ** 63;
   subtype Weighted_Sum is Float range -2.0 ** 64 .. 2.0 ** 64;
   subtype Innovation_Sum is Float range -2.0 ** 110 .. 2.0 ** 110;

   function Regressor_Of (M : Aligned_Vector) return Regressors is
     (0 => (M (X) * M (X) + M (Y) * M (Y)) + M (Z) * M (Z), 1 => M (X), 2 => M (Y), 3 => M (Z));

   function Residual_Of (Phi : Regressors; Theta : Parameters) return Residual is
     ((((1.0 - Phi (0) * Theta (0)) - Phi (1) * Theta (1)) - Phi (2) * Theta (2)) - Phi (3) * Theta (3));

   --  The regressor through the factor, and the gains from the diagonal.
   procedure Project (U : Factor_Matrix; D : Variances; Phi : Regressors; F : out Projections; V : out Gains)
     with Post => (for all I in Parameter_Index => abs V (I) <= 2.0 ** 62)
   is
   begin
      F := (others => 0.0);
      for I in Parameter_Index loop
         for J in 0 .. I loop
            F (I) := Constrain_F (F (I) + U (J, I) * Phi (J), -2.0 ** 52, 2.0 ** 52);
         end loop;
      end loop;
      V := (0 => D (0) * F (0), 1 => D (1) * F (1), 2 => D (2) * F (2), 3 => D (3) * F (3));
   end Project;

   --  The factored covariance update in the reference's order: each scale
   --  from the previous one, the diagonal entry through the ratio of scales,
   --  the gains, and the factor's column.
   procedure Update_Factors
     (E : in out Bias_Estimator; F : Projections; V : Gains; K : out Gains; Alpha_Last : out Scale)
     with Post => E.Lambda = E.Lambda'Old and then E.Theta = E.Theta'Old and then E.B = E.B'Old
   is
      Alpha : Scale := Constrain_F (E.Lambda + V (0) * F (0), 0.9, 2.0 ** 117);
   begin
      K := (others => 0.0);
      E.D (0) := Constrain_F (E.D (0) / Alpha, 0.0, 2.0 ** 10);
      K (0) := V (0);
      for I in 1 .. Parameter_Index'Last loop
         declare
            Previous : constant Scale := Alpha;
         begin
            Alpha := Constrain_F (Previous + V (I) * F (I), 0.9, 2.0 ** 117);
            E.D (I) := Constrain_F (E.D (I) * Constrain_F (Previous / (Alpha * E.Lambda), 0.0, 2.0), 0.0, 2.0 ** 10);
            for J in 0 .. I - 1 loop
               declare
                  DU : constant Float := -(F (I) / Previous) * K (J);
               begin
                  K (J) := Constrain_F (K (J) + V (I) * E.U (J, I), -2.0 ** 62, 2.0 ** 62);
                  E.U (J, I) := Constrain_F (E.U (J, I) + DU, -2.0 ** 24, 2.0 ** 24);
               end;
            end loop;
            K (I) := V (I);
         end;
      end loop;
      Alpha_Last := Alpha;
   end Update_Factors;

   procedure Update_Parameters (Theta : in out Parameters; K : Gains; Alpha : Scale; Err : Residual)
     with Post => (for all I in Parameter_Index => abs Theta (I) <= 2.0 ** 16)
   is
   begin
      for I in Parameter_Index loop
         Theta (I) := Constrain_F (Theta (I) + (K (I) / Alpha) * Err, -2.0 ** 16, 2.0 ** 16);
      end loop;
   end Update_Parameters;

   --  The bias from the parameters, zero while the first parameter is within
   --  2 ** (-100) of zero, where the reference divides by it.
   procedure Update_Bias (E : in out Bias_Estimator)
     with Post => E.Lambda = E.Lambda'Old and then E.Theta = E.Theta'Old
   is
   begin
      for A in Coordinate loop
         if abs E.Theta (0) > 2.0 ** (-100) then
            E.B (A) := Constrain_F (-0.5 * E.Theta (Coordinate'Pos (A) + 1) / E.Theta (0), -2.0 ** 20, 2.0 ** 20);
         else
            E.B (A) := 0.0;
         end if;
      end loop;
   end Update_Bias;

   --  The factor's row I weighted by the gains from column I on.
   function Weighted_Row (U : Factor_Matrix; V : Gains; I : Parameter_Index) return Weighted_Sum
     with Post => abs Weighted_Row'Result <= 2.0 ** 64
   is
      Sum : Weighted_Sum := 0.0;
   begin
      for J in I .. Parameter_Index'Last loop
         Sum := Constrain_F (Sum + U (I, J) * V (J), -2.0 ** 64, 2.0 ** 64);
      end loop;
      return Sum;
   end Weighted_Row;

   function Innovation_Of (U : Factor_Matrix; V : Gains; Phi : Regressors) return Innovation_Sum is
     (((Phi (0) * Weighted_Row (U, V, 0) + Phi (1) * Weighted_Row (U, V, 1)) + Phi (2) * Weighted_Row (U, V, 2))
      + Phi (3) * Weighted_Row (U, V, 3));

   --  One step of the sphere fit on an aligned field: the residual against
   --  the current parameters, the factored covariance update, the parameter
   --  and bias updates, and the forgetting factor from the innovation, kept
   --  where the reference's gain would pass one or divide by zero.
   procedure Estimate_Bias (E : in out Bias_Estimator; M : Aligned_Vector)
     with Post => E.Lambda in Lambda_Min .. 1.0
   is
      Phi   : constant Regressors := Regressor_Of (M);
      Err   : constant Residual := Residual_Of (Phi, E.Theta);
      F     : Projections;
      V     : Gains;
      K     : Gains;
      Alpha : Scale;
      ZN    : Unit_Interval := 1.0;
   begin
      Project (E.U, E.D, Phi, F, V);
      Update_Factors (E, F, V, K, Alpha);
      Update_Parameters (E.Theta, K, Alpha, Err);
      Update_Bias (E);
      declare
         Innovation : constant Innovation_Sum := Innovation_Of (E.U, V, Phi);
      begin
         if Innovation >= 0.0 then
            ZN := Constrain_F (E.Lambda / (E.Lambda + Innovation), 0.0, 1.0);
         end if;
      end;
      E.Lambda := Constrain_F (Lambda_Min + (1.0 - Lambda_Min) * (ZN * ZN), Lambda_Min, 1.0);
   end Estimate_Bias;

   procedure Update (S : in out State; C : Settings; Sample : Raw_Vector; Gyro : Vectors.Vector3; Now_Us : Time_Us) is
      V : Aligned_Vector;
   begin
      S.Beeper := Silence;
      S.Save_Requested := False;
      Align_Sample (S, C, Sample, V);
      if S.Calibrating then
         if Clock.Elapsed (S.Calibration_End_Us, Now_Us) > 0 then
            declare
               RX : constant Float := Gyro.X * Rad_Per_Degree;
               RY : constant Float := Gyro.Y * Rad_Per_Degree;
               RZ : constant Float := Gyro.Z * Rad_Per_Degree;
               Norm_Sq : constant Float := (RX * RX + RY * RY) + RZ * RZ;
            begin
               if not S.Movement_Started and then Norm_Sq > Movement_Threshold then
                  S.Beeper := Movement_Start;
                  S.Zero := (others => 0);
                  S.Movement_Started := True;
                  S.Calibration_End_Us := Now_Us + Calibration_Time_Us;
               end if;
               if S.Movement_Started then
                  Estimate_Bias (S.Estimator, V);
               end if;
            end;
         else
            if S.Movement_Started then
               for A in Coordinate loop
                  S.Zero (A) := Offset (S.Estimator.B (A));
               end loop;
               S.Calibrated := Has_Calibration (S.Zero);
               S.Beeper := Calibrated;
               S.Save_Requested := True;
            else
               S.Beeper := Calibration_Failed;
            end if;
            S.Calibrating := False;
         end if;
      end if;
      for A in Coordinate loop
         S.Field (A) := V (A) - Float (S.Zero (A));
      end loop;
      S.Taps.Updated := True;
      S.Taps.Update_Us := Now_Us;
      S.Taps.Data_Pending := True;
   end Update;

   ----------------
   -- Read_Cycle --
   ----------------

   procedure Read_Cycle
     (S              : in out State;
      C              : Settings;
      Bus_Busy       : Boolean;
      Data_Ready     : Boolean;
      Sample         : Raw_Vector;
      Gyro           : Vectors.Vector3;
      Now_Us         : Time_Us;
      Next_Period_Us : out Natural)
   is
   begin
      S.Taps.Cycle_Set := True;
      S.Taps.Task_Interval_Us := Now_Us - S.Taps.Previous_Task_Us;
      S.Taps.Previous_Task_Us := Now_Us;
      S.Taps.Bus_Busy := Bus_Busy;
      if not Bus_Busy then
         S.Taps.Read_Checked := True;
         S.Taps.No_Data := not Data_Ready;
      end if;
      if Bus_Busy then
         S.Beeper := Silence;
         S.Save_Requested := False;
         Next_Period_Us := Bus_Busy_Interval_Us;
      elsif not Data_Ready then
         S.Beeper := Silence;
         S.Save_Requested := False;
         Next_Period_Us := Recheck_Interval_Us;
      else
         Update (S, C, Sample, Gyro, Now_Us);
         Next_Period_Us := S.Read_Interval_Us;
      end if;
   end Read_Cycle;

end Adaflight.Compass;
