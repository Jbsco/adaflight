--  The position estimator: three position filters in the earth frame,
--  east, north and up, fed by the accelerometer through the attitude, by
--  the barometer against its first reading behind a step gate, and by the
--  GPS fixes against the origin captured when the horizontal axes start,
--  with the barometer offset drawn slowly toward the GPS, the validity and
--  trust of each plane, the update events the hold tasks take, and the
--  smoothed altitude and climb rate that the displays and the vertical
--  controllers read.
with Interfaces;
with Adaflight.Clock;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters;
with Adaflight.Vectors;
with Adaflight.Position_Filter;

package Adaflight.Position_Estimator with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Time_Us is Clock.Time_Us;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Altitude_Cm is Position_Filter.Value;
   subtype Distance_Cm is Position_Filter.Value;

   type Altitude_Source is (Default, Baro_Only, GPS_Only, Rangefinder_Prefer, Rangefinder_Only);

   --  The horizontal source of the position hold configuration.
   type Horizontal_Source is (Auto, GPS_Alone, Optical_Flow_Alone);

   --  The configuration interface's ranges; the lowpass cutoffs in
   --  hundredths of a hertz.
   type Settings is record
      Source         : Altitude_Source := Default;
      Prefer_Baro    : Natural range 0 .. 100 := 50;
      Altitude_LPF   : Positive range 10 .. 5_000 := 300;
      Derivative_LPF : Positive range 10 .. 5_000 := 300;
      Horizontal     : Horizontal_Source := Auto;
   end record;

   --  The position task runs at this rate.
   Task_Rate_Hz : constant := 100;

   --  Latitude and longitude in ten-millionths of a degree, the altitude in
   --  centimetres.
   type Location is record
      Lat, Lon, Alt_Cm : Integer_32 := 0;
   end record;

   --  The rate of the GPS fixes, zero while unknown; a known rate comes from
   --  a solution interval of at most two and a half seconds.
   subtype Fix_Rate_Hz is Float range 0.0 .. 1_000.0
     with Dynamic_Predicate => Fix_Rate_Hz = 0.0 or else Fix_Rate_Hz >= 0.25;

   --  The cosine of the home latitude as the GPS module approximates it.
   subtype Longitude_Scale is Float range -1.01 .. 1.01;

   --  The east and north distance from one location to another in
   --  centimetres, the longitude difference taken the short way round the
   --  antimeridian and scaled by the cosine of the home latitude.
   procedure Distance_2d (From, To : Location; Cos_Lat : Longitude_Scale; East, North : out Float)
     with Global => null,
          Post   => abs East <= 2.5e9 and then abs North <= 2.5e9;

   --  The accelerometer in device counts with its scale, the attitude
   --  rotation, the barometer's altitude with the time and interval of its
   --  latest sample, the GPS as its module reports it (the sensor present,
   --  the fix, the count of solutions so far, the fix rate, the location,
   --  the north, east and down velocity in centimetres per second, the
   --  horizontal, speed and vertical accuracies in millimetres, and the
   --  longitude scale), and the flight modes that ask for the horizontal
   --  estimate.
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
      GPS_Present         : Boolean := False;
      GPS_Fix             : Boolean := False;
      GPS_Stamp           : Unsigned_16 := 0;
      GPS_Rate_Hz         : Fix_Rate_Hz := 0.0;
      GPS_Location        : Location;
      GPS_Velocity_North  : Integer_16 := 0;
      GPS_Velocity_East   : Integer_16 := 0;
      GPS_Velocity_Down   : Integer_16 := 0;
      GPS_H_Acc           : Unsigned_32 := 0;
      GPS_S_Acc           : Unsigned_32 := 0;
      GPS_V_Acc           : Unsigned_32 := 0;
      Cos_Lat             : Longitude_Scale := 1.0;
      Position_Hold_Mode  : Boolean := False;
      Rescue_Mode         : Boolean := False;
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

   --  The tasks that take the estimator's update events.
   type Consumer is (Altitude_Hold, Position_Hold);
   type Pending_Updates is array (Consumer) of Boolean;

   --  The time constant of the barometer offset's approach to the GPS: the
   --  base of two hundred seconds times the accuracy scale of up to ten.
   subtype Anchor_Tau_S is Float range 200.0 .. 2_000.0;

   --  What the debug values read of the last update: whether one ran with its
   --  earth frame acceleration, the barometer's relative altitude when it
   --  fed, the GPS measurement variances and east and north velocities when
   --  the horizontal plane fed, and the GPS relative altitude and climb rate
   --  when the vertical axis fed. Each tap holds what its site last wrote.
   type Debug_Taps is record
      Updated        : Boolean := False;
      Accel_East     : Float := 0.0;
      Accel_North    : Float := 0.0;
      Accel_Up       : Float := 0.0;
      Baro_Fed       : Boolean := False;
      Baro_Rel_Cm    : Altitude_Cm := 0.0;
      GPS_XY_Fed     : Boolean := False;
      GPS_R_Pos      : Position_Filter.Noise := 0.0;
      GPS_R_Vel      : Position_Filter.Noise := 0.0;
      GPS_Vel_East   : Integer_16 := 0;
      GPS_Vel_North  : Integer_16 := 0;
      GPS_Alt_Fed    : Boolean := False;
      GPS_Rel_Alt_Cm : Altitude_Cm := 0.0;
      GPS_Vel_Up     : Altitude_Cm := 0.0;
   end record;

   type State is record
      Up                     : Position_Filter.Filter;
      East                   : Position_Filter.Filter;
      North                  : Position_Filter.Filter;
      XY_Enabled             : Boolean := False;
      Last_XY_Measurement_Us : Time_Us := 0;
      Baro_Offset_Cm         : Altitude_Cm := 0.0;
      Baro_Offset_Set        : Boolean := False;
      Baro_Data_Available    : Boolean := False;
      Baro_Timestamp_Us      : Time_Us := 0;
      Baro_Hold_Us           : Integer_32 := 0;
      Baro_Gate              : Step_Gate;
      Baro_Raw_Cm            : Altitude_Cm := 0.0;
      Baro_Active            : Boolean := False;
      GPS_Stamp              : Unsigned_16 := 0;
      GPS_Data_Available     : Boolean := False;
      GPS_Received_At_Us     : Time_Us := 0;
      GPS_Hold_Us            : Integer_32 := 0;
      Origin                 : Location;
      Origin_Set             : Boolean := False;
      GPS_Alt_Offset_Cm      : Altitude_Cm := 0.0;
      GPS_Alt_Offset_Set     : Boolean := False;
      GPS_Anchor_Tau_S       : Anchor_Tau_S := 200.0;
      GPS_Anchor_Active      : Boolean := False;
      Last_Z_Measurement_Us  : Time_Us := 0;
      Valid_Z                : Boolean := False;
      Valid_XY               : Boolean := False;
      Trust_Z                : Unit_Interval := 0.0;
      Trust_XY               : Unit_Interval := 0.0;
      Position_East          : Distance_Cm := 0.0;
      Position_North         : Distance_Cm := 0.0;
      Position_Up            : Altitude_Cm := 0.0;
      Velocity_East          : Distance_Cm := 0.0;
      Velocity_North         : Distance_Cm := 0.0;
      Velocity_Up            : Altitude_Cm := 0.0;
      Acceleration_East      : Distance_Cm := 0.0;
      Acceleration_North     : Distance_Cm := 0.0;
      Acceleration_Up        : Altitude_Cm := 0.0;
      Pending                : Pending_Updates := (others => False);
      Altitude_Filter        : Filters.PT2;
      Derivative_Filter      : Filters.PT2;
      Filtered_Altitude_Cm   : Signal := 0.0;
      Display_Altitude_Cm    : Signal := 0.0;
      Filtered_Derivative    : Signal := 0.0;
      Control_Altitude_Cm    : Altitude_Cm := 0.0;
      Control_Derivative     : Altitude_Cm := 0.0;
      Control_Acceleration   : Altitude_Cm := 0.0;
      Was_Armed              : Boolean := False;
      Taps                   : Debug_Taps;
   end record;

   procedure Init (S : out State; C : Settings; Armed : Boolean);

   --  One position task: a change of arming resets the vertical filter and
   --  the smoothing; the horizontal axes start or stop as the modes and the
   --  GPS ask; the linear acceleration, zero on the vertical axis while
   --  disarmed, and the predictions; the GPS fix when new or within its
   --  hold interval, against the origin and the first altitude; the
   --  barometer when a new sample is within its hold interval, against the
   --  offset of its first sample, through the step gate; the barometer
   --  offset drawn toward the GPS; the validity and trust; the events for
   --  the hold tasks; and the smoothed outputs.
   procedure Update (S : in out State; C : Settings; Inp : Inputs)
     with Pre => Vectors.Bounded (Inp.Acc, Acc_Bound) and then Vectors.Bounded (Inp.Rotation, Rotation_Bound);

   --  The horizontal axes started by a consumer, with the origin taken from
   --  the fix at hand, or stopped.
   procedure Enable_XY (S : in out State; Inp : Inputs; Enable : Boolean);

   --  The horizontal state discarded with its origin, which the fix at hand
   --  recaptures.
   procedure Reset_XY (S : in out State; Inp : Inputs);

   --  The update event a consumer takes, once per update.
   procedure Take_Update (S : in out State; Who : Consumer; Taken : out Boolean);

   --  A heading is required for the horizontal estimate while the GPS is
   --  its source.
   function Heading_Required (C : Settings; Inp : Inputs) return Boolean is
     (C.Horizontal /= Optical_Flow_Alone and then Inp.GPS_Present and then Inp.GPS_Fix);

   --  The displayed altitude to the nearest centimeter.
   function Estimated_Altitude_Cm (S : State) return Integer;

end Adaflight.Position_Estimator;
