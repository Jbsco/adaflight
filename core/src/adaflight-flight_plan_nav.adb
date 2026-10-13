with Ada.Numerics.Elementary_Functions;

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

   procedure Place_Carrot (S : in out State; Est : Position_Nav.Estimate; Wanted : Vector_2; C : Settings) is
      Craft        : constant Vector_2 := (X => Est.Position.East * 0.01, Y => Est.Position.North * 0.01);
      Rest         : constant Vector_2 := Rest_Point (Est, S.Carrot_Velocity, Lean_Degrees (C.Max_Angle));
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
      S.Carrot := (X => Float'Max (-Distance_Bound, Float'Min (Distance_Bound, Base.X + Gap_X)),
                   Y => Float'Max (-Distance_Bound, Float'Min (Distance_Bound, Base.Y + Gap_Y)));
   end Place_Carrot;

   ----------------------
   -- Read_Back_Carrot --
   ----------------------

   procedure Read_Back_Carrot (S : in out State; N : Position_Nav.Navigator) is
   begin
      S.Carrot := (X => N.Cmd.Target.East, Y => N.Cmd.Target.North);
   end Read_Back_Carrot;

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
