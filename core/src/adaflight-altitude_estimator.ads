--  The altitude estimator: the vertical axis of the position estimate, the
--  accelerometer through the attitude and the barometer against its first
--  reading into the position filter, with the barometer's step gate, the
--  estimate's validity and trust, and the smoothed altitude and climb rate
--  that the displays and the vertical controllers read.
with Interfaces;
with Adaflight.Clock;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters;
with Adaflight.Vectors;
with Adaflight.Position_Filter;

package Adaflight.Altitude_Estimator with SPARK_Mode is
   use type Interfaces.Integer_32;
   subtype Time_Us is Clock.Time_Us;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Altitude_Cm is Position_Filter.Value;

   type Altitude_Source is (Default, Baro_Only, GPS_Only, Rangefinder_Prefer, Rangefinder_Only);

   --  The configuration interface's ranges; the lowpass cutoffs in
   --  hundredths of a hertz.
   type Settings is record
      Source         : Altitude_Source := Default;
      Prefer_Baro    : Natural range 0 .. 100 := 50;
      Altitude_LPF   : Positive range 10 .. 5_000 := 300;
      Derivative_LPF : Positive range 10 .. 5_000 := 300;
   end record;

   --  The position task runs at this rate.
   Task_Rate_Hz : constant := 100;

   --  The accelerometer in device counts with its scale, the attitude
   --  rotation, and the barometer's altitude with the time and interval of
   --  its latest sample.
   subtype Acc_Scale is Float range 2.0 ** (-16) .. 1.0;
   type Inputs is record
      Now_Us              : Time_Us := 0;
      Armed               : Boolean := False;
      Acc                 : Vectors.Vector3 := (0.0, 0.0, 0.0);
      One_G_Reciprocal    : Acc_Scale := 1.0 / 4_096.0;
      Rotation            : Vectors.Matrix33 := Vectors.Identity;
      Baro_Present        : Boolean := False;
      Baro_Altitude_Cm    : Altitude_Cm := 0.0;
      Baro_Sample_Time_Us : Time_Us := 0;
      Baro_Interval_Us    : Integer_32 := 0;
   end record;

   Acc_Bound      : constant := 2.0 ** 16;
   Rotation_Bound : constant := 17.0;

   --  The barometer's step gate: the last reading let through, and the
   --  count of readings rejected since.
   type Step_Gate is record
      Last_Accepted_Cm : Altitude_Cm := 0.0;
      Has_Reference    : Boolean := False;
      Rejects          : Natural range 0 .. 10 := 0;
   end record;

   type State is record
      Up                    : Position_Filter.Filter;
      Baro_Offset_Cm        : Altitude_Cm := 0.0;
      Baro_Offset_Set       : Boolean := False;
      Baro_Data_Available   : Boolean := False;
      Baro_Timestamp_Us     : Time_Us := 0;
      Baro_Hold_Us          : Integer_32 := 0;
      Baro_Gate             : Step_Gate;
      Last_Z_Measurement_Us : Time_Us := 0;
      Valid_Z               : Boolean := False;
      Trust_Z               : Unit_Interval := 0.0;
      Position_Up           : Altitude_Cm := 0.0;
      Velocity_Up           : Altitude_Cm := 0.0;
      Acceleration_Up       : Altitude_Cm := 0.0;
      Altitude_Filter       : Filters.PT2;
      Derivative_Filter     : Filters.PT2;
      Filtered_Altitude_Cm  : Signal := 0.0;
      Display_Altitude_Cm   : Signal := 0.0;
      Filtered_Derivative   : Signal := 0.0;
      Control_Altitude_Cm   : Altitude_Cm := 0.0;
      Control_Derivative    : Altitude_Cm := 0.0;
      Control_Acceleration  : Altitude_Cm := 0.0;
      Was_Armed             : Boolean := False;
   end record;

   procedure Init (S : out State; C : Settings; Armed : Boolean);

   --  One position task: a change of arming resets the filter and the
   --  smoothing; the vertical acceleration, zero while disarmed, and the
   --  prediction; the barometer when a new sample is within its hold
   --  interval, against the offset of its first sample, through the step
   --  gate; the validity and trust; and the smoothed outputs.
   procedure Update (S : in out State; C : Settings; Inp : Inputs)
     with Pre => Vectors.Bounded (Inp.Acc, Acc_Bound) and then Vectors.Bounded (Inp.Rotation, Rotation_Bound);

   --  The displayed altitude to the nearest centimeter.
   function Estimated_Altitude_Cm (S : State) return Integer;

end Adaflight.Altitude_Estimator;
