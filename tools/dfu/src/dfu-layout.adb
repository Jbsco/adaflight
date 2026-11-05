package body DFU.Layout with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   Limit : constant Interfaces.Unsigned_64 := 2 ** 32;

   function Find (S : String; C : Character; From, To : Natural) return Natural
   with
     Pre  => S'First = 1 and then From >= 1 and then To <= S'Last,
     Post => (if Find'Result /= 0 then Find'Result in From .. To and then S (Find'Result) = C)
   is
   begin
      for J in From .. To loop
         if S (J) = C then
            return J;
         end if;
      end loop;
      return 0;
   end Find;

   function Digit_Value (C : Character; Hex : Boolean) return Integer is
     (case C is
         when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
         when 'a' .. 'f' => (if Hex then Character'Pos (C) - Character'Pos ('a') + 10 else -1),
         when 'A' .. 'F' => (if Hex then Character'Pos (C) - Character'Pos ('A') + 10 else -1),
         when others => -1)
   with Post => Digit_Value'Result in -1 .. 15;

   --  The number at the start of S (From .. To) after any spaces, hexadecimal after "0x".
   procedure Read_Number (S : String; From, To : Natural; Value : out Interfaces.Unsigned_64; Ok : out Boolean)
   with
     Pre  => S'First = 1 and then S'Last <= Max_Text and then From >= 1 and then To <= S'Last,
     Post => (if Ok then Value <= Limit)
   is
      J     : Natural := From;
      Hex   : Boolean := False;
      D     : Integer;
      Count : Natural := 0;
   begin
      Value := 0;
      Ok := False;
      while J <= To and then S (J) = ' ' loop
         pragma Loop_Invariant (J in From .. To);
         J := J + 1;
      end loop;
      if J < To and then S (J) = '0' and then (S (J + 1) = 'x' or else S (J + 1) = 'X') then
         Hex := True;
         J := J + 2;
      end if;
      while J <= To loop
         pragma Loop_Invariant (J >= From and then Value <= Limit and then Count <= J - From);
         D := Digit_Value (S (J), Hex);
         exit when D < 0;
         Value := Value * (if Hex then 16 else 10) + Interfaces.Unsigned_64 (D);
         if Value > Limit then
            return;
         end if;
         Count := Count + 1;
         J := J + 1;
      end loop;
      Ok := Count > 0;
   end Read_Number;

   procedure Parse (Text : String; M : out Memory; Ok : out Boolean) is
      Clean      : String (1 .. Max_Text) := (others => ' ');
      N          : Natural range 0 .. Max_Text := 0;
      Slash_1    : Natural;
      Slash_2    : Natural;
      Slash_3    : Natural;
      Groups_End : Natural;
      From       : Natural;
      Comma      : Natural;
      Star       : Natural;
      Group_End  : Natural;
      Name_First : Natural;
      Name_Last  : Natural;
      Start      : Interfaces.Unsigned_64;
      Count      : Interfaces.Unsigned_64;
      Size       : Interfaces.Unsigned_64;
      Next       : Interfaces.Unsigned_64;
      Good       : Boolean;
   begin
      M := (others => <>);
      Ok := False;
      for J in Text'Range loop
         if Text (J) in ' ' .. '~' then
            N := N + 1;
            Clean (N) := Text (J);
         end if;
         pragma Loop_Invariant (N <= J - Text'First + 1);
      end loop;
      if N = 0 or else Clean (1) /= '@' then
         return;
      end if;
      Slash_1 := Find (Clean, '/', 2, N);
      if Slash_1 = 0 then
         return;
      end if;
      Slash_2 := Find (Clean, '/', Slash_1 + 1, N);
      if Slash_2 = 0 then
         return;
      end if;
      Slash_3 := Find (Clean, '/', Slash_2 + 1, N);
      Groups_End := (if Slash_3 = 0 then N else Slash_3 - 1);

      Name_First := 2;
      Name_Last := Slash_1 - 1;
      while Name_First <= Name_Last and then Clean (Name_First) = ' ' loop
         pragma Loop_Invariant (Name_First in 2 .. Name_Last);
         Name_First := Name_First + 1;
      end loop;
      while Name_Last >= Name_First and then Clean (Name_Last) = ' ' loop
         pragma Loop_Invariant (Name_Last in Name_First .. Slash_1 - 1);
         Name_Last := Name_Last - 1;
      end loop;
      for J in Name_First .. Name_Last loop
         exit when M.Length = Max_Name;
         M.Length := M.Length + 1;
         M.Name (M.Length) := Clean (J);
         pragma Loop_Invariant (M.Length <= J - Name_First + 1);
      end loop;

      Read_Number (Clean, Slash_1 + 1, Slash_2 - 1, Start, Good);
      if not Good or else Start >= Limit then
         return;
      end if;
      Next := Start;
      From := Slash_2 + 1;
      loop
         pragma Loop_Invariant (From >= 1 and then Next <= Limit);
         pragma Loop_Invariant (if M.Pages = 0 then Next = Start
                                else Interfaces.Unsigned_64 (M.Last (M.Pages)) + 1 = Next);
         pragma Loop_Invariant (for all P in 1 .. M.Pages => M.First (P) <= M.Last (P));
         pragma Loop_Invariant
           (for all P in 2 .. M.Pages => M.Last (P - 1) < Address'Last and then M.First (P) = M.Last (P - 1) + 1);
         pragma Loop_Invariant
           (for all P in 1 .. M.Pages => M.First (1) <= M.First (P) and then M.Last (P) <= M.Last (M.Pages));
         if From > Groups_End then
            return;
         end if;
         Comma := Find (Clean, ',', From, Groups_End);
         Group_End := (if Comma = 0 then Groups_End else Comma - 1);
         Star := Find (Clean, '*', From, Group_End);
         if Star = 0 or else Find (Clean, '*', Star + 1, Group_End) /= 0 then
            return;
         end if;
         Read_Number (Clean, From, Star - 1, Count, Good);
         if not Good or else Count = 0 then
            return;
         end if;
         Read_Number (Clean, Star + 1, Group_End, Size, Good);
         if not Good or else Size = 0 then
            return;
         end if;
         if Group_End - Star >= 2 then
            case Clean (Group_End - 1) is
               when 'K' =>
                  Size := Size * 1024;
               when 'M' =>
                  Size := Size * 1024 * 1024;
               when others =>
                  null;
            end case;
         end if;
         if Size > Limit or else Count > Interfaces.Unsigned_64 (Max_Pages - M.Pages) then
            return;
         end if;
         for P in 1 .. Natural (Count) loop
            pragma Loop_Invariant (M.Pages = M.Pages'Loop_Entry + P - 1 and then Next <= Limit);
            pragma Loop_Invariant (if M.Pages = 0 then Next = Start
                                   else Interfaces.Unsigned_64 (M.Last (M.Pages)) + 1 = Next);
            pragma Loop_Invariant (for all Q in 1 .. M.Pages => M.First (Q) <= M.Last (Q));
            pragma Loop_Invariant
              (for all Q in 2 .. M.Pages =>
                 M.Last (Q - 1) < Address'Last and then M.First (Q) = M.Last (Q - 1) + 1);
            pragma Loop_Invariant
              (for all Q in 1 .. M.Pages => M.First (1) <= M.First (Q) and then M.Last (Q) <= M.Last (M.Pages));
            if Next + Size > Limit then
               return;
            end if;
            M.Pages := M.Pages + 1;
            M.First (M.Pages) := Address (Next);
            M.Last (M.Pages) := Address (Next + Size - 1);
            Next := Next + Size;
         end loop;
         if Comma = 0 then
            Ok := M.Pages >= 1;
            return;
         end if;
         From := Comma + 1;
      end loop;
   end Parse;

   function Lower (C : Character) return Character is
     (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C);

   function Is_Internal_Flash (M : Memory) return Boolean is
      Spaced : constant String := "internal flash";
      Joined : constant String := "internalflash";
   begin
      if M.Length = Spaced'Length then
         return (for all J in 1 .. M.Length => Lower (M.Name (J)) = Spaced (J));
      elsif M.Length = Joined'Length then
         return (for all J in 1 .. M.Length => Lower (M.Name (J)) = Joined (J));
      end if;
      return False;
   end Is_Internal_Flash;

   procedure Parse_Configuration (Data : Byte_Array; Info : out Interface_Info) is
      Interface_Descriptor  : constant := 4;
      Functional_Descriptor : constant := 16#21#;
      Offset  : Natural;
      Size    : Byte;
      Kind    : Byte;
      In_DFU  : Boolean := False;
   begin
      Info := (others => <>);
      if Data'Length < 2 then
         return;
      end if;
      Offset := Data'First;
      while Offset < Data'Last loop
         pragma Loop_Invariant (Offset in Data'First .. Data'Last - 1);
         Size := Data (Offset);
         Kind := Data (Offset + 1);
         if Kind = Interface_Descriptor and then Data'Last - Offset >= 8 then
            In_DFU := Data (Offset + 5) = 16#FE# and then Data (Offset + 6) = 1;
            if Data (Offset + 2) = 0 and then Info.Alternates < Max_Alternates then
               Info.Alternates := Info.Alternates + 1;
               Info.Strings (Info.Alternates) := Data (Offset + 8);
            end if;
         elsif Kind = Functional_Descriptor and then In_DFU and then Info.Transfer_Size = 0
           and then Size >= 9 and then Data'Last - Offset >= 8
         then
            Info.Transfer_Size :=
              Interfaces.Unsigned_16 (Data (Offset + 5)) + 256 * Interfaces.Unsigned_16 (Data (Offset + 6));
         end if;
         Offset := Offset + (if Size = 0 then 1 else Natural (Size));
      end loop;
   end Parse_Configuration;

   procedure Decode_String (Data : Byte_Array; Text : out String; Length : out Natural) is
      Last : Integer;
      Code : Natural;
      J    : Natural;
   begin
      Text := (others => ' ');
      Length := 0;
      if Data'Length < 2 then
         return;
      end if;
      Last := Data'First + Natural'Min (Natural (Data (Data'First)), Data'Length) - 1;
      J := Data'First + 2;
      while J < Last loop
         pragma Loop_Invariant (J >= Data'First + 2 and then Last <= Data'Last and then Length <= Max_Text);
         Code := Natural (Data (J)) + 256 * Natural (Data (J + 1));
         if Code in 16#20# .. 16#7E# and then Length < Max_Text then
            Length := Length + 1;
            Text (Length) := Character'Val (Code);
         end if;
         J := J + 2;
      end loop;
   end Decode_String;

end DFU.Layout;
