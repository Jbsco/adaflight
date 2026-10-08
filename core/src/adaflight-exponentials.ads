--  Fast exponential and logarithm with the error bounds of the
--  underlying polynomials: relative error 1.0e-5 for Exp_Approx, absolute
--  error 1.0e-6 for Log_Approx over normal inputs. The exponential is
--  assembled from a power of two and an exact mantissa; the logarithm
--  reads the bit pattern of its argument.

with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;

package Adaflight.Exponentials with SPARK_Mode, Pure is

   use type Interfaces.Unsigned_32;

   subtype Exp_Argument is Float range -87.0 .. 88.0;

   function Exp_Approx (X : Exp_Argument) return Float
     with Post => Exp_Approx'Result > 0.0;

   subtype Positive_Signal is Float range Float'Succ (0.0) .. Signal_Bound;

   function Log_Approx (X : Positive_Signal) return Float
     with Post => abs Log_Approx'Result <= 128.0;

   function Pow_Approx (Base : Positive_Signal; Exponent : Float) return Float
     with Pre  => abs Exponent <= 2.0 ** 20
       and then Exponent * Log_Approx (Base) in Exp_Argument,
          Post => Pow_Approx'Result > 0.0;

end Adaflight.Exponentials;
