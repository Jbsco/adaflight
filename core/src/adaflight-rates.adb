with Adaflight.Maths; use Adaflight.Maths;

package body Adaflight.Rates with SPARK_Mode is

   RC_Rate_Incremental : constant Float := 14.54;

   subtype Unit is Float range -1.0 .. 1.0;
   subtype Fraction is Float range 0.0 .. 1.0;

   function Cube (X : Unit) return Unit is (X * X * X)
     with Post => abs Cube'Result <= abs X;

   function Fifth (X : Unit) return Unit is (X * X * X * X * X)
     with Post => abs Fifth'Result <= abs X;

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

   function Apply_Super_Rate (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude)
     return Angle_Rate
   is
      Command_Curved : Unit := Cmd;
      RC_Rate        : constant Base_Rate := Base_Rate_Of (P.RC_Rates (A));
      Rate           : Float;
   begin
      if P.RC_Expo (A) /= 0 then
         Command_Curved := Cmd * Cube (Cmd_Abs) * (Float (P.RC_Expo (A)) / 100.0)
           + Cmd * (1.0 - Float (P.RC_Expo (A)) / 100.0);
      end if;
      Rate := 200.0 * RC_Rate * Command_Curved;
      pragma Assert (abs Rate <= 2201.0);
      if P.Super_Rates (A) /= 0 then
         Rate := Rate * Super_Factor (Cmd_Abs, P.Super_Rates (A));
      end if;
      return Constrain_F (Rate, -Max_Angle_Rate, Max_Angle_Rate);
   end Apply_Super_Rate;

   function Apply_Acro_Plus (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude)
     return Angle_Rate
   is
      Expo_Term : constant Float := 0.01 * Float (P.RC_Expo (A)) * (Cmd * Cmd - 1.0);
      Curved    : Float;
      Rate      : Float;
   begin
      pragma Assert (Expo_Term in -1.0 .. 0.0);
      Curved := (1.0 + Expo_Term) * Cmd;
      pragma Assert (abs Curved <= 1.0);
      Rate := 10.0 * Float (P.RC_Rates (A)) * Curved;
      pragma Assert (abs Rate <= 2600.0);
      Rate := Rate * (1.0 + Cmd_Abs * Float (P.Super_Rates (A)) * 0.01);
      return Constrain_F (Rate, -Max_Angle_Rate, Max_Angle_Rate);
   end Apply_Acro_Plus;

   function Apply_RC_Curve (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude)
     return Angle_Rate
   is
      Curve     : constant Fraction := Float (P.RC_Expo (A)) / 100.0;
      Use_Rates : constant Float := Super_Factor (Cmd_Abs, P.Super_Rates (A));
      Blend     : constant Unit := Expo_Curve (Cmd, Cube (Cmd), Curve);
      Curved    : constant Float := Blend * (Float (P.RC_Rates (A)) / 1000.0);
   begin
      pragma Assert (abs Curved <= 0.26);
      return Constrain_F ((2000.0 * Use_Rates) * Curved, -Setpoint_Limit, Setpoint_Limit);
   end Apply_RC_Curve;

   function Apply_Actual (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude)
     return Angle_Rate
   is
      Expo               : constant Fraction := Float (P.RC_Expo (A)) / 100.0;
      Center_Sensitivity : constant Float := Float (P.RC_Rates (A)) * 10.0;
      Stick_Movement     : constant Float :=
        Float'Max (0.0, Float (P.Super_Rates (A)) * 10.0 - Center_Sensitivity);
      Shaped             : constant Unit := Expo_Curve (Cmd, Fifth (Cmd), Expo);
      Weighted           : constant Float := Cmd_Abs * Shaped;
   begin
      pragma Assert (Center_Sensitivity in 0.0 .. 2550.0);
      pragma Assert (Stick_Movement in 0.0 .. 2550.0);
      pragma Assert (abs Weighted <= 1.0);
      return Constrain_F (Cmd * Center_Sensitivity + Stick_Movement * Weighted,
                          -Max_Angle_Rate, Max_Angle_Rate);
   end Apply_Actual;

   function Apply_Quick (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude)
     return Angle_Rate
   is
      RC_Rate      : constant Positive := P.RC_Rates (A) * 2;
      Max_DPS      : constant Positive := Natural'Max (P.Super_Rates (A) * 10, RC_Rate);
      Expo         : constant Fraction := Float (P.RC_Expo (A)) / 100.0;
      Ratio        : constant Float := Float (Max_DPS) / Float (RC_Rate);
      Super_Config : Float;
      Curve        : Unit;
      Super        : Float;
      Rate         : Float;
   begin
      pragma Assert (Ratio in 1.0 .. 2550.0);
      Super_Config := (Ratio - 1.0) / Ratio;
      pragma Assert (Super_Config in 0.0 .. 1.0);
      if P.Quick_Expo then
         Curve := Expo_Curve (Cmd, Cube (Cmd), Expo);
         Super := 1.0 / Constrain_F (1.0 - (Cmd_Abs * Super_Config), 0.01, 1.0);
         pragma Assert (Super in 1.0 .. 100.0);
         Rate := Curve * Float (RC_Rate) * Super;
      else
         Curve := Expo_Curve (Cmd_Abs, Cube (Cmd_Abs), Expo);
         Super := 1.0 / Constrain_F (1.0 - (Curve * Super_Config), 0.01, 1.0);
         pragma Assert (Super in 1.0 .. 100.0);
         Rate := Cmd * Float (RC_Rate) * Super;
      end if;
      return Constrain_F (Rate, -Setpoint_Limit, Setpoint_Limit);
   end Apply_Quick;

   -----------
   -- Apply --
   -----------

   function Apply (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude) return Angle_Rate is
     (case P.Kind is
        when Super_Rate => Apply_Super_Rate (P, A, Cmd, Cmd_Abs),
        when Acro_Plus  => Apply_Acro_Plus (P, A, Cmd, Cmd_Abs),
        when RC_Curve   => Apply_RC_Curve (P, A, Cmd, Cmd_Abs),
        when Actual     => Apply_Actual (P, A, Cmd, Cmd_Abs),
        when Quick      => Apply_Quick (P, A, Cmd, Cmd_Abs));

   -----------------
   -- Setpoint_Of --
   -----------------

   function Setpoint_Of (P : Profile; A : Axis; Cmd : Command) return Setpoint is
      Limit : constant Float := Float (P.Limits (A));
   begin
      return Constrain_F (Apply (P, A, Cmd, abs Cmd), -Limit, Limit);
   end Setpoint_Of;

end Adaflight.Rates;
