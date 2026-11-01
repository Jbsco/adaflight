--  Attitude estimation: the quaternion of the body frame relative to the
--  earth frame, driven by the gyro rates and corrected toward the
--  accelerometer's gravity direction with proportional and integral
--  feedback, the rotation matrix and Euler angles derived from it, the gain
--  schedule that reconverges after a disarm, the throttle correction for the
--  tilt angle, the headfree frame turned from the heading at its offset, and
--  the heading taken from the GPS course with the confidence that makes it
--  good to fly by.
with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Vectors;

package Adaflight.Attitude with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;

   type Settings is record
      DCM_Kp                    : Natural range 0 .. 32_000 := 2_500;
      DCM_Ki                    : Natural range 0 .. 32_000 := 0;
      Small_Angle               : Natural range 0 .. 180 := 25;
      Throttle_Correction_Angle : Positive range 1 .. 900 := 800;
      Throttle_Correction_Value : Natural range 0 .. 150 := 0;
      Mag_Declination           : Integer range -300 .. 300 := 0;
   end record;

   subtype Gain is Float range 0.0 .. 4.0;
   subtype Angle_Scale is Float range 0.0 .. 6.0e5;
   subtype Correction_Value is Natural range 0 .. 150;
   subtype Unit_Vector2 is Vectors.Vector2
     with Dynamic_Predicate => Vectors.Bounded (Unit_Vector2, 1.0);

   type Config is record
      Kp                   : Gain := 0.25;
      Ki                   : Gain := 0.0;
      Small_Angle_Cos      : Cosine := 0.0;
      Throttle_Angle_Scale : Angle_Scale := 0.0;
      Throttle_Angle_Value : Correction_Value := 0;
      --  Magnetic north in the ground plane, north and west, turned by the
      --  declination.
      North                : Unit_Vector2 := (X => 1.0, Y => 0.0);
   end record;

   function Configure (S : Settings) return Config;

   --  A normalized quaternion component is within one plus rounding; the
   --  bound of two is where the estimator saturates it (DESIGN.md D17).
   Component_Bound : constant := 2.0;
   subtype Component is Float range -Component_Bound .. Component_Bound;

   type Quaternion is record
      W : Component := 1.0;
      X : Component := 0.0;
      Y : Component := 0.0;
      Z : Component := 0.0;
   end record;

   Identity : constant Quaternion := (W => 1.0, X => 0.0, Y => 0.0, Z => 0.0);

   --  Rotation matrix entries from components within two.
   Matrix_Bound : constant := 17.0;

   subtype Decidegrees is Integer range -1_800 .. 1_800;
   subtype Pitch_Decidegrees is Integer range -900 .. 900;
   subtype Heading_Decidegrees is Integer range 0 .. 3_599;

   type Angles is record
      Roll  : Decidegrees := 0;
      Pitch : Pitch_Decidegrees := 0;
      Yaw   : Heading_Decidegrees := 0;
   end record;

   type Phase is (Armed, Restart, Quiet, Reset, Disarmed);

   --  The yaw rate suppression and the GPS heading confidence are held at
   --  bounds no update interval within a second reaches (DESIGN.md D435).
   Suppression_Bound : constant := 2.0 ** 14;
   subtype Suppression is Float range -Suppression_Bound .. 1.0;
   Confidence_Bound : constant := 2.0 ** 60;
   subtype Confidence is Float range -Confidence_Bound .. Confidence_Bound;

   subtype Correction is Integer range -150 .. 150;

   --  Rotation rows are the earth axes north, west, and up as X, Y, and Z;
   --  columns are the body axes.
   --  What the debug values read of the updates: whether the GPS course
   --  weighed on the heading, and its error sine when it did.
   type Debug_Taps is record
      Course_Err_Set : Boolean := False;
      Course_Error   : Float range -2.0 .. 2.0 := 0.0;
      Confidence     : Float := 0.0;
      Usable         : Boolean := False;
   end record;

   type State is record
      Q                   : Quaternion := Identity;
      Rotation            : Vectors.Matrix33 := Vectors.Identity;
      Integral            : Vectors.Vector3;
      Previous_Time       : Time_Us := 0;
      Reset_Phase         : Phase := Disarmed;
      Phase_Timeout       : Time_Us := 0;
      Euler               : Angles;
      Established         : Boolean := False;
      Throttle_Correction : Correction := 0;
      --  The heading at the last headfree offset as a turn about the vertical,
      --  the headfree attitude from the last turn into the headfree frame, and
      --  the quaternion the attitude reports, the headfree one in headfree mode.
      Headfree_Offset     : Quaternion := Identity;
      Headfree            : Quaternion := Identity;
      Reported            : Quaternion := Identity;
      --  The GPS course: whether a fix past the course speed set the heading,
      --  the yaw rate suppression's last value, the heading confidence, and
      --  whether the GPS heading is good to fly by.
      Course_Set          : Boolean := False;
      Yaw_Suppression     : Suppression := 0.0;
      Heading_Confidence  : Confidence := 0.0;
      GPS_Heading         : Boolean := False;
      Taps                : Debug_Taps;
   end record
     with Dynamic_Predicate =>
       Vectors.Bounded (State.Rotation, Matrix_Bound)
       and then Vectors.Bounded (State.Integral, Signal_Bound);

   --  Gyro rates in degrees per second, accelerometer readings in device
   --  units, and the compass field in counts within these bounds.
   Rate_Bound : constant := 2.0 ** 13;
   Acc_Bound  : constant := 2.0 ** 16;
   Mag_Bound  : constant := 2.0 ** 22;

   --  The GPS as the attitude reads it: a fix from a present module with
   --  more than the minimum satellites, its ground speed in centimetres per
   --  second and its course in decidegrees, the latest filtered yaw rate in
   --  degrees per second, and whether the craft is a fixed wing.
   Min_Satellites : constant := 4;
   type Course_Inputs is record
      Usable       : Boolean := False;
      Ground_Speed : Natural range 0 .. 65_535 := 0;
      Course       : Natural range 0 .. 3_599 := 0;
      Yaw_Rate     : Float range -Rate_Bound .. Rate_Bound := 0.0;
      Fixed_Wing   : Boolean := False;
   end record;

   procedure Init (S : out State);

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
   ) with Pre => Vectors.Bounded (Gyro, Rate_Bound)
                 and then Vectors.Bounded (Acc, Acc_Bound)
                 and then Acc_Magnitude in 0.0 .. 1.0e3
                 and then Vectors.Bounded (Mag, Mag_Bound);

   --  The simulator target's attitude: a packet's quaternion sets it, the
   --  older bridges' rotation keeps two entries of mirrored sign, and the
   --  update corrects the throttle angle and holds the GPS heading usable
   --  with no estimate.
   procedure Set_From_Simulator (S : in out State; Q : Quaternion; Legacy_Bridge : Boolean; Headfree_Mode : Boolean);
   procedure Update_Simulated (S : in out State; C : Config; Armed : Boolean; Angle_Mode : Boolean);

   --  Sets the headfree offset to the current heading when roll and pitch are
   --  both within 45 degrees.
   procedure Set_Headfree_Offset (S : in out State; Set : out Boolean);

   --  Turns an earth frame vector into the headfree frame, the attitude turned
   --  back by the heading at the offset.
   Headfree_Bound : constant := 2.0 ** 10;
   procedure Headfree_To_Body (S : in out State; V : in out Vectors.Vector3)
     with Pre  => Vectors.Bounded (V, Headfree_Bound),
          Post => Vectors.Bounded (V, 48.0 * Headfree_Bound);

   --  The heading is good to fly by with a calibrated compass, or once the
   --  GPS course has matched it long enough.
   function Heading_Valid (S : State; Compass_Calibrated : Boolean) return Boolean is
     (Compass_Calibrated or else S.GPS_Heading);

   function Cos_Tilt (S : State) return Float is
     (S.Rotation (Vectors.Z, Vectors.Z));

   function Sin_Pitch (S : State) return Float is
     (-S.Rotation (Vectors.Z, Vectors.X));

end Adaflight.Attitude;
