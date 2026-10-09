--  The accelerometer path: raw device counts aligned to the body frame, the
--  zero offsets from the power-on calibration, the attitude lowpass, the
--  jerk, and the magnitudes in units of gravity that the attitude estimator
--  and the crash detection read.
with Interfaces;
with Adaflight.Vectors;
with Adaflight.Filters;
with Adaflight.Sensor_Alignment;

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

   type State is record
      Lowpass_Hz       : Cutoff := 0;
      Filter           : Axis_PT2;
      Rotation         : Vectors.Matrix33 := Vectors.Identity;
      Board_Rotation   : Vectors.Matrix33 := Vectors.Identity;
      One_G_Reciprocal : Float range 0.0 .. 1.0 := 1.0;
      Acc              : Vectors.Vector3;
      Jerk             : Vectors.Vector3;
      Previous         : Vectors.Vector3;
      Magnitude        : Float := 0.0;
      Jerk_Magnitude   : Float := 0.0;
      Zero             : Zero_Offsets := (others => 0);
      Roll_Trim        : Integer_16 := 0;
      Pitch_Trim       : Integer_16 := 0;
      Calibrating      : Cycle_Count := 0;
      Totals           : Sums := (others => 0);
      Updated_Once     : Boolean := False;
   end record
     with Dynamic_Predicate =>
       Vectors.Bounded (State.Rotation, 2.0) and then Vectors.Bounded (State.Board_Rotation, 2.0)
       and then Vectors.Bounded (State.Acc, 2.0 ** 32) and then Vectors.Bounded (State.Previous, 2.0 ** 32)
       and then Vectors.Bounded (State.Jerk, 2.0 ** 60);

   procedure Init (S : out State; C : Settings);

   procedure Start_Calibration (S : in out State)
     with Post => S.Calibrating = Calibration_Cycles;

   function Calibration_Complete (S : State) return Boolean is (S.Calibrating = 0);

   procedure Update (S : in out State; C : Settings; Sample : Raw_Vector)
     with Post => S.Updated_Once;

end Adaflight.Accelerometer;
