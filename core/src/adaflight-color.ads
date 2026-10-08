--  Colors for the LED strip: hue, saturation, value and their conversion
--  to eight-bit red, green, and blue.

with Interfaces;

package Adaflight.Color with SPARK_Mode, Pure is

   subtype Component is Interfaces.Unsigned_8;

   Hue_Max : constant := 359;
   subtype Hue is Natural range 0 .. Hue_Max;

   type HSV is record
      H : Hue := 0;
      S : Component := 0;
      V : Component := 0;
   end record;

   type RGB is record
      R : Component := 0;
      G : Component := 0;
      B : Component := 0;
   end record;

   function To_RGB (C : HSV) return RGB;

end Adaflight.Color;
