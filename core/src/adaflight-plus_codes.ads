--  Open Location Codes of the grid lengths: a latitude and longitude encoded
--  as the reference's library does, the pair digits of the integer position
--  at the code precision, the separator after the eighth, then the grid
--  digits of the five by four refinement.
package Adaflight.Plus_Codes with SPARK_Mode is

   Pair_Length    : constant := 10;
   Grid_Length    : constant := 5;
   Maximum_Digits : constant := 15;
   Separator_At   : constant := 8;
   Separator      : constant Character := '+';
   Alphabet       : constant String := "23456789CFGHJMPQRVWX";

   subtype Code_Length is Positive range Pair_Length + 1 .. Maximum_Digits;
   subtype Code_Text is String (1 .. Maximum_Digits + 1);
   subtype Degrees is Long_Float range -1_000.0 .. 1_000.0;

   --  The code of Length digits with its separator; Count is Length + 1.
   procedure Encode (Latitude, Longitude : Degrees; Length : Code_Length; Code : out Code_Text; Count : out Natural)
     with Post => Count = Length + 1;

end Adaflight.Plus_Codes;
