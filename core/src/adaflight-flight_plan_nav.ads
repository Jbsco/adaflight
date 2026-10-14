--  The flight plan executor: the period of the hold pattern's orbit at a
--  speed, flown at the configured hold radius.
with Interfaces;

package Adaflight.Flight_Plan_Nav with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   subtype Unsigned_16 is Interfaces.Unsigned_16;

   --  The hold radius in centimeters and the autopilot's maximum velocity in
   --  cm/s, within the configuration interface's ranges.
   subtype Hold_Radius is Unsigned_16 range 50 .. 1_000;
   subtype Max_Velocity is Unsigned_16 range 100 .. 5_000;

   --  The orbit's period in tenths of a second at Speed in cm/s, the maximum
   --  velocity for 0, never below 1 m/s and never above the pattern's
   --  turn rate.
   function Orbit_Period_Ds (Speed : Unsigned_16; Radius : Hold_Radius; Max_Speed : Max_Velocity) return Unsigned_16
     with Global => null,
          Post   => Orbit_Period_Ds'Result >= 1;

end Adaflight.Flight_Plan_Nav;
