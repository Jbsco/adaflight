with Adaflight.Maths; use Adaflight.Maths;

package body Adaflight.Rates with SPARK_Mode is

   RC_Rate_Incremental : constant Float := 14.54;

   subtype Unit is Float range -1.0 .. 1.0;
   subtype Fraction is Float range 0.0 .. 1.0;

   --  The odd powers of a unit value. Bodies rather than expression functions,
   --  so the callers see only the bound and not the polynomial.
   function Cube (X : Unit) return Unit
     with Post => abs Cube'Result <= abs X;
   function Cube (X : Unit) return Unit is
   begin
      return X * X * X;
   end Cube;

   function Fifth (X : Unit) return Unit
     with Post => abs Fifth'Result <= abs X;
   function Fifth (X : Unit) return Unit is
   begin
      return X * X * X * X * X;
   end Fifth;

   --  Expo blend of a command with its cube, which stays within the unit
   --  range because both parts do.
   function Expo_Curve (Cmd : Unit; Cubed : Unit; Expo : Fraction) return Unit
     with Post => abs Expo_Curve'Result <= 1.0;

   function Expo_Curve (Cmd : Unit; Cubed : Unit; Expo : Fraction) return Unit is
      Curved : constant Float := Cubed * Expo;
      Linear : constant Float := Cmd * (1.0 - Expo);
   begin
      pragma Assert (abs Curved <= 1.0);
      pragma Assert (abs Linear <= 1.0);
      return Constrain_F (Curved + Linear, -1.0, 1.0);
   end Expo_Curve;

   --  Reciprocal of the super rate attenuation, held between one and one
   --  hundred as the reference constrains the denominator.
   function Super_Factor (Cmd_Abs : Fraction; Rate : Setting) return Float
     with Post => Super_Factor'Result in 1.0 .. 100.0;

   function Super_Factor (Cmd_Abs : Fraction; Rate : Setting) return Float is
      Attenuation : constant Float := Cmd_Abs * (Float (Rate) / 100.0);
      Denominator : constant Float := Constrain_F (1.0 - Attenuation, 0.01, 1.0);
   begin
      pragma Assert (Attenuation in 0.0 .. 2.55);
      return 1.0 / Denominator;
   end Super_Factor;

   subtype Base_Rate is Float range 0.0 .. 11.0;

   function Base_Rate_Of (Rate : Setting) return Base_Rate
     with Post => Base_Rate_Of'Result <= 11.0;

   function Base_Rate_Of (Rate : Setting) return Base_Rate is
      RC_Rate : constant Float := Float (Rate) / 100.0;
   begin
      if RC_Rate > 2.0 then
         return RC_Rate + RC_Rate_Incremental * (RC_Rate - 2.0);
      else
         return RC_Rate;
      end if;
   end Base_Rate_Of;

   function Apply_Super_Rate (
      RC_S    : Positive_Setting;
      Super_S : Setting;
      Expo_S  : Expo_Setting;
      Cmd     : Command;
      Cmd_Abs : Magnitude
   ) return Angle_Rate is
      subtype Scaled_Rate is Float range -2_201.0 .. 2_201.0;
      Command_Curved : Unit := Cmd;
      RC_Rate        : constant Base_Rate := Base_Rate_Of (RC_S);
      Rate           : Scaled_Rate;
   begin
      if Expo_S /= 0 then
         declare
            Expo   : constant Fraction := Float (Expo_S) / 100.0;
            Shaped : constant Float range -1.01 .. 1.01 := Cmd * Cube (Cmd_Abs);
            Curved : constant Float range -1.05 .. 1.05 := Shaped * Expo;
            Linear : constant Float range -1.01 .. 1.01 := Cmd * (1.0 - Expo);
         begin
            Command_Curved := Constrain_F (Curved + Linear, -1.0, 1.0);
         end;
      end if;
      Rate := Float'(200.0 * RC_Rate) * Command_Curved;
      if Super_S /= 0 then
         return Constrain_F (Rate * Super_Factor (Cmd_Abs, Super_S), -Max_Angle_Rate, Max_Angle_Rate);
      end if;
      return Constrain_F (Rate, -Max_Angle_Rate, Max_Angle_Rate);
   end Apply_Super_Rate;

   function Apply_Acro_Plus (
      RC_S    : Positive_Setting;
      Super_S : Setting;
      Expo_S  : Expo_Setting;
      Cmd     : Command;
      Cmd_Abs : Magnitude
   ) return Angle_Rate is
      Expo_F    : constant Float range 0.0 .. 1.01 := 0.01 * Float (Expo_S);
      Sq_Minus  : constant Float range -1.0 .. 0.0 := Cmd * Cmd - 1.0;
      Expo_Term : constant Float range -1.01 .. 0.0 := Expo_F * Sq_Minus;
      Curved    : constant Float range -1.01 .. 1.01 := (1.0 + Expo_Term) * Cmd;
      Rate      : constant Float range -2_600.0 .. 2_600.0 := Float'(10.0 * Float (RC_S)) * Curved;
      Factor    : constant Float range 1.0 .. 3.6 := 1.0 + Cmd_Abs * Float (Super_S) * 0.01;
   begin
      return Constrain_F (Rate * Factor, -Max_Angle_Rate, Max_Angle_Rate);
   end Apply_Acro_Plus;

   function Apply_RC_Curve (
      RC_S    : Positive_Setting;
      Super_S : Setting;
      Expo_S  : Expo_Setting;
      Cmd     : Command;
      Cmd_Abs : Magnitude
   ) return Angle_Rate is
      Curve     : constant Fraction := Float (Expo_S) / 100.0;
      Use_Rates : constant Float range 1.0 .. 100.0 := Super_Factor (Cmd_Abs, Super_S);
      Blend     : constant Unit := Expo_Curve (Cmd, Cube (Cmd), Curve);
      Scale     : constant Float range 0.0 .. 0.26 := Float (RC_S) / 1000.0;
      Curved    : constant Float range -0.26 .. 0.26 := Blend * Scale;
   begin
      return Constrain_F (Float'(2000.0 * Use_Rates) * Curved, -Setpoint_Limit, Setpoint_Limit);
   end Apply_RC_Curve;

   subtype Travel is Float range 0.0 .. 2_550.0;
   subtype Config_Ratio is Float range 0.0 .. 1_275.0;

   --  The stick travel beyond the center sensitivity, in bodies of their own
   --  so their range checks carry no other context.
   function Movement_Of (Super : Setting; Center : Travel) return Travel
     with Post => (if Float (Super) * 10.0 <= Center then Movement_Of'Result = 0.0);
   function Movement_Of (Super : Setting; Center : Travel) return Travel is
   begin
      return Float'Max (0.0, Float (Super) * 10.0 - Center);
   end Movement_Of;

   function Super_Config_Of (Ratio : Float) return Config_Ratio
     with Pre => Ratio in 1.0 .. 1_275.0;
   function Super_Config_Of (Ratio : Float) return Config_Ratio is
   begin
      return Float'Max (0.0, Float'Min (1_275.0, (Ratio - 1.0) / Ratio));
   end Super_Config_Of;

   function Apply_Actual (
      RC_S    : Positive_Setting;
      Super_S : Setting;
      Expo_S  : Expo_Setting;
      Cmd     : Command;
      Cmd_Abs : Magnitude
   ) return Angle_Rate is
      Expo               : constant Fraction := Float (Expo_S) / 100.0;
      Center_Sensitivity : constant Travel := Float (RC_S) * 10.0;
      Stick_Movement     : constant Travel := Movement_Of (Super_S, Center_Sensitivity);
      Shaped             : constant Unit := Expo_Curve (Cmd, Fifth (Cmd), Expo);
      Weighted           : constant Float range -1.01 .. 1.01 := Float'Max (-1.01, Float'Min (1.01, Cmd_Abs * Shaped));
   begin
      return Constrain_F (Cmd * Center_Sensitivity + Stick_Movement * Weighted,
                          -Max_Angle_Rate, Max_Angle_Rate);
   end Apply_Actual;

   function Apply_Quick (
      RC_S       : Positive_Setting;
      Super_S    : Setting;
      Expo_S     : Expo_Setting;
      Quick_Expo : Boolean;
      Cmd        : Command;
      Cmd_Abs    : Magnitude
   ) return Angle_Rate is
      RC_Rate      : constant Positive := RC_S * 2;
      Max_DPS      : constant Positive := Natural'Max (Super_S * 10, RC_Rate);
      Expo         : constant Fraction := Float (Expo_S) / 100.0;
      --  The quotient of a numerator no smaller than its denominator.
      Ratio        : constant Float range 1.0 .. 1_275.0 := Float'Max (1.0, Float (Max_DPS) / Float (RC_Rate));
      Super_Config : constant Config_Ratio := Super_Config_Of (Ratio);
      Curve        : Unit;
      Denominator  : Float range 0.01 .. 1.0;
      Super        : Float range 1.0 .. 101.0;
      Scaled       : Float range -520.0 .. 520.0;
      Rate         : Float range -53_000.0 .. 53_000.0;
   begin
      if Quick_Expo then
         Curve := Expo_Curve (Cmd, Cube (Cmd), Expo);
         Denominator := Constrain_F (1.0 - (Cmd_Abs * Super_Config), 0.01, 1.0);
         Super := 1.0 / Denominator;
         Scaled := Constrain_F (Curve * Float (RC_Rate), -520.0, 520.0);
         Rate := Constrain_F (Scaled * Super, -53_000.0, 53_000.0);
      else
         Curve := Expo_Curve (Cmd_Abs, Cube (Cmd_Abs), Expo);
         Denominator := Constrain_F (1.0 - (Curve * Super_Config), 0.01, 1.0);
         Super := 1.0 / Denominator;
         Scaled := Constrain_F (Cmd * Float (RC_Rate), -520.0, 520.0);
         Rate := Constrain_F (Scaled * Super, -53_000.0, 53_000.0);
      end if;
      return Constrain_F (Rate, -Setpoint_Limit, Setpoint_Limit);
   end Apply_Quick;

   -----------
   -- Apply --
   -----------

   --  The curves take the axis settings as scalars, so their checks carry
   --  none of the profile.
   function Apply (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude) return Angle_Rate is
      RC_S    : constant Positive_Setting := P.RC_Rates (A);
      Super_S : constant Setting := P.Super_Rates (A);
      Expo_S  : constant Expo_Setting := P.RC_Expo (A);
   begin
      case P.Kind is
         when Super_Rate =>
            return Apply_Super_Rate (RC_S, Super_S, Expo_S, Cmd, Cmd_Abs);
         when Acro_Plus =>
            return Apply_Acro_Plus (RC_S, Super_S, Expo_S, Cmd, Cmd_Abs);
         when RC_Curve =>
            return Apply_RC_Curve (RC_S, Super_S, Expo_S, Cmd, Cmd_Abs);
         when Actual =>
            return Apply_Actual (RC_S, Super_S, Expo_S, Cmd, Cmd_Abs);
         when Quick =>
            return Apply_Quick (RC_S, Super_S, Expo_S, P.Quick_Expo, Cmd, Cmd_Abs);
      end case;
   end Apply;

   -----------------
   -- Setpoint_Of --
   -----------------

   function Setpoint_Of (P : Profile; A : Axis; Cmd : Command) return Setpoint is
      Limit : constant Float := Float (P.Limits (A));
   begin
      return Constrain_F (Apply (P, A, Cmd, abs Cmd), -Limit, Limit);
   end Setpoint_Of;

end Adaflight.Rates;
