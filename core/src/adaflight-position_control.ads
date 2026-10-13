--  The autopilot's horizontal control: the hold point captured and braked
--  onto, the sticks' velocity flown, the navigator's target tracked, walked
--  onto or flown by its velocity, the distance error real against the
--  target or virtual from the velocity error with its integral under the
--  mode's policy, the proportional, integral, damping, acceleration and
--  feedforward terms summed into a lean in the body frame within the angle
--  limit, the fence that fails a hold flying away with one re-anchor per
--  healthy stretch, and the yaw controller that holds the heading, steers
--  to the rescue's target, or turns the nose along the course or at the
--  navigator's target.
with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters;
with Adaflight.Vectors;
with Adaflight.Position_Filter;
with Adaflight.Position_Nav;

package Adaflight.Position_Control with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Vector2 is Vectors.Vector2;
   subtype Cm is Position_Filter.Value;
   subtype Navigator is Position_Nav.Navigator;

   --  The nose on a navigation leg: along the course, at the target, along
   --  the course when the craft flies fast enough and at the target
   --  otherwise, or held where it is; the damper belongs to the wing and
   --  holds it too.
   type Yaw_Mode is (Yaw_Velocity, Yaw_Bearing, Yaw_Hybrid, Yaw_Fixed, Yaw_Dampener);

   --  The configuration interface's ranges: the five position gains, the
   --  feedforward cutoff in tenths of a hertz, the braking exit speed in
   --  percent of the entry speed, the lean limit in degrees, the drag
   --  coefficient, the velocity at full stick in centimetres per second,
   --  the yaw stick deadband in receiver units, the yaw gain and rate limit
   --  in degrees per second, the yaw reversal, the nose on a navigation leg,
   --  the ground speed that gives the course a direction in centimetres per
   --  second, the lean the velocity buildup may reach in degrees, and
   --  whether a rescue flies as a flight plan through the navigation modes.
   subtype Gain_Setting is Natural range 0 .. 200;
   type Settings is record
      Position_P           : Gain_Setting := 30;
      Position_I           : Gain_Setting := 30;
      Position_D           : Gain_Setting := 30;
      Position_A           : Gain_Setting := 30;
      Position_F           : Gain_Setting := 30;
      Position_Cutoff      : Positive range 10 .. 50 := 30;
      Stop_Threshold       : Positive range 5 .. 50 := 10;
      Max_Angle            : Positive range 10 .. 70 := 50;
      Drag_Coefficient     : Natural range 0 .. 100 := 50;
      Max_Velocity         : Positive range 100 .. 5_000 := 500;
      Stick_Deadband       : Natural range 0 .. 500 := 50;
      Yaw_P                : Gain_Setting := 30;
      Max_Yaw_Rate         : Positive range 10 .. 250 := 150;
      Yaw_Reversed         : Boolean := False;
      Nav_Yaw_Mode         : Yaw_Mode := Yaw_Velocity;
      Min_Forward_Velocity : Positive range 10 .. 500 := 300;
      Buildup_Max_Pitch    : Natural range 0 .. 20 := 8;
      Rescue_Plan          : Boolean := False;
   end record;

   Task_Rate_Hz        : constant := 100;
   Nominal_Interval_Us : constant := 1_000_000 / Task_Rate_Hz;

   subtype Heading_Decidegrees is Integer range 0 .. 3_599;
   subtype Setpoint_Dps is Float range -3_000.0 .. 3_000.0;
   subtype Max_Rate_Dps is Float range 1.0 .. 5_000.0;
   subtype Stick_Command is Float range -500.0 .. 500.0;
   subtype Degrees is Float range -720.0 .. 720.0;
   subtype Pitch_Degrees is Float range -90.0 .. 90.0;
   subtype Rate_Limit_Dps is Float range 0.0 .. 1_000.0;

   --  One task's inputs: the arming and failsafe state, the flight modes,
   --  the task's measured interval (nonpositive before the first
   --  measurement), the estimate's east and north position, velocity and
   --  acceleration, its altitude and vertical speed, with its horizontal
   --  validity and heading requirement, the attitude's heading and its
   --  validity, and the receiver's pitch and roll setpoint rates with their
   --  maxima, the yaw command and the pitch and roll deflections.
   type Inputs is record
      Armed, Failsafe_Active                               : Boolean := False;
      Pos_Hold_Mode, Rescue_Mode, Autopilot_Mode, Mag_Mode : Boolean := False;
      Interval_Us                                          : Integer_32 := 0;
      Position, Velocity, Acceleration                     : Vector2 := (0.0, 0.0);
      Position_Up, Velocity_Up                             : Cm := 0.0;
      Valid_XY, Heading_Required                           : Boolean := False;
      Yaw                                                  : Heading_Decidegrees := 0;
      Heading_Valid                                        : Boolean := False;
      Setpoint_Pitch, Setpoint_Roll                        : Setpoint_Dps := 0.0;
      Max_Rate_Pitch, Max_Rate_Roll                        : Max_Rate_Dps := 1_000.0;
      Yaw_Command                                          : Stick_Command := 0.0;
      Deflection_Pitch, Deflection_Roll                    : Unit_Interval := 0.0;
   end record;

   Estimate_Bound : constant := Position_Filter.State_Bound;

   function Bounded (Inp : Inputs) return Boolean is
     (Vectors.Bounded (Inp.Position, Estimate_Bound) and then Vectors.Bounded (Inp.Velocity, Estimate_Bound)
      and then Vectors.Bounded (Inp.Acceleration, Estimate_Bound));

   --  The estimate the navigator updates from.
   function Nav_Estimate (Inp : Inputs) return Position_Nav.Estimate is
     ((Position => (East => Inp.Position.X, North => Inp.Position.Y, Up => Inp.Position_Up),
       Velocity => (East => Inp.Velocity.X, North => Inp.Velocity.Y, Up => Inp.Velocity_Up)))
     with Pre => Bounded (Inp);

   type Anchor_Mode is (Anchor_Off, Anchor_Hold);
   type Integral_Policy is (Accumulate, Freeze, Zero);
   type Control_Mode is (Settled_Hold, Braking, Stick_Velocity, Nav_Track, Nav_Point, Nav_Velocity, Rescue_Velocity);

   subtype Gain is Float range 0.0 .. 8.0;
   type Gains is record
      Kp, Ki, Kd, Ka, Kf, K_Drag : Gain := 0.0;
   end record;

   --  Target velocities in centimetres per second, within what a full stick
   --  at the fastest rate commands; terms in degrees of lean.
   subtype Velocity_Cm is Float range -2.0 ** 26 .. 2.0 ** 26;
   subtype Angle_Term is Float range -2.0 ** 48 .. 2.0 ** 48;
   subtype Seconds is Float range 0.0 .. 1.0E6;
   subtype Interval_S is Float range 0.0025 .. 0.04;

   --  The task interval in seconds, the nominal one before a measurement,
   --  held between a quarter and four times the nominal.
   function Interval (Interval_Us : Integer_32) return Interval_S;

   type Vector2_Cm is record
      X, Y : Cm := 0.0;
   end record;
   --  Targets in centimetres, out to the navigator's bound in metres.
   subtype Target_Cm is Float range -2.0 ** 25 .. 2.0 ** 25;
   type Vector2_Target is record
      X, Y : Target_Cm := 0.0;
   end record;
   type Unit_Vector2 is record
      X, Y : Cosine := 0.0;
   end record;
   type Vector2_Velocity is record
      X, Y : Velocity_Cm := 0.0;
   end record;

   type State is record
      Pid                     : Gains;
      Yaw_Kp                  : Float range 0.0 .. 12.0 := 1.8;
      Max_Angle               : Float range 10.0 .. 70.0 := 50.0;
      Lpf_Dt_S                : Interval_S := 0.01;
      F_East, F_North         : Filters.PT3;
      Target_Position         : Vector2_Target;
      Target_Velocity         : Vector2_Velocity;
      Previous_Target         : Vector2_Velocity;
      Hold_Start              : Vector2_Cm;
      Distance_Error          : Vector2_Cm;
      Distance_Integral       : Vector2_Cm;
      Previous_Velocity       : Vector2_Cm;
      Position_Held           : Boolean := False;
      Abort_Requested         : Boolean := False;
      Heading_Recovery        : Boolean := False;
      Heading_Recovery_Pitch  : Pitch_Degrees := 0.0;
      Force_Level_Park        : Boolean := False;
      Was_Angle_Saturated     : Boolean := False;
      Sanity_Distance         : Cm := 2_000.0;
      Sanity_Violation_S      : Seconds := 0.0;
      Violation_Free_S        : Seconds := 0.0;
      Sanity_Retry_Used       : Boolean := False;
      Sticks_Active           : Boolean := False;
      Was_Sticks_Active       : Boolean := False;
      Speed_XY                : Cm := 0.0;
      Speed_Trend             : Cm := 0.0;
      Speed_Slowing           : Boolean := False;
      Braking                 : Boolean := False;
      Braking_Time_S          : Float range 0.0 .. 1.2 := 0.0;
      Braking_Entry_Direction : Unit_Vector2;
      Braking_Exit_Speed      : Cm := 0.0;
      Anchor                  : Anchor_Mode := Anchor_Off;
      I_Policy                : Integral_Policy := Accumulate;
      Mode                    : Control_Mode := Settled_Hold;
      Nav_Active              : Boolean := False;
      Was_Nav_Active          : Boolean := False;
      Nav_Anchored            : Boolean := False;
      Nav_Anchor_Seq          : Unsigned_32 := 0;
      Nav_Point_Valid         : Boolean := False;
      Nav_Point_Seq           : Unsigned_32 := 0;
      Nav_Point_Reference     : Vector2_Target;
      Nav_Feedforward_Seq     : Unsigned_32 := 0;
      Nav_Override_Valid      : Boolean := False;
      Nav_Override_Deg        : Degrees := 0.0;
      Yaw_Course_Valid        : Boolean := False;
      Yaw_Rate_Dps            : Float range -1_000.0 .. 1_000.0 := 0.0;
      Yaw_Active              : Boolean := False;
      Yaw_Attenuator          : Unit_Interval := 0.0;
      Yaw_Rate_Limit          : Rate_Limit_Dps := 0.0;
      Yaw_Disable_Reason      : Natural range 0 .. 11 := 0;
      Hold_Heading_Valid      : Boolean := False;
      Hold_Heading_Deg        : Degrees := 0.0;
      External_Yaw_Target     : Degrees := 0.0;
      Angle_Roll              : Float range -90.0 .. 90.0 := 0.0;
      Angle_Pitch             : Float range -90.0 .. 90.0 := 0.0;
   end record;

   --  The gains from the settings, the feedforward filters at the nominal
   --  interval, and the yaw controller stood down.
   procedure Init (S : out State; C : Settings);

   --  The controller started by a hold: everything back to its start, the
   --  navigator reset, the hold point captured with its braking, and the
   --  estimator asked to run the horizontal axes.
   procedure Reset_Position_Control
     (S : in out State; C : Settings; Inp : Inputs; N : in out Navigator; Enable_XY : out Boolean)
     with Pre => Bounded (Inp);

   --  The hold point recaptured where the craft is, through the braking
   --  capture, with the fence sized to the ground speed.
   procedure Init_Position_Hold (S : in out State; C : Settings; Inp : Inputs)
     with Pre => Bounded (Inp);
   procedure Reanchor (S : in out State; C : Settings; Inp : Inputs)
     with Pre => Bounded (Inp);

   --  A position task up to the navigator's update: the feedforward filters
   --  retuned and the checks that fail the hold. Proceed asks the caller to
   --  update the navigator, hand a reached leg to its owner and finish the
   --  task; otherwise Ok is false, the hold having failed.
   procedure Begin_Step (S : in out State; C : Settings; Inp : Inputs; Proceed : out Boolean; Ok : out Boolean);

   --  The rest of the task over the updated navigator: the heading
   --  recovery, the mode from the rescue, the navigator, the sticks and the
   --  braking, its targets and policies, the fence, the yaw controller, the
   --  five terms summed into the lean. Ok is false when the hold has failed.
   procedure Finish_Step (S : in out State; C : Settings; Inp : Inputs; N : Navigator; Ok : out Boolean)
     with Pre => Bounded (Inp);

   --  The heading hold task, which stands aside while a hold or a rescue
   --  drives the yaw controller.
   procedure Update_Heading_Hold (S : in out State; C : Settings; Inp : Inputs; N : Navigator)
     with Pre => Bounded (Inp);

   procedure Set_Sticks_Active (S : in out State; Active : Boolean);
   procedure Set_Target_Velocity (S : in out State; V : Vector2_Velocity; Force_Abort : Boolean);
   procedure Set_Yaw_Target (S : in out State; Heading_Deg : Degrees);
   procedure Set_Heading_Recovery (S : in out State; Active : Boolean; Pitch_Deg : Pitch_Degrees);
   procedure Set_Force_Level_Park (S : in out State; Request : Boolean);
   procedure Set_Yaw_Rate_Limit (S : in out State; Limit_Dps : Rate_Limit_Dps);

   --  The nose held on a heading through a navigation leg, ahead of the
   --  yaw mode, or handed back to it.
   procedure Set_Nav_Heading_Override (S : in out State; Valid : Boolean; Heading_Deg : Degrees);

   function Position_Error (S : State) return Vector2_Cm is (S.Distance_Error);

   --  The yaw controller stood down by a mode that stops running the task.
   procedure Disable_Yaw_Control (S : in out State);

   --  Whether the receiver takes the yaw rate from the controller.
   function Yaw_Control_Active (S : State; Inp : Inputs) return Boolean is
     (S.Yaw_Active
      and then (Inp.Autopilot_Mode or else Inp.Pos_Hold_Mode or else Inp.Mag_Mode or else Inp.Rescue_Mode));

end Adaflight.Position_Control;
