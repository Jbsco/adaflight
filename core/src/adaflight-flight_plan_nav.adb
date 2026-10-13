with Adaflight.Maths;

package body Adaflight.Flight_Plan_Nav with SPARK_Mode is

   Min_Cruise_Mps        : constant := 1.0;
   Pattern_Max_Rate_Rads : constant := 0.25;

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
