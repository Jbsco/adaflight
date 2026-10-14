package body Adaflight.CLI_Text with SPARK_Mode is

   function Is_Space (Ch : Character) return Boolean is (Ch = ' ' or else Ch in ASCII.HT .. ASCII.CR);

   function Contains_Ignoring_Case (Text, Fragment : String) return Boolean is
      Match : Boolean;
   begin
      if Fragment'Length = 0 then
         return True;
      end if;
      if Fragment'Length > Text'Length then
         return False;
      end if;
      for Start in 0 .. Text'Length - Fragment'Length loop
         Match := True;
         for K in 0 .. Fragment'Length - 1 loop
            if Lower (Text (Text'First + Start + K)) /= Lower (Fragment (Fragment'First + K)) then
               Match := False;
               exit;
            end if;
         end loop;
         if Match then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Ignoring_Case;

   --  The digits from an index on, held once they pass a limit.
   procedure Read_Digits
     (Text : String; From : Positive; Limit : Integer_64; Value : out Integer_64; Over : out Boolean;
      Next : out Positive)
     with Pre  => From in Text'Range and then Text (From) in '0' .. '9' and then Limit in 0 .. 2 ** 32
                  and then Text'Last < Positive'Last,
          Post => Next in From + 1 .. Text'Last + 1 and then Value in 0 .. Limit,
          Always_Terminates
   is
      I : Positive := From;
   begin
      Value := 0;
      Over := False;
      while I <= Text'Last and then Text (I) in '0' .. '9' loop
         pragma Loop_Invariant (I in From .. Text'Last and then Value in 0 .. Limit);
         pragma Loop_Variant (Increases => I);
         if not Over then
            declare
               Longer : constant Integer_64 := Value * 10 + Integer_64 (Character'Pos (Text (I)) - Character'Pos ('0'));
            begin
               if Longer > Limit then
                  Over := True;
                  Value := Limit;
               else
                  Value := Longer;
               end if;
            end;
         end if;
         I := I + 1;
      end loop;
      Next := I;
   end Read_Digits;

   --  The index after leading spaces and a sign, and whether the sign is a
   --  minus.
   procedure Skip_Prefix (Text : String; I : out Positive; Negative : out Boolean)
     with Pre  => Text'First >= 1 and then Text'Last < Positive'Last and then Text'First <= Text'Last + 1,
          Post => I in Text'First .. Text'Last + 1,
          Always_Terminates
   is
   begin
      I := Text'First;
      Negative := False;
      while I <= Text'Last and then Is_Space (Text (I)) loop
         pragma Loop_Invariant (I in Text'First .. Text'Last);
         pragma Loop_Variant (Increases => I);
         I := I + 1;
      end loop;
      if I <= Text'Last and then Text (I) in '+' | '-' then
         Negative := Text (I) = '-';
         I := I + 1;
      end if;
   end Skip_Prefix;

   procedure Parse_Signed (Text : String; Value : out Integer_32; Next : out Positive) is
      I        : Positive;
      Negative : Boolean;
      Digits_Value : Integer_64;
      Over     : Boolean;
   begin
      Skip_Prefix (Text, I, Negative);
      if I > Text'Last or else Text (I) not in '0' .. '9' then
         Value := 0;
         Next := Text'First;
         return;
      end if;
      Read_Digits (Text, I, (if Negative then 2 ** 31 else 2 ** 31 - 1), Digits_Value, Over, Next);
      pragma Unreferenced (Over);
      Value := Integer_32 (if Negative then -Digits_Value else Digits_Value);
   end Parse_Signed;

   procedure Parse_Unsigned (Text : String; Value : out Unsigned_32; Next : out Positive) is
      I        : Positive;
      Negative : Boolean;
      Digits_Value : Integer_64;
      Over     : Boolean;
   begin
      Skip_Prefix (Text, I, Negative);
      if I > Text'Last or else Text (I) not in '0' .. '9' then
         Value := 0;
         Next := Text'First;
         return;
      end if;
      Read_Digits (Text, I, 2 ** 32 - 1, Digits_Value, Over, Next);
      if Over then
         Value := Unsigned_32'Last;
      elsif Negative then
         Value := -Unsigned_32 (Digits_Value);
      else
         Value := Unsigned_32 (Digits_Value);
      end if;
   end Parse_Unsigned;

   function To_Integer (Text : String) return Integer_32 is
      Value : Integer_32;
      Next  : Positive;
   begin
      Parse_Signed (Text, Value, Next);
      pragma Unreferenced (Next);
      return Value;
   end To_Integer;

   Float_Max : constant Long_Float := Long_Float (Float'Last);

   --  Whether the reference's float arithmetic rounds a product to infinity.
   function Overflows (P : Long_Float) return Boolean is (P >= Float_Max + 2.0 ** 103);

   --  The float nearest a product, held at the largest float.
   function Nearest (P : Long_Float) return Float is
     (if P > Float_Max then Float'Last else Float (P))
     with Pre => P >= 0.0, Post => Nearest'Result >= 0.0;

   function Parse_Float (Text : String) return Float is
      I         : Positive := Text'First;
      Negative  : Boolean := False;
      Value     : Float := 0.0;
      Over      : Boolean := False;
      Pow10     : Float := 10.0;
      Pow10_Inf : Boolean := False;
      Scale     : Float := 1.0;
      Scale_Inf : Boolean := False;
      Frac      : Boolean := False;
      Expon     : Unsigned_32 := 0;
      Result    : Float;

      function Digit_At (K : Positive) return Boolean is (K in Text'Range and then Text (K) in '0' .. '9');

      function Digit (K : Positive) return Float is (Float (Character'Pos (Text (K)) - Character'Pos ('0')))
        with Pre => Digit_At (K), Post => Digit'Result in 0.0 .. 9.0;
   begin
      while I <= Text'Last and then (Text (I) = ' ' or else Text (I) = ASCII.HT) loop
         pragma Loop_Invariant (I in Text'Range);
         pragma Loop_Variant (Increases => I);
         I := I + 1;
      end loop;
      if I <= Text'Last and then Text (I) = '-' then
         Negative := True;
         I := I + 1;
      elsif I <= Text'Last and then Text (I) = '+' then
         I := I + 1;
      end if;
      while Digit_At (I) loop
         pragma Loop_Invariant (I in Text'Range and then Value >= 0.0);
         pragma Loop_Variant (Increases => I);
         declare
            P : constant Long_Float := Long_Float (Value) * 10.0;
            T : constant Float := Nearest (P);
         begin
            if Overflows (P) then
               Over := True;
            end if;
            Value := (if T <= 3.0E38 then T + Digit (I) else T);
         end;
         I := I + 1;
      end loop;
      if I <= Text'Last and then Text (I) = '.' then
         I := I + 1;
         while Digit_At (I) loop
            pragma Loop_Invariant (I in Text'Range and then Value >= 0.0 and then Pow10 >= 10.0);
            pragma Loop_Variant (Increases => I);
            if not Pow10_Inf then
               if Value <= 3.0E38 then
                  Value := Value + Digit (I) / Pow10;
               end if;
               if Overflows (Long_Float (Pow10) * 10.0) then
                  Pow10_Inf := True;
               else
                  Pow10 := Nearest (Long_Float (Pow10) * 10.0);
               end if;
            end if;
            I := I + 1;
         end loop;
      end if;
      if I <= Text'Last and then (Text (I) = 'e' or else Text (I) = 'E') then
         I := I + 1;
         if I <= Text'Last and then Text (I) = '-' then
            Frac := True;
            I := I + 1;
         elsif I <= Text'Last and then Text (I) = '+' then
            I := I + 1;
         end if;
         while Digit_At (I) loop
            pragma Loop_Invariant (I in Text'Range);
            pragma Loop_Variant (Increases => I);
            Expon := Expon * 10 + Unsigned_32 (Character'Pos (Text (I)) - Character'Pos ('0'));
            I := I + 1;
         end loop;
         if Expon > 308 then
            Expon := 308;
         end if;
         while Expon >= 8 loop
            pragma Loop_Invariant (Expon <= 308 and then Scale >= 1.0);
            pragma Loop_Variant (Decreases => Expon);
            if not Scale_Inf then
               if Overflows (Long_Float (Scale) * 1.0E8) then
                  Scale_Inf := True;
               else
                  Scale := Nearest (Long_Float (Scale) * 1.0E8);
               end if;
            end if;
            Expon := Expon - 8;
         end loop;
         while Expon > 0 loop
            pragma Loop_Invariant (Expon <= 308 and then Scale >= 1.0);
            pragma Loop_Variant (Decreases => Expon);
            if not Scale_Inf then
               if Overflows (Long_Float (Scale) * 10.0) then
                  Scale_Inf := True;
               else
                  Scale := Nearest (Long_Float (Scale) * 10.0);
               end if;
            end if;
            Expon := Expon - 1;
         end loop;
      end if;
      if Over then
         Result := Float'Last;
      elsif Frac then
         Result := (if Scale_Inf then 0.0 else Value / Scale);
      elsif Scale_Inf then
         Result := (if Value = 0.0 then 0.0 else Float'Last);
      else
         Result := Nearest (Long_Float (Value) * Long_Float (Scale));
      end if;
      return (if Negative then -Result else Result);
   end Parse_Float;

   function Float_Text (X : Float) return String is
      Y : Float;
      F : Float;
      V : Integer_64;
   begin
      if X > 0.0 then
         Y := (if X <= 3.0E38 then X + 0.0005 else X);
      else
         Y := (if X >= -3.0E38 then X - 0.0005 else X);
      end if;
      F := (if Y >= 0.0 then Nearest (Long_Float (Y) * 1000.0) else -Nearest (-(Long_Float (Y) * 1000.0)));
      if F >= 2_147_483_648.0 then
         V := 2_147_483_647;
      elsif F <= -2_147_483_648.0 then
         V := -2_147_483_648;
      else
         V := Integer_64 (Float'Truncation (F));
      end if;
      declare
         Magnitude : constant String := Decimal (abs V);
         Padded    : constant String :=
           (case Magnitude'Length is
               when 1 => "000" & Magnitude,
               when 2 => "00" & Magnitude,
               when 3 => "0" & Magnitude,
               when others => Magnitude);
      begin
         return (if V >= 0 then ' ' else '-') & Padded (Padded'First .. Padded'Last - 3) & '.'
                & Padded (Padded'Last - 2 .. Padded'Last);
      end;
   end Float_Text;

   --  The divisor that scales a fraction of some digits to seven.
   function Fraction_Scale (Count : Natural) return Integer_32 is
     (case Count is
         when 0 => 10_000_000, when 1 => 1_000_000, when 2 => 100_000, when 3 => 10_000, when 4 => 1_000,
         when 5 => 100, when 6 => 10, when others => 1);

   procedure Parse_Coordinate (Text : String; Value : out Integer_32; OK : out Boolean) is
      I        : Positive := Text'First;
      Negative : Boolean := False;
      Whole    : Integer_32 := 0;
      Fraction : Integer_32 := 0;
      Divisor  : Integer_32 := 10_000_000;
      Count    : Natural := 0;
      D        : Integer_32;
   begin
      Value := 0;
      OK := False;
      if I <= Text'Last and then Text (I) = '-' then
         Negative := True;
         I := I + 1;
      elsif I <= Text'Last and then Text (I) = '+' then
         I := I + 1;
      end if;
      if I > Text'Last or else Text (I) not in '0' .. '9' then
         return;
      end if;
      while I <= Text'Last and then Text (I) in '0' .. '9' loop
         pragma Loop_Invariant (I in Text'Range and then Whole >= 0);
         pragma Loop_Variant (Increases => I);
         D := Character'Pos (Text (I)) - Character'Pos ('0');
         if Whole > (Integer_32'Last - D) / 10 then
            return;
         end if;
         Whole := Whole * 10 + D;
         I := I + 1;
      end loop;
      if I <= Text'Last and then Text (I) = '.' then
         I := I + 1;
         while I <= Text'Last and then Text (I) in '0' .. '9' and then Count < 7 loop
            pragma Loop_Invariant
              (I in Text'Range and then Count < 7 and then Divisor = Fraction_Scale (Count)
               and then Fraction in 0 .. 10 ** Count - 1);
            pragma Loop_Variant (Increases => I);
            D := Character'Pos (Text (I)) - Character'Pos ('0');
            if Fraction > (Integer_32'Last - D) / 10 then
               return;
            end if;
            Fraction := Fraction * 10 + D;
            Divisor := Divisor / 10;
            Count := Count + 1;
            I := I + 1;
         end loop;
         while I <= Text'Last and then Text (I) in '0' .. '9' loop
            pragma Loop_Invariant (I in Text'Range);
            pragma Loop_Variant (Increases => I);
            I := I + 1;
         end loop;
         if Divisor > 0 and then Fraction > Integer_32'Last / Divisor then
            return;
         end if;
         Fraction := Fraction * Divisor;
      end if;
      if I <= Text'Last then
         return;
      end if;
      if Whole > (Integer_32'Last - Fraction) / 10_000_000 then
         return;
      end if;
      Value := Whole * 10_000_000 + Fraction;
      if Negative then
         Value := -Value;
      end if;
      OK := True;
   end Parse_Coordinate;

   function Coordinate_Text (Value : Integer_32) return String is
      Magnitude : constant Integer_64 := abs Integer_64 (Value);
      Whole     : constant Integer_64 := Magnitude / 10_000_000;
      Sign      : constant Natural := (if Value < 0 then 1 else 0);
      Width     : constant Positive := (if Whole >= 100 then 3 elsif Whole >= 10 then 2 else 1);
      Text      : String (1 .. Sign + Width + 8) := (others => '0');
      W         : Integer_64 := Whole;
      F         : Integer_64 := Magnitude mod 10_000_000;
   begin
      if Sign = 1 then
         Text (1) := '-';
      end if;
      for K in reverse 1 .. Width loop
         pragma Loop_Invariant (W >= 0);
         Text (Sign + K) := Character'Val (Character'Pos ('0') + Natural (W mod 10));
         W := W / 10;
      end loop;
      Text (Sign + Width + 1) := '.';
      for K in reverse 1 .. 7 loop
         pragma Loop_Invariant (F >= 0);
         Text (Sign + Width + 1 + K) := Character'Val (Character'Pos ('0') + Natural (F mod 10));
         F := F / 10;
      end loop;
      return Text;
   end Coordinate_Text;

   procedure Parse_Whole (Text : String; Value : out Integer_64; OK : out Boolean) is
      I        : Positive := Text'First;
      Negative : Boolean := False;
   begin
      Value := 0;
      OK := False;
      if I <= Text'Last and then Text (I) in '-' | '+' then
         Negative := Text (I) = '-';
         I := I + 1;
      end if;
      if I > Text'Last or else Text (I) not in '0' .. '9' then
         return;
      end if;
      while I <= Text'Last and then Text (I) in '0' .. '9' loop
         pragma Loop_Invariant (I in Text'Range and then Value in 0 .. 10 ** 12);
         pragma Loop_Variant (Increases => I);
         Value := Integer_64'Min (10 ** 12, Value * 10 + Integer_64 (Character'Pos (Text (I)) - Character'Pos ('0')));
         I := I + 1;
      end loop;
      OK := I > Text'Last;
      if Negative then
         Value := -Value;
      end if;
   end Parse_Whole;

   function Decimal (V : Integer_64) return String is
      Buffer    : String (1 .. 21) := (others => '0');
      First     : Positive range 2 .. 21 := 21;
      Magnitude : Unsigned_64 := (if V < 0 then Unsigned_64 (-(V + 1)) + 1 else Unsigned_64 (V));
   begin
      Buffer (21) := Character'Val (Character'Pos ('0') + Natural (Magnitude mod 10));
      Magnitude := Magnitude / 10;
      for K in reverse 2 .. 20 loop
         exit when Magnitude = 0;
         Buffer (K) := Character'Val (Character'Pos ('0') + Natural (Magnitude mod 10));
         Magnitude := Magnitude / 10;
         First := K;
      end loop;
      if V < 0 then
         Buffer (First - 1) := '-';
         return Buffer (First - 1 .. 21);
      end if;
      return Buffer (First .. 21);
   end Decimal;

   --  A number below 100 in one or two digits.
   function Small_Decimal (N : Natural) return String is
     (if N < 10 then (1 => Character'Val (Character'Pos ('0') + N))
      else (Character'Val (Character'Pos ('0') + N / 10), Character'Val (Character'Pos ('0') + N mod 10)))
     with Pre => N < 100;

   --  A port identifier's name by its family.
   function Family_Name (Id : Serial_Feature_Map.Port_Id) return String is
     (case Id is
         when 20 => "VCP",
         when 30 .. 39 => "SOFT" & Small_Decimal (Id - 29),
         when 40 .. 49 => "LPUART" & Small_Decimal (Id - 39),
         when 50 .. 69 => "UART" & Small_Decimal (Id - 50),
         when 70 .. 79 => "PIOUART" & Small_Decimal (Id - 70),
         when others => "");

   function Port_Name (Id : Integer_64; Ports : Port_List) return String is
   begin
      if Id = -1 then
         return "NONE";
      end if;
      for P of Ports loop
         if Integer_64 (P) = Id then
            return Family_Name (P);
         end if;
      end loop;
      return "";
   end Port_Name;

   procedure Port_From_Name (Name : String; Ports : Port_List; Found : out Boolean; Id : out Integer_64) is
   begin
      Found := False;
      Id := -1;
      if Same_Ignoring_Case (Name, "NONE") then
         Found := True;
         return;
      end if;
      for P of Ports loop
         if Family_Name (P)'Length > 0 and then Same_Ignoring_Case (Name, Family_Name (P)) then
            Found := True;
            Id := Integer_64 (P);
            return;
         end if;
      end loop;
   end Port_From_Name;

end Adaflight.CLI_Text;
