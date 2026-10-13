with Ada.Numerics.Elementary_Functions;
with Adaflight.Clock;

package body Adaflight.Flight_Plan_Nav with SPARK_Mode is

   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;

   Min_Cruise_Mps        : constant := 1.0;
   Pattern_Max_Rate_Rads : constant := 0.25;
   G_Acceleration        : constant Float := 9.80665;
   Brake_Response_S      : constant := 0.15;
   Brake_Reversal_S      : constant := 1.0;
   Brake_Min_Angle       : constant := 10;
   Turn_In_Mps           : constant := 4.0;
   Turn_In_Rate_Dps      : constant := 30.0;
   Yaw_Bearing_Min_M     : constant := 2.0;
   Yaw_Align_Deg         : constant := 30.0;
   Yaw_Align_Timeout_Us  : constant := 10_000_000;
   Yaw_Swing_Max_Mps     : constant := 1.5;
   Progress_Epsilon_M    : constant := 2.0;
   Stall_Timeout_Us      : constant := 30_000_000;
   Flyaway_Min_M         : constant := 20.0;
   Flyaway_Max_M         : constant := 100.0;
   Flyaway_Leg_Fraction  : constant := 0.25;
   Hdg_Fault_Err_Deg     : constant := 70.0;
   Hdg_Fault_Time_S      : constant := 2.0;
   Hdg_Fault_Min_Cms     : constant := 300.0;
   Hdg_Fault_Aligned_Deg : constant := 30.0;
   Pass_Max_M            : constant := 12.0;
   Carrot_Lead_Min_M     : constant := 6.0;
   Gate_Radius_Scale     : constant := 1.5;
   Overrun_Lat_M         : constant := 8.0;
   Meas_Filter_S         : constant := 0.20;
   Carrot_Brake_Lag_S    : constant := 0.50;
   Approach_Decel_Mps2   : constant := 0.3;
   Rescue_Still_Radius_M : constant := 0.3;
   Carrot_No_Arrival_M   : constant := -1.0;
   Completion_Any_Mps    : constant := 1_000.0;
   Delay_Min_Cruise_Mps  : constant := 0.1;
   Rescue_Approach_Decel : constant := 1.0;
   Rescue_Stop_Still_Mps : constant := 0.5;
   Rescue_Stop_Settle_S  : constant := 3.0;
   Rescue_Pitch_Fwd_Deg  : constant := 35.0;
   Rescue_Drift_Still_Sq : constant := 10_000.0;
   Landing_Depth_M       : constant := 200.0;
   Landing_Min_Rate_Mps  : constant := 0.3;
   Landing_Establish_Us  : constant := 5_000_000;
   Rescue_Heading_Timeout_Us : constant := 15_000_000;
   Rescue_Settle_Deg     : constant := 5.0;
   Rescue_Settle_Cms     : constant := 300;
   Rescue_Settle_Us      : constant := 500_000;
   Rescue_Settle_Max_Us  : constant := 2_000_000;
   Rescue_Drift_Timeout_Us : constant := 5_000_000;
   Pattern_Update_Us     : constant := 200_000;
   Pattern_Start_Mps     : constant := 1.5;
   Pattern_Start_Us      : constant := 5_000_000;
   Deci_Per_Rad          : constant Float := 1_800.0 / Maths.Pi;

   --  Degrees in radians, rounded as the C rounds its product: the turn-in
   --  rate and the angle a turn-in counts as done within.
   Rad_30 : constant Float := Float'Machine (30.0 * Maths.Rad_Per_Degree);
   Rad_15 : constant Float := Float'Machine (15.0 * Maths.Rad_Per_Degree);

   procedure Call (O : in out Executor_Output; Kind : Call_Kind; On : Boolean; Value : Float) is
   begin
      if O.Count < Max_Calls then
         O.Count := O.Count + 1;
         O.Calls (O.Count) := (Kind => Kind, On => On, Value => Value);
      end if;
   end Call;

   procedure Command_Nose (O : in out Executor_Output; Override : Boolean; Heading : Float) is
   begin
      Call (O, Nose_Override, Override, Heading);
   end Command_Nose;

   function Constrain (Amt, Low, High : Float) return Float is
     (if Amt < Low then Low elsif Amt > High then High else Amt);

   --  The controller's reach and a turn-in's width, each operation rounded
   --  as the C rounds it.
   Reach_M      : constant Float := Float'Machine (500.0 * Float'Machine (0.01));
   Turn_Width_M : constant Float :=
     Float'Machine (Float'Machine (2.0 * Turn_In_Mps) / Float'Machine (Turn_In_Rate_Dps * Maths.Rad_Per_Degree));

   --  The single-precision tangent of each whole degree of lean from 10 to
   --  70, correctly rounded as the C library's tangent gives it.
   type Tangent_Table is array (Brake_Min_Angle .. 70) of Float;
   Tangents : constant Tangent_Table :=
     (0.176326975, 0.194380313, 0.212556571, 0.230868191, 0.249328002, 0.267949194,
      0.286745369, 0.305730671, 0.324919701, 0.344327599, 0.36397022, 0.383864045,
      0.40402624, 0.424474806, 0.445228696, 0.46630767, 0.487732589, 0.509525418,
      0.531709433, 0.55430907, 0.577350259, 0.600860596, 0.624869347, 0.649407625,
      0.674508512, 0.700207531, 0.726542532, 0.753553987, 0.781285644, 0.809784055,
      0.839099586, 0.869286716, 0.900404096, 0.932515025, 0.965688765, 1.0,
      1.03553033, 1.07236874, 1.11061251, 1.15036833, 1.19175363, 1.23489702,
      1.27994156, 1.32704484, 1.37638187, 1.42814791, 1.48256099, 1.5398649,
      1.60033453, 1.66427946, 1.7320509, 1.80404794, 1.88072622, 1.96261036,
      2.0503037, 2.14450693, 2.24603701, 2.35585189, 2.47508645, 2.60508895,
      2.74747729);

   --  The square root of a sum of squares, held at a bound whose square is
   --  at least the sum's, so the hold leaves every root in range alone.
   function Root (X : Float; Bound : Float) return Float is
     (Float'Min (Bound, Ada.Numerics.Elementary_Functions.Sqrt (X)))
     with Pre  => Bound in 0.0 .. 1.0e15 and then X in 0.0 .. Bound * Bound,
          Post => Root'Result in 0.0 .. Bound;

   function Whole_Part (X : Float) return Natural is (Natural (Float'Truncation (X)))
     with Pre => X in 0.0 .. 65_535.0;

   --  The nearest whole number with a tie going to the even one, as the C
   --  library rounds in its default mode.
   function Round_To_Even (X : Float) return Natural
     with Pre  => X in 0.0 .. 65_535.0,
          Post => Round_To_Even'Result in Whole_Part (X) .. Whole_Part (X) + 1
   is
      Base     : constant Natural := Whole_Part (X);
      Fraction : constant Float := X - Float'Truncation (X);
   begin
      if Fraction > 0.5 or else (Fraction = 0.5 and then Base mod 2 = 1) then
         return Base + 1;
      else
         return Base;
      end if;
   end Round_To_Even;

   ---------------------------
   -- Next_Positional_Index --
   ---------------------------

   function Next_Positional_Index (S : State; P : Flight_Plan.Plan; From : Natural) return Natural is
      Count : constant Natural := Active_Count (S, P);
   begin
      for I in From .. Count - 1 loop
         if Active_Waypoint (S, P, I).Kind < Flight_Plan.Type_Alt_Change then
            return I;
         end if;
      end loop;
      return Count;
   end Next_Positional_Index;

   -------------------------
   -- Flown_As_Carrot_Leg --
   -------------------------

   function Flown_As_Carrot_Leg (S : State; P : Flight_Plan.Plan; W : Flight_Plan.Waypoint; Index : Natural)
     return Boolean
   is
      Is_Last     : constant Boolean := Next_Positional_Index (S, P, Index + 1) >= Active_Count (S, P);
      Face_Target : constant Boolean := W.Yaw_Behaviour = Flight_Plan.Yaw_Face_Target;
   begin
      return not Is_Station_Keeping (W.Kind) and then (not Is_Last or else Face_Target);
   end Flown_As_Carrot_Leg;

   --------------------
   -- Compute_Target --
   --------------------

   procedure Compute_Target
     (S          : State;
      W          : Flight_Plan.Waypoint;
      Has_Origin : Boolean;
      Origin     : Position_Estimator.Location;
      Cos_Lat    : Position_Estimator.Longitude_Scale;
      Target     : out ENU;
      Ok         : out Boolean)
   is
      East_Cm, North_Cm : Float;
   begin
      Target := (others => 0.0);
      if not Has_Origin then
         Ok := False;
         return;
      end if;
      Position_Estimator.Distance_2d
        (Origin, (Lat => W.Latitude, Lon => W.Longitude, Alt_Cm => W.Altitude), Cos_Lat, East_Cm, North_Cm);
      Target.East := East_Cm * 0.01;
      Target.North := North_Cm * 0.01;
      Target.Up := Float (Interfaces.Integer_64 (W.Altitude) - Interfaces.Integer_64 (Origin.Alt_Cm)) * 0.01
        + S.Z_Bias_M;
      Ok := True;
   end Compute_Target;

   ----------------------------
   -- Capture_Altitude_Frame --
   ----------------------------

   procedure Capture_Altitude_Frame
     (S : in out State; Has_Origin : Boolean; Origin_Alt_Cm : Integer_32; Estimator_Alt_Cm : Float;
      GPS_Alt_Cm : Integer_32)
   is
      Bias : Float;
   begin
      if Has_Origin then
         Bias := Estimator_Alt_Cm * 0.01
           - Float (Interfaces.Integer_64 (GPS_Alt_Cm) - Interfaces.Integer_64 (Origin_Alt_Cm)) * 0.01;
      else
         Bias := Estimator_Alt_Cm * 0.01;
      end if;
      S.Z_Bias_M := Float'Max (-1.0e6, Float'Min (1.0e6, Bias));
   end Capture_Altitude_Frame;

   -------------------
   -- Leg_Vert_Rate --
   -------------------

   function Leg_Vert_Rate (W : Flight_Plan.Waypoint; C : Settings) return Float is
   begin
      if W.Vert_Rate > 0 then
         return Float (W.Vert_Rate) * 0.01;
      end if;
      return (if W.Kind = Flight_Plan.Type_Land then Float (C.Landing_Rate) else C.Climb_Rate) * 0.01;
   end Leg_Vert_Rate;

   ------------------------
   -- Commanded_Altitude --
   ------------------------

   function Commanded_Altitude (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Float is
   begin
      if Position_Nav.Has_Active_Target (N) and then N.Cmd.Include_Altitude then
         return Float'Max (-2.0 ** 18, Float'Min (2.0 ** 18, Position_Nav.Target_Altitude_Cm (N) * 0.01));
      end if;
      return Est.Position.Up * 0.01;
   end Commanded_Altitude;

   -------------------
   -- Braking_Decel --
   -------------------

   function Braking_Decel (Angle : Lean_Degrees) return Float is
     (G_Acceleration * Tangents (Natural'Max (Angle, Brake_Min_Angle)));

   ----------------
   -- Rest_Point --
   ----------------

   function Rest_Point (Est : Position_Nav.Estimate; Moving : Vector_2; Angle : Lean_Degrees) return Vector_2 is
      Closing_X : constant Float := Est.Velocity.East * 0.01 - Moving.X;
      Closing_Y : constant Float := Est.Velocity.North * 0.01 - Moving.Y;
      Speed     : constant Float := Root (Closing_X * Closing_X + Closing_Y * Closing_Y, 1.7e6);
      Scale     : constant Float := Speed / (2.0 * Braking_Decel (Angle)) + Brake_Response_S;
   begin
      pragma Assert (Scale in 0.0 .. 5.0e5);
      return (X => Est.Position.East * 0.01 + Closing_X * Scale,
              Y => Est.Position.North * 0.01 + Closing_Y * Scale);
   end Rest_Point;

   ------------------
   -- Place_Carrot --
   ------------------

   function Place_Carrot (Est : Position_Nav.Estimate; Velocity : Vector_2; Wanted : Vector_2; C : Settings)
     return Vector_2
   is
      Craft        : constant Vector_2 := (X => Est.Position.East * 0.01, Y => Est.Position.North * 0.01);
      Rest         : constant Vector_2 := Rest_Point (Est, Velocity, Lean_Degrees (C.Max_Angle));
      From_Craft_X : constant Float := Wanted.X - Craft.X;
      From_Craft_Y : constant Float := Wanted.Y - Craft.Y;
      From_Rest_X  : constant Float := Wanted.X - Rest.X;
      From_Rest_Y  : constant Float := Wanted.Y - Rest.Y;
      Nearer_Rest  : constant Boolean :=
        Root (From_Rest_X * From_Rest_X + From_Rest_Y * From_Rest_Y, 1.0e12)
          < Root (From_Craft_X * From_Craft_X + From_Craft_Y * From_Craft_Y, 1.0e12);
      Gap_X        : Float := (if Nearer_Rest then From_Rest_X else From_Craft_X);
      Gap_Y        : Float := (if Nearer_Rest then From_Rest_Y else From_Craft_Y);
      Gap_Length   : constant Float := Root (Gap_X * Gap_X + Gap_Y * Gap_Y, 1.0e12);
      Base         : constant Vector_2 := (if Nearer_Rest then Rest else Craft);
   begin
      if Gap_Length > Reach_M then
         Gap_X := Gap_X * (Reach_M / Gap_Length);
         Gap_Y := Gap_Y * (Reach_M / Gap_Length);
      end if;
      return (X => Float'Max (-Position_Nav.Metres_Bound, Float'Min (Position_Nav.Metres_Bound, Base.X + Gap_X)),
              Y => Float'Max (-Position_Nav.Metres_Bound, Float'Min (Position_Nav.Metres_Bound, Base.Y + Gap_Y)));
   end Place_Carrot;

   ----------------------
   -- Nav_Target_Delta --
   ----------------------

   function Nav_Target_Delta (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return ENU is
     (East  => N.Cmd.Target.East - Est.Position.East * 0.01,
      North => N.Cmd.Target.North - Est.Position.North * 0.01,
      Up    => (if N.Cmd.Include_Altitude then N.Cmd.Target.Up - Est.Position.Up * 0.01 else 0.0));

   ----------------------------
   -- Distance_To_Nav_Target --
   ----------------------------

   function Distance_To_Nav_Target (N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Float is
      D : constant ENU := Nav_Target_Delta (N, Est);
   begin
      pragma Assert (abs D.East <= 5.0e5 and then abs D.North <= 5.0e5 and then abs D.Up <= 5.0e5);
      return Root (D.East * D.East + D.North * D.North + D.Up * D.Up, 9.0e5);
   end Distance_To_Nav_Target;

   ------------------------
   -- Nav_Waypoint_Delta --
   ------------------------

   function Nav_Waypoint_Delta (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return ENU is
   begin
      if S.Leg_Is_Pass_Gate then
         return (East  => S.Leg_Target.East - Est.Position.East * 0.01,
                 North => S.Leg_Target.North - Est.Position.North * 0.01,
                 Up    => S.Leg_Target.Up - Est.Position.Up * 0.01);
      end if;
      return Nav_Target_Delta (N, Est);
   end Nav_Waypoint_Delta;

   ----------------------
   -- Braking_Distance --
   ----------------------

   function Braking_Distance (S : State; Est : Position_Nav.Estimate; C : Settings) return Float is
      Speed : constant Float :=
        Root (Est.Velocity.East * Est.Velocity.East + Est.Velocity.North * Est.Velocity.North, 2.4e7) * 0.01;
   begin
      if S.Leg_Turn_In then
         return Speed * Speed / (2.0 * Braking_Decel (Rescue_Stop_Max_Angle (C))) + Speed * Brake_Reversal_S
           + Turn_Width_M;
      end if;
      return Speed * Speed / (2.0 * Braking_Decel (Lean_Degrees (C.Max_Angle))) + Speed * Brake_Reversal_S;
   end Braking_Distance;

   ------------------
   -- Wrap_Deg_180 --
   ------------------

   function Wrap_Deg_180 (Deg : Float) return Float is
      Shifted : constant Float := Deg + 540.0;
      --  The remainder of the division by 360 with the dividend's sign, by
      --  one exact subtraction of the whole turns.
      Turns   : constant Float :=
        (if Shifted >= 1_800.0 then 1_800.0
         elsif Shifted >= 1_440.0 then 1_440.0
         elsif Shifted >= 1_080.0 then 1_080.0
         elsif Shifted >= 720.0 then 720.0
         elsif Shifted >= 360.0 then 360.0
         elsif Shifted > -360.0 then 0.0
         elsif Shifted > -720.0 then -360.0
         else -720.0);
      Wrapped : Float := Shifted - Turns;
   begin
      if Wrapped < 0.0 then
         Wrapped := Wrapped + 360.0;
      end if;
      return Wrapped - 180.0;
   end Wrap_Deg_180;

   ----------------------
   -- Bearing_To_Point --
   ----------------------

   procedure Bearing_To_Point (Est : Position_Nav.Estimate; Point : ENU; Bearing : out Float; Ok : out Boolean) is
      Delta_E : constant Float := Point.East - Est.Position.East * 0.01;
      Delta_N : constant Float := Point.North - Est.Position.North * 0.01;
   begin
      Bearing := 0.0;
      if Delta_E * Delta_E + Delta_N * Delta_N < Yaw_Bearing_Min_M * Yaw_Bearing_Min_M then
         Ok := False;
         return;
      end if;
      Bearing := Maths.Atan2_Approx (Delta_E, Delta_N) / Maths.Rad_Per_Degree;
      Ok := True;
   end Bearing_To_Point;

   ------------------------
   -- Leg_Nose_On_Target --
   ------------------------

   function Leg_Nose_On_Target (Est : Position_Nav.Estimate; Target : ENU; Yaw_Decidegrees : Integer_32)
     return Boolean
   is
      Bearing : Float;
      Ok      : Boolean;
   begin
      Bearing_To_Point (Est, Target, Bearing, Ok);
      if not Ok then
         return True;
      end if;
      return abs Wrap_Deg_180 (Float (Yaw_Decidegrees) * 0.1 - Bearing) < Yaw_Align_Deg;
   end Leg_Nose_On_Target;

   --------------------
   -- Pattern_Carrot --
   --------------------

   function Pattern_Carrot (S : State; Phase : Maths.Angle; Radius_M : Float) return ENU is
   begin
      if S.Pattern_Type = Flight_Plan.Pattern_Figure_8 then
         return (East  => S.Pattern_Centre.East + Radius_M * Maths.Sin_Approx (Phase),
                 North => S.Pattern_Centre.North + Radius_M * Maths.Sin_Approx (Phase) * Maths.Cos_Approx (Phase),
                 Up    => S.Pattern_Centre.Up);
      end if;
      return (East  => S.Pattern_Centre.East + Radius_M * Maths.Cos_Approx (Phase),
              North => S.Pattern_Centre.North + Radius_M * Maths.Sin_Approx (Phase),
              Up    => S.Pattern_Centre.Up);
   end Pattern_Carrot;

   --  The attitude handed back to position control from either stage of the
   --  rescue's heading recovery.
   procedure End_Heading_Recovery (S : in out State; O : in out Executor_Output) is
   begin
      if S.Rescue_Blind_Climb or else S.Rescue_Heading_Hold then
         Call (O, Heading_Recovery, False, 0.0);
      end if;
      S.Rescue_Blind_Climb := False;
      S.Rescue_Climbed := False;
      S.Rescue_Heading_Hold := False;
   end End_Heading_Recovery;

   -------------------
   -- Abort_Mission --
   -------------------

   procedure Abort_Mission
     (S : in out State; N : in out Position_Nav.Navigator; Reason : Abort_Reason; O : in out Executor_Output)
   is
   begin
      End_Heading_Recovery (S, O);
      S.Mode := Aborted;
      S.Reason := Reason;
      S.Pattern_Pending := False;
      S.Pattern_Active := False;
      S.In_Pre_Turn := False;
      Command_Nose (O, False, 0.0);
      Position_Nav.Clear_Target (N);
   end Abort_Mission;

   ------------------------------
   -- Update_Progress_Tracking --
   ------------------------------

   procedure Update_Progress_Tracking
     (S : in out State; N : in out Position_Nav.Navigator; Distance_M : Float; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
   is
   begin
      if not S.Best_Valid then
         S.Flyaway_Margin_M :=
           Constrain (Float'Max (Distance_M * Flyaway_Leg_Fraction, Braking_Distance (S, I.Est, C)),
                      Flyaway_Min_M, Flyaway_Max_M);
      end if;
      if not S.Best_Valid or else Distance_M < S.Best_Distance_M - Progress_Epsilon_M then
         S.Best_Valid := True;
         S.Best_Distance_M := Distance_M;
         S.Last_Progress_Us := I.Now_Us;
         return;
      end if;
      if Distance_M > S.Best_Distance_M + S.Flyaway_Margin_M then
         Abort_Mission (S, N, Flyaway, O);
         return;
      end if;
      if Clock.Elapsed (I.Now_Us, S.Last_Progress_Us) >= Stall_Timeout_Us then
         Abort_Mission (S, N, Stalled, O);
      end if;
   end Update_Progress_Tracking;

   -------------------------
   -- Check_Heading_Fault --
   -------------------------

   procedure Check_Heading_Fault
     (S : in out State; N : Position_Nav.Navigator; I : Leg_Inputs; C : Settings; Fault : out Boolean)
   is
   begin
      if C.Yaw_Mode = Yaw_Mode_Fixed or else C.Yaw_Mode = Yaw_Mode_Dampener then
         S.Hdg_Fault_Time_S := 0.0;
         Fault := False;
         return;
      end if;
      declare
         D       : constant ENU := Nav_Waypoint_Delta (S, N, I.Est);
         Bearing : constant Float := Maths.Atan2_Approx (D.East, D.North) / Maths.Rad_Per_Degree;
         Heading : constant Float := Float (I.Yaw_Decidegrees) * 0.1;
         Yaw_Err : constant Float := Wrap_Deg_180 (Heading - Bearing);
         Cog_Off : constant Float := abs Wrap_Deg_180 (Heading - Float (I.Ground_Course) * 0.1);
         Eligible : constant Boolean :=
           Float (I.Ground_Speed) > Hdg_Fault_Min_Cms and then abs Yaw_Err < Hdg_Fault_Aligned_Deg
           and then not S.In_Pre_Turn;
      begin
         S.Hdg_Fault_Time_S :=
           (if Eligible and then Cog_Off > Hdg_Fault_Err_Deg
            then Float'Min (1.0e6, S.Hdg_Fault_Time_S + I.Dt_S)
            else Float'Max (S.Hdg_Fault_Time_S - 2.0 * I.Dt_S, 0.0));
         Fault := S.Hdg_Fault_Time_S > Hdg_Fault_Time_S;
      end;
   end Check_Heading_Fault;

   --  The angle between two bearings in degrees.
   function Bearing_Gap (A, B : Float) return Float is (abs Wrap_Deg_180 (A - B))
     with Pre => A in -400.0 .. 400.0 and then B in -400.0 .. 400.0;

   --------------------
   -- Update_Leg_Yaw --
   --------------------

   procedure Update_Leg_Yaw
     (S : in out State; P : Flight_Plan.Plan; I : Leg_Inputs; O : in out Executor_Output)
   is
      Face    : ENU := S.Leg_Target;
      Bearing : Float;
      Ok      : Boolean;
   begin
      if S.Leg_Turn_In
        and then Root (S.Carrot_Velocity.X * S.Carrot_Velocity.X + S.Carrot_Velocity.Y * S.Carrot_Velocity.Y, 1.5e3)
          > 1.0
      then
         Command_Nose (O, True, Maths.Atan2_Approx (S.Carrot_Velocity.X, S.Carrot_Velocity.Y) / Maths.Rad_Per_Degree);
         return;
      end if;
      case S.Leg_Yaw_Behaviour is
         when Flight_Plan.Yaw_Hold =>
            Command_Nose (O, True, S.Leg_Yaw_Hold_Deg);
            return;
         when Flight_Plan.Yaw_Face_Target | Flight_Plan.Yaw_Face_Next =>
            null;
         when others =>
            return;
      end case;
      if S.Leg_Yaw_Behaviour = Flight_Plan.Yaw_Face_Next then
         declare
            Next : constant Natural := Next_Positional_Index (S, P, Natural (S.Current_Index) + 1);
         begin
            if Next >= Active_Count (S, P) then
               Command_Nose (O, False, 0.0);
               return;
            end if;
            Compute_Target (S, Active_Waypoint (S, P, Next), I.Has_Origin, I.Origin, I.Cos_Lat, Face, Ok);
            if not Ok then
               Command_Nose (O, False, 0.0);
               return;
            end if;
         end;
      end if;
      Bearing_To_Point (I.Est, Face, Bearing, Ok);
      if not Ok then
         Command_Nose (O, False, 0.0);
         S.Leg_Yaw_Gated := False;
         return;
      end if;
      pragma Assert (Bearing in -180.01 .. 180.01);
      declare
         Waited_Out : constant Boolean := Clock.Elapsed (I.Now_Us, S.Leg_Yaw_Gate_Start) >= Yaw_Align_Timeout_Us;
         Speed_Mps  : constant Float :=
           Root (I.Est.Velocity.East * I.Est.Velocity.East + I.Est.Velocity.North * I.Est.Velocity.North, 2.4e7)
             * 0.01;
      begin
         S.Leg_Yaw_Braked := S.Leg_Yaw_Braked or else Waited_Out or else Speed_Mps <= Yaw_Swing_Max_Mps;
         if (S.Leg_Yaw_Gated or else (S.Is_Rescue_Plan and then S.Current_Index = 0)) and then not S.Leg_Yaw_Braked
         then
            Command_Nose (O, True, S.Leg_Yaw_Hold_Deg);
            return;
         end if;
         Command_Nose (O, True, Bearing);
         if S.Leg_Yaw_Gated then
            if Bearing_Gap (Float (I.Yaw_Decidegrees) * 0.1, Bearing) < Yaw_Align_Deg then
               S.Leg_Yaw_Gated := False;
            elsif Waited_Out then
               S.Leg_Yaw_Gated := False;
               S.Leg_Yaw_Timed_Out := True;
            end if;
         end if;
      end;
   end Update_Leg_Yaw;

   --  A component of a unit vector held within two, which it never reaches,
   --  and a quantity held within a bound it never reaches, so neither hold
   --  acts.
   function Unit_Held (X : Float) return Float is (Float'Max (-2.0, Float'Min (2.0, X)));
   function Held (X : Float; Bound : Float) return Float is (Float'Max (-Bound, Float'Min (Bound, X)))
     with Pre => Bound in 0.0 .. 1.0e30;

   --  The root of a positive squared norm, held above the root of the
   --  smallest positive float so that its reciprocal is finite.
   Min_Root : constant := 2.0 ** (-75);
   function Positive_Root (Sq : Float) return Float is
     (Float'Max (Min_Root, Ada.Numerics.Elementary_Functions.Sqrt (Sq)))
     with Pre => Sq > 0.0, Post => Positive_Root'Result >= Min_Root;

   --  The unit vector along X and Y, or zero for a zero vector.
   function Unit_Direction (X, Y : Float) return Vector_2
     with Pre  => abs X <= 2.0e7 and then abs Y <= 2.0e7,
          Post => abs Unit_Direction'Result.X <= 2.0 and then abs Unit_Direction'Result.Y <= 2.0
   is
      Norm_Sq : constant Float range 0.0 .. 1.0e15 := X * X + Y * Y;
   begin
      if Norm_Sq > 0.0 then
         declare
            Inverse : constant Float range 0.0 .. 2.0 ** 75 := 1.0 / Positive_Root (Norm_Sq);
         begin
            return (X => Unit_Held (X * Inverse), Y => Unit_Held (Y * Inverse));
         end;
      end if;
      return (X => 0.0, Y => 0.0);
   end Unit_Direction;

   --  The carrot's direction of flight turned toward the aim by at most the
   --  turn budget, the turn the aim asks for, and the speed the turning
   --  takes; the aim itself while the carrot is all but still.
   procedure Turn_Toward
     (Velocity    : Vector_2;
      Flying      : Float;
      Aim         : Vector_2;
      Turn_Budget : Float;
      Direction   : out Vector_2;
      Turn_Rad    : out Float;
      Turning     : out Float)
     with Global => null,
          Pre    => abs Velocity.X <= 1_000.0 and then abs Velocity.Y <= 1_000.0 and then Flying in 0.0 .. 1.5e3
                    and then abs Aim.X <= 2.0 and then abs Aim.Y <= 2.0 and then Turn_Budget in 0.0 .. 7.0,
          Post   => abs Direction.X <= 2.0e5 and then abs Direction.Y <= 2.0e5
                    and then Turn_Rad in -Maths.Pi .. Maths.Pi and then Turning in 0.0 .. 5.0e3
   is
   begin
      Direction := Aim;
      Turn_Rad := 0.0;
      Turning := 0.0;
      if Flying > 0.01 then
         declare
            Inverse : constant Float range 0.0 .. 100.0 := 1.0 / Flying;
            Along_X : constant Float range -1.0e5 .. 1.0e5 := Velocity.X * Inverse;
            Along_Y : constant Float range -1.0e5 .. 1.0e5 := Velocity.Y * Inverse;
         begin
            Turn_Rad := Maths.Atan2_Approx (Along_X * Aim.Y - Along_Y * Aim.X, Along_X * Aim.X + Along_Y * Aim.Y);
            Turning := abs Turn_Rad * Flying;
            if Turning > Turn_Budget then
               declare
                  Step   : constant Float range -1.0e3 .. 1.0e3 :=
                    (if Turn_Rad > 0.0 then Turn_Budget else -Turn_Budget) / Flying;
                  Sine   : Maths.Cosine;
                  Cosine : Maths.Cosine;
               begin
                  Maths.Sin_Cos_Approx (Step, Sine, Cosine);
                  Direction := (X => Along_X * Cosine - Along_Y * Sine, Y => Along_X * Sine + Along_Y * Cosine);
                  Turning := Turn_Budget;
               end;
            end if;
         end;
      end if;
   end Turn_Toward;

   --  The craft's course within the turn-in's done angle of the waypoint, or
   --  the craft all but stopped.
   function Course_On_Waypoint (Est : Position_Nav.Estimate; To_Wp : Vector_2) return Boolean
     with Pre => abs To_Wp.X <= 1.0e6 and then abs To_Wp.Y <= 1.0e6
   is
      Vel_X      : constant Float range -2.0e5 .. 2.0e5 := Est.Velocity.East * 0.01;
      Vel_Y      : constant Float range -2.0e5 .. 2.0e5 := Est.Velocity.North * 0.01;
      Cross      : constant Float range -1.0e12 .. 1.0e12 := Vel_X * To_Wp.Y - Vel_Y * To_Wp.X;
      Dot        : constant Float range -1.0e12 .. 1.0e12 := Vel_X * To_Wp.X + Vel_Y * To_Wp.Y;
      Course_Off : constant Maths.Half_Turn := Maths.Atan2_Approx (Cross, Dot);
   begin
      return Root (Vel_X * Vel_X + Vel_Y * Vel_Y, 3.0e5) < 1.0 or else abs Course_Off < Rad_15;
   end Course_On_Waypoint;

   --  The carrot steered onto the leg line toward a point one lead ahead, at
   --  the profile speed within the carrot's acceleration, with the turn-in's
   --  braking and turn, the lean cap's release and the approach brake; then
   --  placed within reach, the nose commanded, and the carrot and its
   --  velocity handed to the navigator.
   procedure Steer
     (S             : in out State;
      N             : in out Position_Nav.Navigator;
      I             : Leg_Inputs;
      C             : Settings;
      Dir           : Vector_2;
      To_Wp         : Vector_2;
      Dist          : Float;
      Carrot_To_Wp  : Float;
      Leg_Bearing   : Float;
      Nose_Bearing  : Float;
      Aligned       : Boolean;
      Profile_Speed : Float;
      O             : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S) and then abs Dir.X <= 2.0 and then abs Dir.Y <= 2.0
                    and then abs To_Wp.X <= 1.0e6 and then abs To_Wp.Y <= 1.0e6
                    and then Dist in 0.0 .. 1.0e6 and then Carrot_To_Wp in 0.0 .. 1.0e6
                    and then Leg_Bearing in -181.0 .. 181.0 and then Profile_Speed in 0.0 .. 1_000.0,
          Post   => Leg_Bounded (S)
   is
      Accel          : constant Float range 0.0 .. 10.1 := Float (C.Nav_Accel) * 0.01;
      Lead_Time      : constant Float range 0.0 .. 4.1 := Float (C.Lead_Time) * 0.1;
      Lead_Max       : constant Float range 5.0 .. 61.0 := Float (C.Lead_Max) * 0.01;
      From_Start_X   : constant Float range -6.0e5 .. 6.0e5 := S.Carrot.X - S.Leg_Start.X;
      From_Start_Y   : constant Float range -6.0e5 .. 6.0e5 := S.Carrot.Y - S.Leg_Start.Y;
      Carrot_Along   : constant Float range -3.0e6 .. 3.0e6 := From_Start_X * Dir.X + From_Start_Y * Dir.Y;
      Carrot_Cross   : constant Float range -3.0e6 .. 3.0e6 := From_Start_X * Dir.Y - From_Start_Y * Dir.X;
      Lead           : constant Float range 0.0 .. 61.0 :=
        Constrain (S.Carrot_Speed * Lead_Time, Carrot_Lead_Min_M, Lead_Max);
      Ahead          : constant Float range 0.0 .. 3.0e6 := Float'Max (Lead, abs Carrot_Cross);
      Aim_X          : Float range -2.0e7 .. 2.0e7 := S.Leg_Start.X + Dir.X * (Carrot_Along + Ahead) - S.Carrot.X;
      Aim_Y          : Float range -2.0e7 .. 2.0e7 := S.Leg_Start.Y + Dir.Y * (Carrot_Along + Ahead) - S.Carrot.Y;
      Budget         : constant Float range 0.0 .. 2.6 := Accel * I.Dt_S;
      Flying         : constant Float range 0.0 .. 1.5e3 :=
        Root (S.Carrot_Velocity.X * S.Carrot_Velocity.X + S.Carrot_Velocity.Y * S.Carrot_Velocity.Y, 1.5e3);
      Turn_Budget    : Float range 0.0 .. 7.0 := Budget;
      Slow_Budget    : Float range 0.0 .. 7.0 := Budget;
      Turn_In_Braked : Boolean := True;
      Desired        : Float range 0.0 .. 1_000.0 := Profile_Speed;
      Direction      : Vector_2;
      Turn_Rad       : Float;
      Turning        : Float;
   begin
      if S.Leg_Turn_In then
         --  Straight at the waypoint at the turn-in speed, braked at the
         --  rescue's lean before the turn comes round at the turn-in rate.
         Aim_X := S.Leg_Target.East - S.Carrot.X;
         Aim_Y := S.Leg_Target.North - S.Carrot.Y;
         Desired := Float'Min (S.Leg_Cruise, Turn_In_Mps);
         if S.Leg_Approach_Decel > 0.0 then
            Desired := Float'Min (Desired, Position_Nav.Approach_Speed
                                    (S.Leg_Cruise, S.Leg_Approach_Decel, Rescue_Still_Radius_M, Dist));
         end if;
         Desired := Float'Min (Desired, 0.5 * Rad_30 * Carrot_To_Wp);
         declare
            Lean      : constant Float range 1.7 .. 27.0 := Braking_Decel (Rescue_Stop_Max_Angle (C));
            Turn_Rate : constant Float range 0.0 .. 27.0 := Float'Min (Rad_30 * Flying, Lean);
         begin
            Slow_Budget := Lean * I.Dt_S;
            Turn_In_Braked := S.Carrot_Speed <= Desired + Slow_Budget;
            Turn_Budget := (if Turn_In_Braked then Turn_Rate * I.Dt_S else 0.0);
         end;
      end if;
      Turn_Toward (S.Carrot_Velocity, Flying, Unit_Direction (Aim_X, Aim_Y), Turn_Budget, Direction, Turn_Rad, Turning);
      declare
         Speed_Up : constant Float range 0.0 .. 10.0 :=
           Root (Float'Max (Budget * Budget - Turning * Turning, 0.0), 10.0);
         Low      : constant Float range -7.0 .. 1_000.0 := S.Carrot_Speed - Slow_Budget;
         High     : constant Float range 0.0 .. 1_010.0 := S.Carrot_Speed + Speed_Up;
      begin
         S.Carrot_Speed := Constrain (Desired, Low, High);
      end;
      if S.Leg_Turn_In and then Turn_In_Braked and then abs Turn_Rad < Rad_15 then
         S.Leg_Turn_In := False;
         S.Leg_Valid := False;
      end if;
      if S.Leg_Turn_Capped and then not S.Leg_Turn_In and then Course_On_Waypoint (I.Est, To_Wp) then
         S.Leg_Turn_Capped := False;
         Position_Nav.Set_Max_Angle (N, 0.0);
      end if;
      if S.Leg_Approach_Decel > 0.0 and then not S.Leg_Turn_In then
         S.Carrot_Speed := Float'Min (S.Carrot_Speed, Position_Nav.Approach_Speed
                                        (S.Leg_Cruise, S.Leg_Approach_Decel, Rescue_Still_Radius_M, Dist));
      end if;
      declare
         Vel_X : constant Float range -1_000.0 .. 1_000.0 := Held (Direction.X * S.Carrot_Speed, 1_000.0);
         Vel_Y : constant Float range -1_000.0 .. 1_000.0 := Held (Direction.Y * S.Carrot_Speed, 1_000.0);
      begin
         S.Carrot_Velocity := (X => Vel_X, Y => Vel_Y);
         S.Carrot := Place_Carrot (I.Est, (X => Vel_X, Y => Vel_Y), S.Carrot, C);
      end;
      if S.Leg_Yaw_Behaviour = Flight_Plan.Yaw_Default then
         declare
            Carrot_Bearing : constant Float range -181.0 .. 181.0 :=
              Maths.Atan2_Approx (S.Carrot_Velocity.X, S.Carrot_Velocity.Y) / Maths.Rad_Per_Degree;
            Coming_Round   : constant Boolean :=
              S.Carrot_Speed > Min_Cruise_Mps and then Bearing_Gap (Carrot_Bearing, Leg_Bearing) > Yaw_Align_Deg;
         begin
            if S.In_Pre_Turn or else not Aligned or else Coming_Round then
               Command_Nose (O, True, Nose_Bearing);
            else
               Command_Nose (O, False, 0.0);
            end if;
         end;
      end if;
      Position_Nav.Move_Target (N, (East => S.Carrot.X, North => S.Carrot.Y, Up => S.Leg_Target.Up));
      Position_Nav.Set_Velocity_Feedforward (N, (East => S.Carrot_Velocity.X, North => S.Carrot_Velocity.Y));
   end Steer;

   --  The corner speed on a constant budget of velocity change, and whether
   --  the leg turns at the gate.
   procedure Corner_Speed
     (Wp, In_From, Next : Vector_2;
      Have_Next         : Boolean;
      Cruise            : Speed;
      C                 : Settings;
      Corner            : out Float;
      Turns_At_Gate     : out Boolean)
     with Global => null,
          Pre    => abs Wp.X <= Position_Nav.Metres_Bound and then abs Wp.Y <= Position_Nav.Metres_Bound
                    and then abs In_From.X <= Position_Nav.Metres_Bound
                    and then abs In_From.Y <= Position_Nav.Metres_Bound
                    and then abs Next.X <= 2.5e7 and then abs Next.Y <= 2.5e7,
          Post   => Corner in 0.0 .. 1_000.0
   is
      Floor   : constant Float range 0.0 .. 20.1 := Float (C.Corner_Speed) * 0.01;
      Delta_V : constant Float range 0.0 .. 40.1 := Float (C.Corner_Delta_V) * 0.01;
   begin
      Corner := Cruise;
      Turns_At_Gate := False;
      if Have_Next then
         declare
            In_X    : constant Float range -6.0e5 .. 6.0e5 := Wp.X - In_From.X;
            In_Y    : constant Float range -6.0e5 .. 6.0e5 := Wp.Y - In_From.Y;
            Out_X   : constant Float range -3.0e7 .. 3.0e7 := Next.X - Wp.X;
            Out_Y   : constant Float range -3.0e7 .. 3.0e7 := Next.Y - Wp.Y;
            In_Len  : constant Float range 0.0 .. 1.0e6 := Root (In_X * In_X + In_Y * In_Y, 1.0e6);
            Out_Len : constant Float range 0.0 .. 5.0e7 := Root (Out_X * Out_X + Out_Y * Out_Y, 5.0e7);
         begin
            if In_Len > 1.0 and then Out_Len > 1.0 then
               declare
                  Cos_Turn : constant Float range -1.0e14 .. 1.0e14 :=
                    (In_X * Out_X + In_Y * Out_Y) / (In_Len * Out_Len);
                  Shed     : constant Float range 0.0 .. 1.5e7 := Root (Float'Max (2.0 - 2.0 * Cos_Turn, 0.0), 1.5e7);
               begin
                  Turns_At_Gate := Shed > 0.05;
                  Corner := (if Turns_At_Gate then Constrain (Delta_V / Shed, Floor, Cruise) else Cruise);
               end;
            end if;
         end;
      end if;
   end Corner_Speed;

   --  A crossing past the waypoint along the leg inside the lateral
   --  corridor.
   function Overran (Wp, Start, Craft : Vector_2) return Boolean
     with Pre => abs Wp.X <= Position_Nav.Metres_Bound and then abs Wp.Y <= Position_Nav.Metres_Bound
                 and then abs Start.X <= Position_Nav.Metres_Bound and then abs Start.Y <= Position_Nav.Metres_Bound
                 and then abs Craft.X <= 2.0e5 and then abs Craft.Y <= 2.0e5
   is
      In_X   : constant Float range -6.0e5 .. 6.0e5 := Wp.X - Start.X;
      In_Y   : constant Float range -6.0e5 .. 6.0e5 := Wp.Y - Start.Y;
      In_Len : constant Float range 0.0 .. 1.0e6 := Root (In_X * In_X + In_Y * In_Y, 1.0e6);
   begin
      if In_Len > 1.0 then
         declare
            Ux      : constant Float range -2.0 .. 2.0 := Unit_Held (In_X / In_Len);
            Uy      : constant Float range -2.0 .. 2.0 := Unit_Held (In_Y / In_Len);
            From_X  : constant Float range -6.0e5 .. 6.0e5 := Craft.X - Start.X;
            From_Y  : constant Float range -6.0e5 .. 6.0e5 := Craft.Y - Start.Y;
            Along   : constant Float range -3.0e6 .. 3.0e6 := From_X * Ux + From_Y * Uy;
            Lateral : constant Float range 0.0 .. 3.0e6 := abs (From_Y * Ux - From_X * Uy);
         begin
            return Along > In_Len and then Lateral < Overrun_Lat_M;
         end;
      end if;
      return False;
   end Overran;

   --  The leg line from its anchor, the filtered along-track distance, the
   --  speed profile into the corner, the pre-turn onto the next leg, the
   --  march gate, then the carrot steered.
   procedure Track_Leg
     (S            : in out State;
      N            : in out Position_Nav.Navigator;
      I            : Leg_Inputs;
      C            : Settings;
      Craft        : Vector_2;
      To_Wp        : Vector_2;
      Dist         : Float;
      Carrot_To_Wp : Float;
      Next         : Vector_2;
      Have_Next    : Boolean;
      Arrive       : Float;
      Corner       : Float;
      O            : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S) and then abs Craft.X <= 2.0e5 and then abs Craft.Y <= 2.0e5
                    and then abs To_Wp.X <= 1.0e6 and then abs To_Wp.Y <= 1.0e6
                    and then Dist in 0.0 .. 1.0e6 and then Carrot_To_Wp in 0.0 .. 1.0e6
                    and then abs Next.X <= 2.5e7 and then abs Next.Y <= 2.5e7
                    and then Arrive in 0.0 .. 1.0e5 and then Corner in 0.0 .. 1_000.0,
          Post   => Leg_Bounded (S)
   is
      Decel : constant Float range 0.0 .. 10.1 := Float (C.Nav_Decel) * 0.01;
   begin
      if not S.Leg_Valid then
         S.Leg_Start := (if S.Leg_Anchor_Valid then S.Leg_Anchor else S.Carrot);
         S.Leg_Anchor_Valid := False;
         S.Leg_Valid := True;
         S.Meas_Filt_Valid := False;
      end if;
      declare
         Wp        : constant Vector_2 := (X => S.Leg_Target.East, Y => S.Leg_Target.North);
         Leg_X     : constant Float range -6.0e5 .. 6.0e5 := Wp.X - S.Leg_Start.X;
         Leg_Y     : constant Float range -6.0e5 .. 6.0e5 := Wp.Y - S.Leg_Start.Y;
         Leg_Len   : constant Float range 0.0 .. 1.0e6 := Root (Leg_X * Leg_X + Leg_Y * Leg_Y, 1.0e6);
         Dir_X     : constant Float range -2.0 .. 2.0 := (if Leg_Len > 1.0 then Unit_Held (Leg_X / Leg_Len) else 1.0);
         Dir_Y     : constant Float range -2.0 .. 2.0 := (if Leg_Len > 1.0 then Unit_Held (Leg_Y / Leg_Len) else 0.0);
         From_X    : constant Float range -6.0e5 .. 6.0e5 := Craft.X - S.Leg_Start.X;
         From_Y    : constant Float range -6.0e5 .. 6.0e5 := Craft.Y - S.Leg_Start.Y;
         Along_Raw : constant Float range -3.0e6 .. 3.0e6 := From_X * Dir_X + From_Y * Dir_Y;
      begin
         if not S.Meas_Filt_Valid or else I.Dt_S <= 0.0 then
            S.Along_Filt_M := Along_Raw;
            S.Meas_Filt_Valid := True;
         else
            declare
               Alpha : constant Float range 0.0 .. 1.0 := I.Dt_S / (Meas_Filter_S + I.Dt_S);
            begin
               S.Along_Filt_M := Held (S.Along_Filt_M + Alpha * (Along_Raw - S.Along_Filt_M), 1.0e7);
            end;
         end if;
         declare
            Remaining_Raw   : constant Float range 0.0 .. 5.0e6 := Float'Max (Leg_Len - Along_Raw - Arrive, 0.0);
            Remaining_Filt  : constant Float range 0.0 .. 1.2e7 := Float'Max (Leg_Len - S.Along_Filt_M - Arrive, 0.0);
            Brake_Lag       : constant Float range 0.0 .. 500.0 := S.Carrot_Speed * Carrot_Brake_Lag_S;
            Remaining_Brake : constant Float range 0.0 .. 1.2e7 := Float'Max (Remaining_Filt - Brake_Lag, 0.0);
            Desired         : Float range 0.0 .. 1_000.0 :=
              Float'Min (S.Leg_Cruise, Root (Corner * Corner + 2.0 * Decel * Remaining_Brake, 1.0e5));
            Heading         : constant Float range 0.0 .. 360.1 := Float (I.Yaw_Decidegrees) * 0.1;
            Leg_Bearing     : constant Float range -181.0 .. 181.0 :=
              Maths.Atan2_Approx (Dir_X, Dir_Y) / Maths.Rad_Per_Degree;
            Leg_Err         : constant Float := Wrap_Deg_180 (Heading - Leg_Bearing);
            Nose_Bearing    : Float range -400.0 .. 400.0 := Leg_Bearing;
            Aligned         : Boolean;
         begin
            --  The pre-turn blends the nose onto the next leg through the
            --  approach.
            S.In_Pre_Turn := False;
            if Have_Next then
               declare
                  Preturn    : constant Float range 0.0 .. 50.1 := Float (C.Preturn_Dist) * 0.01;
                  T          : constant Float range 0.0 .. 1.0 :=
                    1.0 - Constrain ((Remaining_Raw - 5.0) / Float'Max (Preturn - 5.0, 1.0), 0.0, 1.0);
                  Next_Leg_X : constant Float range -3.0e7 .. 3.0e7 := Next.X - Wp.X;
                  Next_Leg_Y : constant Float range -3.0e7 .. 3.0e7 := Next.Y - Wp.Y;
               begin
                  if T > 0.0 and then Root (Next_Leg_X * Next_Leg_X + Next_Leg_Y * Next_Leg_Y, 5.0e7) > 1.0 then
                     declare
                        Next_Bearing : constant Float range -181.0 .. 181.0 :=
                          Maths.Atan2_Approx (Next_Leg_X, Next_Leg_Y) / Maths.Rad_Per_Degree;
                     begin
                        Nose_Bearing := Leg_Bearing + T * Wrap_Deg_180 (Next_Bearing - Leg_Bearing);
                        S.In_Pre_Turn := True;
                     end;
                  end if;
               end;
            end if;
            Aligned := abs Leg_Err < 90.0 or else S.In_Pre_Turn or else S.Leg_Yaw_Timed_Out;
            if not Aligned or else S.Leg_Yaw_Gated or else Leg_Len <= 1.0 then
               Desired := 0.0;
            end if;
            Steer (S, N, I, C, (X => Dir_X, Y => Dir_Y), To_Wp, Dist, Carrot_To_Wp, Leg_Bearing, Nose_Bearing,
                   Aligned, Desired, O);
         end;
      end;
   end Track_Leg;

   -----------------------
   -- Update_Leg_Carrot --
   -----------------------

   procedure Update_Leg_Carrot
     (S            : in out State;
      N            : in out Position_Nav.Navigator;
      P            : Flight_Plan.Plan;
      I            : Leg_Inputs;
      C            : Settings;
      O            : in out Executor_Output;
      Gate_Crossed : out Boolean)
   is
      Craft      : constant Vector_2 := (X => I.Est.Position.East * 0.01, Y => I.Est.Position.North * 0.01);
      Wp         : constant Vector_2 := (X => S.Leg_Target.East, Y => S.Leg_Target.North);
      To_Wp      : constant Vector_2 := (X => Wp.X - Craft.X, Y => Wp.Y - Craft.Y);
      Dist       : constant Float range 0.0 .. 1.0e6 := Root (To_Wp.X * To_Wp.X + To_Wp.Y * To_Wp.Y, 1.0e6);
      Next_Index : constant Natural := Next_Positional_Index (S, P, Natural (S.Current_Index) + 1);
      Next       : Vector_2 := Wp;
      Have_Next  : Boolean := False;
      Corner     : Float range 0.0 .. 1_000.0;
      Turns      : Boolean;
   begin
      Gate_Crossed := False;
      S.Carrot := Read_Back_Carrot (N);
      if Next_Index < Active_Count (S, P) then
         declare
            Next_Target : ENU;
            Ok          : Boolean;
         begin
            Compute_Target (S, Active_Waypoint (S, P, Next_Index), I.Has_Origin, I.Origin, I.Cos_Lat, Next_Target, Ok);
            if Ok then
               Next := (X => Next_Target.East, Y => Next_Target.North);
               Have_Next := True;
            end if;
         end;
      end if;
      Corner_Speed (Wp, (if S.Leg_Valid then S.Leg_Start else Craft), Next, Have_Next, S.Leg_Cruise, C, Corner, Turns);

      declare
         Flyby    : constant Boolean :=
           Natural (S.Current_Index) >= Active_Count (S, P)
           or else Active_Waypoint (S, P, Natural (S.Current_Index)).Kind = Flight_Plan.Type_Flyby;
         Arrive   : constant Float range 0.0 .. 1.0e5 :=
           (if Flyby
            then Constrain (Corner * Gate_Radius_Scale, Float'Min (S.Leg_Arrive_Radius, Pass_Max_M), Pass_Max_M)
            else S.Leg_Arrive_Radius);
         Ran_Over : constant Boolean := S.Leg_Valid and then Overran (Wp, S.Leg_Start, Craft);
      begin
         --  A point leg next takes over at no more than its braking speed.
         if Have_Next and then S.Leg_Approach_Decel <= 0.0
           and then not Flown_As_Carrot_Leg (S, P, Active_Waypoint (S, P, Next_Index), Next_Index)
         then
            declare
               Out_X     : constant Float range -3.0e7 .. 3.0e7 := Next.X - Wp.X;
               Out_Y     : constant Float range -3.0e7 .. 3.0e7 := Next.Y - Wp.Y;
               Out_Len   : constant Float range 0.0 .. 5.0e7 := Root (Out_X * Out_X + Out_Y * Out_Y, 5.0e7);
               Hand_Over : constant Float range 0.0 .. 6.0e7 := Root (Out_Len * Out_Len + Arrive * Arrive, 6.0e7);
            begin
               Corner := Float'Min (Corner, Root (2.0 * Approach_Decel_Mps2 * Hand_Over, 1.0e4));
            end;
         end if;

         Update_Progress_Tracking (S, N, Dist, I, C, O);
         if S.Mode /= Targeting then
            return;
         end if;

         declare
            Carrot_To_Wp_X : constant Float range -6.0e5 .. 6.0e5 := Wp.X - S.Carrot.X;
            Carrot_To_Wp_Y : constant Float range -6.0e5 .. 6.0e5 := Wp.Y - S.Carrot.Y;
            Carrot_To_Wp   : constant Float range 0.0 .. 1.0e6 :=
              Root (Carrot_To_Wp_X * Carrot_To_Wp_X + Carrot_To_Wp_Y * Carrot_To_Wp_Y, 1.0e6);
            Gate_Dist      : constant Float := (if Turns then Float'Min (Dist, Carrot_To_Wp) else Dist);
         begin
            if not S.Leg_Yaw_Gated and then not S.Leg_Turn_In and then not S.Leg_Turn_Capped
              and then (Gate_Dist < Arrive or else Ran_Over)
            then
               S.Leg_Anchor := Wp;
               S.Leg_Anchor_Valid := True;
               Gate_Crossed := True;
               return;
            end if;
            Track_Leg (S, N, I, C, Craft, To_Wp, Dist, Carrot_To_Wp, Next, Have_Next, Arrive, Corner, O);
         end;
      end;
   end Update_Leg_Carrot;

   --  The plan over: the target dropped and the nose handed back.
   procedure Complete_Plan (S : in out State; N : in out Position_Nav.Navigator; O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
   begin
      S.Mode := Complete;
      Position_Nav.Clear_Target (N);
      Command_Nose (O, False, 0.0);
   end Complete_Plan;

   --  The current waypoint and those after it walked past while they are
   --  modifiers, each staged for the next leg: an altitude override, a delay
   --  window, and a yaw rate cap. Found is false when the plan ends first.
   procedure Drain_Modifiers
     (S      : in out State;
      P      : Flight_Plan.Plan;
      Now_Us : Unsigned_32;
      O      : in out Executor_Output;
      W      : out Flight_Plan.Waypoint;
      Found  : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S) and then S.Injected_Waypoints = S.Injected_Waypoints'Old
                    and then (if Found then Natural (S.Current_Index) < Active_Count (S, P))
   is
   begin
      W := (others => <>);
      Found := False;
      for Guard in 1 .. Flight_Plan.Max_Waypoints loop
         pragma Loop_Invariant (Leg_Bounded (S) and then S.Injected_Waypoints = S.Injected_Waypoints'Loop_Entry);
         if Natural (S.Current_Index) >= Active_Count (S, P) then
            return;
         end if;
         W := Active_Waypoint (S, P, Natural (S.Current_Index));
         case W.Kind is
            when Flight_Plan.Type_Alt_Change =>
               S.Alt_Override_Pending := True;
               S.Alt_Override_Cm := W.Altitude;
               S.Alt_Override_Mode := W.Pattern;
            when Flight_Plan.Type_Delay =>
               S.Delay_Active := True;
               S.Delay_Duration_Ds := W.Duration_Ds;
               S.Delay_End_Us := Now_Us + Unsigned_32 (W.Duration_Ds) * 100_000;
            when Flight_Plan.Type_Yaw_Rate =>
               S.Yaw_Rate_Cap_Dps := Float (W.Speed);
               Call (O, Yaw_Rate_Limit, True, S.Yaw_Rate_Cap_Dps);
            when others =>
               Found := True;
               return;
         end case;
         S.Current_Index := S.Current_Index + 1;
         if Natural (S.Current_Index) >= Active_Count (S, P) then
            return;
         end if;
      end loop;
   end Drain_Modifiers;

   function Is_Rescue_Stop (S : State) return Boolean is (S.Is_Rescue_Plan and then S.Current_Index = 0);

   --  A target held within the navigator's bound, which no waypoint within
   --  the estimator's reach of the origin comes near.
   function Held_Target (T : ENU) return ENU is
     (East  => Held (T.East, Position_Nav.Metres_Bound),
      North => Held (T.North, Position_Nav.Metres_Bound),
      Up    => Held (T.Up, Position_Nav.Metres_Bound));

   --  The leg to a waypoint whose target is known: its radius, approach and
   --  cruise, the nose and its gate, then the carrot, the hold while the
   --  nose comes round, or the point leg handed to the navigator.
   procedure Dispatch_Leg
     (S         : in out State;
      N         : in out Position_Nav.Navigator;
      P         : Flight_Plan.Plan;
      I         : Leg_Inputs;
      C         : Settings;
      O         : in out Executor_Output;
      Effective : Flight_Plan.Waypoint;
      Computed  : ENU)
     with Global => null,
          Pre    => Leg_Bounded (S) and then Natural (S.Current_Index) < Active_Count (S, P)
                    and then abs Computed.East <= 2.5e7 and then abs Computed.North <= 2.5e7
                    and then abs Computed.Up <= 4.5e7,
          Post   => Leg_Bounded (S)
   is
      Est             : Position_Nav.Estimate renames I.Est;
      Craft           : constant Vector_2 := (X => Est.Position.East * 0.01, Y => Est.Position.North * 0.01);
      Blind_Climb     : constant Boolean :=
        Is_Rescue_Stop (S) and then Active_Count (S, P) > 1 and then I.Heading_Required and then not I.Heading_Valid;
      Rescue_Stop     : constant Boolean := Is_Rescue_Stop (S) and then not Blind_Climb;
      Station         : constant Boolean := Is_Station_Keeping (Effective.Kind);
      Approach_Rescue : constant Boolean :=
        S.Is_Rescue_Plan and then not Rescue_Stop
        and then (Effective.Kind = Flight_Plan.Type_Flyover or else Effective.Kind = Flight_Plan.Type_Land);
      Face_Target     : constant Boolean := Effective.Yaw_Behaviour = Flight_Plan.Yaw_Face_Target;
      Pass_Gate       : constant Boolean := Flown_As_Carrot_Leg (S, P, Effective, Natural (S.Current_Index));
      Turn_In         : constant Boolean := S.Turn_In_Requested and then Pass_Gate;
      Target          : ENU := Computed;
      Arrival         : Float range 0.0 .. 500.0 :=
        (if Station then Float (C.Radius) * 0.01 else Float'Min (Float (C.Arrival_Radius) * 0.01, Pass_Max_M));
      Cruise          : Float range 0.0 .. 1_000.0 :=
        (if Effective.Speed > 0 then Float (Effective.Speed) * 0.01 else Float (C.Max_Speed) * 0.01);
   begin
      --  A takeoff climbs where the craft is; the rescue's stop holds where
      --  the craft comes to rest.
      if Effective.Kind = Flight_Plan.Type_Takeoff then
         Target.East := Craft.X;
         Target.North := Craft.Y;
      end if;
      if Rescue_Stop then
         declare
            Hold : constant Vector_2 := Rest_Point (Est, (X => 0.0, Y => 0.0), Rescue_Stop_Max_Angle (C));
         begin
            Target.East := Hold.X;
            Target.North := Hold.Y;
         end;
      end if;
      Target := Held_Target (Target);
      if Approach_Rescue then
         Arrival := Float'Max (Arrival, Float (C.Descent_Dist_M));
      end if;
      S.Leg_Arrive_Radius := Arrival;
      S.Leg_Approach_Decel := (if Approach_Rescue then Rescue_Approach_Decel else 0.0);
      if Cruise < Min_Cruise_Mps then
         Cruise := Min_Cruise_Mps;
      end if;

      --  A delay stretches the leg from where the craft is over its time.
      if S.Delay_Active then
         declare
            Delay_S : constant Float range 0.0 .. 6_553.6 := Float (S.Delay_Duration_Ds) * 0.1;
            Leg_E   : constant Float range -6.0e5 .. 6.0e5 := Target.East - Est.Position.East * 0.01;
            Leg_N   : constant Float range -6.0e5 .. 6.0e5 := Target.North - Est.Position.North * 0.01;
            Leg_U   : constant Float range -6.0e5 .. 6.0e5 := Target.Up - Est.Position.Up * 0.01;
            Leg_Len : constant Float range 0.0 .. 1.1e6 := Root (Leg_E * Leg_E + Leg_N * Leg_N + Leg_U * Leg_U, 1.1e6);
         begin
            if Delay_S > 0.0 and then Leg_Len > 0.1 then
               Cruise := Float'Min (Cruise, Float'Max (Delay_Min_Cruise_Mps, Leg_Len / Delay_S));
            end if;
         end;
      end if;

      S.Turn_In_Requested := False;
      S.Leg_Turn_In := Turn_In;
      S.Pattern_Pending := False;
      S.Pattern_Active := False;
      if not Pass_Gate then
         S.Carrot_Valid := False;
         S.Leg_Anchor_Valid := False;
      end if;
      S.Leg_Is_Pass_Gate := Pass_Gate;
      S.Leg_Valid := False;
      S.Leg_Target := Target;
      S.Leg_Cruise := Cruise;
      S.Leg_Vert_Rate_Mps := Leg_Vert_Rate (Effective, C);
      S.Leg_Yaw_Behaviour := Effective.Yaw_Behaviour;
      S.Leg_Yaw_Hold_Deg := Float (I.Yaw_Decidegrees) * 0.1;
      S.In_Pre_Turn := False;

      declare
         Start_Alt    : constant Float := Commanded_Altitude (N, Est);
         Handing_Over : constant Boolean := Position_Nav.Has_Active_Target (N) and then not S.Dispatch_Afresh;
      begin
         --  The gate belongs to the waypoint: a leg dispatched again keeps
         --  the wait it has served.
         if S.Leg_Yaw_Index /= S.Current_Index then
            S.Leg_Yaw_Index := S.Current_Index;
            S.Leg_Yaw_Gate_Start := I.Now_Us;
            S.Leg_Yaw_Timed_Out := False;
            S.Leg_Yaw_Braked := Handing_Over and then Pass_Gate;
         end if;
         S.Leg_Yaw_Gated :=
           Face_Target and then not Turn_In and then not S.Leg_Yaw_Timed_Out
           and then not Leg_Nose_On_Target (Est, Target, I.Yaw_Decidegrees);
         S.Leg_Yaw_Holding := S.Leg_Yaw_Gated and then not Pass_Gate;
         if not Pass_Gate and then Effective.Yaw_Behaviour = Flight_Plan.Yaw_Default then
            Command_Nose (O, False, 0.0);
         end if;

         if Pass_Gate then
            if not S.Carrot_Valid then
               if Turn_In then
                  S.Carrot_Velocity :=
                    (X => Held (Est.Velocity.East * 0.01, 1_000.0), Y => Held (Est.Velocity.North * 0.01, 1_000.0));
                  S.Carrot := Craft;
               elsif Handing_Over then
                  declare
                     Commanded : constant Position_Nav.Velocity_3_Cm_S := Position_Nav.Target_Velocity_Cm_S (N);
                     Held_At   : constant Vector_2 :=
                       (X => I.Position_Error.X * 0.01 + Craft.X, Y => I.Position_Error.Y * 0.01 + Craft.Y);
                  begin
                     S.Carrot_Velocity :=
                       (X => Held (Commanded.East * 0.01, 1_000.0), Y => Held (Commanded.North * 0.01, 1_000.0));
                     S.Carrot := Place_Carrot (Est, S.Carrot_Velocity, Held_At, C);
                  end;
               else
                  declare
                     Leg_X   : constant Float range -6.0e5 .. 6.0e5 := Target.East - Craft.X;
                     Leg_Y   : constant Float range -6.0e5 .. 6.0e5 := Target.North - Craft.Y;
                     Leg_Len : constant Float range 0.0 .. 1.0e6 := Root (Leg_X * Leg_X + Leg_Y * Leg_Y, 1.0e6);
                     Dir_X   : Float range -2.0 .. 2.0 := 0.0;
                     Dir_Y   : Float range -2.0 .. 2.0 := 0.0;
                  begin
                     if Leg_Len > 1.0 then
                        declare
                           Inverse : constant Float range 0.0 .. 1.0 := 1.0 / Leg_Len;
                        begin
                           Dir_X := Unit_Held (Leg_X * Inverse);
                           Dir_Y := Unit_Held (Leg_Y * Inverse);
                        end;
                     end if;
                     declare
                        Along : constant Float range -1.0e6 .. 1.0e6 :=
                          (Est.Velocity.East * Dir_X + Est.Velocity.North * Dir_Y) * 0.01;
                        Speed : constant Float range 0.0 .. 1_000.0 :=
                          (if S.Leg_Yaw_Gated then 0.0 else Constrain (Along, 0.0, Cruise));
                        Rest  : Vector_2;
                     begin
                        S.Carrot_Velocity := (X => Held (Dir_X * Speed, 1_000.0), Y => Held (Dir_Y * Speed, 1_000.0));
                        Rest := Rest_Point (Est, S.Carrot_Velocity, Lean_Degrees (C.Max_Angle));
                        S.Carrot := (X => Held (Rest.X, Position_Nav.Metres_Bound),
                                     Y => Held (Rest.Y, Position_Nav.Metres_Bound));
                     end;
                  end;
               end if;
               S.Carrot_Speed :=
                 Float'Min (1_000.0, Root (S.Carrot_Velocity.X * S.Carrot_Velocity.X
                                           + S.Carrot_Velocity.Y * S.Carrot_Velocity.Y, 1.5e3));
               S.Carrot_Valid := True;
               S.Leg_Anchor_Valid := False;
            else
               S.Carrot := Read_Back_Carrot (N);
            end if;
            Position_Nav.Set_Target (N, (East => S.Carrot.X, North => S.Carrot.Y, Up => Target.Up), Cruise,
                                     Carrot_No_Arrival_M, Completion_Any_Mps, True);
            S.Leg_Turn_Capped := Turn_In;
            if Turn_In then
               Position_Nav.Set_Max_Angle (N, Float (Rescue_Stop_Max_Angle (C)));
            end if;
            Position_Nav.Set_Accel_Limits (N, 0.0, 0.0);
            Position_Nav.Set_Altitude_Arrival_Required (N, False);
            Position_Nav.Set_Velocity_Feedforward (N, (East => S.Carrot_Velocity.X, North => S.Carrot_Velocity.Y));
         elsif S.Leg_Yaw_Holding then
            --  Held where the craft is, at the leg's altitude, until the
            --  nose has come round.
            Position_Nav.Set_Target (N, (East => Craft.X, North => Craft.Y, Up => Target.Up), Cruise,
                                     Carrot_No_Arrival_M, Completion_Any_Mps, True);
            Position_Nav.Set_Accel_Limits (N, 0.0, Approach_Decel_Mps2);
            Position_Nav.Set_Altitude_Arrival_Required (N, False);
         else
            Position_Nav.Set_Target
              (N, (East => Target.East, North => Target.North, Up => Target.Up), Cruise, Arrival,
               (if Rescue_Stop then Rescue_Stop_Still_Mps else Completion_Any_Mps), True, Handler => True);
            Position_Nav.Set_Accel_Limits
              (N, Point_Leg_Accel (S, C), (if S.Leg_Approach_Decel > 0.0 then 0.0 else Approach_Decel_Mps2));
            Position_Nav.Set_Approach_Brake (N, S.Leg_Approach_Decel, Rescue_Still_Radius_M);
            Position_Nav.Set_Altitude_Arrival_Required
              (N, Station and then not (S.Is_Rescue_Plan and then Effective.Kind = Flight_Plan.Type_Land));
            if Rescue_Stop then
               Position_Nav.Set_Velocity_Feedforward (N, (East => 0.0, North => 0.0));
               Position_Nav.Set_Settle_Timeout (N, Rescue_Stop_Settle_S);
               Position_Nav.Set_Max_Angle (N, Float (Rescue_Stop_Max_Angle (C)));
            end if;
         end if;
         if S.Dispatch_Afresh then
            Position_Nav.Start_Afresh (N);
            S.Dispatch_Afresh := False;
         end if;
         if Blind_Climb then
            S.Rescue_Blind_Climb := True;
            S.Rescue_Climbed := False;
            Call (O, Heading_Recovery, True, 0.0);
         end if;
         --  The altitude walks to the waypoint at the leg's rate from the
         --  altitude already commanded.
         Position_Nav.Set_Vertical_Profile (N, S.Leg_Vert_Rate_Mps, Start_Alt);
      end;
      Update_Leg_Yaw (S, P, I, O);
      S.Mode := Targeting;
      S.Hold_Duration_Ds := Effective.Duration_Ds;
      S.Best_Valid := False;
      S.Last_Progress_Us := I.Now_Us;
      S.Hdg_Fault_Time_S := 0.0;
   end Dispatch_Leg;

   -----------------------
   -- Dispatch_Waypoint --
   -----------------------

   procedure Dispatch_Waypoint
     (S          : in out State;
      N          : in out Position_Nav.Navigator;
      P          : Flight_Plan.Plan;
      I          : Leg_Inputs;
      C          : Settings;
      O          : in out Executor_Output;
      Dispatched : out Boolean)
   is
      W     : Flight_Plan.Waypoint;
      Found : Boolean;
   begin
      Dispatched := False;
      Drain_Modifiers (S, P, I.Now_Us, O, W, Found);
      if not Found then
         Complete_Plan (S, N, O);
         return;
      end if;
      declare
         Effective : Flight_Plan.Waypoint := W;
         Target    : ENU;
         Ok        : Boolean;
      begin
         --  The staged altitude override holds for the whole leg.
         if S.Alt_Override_Pending then
            Effective.Altitude := S.Alt_Override_Cm;
         end if;
         Compute_Target (S, Effective, I.Has_Origin, I.Origin, I.Cos_Lat, Target, Ok);
         if not Ok then
            S.Mode := Idle;
            return;
         end if;
         Dispatch_Leg (S, N, P, I, C, O, Effective, Target);
         Dispatched := True;
      end;
   end Dispatch_Waypoint;

   --  A dispatch whose outcome the caller leaves to the update's retry.
   procedure Dispatch
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
      Dispatched : Boolean;
   begin
      Dispatch_Waypoint (S, N, P, I, C, O, Dispatched);
      pragma Unreferenced (Dispatched);
   end Dispatch;

   --  The next waypoint dispatched with the leg's modifiers cleared, or the
   --  plan complete after its last.
   procedure Advance_To_Next
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
   begin
      S.Alt_Override_Pending := False;
      S.Pattern_Pending := False;
      S.Pattern_Active := False;
      if Natural (S.Current_Index) + 1 >= Active_Count (S, P) then
         Complete_Plan (S, N, O);
         return;
      end if;
      S.Current_Index := S.Current_Index + 1;
      Dispatch (S, N, P, I, C, O);
   end Advance_To_Next;

   --  The landing's target below the craft, its descent rate, and the leg
   --  handed to the navigator; a landing at the end of an approach brake
   --  closes the rest of it on the way down.
   procedure Start_Landing
     (S            : in out State;
      N            : in out Position_Nav.Navigator;
      I            : Leg_Inputs;
      C            : Settings;
      East, North  : Float;
      Descent_Rate : Float)
     with Global => null,
          Pre    => Leg_Bounded (S) and then abs East <= Position_Nav.Metres_Bound
                    and then abs North <= Position_Nav.Metres_Bound and then Descent_Rate in 0.0 .. 1_000.0,
          Post   => Leg_Bounded (S)
   is
      Start_Alt : constant Float := Commanded_Altitude (N, I.Est);
      Descent   : constant Float range 0.3 .. 1_000.0 := Float'Max (Landing_Min_Rate_Mps, Descent_Rate);
      Continued : constant Boolean := S.Leg_Approach_Decel > 0.0;
   begin
      Position_Nav.Set_Target
        (N, (East => East, North => North, Up => I.Est.Position.Up * 0.01 - Landing_Depth_M),
         (if Continued then S.Leg_Cruise else Descent), 1.0, 0.1, True);
      Position_Nav.Set_Accel_Limits (N, Point_Leg_Accel (S, C), (if Continued then 0.0 else Approach_Decel_Mps2));
      Position_Nav.Set_Approach_Brake (N, S.Leg_Approach_Decel, Rescue_Still_Radius_M);
      Position_Nav.Set_Vertical_Profile (N, Descent, Start_Alt);
      S.Landing_Rate_Mps := Descent;
      S.Mode := Landing;
      S.Landing_Start_Us := I.Now_Us;
      S.Touchdown_Quiet_Us := 0;
      S.Landing_Established := False;
   end Start_Landing;

   ----------------------------
   -- Start_Landing_In_Place --
   ----------------------------

   procedure Start_Landing_In_Place (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings)
   is
   begin
      Start_Landing
        (S, N, I, C, I.Est.Position.East * 0.01, I.Est.Position.North * 0.01, Float (C.Landing_Rate) * 0.01);
      Position_Nav.Start_Afresh (N);
   end Start_Landing_In_Place;

   ---------------------------------
   -- Start_Landing_At_Nav_Target --
   ---------------------------------

   procedure Start_Landing_At_Nav_Target
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
   is
   begin
      if not Position_Nav.Has_Active_Target (N) then
         Dispatch (S, N, P, I, C, O);
         return;
      end if;
      Start_Landing (S, N, I, C, N.Cmd.Target.East, N.Cmd.Target.North, S.Leg_Vert_Rate_Mps);
   end Start_Landing_At_Nav_Target;

   --------------------
   -- Update_Landing --
   --------------------

   procedure Update_Landing
     (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings; O : in out Executor_Output)
   is
      Vertical  : constant Float := I.Est.Velocity.Up;
      Commanded : constant Float range 0.0 .. 1.0e5 := S.Landing_Rate_Mps * 100.0;
   begin
      if S.Mode = Landing then
         Position_Nav.Lower_Target_Altitude (N, I.Est.Position.Up * 0.01 - Landing_Depth_M);
      end if;
      if not S.Landing_Established and then Vertical < -0.25 * Commanded then
         S.Landing_Established := True;
      end if;
      if not S.Landing_Established
        and then not (I.Below_Landing and then Clock.Elapsed (I.Now_Us, S.Landing_Start_Us) >= Landing_Establish_Us)
      then
         return;
      end if;
      --  A descent at the commanded rate is never quiet.
      if Vertical > -0.25 * Commanded and then abs Vertical < Float (C.Touchdown_Cms) then
         if S.Touchdown_Quiet_Us = 0 then
            S.Touchdown_Quiet_Us := I.Now_Us;
         elsif Clock.Elapsed (I.Now_Us, S.Touchdown_Quiet_Us) >= Integer_32 (C.Touchdown_Ds) * 100_000 then
            Complete_Plan (S, N, O);
            Call (O, Disarm, True, 0.0);
         end if;
      else
         S.Touchdown_Quiet_Us := 0;
      end if;
   end Update_Landing;

   --  The craft still drifting at 1 m/s or more after the rescue's climb.
   function Rescue_Drifting (Est : Position_Nav.Estimate) return Boolean is
     (Est.Velocity.East * Est.Velocity.East + Est.Velocity.North * Est.Velocity.North >= Rescue_Drift_Still_Sq);

   --  The pitch-forward that teaches the attitude its heading from the GPS
   --  course before the rescue's return leg.
   procedure Start_Rescue_Pitch_Forward (S : in out State; I : Leg_Inputs; O : in out Executor_Output) is
   begin
      S.Rescue_Blind_Climb := False;
      S.Rescue_Climbed := False;
      S.Rescue_Heading_Hold := True;
      S.Rescue_Heading_Start_Us := I.Now_Us;
      S.Rescue_Heading_Trusted := False;
      Call (O, Heading_Recovery, True, Rescue_Pitch_Fwd_Deg);
   end Start_Rescue_Pitch_Forward;

   ----------------------
   -- Waypoint_Reached --
   ----------------------

   procedure Waypoint_Reached
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
   is
   begin
      if not S.Active then
         return;
      end if;
      if Natural (S.Current_Index) >= Active_Count (S, P) then
         Complete_Plan (S, N, O);
         return;
      end if;
      declare
         W : constant Flight_Plan.Waypoint := Active_Waypoint (S, P, Natural (S.Current_Index));
      begin
         --  The listener follows the stored mission, not an injected plan.
         if I.Listener and then S.Injected_Waypoints = 0 then
            Call (O, Reached_Waypoint, True, Float (S.Current_Index));
         end if;
         --  The rescue's stop without a heading climbs, then pitches forward.
         if Is_Rescue_Stop (S) and then Active_Count (S, P) > 1 and then not I.Heading_Valid then
            if S.Rescue_Blind_Climb and then Rescue_Drifting (I.Est) then
               S.Rescue_Climbed := True;
               S.Rescue_Climbed_Us := I.Now_Us;
            else
               Start_Rescue_Pitch_Forward (S, I, O);
            end if;
            return;
         end if;
         End_Heading_Recovery (S, O);
         if Is_Station_Keeping (W.Kind) and then S.Hold_Duration_Ds > 0 then
            S.Mode := Holding;
            S.Hold_Start_Us := I.Now_Us;
            S.Hold_Last_Update_Us := S.Hold_Start_Us;
            S.Hold_Elapsed_Us := 0;
            if W.Kind = Flight_Plan.Type_Hold and then W.Pattern /= Flight_Plan.Pattern_None then
               S.Pattern_Pending := True;
            end if;
            return;
         end if;
         if W.Kind = Flight_Plan.Type_Land then
            Start_Landing_At_Nav_Target (S, N, P, I, C, O);
            return;
         end if;
         Advance_To_Next (S, N, P, I, C, O);
      end;
   end Waypoint_Reached;

   --  The staged modifiers cleared, with the yaw rate cap lifted.
   procedure Clear_Modifier_State (S : in out State; O : in out Executor_Output) is
   begin
      S.Alt_Override_Pending := False;
      S.Alt_Override_Cm := 0;
      S.Alt_Override_Mode := 0;
      S.Delay_Active := False;
      S.Delay_Duration_Ds := 0;
      S.Delay_End_Us := 0;
      S.Yaw_Rate_Cap_Dps := 0.0;
      Call (O, Yaw_Rate_Limit, True, 0.0);
   end Clear_Modifier_State;

   --  The nose gate's state, which belongs to a waypoint index, cleared.
   procedure Clear_Leg_Yaw_State (S : in out State) is
   begin
      S.Turn_In_Requested := False;
      S.Leg_Turn_In := False;
      S.Leg_Turn_Capped := False;
      S.Leg_Yaw_Behaviour := Flight_Plan.Yaw_Default;
      S.Leg_Yaw_Gated := False;
      S.Leg_Yaw_Holding := False;
      S.Leg_Yaw_Timed_Out := False;
      S.Leg_Yaw_Index := Unsigned_8'Last;
   end Clear_Leg_Yaw_State;

   ----------
   -- Init --
   ----------

   procedure Init (S : in out State; O : in out Executor_Output) is
   begin
      S.Mode := Idle;
      S.Current_Index := 0;
      S.Pending_Start_Index := 0;
      S.Active := False;
      S.Z_Bias_M := 0.0;
      S.Reason := None;
      S.Injected_Waypoints := 0;
      S.Pattern_Pending := False;
      S.Pattern_Active := False;
      S.Hdg_Fault_Time_S := 0.0;
      S.Last_Update_Us := 0;
      S.Leg_Is_Pass_Gate := False;
      S.Leg_Valid := False;
      S.Carrot_Speed := 0.0;
      S.Carrot_Valid := False;
      S.Dispatch_Afresh := False;
      S.In_Pre_Turn := False;
      S.Meas_Filt_Valid := False;
      S.Staged_Count := 0;
      S.Is_Rescue_Plan := False;
      S.Rescue_Blind_Climb := False;
      S.Rescue_Climbed := False;
      S.Rescue_Heading_Hold := False;
      S.Rescue_Descent_Active := False;
      Call (O, Emergency_Descent, False, 0.0);
      Clear_Modifier_State (S, O);
      Clear_Leg_Yaw_State (S);
   end Init;

   ------------
   -- Engage --
   ------------

   procedure Engage
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
   is
   begin
      S.Current_Index := 0;
      S.Mode := Idle;
      S.Reason := None;
      S.Injected_Waypoints := 0;
      S.Pattern_Pending := False;
      S.Pattern_Active := False;
      S.Hdg_Fault_Time_S := 0.0;
      S.Last_Update_Us := 0;
      S.Leg_Is_Pass_Gate := False;
      S.Leg_Valid := False;
      S.Carrot_Speed := 0.0;
      S.Carrot_Valid := False;
      S.Dispatch_Afresh := False;
      S.In_Pre_Turn := False;
      S.Meas_Filt_Valid := False;
      --  A fresh engage clears a heading-fault park.
      Call (O, Level_Park, False, 0.0);
      Command_Nose (O, False, 0.0);
      Clear_Modifier_State (S, O);
      Clear_Leg_Yaw_State (S);
      Capture_Altitude_Frame (S, I.Has_Origin, I.Origin.Alt_Cm, I.Estimator_Alt_Cm, I.GPS.Alt_Cm);
      Position_Nav.Set_Auto_Clear_On_Reach (N, False);
      S.Is_Rescue_Plan := False;
      End_Heading_Recovery (S, O);
      --  A staged rescue plan replaces the stored one.
      if S.Staged_Count > 0 then
         for K in 0 .. S.Staged_Count - 1 loop
            pragma Loop_Invariant (Leg_Bounded (S));
            S.Injected (K) := S.Staged (K);
         end loop;
         S.Injected_Waypoints := S.Staged_Count;
         S.Staged_Count := 0;
         S.Is_Rescue_Plan := True;
         S.Active := True;
         Dispatch (S, N, P, I, C, O);
         return;
      end if;
      if P.Count = 0 then
         Complete_Plan (S, N, O);
         S.Active := True;
         return;
      end if;
      --  A set-current received while idle chooses the starting leg.
      S.Current_Index := (if Natural (S.Pending_Start_Index) < P.Count then S.Pending_Start_Index else 0);
      S.Pending_Start_Index := 0;
      S.Active := True;
      Dispatch (S, N, P, I, C, O);
   end Engage;

   ---------------
   -- Disengage --
   ---------------

   procedure Disengage (S : in out State; N : in out Position_Nav.Navigator; O : in out Executor_Output) is
   begin
      S.Active := False;
      S.Mode := Idle;
      S.Injected_Waypoints := 0;
      S.Pattern_Pending := False;
      S.Pattern_Active := False;
      S.Hdg_Fault_Time_S := 0.0;
      S.Last_Update_Us := 0;
      S.Leg_Is_Pass_Gate := False;
      S.Leg_Valid := False;
      S.Carrot_Speed := 0.0;
      S.Carrot_Valid := False;
      S.Dispatch_Afresh := False;
      S.In_Pre_Turn := False;
      S.Meas_Filt_Valid := False;
      Call (O, Level_Park, False, 0.0);
      Command_Nose (O, False, 0.0);
      S.Staged_Count := 0;
      S.Is_Rescue_Plan := False;
      End_Heading_Recovery (S, O);
      Clear_Modifier_State (S, O);
      Clear_Leg_Yaw_State (S);
      Position_Nav.Clear_Target (N);
   end Disengage;

   -----------------
   -- Inject_Plan --
   -----------------

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
   is
   begin
      Accepted := False;
      if not S.Active or else Count = 0 or else Count > Injected_Max then
         return;
      end if;
      for K in 0 .. Count - 1 loop
         pragma Loop_Invariant (Leg_Bounded (S));
         S.Injected (K) := Plan (K);
      end loop;
      S.Injected_Waypoints := Count;
      S.Current_Index := 0;
      S.Reason := None;
      S.Carrot_Valid := False;
      S.Dispatch_Afresh := True;
      S.Carrot_Speed := 0.0;
      S.Meas_Filt_Valid := False;
      S.Is_Rescue_Plan := False;
      Clear_Modifier_State (S, O);
      Clear_Leg_Yaw_State (S);
      Dispatch (S, N, P, I, C, O);
      Accepted := True;
   end Inject_Plan;

   -----------------------
   -- Set_Current_Index --
   -----------------------

   procedure Set_Current_Index
     (S        : in out State;
      N        : in out Position_Nav.Navigator;
      P        : Flight_Plan.Plan;
      I        : Leg_Inputs;
      C        : Settings;
      O        : in out Executor_Output;
      Index    : Unsigned_8;
      Accepted : out Boolean)
   is
   begin
      Accepted := False;
      --  The index is the stored plan's; an injected plan keeps its own.
      if S.Injected_Waypoints > 0 or else Natural (Index) >= P.Count then
         return;
      end if;
      if S.Active then
         S.Current_Index := Index;
         S.Pattern_Pending := False;
         S.Pattern_Active := False;
         S.Reason := None;
         S.Carrot_Valid := False;
         S.Dispatch_Afresh := True;
         S.Carrot_Speed := 0.0;
         S.Meas_Filt_Valid := False;
         Clear_Modifier_State (S, O);
         Clear_Leg_Yaw_State (S);
         S.Mode := Targeting;
         Dispatch (S, N, P, I, C, O);
      else
         S.Pending_Start_Index := Index;
      end if;
      Accepted := True;
   end Set_Current_Index;

   --  The pattern's carrot at its phase handed to the navigator as a moving
   --  target that never arrives, its altitude walked from the altitude
   --  already commanded.
   procedure Issue_Pattern_Command (S : State; N : in out Position_Nav.Navigator; I : Leg_Inputs; Radius_M : Float)
     with Global => null,
          Pre    => Leg_Bounded (S) and then Radius_M in 0.5 .. 10.0
   is
      Carrot    : constant ENU := Held_Target (Pattern_Carrot (S, S.Pattern_Phase_Rad, Radius_M));
      Start_Alt : constant Float := Commanded_Altitude (N, I.Est);
   begin
      Position_Nav.Set_Target
        (N, (East => Carrot.East, North => Carrot.North, Up => Carrot.Up), S.Pattern_Cruise_Mps, Radius_M, 0.0, True);
      Position_Nav.Move_Target (N, (East => Carrot.East, North => Carrot.North, Up => Carrot.Up));
      Position_Nav.Set_Accel_Limits (N, 0.0, 0.0);
      Position_Nav.Set_Vertical_Profile (N, S.Leg_Vert_Rate_Mps, Start_Alt);
   end Issue_Pattern_Command;

   --  The hold's orbit or figure eight about the leg's target, started where
   --  the craft is on it: an orbit from the craft's bearing from the centre,
   --  a figure eight from the centre.
   procedure Start_Hold_Pattern
     (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings; W : Flight_Plan.Waypoint)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
      Radius_M : constant Float range 0.5 .. 10.0 := Float (C.Radius) * 0.01;
   begin
      S.Pattern_Type := W.Pattern;
      S.Pattern_Centre := (East => N.Cmd.Target.East, North => N.Cmd.Target.North, Up => N.Cmd.Target.Up);
      S.Pattern_Cruise_Mps := N.Cmd.Cruise_Speed;
      S.Pattern_Speed_Mps := Float'Min (N.Cmd.Cruise_Speed, Radius_M * Pattern_Max_Rate_Rads);
      if W.Pattern = Flight_Plan.Pattern_Figure_8 then
         S.Pattern_Phase_Rad := 0.0;
      else
         S.Pattern_Phase_Rad :=
           Maths.Atan2_Approx (I.Est.Position.North * 0.01 - S.Pattern_Centre.North,
                               I.Est.Position.East * 0.01 - S.Pattern_Centre.East);
      end if;
      S.Pattern_Last_Update_Us := I.Now_Us;
      S.Pattern_Active := True;
      Issue_Pattern_Command (S, N, I, Radius_M);
   end Start_Hold_Pattern;

   --  The pattern's phase advanced every 0.2 s at its speed, at most a
   --  second's worth, and its carrot moved; the command issued again when
   --  the navigator has lost it.
   procedure Update_Hold_Pattern (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
      Since_Us : constant Integer_32 := Clock.Elapsed (I.Now_Us, S.Pattern_Last_Update_Us);
      Radius_M : constant Float range 0.5 .. 10.0 := Float (C.Radius) * 0.01;
   begin
      if Since_Us < Pattern_Update_Us then
         return;
      end if;
      S.Pattern_Last_Update_Us := I.Now_Us;
      S.Pattern_Phase_Rad :=
        Held (S.Pattern_Phase_Rad + S.Pattern_Speed_Mps / Radius_M * Float'Min (Float (Since_Us) * 1.0e-6, 1.0), 10.0);
      if S.Pattern_Phase_Rad > Maths.Pi then
         S.Pattern_Phase_Rad := S.Pattern_Phase_Rad - 2.0 * Maths.Pi;
      end if;
      if Position_Nav.Has_Active_Target (N) then
         declare
            Carrot : constant ENU := Held_Target (Pattern_Carrot (S, S.Pattern_Phase_Rad, Radius_M));
         begin
            Position_Nav.Move_Target (N, (East => Carrot.East, North => Carrot.North, Up => Carrot.Up));
         end;
      else
         Issue_Pattern_Command (S, N, I, Radius_M);
      end if;
   end Update_Hold_Pattern;

   --  The geofence's return: home at the return altitude, never lower than
   --  the craft, then a landing there; a landing in place when the plan
   --  cannot be injected.
   procedure Inject_Return_Home_Plan
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
      Wanted     : constant Interfaces.Integer_64 :=
        Interfaces.Integer_64 (I.Home.Alt_Cm) + Interfaces.Integer_64 (C.Return_Alt_M) * 100;
      Return_Alt : constant Integer_32 :=
        Integer_32'Max (Integer_32 (Interfaces.Integer_64'Min (Interfaces.Integer_64 (Integer_32'Last), Wanted)),
                        I.GPS.Alt_Cm);
      Plan       : Injected_List := (others => (others => <>));
      Accepted   : Boolean;
   begin
      Plan (0) := (Latitude => I.Home.Lat, Longitude => I.Home.Lon, Altitude => Return_Alt, Speed => C.Return_Cms,
                   Duration_Ds => 0, Vert_Rate => 0, Kind => Flight_Plan.Type_Flyover, Pattern => 0,
                   Yaw_Behaviour => Flight_Plan.Yaw_Face_Target);
      Plan (1) := (Latitude => I.Home.Lat, Longitude => I.Home.Lon, Altitude => Return_Alt, Speed => C.Return_Cms,
                   Duration_Ds => 0, Vert_Rate => 0, Kind => Flight_Plan.Type_Land, Pattern => 0,
                   Yaw_Behaviour => Flight_Plan.Yaw_Default);
      Inject_Plan (S, N, P, I, C, O, Plan, 2, Accepted);
      if not Accepted then
         Start_Landing_In_Place (S, N, I, C);
      end if;
   end Inject_Return_Home_Plan;

   --  Past the configured distance from home, the return or a landing in
   --  place; never while an injected plan, itself the response, flies.
   procedure Check_Geofence
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
   begin
      if S.Injected_Waypoints > 0 then
         return;
      end if;
      if C.Fence_M = 0 or else not I.Home_Fix then
         return;
      end if;
      if I.Home_Distance_M <= C.Fence_M then
         return;
      end if;
      if C.Fence_Return then
         Inject_Return_Home_Plan (S, N, P, I, C, O);
      else
         Start_Landing_In_Place (S, N, I, C);
      end if;
   end Check_Geofence;

   --  The rescue's heading trusted once the GPS course has stayed within 5
   --  degrees of the nose at speed for half a second, or 2 s after the
   --  attitude first trusted it.
   procedure Rescue_Heading_Settled (S : in out State; I : Leg_Inputs; Settled : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
   begin
      if not S.Rescue_Heading_Trusted then
         S.Rescue_Heading_Trusted := True;
         S.Rescue_Heading_Trusted_Us := I.Now_Us;
         S.Rescue_Heading_Off_Course_Us := I.Now_Us;
      end if;
      if I.Ground_Speed < Rescue_Settle_Cms
        or else abs Wrap_Deg_180 (Float (I.Yaw_Decidegrees - Integer_32 (I.Ground_Course)) * 0.1) > Rescue_Settle_Deg
      then
         S.Rescue_Heading_Off_Course_Us := I.Now_Us;
      end if;
      Settled := Clock.Elapsed (I.Now_Us, S.Rescue_Heading_Off_Course_Us) >= Rescue_Settle_Us
                 or else Clock.Elapsed (I.Now_Us, S.Rescue_Heading_Trusted_Us) >= Rescue_Settle_Max_Us;
   end Rescue_Heading_Settled;

   --  The progress of a point leg against its navigation target.
   procedure Check_Leg_Progress
     (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings; O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
   begin
      if not Position_Nav.Has_Active_Target (N) then
         return;
      end if;
      Update_Progress_Tracking (S, N, Distance_To_Nav_Target (N, I.Est), I, C, O);
   end Check_Leg_Progress;

   --  The rescue's climb without a heading: the leg flown again once a
   --  heading is known, else the target kept over the craft, the climb's
   --  progress checked, and the pitch-forward started once the drift has
   --  died away or 5 s after the climb.
   procedure Update_Blind_Climb
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
   begin
      if not (I.Heading_Required and then not I.Heading_Valid) then
         End_Heading_Recovery (S, O);
         S.Dispatch_Afresh := True;
         S.Leg_Yaw_Index := Unsigned_8'Last;
         Dispatch (S, N, P, I, C, O);
         return;
      end if;
      Position_Nav.Move_Target
        (N, (East => I.Est.Position.East * 0.01, North => I.Est.Position.North * 0.01, Up => S.Leg_Target.Up));
      if not S.Rescue_Climbed then
         Check_Leg_Progress (S, N, I, C, O);
      elsif not Rescue_Drifting (I.Est)
        or else Clock.Elapsed (I.Now_Us, S.Rescue_Climbed_Us) >= Rescue_Drift_Timeout_Us
      then
         Start_Rescue_Pitch_Forward (S, I, O);
      end if;
   end Update_Blind_Climb;

   --  One cycle of a leg: the nose, the swap from the nose hold to the real
   --  target, the carrot or the point leg's progress, then the heading-fault
   --  check, which parks the craft level and aborts. Stop reports an exit
   --  before the hold's cycle.
   procedure Update_Targeting
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output; Stop : out Boolean)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
      Gate       : Boolean;
      Fault      : Boolean;
   begin
      Stop := False;
      Update_Leg_Yaw (S, P, I, O);
      if S.Leg_Yaw_Holding and then not S.Leg_Yaw_Gated then
         Dispatch (S, N, P, I, C, O);
         Stop := True;
         return;
      end if;
      if S.Leg_Is_Pass_Gate then
         Update_Leg_Carrot (S, N, P, I, C, O, Gate);
         if Gate then
            Waypoint_Reached (S, N, P, I, C, O);
         end if;
      else
         Check_Leg_Progress (S, N, I, C, O);
      end if;
      if S.Mode = Targeting and then Position_Nav.Has_Active_Target (N) then
         Check_Heading_Fault (S, N, I, C, Fault);
         if Fault then
            Call (O, Level_Park, True, 0.0);
            Abort_Mission (S, N, Mag_Fault, O);
            Stop := True;
         end if;
      end if;
   end Update_Targeting;

   --  One cycle of a hold: the time held, the nose, the pattern started
   --  once the arrival's braking has settled or moved on, and on expiry the
   --  landing or the next leg.
   procedure Update_Holding
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
     with Global => null,
          Pre    => Leg_Bounded (S),
          Post   => Leg_Bounded (S)
   is
      use type Interfaces.Unsigned_64;
   begin
      --  Per-update deltas, so a hold may outlast a turn of the clock.
      S.Hold_Elapsed_Us := S.Hold_Elapsed_Us + Unsigned_64 (I.Now_Us - S.Hold_Last_Update_Us);
      S.Hold_Last_Update_Us := I.Now_Us;
      Update_Leg_Yaw (S, P, I, O);
      if S.Pattern_Pending then
         if not Position_Nav.Has_Active_Target (N) or else Natural (S.Current_Index) >= Active_Count (S, P) then
            S.Pattern_Pending := False;
         elsif Root (I.Est.Velocity.East * I.Est.Velocity.East + I.Est.Velocity.North * I.Est.Velocity.North, 2.4e7)
                 * 0.01 < Pattern_Start_Mps
           or else Clock.Elapsed (I.Now_Us, S.Hold_Start_Us) >= Pattern_Start_Us
         then
            S.Pattern_Pending := False;
            Start_Hold_Pattern (S, N, I, C, Active_Waypoint (S, P, Natural (S.Current_Index)));
         end if;
      elsif S.Pattern_Active then
         Update_Hold_Pattern (S, N, I, C);
      end if;
      if S.Hold_Elapsed_Us >= Unsigned_64 (S.Hold_Duration_Ds) * 100_000 then
         if Natural (S.Current_Index) < Active_Count (S, P)
           and then Active_Waypoint (S, P, Natural (S.Current_Index)).Kind = Flight_Plan.Type_Land
         then
            Start_Landing_At_Nav_Target (S, N, P, I, C, O);
         else
            Advance_To_Next (S, N, P, I, C, O);
         end if;
      end if;
   end Update_Holding;

   ------------
   -- Update --
   ------------

   procedure Update
     (S : in out State; N : in out Position_Nav.Navigator; P : Flight_Plan.Plan; I : Leg_Inputs; C : Settings;
      O : in out Executor_Output)
   is
      Cycle      : Leg_Inputs := I;
      Stop       : Boolean := False;
   begin
      if not S.Active then
         return;
      end if;
      Cycle.Dt_S :=
        (if S.Last_Update_Us /= 0
         then Constrain (Float (Clock.Elapsed (I.Now_Us, S.Last_Update_Us)) * 1.0e-6, 0.0, 0.25)
         else 0.0);
      S.Last_Update_Us := I.Now_Us;

      --  The rescue's heading recovery: the next leg once the heading has
      --  settled, an abort when it never comes.
      if S.Rescue_Heading_Hold then
         if I.Heading_Valid then
            declare
               Settled : Boolean;
            begin
               Rescue_Heading_Settled (S, Cycle, Settled);
               if Settled then
                  End_Heading_Recovery (S, O);
                  S.Dispatch_Afresh := True;
                  S.Turn_In_Requested := True;
                  Advance_To_Next (S, N, P, Cycle, C, O);
               end if;
            end;
         elsif Clock.Elapsed (I.Now_Us, S.Rescue_Heading_Start_Us) >= Rescue_Heading_Timeout_Us then
            Abort_Mission (S, N, Heading, O);
         end if;
         return;
      end if;

      --  A dispatch retried once the estimator has an origin.
      if S.Mode = Idle and then Active_Count (S, P) > 0 then
         Dispatch (S, N, P, Cycle, C, O);
         return;
      end if;

      --  A leg the position controller wiped is issued again, its carrot
      --  started afresh.
      if S.Mode = Targeting and then not Position_Nav.Has_Active_Target (N) then
         S.Carrot_Valid := False;
         S.Carrot_Speed := 0.0;
         S.Meas_Filt_Valid := False;
         Dispatch (S, N, P, Cycle, C, O);
         return;
      end if;

      if S.Mode = Landing then
         Update_Landing (S, N, Cycle, C, O);
         return;
      end if;

      if S.Mode = Targeting or else S.Mode = Holding then
         if not I.Estimator_Valid then
            Abort_Mission (S, N, Estimator, O);
            return;
         end if;
         Check_Geofence (S, N, P, Cycle, C, O);
         if S.Mode = Landing then
            return;
         end if;
      end if;

      --  The delay's end restores the leg's cruise.
      if S.Delay_Active and then Clock.Elapsed (I.Now_Us, S.Delay_End_Us) >= 0 then
         S.Delay_Active := False;
         if S.Mode = Targeting then
            Dispatch (S, N, P, Cycle, C, O);
         end if;
      end if;

      if S.Mode = Targeting and then S.Rescue_Blind_Climb then
         Update_Blind_Climb (S, N, P, Cycle, C, O);
         return;
      end if;

      if S.Mode = Targeting then
         Update_Targeting (S, N, P, Cycle, C, O, Stop);
      end if;
      if not Stop and then S.Mode = Holding then
         Update_Holding (S, N, P, Cycle, C, O);
      end if;
   end Update;

   --  Whether the craft comes to a stop within the rescue's minimum start
   --  distance of home, braking at the rescue's lean.
   function Rescue_Stops_Near_Home (I : Leg_Inputs; C : Settings) return Boolean is
      Rest     : constant Vector_2 := Rest_Point (I.Est, (X => 0.0, Y => 0.0), Rescue_Stop_Max_Angle (C));
      East_Cm  : Float;
      North_Cm : Float;
   begin
      Position_Estimator.Distance_2d (I.Home, I.GPS, I.Cos_Lat, East_Cm, North_Cm);
      declare
         East_M  : constant Float range -7.0e11 .. 7.0e11 := East_Cm * 0.01 + Rest.X - I.Est.Position.East * 0.01;
         North_M : constant Float range -7.0e11 .. 7.0e11 := North_Cm * 0.01 + Rest.Y - I.Est.Position.North * 0.01;
      begin
         return East_M * East_M + North_M * North_M < Float (C.Min_Start_M) * Float (C.Min_Start_M);
      end;
   end Rescue_Stops_Near_Home;

   --  An altitude in centimetres held within the 32-bit range.
   function Held_Altitude (Cm : Interfaces.Integer_64) return Integer_32 is
     (Integer_32 (Interfaces.Integer_64'Max (Interfaces.Integer_64 (Integer_32'First),
                                             Interfaces.Integer_64'Min (Interfaces.Integer_64 (Integer_32'Last), Cm))));

   --  The failsafe rescue's plan: a climb where the craft comes to a stop, the
   --  return home at the altitude its mode gives, never lower than the craft,
   --  and a landing at home; or a landing where the craft stops when that is
   --  near home, none without a heading to hold it there.
   procedure Build_Rescue_Plan (I : Leg_Inputs; C : Settings; Plan : out Injected_List; Count : out Natural)
     with Global => null,
          Post   => Count <= 3
   is
      Speed       : constant Unsigned_16 := C.Return_Cms;
      Current_Alt : constant Integer_32 := I.GPS.Alt_Cm;
   begin
      Plan := (others => (others => <>));
      Count := 0;
      if not I.Home_Fix or else not I.GPS_Fix then
         return;
      end if;
      if Rescue_Stops_Near_Home (I, C) then
         if I.Heading_Required and then not I.Heading_Valid then
            return;
         end if;
         Plan (0) := (Latitude => I.GPS.Lat, Longitude => I.GPS.Lon, Altitude => Current_Alt, Speed => Speed,
                      Duration_Ds => 0, Vert_Rate => C.Descend_Cms, Kind => Flight_Plan.Type_Land, Pattern => 0,
                      Yaw_Behaviour => Flight_Plan.Yaw_Hold);
         Count := 1;
         return;
      end if;
      declare
         Home_Alt   : constant Interfaces.Integer_64 := Interfaces.Integer_64 (I.Home.Alt_Cm);
         Climb      : constant Interfaces.Integer_64 := Interfaces.Integer_64 (C.Initial_Climb_M) * 100;
         Wanted     : constant Interfaces.Integer_64 :=
           (case C.Rescue_Alt_Mode is
               when 1      => Home_Alt + Interfaces.Integer_64 (C.Return_Alt_M) * 100,
               when 2      => Interfaces.Integer_64 (Current_Alt) + Climb,
               when others =>
                  Home_Alt + Interfaces.Integer_64 (Float'Truncation (I.Rescue_Max_Alt_Cm)) + Climb);
         Return_Alt : constant Integer_32 := Integer_32'Max (Held_Altitude (Wanted), Current_Alt);
      begin
         Plan (0) := (Latitude => I.GPS.Lat, Longitude => I.GPS.Lon, Altitude => Return_Alt, Speed => 0,
                      Duration_Ds => 0, Vert_Rate => C.Ascend_Cms, Kind => Flight_Plan.Type_Hold, Pattern => 0,
                      Yaw_Behaviour => Flight_Plan.Yaw_Face_Next);
         Plan (1) := (Latitude => I.Home.Lat, Longitude => I.Home.Lon, Altitude => Return_Alt, Speed => Speed,
                      Duration_Ds => 0, Vert_Rate => C.Ascend_Cms, Kind => Flight_Plan.Type_Flyover, Pattern => 0,
                      Yaw_Behaviour => Flight_Plan.Yaw_Face_Target);
         Plan (2) := (Latitude => I.Home.Lat, Longitude => I.Home.Lon, Altitude => Return_Alt, Speed => Speed,
                      Duration_Ds => 0, Vert_Rate => C.Descend_Cms, Kind => Flight_Plan.Type_Land, Pattern => 0,
                      Yaw_Behaviour => Flight_Plan.Yaw_Default);
         Count := 3;
      end;
   end Build_Rescue_Plan;

   -----------------------
   -- Stage_Rescue_Plan --
   -----------------------

   procedure Stage_Rescue_Plan
     (S      : in out State;
      N      : in out Position_Nav.Navigator;
      P      : Flight_Plan.Plan;
      I      : Leg_Inputs;
      C      : Settings;
      O      : in out Executor_Output;
      Staged : out Boolean)
   is
      Plan  : Injected_List;
      Count : Natural;
   begin
      Staged := False;
      Build_Rescue_Plan (I, C, Plan, Count);
      if Count = 0 then
         return;
      end if;
      --  A plan already flying is replaced at once.
      if S.Active then
         Capture_Altitude_Frame (S, I.Has_Origin, I.Origin.Alt_Cm, I.Estimator_Alt_Cm, I.GPS.Alt_Cm);
         for K in 0 .. Count - 1 loop
            pragma Loop_Invariant (Leg_Bounded (S));
            S.Injected (K) := Plan (K);
         end loop;
         S.Injected_Waypoints := Count;
         S.Current_Index := 0;
         S.Reason := None;
         S.Is_Rescue_Plan := True;
         End_Heading_Recovery (S, O);
         S.Staged_Count := 0;
         S.Dispatch_Afresh := True;
         Clear_Modifier_State (S, O);
         Clear_Leg_Yaw_State (S);
         Dispatch (S, N, P, I, C, O);
         Staged := True;
         return;
      end if;
      for K in 0 .. Count - 1 loop
         pragma Loop_Invariant (Leg_Bounded (S));
         S.Staged (K) := Plan (K);
      end loop;
      S.Staged_Count := Count;
      Staged := True;
   end Stage_Rescue_Plan;

   --------------------
   -- Rescue_Descent --
   --------------------

   procedure Rescue_Descent
     (S : in out State; N : in out Position_Nav.Navigator; I : Leg_Inputs; C : Settings; O : in out Executor_Output;
      Request : Boolean)
   is
   begin
      if not Request then
         if S.Rescue_Descent_Active then
            S.Rescue_Descent_Active := False;
            Call (O, Emergency_Descent, False, 0.0);
         end if;
         return;
      end if;
      if not S.Rescue_Descent_Active then
         S.Rescue_Descent_Active := True;
         S.Landing_Rate_Mps := Float'Max (Landing_Min_Rate_Mps, Float (C.Descend_Cms) * 0.01);
         S.Landing_Start_Us := I.Now_Us;
         S.Touchdown_Quiet_Us := 0;
         S.Landing_Established := False;
         Call (O, Emergency_Descent, True, Float (C.Descend_Cms));
      end if;
      Update_Landing (S, N, I, C, O);
   end Rescue_Descent;

   --------------------------
   -- Distance_To_Waypoint --
   --------------------------

   function Distance_To_Waypoint (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Float is
   begin
      if not S.Active or else not Position_Nav.Has_Active_Target (N) then
         return -1.0;
      end if;
      declare
         D : constant ENU := Nav_Waypoint_Delta (S, N, Est);
      begin
         return Root (D.East * D.East + D.North * D.North + D.Up * D.Up, 9.0e5);
      end;
   end Distance_To_Waypoint;

   -------------------------
   -- Bearing_To_Waypoint --
   -------------------------

   function Bearing_To_Waypoint (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Integer_32
   is
   begin
      if not S.Active or else not Position_Nav.Has_Active_Target (N) then
         return -1;
      end if;
      declare
         D       : constant ENU := Nav_Waypoint_Delta (S, N, Est);
         Scaled  : constant Float range -1_800.5 .. 1_800.5 := Maths.Atan2_Approx (D.East, D.North) * Deci_Per_Rad;
         Rounded : constant Integer_32 :=
           (if Scaled >= 0.0 then Integer_32 (Round_To_Even (Scaled)) else -Integer_32 (Round_To_Even (-Scaled)));
         Deci    : constant Integer_32 := Rounded rem 3_600;
      begin
         return (if Deci < 0 then Deci + 3_600 else Deci);
      end;
   end Bearing_To_Waypoint;

   -----------------
   -- Eta_Seconds --
   -----------------

   function Eta_Seconds (S : State; N : Position_Nav.Navigator; Est : Position_Nav.Estimate) return Unsigned_16 is
   begin
      if not S.Active or else not Position_Nav.Has_Active_Target (N) then
         return 0;
      end if;
      declare
         Speed_Mps : constant Float range 0.0 .. 2.4e5 :=
           Root (Est.Velocity.East * Est.Velocity.East + Est.Velocity.North * Est.Velocity.North, 2.4e7) * 0.01;
      begin
         if Speed_Mps < 0.5 then
            return 0;
         end if;
         declare
            D    : constant ENU := Nav_Waypoint_Delta (S, N, Est);
            Dist : constant Float range 0.0 .. 8.0e5 := Root (D.East * D.East + D.North * D.North, 8.0e5);
            Eta  : constant Float range 0.0 .. 1.7e6 := Dist / Speed_Mps;
         begin
            if Eta >= 65_535.0 then
               return Unsigned_16'Last;
            end if;
            return Unsigned_16 (Natural'Min (Round_To_Even (Eta), 65_535));
         end;
      end;
   end Eta_Seconds;

   ---------------------
   -- Orbit_Period_Ds --
   ---------------------

   function Orbit_Period_Ds (Speed : Unsigned_16; Radius : Hold_Radius; Max_Speed : Max_Velocity) return Unsigned_16 is
      Radius_M : constant Float := Float (Radius) * 0.01;
      Cruise   : Float := (if Speed > 0 then Float (Speed) * 0.01 else Float (Max_Speed) * 0.01);
   begin
      if Cruise < Min_Cruise_Mps then
         Cruise := Min_Cruise_Mps;
      end if;
      declare
         Rate   : constant Float := Float'Min (Cruise, Radius_M * Pattern_Max_Rate_Rads) / Radius_M;
         Period : Float;
      begin
         pragma Assert (Rate in 0.0 .. 1.0);
         Period := 10.0 * 2.0 * Maths.Pi / Rate;
         pragma Assert (Period >= 1.0);
         if Period >= 65_535.0 then
            return Unsigned_16'Last;
         end if;
         return Unsigned_16 (Round_To_Even (Period));
      end;
   end Orbit_Period_Ds;

end Adaflight.Flight_Plan_Nav;
