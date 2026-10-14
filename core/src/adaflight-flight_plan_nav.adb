with Ada.Numerics.Elementary_Functions;
with Adaflight.Clock;

package body Adaflight.Flight_Plan_Nav with SPARK_Mode is

   use type Interfaces.Integer_64;

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

   --  Degrees in radians, rounded as the C rounds its product: the turn-in
   --  rate and the angle a turn-in counts as done within.
   Rad_30 : constant Float := Float'Machine (30.0 * Maths.Rad_Per_Degree);
   Rad_15 : constant Float := Float'Machine (15.0 * Maths.Rad_Per_Degree);

   procedure Call (O : in out Autopilot_Output; Kind : Autopilot_Call_Kind; On : Boolean; Value : Float) is
   begin
      if O.Count < Max_Autopilot_Calls then
         O.Count := O.Count + 1;
         O.Calls (O.Count) := (Kind => Kind, On => On, Value => Value);
      end if;
   end Call;

   procedure Command_Nose (O : in out Autopilot_Output; Override : Boolean; Heading : Float) is
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

   -------------------
   -- Abort_Mission --
   -------------------

   procedure Abort_Mission
     (S : in out State; N : in out Position_Nav.Navigator; Reason : Abort_Reason; O : in out Autopilot_Output)
   is
   begin
      if S.Rescue_Blind_Climb or else S.Rescue_Heading_Hold then
         Call (O, Heading_Recovery, False, 0.0);
      end if;
      S.Rescue_Blind_Climb := False;
      S.Rescue_Climbed := False;
      S.Rescue_Heading_Hold := False;
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
      O : in out Autopilot_Output)
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
     (S : in out State; P : Flight_Plan.Plan; I : Leg_Inputs; O : in out Autopilot_Output)
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
      O             : in out Autopilot_Output)
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
      O            : in out Autopilot_Output)
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
      O            : in out Autopilot_Output;
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
