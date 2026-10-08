--  Stick to setpoint curves: five rate curve families over a normalized
--  stick command, with the per-axis settings of a rate profile.

with Adaflight.Axes; use Adaflight.Axes;

package Adaflight.Rates with SPARK_Mode, Pure is

   type Curve_Kind is (Super_Rate, Acro_Plus, RC_Curve, Actual, Quick);

   subtype Setting is Natural range 0 .. 255;
   subtype Positive_Setting is Setting range 1 .. 255;
   subtype Expo_Setting is Natural range 0 .. 100;
   Max_Rate_Limit : constant := 1998;
   subtype Rate_Limit is Natural range 0 .. Max_Rate_Limit;

   type Axis_Settings is array (Axis) of Setting;
   type Axis_Rates is array (Axis) of Positive_Setting;
   type Axis_Expo is array (Axis) of Expo_Setting;
   type Axis_Limits is array (Axis) of Rate_Limit;

   type Profile is record
      Kind           : Curve_Kind := Actual;
      RC_Rates       : Axis_Rates := (others => 7);
      RC_Expo        : Axis_Expo := (others => 0);
      Super_Rates    : Axis_Settings := (others => 67);
      Limits         : Axis_Limits := (others => Max_Rate_Limit);
      Quick_Expo     : Boolean := False;
   end record;

   --  Stick command normalized to the unit range and its magnitude.
   subtype Command is Float range -1.0 .. 1.0;
   subtype Magnitude is Float range 0.0 .. 1.0;

   --  Widest rate any curve family produces from the admitted settings.
   Max_Angle_Rate : constant := 2.0 ** 20;
   subtype Angle_Rate is Float range -Max_Angle_Rate .. Max_Angle_Rate;

   Setpoint_Limit : constant := 1998.0;
   subtype Setpoint is Float range -Setpoint_Limit .. Setpoint_Limit;

   --  Angle rate in degrees per second for a stick command on one axis.
   function Apply (P : Profile; A : Axis; Cmd : Command; Cmd_Abs : Magnitude) return Angle_Rate
     with Pre => Cmd_Abs = abs Cmd;

   --  The angle rate held within the profile's limit for the axis.
   function Setpoint_Of (P : Profile; A : Axis; Cmd : Command) return Setpoint
     with Post => abs Setpoint_Of'Result <= Float (P.Limits (A));

end Adaflight.Rates;
