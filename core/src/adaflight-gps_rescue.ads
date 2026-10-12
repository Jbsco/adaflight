--  The GPS rescue: the phases from the climb to the return altitude through
--  the turn toward home, the flight home, the descent and the landing, with
--  the sanity checks that count failing seconds, the emergency descent and
--  the disarm, and the targets it hands the autopilot: the altitude with its
--  climb or descent rate, the velocity toward home with its slow start and
--  its slowdown, the heading toward home ramped in, and the forward pitch
--  while the heading is unknown.
with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Vectors;
with Adaflight.Position_Filter;
with Adaflight.Altitude_Control;
with Adaflight.Position_Control;

package Adaflight.GPS_Rescue with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Vector2 is Vectors.Vector2;
   subtype Cm is Position_Filter.Value;

   type Altitude_Mode is (Max_Altitude, Fixed_Altitude, Current_Altitude);
   type Sanity_Checks is (Off, On, Failsafe_Only);

   --  The rescue settings with the autopilot's landing altitude and the GPS
   --  setting that keeps the home point across arming.
   type Settings is record
      Min_Start_Distance_M : Natural range 5 .. 30 := 15;
      Mode                 : Altitude_Mode := Max_Altitude;
      Initial_Climb_M      : Natural range 0 .. 100 := 10;
      Ascend_Rate          : Natural range 50 .. 2_500 := 750;
      Return_Altitude_M    : Natural range 5 .. 1_000 := 30;
      Ground_Speed_Cms     : Natural range 0 .. 3_000 := 750;
      Descent_Distance_M   : Natural range 5 .. 500 := 20;
      Descend_Rate         : Natural range 25 .. 500 := 150;
      Sanity               : Sanity_Checks := Failsafe_Only;
      Min_Sats             : Natural range 5 .. 50 := 8;
      Landing_Altitude_M   : Natural range 0 .. 255 := 4;
      Set_Home_Once        : Boolean := False;
   end record;

   Task_Rate_Hz : constant := 100;

   type Rescue_Phase is (Idle, Initialize, Attain_Alt, Pitch_Forward, Rotate, Fly_Home, Descent, Landing,
                         Emergency_Descent, Do_Nothing);
   type Failure_State is (Healthy, Flyaway, GPS_Lost, Low_Sats, Crash_Flip, Stalled, Too_Close, No_Home_Point,
                          No_Altitude, No_Heading);

   subtype Heading_Decidegrees is Integer range 0 .. 3_599;
   Estimate_Bound : constant := Position_Filter.State_Bound;

   --  One task's inputs: the time, the mode and arming, the GPS as its
   --  module and the estimator report it, the altitude estimate's control
   --  and smoothed values with its validity, the attitude heading, the fix
   --  and home states, the satellite count, the crash recovery, the
   --  receiver link, and the attitude values the altitude controller takes.
   type Inputs is record
      Now_Us                : Unsigned_32 := 0;
      Rescue_Mode           : Boolean := False;
      Armed                 : Boolean := False;
      GPS_Stamp             : Unsigned_16 := 0;
      Heading_Valid         : Boolean := False;
      GPS_Healthy           : Boolean := False;
      Altitude_Control_Cm   : Cm := 0.0;
      Altitude_Filtered_Cm  : Cm := 0.0;
      Altitude_Available    : Boolean := False;
      Valid_XY              : Boolean := False;
      Position, Velocity    : Vector2 := (0.0, 0.0);
      Yaw                   : Heading_Decidegrees := 0;
      GPS_Fix               : Boolean := False;
      GPS_Fix_Home          : Boolean := False;
      Num_Sat               : Unsigned_8 := 0;
      Crash_Recovery_Active : Boolean := False;
      Rx_Receiving          : Boolean := True;
      Vertical_Velocity     : Cm := 0.0;
      Vertical_Acceleration : Cm := 0.0;
      Cos_Tilt              : Altitude_Control.Cosine := 1.0;
   end record;

   function Bounded (Inp : Inputs) return Boolean is
     (Vectors.Bounded (Inp.Position, Estimate_Bound) and then Vectors.Bounded (Inp.Velocity, Estimate_Bound));

   subtype Seconds_Count is Integer range 0 .. 127;
   subtype Slowdown_Cm is Float range 500.0 .. 100_000.0;

   type Vector2_Cm is record
      X, Y : Cm := 0.0;
   end record;
   subtype Heading_Deg is Float range -360.0 .. 360.0;
   subtype Error_Deg is Float range -180.0 .. 180.0;
   subtype Speed_Cms is Float range 0.0 .. 3_000.0;
   subtype Rate_Cms is Float range -8_000.0 .. 8_000.0;

   --  What the rescue intends: the altitudes, the altitude rate, the
   --  distances of descent and slowdown, the failing seconds, the start
   --  attenuators, the heading and speed toward home and the velocity.
   type Intent is record
      Max_Altitude_Cm      : Cm := 0.0;
      Return_Altitude_Cm   : Cm := 0.0;
      Target_Altitude_Cm   : Cm := 0.0;
      Target_Altitude_Vel  : Rate_Cms := 0.0;
      Descent_Distance_Cm  : Cm := 0.0;
      Slowdown_Distance_Cm : Slowdown_Cm := 500.0;
      Seconds_Failing      : Seconds_Count := 0;
      Yaw_Attenuator       : Unit_Interval := 0.0;
      Target_Heading_Deg   : Heading_Deg := 0.0;
      XY_Start_Attenuator  : Unit_Interval := 0.0;
      Target_Speed_Cms     : Speed_Cms := 0.0;
      Target_Velocity      : Position_Control.Vector2_Velocity;
      Initial_Climb_Cm     : Cm := 0.0;
   end record;

   --  What the rescue sees: the GPS health, the heading, new fixes, the
   --  estimate, the distance and speed, the headings and their error.
   type Sensor is record
      GPS_Healthy           : Boolean := False;
      Heading_OK            : Boolean := True;
      New_GPS_Data          : Boolean := False;
      Position_XY_Available : Boolean := False;
      Aircraft_Heading_Deg  : Float range 0.0 .. 360.0 := 0.0;
      Error_Angle_Deg       : Error_Deg := 0.0;
      Distance_To_Home_Cm   : Cm := 0.0;
      Current_Speed_Cms     : Cm := 0.0;
      Current_Velocity      : Vector2_Cm;
      Current_Position      : Vector2_Cm;
      Current_Altitude_Cm   : Cm := 0.0;
   end record;

   type State is record
      Phase                 : Rescue_Phase := Idle;
      Failure               : Failure_State := Healthy;
      Sense                 : Sensor;
      Want                  : Intent;
      Is_Available          : Boolean := True;
      Is_OK                 : Boolean := True;
      GPS_Stamp             : Unsigned_16 := 0;
      Prev_Altitude_Cm      : Cm := 0.0;
      Prev_Target_Alt_Cm    : Cm := 0.0;
      Prev_Distance_Cm      : Cm := 0.0;
      Seconds_Low_Sats      : Seconds_Count := 0;
      Seconds_Doing_Nothing : Seconds_Count := 0;
      Last_Sanity_Check_Us  : Unsigned_32 := 0;
      Return_Altitude_Low   : Boolean := True;
   end record;

   --  The distances from the settings; the rescue is available and healthy
   --  until a task says otherwise.
   procedure Init (S : out State; C : Settings);

   --  One rescue task over the autopilot's altitude controller and
   --  horizontal controller, which the caller owns. Disarm asks the core to
   --  disarm; Arming_Disabled asks it to disable arming by the switch.
   procedure Update
     (S : in out State; C : Settings; Inp : Inputs;
      AC : Altitude_Control.Settings; Altitude : in out Altitude_Control.State;
      PC : Position_Control.Settings; P_Inp : Position_Control.Inputs; Position : in out Position_Control.State;
      Disarm : out Boolean; Arming_Disabled : out Boolean)
     with Pre => Bounded (Inp) and then Position_Control.Bounded (P_Inp);

end Adaflight.GPS_Rescue;
