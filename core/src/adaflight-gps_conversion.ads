--  Conversion of a GPS coordinate field in degrees and minutes
--  ("ddmm.mmmm") to ten-millionths of a degree.

with Interfaces;

package Adaflight.GPS_Conversion with SPARK_Mode, Pure is

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  Returns zero when the integer part runs beyond fifteen digits. The
   --  digits of degrees and minutes accumulate in eight bits and wrap as
   --  the reference's do.
   Max_Field_Length : constant := 64;

   function Coordinate_To_Degrees (Field : String) return Unsigned_32
     with Pre => Field'Length <= Max_Field_Length;

end Adaflight.GPS_Conversion;
