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
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   --  The hold radius in centimeters and the autopilot's maximum velocity in
   --  cm/s, within the configuration interface's ranges.
   subtype Hold_Radius is Unsigned_16 range 50 .. 1_000;
   subtype Max_Velocity is Unsigned_16 range 100 .. 5_000;

   --  The autopilot's yaw modes; the fixed and dampener modes leave the nose
   --  uncommanded.
   Yaw_Mode_Fixed    : constant := 3;
   Yaw_Mode_Dampener : constant := 4;

   --  The autopilot's settings the executor reads, within the configuration
   --  interface's ranges: the maximum lean in degrees, the radii and speeds
   --  in centimeters and cm/s, the accelerations in cm/s/s, the climb rate
   --  alt hold flies at in cm/s, the carrot's lead time in tenths of a
   --  second and lead limit in centimeters, the pre-turn distance in
   --  centimeters, and the yaw mode.
   type Settings is record
      Max_Angle      : Unsigned_8 range 10 .. 70 := 50;
      Arrival_Radius : Unsigned_16 range 100 .. 5_000 := 500;
      Radius         : Hold_Radius := 200;
      Max_Speed      : Max_Velocity := 500;
      Nav_Accel      : Unsigned_16 range 20 .. 1_000 := 250;
      Landing_Rate   : Unsigned_8 range 10 .. 200 := 50;
      Climb_Rate     : Float range 0.0 .. 2_550.0 := 0.0;
      Corner_Speed   : Unsigned_16 range 50 .. 2_000 := 300;
      Corner_Delta_V : Unsigned_16 range 100 .. 4_000 := 500;
      Nav_Decel      : Unsigned_16 range 20 .. 1_000 := 150;
      Lead_Time      : Unsigned_8 range 2 .. 40 := 10;
      Lead_Max       : Unsigned_16 range 600 .. 6_000 := 2_000;
      Preturn_Dist   : Unsigned_16 range 500 .. 5_000 := 1_500;
      Yaw_Mode       : Unsigned_8 range 0 .. 4 := 0;
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

   type Nav_State is (Idle, Targeting, Holding, Complete, Landing, Aborted);
   type Abort_Reason is (None, Estimator, Stalled, Flyaway, Heading, Mag_Fault);

   subtype Speed is Float range 0.0 .. 1_000.0;
   subtype Bearing_Degrees is Float range -400.0 .. 400.0;

   --  The executor's state: whether it flies a plan and in which state, why
   --  it aborted, the current waypoint, the injected plan that replaces the
   --  stored one while it holds waypoints, and the altitude frame offset;
   --  the leg's target, arrival radius, cruise, approach deceleration and
   --  line, and whether it is a carrot leg turning in with its lean capped;
   --  the nose behaviour with its held heading and gate; the carrot with its
   --  velocity and speed, the anchor the next leg starts from, the pre-turn
   --  and the filtered along-track position; the progress tracking and the
   --  heading-fault time; the hold pattern; and the rescue's heading
   --  recovery stages.
   type State is record
      Active              : Boolean := False;
      Mode                : Nav_State := Idle;
      Reason              : Abort_Reason := None;
      Current_Index       : Unsigned_8 := 0;
      Injected            : Injected_List := (others => (others => <>));
      Injected_Waypoints  : Injected_Count := 0;
      Z_Bias_M            : Float range -1.0e6 .. 1.0e6 := 0.0;
      Leg_Is_Pass_Gate    : Boolean := False;
      Leg_Target          : ENU;
      Leg_Arrive_Radius   : Float range 0.0 .. 100_000.0 := 0.0;
      Leg_Cruise          : Speed := 0.0;
      Leg_Approach_Decel  : Float range 0.0 .. 1_000.0 := 0.0;
      Leg_Valid           : Boolean := False;
      Leg_Start           : Vector_2;
      Leg_Turn_In         : Boolean := False;
      Leg_Turn_Capped     : Boolean := False;
      Leg_Yaw_Behaviour   : Unsigned_8 := Flight_Plan.Yaw_Default;
      Leg_Yaw_Hold_Deg    : Bearing_Degrees := 0.0;
      Leg_Yaw_Gated       : Boolean := False;
      Leg_Yaw_Gate_Start  : Unsigned_32 := 0;
      Leg_Yaw_Timed_Out   : Boolean := False;
      Leg_Yaw_Braked      : Boolean := False;
      Carrot              : Vector_2;
      Carrot_Velocity     : Vector_2;
      Carrot_Speed        : Speed := 0.0;
      Leg_Anchor          : Vector_2;
      Leg_Anchor_Valid    : Boolean := False;
      In_Pre_Turn         : Boolean := False;
      Along_Filt_M        : Distance := 0.0;
      Meas_Filt_Valid     : Boolean := False;
      Best_Valid          : Boolean := False;
      Best_Distance_M     : Float range 0.0 .. 1.0e13 := 0.0;
      Flyaway_Margin_M    : Float range 0.0 .. 100.0 := 0.0;
      Last_Progress_Us    : Unsigned_32 := 0;
      Hdg_Fault_Time_S    : Float range 0.0 .. 1.0e6 := 0.0;
      Pattern_Pending     : Boolean := False;
      Pattern_Active      : Boolean := False;
      Pattern_Type        : Unsigned_8 := Flight_Plan.Pattern_None;
      Pattern_Centre      : ENU;
      Is_Rescue_Plan      : Boolean := False;
      Rescue_Blind_Climb  : Boolean := False;
      Rescue_Climbed      : Boolean := False;
      Rescue_Heading_Hold : Boolean := False;
   end record;

   --  What every cycle of a carrot leg keeps: the leg's points and the
   --  carrot within the navigator's bound, the carrot's velocity within its
   --  stated speed, and the filtered along-track distance within 10^7 m.
   function Leg_Bounded (S : State) return Boolean is
     (abs S.Leg_Target.East <= Position_Nav.Metres_Bound and then abs S.Leg_Target.North <= Position_Nav.Metres_Bound
      and then abs S.Leg_Target.Up <= Position_Nav.Metres_Bound
      and then abs S.Leg_Start.X <= Position_Nav.Metres_Bound and then abs S.Leg_Start.Y <= Position_Nav.Metres_Bound
      and then abs S.Leg_Anchor.X <= Position_Nav.Metres_Bound and then abs S.Leg_Anchor.Y <= Position_Nav.Metres_Bound
      and then abs S.Carrot.X <= Position_Nav.Metres_Bound and then abs S.Carrot.Y <= Position_Nav.Metres_Bound
      and then abs S.Carrot_Velocity.X <= 1_000.0 and then abs S.Carrot_Velocity.Y <= 1_000.0
      and then abs S.Along_Filt_M <= 1.0e7);

   --  What a leg's cycle reads: the estimate, the time since the last cycle
   --  and the clock, the nose's yaw in decidegrees, the GPS course in
   --  decidegrees and ground speed in cm/s, and the estimator's GPS origin
   --  with the longitude scale.
   type Leg_Inputs is record
      Est             : Position_Nav.Estimate;
      Dt_S            : Float range 0.0 .. 0.25 := 0.0;
      Now_Us          : Unsigned_32 := 0;
      Yaw_Decidegrees : Integer_32 range 0 .. 3_600 := 0;
      Ground_Course   : Unsigned_16 range 0 .. 3_600 := 0;
      Ground_Speed    : Unsigned_16 := 0;
      Has_Origin      : Boolean := False;
      Origin          : Position_Estimator.Location;
      Cos_Lat         : Position_Estimator.Longitude_Scale := 1.0;
   end record;

   --  The executor's calls into the autopilot in call order: the nose held
   --  on a heading in degrees or handed back to the configured yaw mode, and
   --  the heading recovery's pitch-forward in degrees started or ended.
   type Autopilot_Call_Kind is (Nose_Override, Heading_Recovery);
   type Autopilot_Call is record
      Kind  : Autopilot_Call_Kind := Nose_Override;
      On    : Boolean := False;
      Value : Float := 0.0;
   end record;
   Max_Autopilot_Calls : constant := 16;
   type Autopilot_Call_List is array (1 .. Max_Autopilot_Calls) of Autopilot_Call;
   type Autopilot_Output is record
      Calls : Autopilot_Call_List;
      Count : Natural range 0 .. Max_Autopilot_Calls := 0;
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
     with Global => null,
          Post   => Ok = Has_Origin and then abs Target.East <= 2.5e7 and then abs Target.North <= 2.5e7
                    and then abs Target.Up <= 4.5e7;

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
   function Place_Carrot (Est : Position_Nav.Estimate; Velocity : Vector_2; Wanted : Vector_2; C : Settings)
     return Vector_2
     with Pre  => abs Velocity.X <= 1.0e6 and then abs Velocity.Y <= 1.0e6
                  and then abs Wanted.X <= 1.0e11 and then abs Wanted.Y <= 1.0e11,
          Post => abs Place_Carrot'Result.X <= Position_Nav.Metres_Bound
                  and then abs Place_Carrot'Result.Y <= Position_Nav.Metres_Bound;

   --  The carrot where the navigator has walked it.
   function Read_Back_Carrot (N : Position_Nav.Navigator) return Vector_2 is
     (X => N.Cmd.Target.East, Y => N.Cmd.Target.North);

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

   --  The stall and flyaway checks against a distance to the goal: a leg
   --  that stops closing for 30 s or falls back past its margin aborts.
   procedure Update_Progress_Tracking
     (S : in out State; N : in out Position_Nav.Navigator; Distance_M : Float; I : Leg_Inputs; C : Settings;
      O : in out Autopilot_Output)
     with Global => null,
          Pre    => Distance_M in 0.0 .. 1.0e12,
          Post   => (if Leg_Bounded (S'Old) then Leg_Bounded (S));

   --  The plan stopped with its reason: the nose handed back and the target
   --  cleared, so position hold keeps the craft where it is.
   procedure Abort_Mission
     (S : in out State; N : in out Position_Nav.Navigator; Reason : Abort_Reason; O : in out Autopilot_Output)
     with Global => null,
          Post   => S.Mode = Aborted and then (if Leg_Bounded (S'Old) then Leg_Bounded (S));

   --  One cycle of the heading-fault detector; true once the GPS course has
   --  disagreed with the nose for 2 s at speed while the nose was on the
   --  leg.
   procedure Check_Heading_Fault
     (S : in out State; N : Position_Nav.Navigator; I : Leg_Inputs; C : Settings; Fault : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  The nose command of a leg that states its yaw behaviour, and the gate
   --  a face-the-target leg waits at until the nose has come round.
   procedure Update_Leg_Yaw
     (S : in out State; P : Flight_Plan.Plan; I : Leg_Inputs; O : in out Autopilot_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  One cycle of a carrot leg: the carrot marched along the leg line at
   --  the speed profile into the corner, steered within the carrot's
   --  acceleration, the pre-turn onto the next leg, the gate, and the nose.
   --  Gate_Crossed reports the waypoint reached, for the caller to advance.
   procedure Update_Leg_Carrot
     (S            : in out State;
      N            : in out Position_Nav.Navigator;
      P            : Flight_Plan.Plan;
      I            : Leg_Inputs;
      C            : Settings;
      O            : in out Autopilot_Output;
      Gate_Crossed : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  The orbit's period in tenths of a second at Speed in cm/s, the maximum
   --  velocity for 0, never below 1 m/s and never above the pattern's
   --  turn rate.
   function Orbit_Period_Ds (Speed : Unsigned_16; Radius : Hold_Radius; Max_Speed : Max_Velocity) return Unsigned_16
     with Global => null,
          Post   => Orbit_Period_Ds'Result >= 1;

end Adaflight.Flight_Plan_Nav;
