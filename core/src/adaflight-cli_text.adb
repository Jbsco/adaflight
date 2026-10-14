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
