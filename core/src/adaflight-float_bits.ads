--  The bit pattern of a float, for hexadecimal printing in logs.

with Ada.Unchecked_Conversion;
with Interfaces;

package Adaflight.Float_Bits with SPARK_Mode, Pure is

   function To_Bits is new Ada.Unchecked_Conversion (Float, Interfaces.Unsigned_32);

   function Float_Bits (F : Float) return Interfaces.Unsigned_32 is (To_Bits (F));

end Adaflight.Float_Bits;
