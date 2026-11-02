--  The accelerometer path: raw device counts aligned to the body frame, the
--  zero offsets from the power-on calibration, the attitude lowpass, the
--  jerk, the magnitudes in units of gravity that the attitude estimator and
--  the crash detection read, and the in-flight calibration's measurement and
--  save.
with Interfaces;
with Adaflight.Vectors;
with Adaflight.Filters;
with Adaflight.Sensor_Alignment;
with Adaflight.Acc_Inflight;

package Adaflight.Accelerometer with SPARK_Mode is
   use type Interfaces.Integer_64;
   subtype Integer_16 is Interfaces.Integer_16;

   subtype Raw is Integer range -32_768 .. 32_767;
   type Raw_Vector is array (Vectors.Coordinate) of Raw;

   subtype Sample_Rate is Positive range 1 .. 10_000;
   subtype Cutoff is Natural range 0 .. 1_000;
   subtype Counts_Per_G is Positive range 1 .. 65_535;

   type Settings is record
      Sample_Rate_Hz : Sample_Rate := 1_000;
      Lowpass_Hz     : Cutoff := 25;
      Alignment      : Sensor_Alignment.Standard_Alignment := Sensor_Alignment.CW0;
      Custom_Angles  : Sensor_Alignment.Alignment_Angles;
      Board          : Sensor_Alignment.Board_Angles;
      One_G          : Counts_Per_G := 256;
      Roll_Trim      : Integer_16 := 0;
      Pitch_Trim     : Integer_16 := 0;
      --  The in-flight calibration feature.
      Inflight_Calibration : Boolean := False;
   end record;

   Calibration_Cycles : constant := 400;
   subtype Cycle_Count is Natural range 0 .. Calibration_Cycles;

   --  An aligned count: a standard alignment permutes the raw counts, and the
   --  custom and board rotation matrices, whose entries are within two, mix
   --  them twice.
   Aligned_Bound : constant := 2.0 ** 21;
   subtype Aligned is Float range -Aligned_Bound .. Aligned_Bound;
   type Aligned_Vector is array (Vectors.Coordinate) of Aligned;

   subtype Zero_Count is Integer range -32_768 .. 32_767;
   type Zero_Offsets is array (Vectors.Coordinate) of Zero_Count;

   --  A calibration total: 400 cycles of counts within 2 ** 18 stay far
   --  inside this range, where the total saturates.
   subtype Sum is Interfaces.Integer_64 range -(2 ** 28) .. 2 ** 28;
   type Sums is array (Vectors.Coordinate) of Sum;

   type Axis_PT2 is array (Vectors.Coordinate) of Filters.PT2;

   --  The bounds the alignment and the outputs keep, stated on the components
   --  so that a write to one component checks that component alone.
   subtype Rotation_Matrix is Vectors.Matrix33
     with Dynamic_Predicate => Vectors.Bounded (Rotation_Matrix, 2.0);
   subtype Acc_Vector is Vectors.Vector3
     with Dynamic_Predicate => Vectors.Bounded (Acc_Vector, 2.0 ** 32);
   subtype Jerk_Vector is Vectors.Vector3
     with Dynamic_Predicate => Vectors.Bounded (Jerk_Vector, 2.0 ** 60);

   --  Values a debug recorder reads after an update: that one ran, and each
   --  axis's trimmed sample before its filter, which upstream logs ahead of
   --  the filtered one.
   type Debug_Taps is record
      Updated    : Boolean := False;
      Pre_Filter : Acc_Vector := (0.0, 0.0, 0.0);
   end record;

   type State is record
      Lowpass_Hz       : Cutoff := 0;
      Filter           : Axis_PT2;
      Rotation         : Rotation_Matrix := Vectors.Identity;
      Board_Rotation   : Rotation_Matrix := Vectors.Identity;
      One_G_Reciprocal : Float range 0.0 .. 1.0 := 1.0;
      Acc              : Acc_Vector := (0.0, 0.0, 0.0);
      Jerk             : Jerk_Vector := (0.0, 0.0, 0.0);
      Previous         : Acc_Vector := (0.0, 0.0, 0.0);
      Magnitude        : Float := 0.0;
      Jerk_Magnitude   : Float := 0.0;
      Zero             : Zero_Offsets := (others => 0);
      Roll_Trim        : Integer_16 := 0;
      Pitch_Trim       : Integer_16 := 0;
      Calibrating      : Cycle_Count := 0;
      Totals           : Sums := (others => 0);
      Updated_Once     : Boolean := False;
      --  The in-flight calibration's totals, and the offsets and angle trims
      --  kept while it measures.
      Inflight_Totals  : Sums := (others => 0);
      Saved_Zero       : Zero_Offsets := (others => 0);
      Saved_Roll_Trim  : Integer_16 := 0;
      Saved_Pitch_Trim : Integer_16 := 0;
      --  Whether the last update ended a measurement, which sounds the
      --  calibration tone, and whether it saved the offsets, which saves the
      --  configuration.
      Inflight_Ended   : Boolean := False;
      Inflight_Saved   : Boolean := False;
      Taps             : Debug_Taps;
   end record;

   procedure Init (S : out State; C : Settings);

   procedure Start_Calibration (S : in out State)
     with Post => S.Calibrating = Calibration_Cycles;

   function Calibration_Complete (S : State) return Boolean is (S.Calibrating = 0);

   --  One sample, with the in-flight calibration the arming logic shares.
   procedure Update (S : in out State; C : Settings; Sample : Raw_Vector; Cal : in out Acc_Inflight.State)
     with Post => S.Updated_Once;

end Adaflight.Accelerometer;
