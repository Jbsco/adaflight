--  Power through the double-precision elementary functions of the Ada
--  runtime, for tables built at configuration time. The body is outside
--  SPARK (D15); it saturates its result to honor the postcondition.

with Adaflight.Exponentials;

package Adaflight.Accurate_Power with SPARK_Mode, Pure is

   function Pow (Base : Float; Expo : Float) return Float
     with Pre  => Base > 0.0 and then abs Expo <= 1000.0,
          Post => Pow'Result in 0.0 .. Exponentials.Exp_Result_Max;

end Adaflight.Accurate_Power;
