package body Adaflight.RTC with SPARK_Mode is

   subtype Cycle_Year is Natural range 0 .. 3;
   subtype Month_Index is Natural range 0 .. 11;
   type Day_Table is array (Cycle_Year, Month_Index) of Unsigned_16;

   --  Days from the start of the four-year cycle to the start of each month.
   Days : constant Day_Table :=
     ((0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335),
      (366, 397, 425, 456, 486, 517, 547, 578, 609, 639, 670, 700),
      (731, 762, 790, 821, 851, 882, 912, 943, 974, 1004, 1035, 1065),
      (1096, 1127, 1155, 1186, 1216, 1247, 1277, 1308, 1339, 1369, 1400, 1430));

   Cycle_Days : constant := 365 * 4 + 1;

   function Wrapped_8 (V : Integer) return Unsigned_8 is (Unsigned_8 (V mod 256));
   function Wrapped_16 (V : Interfaces.Integer_64) return Unsigned_16 is (Unsigned_16 (V mod 65536));

   ----------------
   -- Seconds_Of --
   ----------------

   function Seconds_Of (T : Interfaces.Integer_64) return Interfaces.Integer_64 is (T / Millis_Per_Second);

   ---------------
   -- Millis_Of --
   ---------------

   function Millis_Of (T : Interfaces.Integer_64) return Unsigned_16 is
     (Wrapped_16 (T rem Millis_Per_Second));

   ------------------
   -- Date_To_Time --
   ------------------

   function Date_To_Time (D : Date_Time) return Time is
      Year  : constant Unsigned_32 := Unsigned_32'Mod (Integer (D.Year) - Reference_Year);
      Month : constant Month_Index := Natural (D.Month) - 1;
      Day   : constant Unsigned_32 := Unsigned_32'Mod (Integer (D.Day) - 1);
      U     : Unsigned_32;
   begin
      U := Year / 4 * Cycle_Days + Unsigned_32 (Days (Cycle_Year (Year mod 4), Month)) + Day;
      U := (U * 24 + Unsigned_32 (D.Hours)) * 60 + Unsigned_32 (D.Minutes);
      U := U * 60 + Unsigned_32 (D.Seconds);
      return Make (Interfaces.Integer_64 (U) + Epoch_2000_Offset, D.Millis);
   end Date_To_Time;

   ------------------
   -- Time_To_Date --
   ------------------

   function Time_To_Date (T : Interfaces.Integer_64) return Date_Time is
      Unix  : Interfaces.Integer_64 := T / Millis_Per_Second - Epoch_2000_Offset;
      Years : Interfaces.Integer_64;
      Year  : Cycle_Year := 0;
      Month : Month_Index := 0;
      D     : Date_Time;
   begin
      D.Seconds := Wrapped_8 (Integer (Unix rem 60));
      Unix := Unix / 60;
      D.Minutes := Wrapped_8 (Integer (Unix rem 60));
      Unix := Unix / 60;
      D.Hours := Wrapped_8 (Integer (Unix rem 24));
      Unix := Unix / 24;
      Years := Unix / Cycle_Days * 4;
      Unix := Unix rem Cycle_Days;
      for Y in reverse 1 .. 3 loop
         if Unix >= Interfaces.Integer_64 (Days (Y, 0)) then
            Year := Y;
            exit;
         end if;
      end loop;
      for M in reverse 1 .. 11 loop
         if Unix >= Interfaces.Integer_64 (Days (Year, M)) then
            Month := M;
            exit;
         end if;
      end loop;
      D.Year := Wrapped_16 (Years + Interfaces.Integer_64 (Year) + Reference_Year);
      D.Month := Unsigned_8 (Month + 1);
      D.Day := Wrapped_8 (Integer (Unix) - Integer (Days (Year, Month)) + 1);
      D.Millis := Millis_Of (T);
      return D;
   end Time_To_Date;

   -----------------
   -- With_Offset --
   -----------------

   function With_Offset (D : Date_Time; Minutes : Zone_Minutes) return Date_Time is
      T : constant Time := Date_To_Time (D);
   begin
      return Time_To_Date (T + Interfaces.Integer_64 (Minutes) * 60 * Millis_Per_Second);
   end With_Offset;

   ------------
   -- Format --
   ------------

   function Digit_Count (V : Natural) return Positive is
     (if V < 10 then 1 elsif V < 100 then 2 elsif V < 1_000 then 3 elsif V < 10_000 then 4 elsif V < 100_000 then 5
      else 6)
     with Pre => V < 1_000_000;

   --  A number in at least Width characters, padded with zeros on the
   --  left, as the reference's printf writes it.
   procedure Put_Number (Text : in out Formatted; Pos : in out Positive; Value : Natural; Width : Positive)
     with Pre  => Value <= 65_535 and then Width <= 4 and then Pos <= Text_Length
                  and then Pos + Integer'Max (Width, Digit_Count (Value)) - 1 <= Text_Length,
          Post => Pos = Pos'Old + Integer'Max (Width, Digit_Count (Value))
   is
      Count : constant Positive := Integer'Max (Width, Digit_Count (Value));
      V     : Natural := Value;
   begin
      for I in reverse 0 .. Count - 1 loop
         Text (Pos + I) := Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
      end loop;
      Pos := Pos + Count;
   end Put_Number;

   procedure Put_Char (Text : in out Formatted; Pos : in out Positive; C : Character)
     with Pre => Pos <= Text_Length, Post => Pos = Pos'Old + 1
   is
   begin
      Text (Pos) := C;
      Pos := Pos + 1;
   end Put_Char;

   procedure Format (D : Date_Time; Zone : Zone_Minutes; Short : Boolean; Text : out Formatted;
                     Length : out Natural; Valid : out Boolean) is
      Shown      : Date_Time := D;
      Tz_Hours   : Integer range -13 .. 13 := 0;
      Tz_Minutes : Natural range 0 .. 59 := 0;
      Pos        : Positive := 1;
   begin
      Text := (others => ' ');
      Valid := True;
      if Zone /= 0 then
         Tz_Hours := Integer (Zone) / 60;
         Tz_Minutes := abs (Integer (Zone) rem 60);
         if D.Month in 1 .. 12 then
            Shown := With_Offset (D, Zone);
         end if;
      end if;
      if not Is_Valid (Shown) then
         Shown := Default_Date;
         Valid := False;
      end if;
      Put_Number (Text, Pos, Natural (Shown.Year), 4);
      Put_Char (Text, Pos, '-');
      Put_Number (Text, Pos, Natural (Shown.Month), 2);
      Put_Char (Text, Pos, '-');
      Put_Number (Text, Pos, Natural (Shown.Day), 2);
      Put_Char (Text, Pos, (if Short then ' ' else 'T'));
      Put_Number (Text, Pos, Natural (Shown.Hours), 2);
      Put_Char (Text, Pos, ':');
      Put_Number (Text, Pos, Natural (Shown.Minutes), 2);
      Put_Char (Text, Pos, ':');
      Put_Number (Text, Pos, Natural (Shown.Seconds), 2);
      if not Short then
         Put_Char (Text, Pos, '.');
         Put_Number (Text, Pos, Natural (Shown.Millis), 3);
         Put_Char (Text, Pos, (if Tz_Hours >= 0 then '+' else '-'));
         Put_Number (Text, Pos, abs Tz_Hours, 2);
         Put_Char (Text, Pos, ':');
         Put_Number (Text, Pos, Tz_Minutes, 2);
      end if;
      Length := Pos - 1;
   end Format;

   ----------------
   -- Format_UTC --
   ----------------

   procedure Format_UTC (D : Date_Time; Text : out Formatted; Length : out Natural; Valid : out Boolean) is
   begin
      Format (D, 0, False, Text, Length, Valid);
   end Format_UTC;

   ------------------
   -- Format_Local --
   ------------------

   procedure Format_Local (D : Date_Time; C : Settings; Text : out Formatted; Length : out Natural;
                           Valid : out Boolean) is
   begin
      Format (D, (if Is_Valid (D) then C.Zone else 0), False, Text, Length, Valid);
   end Format_Local;

   ------------------------
   -- Format_Local_Short --
   ------------------------

   procedure Format_Local_Short (D : Date_Time; C : Settings; Text : out Formatted; Length : out Natural;
                                 Valid : out Boolean) is
   begin
      Format (D, C.Zone, True, Text, Length, Valid);
   end Format_Local_Short;

   ------------------
   -- UTC_To_Local --
   ------------------

   function UTC_To_Local (D : Date_Time; C : Settings) return Date_Time is (With_Offset (D, C.Zone));

   -----------
   -- Split --
   -----------

   procedure Split (Text : String; Position : out Natural; Found : out Boolean) is
   begin
      Position := 0;
      Found := False;
      for I in Text'Range loop
         if Text (I) = 'T' then
            Position := I;
            Found := True;
            return;
         end if;
      end loop;
   end Split;

   ---------
   -- Set --
   ---------

   procedure Set (C : out Clock; T : Time; Now_Ms : Unsigned_32) is
   begin
      C.Started := T - Interfaces.Integer_64 (Now_Ms);
      C.Is_Set := True;
   end Set;

   -------------------
   -- Get_Date_Time --
   -------------------

   procedure Get_Date_Time (C : Clock; Now_Ms : Unsigned_32; D : out Date_Time; OK : out Boolean) is
   begin
      if Has_Time (C) then
         D := Time_To_Date (Get (C, Now_Ms));
         OK := True;
      else
         D := Default_Date;
         OK := False;
      end if;
   end Get_Date_Time;

   -------------------
   -- Set_Date_Time --
   -------------------

   procedure Set_Date_Time (C : out Clock; D : Date_Time; Now_Ms : Unsigned_32) is
   begin
      Set (C, Date_To_Time (D), Now_Ms);
   end Set_Date_Time;

   -------------------
   -- Persist_Write --
   -------------------

   procedure Persist_Write (C : Clock; Now_Ms : Unsigned_32; Minutes : Zone_Minutes; High, Low : out Unsigned_32) is
      use type Interfaces.Unsigned_64;
      W : Interfaces.Unsigned_64;
   begin
      if Has_Time (C) then
         W := Interfaces.Unsigned_64'Mod
           (Get (C, Now_Ms) + Interfaces.Integer_64 (Minutes) * 60 * Millis_Per_Second);
         High := Unsigned_32 (W / 2 ** 32);
         Low := Unsigned_32 (W mod 2 ** 32);
      else
         High := 0;
         Low := 0;
      end if;
   end Persist_Write;

   ------------------
   -- Persist_Read --
   ------------------

   procedure Persist_Read (High, Low : Unsigned_32; T : out Time; OK : out Boolean) is
      use type Interfaces.Unsigned_64;
      W : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (High) * 2 ** 32 + Interfaces.Unsigned_64 (Low);
      V : constant Interfaces.Integer_64 :=
        (if W >= 2 ** 63 then Interfaces.Integer_64 (W - 2 ** 63) - Interfaces.Integer_64'Last - 1
         else Interfaces.Integer_64 (W));
   begin
      T := 0;
      OK := False;
      if (High /= 0 or else Low /= 0) and then V in Time then
         T := V;
         OK := True;
      end if;
   end Persist_Read;

end Adaflight.RTC;
