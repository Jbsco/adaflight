--  The gyro: the zero offset calibration with its movement check, then per
--  sensor sample the zeroed, aligned, and scaled rate accumulated at the
--  sensor rate with the optional second lowpass as the downsampler, then per
--  loop the RPM notches, the two static notches, the first lowpass with its
--  dynamic cutoff, the dynamic notches, the overflow and yaw spin detection,
--  and the lowpass that feeds the attitude estimate, in the operation order
--  of the reference.

with Interfaces;
with Adaflight.Clock;
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.PID_Config; use Adaflight.PID_Config;
with Adaflight.PID_Filters;
with Adaflight.Sensor_Alignment;
with Adaflight.Vectors;
with Adaflight.Dyn_Notch;
with Adaflight.RPM_Filter;

package Adaflight.Gyro_Filters with SPARK_Mode, Pure is

   subtype Axis is Adaflight.Axes.Axis;

   IMU_Downsample_Cutoff_Hz : constant Float := 200.0;

   --  Raw sensor readings in the sensor's units, as a 16-bit device gives them.
   subtype Raw is Integer range -32_768 .. 32_767;
   type Raw_Vector is array (Axis) of Raw;
   subtype Offset is Float range -32_768.0 .. 32_767.0;
   type Offsets is array (Axis) of Offset;

   --  The gyro sensors a board can carry, which of them run, one sample from
   --  each, and each sensor's alignment to the board.
   Max_Gyros : constant := 4;
   subtype Gyro_Index is Natural range 0 .. Max_Gyros - 1;
   type Gyro_Flags is array (Gyro_Index) of Boolean;
   type Raw_Samples is array (Gyro_Index) of Raw_Vector;
   type Sensor_Placement is record
      Alignment     : Sensor_Alignment.Standard_Alignment := Sensor_Alignment.CW0;
      Custom_Angles : Sensor_Alignment.Alignment_Angles;
   end record;
   type Sensor_Placements is array (Gyro_Index) of Sensor_Placement;

   type Overflow_Check is (No_Check, Yaw_Axis, All_Axes);
   type Spin_Recovery is (Off, On, Auto);
   subtype Spin_Threshold is Integer range 500 .. 1_950;

   type Settings is record
      LPF1_Type        : Lowpass_Kind := PID_Profile.PT1;
      LPF1_Static_Hz   : Hertz := 250;
      LPF1_Dyn_Min_Hz  : Hertz := 250;
      LPF1_Dyn_Max_Hz  : Hertz := 500;
      LPF1_Dyn_Expo    : Natural range 0 .. 10 := 5;
      LPF2_Type        : Lowpass_Kind := PID_Profile.PT1;
      LPF2_Static_Hz   : Hertz := 500;
      Notch1_Hz        : Hertz := 0;
      Notch1_Cutoff    : Hertz := 0;
      Notch2_Hz        : Hertz := 0;
      Notch2_Cutoff    : Hertz := 0;
      Sample_Time_Us   : PID_Config.Loop_Time_Us := 125;
      Loop_Time_Us     : PID_Config.Loop_Time_Us := 125;
      Scale            : Float range 2.0 ** (-10) .. 1.0 := 1.0;
      --  The enabled sensors, which share the scale and the sample time.
      Enabled          : Gyro_Flags := (0 => True, others => False);
      Sensors          : Sensor_Placements;
      Board            : Sensor_Alignment.Board_Angles;
      --  The calibration in hundredths of a second, its movement limit as a
      --  deviation in counts, and the yaw offset in hundredths of a count.
      Calibration_Duration : Positive range 1 .. 3_000 := 125;
      Movement_Threshold   : Natural range 0 .. 200 := 48;
      Offset_Yaw           : Integer range -1_000 .. 1_000 := 0;
      Check_Overflow       : Overflow_Check := All_Axes;
      Overflow_Protected   : Boolean := True;
      Yaw_Spin             : Spin_Recovery := Auto;
      Yaw_Spin_Threshold   : Spin_Threshold := 1_950;
      Dynamic_Notch        : Dyn_Notch.Settings;
      RPM                  : RPM_Filter.Settings;
      Motors               : RPM_Filter.Motor_Count := 4;
      Motor_Telemetry      : Boolean := False;
      Simplified_Filter    : Boolean := True;
      Simplified_Filter_Multiplier : Natural range 10 .. 200 := 100;
      --  The axis whose samples the debug values follow through the stages.
      Debug_Axis           : Axis := Roll;
   end record
     with Dynamic_Predicate =>
       (Settings.LPF1_Dyn_Min_Hz = 0 or else Settings.LPF1_Dyn_Min_Hz <= Settings.LPF1_Dyn_Max_Hz)
       and then (Settings.Notch1_Hz = 0 or else Settings.Notch1_Cutoff < Settings.Notch1_Hz)
       and then (Settings.Notch2_Hz = 0 or else Settings.Notch2_Cutoff < Settings.Notch2_Hz)
       and then Settings.Sample_Time_Us <= Settings.Loop_Time_Us;

   subtype Stage is PID_Filters.Lowpass_Stage;
   type Axis_Stage is array (Axis) of Stage;
   type Axis_Notch is array (Axis) of SVF_Notch;
   type Axis_PT1 is array (Axis) of Filters.PT1;
   type Axis_Stats is array (Axis) of Running_Stats;
   --  The sum of a calibration's counts, with room for the longest duration
   --  at full scale.
   subtype Cal_Total is Float range -8.0e9 .. 8.0e9;
   type Cal_Totals is array (Axis) of Cal_Total;
   subtype Sample_Count is Natural range 0 .. 255;

   --  The calibration cycles of the longest duration at the fastest sampling.
   Max_Calibration_Cycles : constant := 3_000 * 10_000 / PID_Config.Loop_Time_Us'First;
   subtype Cycle_Count is Natural range 0 .. Max_Calibration_Cycles;
   subtype Time_Us is Clock.Time_Us;

   --  Per sensor: the custom alignment's rotation, the zero offset, the
   --  calibration's totals and statistics with its remaining cycles, and the
   --  last zeroed and aligned counts, which the board rotation keeps within
   --  three times 2 ** 20.
   subtype Rotation_Matrix is Vectors.Matrix33
     with Dynamic_Predicate => Vectors.Bounded (Rotation_Matrix, 2.0);
   subtype Aligned_Count is Float range -2.0 ** 22 .. 2.0 ** 22;
   type Aligned_Counts is array (Axis) of Aligned_Count;
   --  A calibration cycle's deviation, bounded for the debug values.
   subtype Deviation is Float range 0.0 .. 2.0 ** 20;
   type Deviations is array (Axis) of Deviation;

   type Sensor_State is record
      Rotation         : Rotation_Matrix := Vectors.Identity;
      Zero             : Offsets := (others => 0.0);
      Cal_Sum          : Cal_Totals := (others => 0.0);
      Cal_Stats        : Axis_Stats;
      Cycles_Remaining : Cycle_Count := 0;
      Aligned          : Aligned_Counts := (others => 0.0);
      --  The debug values' view of the last accumulation: whether a
      --  calibration cycle ran, whether it was the final one, and whether it
      --  failed the movement check.
      Cal_Step         : Boolean := False;
      Cal_Final        : Boolean := False;
      Cal_Failed       : Boolean := False;
      Raw_Roll         : Interfaces.Integer_16 := 0;
      Raw_Pitch        : Interfaces.Integer_16 := 0;
   end record;
   type Sensor_States is array (Gyro_Index) of Sensor_State;

   --  What the debug values read of the last loop: the raw source sensor's
   --  counts, the debug axis's rate after downsampling, after the RPM notches,
   --  after the static filters, and before and after the dynamic notches while
   --  they ran, the dynamic lowpass's last cutoff, and the last calibration
   --  cycle's deviations.
   type Raw_Counts is array (Axis) of Interfaces.Integer_16;
   type Debug_Taps is record
      Raw_Last      : Raw_Counts := (others => 0);
      Downsampled   : Signal := 0.0;
      After_RPM     : Signal := 0.0;
      After_Static  : Signal := 0.0;
      Dyn_In        : Signal := 0.0;
      Dyn_Out       : Signal := 0.0;
      Dyn_Ran       : Boolean := False;
      LPF_Cutoff    : Float range 0.0 .. 2_300.0 := 0.0;
      Cal_Deviation : Deviations := (others => 0.0);
   end record;

   type State is record
      Lowpass1          : Axis_Stage;
      Lowpass2          : Axis_Stage;
      Downsample_Filter : Boolean := False;
      Notch1_Used       : Boolean := False;
      Notch1            : Axis_Notch;
      Notch2_Used       : Boolean := False;
      Notch2            : Axis_Notch;
      IMU_Filter        : Axis_PT1;
      Dyn_LPF           : PID_Config.Dyn_Lowpass := None;
      Dyn_LPF_Min       : Hertz := 0;
      Dyn_LPF_Max       : Hertz := 0;
      Dyn_LPF_Expo      : Natural range 0 .. 10 := 0;
      Rate              : Axis_Signals := (others => 0.0);
      Filtered          : Axis_Signals := (others => 0.0);
      Downsampled       : Axis_Signals := (others => 0.0);
      Sample_Sum        : Axis_Signals := (others => 0.0);
      Samples           : Sample_Count := 0;
      Board_Rotation    : Vectors.Matrix33 := Vectors.Identity;
      Enabled           : Gyro_Flags := (0 => True, others => False);
      Sensors           : Sensor_States;
      First_Arm_Started : Boolean := False;
      Overflow_Detected : Boolean := False;
      Overflow_Time_Us  : Time_Us := 0;
      Yaw_Spin_Enabled  : Boolean := False;
      Yaw_Spin_Limit    : Spin_Threshold := 1_950;
      Yaw_Spin_Detected : Boolean := False;
      Yaw_Spin_Time_Us  : Time_Us := 0;
      Dyn               : Dyn_Notch.State;
      RPM               : RPM_Filter.State;
      Taps              : Debug_Taps;
   end record
     with Dynamic_Predicate => Vectors.Bounded (State.Board_Rotation, 2.0);

   procedure Init (S : out State; C : Settings);

   --  The yaw spin threshold from the setting or from the rates' maximum yaw
   --  rate with an overshoot allowance, as the receiver setup requests.
   procedure Init_Yaw_Spin_Recovery (S : in out State; C : Settings; Max_Yaw_Rate : Natural)
     with Pre => Max_Yaw_Rate <= 10_000;

   function Calibration_Cycles (C : Settings) return Cycle_Count is
     (C.Calibration_Duration * 10_000 / C.Sample_Time_Us);

   --  Starts a calibration of every enabled sensor; the first arming
   --  calibration starts once.
   procedure Start_Calibration (S : in out State; C : Settings; First_Arm : Boolean);

   function Sensor_Calibrated (S : State; I : Gyro_Index) return Boolean is
     (S.Sensors (I).Cycles_Remaining = 0);

   function Calibration_Complete (S : State) return Boolean is
     (for all I in Gyro_Index => not S.Enabled (I) or else Sensor_Calibrated (S, I));

   function First_Arm_Calibration_Running (S : State) return Boolean is
     (S.First_Arm_Started and then not Calibration_Complete (S));

   --  One sample from each sensor. Each enabled sensor with new data runs a
   --  calibration cycle while its calibration runs, else takes its zeroed
   --  and aligned counts; a sensor without new data keeps its last counts.
   --  The rate is then the average of the scaled counts of the enabled
   --  sensors that finished calibrating, and keeps its last value while none
   --  has, followed by the downsampling accumulation of the rate. Finished
   --  is set when a sensor's calibration ends with its movement check
   --  passed, when the reference sounds its tone.
   procedure Accumulate
     (S : in out State; C : Settings; Samples : Raw_Samples; Ready : Gyro_Flags; Finished : out Boolean);

   --  One loop: the downsampled rates through the RPM notches at the motors'
   --  frequencies, then each through the static notches, the lowpass, and
   --  the dynamic notches, the dynamic notch update, the overflow and yaw
   --  spin checks, and the attitude lowpass while no overflow is detected.
   --  The throttle percent gates the dynamic notch's record of its highest
   --  center; the cycle multiplier corrects the RPM notch period to the
   --  loop's measured period.
   procedure Filter
     (S : in out State; C : Settings; Now_Us : Time_Us; Throttle_Percent : Natural;
      Motor_Hz : RPM_Filter.Motor_Frequencies; Dt_Scale : RPM_Filter.Cycle_Multiplier);

   --  The first lowpass follows the throttle, as the mixer requests.
   procedure Update_Dynamic_Lowpass (S : in out State; C : Settings; Throttle : Unit_Interval);

end Adaflight.Gyro_Filters;
