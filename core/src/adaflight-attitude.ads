--  Attitude estimation: the quaternion of the body frame relative to the
--  earth frame, driven by the gyro rates and corrected toward the
--  accelerometer's gravity direction with proportional and integral
--  feedback, the rotation matrix and Euler angles derived from it, the gain
--  schedule that reconverges after a disarm, and the throttle correction for
--  the tilt angle.
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

   subtype Correction is Integer range -150 .. 150;

   --  Rotation rows are the earth axes north, west, and up as X, Y, and Z;
   --  columns are the body axes.
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
   end record
     with Dynamic_Predicate =>
       Vectors.Bounded (State.Rotation, Matrix_Bound)
       and then Vectors.Bounded (State.Integral, Signal_Bound);

   --  Gyro rates in degrees per second, accelerometer readings in device
   --  units, and the compass field in counts within these bounds.
   Rate_Bound : constant := 2.0 ** 13;
   Acc_Bound  : constant := 2.0 ** 16;
   Mag_Bound  : constant := 2.0 ** 22;

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
      Angle_Mode    : Boolean
   ) with Pre => Vectors.Bounded (Gyro, Rate_Bound)
                 and then Vectors.Bounded (Acc, Acc_Bound)
                 and then Acc_Magnitude in 0.0 .. 1.0e3
                 and then Vectors.Bounded (Mag, Mag_Bound);

   function Cos_Tilt (S : State) return Float is
     (S.Rotation (Vectors.Z, Vectors.Z));

   function Sin_Pitch (S : State) return Float is
     (-S.Rotation (Vectors.Z, Vectors.X));

end Adaflight.Attitude;
