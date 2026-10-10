--  The wrapping clocks: the microsecond and millisecond counters are 32-bit
--  values that wrap, and a difference of two readings is signed.
with Interfaces;

package Adaflight.Clock with SPARK_Mode, Pure is
   use type Interfaces.Integer_64;
   subtype Time_Us is Interfaces.Unsigned_32;
   subtype Time_Ms is Interfaces.Unsigned_32;

   --  The plain difference of two readings, and the signed difference of one
   --  wrapping counter: the plain difference brought into the signed range by
   --  one turn of the counter.
   function Difference (Later : Interfaces.Unsigned_32; Earlier : Interfaces.Unsigned_32)
                        return Interfaces.Integer_64 is
     (Interfaces.Integer_64 (Later) - Interfaces.Integer_64 (Earlier));

   function Elapsed (Later : Interfaces.Unsigned_32; Earlier : Interfaces.Unsigned_32) return Interfaces.Integer_32
     with Post =>
       Interfaces.Integer_64 (Elapsed'Result) =
         (if Difference (Later, Earlier) > Interfaces.Integer_64 (Interfaces.Integer_32'Last)
          then Difference (Later, Earlier) - 2 ** 32
          elsif Difference (Later, Earlier) < Interfaces.Integer_64 (Interfaces.Integer_32'First)
          then Difference (Later, Earlier) + 2 ** 32
          else Difference (Later, Earlier));

end Adaflight.Clock;
