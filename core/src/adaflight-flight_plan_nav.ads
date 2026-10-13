--  The flight plan executor: the plan it flies, the stored mission or an
--  injected one, and the geometry its legs are built from: the target of a
--  waypoint in the estimator's frame, the braking distance and the point the
--  craft comes to rest at, the carrot's placement within the controller's
--  reach, the bearing and the nose test, the hold pattern's carrot, and the
--  orbit's period; a carrot leg's cycle; and the dispatch of a leg, the
--  arrival at a waypoint, and the landing.
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
   subtype Unsigned_64 is Interfaces.Unsigned_64;
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
   --  centimeters, the yaw mode, the touchdown's speed in cm/s and time in
   --  tenths of a second, the rescue's descent distance in metres, the
   --  geofence's distance from home in metres with its action, a return home
   --  or a landing in place, and the return's altitude above home in metres
   --  and speed in cm/s.
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
      Touchdown_Cms  : Unsigned_8 range 10 .. 200 := 50;
      Touchdown_Ds   : Unsigned_8 range 5 .. 50 := 10;
      Descent_Dist_M : Unsigned_16 range 5 .. 500 := 20;
      Fence_M        : Unsigned_16 range 0 .. 10_000 := 0;
      Fence_Return   : Boolean := False;
      Return_Alt_M   : Unsigned_16 range 5 .. 1_000 := 30;
      Return_Cms     : Unsigned_16 range 0 .. 3_000 := 750;
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
   --  it aborted, the current waypoint and the one a set-current chose while
   --  idle, the hold's start and time held, the staged modifiers, the
   --  injected plan that replaces the stored one while it holds waypoints,
   --  the rescue plan staged for the next engage, and the altitude frame
   --  offset; the leg's target, arrival radius,
   --  cruise, vertical rate, approach deceleration and line, and whether it
   --  is a carrot leg turning in with its lean capped; the nose behaviour
   --  with its held heading and gate; the carrot with its velocity and
   --  speed, the anchor the next leg starts from, the pre-turn and the
   --  filtered along-track position; the progress tracking and the
   --  heading-fault time; the hold pattern; the rescue's heading recovery
   --  stages; and the landing.
   type State is record
      Active              : Boolean := False;
      Mode                : Nav_State := Idle;
      Reason              : Abort_Reason := None;
      Current_Index       : Unsigned_8 := 0;
      Pending_Start_Index : Unsigned_8 := 0;
      Hold_Start_Us       : Unsigned_32 := 0;
      Hold_Last_Update_Us : Unsigned_32 := 0;
      Hold_Elapsed_Us     : Unsigned_64 := 0;
      Hold_Duration_Ds    : Unsigned_16 := 0;
      Alt_Override_Pending : Boolean := False;
      Alt_Override_Cm     : Integer_32 := 0;
      Alt_Override_Mode   : Unsigned_8 := 0;
      Delay_Active        : Boolean := False;
      Delay_Duration_Ds   : Unsigned_16 := 0;
      Delay_End_Us        : Unsigned_32 := 0;
      Yaw_Rate_Cap_Dps    : Float range 0.0 .. 65_535.0 := 0.0;
      Injected            : Injected_List := (others => (others => <>));
      Injected_Waypoints  : Injected_Count := 0;
      Staged              : Injected_List := (others => (others => <>));
      Staged_Count        : Injected_Count := 0;
      Z_Bias_M            : Float range -1.0e6 .. 1.0e6 := 0.0;
      Leg_Is_Pass_Gate    : Boolean := False;
      Leg_Target          : ENU;
      Leg_Arrive_Radius   : Float range 0.0 .. 100_000.0 := 0.0;
      Leg_Cruise          : Speed := 0.0;
      Leg_Vert_Rate_Mps   : Speed := 0.0;
      Leg_Approach_Decel  : Float range 0.0 .. 1_000.0 := 0.0;
      Leg_Valid           : Boolean := False;
      Leg_Start           : Vector_2;
      Leg_Turn_In         : Boolean := False;
      Leg_Turn_Capped     : Boolean := False;
      Leg_Yaw_Behaviour   : Unsigned_8 := Flight_Plan.Yaw_Default;
      Leg_Yaw_Hold_Deg    : Bearing_Degrees := 0.0;
      Leg_Yaw_Gated       : Boolean := False;
      Leg_Yaw_Holding     : Boolean := False;
      Leg_Yaw_Gate_Start  : Unsigned_32 := 0;
      Leg_Yaw_Timed_Out   : Boolean := False;
      Leg_Yaw_Braked      : Boolean := False;
      Leg_Yaw_Index       : Unsigned_8 := Unsigned_8'Last;
      Carrot              : Vector_2;
      Carrot_Velocity     : Vector_2;
      Carrot_Speed        : Speed := 0.0;
      Carrot_Valid        : Boolean := False;
      Turn_In_Requested   : Boolean := False;
      Leg_Anchor          : Vector_2;
      Leg_Anchor_Valid    : Boolean := False;
      In_Pre_Turn         : Boolean := False;
      Dispatch_Afresh     : Boolean := False;
      Along_Filt_M        : Distance := 0.0;
      Meas_Filt_Valid     : Boolean := False;
      Best_Valid          : Boolean := False;
      Best_Distance_M     : Float range 0.0 .. 1.0e13 := 0.0;
      Flyaway_Margin_M    : Float range 0.0 .. 100.0 := 0.0;
      Last_Progress_Us    : Unsigned_32 := 0;
      Hdg_Fault_Time_S    : Float range 0.0 .. 1.0e6 := 0.0;
      Last_Update_Us      : Unsigned_32 := 0;
      Pattern_Pending     : Boolean := False;
      Pattern_Active      : Boolean := False;
      Pattern_Type        : Unsigned_8 := Flight_Plan.Pattern_None;
      Pattern_Centre      : ENU;
      Pattern_Phase_Rad   : Float range -10.0 .. 10.0 := 0.0;
      Pattern_Speed_Mps   : Speed := 0.0;
      Pattern_Cruise_Mps  : Speed := 0.0;
      Pattern_Last_Update_Us : Unsigned_32 := 0;
      Is_Rescue_Plan      : Boolean := False;
      Rescue_Blind_Climb  : Boolean := False;
      Rescue_Climbed      : Boolean := False;
      Rescue_Climbed_Us   : Unsigned_32 := 0;
      Rescue_Heading_Hold : Boolean := False;
      Rescue_Heading_Start_Us : Unsigned_32 := 0;
      Rescue_Heading_Trusted : Boolean := False;
      Rescue_Heading_Trusted_Us : Unsigned_32 := 0;
      Rescue_Heading_Off_Course_Us : Unsigned_32 := 0;
      Rescue_Descent_Active : Boolean := False;
      Landing_Rate_Mps    : Speed := 0.0;
      Landing_Start_Us    : Unsigned_32 := 0;
      Touchdown_Quiet_Us  : Unsigned_32 := 0;
      Landing_Established : Boolean := False;
   end record;

   --  What every cycle of the executor keeps: the leg's points, the carrot
   --  and the hold pattern's centre within the navigator's bound, the
   --  carrot's velocity within its stated speed, and the filtered
   --  along-track distance within 10^7 m.
   function Leg_Bounded (S : State) return Boolean is
     (abs S.Leg_Target.East <= Position_Nav.Metres_Bound and then abs S.Leg_Target.North <= Position_Nav.Metres_Bound
      and then abs S.Leg_Target.Up <= Position_Nav.Metres_Bound
      and then abs S.Leg_Start.X <= Position_Nav.Metres_Bound and then abs S.Leg_Start.Y <= Position_Nav.Metres_Bound
      and then abs S.Leg_Anchor.X <= Position_Nav.Metres_Bound and then abs S.Leg_Anchor.Y <= Position_Nav.Metres_Bound
      and then abs S.Carrot.X <= Position_Nav.Metres_Bound and then abs S.Carrot.Y <= Position_Nav.Metres_Bound
      and then abs S.Carrot_Velocity.X <= 1_000.0 and then abs S.Carrot_Velocity.Y <= 1_000.0
      and then abs S.Along_Filt_M <= 1.0e7
      and then abs S.Pattern_Centre.East <= Position_Nav.Metres_Bound
      and then abs S.Pattern_Centre.North <= Position_Nav.Metres_Bound
      and then abs S.Pattern_Centre.Up <= Position_Nav.Metres_Bound);

   --  What a cycle reads: the estimate, the time since the last cycle and
   --  the clock, the nose's yaw in decidegrees, the GPS course in decidegrees
   --  and ground speed in cm/s, the estimator's GPS origin with the
   --  longitude scale, whether the attitude trusts its heading and the
   --  estimator needs one, whether the craft is below the landing altitude,
   --  whether a listener takes the reached waypoints, the position
   --  controller's error in centimetres, whether the estimate's position is
   --  valid, the GPS home with whether it is fixed and the distance to it in
   --  metres, the GPS altitude in centimetres, and the estimator's altitude
   --  in centimetres.
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
      Heading_Valid    : Boolean := True;
      Heading_Required : Boolean := False;
      Below_Landing    : Boolean := False;
      Listener         : Boolean := False;
      Position_Error   : Vector_2;
      Estimator_Valid  : Boolean := True;
      Home_Fix         : Boolean := False;
      Home_Distance_M  : Unsigned_16 := 0;
      Home             : Position_Estimator.Location;
      GPS_Alt_Cm       : Integer_32 := 0;
      Estimator_Alt_Cm : Float range -2.0 ** 24 .. 2.0 ** 24 := 0.0;
   end record;

   --  The executor's calls out in call order: the nose held on a heading in
   --  degrees or handed back to the configured yaw mode, the heading
   --  recovery's pitch-forward in degrees started or ended, the yaw rate
   --  limit in degrees a second, the level park set or cleared, the disarm
   --  on touchdown, a reached waypoint's index to its listener, and alt
   --  hold's emergency descent set or cleared with its rate in cm/s.
   type Call_Kind is
     (Nose_Override, Heading_Recovery, Yaw_Rate_Limit, Level_Park, Disarm, Reached_Waypoint, Emergency_Descent);
   type Outgoing_Call is record
      Kind  : Call_Kind := Nose_Override;
      On    : Boolean := False;
      Value : Float := 0.0;
   end record;
   Max_Calls : constant := 16;
   type Outgoing_Call_List is array (1 .. Max_Calls) of Outgoing_Call;
   type Executor_Output is record
      Calls : Outgoing_Call_List;
      Count : Natural range 0 .. Max_Calls := 0;
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
     with Global => null,
          Pre    => Estimator_Alt_Cm in -2.0 ** 24 .. 2.0 ** 24,
          Post   => (if Leg_Bounded (S'Old) then Leg_Bounded (S));

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
   function Nav_Target_Delta (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return ENU
     with Post => abs Nav_Target_Delta'Result.East <= 5.0e5 and then abs Nav_Target_Delta'Result.North <= 5.0e5
                  and then abs Nav_Target_Delta'Result.Up <= 5.0e5;

   function Distance_To_Nav_Target (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Float
     with Post => Distance_To_Nav_Target'Result in 0.0 .. 9.0e5;

   --  The distance to the waypoint: the leg's target on a carrot leg, where
   --  the navigator's target is the carrot.
   function Nav_Waypoint_Delta (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return ENU
     with Pre  => abs S.Leg_Target.East <= 1.0e9 and then abs S.Leg_Target.North <= 1.0e9
                  and then abs S.Leg_Target.Up <= 1.0e9,
          Post => (if Leg_Bounded (S)
                   then abs Nav_Waypoint_Delta'Result.East <= 5.0e5
                        and then abs Nav_Waypoint_Delta'Result.North <= 5.0e5
                        and then abs Nav_Waypoint_Delta'Result.Up <= 5.0e5);

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
      O : in out Executor_Output)
     with Global => null,
          Pre    => Distance_M in 0.0 .. 1.0e12,
          Post   => (if Leg_Bounded (S'Old) then Leg_Bounded (S));

   --  The plan stopped with its reason: the nose handed back and the target
   --  cleared, so position hold keeps the craft where it is.
   procedure Abort_Mission
     (S : in out State; N : in out Position_Nav.Navigator; Reason : Abort_Reason; O : in out Executor_Output)
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
     (S : in out State; P : Flight_Plan.Plan; I : Leg_Inputs; O : in out Executor_Output)
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
      O            : in out Executor_Output;
      Gate_Crossed : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  The next leg from the current waypoint on: the modifiers before it
   --  staged, its target, radius, cruise and nose, the carrot or the point
   --  leg handed to the navigator, and the leg's progress tracking reset.
   --  Dispatched is false when the plan ends first or the estimator has no
   --  origin.
   procedure Dispatch_Waypoint
     (S          : in out State;
      N          : in out Position_Nav.Navigator;
      P          : Flight_Plan.Plan;
      I          : Leg_Inputs;
      C          : Settings;
      O          : in out Executor_Output;
      Dispatched : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  A waypoint reached: the listener told, the rescue's heading recovery
   --  staged, a hold or a landing started, or the plan advanced.
   procedure Waypoint_Reached
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  A landing where the craft is, at the configured descent rate.
   procedure Start_Landing_In_Place (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  A landing at the leg's target at the leg's rate, or the leg flown
   --  again when the navigator has lost it.
   procedure Start_Landing_At_Nav_Target
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  One cycle of a landing: the target kept below the craft, and the plan
   --  complete with a disarm once the descent has stopped for the touchdown
   --  time.
   procedure Update_Landing
     (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings; O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  The executor at power-up: idle, with no plan, modifiers or nose.
   procedure Init (S : in out State; O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  The plan flown from its start when the autopilot engages: a staged
   --  rescue plan in place of the stored one, or the stored plan from the
   --  waypoint a set-current chose while idle.
   procedure Engage
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  The executor stopped, its plan and target dropped, the nose handed
   --  back.
   procedure Disengage (S : in out State; N : in out Position_Nav.Navigator; O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  A plan of one to four waypoints flown in place of the stored one while
   --  the executor is active; Accepted is false otherwise.
   procedure Inject_Plan
     (S        : in out State;
      N        : in out Position_Nav.Navigator;
      P        : Flight_Plan.Plan;
      I        : Leg_Inputs;
      C        : Settings;
      O        : in out Executor_Output;
      Plan     : Injected_List;
      Count    : Natural;
      Accepted : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   function Is_Injected_Plan_Active (S : State) return Boolean is (S.Active and then S.Injected_Waypoints > 0);

   --  The stored plan's waypoint flown next, now while active or from the
   --  next engage; Accepted is false for an index past the plan or while an
   --  injected plan flies.
   procedure Set_Current_Index
     (S        : in out State;
      N        : in out Position_Nav.Navigator;
      P        : Flight_Plan.Plan;
      I        : Leg_Inputs;
      C        : Settings;
      O        : in out Executor_Output;
      Index    : Unsigned_8;
      Accepted : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  One cycle of the executor: the rescue's heading recovery, a dispatch
   --  retried, the landing, the estimator and geofence checks, the delay's
   --  end, the rescue's blind climb, the leg with its nose and heading-fault
   --  check, and the hold with its pattern and expiry.
   procedure Update
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S);

   --  The distance to the waypoint in metres, -1 without an active leg.
   function Distance_To_Waypoint (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Float
     with Pre => Leg_Bounded (S);

   --  The bearing to the waypoint in tenths of a degree from north, -1
   --  without an active leg.
   function Bearing_To_Waypoint (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Integer_32
     with Pre  => Leg_Bounded (S),
          Post => Bearing_To_Waypoint'Result in -1 .. 3_599;

   --  The seconds to the waypoint at the craft's ground speed, 0 without an
   --  active leg or below 0.5 m/s.
   function Eta_Seconds (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Unsigned_16
     with Pre => Leg_Bounded (S);

   --  The orbit's period in tenths of a second at Speed in cm/s, the maximum
   --  velocity for 0, never below 1 m/s and never above the pattern's
   --  turn rate.
   function Orbit_Period_Ds (Speed : Unsigned_16; Radius : Hold_Radius; Max_Speed : Max_Velocity) return Unsigned_16
     with Global => null,
          Post   => Orbit_Period_Ds'Result >= 1;

end Adaflight.Flight_Plan_Nav;
