package body Adaflight.Plus_Codes with SPARK_Mode is

   Lat_Max        : constant := 90.0;
   Lon_Max        : constant := 180.0;
   Grid_Rows      : constant := 5;
   Grid_Cols      : constant := 4;
   Encoding_Base  : constant := 20;
   Lat_Precision  : constant := 2.5e7;
   Lon_Precision  : constant := 8.192e6;

   --  The latitude precision of a grid-length code: the pair precision over
   --  the rows of each grid digit.
   function Latitude_Precision (Length : Code_Length) return Long_Float is
     ((1.0 / 8_000.0) / (case Length - Pair_Length is
                            when 1 => 5.0, when 2 => 25.0, when 3 => 125.0, when 4 => 625.0, when others => 3_125.0));

   --  The latitude clipped to its range, the north pole moved half a code
   --  precision south so a code exists for it.
   function Adjust_Latitude (Latitude : Degrees; Length : Code_Length) return Long_Float is
     (if Latitude < -Lat_Max then -Lat_Max
      elsif Latitude < Lat_Max then Latitude
      else Lat_Max - Latitude_Precision (Length) / 2.0)
     with Post => Adjust_Latitude'Result in -Lat_Max .. Lat_Max;

   procedure Encode (Latitude, Longitude : Degrees; Length : Code_Length; Code : out Code_Text; Count : out Natural) is
      Lat       : constant Long_Float := Adjust_Latitude (Latitude, Length);
      Lon       : Long_Float := Longitude;
      Lat_Val   : Long_Long_Integer;
      Lng_Val   : Long_Long_Integer;
      Full      : String (1 .. Maximum_Digits + 1) := (others => ' ');
      Pos       : Natural;
   begin
      for Turn in 1 .. 3 loop
         if Lon < -Lon_Max then
            Lon := Lon + 2.0 * Lon_Max;
         end if;
      end loop;
      for Turn in 1 .. 3 loop
         if Lon >= Lon_Max then
            Lon := Lon - 2.0 * Lon_Max;
         end if;
      end loop;
      pragma Assert (Lon in -Lon_Max .. Lon_Max);
      declare
         Lat_Scaled : constant Long_Float := Lat_Max * Lat_Precision + Lat * Lat_Precision;
         Lon_Scaled : constant Long_Float := Lon_Max * Lon_Precision + Lon * Lon_Precision;
      begin
         pragma Assert (Lat_Scaled in 0.0 .. 2.0 * Lat_Max * Lat_Precision);
         pragma Assert (Lon_Scaled in 0.0 .. 2.0 * Lon_Max * Lon_Precision);
         Lat_Val := Long_Long_Integer (Long_Float'Truncation (Lat_Scaled));
         Lng_Val := Long_Long_Integer (Long_Float'Truncation (Lon_Scaled));
      end;
      Pos := Maximum_Digits + 1;
      for I in 1 .. Grid_Length loop
         pragma Loop_Invariant (Pos = Maximum_Digits + 2 - I);
         pragma Loop_Invariant (Lat_Val in 0 .. 2 ** 34 and then Lng_Val in 0 .. 2 ** 34);
         declare
            Lat_Digit : constant Natural := Natural (Lat_Val mod Grid_Rows);
            Lng_Digit : constant Natural := Natural (Lng_Val mod Grid_Cols);
         begin
            Full (Pos) := Alphabet (Lat_Digit * Grid_Cols + Lng_Digit + 1);
            Pos := Pos - 1;
            Lat_Val := Lat_Val / Grid_Rows;
            Lng_Val := Lng_Val / Grid_Cols;
         end;
      end loop;
      Pos := Pair_Length + 1;
      for I in 1 .. Pair_Length / 2 loop
         pragma Loop_Invariant (Pos = Pair_Length + 1 - 2 * (I - 1) - (if I > 1 then 1 else 0));
         pragma Loop_Invariant (Lat_Val in 0 .. 2 ** 34 and then Lng_Val in 0 .. 2 ** 34);
         Full (Pos) := Alphabet (Natural (Lng_Val mod Encoding_Base) + 1);
         Full (Pos - 1) := Alphabet (Natural (Lat_Val mod Encoding_Base) + 1);
         Pos := Pos - 2;
         Lat_Val := Lat_Val / Encoding_Base;
         Lng_Val := Lng_Val / Encoding_Base;
         if I = 1 then
            Full (Pos) := Separator;
            Pos := Pos - 1;
         end if;
      end loop;
      Count := Length + 1;
      Code := (others => ' ');
      Code (1 .. Count) := Full (1 .. Count);
   end Encode;

end Adaflight.Plus_Codes;
