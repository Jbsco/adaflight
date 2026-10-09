with Adaflight.Maths; use Adaflight.Maths;

package body Adaflight.Accelerometer with SPARK_Mode is
   use Vectors;
   use type Sensor_Alignment.Standard_Alignment;

   --  A calibration total is kept as an integer that the reference adds the
   --  float sample to and truncates back, so the sum follows the same path.
   function Accumulate (Total : Sum; Value : Aligned) return Sum
     with Post => abs Accumulate'Result <= 2 ** 28
   is
      subtype Wide is Float range -2.0 ** 29 .. 2.0 ** 29;
      Total_F   : constant Wide := Float (Total);
      Added     : constant Wide := Total_F + Value;
      Truncated : constant Wide := Float'Truncation (Added);
      Whole     : constant Interfaces.Integer_64 := Interfaces.Integer_64 (Truncated);
   begin
      return Interfaces.Integer_64'Max (Sum'First, Interfaces.Integer_64'Min (Sum'Last, Whole));
   end Accumulate;

   function Offset (Total : Sum) return Zero_Count is
     (Integer (Interfaces.Integer_64'Max (-32_768, Interfaces.Integer_64'Min (Total, 32_767))));

   function Reciprocal (One_G : Counts_Per_G) return Float is (1.0 / Float (One_G))
     with Post => Reciprocal'Result in 0.0 .. 1.0;

   --  The raw counts aligned to the body frame: the sensor's standard or
   --  custom alignment, then the board rotation when the board is not level.
   procedure Align_Sample (S : State; C : Settings; Sample : Raw_Vector; V : out Aligned_Vector)
     with Post => (for all A in Coordinate => abs V (A) <= Aligned_Bound)
   is
      Raw_V : constant Vector3 := (X => Float (Sample (X)), Y => Float (Sample (Y)), Z => Float (Sample (Z)));
      Rotated : constant Vector3 :=
        (if C.Alignment = Sensor_Alignment.Custom then Apply_Rotation (Raw_V, S.Rotation)
         else Sensor_Alignment.Align (Raw_V, C.Alignment));
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
   begin
      S := (Lowpass_Hz       => C.Lowpass_Hz,
            Filter           => (others => (others => <>)),
            Rotation         => Sensor_Alignment.Rotation_Matrix (C.Custom_Angles),
            Board_Rotation   => Sensor_Alignment.Board_Rotation (C.Board),
            One_G_Reciprocal => Reciprocal (C.One_G),
            Acc              => (0.0, 0.0, 0.0),
            Jerk             => (0.0, 0.0, 0.0),
            Previous         => (0.0, 0.0, 0.0),
            Magnitude        => 0.0,
            Jerk_Magnitude   => 0.0,
            Zero             => (others => 0),
            Roll_Trim        => C.Roll_Trim,
            Pitch_Trim       => C.Pitch_Trim,
            Calibrating      => 0,
            Totals           => (others => 0),
            Updated_Once     => False);
      if S.Lowpass_Hz /= 0 then
         declare
            K : constant Unit_Interval :=
              Filters.PT2_Gain (Float (C.Lowpass_Hz), 1.0 / Float (C.Sample_Rate_Hz));
         begin
            for A in Coordinate loop
               Filters.PT2_Init (S.Filter (A), K);
            end loop;
         end;
      end if;
   end Init;

   -----------------------
   -- Start_Calibration --
   -----------------------

   procedure Start_Calibration (S : in out State) is
   begin
      S.Calibrating := Calibration_Cycles;
      S.Totals := (others => 0);
   end Start_Calibration;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out State; C : Settings; Sample : Raw_Vector) is
      V : Aligned_Vector;

      --  One axis after the calibration and the zero offset: the lowpass,
      --  the jerk from the previous value, and the value kept.
      procedure Finish (Value : Aligned; Z : Zero_Count; Use_Filter : Boolean; Rate : Sample_Rate;
                        F : in out Filters.PT2; Prev : in out Float; Out_Value : out Float; Jerk : out Float)
        with Pre  => abs Prev <= Signal_Bound,
             Post => abs Out_Value <= Signal_Bound and then abs Prev <= Signal_Bound
                     and then abs Jerk <= 2.0 ** 60
      is
         Trimmed : Signal := Value - Float (Z);
      begin
         if Use_Filter then
            declare
               Filtered : Signal;
            begin
               Filters.PT2_Apply (F, Trimmed, Filtered);
               Trimmed := Filtered;
            end;
         end if;
         Jerk := (Trimmed - Prev) * Float (Rate);
         Prev := Trimmed;
         Out_Value := Trimmed;
      end Finish;
   begin
      Align_Sample (S, C, Sample, V);
      if S.Calibrating /= 0 then
         for A in Coordinate loop
            if S.Calibrating = Calibration_Cycles then
               S.Totals (A) := 0;
            end if;
            S.Totals (A) := Accumulate (S.Totals (A), V (A));
            V (A) := 0.0;
            S.Zero (A) := 0;
         end loop;
         if S.Calibrating = 1 then
            S.Zero (X) := Offset ((S.Totals (X) + Calibration_Cycles / 2) / Calibration_Cycles);
            S.Zero (Y) := Offset ((S.Totals (Y) + Calibration_Cycles / 2) / Calibration_Cycles);
            S.Zero (Z) := Offset ((S.Totals (Z) + Calibration_Cycles / 2) / Calibration_Cycles
                                  - Interfaces.Integer_64 (C.One_G));
            S.Roll_Trim := 0;
            S.Pitch_Trim := 0;
         end if;
         S.Calibrating := S.Calibrating - 1;
      end if;
      declare
         Use_Filter : constant Boolean := S.Lowpass_Hz /= 0;
      begin
         Finish (V (X), S.Zero (X), Use_Filter, C.Sample_Rate_Hz, S.Filter (X), S.Previous.X, S.Acc.X, S.Jerk.X);
         Finish (V (Y), S.Zero (Y), Use_Filter, C.Sample_Rate_Hz, S.Filter (Y), S.Previous.Y, S.Acc.Y, S.Jerk.Y);
         Finish (V (Z), S.Zero (Z), Use_Filter, C.Sample_Rate_Hz, S.Filter (Z), S.Previous.Z, S.Acc.Z, S.Jerk.Z);
      end;
      S.Magnitude := Norm (S.Acc) * S.One_G_Reciprocal;
      S.Jerk_Magnitude := Norm (S.Jerk) * S.One_G_Reciprocal;
      S.Updated_Once := True;
   end Update;

end Adaflight.Accelerometer;
