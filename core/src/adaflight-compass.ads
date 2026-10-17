--  The compass: the raw field aligned to the body frame through the
--  sensor's alignment and the board rotation, the calibration that waits
--  for the craft to move and then fits the hard-iron bias with a recursive
--  least squares estimator on the field's sphere, the zero offsets
--  subtracted from every read, and the task's read cycle.
with Adaflight.Clock;
with Adaflight.Vectors;
with Adaflight.Sensor_Alignment;

package Adaflight.Compass with SPARK_Mode is
   subtype Time_Us is Clock.Time_Us;
   subtype Coordinate is Vectors.Coordinate;

   subtype Raw is Integer range -32_768 .. 32_767;
   type Raw_Vector is array (Coordinate) of Raw;
   subtype Zero_Count is Integer range -32_768 .. 32_767;
   type Zero_Offsets is array (Coordinate) of Zero_Count;

   --  A device's output data rate in hertz, none at zero; the drivers' rates
   --  lie within this range.
   subtype Output_Rate is Natural range 0 .. 400
     with Static_Predicate => Output_Rate in 0 | 16 .. 400;

   type Settings is record
      Alignment     : Sensor_Alignment.Standard_Alignment := Sensor_Alignment.Default;
      Custom_Angles : Sensor_Alignment.Alignment_Angles;
      Board         : Sensor_Alignment.Board_Angles;
      Zero          : Zero_Offsets := (others => 0);
      Odr_Hz        : Output_Rate := 0;
   end record;

   --  An aligned count: a standard alignment permutes the raw counts, and
   --  the custom and board rotation matrices, whose entries are within two,
   --  mix them twice. A zeroed count adds the offset's range.
   Aligned_Bound : constant := 2.0 ** 21;
   subtype Aligned is Float range -Aligned_Bound .. Aligned_Bound;
   type Aligned_Vector is array (Coordinate) of Aligned;
   subtype Field_Count is Float range -2.0 ** 22 .. 2.0 ** 22;
   type Field_Vector is array (Coordinate) of Field_Count;

   type Beep is (Silence, Calibration_Start, Movement_Start, Calibrated, Calibration_Failed);

   --  The bias estimator: the four parameters of the sphere fit, the unit
   --  upper triangular factor and the diagonal of its covariance, the
   --  forgetting factor, and the bias the parameters give. The bounds hold
   --  a field within the aligned range by a wide margin (DESIGN.md D30).
   Lambda_Min         : constant Float := 0.95;
   Initial_Covariance : constant Float := 100.0;
   subtype Parameter_Index is Natural range 0 .. 3;
   subtype Estimate is Float range -2.0 ** 16 .. 2.0 ** 16;
   type Parameters is array (Parameter_Index) of Estimate;
   subtype Factor_Entry is Float range -2.0 ** 24 .. 2.0 ** 24;
   type Factor_Matrix is array (Parameter_Index, Parameter_Index) of Factor_Entry;
   subtype Variance is Float range 0.0 .. 2.0 ** 10;
   type Variances is array (Parameter_Index) of Variance;
   subtype Forgetting is Float range 0.9 .. 1.0;
   subtype Bias is Float range -2.0 ** 20 .. 2.0 ** 20;
   type Biases is array (Coordinate) of Bias;

   Factor_Identity : constant Factor_Matrix :=
     ((1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 1.0, 0.0), (0.0, 0.0, 0.0, 1.0));

   type Bias_Estimator is record
      Lambda : Forgetting := Lambda_Min;
      B      : Biases := (others => 0.0);
      Theta  : Parameters := (others => 0.0);
      U      : Factor_Matrix := Factor_Identity;
      D      : Variances := (others => Initial_Covariance);
   end record;

   subtype Rotation_Matrix is Vectors.Matrix33
     with Dynamic_Predicate => Vectors.Bounded (Rotation_Matrix, 2.0);

   type State is record
      Alignment          : Sensor_Alignment.Standard_Alignment := Sensor_Alignment.Default;
      Rotation           : Rotation_Matrix := Vectors.Identity;
      Board_Rotation     : Rotation_Matrix := Vectors.Identity;
      Field              : Field_Vector := (others => 0.0);
      Zero               : Zero_Offsets := (others => 0);
      Calibrated         : Boolean := False;
      Calibrating        : Boolean := False;
      Movement_Started   : Boolean := False;
      Calibration_End_Us : Time_Us := 0;
      Estimator          : Bias_Estimator;
      Beeper             : Beep := Silence;
      Save_Requested     : Boolean := False;
      --  The wait after a read before the next, in microseconds.
      Read_Interval_Us   : Natural range 0 .. 65_535 := 25_000;
   end record;

   --  The squared gyro norm, in radians per second squared, that starts the
   --  fit once a calibration waits for movement.
   function Movement_Threshold return Float;

   --  The alignment, the rotation from the negated custom angles, the board
   --  rotation, the estimator at its initial covariance, the stored zero,
   --  which counts as a calibration when any offset is nonzero, and the read
   --  interval: the output data period less two rechecks and a twentieth of
   --  itself, or the task period of 40 Hz for a device without a rate.
   procedure Init (S : out State; C : Settings);

   --  Starts the wait for movement and resets the estimator's covariance.
   procedure Start_Calibration (S : in out State; Now_Us : Time_Us);

   function Calibration_Complete (S : State) return Boolean is (not S.Calibrating);

   --  A calibrated compass whose last read is not all zeros.
   function Enabled_And_Calibrated (S : State) return Boolean is
     (S.Calibrated
      and then (S.Field (Vectors.X) /= 0.0 or else S.Field (Vectors.Y) /= 0.0 or else S.Field (Vectors.Z) /= 0.0));

   --  One read: the aligned field; during a calibration, the fit from the
   --  moment the gyro norm passes the threshold until the window ends, when
   --  the rounded bias becomes the zero and a save is requested; then the
   --  zero subtracted. The beeper request and the save request are set for
   --  this read only. The gyro rates are in degrees per second.
   procedure Update (S : in out State; C : Settings; Sample : Raw_Vector; Gyro : Vectors.Vector3; Now_Us : Time_Us)
     with Pre => Vectors.Bounded (Gyro, 2.0 ** 32);

   --  One call of the compass task: with the bus busy it comes back in 500 us
   --  and without new data in 1 ms, making no read; with new data it reads
   --  the sample and comes back after the read interval. Every call ignores
   --  the task's execution rate.
   procedure Read_Cycle
     (S              : in out State;
      C              : Settings;
      Bus_Busy       : Boolean;
      Data_Ready     : Boolean;
      Sample         : Raw_Vector;
      Gyro           : Vectors.Vector3;
      Now_Us         : Time_Us;
      Next_Period_Us : out Natural)
     with Pre => Vectors.Bounded (Gyro, 2.0 ** 32);

end Adaflight.Compass;
