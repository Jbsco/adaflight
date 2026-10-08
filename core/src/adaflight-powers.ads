--  Powers of two over the exponent range of a binary32 float, as a
--  function over a static table.

package Adaflight.Powers with SPARK_Mode, Pure is

   subtype Binary_Exponent is Integer range -126 .. 127;

   --  Exponents whose power is a normal float with a normal float on
   --  either side.
   subtype Normal_Exponent is Binary_Exponent range -125 .. 126;

   function Power_Of_Two (E : Normal_Exponent) return Float
     with Post => Power_Of_Two'Result in 2.0 ** (-125) .. 2.0 ** 126;

end Adaflight.Powers;
