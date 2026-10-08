with Ada.Numerics.Long_Elementary_Functions;

package body Adaflight.Accurate_Power with SPARK_Mode => Off is

   function Pow (Base : Float; Expo : Float) return Float is
      use Ada.Numerics.Long_Elementary_Functions;
      Ln       : constant Long_Float := Log (Long_Float (Base));
      Argument : constant Long_Float := Long_Float'Min (Long_Float (Expo) * Ln, 700.0);
      Wide     : constant Long_Float := Exp (Argument);
   begin
      return Float (Long_Float'Min (Long_Float'Max (Wide, 0.0),
                                    Long_Float (Exponentials.Exp_Result_Max)));
   end Pow;

end Adaflight.Accurate_Power;
