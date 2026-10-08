--  Powers of two over the exponent range of a binary32 float, as a
--  function over a static table.

package Adaflight.Powers with SPARK_Mode, Pure is

   subtype Binary_Exponent is Integer range -126 .. 127;

   function Power_Of_Two (E : Binary_Exponent) return Float
     with Post => Power_Of_Two'Result in 2.0 ** (-126) .. 2.0 ** 127;

end Adaflight.Powers;
