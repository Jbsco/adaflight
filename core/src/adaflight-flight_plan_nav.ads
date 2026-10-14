--  The flight plan executor: the plan it flies, the stored mission or an
--  injected one, and the geometry its legs are built from: the target of a
--  waypoint in the estimator's frame, the braking distance and the point the
--  craft comes to rest at, the carrot's placement within the controller's
--  reach, the bearing and the nose test, the hold pattern's carrot, and the
--  orbit's period.
with Interfaces;
with Adaflight.Flight_Plan;
with Adaflight.Maths;
with Adaflight.Position_Estimator;
with Adaflight.Position_Nav;

package Adaflight.Flight_Plan_Nav with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Integer_32 is Interfaces.Integer_32;

   --  The hold radius in centimeters and the autopilot's maximum velocity in
   --  cm/s, within the configuration interface's ranges.
   subtype Hold_Radius is Unsigned_16 range 50 .. 1_000;
   subtype Max_Velocity is Unsigned_16 range 100 .. 5_000;

   --  The autopilot's settings the executor reads, within the configuration
   --  interface's ranges: the maximum lean in degrees, the radii and speeds
   --  in centimeters and cm/s, the acceleration in cm/s/s, and the climb
   --  rate alt hold flies at in cm/s.
   type Settings is record
      Max_Angle      : Unsigned_8 range 10 .. 70 := 50;
      Arrival_Radius : Unsigned_16 range 100 .. 5_000 := 500;
      Radius         : Hold_Radius := 200;
      Max_Speed      : Max_Velocity := 500;
      Nav_Accel      : Unsigned_16 range 20 .. 1_000 := 250;
      Landing_Rate   : Unsigned_8 range 10 .. 200 := 50;
      Climb_Rate     : Float range 0.0 .. 2_550.0 := 0.0;
   end record;

   Injected_Max : constant := 4;
   subtype Injected_Count is Natural range 0 .. Injected_Max;
   type Injected_List is array (0 .. Injected_Max - 1) of Flight_Plan.Waypoint;

   --  Distances and speeds in metres, wide enough for any estimate.
   Distance_Bound : constant := 1.0e12;
   subtype Distance is Float range -Distance_Bound .. Distance_Bound;
   type Vector_2 is record
      X, Y : Distance := 0.0;
   end record;
   type ENU is record
      East, North, Up : Distance := 0.0;
   end record;

   --  The executor's state the geometry reads: the injected plan that
   --  replaces the stored one while it holds waypoints, the altitude frame
   --  offset, the leg's target and whether it is a carrot leg turning in,
   --  the carrot with its velocity, the leg's approach deceleration, and the
   --  hold pattern's type and centre.
   type State is record
      Injected            : Injected_List := (others => (others => <>));
      Injected_Waypoints  : Injected_Count := 0;
      Z_Bias_M            : Float range -1.0e6 .. 1.0e6 := 0.0;
      Leg_Is_Pass_Gate    : Boolean := False;
      Leg_Target          : ENU;
      Leg_Turn_In         : Boolean := False;
      Leg_Approach_Decel  : Float range 0.0 .. 1_000.0 := 0.0;
      Carrot              : Vector_2;
      Carrot_Velocity     : Vector_2;
      Pattern_Type        : Unsigned_8 := Flight_Plan.Pattern_None;
      Pattern_Centre      : ENU;
   end record;

   function Active_Count (S : State; P : Flight_Plan.Plan) return Natural is
     (if S.Injected_Waypoints > 0 then S.Injected_Waypoints else P.Count)
     with Post => Active_Count'Result <= Flight_Plan.Max_Waypoints;

   function Active_Waypoint (S : State; P : Flight_Plan.Plan; Index : Natural) return Flight_Plan.Waypoint is
     (if S.Injected_Waypoints > 0 then S.Injected (Index) else P.Waypoints (Index))
     with Pre => Index < Active_Count (S, P);

   --  The next waypoint at or after From that is not a modifier, or the
   --  active count when none is left.
   function Next_Positional_Index (S : State; P : Flight_Plan.Plan; From : Natural) return Natural
     with Post => Next_Positional_Index'Result <= Active_Count (S, P);

   function Is_Station_Keeping (Kind : Unsigned_8) return Boolean is
     (Kind = Flight_Plan.Type_Hold or else Kind = Flight_Plan.Type_Land or else Kind = Flight_Plan.Type_Takeoff);

   --  A fly-over or fly-by waypoint with another positional one after it,
   --  or one that faces its target, flies the carrot along its leg.
   function Flown_As_Carrot_Leg (S : State; P : Flight_Plan.Plan; W : Flight_Plan.Waypoint; Index : Natural)
     return Boolean
     with Pre => Index < Flight_Plan.Max_Waypoints;

   --  The waypoint's target in the estimator's frame from the GPS origin,
   --  false while the estimator has none.
   procedure Compute_Target
     (S         : State;
      W         : Flight_Plan.Waypoint;
      Has_Origin : Boolean;
      Origin    : Position_Estimator.Location;
      Cos_Lat   : Position_Estimator.Longitude_Scale;
      Target    : out ENU;
      Ok        : out Boolean)
     with Global => null;

   --  The offset between the estimator's altitude and the GPS frame the
   --  waypoints' altitudes are in.
   procedure Capture_Altitude_Frame
     (S : in out State; Has_Origin : Boolean; Origin_Alt_Cm : Integer_32; Estimator_Alt_Cm : Float;
      GPS_Alt_Cm : Integer_32)
     with Global => null, Pre => Estimator_Alt_Cm in -2.0 ** 24 .. 2.0 ** 24;

   --  The rate a leg climbs or descends at in m/s: its own, or the landing
   --  rate on a landing and the alt hold climb rate on any other.
   function Leg_Vert_Rate (W : Flight_Plan.Waypoint; C : Settings) return Float
     with Post => Leg_Vert_Rate'Result in 0.0 .. 1_000.0;

   --  Where a leg taking over starts its altitude ramp: the target altitude
   --  of a leg flying with one, else the craft's.
   function Commanded_Altitude (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Float
     with Post => abs Commanded_Altitude'Result <= 2.0 ** 18;

   --  A lean in whole degrees, as the settings give it.
   subtype Lean_Degrees is Natural range 0 .. 70;

   --  The deceleration a lean of at least 10 degrees buys, in m/s/s.
   function Braking_Decel (Angle : Lean_Degrees) return Float
     with Post => Braking_Decel'Result in 1.7 .. 27.0;

   --  The lean the rescue's first leg brakes at: the maximum, at most 35.
   function Rescue_Stop_Max_Angle (C : Settings) return Lean_Degrees is
     (Natural'Min (Natural (C.Max_Angle), 35));

   --  Where braking at a lean brings the craft to rest on something moving.
   function Rest_Point (Est : Position_Nav.Estimate; Moving : Vector_2; Angle : Lean_Degrees) return Vector_2
     with Pre  => abs Moving.X <= 1.0e6 and then abs Moving.Y <= 1.0e6,
          Post => abs Rest_Point'Result.X <= 6.0e11 and then abs Rest_Point'Result.Y <= 6.0e11;

   --  The carrot at Wanted, never further than the controller's reach from
   --  the craft or from where the craft comes to rest on it.
   procedure Place_Carrot (S : in out State; Est : Position_Nav.Estimate; Wanted : Vector_2; C : Settings)
     with Global => null,
          Pre    => abs S.Carrot_Velocity.X <= 1.0e6 and then abs S.Carrot_Velocity.Y <= 1.0e6
                    and then abs Wanted.X <= 1.0e11 and then abs Wanted.Y <= 1.0e11;

   --  The carrot where the navigator has walked it.
   procedure Read_Back_Carrot (S : in out State; N : Position_Nav.Navigator)
     with Global => null;

   --  The acceleration of a point leg out of the one before: the setting,
   --  never slower than the braking curve or the approach.
   function Point_Leg_Accel (S : State; C : Settings) return Float is
     (Float'Max (Float'Max (Float (C.Nav_Accel) * 0.01, 0.3), S.Leg_Approach_Decel));

   --  The distance to the navigator's target, without the up part when the
   --  leg leaves the altitude out.
   function Nav_Target_Delta (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return ENU;

   function Distance_To_Nav_Target (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Float
     with Post => Distance_To_Nav_Target'Result >= 0.0;

   --  The distance to the waypoint: the leg's target on a carrot leg, where
   --  the navigator's target is the carrot.
   function Nav_Waypoint_Delta (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return ENU
     with Pre => abs S.Leg_Target.East <= 1.0e9 and then abs S.Leg_Target.North <= 1.0e9
                 and then abs S.Leg_Target.Up <= 1.0e9;

   --  How far the craft goes before its speed turns round: the braking
   --  distance at the lean, the speed carried through the reversal, and a
   --  turn's width on a leg turning in.
   function Braking_Distance (S : State; Est : Position_Nav.Estimate; C : Settings) return Float
     with Post => Braking_Distance'Result >= 0.0;

   --  An angle in degrees into -180 .. 180.
   function Wrap_Deg_180 (Deg : Float) return Float
     with Pre  => Deg in -1_440.0 .. 1_440.0,
          Post => Wrap_Deg_180'Result in -180.0 .. 180.0;

   --  The bearing from the craft to a point in degrees, false within 2 m.
   procedure Bearing_To_Point (Est : Position_Nav.Estimate; Point : ENU; Bearing : out Float; Ok : out Boolean)
     with Global => null,
          Pre    => abs Point.East <= 1.0e9 and then abs Point.North <= 1.0e9,
          Post   => (if Ok then Bearing in -180.01 .. 180.01);

   --  The nose within 30 degrees of the bearing to the target, or the
   --  target within 2 m.
   function Leg_Nose_On_Target (Est : Position_Nav.Estimate; Target : ENU; Yaw_Decidegrees : Integer_32)
     return Boolean
     with Pre => abs Target.East <= 1.0e9 and then abs Target.North <= 1.0e9
                 and then Yaw_Decidegrees in -3_600 .. 3_600;

   --  The hold pattern's carrot at a phase: an orbit, or a figure eight
   --  through the centre.
   function Pattern_Carrot (S : State; Phase : Maths.Angle; Radius_M : Float) return ENU
     with Pre => Radius_M in 0.0 .. 1_000.0 and then abs S.Pattern_Centre.East <= 1.0e9
                 and then abs S.Pattern_Centre.North <= 1.0e9;

   --  The orbit's period in tenths of a second at Speed in cm/s, the maximum
   --  velocity for 0, never below 1 m/s and never above the pattern's
   --  turn rate.
   function Orbit_Period_Ds (Speed : Unsigned_16; Radius : Hold_Radius; Max_Speed : Max_Velocity) return Unsigned_16
     with Global => null,
          Post   => Orbit_Period_Ds'Result >= 1;

end Adaflight.Flight_Plan_Nav;
