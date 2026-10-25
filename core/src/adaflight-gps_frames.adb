with Adaflight.GPS_Conversion;
with Adaflight.Maths;

package body Adaflight.GPS_Frames with SPARK_Mode is
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_64;

   subtype Unsigned_64 is Interfaces.Unsigned_64;
   subtype Integer_64 is Interfaces.Integer_64;

   Dollar     : constant Unsigned_8 := Character'Pos ('$');
   Comma      : constant Unsigned_8 := Character'Pos (',');
   Star       : constant Unsigned_8 := Character'Pos ('*');
   CR         : constant Unsigned_8 := 13;
   LF         : constant Unsigned_8 := 10;
   Zero       : constant Unsigned_8 := Character'Pos ('0');
   Nine       : constant Unsigned_8 := Character'Pos ('9');
   Upper_A    : constant Unsigned_8 := Character'Pos ('A');
   Lower_A    : constant Unsigned_8 := Character'Pos ('a');
   Preamble_1 : constant Unsigned_8 := 16#B5#;
   Preamble_2 : constant Unsigned_8 := 16#62#;

   Week_Ms          : constant Unsigned_32 := 7 * 24 * 3600 * 1000;
   GPS_Epoch_Offset : constant Integer_64 := 315_964_800;
   Leap_Seconds     : constant Integer_64 := 18;

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function To_Unsigned (I : Integer_32) return Unsigned_32 is
     (if I < 0 then not Unsigned_32 (-(I + 1)) else Unsigned_32 (I));

   function To_Signed_16 (W : Unsigned_16) return Integer_16 is
     (if W >= 2 ** 15 then -Integer_16 (not W) - 1 else Integer_16 (W));

   --  The low sixteen bits of a wider value, as the narrowing conversions take them.
   function Wrap_16 (X : Integer_32) return Integer_16 is (To_Signed_16 (Unsigned_16'Mod (X)));

   function Negate (X : Integer_32) return Integer_32 is (To_Signed (0 - To_Unsigned (X)));

   function U16 (P : Payload_Bytes; Off : Payload_Index) return Unsigned_16 is
     (Unsigned_16 (P (Off)) or Interfaces.Shift_Left (Unsigned_16 (P (Off + 1)), 8))
     with Pre => Off <= Payload_Index'Last - 1;

   function U32 (P : Payload_Bytes; Off : Payload_Index) return Unsigned_32 is
     (Unsigned_32 (P (Off))
      or Interfaces.Shift_Left (Unsigned_32 (P (Off + 1)), 8)
      or Interfaces.Shift_Left (Unsigned_32 (P (Off + 2)), 16)
      or Interfaces.Shift_Left (Unsigned_32 (P (Off + 3)), 24))
     with Pre => Off <= Payload_Index'Last - 3;

   function I32 (P : Payload_Bytes; Off : Payload_Index) return Integer_32 is (To_Signed (U32 (P, Off)))
     with Pre => Off <= Payload_Index'Last - 3;

   function I16 (P : Payload_Bytes; Off : Payload_Index) return Integer_16 is (To_Signed_16 (U16 (P, Off)))
     with Pre => Off <= Payload_Index'Last - 1;

   procedure Set_Fix (R : in out Receiver; On : Boolean) is
   begin
      if On then
         R.Fix := True;
         R.Fix_Ever := True;
      else
         R.Fix := False;
      end if;
   end Set_Fix;

   --  The interval since the previous solution, through the wrap of the week.
   procedure Nav_Interval (R : in out Receiver) is
      Delta_Ms : constant Unsigned_32 := (Week_Ms + R.Sol.Time - R.Last_Nav_Time) mod Week_Ms;
   begin
      R.Last_Nav_Time := R.Sol.Time;
      R.Sol.Nav_Interval_Ms := Unsigned_32'Max (50, Unsigned_32'Min (2500, Delta_Ms));
   end Nav_Interval;

   procedure Clock_From_Solution (R : Receiver; Clock_Has_Time : Boolean; Clock : in out Clock_Request) is
   begin
      if not Clock_Has_Time and then R.Sol.Utc.Valid then
         Clock := (Set     => True,
                   Year    => R.Sol.Utc.Year,
                   Month   => R.Sol.Utc.Month,
                   Day     => R.Sol.Utc.Day,
                   Hours   => R.Sol.Utc.Hour,
                   Minutes => R.Sol.Utc.Minute,
                   Seconds => R.Sol.Utc.Second,
                   Millis  => R.Sol.Utc.Millis);
      end if;
   end Clock_From_Solution;

   -------------------
   -- Date and time --
   -------------------

   type Month_Table is array (0 .. 11) of Integer_64;
   Month_Days      : constant Month_Table := (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334);
   Leap_Month_Days : constant Month_Table := (0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335);

   function Is_Leap (Y : Integer_64) return Boolean is
     (Y mod 4 = 0 and then (Y mod 100 /= 0 or else Y mod 400 = 0))
     with Pre => Y >= 0;

   function Leap_Year (Y : Unsigned_16) return Boolean is
     (Y mod 4 = 0 and then (Y mod 100 /= 0 or else Y mod 400 = 0));

   Max_Unix : constant Integer_64 := 2 ** 36;

   --  Seconds since 1970 to the calendar: the remainders give the second,
   --  minute and hour, the years count up from 1970 and the month comes from
   --  the day table.
   procedure Unix_To_Date_Time (DT : in out Date_Time; Unix : Integer_64; Millis : Unsigned_16)
     with Pre => Unix in -Max_Unix .. Max_Unix
   is
      S     : Integer_64 := Unix;
      Days  : Integer_64;
      Year  : Integer_64 := 1970;
      Month : Natural range 0 .. 11 := 0;
      Leap  : Boolean;
   begin
      DT.Second := Unsigned_8'Mod (S rem 60);
      S := S / 60;
      DT.Minute := Unsigned_8'Mod (S rem 60);
      S := S / 60;
      DT.Hour := Unsigned_8'Mod (S rem 24);
      Days := S / 24;
      for K in 1 .. 2500 loop
         pragma Loop_Invariant (Year = 1970 + Integer_64 (K) - 1);
         pragma Loop_Invariant (Days <= Max_Unix / 86_400);
         declare
            In_Year : constant Integer_64 := (if Is_Leap (Year) then 366 else 365);
         begin
            exit when Days < In_Year;
            Days := Days - In_Year;
            Year := Year + 1;
         end;
      end loop;
      Leap := Is_Leap (Year);
      for M in reverse 1 .. 11 loop
         if Days >= (if Leap then Leap_Month_Days (M) else Month_Days (M)) then
            Month := M;
            exit;
         end if;
      end loop;
      DT.Year := Unsigned_16 (Year);
      DT.Month := Unsigned_8 (Month + 1);
      DT.Day := Unsigned_8'Mod (Days - (if Leap then Leap_Month_Days (Month) else Month_Days (Month)) + 1);
      DT.Millis := Millis;
   end Unix_To_Date_Time;

   --  A week number and time of week to the calendar, one carry or borrow
   --  from the nanosecond part, then the offset of the GPS epoch and the
   --  leap seconds.
   procedure Week_Time_To_Date_Time (DT : in out Date_Time; Week : Integer_16; Tow_Ms : Unsigned_32;
                                     Tow_Ns : Integer_32) is
      Seconds : Integer_64 := Integer_64 (Week) * 604_800 + Integer_64 (Tow_Ms / 1000);
      Millis  : Integer_32 := Integer_32 (Tow_Ms mod 1000) + Tow_Ns / 1_000_000;
   begin
      if Millis < 0 then
         Millis := Millis + 1000;
         Seconds := Seconds - 1;
      elsif Millis >= 1000 then
         Millis := Millis - 1000;
         Seconds := Seconds + 1;
      end if;
      Unix_To_Date_Time (DT, Seconds + GPS_Epoch_Offset - Leap_Seconds, Unsigned_16'Mod (Millis));
   end Week_Time_To_Date_Time;

   Days_Table : constant array (1 .. 12) of Unsigned_8 := (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

   --  A month outside the calendar reads outside the table in the reference
   --  (finding F57); the port takes thirty-one days for it.
   function Days_In_Month (Year : Unsigned_16; Month : Unsigned_8) return Unsigned_8 is
     (if Month = 2 and then Leap_Year (Year) then 29
      elsif Month in 1 .. 12 then Days_Table (Natural (Month))
      else 31);

   procedure Add_One_Second (DT : in out Date_Time) is
   begin
      DT.Second := DT.Second + 1;
      if DT.Second <= 59 then
         return;
      end if;
      DT.Second := 0;
      DT.Minute := DT.Minute + 1;
      if DT.Minute <= 59 then
         return;
      end if;
      DT.Minute := 0;
      DT.Hour := DT.Hour + 1;
      if DT.Hour <= 23 then
         return;
      end if;
      DT.Hour := 0;
      DT.Day := DT.Day + 1;
      if DT.Day <= Days_In_Month (DT.Year, DT.Month) then
         return;
      end if;
      DT.Day := 1;
      DT.Month := DT.Month + 1;
      if DT.Month <= 12 then
         return;
      end if;
      DT.Month := 1;
      DT.Year := DT.Year + 1;
   end Add_One_Second;

   procedure Subtract_One_Second (DT : in out Date_Time) is
   begin
      if DT.Second > 0 then
         DT.Second := DT.Second - 1;
         return;
      end if;
      DT.Second := 59;
      if DT.Minute > 0 then
         DT.Minute := DT.Minute - 1;
         return;
      end if;
      DT.Minute := 59;
      if DT.Hour > 0 then
         DT.Hour := DT.Hour - 1;
         return;
      end if;
      DT.Hour := 23;
      if DT.Day > 1 then
         DT.Day := DT.Day - 1;
         return;
      end if;
      if DT.Month > 1 then
         DT.Month := DT.Month - 1;
      else
         DT.Month := 12;
         DT.Year := DT.Year - 1;
      end if;
      DT.Day := Days_In_Month (DT.Year, DT.Month);
   end Subtract_One_Second;

   --  The calendar fields of a NAV-PVT with the nanosecond correction, one
   --  second either way at most.
   procedure Date_Time_From_PVT (DT : in out Date_Time; P : Payload_Bytes) is
      Nano_Ms : constant Integer_32 := I32 (P, 16) / 1_000_000;
   begin
      DT.Valid := (P (11) and 1) /= 0 and then (P (11) and 2) /= 0;
      if not DT.Valid then
         return;
      end if;
      DT.Year := U16 (P, 4);
      DT.Month := P (6);
      DT.Day := P (7);
      DT.Hour := P (8);
      DT.Minute := P (9);
      DT.Second := P (10);
      if Nano_Ms < 0 then
         DT.Millis := Unsigned_16'Mod (Nano_Ms + 1000);
         Subtract_One_Second (DT);
      elsif Nano_Ms >= 1000 then
         DT.Millis := Unsigned_16 (Nano_Ms - 1000);
         Add_One_Second (DT);
      else
         DT.Millis := Unsigned_16 (Nano_Ms);
      end if;
   end Date_Time_From_PVT;

   ----------
   -- NMEA --
   ----------

   --  A decimal field to a number, with Mult digits after the point kept
   --  and the field cut there; zero for a run past fifteen characters.
   --  The cut is dropped where it would fall outside the buffer, which the
   --  reference writes past (finding F55).
   procedure Grab_Fields (F : in out Field_Bytes; Mult : Natural; Value : out Unsigned_32)
     with Pre => Mult <= 2
   is
      I   : Natural := 0;
      Tmp : Unsigned_32 := 0;
      Neg : Boolean := False;
   begin
      while I <= Field_Index'Last and then F (I) /= 0 loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (I <= Field_Index'Last);
         if I = 0 and then F (0) = Character'Pos ('-') then
            Neg := True;
         else
            if F (I) = Character'Pos ('.') then
               I := I + 1;
               if Mult = 0 then
                  exit;
               end if;
               if I + Mult <= Field_Index'Last then
                  F (I + Mult) := 0;
               end if;
            end if;
            Tmp := Tmp * 10;
            if F (I) in Zero .. Nine then
               Tmp := Tmp + Unsigned_32 (F (I) - Zero);
            end if;
            if I >= 15 then
               Value := 0;
               return;
            end if;
         end if;
         I := I + 1;
      end loop;
      Value := (if Neg then 0 - Tmp else Tmp);
   end Grab_Fields;

   function Field_Length (F : Field_Bytes) return Field_Index is
   begin
      for K in Field_Index loop
         if F (K) = 0 then
            return K;
         end if;
      end loop;
      return Field_Index'Last;
   end Field_Length;

   function Coordinate (F : Field_Bytes) return Unsigned_32 is
      N : constant Field_Index := Field_Length (F);
      S : String (1 .. Field_Index'Last) := (others => ' ');
   begin
      for K in 1 .. N loop
         S (K) := Character'Val (F (K - 1));
      end loop;
      return Adaflight.GPS_Conversion.Coordinate_To_Degrees (S (1 .. N));
   end Coordinate;

   function Hex_Value (B : Unsigned_8) return Integer is
     (if B >= Upper_A then Integer (B) - Integer (Upper_A) + 10 else Integer (B) - Integer (Zero));

   --  One field of the sentence in progress, by its position. A GSV
   --  satellite number of zero indexes before the list in the reference
   --  (finding F56); the port skips it.
   procedure Parse_Field (R : in out Receiver; Idx : Unsigned_8) is
      V : Unsigned_32;
   begin
      case R.NMEA.Frame is
         when GGA =>
            case Idx is
               when 1 =>
                  R.NMEA.Values.Time := Unsigned_32
                    ((Integer (R.NMEA.Field (5) - Zero) * 10 + Integer (R.NMEA.Field (7) - Zero)) * 100);
               when 2 =>
                  R.NMEA.Values.Latitude := To_Signed (Coordinate (R.NMEA.Field));
               when 3 =>
                  if R.NMEA.Field (0) = Character'Pos ('S') then
                     R.NMEA.Values.Latitude := Negate (R.NMEA.Values.Latitude);
                  end if;
               when 4 =>
                  R.NMEA.Values.Longitude := To_Signed (Coordinate (R.NMEA.Field));
               when 5 =>
                  if R.NMEA.Field (0) = Character'Pos ('W') then
                     R.NMEA.Values.Longitude := Negate (R.NMEA.Values.Longitude);
                  end if;
               when 6 =>
                  R.NMEA.Values.Fix := R.NMEA.Field (0) > Zero;
               when 7 =>
                  Grab_Fields (R.NMEA.Field, 0, V);
                  R.NMEA.Values.Num_Sat := Unsigned_8'Mod (V);
               when 9 =>
                  Grab_Fields (R.NMEA.Field, 1, V);
                  R.NMEA.Values.Altitude_Cm := To_Signed (V * 10);
               when others =>
                  null;
            end case;
         when RMC =>
            case Idx is
               when 1 =>
                  Grab_Fields (R.NMEA.Field, 2, V);
                  R.NMEA.Values.Time := V;
               when 7 =>
                  Grab_Fields (R.NMEA.Field, 1, V);
                  R.NMEA.Values.Speed := Unsigned_16'Mod ((V * 5144) / 1000);
               when 8 =>
                  Grab_Fields (R.NMEA.Field, 1, V);
                  R.NMEA.Values.Ground_Course := Unsigned_16'Mod (V);
               when 9 =>
                  Grab_Fields (R.NMEA.Field, 0, V);
                  R.NMEA.Values.Date := V;
               when others =>
                  null;
            end case;
         when GSV =>
            case Idx is
               when 2 =>
                  Grab_Fields (R.NMEA.Field, 0, V);
                  R.NMEA.Sv_Message := Unsigned_8'Mod (V);
               when 3 =>
                  Grab_Fields (R.NMEA.Field, 0, V);
                  R.Num_Channels := Unsigned_8 (Unsigned_32'Min (V, Legacy_Satellites));
               when others =>
                  null;
            end case;
            if Idx >= 4 then
               declare
                  Packet  : constant Natural := (Natural (Idx) - 4) / 4 + 1;
                  Sat_Num : constant Unsigned_8 :=
                    Unsigned_8'Mod (Packet + 4 * (Integer (R.NMEA.Sv_Message) - 1));
                  Param   : constant Natural := Natural (Idx) - 3 - 4 * (Packet - 1);
               begin
                  if Sat_Num in 1 .. Legacy_Satellites then
                     case Param is
                        when 1 =>
                           R.Sats (Natural (Sat_Num) - 1).Channel := Sat_Num;
                           Grab_Fields (R.NMEA.Field, 0, V);
                           R.Sats (Natural (Sat_Num) - 1).Id := Unsigned_8'Mod (V);
                        when 4 =>
                           Grab_Fields (R.NMEA.Field, 0, V);
                           R.Sats (Natural (Sat_Num) - 1).Cno := Unsigned_8'Mod (V);
                           R.Sats (Natural (Sat_Num) - 1).Quality := 0;
                        when others =>
                           null;
                     end case;
                  end if;
               end;
            end if;
         when GSA =>
            case Idx is
               when 15 =>
                  Grab_Fields (R.NMEA.Field, 2, V);
                  R.NMEA.Values.Pdop := Unsigned_16'Mod (V);
               when 16 =>
                  Grab_Fields (R.NMEA.Field, 2, V);
                  R.NMEA.Values.Hdop := Unsigned_16'Mod (V);
               when 17 =>
                  Grab_Fields (R.NMEA.Field, 2, V);
                  R.NMEA.Values.Vdop := Unsigned_16'Mod (V);
               when others =>
                  null;
            end case;
         when No_Frame =>
            null;
      end case;
   end Parse_Field;

   --  The values of a sentence that passed its parity into the solution. A
   --  GGA sentence places the position under a fix and times the solution;
   --  an RMC sentence asks for the clock while it has no time, with the
   --  millisecond field from the time's hundredths.
   procedure Write_Solution (R : in out Receiver; Clock_Has_Time : Boolean; New_Solution : out Boolean;
                             Clock : in out Clock_Request) is
      Ten_Seconds : constant Unsigned_32 := 10_000;
   begin
      New_Solution := False;
      case R.NMEA.Frame is
         when GGA =>
            Set_Fix (R, R.NMEA.Values.Fix);
            if R.Fix then
               R.Sol.Llh.Lat := R.NMEA.Values.Latitude;
               R.Sol.Llh.Lon := R.NMEA.Values.Longitude;
               R.Sol.Num_Sat := R.NMEA.Values.Num_Sat;
               R.Sol.Llh.Alt_Cm := R.NMEA.Values.Altitude_Cm;
            end if;
            declare
               Delta_Ms : constant Unsigned_32 :=
                 (Ten_Seconds + R.NMEA.Values.Time - R.Last_Nav_Time) mod Ten_Seconds;
            begin
               R.Last_Nav_Time := R.NMEA.Values.Time;
               R.Sol.Nav_Interval_Ms := Unsigned_32'Max (50, Unsigned_32'Min (2500, Delta_Ms));
            end;
            New_Solution := True;
         when GSA =>
            R.Sol.Dop := (Pdop => R.NMEA.Values.Pdop, Hdop => R.NMEA.Values.Hdop, Vdop => R.NMEA.Values.Vdop);
         when RMC =>
            R.Sol.Ground_Speed := R.NMEA.Values.Speed;
            R.Sol.Ground_Course := R.NMEA.Values.Ground_Course;
            if not Clock_Has_Time and then R.NMEA.Values.Date /= 0 and then R.NMEA.Values.Time /= 0 then
               Clock := (Set     => True,
                         Year    => Unsigned_16 (R.NMEA.Values.Date mod 100 + 2000),
                         Month   => Unsigned_8 ((R.NMEA.Values.Date / 100) mod 100),
                         Day     => Unsigned_8 ((R.NMEA.Values.Date / 10_000) mod 100),
                         Hours   => Unsigned_8 ((R.NMEA.Values.Time / 1_000_000) mod 100),
                         Minutes => Unsigned_8 ((R.NMEA.Values.Time / 10_000) mod 100),
                         Seconds => Unsigned_8 ((R.NMEA.Values.Time / 100) mod 100),
                         Millis  => Unsigned_16 ((R.NMEA.Values.Time mod 100) * 10));
            end if;
         when GSV | No_Frame =>
            null;
      end case;
   end Write_Solution;

   ------------------
   -- Receive_NMEA --
   ------------------

   procedure Receive_NMEA (R : in out Receiver; C : Unsigned_8; Clock_Has_Time : Boolean;
                           New_Solution : out Boolean; Clock : out Clock_Request) is
   begin
      New_Solution := False;
      Clock := (others => <>);
      case C is
         when Dollar =>
            R.NMEA.Param := 0;
            R.NMEA.Offset := 0;
            R.NMEA.Parity := 0;
         when Comma | Star =>
            R.NMEA.Field (Natural (R.NMEA.Offset)) := 0;
            if R.NMEA.Param = 0 then
               R.NMEA.Frame := No_Frame;
               if R.NMEA.Field (5) = 0 and then R.NMEA.Field (2) = Character'Pos ('G')
                 and then R.NMEA.Field (3) = Character'Pos ('G') and then R.NMEA.Field (4) = Character'Pos ('A')
               then
                  R.NMEA.Frame := GGA;
               elsif R.NMEA.Field (5) = 0 and then R.NMEA.Field (2) = Character'Pos ('R')
                 and then R.NMEA.Field (3) = Character'Pos ('M') and then R.NMEA.Field (4) = Character'Pos ('C')
               then
                  R.NMEA.Frame := RMC;
               elsif R.NMEA.Field (5) = 0 and then R.NMEA.Field (2) = Character'Pos ('G')
                 and then R.NMEA.Field (3) = Character'Pos ('S') and then R.NMEA.Field (4) = Character'Pos ('V')
               then
                  R.NMEA.Frame := GSV;
               elsif R.NMEA.Field (5) = 0 and then R.NMEA.Field (2) = Character'Pos ('G')
                 and then R.NMEA.Field (3) = Character'Pos ('S') and then R.NMEA.Field (4) = Character'Pos ('A')
               then
                  R.NMEA.Frame := GSA;
               end if;
            end if;
            Parse_Field (R, R.NMEA.Param);
            R.NMEA.Param := R.NMEA.Param + 1;
            R.NMEA.Offset := 0;
            if C = Star then
               R.NMEA.Checksum_Param := True;
            else
               R.NMEA.Parity := R.NMEA.Parity xor C;
            end if;
         when CR | LF =>
            if R.NMEA.Checksum_Param then
               declare
                  Checksum : constant Unsigned_8 :=
                    Unsigned_8'Mod (16 * Hex_Value (R.NMEA.Field (0)) + Hex_Value (R.NMEA.Field (1)));
               begin
                  if Checksum = R.NMEA.Parity then
                     Write_Solution (R, Clock_Has_Time, New_Solution, Clock);
                  end if;
               end;
            end if;
            R.NMEA.Checksum_Param := False;
         when others =>
            if R.NMEA.Offset < 15 then
               R.NMEA.Field (Natural (R.NMEA.Offset)) := C;
               R.NMEA.Offset := R.NMEA.Offset + 1;
            end if;
            if not R.NMEA.Checksum_Param then
               R.NMEA.Parity := R.NMEA.Parity xor C;
            end if;
      end case;
   end Receive_NMEA;

   ---------
   -- UBX --
   ---------

   function Is_Hex (B : Unsigned_8) return Boolean is
     (B in Zero .. Nine or else B in Upper_A .. Upper_A + 5 or else B in Lower_A .. Lower_A + 5);

   function Hex_Digit (B : Unsigned_8) return Unsigned_64 is
     (if B in Zero .. Nine then Unsigned_64 (B - Zero)
      elsif B in Upper_A .. Upper_A + 5 then Unsigned_64 (B - Upper_A) + 10
      else Unsigned_64 (B - Lower_A) + 10)
     with Pre => Is_Hex (B);

   --  The hardware version field read as the C library reads an unsigned
   --  hexadecimal number: blanks, a sign and a 0x prefix allowed, the value
   --  saturated past sixty-four bits, then cut to thirty-two.
   function Hex_Version (P : Payload_Bytes; Start : Payload_Index) return Unsigned_32 is
      I        : Natural := Start;
      Negative : Boolean := False;
      Acc      : Unsigned_64 := 0;
      Overflow : Boolean := False;
   begin
      while I <= Payload_Index'Last and then (P (I) = 32 or else P (I) in 9 .. 13) loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (I in Start .. Payload_Index'Last);
         I := I + 1;
      end loop;
      if I <= Payload_Index'Last and then P (I) = Character'Pos ('+') then
         I := I + 1;
      elsif I <= Payload_Index'Last and then P (I) = Character'Pos ('-') then
         Negative := True;
         I := I + 1;
      end if;
      if I + 2 <= Payload_Index'Last and then P (I) = Zero
        and then (P (I + 1) = Character'Pos ('x') or else P (I + 1) = Character'Pos ('X'))
        and then Is_Hex (P (I + 2))
      then
         I := I + 2;
      end if;
      while I <= Payload_Index'Last and then Is_Hex (P (I)) loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (I in Start .. Payload_Index'Last);
         declare
            D : constant Unsigned_64 := Hex_Digit (P (I));
         begin
            if Acc > (Unsigned_64'Last - D) / 16 then
               Overflow := True;
            else
               Acc := Acc * 16 + D;
            end if;
         end;
         I := I + 1;
      end loop;
      if Overflow then
         return Unsigned_32'Last;
      end if;
      declare
         V : constant Unsigned_32 := Unsigned_32'Mod (Acc);
      begin
         return (if Negative then 0 - V else V);
      end;
   end Hex_Version;

   --  Millimetres per second as the message carries them, their squares and
   --  the speed over ground and down, bounded step by step for the provers.
   subtype Rate_Mm is Float range -2.2E9 .. 2.2E9;
   subtype Rate_Square is Float range 0.0 .. 5.0E18;
   subtype Rate_Sum is Float range 0.0 .. 1.0E19;

   procedure Parse_PVT (R : in out Receiver; Clock_Has_Time : Boolean; Clock : in out Clock_Request) is
      Gs    : constant Rate_Mm := Float (I32 (R.UBX.Payload, 60));
      Vd    : constant Rate_Mm := Float (I32 (R.UBX.Payload, 56));
      Gs2   : constant Rate_Square := Gs * Gs;
      Vd2   : constant Rate_Square := Vd * Vd;
      Sum   : constant Rate_Sum := Gs2 + Vd2;
      Speed : constant Float := Float'Min (Adaflight.Maths.Sqrt_Non_Negative (Sum) * 0.1, 1.0E9);
   begin
      R.UBX.Valid_Fix := (R.UBX.Payload (21) and 1) /= 0 and then R.UBX.Payload (20) = 3;
      R.Sol.Time := U32 (R.UBX.Payload, 0);
      Nav_Interval (R);
      R.Sol.Llh.Lon := I32 (R.UBX.Payload, 24);
      R.Sol.Llh.Lat := I32 (R.UBX.Payload, 28);
      R.Sol.Llh.Alt_Cm := I32 (R.UBX.Payload, 36) / 10;
      Set_Fix (R, R.UBX.Valid_Fix);
      R.UBX.New_Position := True;
      R.Sol.Num_Sat := R.UBX.Payload (23);
      R.Sol.Acc := (Horizontal => U32 (R.UBX.Payload, 40),
                    Vertical   => U32 (R.UBX.Payload, 44),
                    Speed      => U32 (R.UBX.Payload, 68),
                    Heading    => U32 (R.UBX.Payload, 72));
      R.Sol.Speed_3d := Unsigned_16'Mod (Integer_64 (Float'Truncation (Speed)));
      R.Sol.Ground_Speed := Unsigned_16'Mod (I32 (R.UBX.Payload, 60) / 10);
      R.Sol.Ground_Course := Unsigned_16'Mod (I32 (R.UBX.Payload, 64) / 10_000);
      R.Sol.Dop := (Pdop => U16 (R.UBX.Payload, 76),
                    Hdop => U16 (R.UBX.Payload, 76),
                    Vdop => U16 (R.UBX.Payload, 76));
      R.Sol.Velned := (North => Wrap_16 (I32 (R.UBX.Payload, 48) / 10),
                       East  => Wrap_16 (I32 (R.UBX.Payload, 52) / 10),
                       Down  => Wrap_16 (I32 (R.UBX.Payload, 56) / 10));
      R.UBX.New_Speed := True;
      Date_Time_From_PVT (R.Sol.Utc, R.UBX.Payload);
      Clock_From_Solution (R, Clock_Has_Time, Clock);
   end Parse_PVT;

   --  The satellite list from NAV-SAT: up to the maximum kept, the rest
   --  marked unassigned, and the channel count set to the maximum so a
   --  reader knows the list carries constellation ids.
   procedure Parse_Sat (R : in out Receiver) is
      N : constant Unsigned_8 := Unsigned_8'Min (R.UBX.Payload (5), Max_Satellites);
   begin
      for I in Satellite_Index loop
         if Unsigned_8 (I) < N then
            R.Sats (I) := (Channel => R.UBX.Payload (8 + 12 * I),
                           Id      => R.UBX.Payload (9 + 12 * I),
                           Cno     => R.UBX.Payload (10 + 12 * I),
                           Quality => Unsigned_8'Mod (U32 (R.UBX.Payload, 16 + 12 * I)));
         else
            R.Sats (I) := (Channel => 255, others => 0);
         end if;
      end loop;
      R.Num_Channels := Max_Satellites;
   end Parse_Sat;

   --  The satellite list from NAV-SVINFO, up to the legacy count.
   procedure Parse_Svinfo (R : in out Receiver) is
      N : constant Unsigned_8 := Unsigned_8'Min (R.UBX.Payload (4), Legacy_Satellites);
   begin
      for I in Satellite_Index loop
         if Unsigned_8 (I) < N then
            R.Sats (I) := (Channel => R.UBX.Payload (8 + 12 * I),
                           Id      => R.UBX.Payload (9 + 12 * I),
                           Quality => R.UBX.Payload (11 + 12 * I),
                           Cno     => R.UBX.Payload (12 + 12 * I));
         else
            R.Sats (I) := (others => 0);
         end if;
      end loop;
      R.Num_Channels := N;
   end Parse_Svinfo;

   procedure Parse_Version (D : in out UBX_Decoder) is
      V : constant Unsigned_32 := Hex_Version (D.Payload, 30);
   begin
      D.Version := (case V is
                      when 16#0004_0005# => M5,
                      when 16#0004_0007# => M6,
                      when 16#0007_0000# => M7,
                      when 16#0008_0000# => M8,
                      when 16#0019_0000# => M9,
                      when 16#000A_0000# => M10,
                      when others        => Undefined);
      D.M7_Or_Above := D.Version >= M7;
      D.M8_Or_Above := D.Version >= M8;
      D.M9_Or_Above := D.Version >= M9;
   end Parse_Version;

   procedure Parse_Posllh (R : in out Receiver) is
   begin
      R.Sol.Llh.Lon := I32 (R.UBX.Payload, 4);
      R.Sol.Llh.Lat := I32 (R.UBX.Payload, 8);
      R.Sol.Llh.Alt_Cm := I32 (R.UBX.Payload, 16) / 10;
      R.Sol.Time := U32 (R.UBX.Payload, 0);
      Nav_Interval (R);
      Set_Fix (R, R.UBX.Valid_Fix);
      R.UBX.New_Position := True;
   end Parse_Posllh;

   procedure Parse_Sol (R : in out Receiver; Clock_Has_Time : Boolean; Clock : in out Clock_Request) is
      Status : constant Unsigned_8 := R.UBX.Payload (11);
   begin
      R.UBX.Valid_Fix := (Status and 1) /= 0 and then R.UBX.Payload (10) = 3;
      if not R.UBX.Valid_Fix then
         R.Fix := False;
      end if;
      R.Sol.Num_Sat := R.UBX.Payload (47);
      R.Sol.Utc.Valid := (Status and 8) /= 0 and then (Status and 4) /= 0;
      if R.Sol.Utc.Valid then
         Week_Time_To_Date_Time (R.Sol.Utc, I16 (R.UBX.Payload, 8), U32 (R.UBX.Payload, 0),
                                 I32 (R.UBX.Payload, 4));
      end if;
      Clock_From_Solution (R, Clock_Has_Time, Clock);
   end Parse_Sol;

   procedure Parse_Velned (R : in out Receiver; Clock_Has_Time : Boolean; Clock : in out Clock_Request) is
   begin
      R.Sol.Speed_3d := Unsigned_16'Mod (U32 (R.UBX.Payload, 16));
      R.Sol.Ground_Speed := Unsigned_16'Mod (U32 (R.UBX.Payload, 20));
      R.Sol.Ground_Course := Unsigned_16'Mod (I32 (R.UBX.Payload, 24) / 10_000);
      R.Sol.Velned := (North => Wrap_16 (I32 (R.UBX.Payload, 4)),
                       East  => Wrap_16 (I32 (R.UBX.Payload, 8)),
                       Down  => Wrap_16 (I32 (R.UBX.Payload, 12)));
      R.UBX.New_Speed := True;
      Clock_From_Solution (R, Clock_Has_Time, Clock);
   end Parse_Velned;

   --  A complete message by class and id. The GNSS configuration reply
   --  raises its flag for the link, which answers it. New_Solution needs a
   --  new position and a new speed together.
   procedure Parse_Message (R : in out Receiver; Clock_Has_Time : Boolean; New_Solution : out Boolean;
                            Clock : in out Clock_Request) is
      Known : Boolean := True;
   begin
      New_Solution := False;
      case R.UBX.Class is
         when 16#01# =>
            case R.UBX.Id is
               when 16#07# =>
                  Parse_PVT (R, Clock_Has_Time, Clock);
               when 16#35# =>
                  Parse_Sat (R);
               when 16#02# =>
                  Parse_Posllh (R);
               when 16#03# =>
                  R.UBX.Valid_Fix := (R.UBX.Payload (5) and 1) /= 0 and then R.UBX.Payload (4) = 3;
                  if not R.UBX.Valid_Fix then
                     R.Fix := False;
                  end if;
               when 16#04# =>
                  R.Sol.Dop := (Pdop => U16 (R.UBX.Payload, 6),
                                Hdop => U16 (R.UBX.Payload, 12),
                                Vdop => U16 (R.UBX.Payload, 10));
               when 16#06# =>
                  Parse_Sol (R, Clock_Has_Time, Clock);
               when 16#12# =>
                  Parse_Velned (R, Clock_Has_Time, Clock);
               when 16#30# =>
                  Parse_Svinfo (R);
               when others =>
                  Known := False;
            end case;
         when 16#05# =>
            case R.UBX.Id is
               when 16#01# =>
                  if R.UBX.Ack = Waiting and then R.UBX.Payload (1) = R.UBX.Ack_Message then
                     R.UBX.Ack := Got_Ack;
                  end if;
               when 16#00# =>
                  if R.UBX.Ack = Waiting and then R.UBX.Payload (1) = R.UBX.Ack_Message then
                     R.UBX.Ack := Got_Nack;
                  end if;
               when others =>
                  Known := False;
            end case;
         when 16#06# =>
            if R.UBX.Id = 16#3E# then
               R.UBX.Gnss_Reply := True;
            else
               Known := False;
            end if;
         when 16#0A# =>
            if R.UBX.Id = 16#04# then
               Parse_Version (R.UBX);
            else
               Known := False;
            end if;
         when others =>
            Known := False;
      end case;
      if Known and then R.UBX.New_Position and then R.UBX.New_Speed then
         R.UBX.New_Position := False;
         R.UBX.New_Speed := False;
         New_Solution := True;
      end if;
   end Parse_Message;

   -----------------
   -- Receive_UBX --
   -----------------

   procedure Receive_UBX (R : in out Receiver; C : Unsigned_8; Clock_Has_Time : Boolean;
                          New_Solution : out Boolean; Clock : out Clock_Request) is
   begin
      New_Solution := False;
      Clock := (others => <>);
      R.UBX.Almost_Done := False;
      if R.UBX.Phase = Payload_Content then
         R.UBX.Ck_A := R.UBX.Ck_A + C;
         R.UBX.Ck_B := R.UBX.Ck_B + R.UBX.Ck_A;
         if R.UBX.Counter < Payload_Size then
            R.UBX.Payload (Natural (R.UBX.Counter)) := C;
         end if;
         R.UBX.Counter := R.UBX.Counter + 1;
         if R.UBX.Counter >= R.UBX.Length then
            R.UBX.Phase := Checksum_A;
         end if;
         return;
      end if;
      case R.UBX.Phase is
         when Sync_1 =>
            if C = Preamble_1 then
               R.UBX.Phase := Sync_2;
            end if;
         when Sync_2 =>
            if C = Preamble_2 then
               R.UBX.Phase := Message_Class;
            elsif C /= Preamble_1 then
               R.UBX.Phase := Sync_1;
            end if;
         when Message_Class =>
            R.UBX.Ck_A := C;
            R.UBX.Ck_B := C;
            R.UBX.Class := C;
            R.UBX.Phase := Message_Id;
         when Message_Id =>
            R.UBX.Ck_A := R.UBX.Ck_A + C;
            R.UBX.Ck_B := R.UBX.Ck_B + R.UBX.Ck_A;
            R.UBX.Id := C;
            R.UBX.Phase := Length_Low;
         when Length_Low =>
            R.UBX.Ck_A := R.UBX.Ck_A + C;
            R.UBX.Ck_B := R.UBX.Ck_B + R.UBX.Ck_A;
            R.UBX.Length := Unsigned_16 (C);
            R.UBX.Phase := Length_High;
         when Length_High =>
            R.UBX.Ck_A := R.UBX.Ck_A + C;
            R.UBX.Ck_B := R.UBX.Ck_B + R.UBX.Ck_A;
            R.UBX.Length := R.UBX.Length + Interfaces.Shift_Left (Unsigned_16 (C), 8);
            if R.UBX.Length = 0 then
               R.UBX.Phase := Checksum_A;
            elsif R.UBX.Length > Max_Sane_Length then
               R.UBX.Phase := (if C = Preamble_1 then Sync_2 else Sync_1);
            else
               R.UBX.Counter := 0;
               R.UBX.Phase := Payload_Content;
            end if;
         when Payload_Content =>
            null;
         when Checksum_A =>
            if R.UBX.Ck_A = C then
               R.UBX.Phase := Checksum_B;
               R.UBX.Almost_Done := True;
            else
               R.UBX.Phase := (if C = Preamble_1 then Sync_2 else Sync_1);
            end if;
         when Checksum_B =>
            if R.UBX.Ck_B = C then
               Parse_Message (R, Clock_Has_Time, New_Solution, Clock);
               R.UBX.Phase := Sync_1;
            else
               R.UBX.Phase := (if C = Preamble_1 then Sync_2 else Sync_1);
            end if;
      end case;
   end Receive_UBX;

end Adaflight.GPS_Frames;
