with Adaflight.Maths;
with Adaflight.Plus_Codes;
with Adaflight.Text;

package body Adaflight.OSD_Format with SPARK_Mode is
   use type Interfaces.Integer_64;
   subtype Integer_64 is Interfaces.Integer_64;

   procedure Append (T : in out Text; C : Character) is
   begin
      if T.Length < Max_Length then
         T.Length := T.Length + 1;
         T.Data (T.Length) := C;
      end if;
   end Append;

   procedure Append_String (T : in out Text; S : String) is
   begin
      for K in S'Range loop
         pragma Loop_Invariant (T.Length = Natural'Min (Max_Length, T.Length'Loop_Entry + (K - S'First)));
         Append (T, S (K));
      end loop;
   end Append_String;

   --  The text padded on the left to Width with zeros or spaces, then the
   --  digits, as the reference's printf pads a field.
   procedure Append_Padded (T : in out Text; Image : String; Width : Natural; Zero_Pad : Boolean)
     with Pre => Width <= 9 and then Image'Length <= Max_Length
   is
   begin
      for I in Image'Length + 1 .. Width loop
         Append (T, (if Zero_Pad then '0' else ' '));
      end loop;
      Append_String (T, Image);
   end Append_Padded;

   procedure Append_Natural (T : in out Text; N : Natural; Width : Natural; Zero_Pad : Boolean) is
      Buffer : String (1 .. Adaflight.Text.Max_Decimal_Length) := (others => ' ');
      Length : Natural;
   begin
      Adaflight.Text.Put_Integer (Integer_32 (N), Buffer, Length);
      Append_Padded (T, Buffer (1 .. Length), Width, Zero_Pad);
   end Append_Natural;

   procedure Append_Integer (T : in out Text; V : Integer_32; Width : Natural; Zero_Pad : Boolean) is
      Buffer : String (1 .. Adaflight.Text.Max_Decimal_Length) := (others => ' ');
      Length : Natural;
   begin
      Adaflight.Text.Put_Integer (V, Buffer, Length);
      Append_Padded (T, Buffer (1 .. Length), Width, Zero_Pad);
   end Append_Integer;

   procedure Print_Float (T : out Text; Leading : Character; Value : Float; Format : Number_Format; D : Decimals;
                          Round : Boolean; Trailing : Character) is
      Scaled          : constant Float := Value * Multiplier (D);
      Mult            : constant Positive := (case D is when 0 => 1, when 1 => 10, when 2 => 100, when 3 => 1_000);
      Scaled_Abs      : Natural;
      Integer_Part    : Natural;
      Fractional_Part : Natural;
   begin
      T := (others => <>);
      if Round then
         Scaled_Abs := abs Adaflight.Maths.Round_Half_Even (Scaled);
      else
         Scaled_Abs := abs Integer (Float'Truncation (Scaled));
      end if;
      Integer_Part := Scaled_Abs / Mult;
      Fractional_Part := Scaled_Abs mod Mult;
      if Leading /= Symbol_None then
         Append (T, Leading);
      end if;
      if Scaled < 0.0 and then (Integer_Part /= 0 or else Fractional_Part /= 0) then
         Append (T, '-');
      end if;
      if Format.Has_Lead then
         Append (T, Format.Lead);
      end if;
      Append_Natural (T, Integer_Part, Format.Width, Format.Zero_Pad);
      if D > 0 then
         Append (T, '.');
         Append_Natural (T, Fractional_Part, D, True);
      end if;
      if Trailing /= Symbol_None then
         Append (T, Trailing);
      end if;
   end Print_Float;

   procedure Altitude_String (T : out Text; Altitude_Cm : Integer_32; Variant : Element_Type; Altitude_Asl_Cm : Float;
                              Units : Unit_System) is
      Alt  : constant Integer_32 :=
        (if Variant in Type_3 | Type_4 then Integer_32 (Float'Truncation (Altitude_Asl_Cm)) else Altitude_Cm);
      Decs : constant Decimals := (if Variant in Type_1 | Type_3 then 1 else 0);
   begin
      Print_Float (T, Symbol_Altitude, Meters_To_Unit (Alt, Units) / 100.0, Default_Format, Decs, True,
                   Meters_Symbol (Units));
   end Altitude_String;

   procedure Coordinate (T : out Text; Is_Longitude : Boolean; Variant : Element_Type; Fix_Ever : Boolean;
                         Lat, Lon : Integer_32) is
      Divider      : constant := 10_000_000;
      Value        : constant Integer_32 := (if not Fix_Ever then 0 elsif Is_Longitude then Lon else Lat);
      Degrees_Part : constant Natural := Natural (abs Value / Divider);
      Fraction     : Natural := Natural (abs Value mod Divider);
      Lead         : constant Character := (if Is_Longitude then Symbol_Longitude else Symbol_Latitude);
   begin
      T := (others => <>);
      case Variant is
         when Type_4 =>
            Append (T, Symbol_Sat_Left);
            Append (T, Symbol_Sat_Right);
            if Fix_Ever then
               declare
                  Code  : Adaflight.Plus_Codes.Code_Text;
                  Count : Natural;
               begin
                  Adaflight.Plus_Codes.Encode (Long_Float (Lat) / 1.0e7, Long_Float (Lon) / 1.0e7, 11, Code, Count);
                  Append_String (T, Code (1 .. Count));
               end;
            else
               Append_String (T, "--------+---");
            end if;
         when Type_3 =>
            declare
               Minutes            : constant Natural := Fraction * 60 / Divider;
               Fractional_Minutes : constant Natural := Fraction * 60 mod Divider;
               Seconds            : constant Natural := Fractional_Minutes * 60 / Divider;
               Tenths             : constant Natural := (Fractional_Minutes * 60 mod Divider) * 10 / Divider;
               Trailing           : constant Character :=
                 (if Is_Longitude then (if Value < 0 then 'W' else 'E') else (if Value < 0 then 'S' else 'N'));
            begin
               Append (T, Lead);
               Append_Natural (T, Degrees_Part, 0, False);
               Append (T, Symbol_Degree);
               Append_Natural (T, Minutes, 2, True);
               Append (T, Symbol_Minute);
               Append_Natural (T, Seconds, 2, True);
               Append (T, '.');
               Append_Natural (T, Tenths, 0, False);
               Append (T, Symbol_Second);
               Append (T, Trailing);
            end;
         when Type_1 | Type_2 =>
            if Variant = Type_2 then
               Fraction := Fraction / 1_000;
            end if;
            Append (T, Lead);
            if Value < 0 then
               Append (T, Symbol_Hyphen);
            end if;
            Append_Natural (T, Degrees_Part, 0, False);
            Append (T, '.');
            Append_Natural (T, Fraction, (if Variant = Type_1 then 7 else 4), True);
      end case;
   end Coordinate;

   procedure Distance_String (T : out Text; Distance_M : Integer_32; Leading : Character; Units : Unit_System) is
      Converted  : constant Float := Meters_To_Unit (Distance_M, Units);
      Transition : constant Float := (if Units = Imperial then 5_280.0 else 1_000.0);
      Small      : constant Character := (if Units = Imperial then Symbol_Feet else Symbol_Metres);
      Large      : constant Character := (if Units = Imperial then Symbol_Miles else Symbol_Kilometres);
   begin
      if Converted < Transition then
         Print_Float (T, Leading, Converted, Default_Format, 0, False, Small);
      else
         declare
            Display : constant Float := Converted / Transition;
         begin
            Print_Float (T, Leading, Display, Default_Format, (if Display >= 10.0 then 1 else 2), False, Large);
         end;
      end if;
   end Distance_String;

   procedure PID_Line (T : out Text; Label : String; P, I, D, D_Max : Unsigned_8; F : Unsigned_16) is
      type Values is array (1 .. 5) of Integer_32;
      V : constant Values := (Integer_32 (P), Integer_32 (I), Integer_32 (D), Integer_32 (D_Max), Integer_32 (F));
   begin
      T := (others => <>);
      Append_String (T, Label);
      for K in V'Range loop
         Append (T, ' ');
         Append_Integer (T, V (K), 3, False);
      end loop;
   end PID_Line;

   procedure RTC_Date_Time (T : out Text; Variant : Element_Type; Has_Time : Boolean; Date : Adaflight.RTC.Date_Time;
                            Zone : Adaflight.RTC.Settings; Valid : out Boolean) is
   begin
      T := (others => <>);
      Valid := Has_Time;
      if not Has_Time then
         return;
      end if;
      declare
         Local : constant Adaflight.RTC.Date_Time := Adaflight.RTC.UTC_To_Local (Date, Zone);
      begin
         case Variant is
            when Type_3 =>
               Append_Natural (T, Natural (Local.Hours), 2, True);
               Append (T, ':');
               Append_Natural (T, Natural (Local.Minutes), 2, True);
               Append (T, ':');
               Append_Natural (T, Natural (Local.Seconds), 2, True);
            when Type_2 =>
               Append_Natural (T, Natural (Local.Month), 2, True);
               Append (T, '.');
               Append_Natural (T, Natural (Local.Day), 2, True);
               Append (T, ' ');
               Append_Natural (T, Natural (Local.Hours), 2, True);
               Append (T, ':');
               Append_Natural (T, Natural (Local.Minutes), 2, True);
            when Type_1 | Type_4 =>
               declare
                  Formatted : Adaflight.RTC.Formatted;
                  Length    : Natural;
                  Shown     : Boolean;
               begin
                  Adaflight.RTC.Format_Local_Short (Date, Zone, Formatted, Length, Shown);
                  pragma Unreferenced (Shown);
                  Append_String (T, Formatted (1 .. Length));
               end;
         end case;
      end;
   end RTC_Date_Time;

   procedure Put_Time (T : in out Text; Precision : Timer_Precision; Time_Us : Unsigned_32) is
      Total_Seconds : constant Natural := Natural (Time_Us / 1_000_000);
   begin
      Append_Natural (T, Total_Seconds / 60, 2, True);
      Append (T, ':');
      Append_Natural (T, Total_Seconds mod 60, 2, True);
      case Precision is
         when Precision_Hundredths =>
            Append (T, '.');
            Append_Natural (T, Natural ((Time_Us / 10_000) mod 100), 2, True);
         when Precision_Tenths =>
            Append (T, '.');
            Append_Natural (T, Natural ((Time_Us / 100_000) mod 10), 1, True);
         when others =>
            null;
      end case;
   end Put_Time;

   procedure Time_String (T : out Text; Precision : Timer_Precision; Time_Us : Unsigned_32) is
   begin
      T := (others => <>);
      Put_Time (T, Precision, Time_Us);
   end Time_String;

   procedure Timer_String (T : out Text; Show_Symbol, Use_Precision : Boolean; Timer : Unsigned_16; C : Timer_Clocks) is
      Source : constant Timer_Source := Timer_Source_Of (Timer);
   begin
      T := (others => <>);
      if Show_Symbol then
         Append (T, Timer_Symbol (Source, C.Armed));
      end if;
      Put_Time (T, (if Use_Precision then Timer_Precision_Of (Timer) else Precision_Second), Timer_Value (Source, C));
   end Timer_String;

   function Battery_Symbol (Cell_Voltage : Cell_Volts; State : Adaflight.Battery.Battery_State;
                            Min_Cell, Max_Cell : Unsigned_16) return Character is
   begin
      if State = Adaflight.Battery.Critical then
         return Symbol_Main_Batt;
      end if;
      declare
         Span   : constant Integer_64 := 8 * (Integer_64 (Cell_Voltage) - Integer_64 (Min_Cell));
         Limits : constant Integer_64 := Integer_64 (Max_Cell) - Integer_64 (Min_Cell);
         Offset : Integer_64;
      begin
         pragma Assert (Limits /= 0 and then abs Span <= 8 * 65_535);
         Offset := Span / Limits;
         pragma Assert (abs Offset <= abs Span);
         return Character'Val (16#96# - Integer (Integer_64'Max (0, Integer_64'Min (6, Offset))));
      end;
   end Battery_Symbol;

   function Heading_Sector (Heading : Integer; Directions : Positive) return Natural is
      Positive_Heading : constant Natural := Heading + 360;
      Direction        : constant Natural := (Positive_Heading * Directions + 180) / 360;
   begin
      return Direction mod Directions;
   end Heading_Sector;

   function Direction_Symbol (Heading : Integer) return Character is
      Sector : constant Natural := (16 - Heading_Sector (Heading, 16) + 8) mod 16;
   begin
      return Character'Val (16#60# + Sector);
   end Direction_Symbol;

   function Temperature_In_Units (Celsius : Integer; Units : Unit_System) return Integer is
     (if Units = Imperial then Adaflight.Maths.Round_Half_Even (Float (Celsius) * 9.0 / 5.0 + 32.0) else Celsius);

end Adaflight.OSD_Format;
