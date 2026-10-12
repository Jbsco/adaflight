package body Adaflight.Text with SPARK_Mode is

   Upper_Digits : constant String := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
   Lower_Digits : constant String := "0123456789abcdefghijklmnopqrstuvwxyz";

   Max_Exponent : constant := 38;
   Max_Scale    : constant := 1.00000007E38;

   --  A mantissa or a divisor past this takes no further digit.
   Mantissa_Limit : constant := 3.0E37;

   --  The scale of an exponent of ten as the repeated products of 1.0E8 and
   --  then of 10.0 leave it, so a read value scales as the reference computes it.
   function Scale_Of (Expon : Natural) return Float
     with Pre  => Expon <= Max_Exponent,
          Post => Scale_Of'Result in 1.0 .. Max_Scale;

   function Scale_Of (Expon : Natural) return Float is
      Scale_Table : constant array (0 .. Max_Exponent) of Float :=
        (1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0, 100000000.0, 1.0E9,
         1.0E10, 9.9999998E10, 9.99999996E11, 9.99999983E12, 1.0E14, 9.99999987E14, 1.00000003E16,
         9.99999984E16, 9.99999984E17, 9.99999998E18, 1.00000002E20, 1.00000002E21, 9.99999978E21,
         9.99999978E22, 1.00000001E24, 1.00000007E25, 1.00000003E26, 1.00000006E27, 1.00000006E28,
         1.00000002E29, 1.00000002E30, 9.99999985E30, 1.00000003E32, 1.00000007E33, 1.00000004E34,
         1.00000004E35, 1.00000004E36, 1.00000006E37, 1.00000007E38);
   begin
      return Scale_Table (Expon);
   end Scale_Of;

   function Code (C : Character) return Integer is (Character'Pos (C));

   function Magnitude (Value : Integer_32) return Unsigned_32 is
     (if Value < 0 then (not Unsigned_32'Mod (Value)) + 1 else Unsigned_32 (Value));

   function To_Signed (Bits : Unsigned_32) return Integer_32 is
     (if Bits >= 2 ** 31 then -Integer_32 (not Bits) - 1 else Integer_32 (Bits));

   --  A digit's value in any base up to sixteen, or minus one.
   function Digit_Value (C : Character) return Integer is
     (if C in '0' .. '9' then Code (C) - Code ('0')
      elsif C in 'a' .. 'f' then Code (C) - Code ('a') + 10
      elsif C in 'A' .. 'F' then Code (C) - Code ('A') + 10
      else -1);

   --  The digits of Value in Base at the end of D, Count of them.
   procedure Digits_Of (Value : Unsigned_32; Base : Number_Base; Upper : Boolean;
                        D : out String; Count : out Natural)
     with Pre  => D'Length >= 1,
          Post => Count in 1 .. D'Length
   is
      V    : Unsigned_32 := Value;
      Stop : Positive := D'Last;
   begin
      D := (others => '0');
      for I in reverse D'Range loop
         pragma Loop_Invariant (Stop in D'Range);
         declare
            Digit : constant Natural := Natural (V mod Unsigned_32 (Base));
         begin
            D (I) := (if Upper then Upper_Digits (Digit + 1) else Lower_Digits (Digit + 1));
         end;
         Stop := I;
         V := V / Unsigned_32 (Base);
         exit when V = 0;
      end loop;
      Count := D'Last - Stop + 1;
   end Digits_Of;

   --  A signed value with Room digits at most behind its sign.
   procedure Put_Signed (Value : Integer_32; Base : Number_Base; Upper : Boolean; Room : Positive;
                         Buffer : in out String; Length : out Natural)
     with Pre  => Room <= Max_Digits and then Buffer'Length > Room,
          Post => Length in 1 .. Room + 1
   is
      D     : String (1 .. Room);
      Count : Natural;
      Start : Positive := Buffer'First;
   begin
      Digits_Of (Magnitude (Value), Base, Upper, D, Count);
      if Value < 0 then
         Buffer (Buffer'First) := '-';
         Start := Buffer'First + 1;
      end if;
      Buffer (Start .. Start + (Count - 1)) := D (Room - Count + 1 .. Room);
      Length := Count + (if Value < 0 then 1 else 0);
   end Put_Signed;

   function Compare_Ignoring_Case (A, B : String; Count : Natural) return Integer is
      D      : Integer := 0;
      C1, C2 : Integer;
   begin
      for I in 0 .. Count - 1 loop
         C1 := (if I < A'Length then Code (To_Lower (A (A'First + I))) else 0);
         C2 := (if I < B'Length then Code (To_Lower (B (B'First + I))) else 0);
         D := C1 - C2;
         exit when D /= 0 or else C2 = 0;
      end loop;
      return D;
   end Compare_Ignoring_Case;

   function Find_Ignoring_Case (Haystack, Needle : String) return Natural is
   begin
      if Needle'Length = 0 then
         return (if Haystack'Length > 0 then Haystack'First else 0);
      end if;
      for I in Haystack'Range loop
         if Compare_Ignoring_Case (Haystack (I .. Haystack'Last), Needle, Needle'Length) = 0 then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Ignoring_Case;

   procedure Put_Unsigned (Value : Unsigned_32; Base : Number_Base; Upper : Boolean;
                           Buffer : in out String; Length : out Natural) is
      D     : String (1 .. Max_Digits);
      Count : Natural;
   begin
      Digits_Of (Value, Base, Upper, D, Count);
      Buffer (Buffer'First .. Buffer'First + (Count - 1)) := D (Max_Digits - Count + 1 .. Max_Digits);
      Length := Count;
   end Put_Unsigned;

   procedure Put_Integer (Value : Integer_32; Buffer : in out String; Length : out Natural) is
   begin
      Put_Signed (Value, 10, False, Max_Decimal_Length - 1, Buffer, Length);
   end Put_Integer;

   procedure Put_Integer_In_Base (Value : Integer_32; Base : Integer; Buffer : in out String; Length : out Natural) is
   begin
      Put_Signed (Value, (if Base in Number_Base then Base else 10), True, Max_Digits, Buffer, Length);
   end Put_Integer_In_Base;

   procedure Put_Fixed (Value : Float; Buffer : in out String; Length : out Natural) is
      X     : Float := Value;
      V     : Integer_32;
      D     : String (1 .. 10);
      Count : Natural;
      P     : String (1 .. 10) := (others => '0');
      M     : Natural;
   begin
      if X > 0.0 then
         X := X + 0.0005;
      else
         X := X - 0.0005;
      end if;
      V := Integer_32 (Float'Truncation (X * 1000.0));
      Digits_Of (Magnitude (V), 10, False, D, Count);
      --  At least four digits, so that three fall behind the point.
      M := Natural'Max (Count, 4);
      P (M - Count + 1 .. M) := D (10 - Count + 1 .. 10);
      Buffer (Buffer'First) := (if V >= 0 then ' ' else '-');
      Buffer (Buffer'First + 1 .. Buffer'First + M - 3) := P (1 .. M - 3);
      Buffer (Buffer'First + M - 2) := '.';
      Buffer (Buffer'First + M - 1 .. Buffer'First + M + 1) := P (M - 2 .. M);
      Length := M + 2;
   end Put_Fixed;

   function To_Float (S : String) return Float is
      I      : Integer := S'First;
      Sign   : Float := 1.0;
      Value  : Float := 0.0;
      Pow10  : Float := 10.0;
      Beyond : Boolean := False;
      Frac   : Boolean := False;
      Expon  : Natural := 0;
      Result : Float;
   begin
      while I <= S'Last and then (S (I) = ' ' or else S (I) = Ada.Characters.Latin_1.HT) loop
         pragma Loop_Invariant (I in S'First .. S'Last);
         pragma Loop_Variant (Increases => I);
         I := I + 1;
      end loop;
      if I <= S'Last and then S (I) = '-' then
         Sign := -1.0;
         I := I + 1;
      elsif I <= S'Last and then S (I) = '+' then
         I := I + 1;
      end if;
      while I <= S'Last and then Is_Digit (S (I)) loop
         pragma Loop_Invariant (I in S'First .. S'Last);
         pragma Loop_Invariant (Value in 0.0 .. 3.1E38);
         pragma Loop_Variant (Increases => I);
         if Value <= Mantissa_Limit then
            Value := Value * 10.0 + Float (Code (S (I)) - Code ('0'));
         end if;
         I := I + 1;
      end loop;
      if I <= S'Last and then S (I) = '.' then
         I := I + 1;
         while I <= S'Last and then Is_Digit (S (I)) loop
            pragma Loop_Invariant (I in S'First .. S'Last);
            pragma Loop_Invariant (Value in 0.0 .. 3.1E38);
            pragma Loop_Invariant (Pow10 in 10.0 .. 3.1E38);
            pragma Loop_Variant (Increases => I);
            if not Beyond then
               Value := Value + Float (Code (S (I)) - Code ('0')) / Pow10;
               if Pow10 <= Mantissa_Limit then
                  Pow10 := Pow10 * 10.0;
               else
                  Beyond := True;
               end if;
            end if;
            I := I + 1;
         end loop;
      end if;
      if I <= S'Last and then (S (I) = 'e' or else S (I) = 'E') then
         I := I + 1;
         if I <= S'Last and then S (I) = '-' then
            Frac := True;
            I := I + 1;
         elsif I <= S'Last and then S (I) = '+' then
            I := I + 1;
         end if;
         while I <= S'Last and then Is_Digit (S (I)) loop
            pragma Loop_Invariant (I in S'First .. S'Last);
            pragma Loop_Invariant (Expon <= 10_009);
            pragma Loop_Variant (Increases => I);
            if Expon <= 1000 then
               Expon := Expon * 10 + (Code (S (I)) - Code ('0'));
            end if;
            I := I + 1;
         end loop;
      end if;
      if Expon > Max_Exponent then
         --  The scale is past the float range: a division by it leaves
         --  nothing, a product saturates.
         Result := (if Frac or else Value = 0.0 then 0.0 else Float'Last);
      elsif Frac then
         Result := Value / Scale_Of (Expon);
      else
         declare
            Product : constant Long_Float := Long_Float (Value) * Long_Float (Scale_Of (Expon));
         begin
            Result := (if Product <= Long_Float (Float'Last) then Float (Product) else Float'Last);
         end;
      end if;
      return Sign * Result;
   end To_Float;

   procedure Format (Template : String; Args : Argument_List; Pool : String;
                     Output : in out String; Length : out Natural) is
      I     : Integer := Template'First;
      Used  : Natural := 0;
      C     : Character;
      Zero  : Boolean;
      Width : Natural;
      Num   : String (1 .. Max_Signed_Length) := (others => ' ');
      N     : Natural;
      A     : Argument;
      Found : Boolean;
      Ended : Boolean;

      procedure Put (Ch : Character)
        with Pre  => Length <= Output'Length,
             Post => Length <= Output'Length
      is
      begin
         if Length < Output'Length then
            Output (Output'First + Length) := Ch;
            Length := Length + 1;
         end if;
      end Put;

      --  Item behind its padding to the width.
      procedure Put_Padded (Item : String; Zero_Fill : Boolean)
        with Pre  => Length <= Output'Length,
             Post => Length <= Output'Length
      is
         Fill : constant Character := (if Zero_Fill then '0' else ' ');
      begin
         if Width > Item'Length then
            for J in 1 .. Width - Item'Length loop
               pragma Loop_Invariant (Length <= Output'Length);
               Put (Fill);
            end loop;
         end if;
         for J in Item'Range loop
            pragma Loop_Invariant (Length <= Output'Length);
            Put (Item (J));
         end loop;
      end Put_Padded;

      procedure Take
        with Pre  => Used <= Args'Length,
             Post => Used <= Args'Length
      is
      begin
         if Used < Args'Length then
            A := Args (Args'First + Used);
            Used := Used + 1;
            Found := True;
         else
            A := (Bits => 0, First => 1, Last => 0);
            Found := False;
         end if;
      end Take;

   begin
      Length := 0;
      Scan : while I <= Template'Last loop
         pragma Loop_Invariant (I in Template'First .. Template'Last);
         pragma Loop_Invariant (Length <= Output'Length);
         pragma Loop_Invariant (Used <= Args'Length);
         pragma Loop_Variant (Increases => I);
         C := Template (I);
         I := I + 1;
         if C /= '%' then
            Put (C);
         else
            exit Scan when I > Template'Last;
            C := Template (I);
            I := I + 1;
            Zero := False;
            Width := 0;
            if C = '0' then
               Zero := True;
               exit Scan when I > Template'Last;
               C := Template (I);
               I := I + 1;
            end if;
            if Is_Digit (C) then
               --  The width digits, with a letter of value ten read as one; the
               --  character that ends them is the conversion.
               Width := Digit_Value (C);
               Ended := True;
               for J in I .. Template'Last loop
                  pragma Loop_Invariant (Width <= 10_010);
                  C := Template (J);
                  if Digit_Value (C) < 0 or else Digit_Value (C) > 10 then
                     I := J + 1;
                     Ended := False;
                     exit;
                  end if;
                  if Width <= 1000 then
                     Width := Width * 10 + Digit_Value (C);
                  end if;
               end loop;
               exit Scan when Ended;
            end if;
            if C = 'l' then
               exit Scan when I > Template'Last;
               C := Template (I);
               I := I + 1;
            end if;
            case C is
               when 'd' | 'u' | 'x' | 'X' =>
                  Take;
                  if Found then
                     if C = 'd' then
                        Put_Integer (To_Signed (A.Bits), Num, N);
                     elsif C = 'u' then
                        Put_Unsigned (A.Bits, 10, False, Num, N);
                     else
                        Put_Unsigned (A.Bits, 16, C = 'X', Num, N);
                     end if;
                     Put_Padded (Num (1 .. N), Zero);
                  end if;
               when 'c' =>
                  Take;
                  if Found then
                     Put (Character'Val (A.Bits mod 256));
                  end if;
               when 's' =>
                  Take;
                  if Found then
                     if A.Last < A.First then
                        Put_Padded ("", False);
                     elsif A.First >= Pool'First and then A.Last <= Pool'Last then
                        Put_Padded (Pool (A.First .. A.Last), False);
                     end if;
                  end if;
               when '%' =>
                  Put ('%');
               when others =>
                  null;
            end case;
         end if;
      end loop Scan;
   end Format;

end Adaflight.Text;
