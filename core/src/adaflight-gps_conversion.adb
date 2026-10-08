package body Adaflight.GPS_Conversion with SPARK_Mode is

   use Interfaces;

   Max_Digits : constant := 15;
   subtype Digit_Count is Natural range 0 .. Max_Digits;
   subtype Digit_Index is Positive range 1 .. Max_Digits;
   type Digit_Values is array (Digit_Index) of Unsigned_8;

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');

   function Digit (C : Character) return Unsigned_8 is
     (Character'Pos (C) - Character'Pos ('0'))
     with Pre => Is_Digit (C);

   --  Leading digits of F, at most Max_Digits of them. Too_Many reports a
   --  run of more than Max_Digits digits.
   procedure Collect_Digits
     (F : String; Values : out Digit_Values; Count : out Digit_Count; Too_Many : out Boolean)
     with Pre  => F'First = 1 and then F'Length <= Max_Field_Length,
          Post => Count <= F'Length
   is
      Limit : constant Digit_Count := Natural'Min (F'Length, Max_Digits);
   begin
      Values := (others => 0);
      Count := 0;
      for K in 1 .. Limit loop
         pragma Loop_Invariant (Count = K - 1);
         exit when not Is_Digit (F (K));
         Values (K) := Digit (F (K));
         Count := K;
      end loop;
      Too_Many := Count = Max_Digits and then F'Length > Max_Digits
        and then Is_Digit (F (Max_Digits + 1));
   end Collect_Digits;

   --  Decimal accumulation of Values (From .. To) in eight bits, wrapping
   --  as the reference does.
   function Accumulate (Values : Digit_Values; From : Positive; To : Natural) return Unsigned_8
     with Pre => From <= Max_Digits + 1 and then To <= Max_Digits
   is
      Result : Unsigned_8 := 0;
   begin
      for K in From .. To loop
         if Result /= 0 then
            Result := Result * 10;
         end if;
         Result := Result + Values (K);
      end loop;
      return Result;
   end Accumulate;

   --  Up to four digits after position Start, in ten-thousandths.
   function Fraction (F : String; Start : Positive) return Unsigned_16
     with Pre  => F'First = 1 and then F'Length <= Max_Field_Length
       and then Start <= Max_Field_Length + 1,
          Post => Fraction'Result <= 9999
   is
      Result : Unsigned_16 := 0;
      Next   : Positive := Start;
   begin
      for D in 1 .. 4 loop
         pragma Loop_Invariant
           (Result <= (case D is when 1 => 0, when 2 => 9, when 3 => 99, when others => 999));
         pragma Loop_Invariant (Next in Start .. Start + D - 1);
         Result := Result * 10;
         if Next <= F'Last and then Is_Digit (F (Next)) then
            Result := Result + Unsigned_16 (Digit (F (Next)));
            Next := Next + 1;
         end if;
      end loop;
      return Result;
   end Fraction;

   ---------------------------
   -- Coordinate_To_Degrees --
   ---------------------------

   function Coordinate_To_Degrees (Field : String) return Unsigned_32 is
      F             : constant String (1 .. Field'Length) := Field;
      Values        : Digit_Values;
      Count         : Digit_Count;
      Too_Many      : Boolean;
      Degree_Digits : Digit_Count;
      Degrees       : Unsigned_8;
      Minutes       : Unsigned_8;
      Fractional    : Unsigned_16 := 0;
   begin
      Collect_Digits (F, Values, Count, Too_Many);
      if Too_Many then
         return 0;
      end if;
      Degree_Digits := (if Count > 2 then Count - 2 else 0);
      Degrees := Accumulate (Values, 1, Degree_Digits);
      Minutes := Accumulate (Values, Degree_Digits + 1, Count);
      if Count < F'Length and then F (Count + 1) = '.' then
         Fractional := Fraction (F, Count + 2);
      end if;
      return Unsigned_32 (Degrees) * 10_000_000
        + (Unsigned_32 (Minutes) * 1_000_000 + Unsigned_32 (Fractional) * 100) / 6;
   end Coordinate_To_Degrees;

end Adaflight.GPS_Conversion;
