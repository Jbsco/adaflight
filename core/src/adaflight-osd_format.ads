--  The OSD's text formatting: numbers with their symbols and decimals,
--  altitudes and distances in the selected unit, coordinates in decimal,
--  sexagesimal and plus-code forms, PID lines, the clock, timers with their
--  sources and precisions, the battery and direction symbols, and the unit
--  conversions. The readings and the settings stay with the target.
with Interfaces;
with Adaflight.Battery;
with Adaflight.RTC;

package Adaflight.OSD_Format with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;
   use type Adaflight.Battery.Battery_State;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   type Unit_System is (Imperial, Metric, British);
   type Element_Type is (Type_1, Type_2, Type_3, Type_4);

   Max_Length : constant := 31;

   type Text is record
      Data   : String (1 .. Max_Length) := (others => ' ');
      Length : Natural range 0 .. Max_Length := 0;
   end record;

   --  The reference's symbol codes.
   Symbol_None        : constant Character := Character'Val (16#00#);
   Symbol_Altitude    : constant Character := Character'Val (16#7F#);
   Symbol_Latitude    : constant Character := Character'Val (16#89#);
   Symbol_Longitude   : constant Character := Character'Val (16#98#);
   Symbol_Sat_Left    : constant Character := Character'Val (16#1E#);
   Symbol_Sat_Right   : constant Character := Character'Val (16#1F#);
   Symbol_Hyphen      : constant Character := '-';
   Symbol_Degree      : constant Character := Character'Val (16#08#);
   Symbol_Minute      : constant Character := ''';
   Symbol_Second      : constant Character := '"';
   Symbol_Feet        : constant Character := Character'Val (16#0F#);
   Symbol_Miles       : constant Character := Character'Val (16#7E#);
   Symbol_Metres      : constant Character := Character'Val (16#0C#);
   Symbol_Kilometres  : constant Character := Character'Val (16#7D#);
   Symbol_On_Minutes  : constant Character := Character'Val (16#9B#);
   Symbol_Fly_Minutes : constant Character := Character'Val (16#9C#);
   Symbol_Main_Batt   : constant Character := Character'Val (16#97#);
   Symbol_Batt_Empty  : constant Character := Character'Val (16#96#);
   Symbol_Arrow_South : constant Character := Character'Val (16#60#);
   Symbol_Mph         : constant Character := Character'Val (16#9D#);
   Symbol_Kph         : constant Character := Character'Val (16#9E#);
   Symbol_Feet_S      : constant Character := Character'Val (16#99#);
   Symbol_Metres_S    : constant Character := Character'Val (16#9F#);
   Symbol_Fahrenheit  : constant Character := Character'Val (16#0D#);
   Symbol_Celsius     : constant Character := Character'Val (16#0E#);
   Symbol_Volt        : constant Character := Character'Val (16#06#);
   Symbol_Amp         : constant Character := Character'Val (16#9A#);
   Symbol_MAh         : constant Character := Character'Val (16#07#);

   --  Text appended a character, a string, or a number padded on the left
   --  to a width with zeros or spaces, as the reference's printf pads a
   --  field; past the maximum the text stops.
   procedure Append (T : in out Text; C : Character)
     with Post => T.Length = Natural'Min (Max_Length, T.Length'Old + 1);
   procedure Append_String (T : in out Text; S : String)
     with Pre  => S'Length <= Max_Length,
          Post => T.Length = Natural'Min (Max_Length, T.Length'Old + S'Length);
   procedure Append_Natural (T : in out Text; N : Natural; Width : Natural; Zero_Pad : Boolean)
     with Pre => Width <= 9;
   procedure Append_Integer (T : in out Text; V : Integer_32; Width : Natural; Zero_Pad : Boolean)
     with Pre => Width <= 9;

   --  How the integer part prints: a character before it, the width and
   --  whether zeros pad it; the default is a width of one.
   type Number_Format is record
      Lead     : Character := ' ';
      Has_Lead : Boolean := False;
      Width    : Natural range 0 .. 9 := 1;
      Zero_Pad : Boolean := True;
   end record;

   Default_Format : constant Number_Format := (others => <>);

   subtype Decimals is Natural range 0 .. 3;
   function Multiplier (D : Decimals) return Float is
     (case D is when 0 => 1.0, when 1 => 10.0, when 2 => 100.0, when 3 => 1_000.0);
   Value_Bound : constant := 2_000_000_000.0;

   --  A value with its symbols and decimals, rounded half to even or cut at
   --  the last decimal, the integer part in the format, a minus sign when
   --  the value is negative and the digits are not all zero.
   procedure Print_Float (T : out Text; Leading : Character; Value : Float; Format : Number_Format; D : Decimals;
                          Round : Boolean; Trailing : Character)
     with Pre => abs Value <= Value_Bound / Multiplier (D);

   Altitude_Bound : constant := 40_000_000;

   --  The altitude in the unit with the altitude symbol: one decimal or none,
   --  above the launch point or above sea level by the variant.
   procedure Altitude_String (T : out Text; Altitude_Cm : Integer_32; Variant : Element_Type; Altitude_Asl_Cm : Float;
                              Units : Unit_System)
     with Pre => Altitude_Asl_Cm in -Float (Altitude_Bound) .. Float (Altitude_Bound);

   --  A coordinate in ten-millionths of a degree: seven or four decimals,
   --  degrees, minutes and seconds, or the plus code, zero until the first
   --  fix.
   procedure Coordinate (T : out Text; Is_Longitude : Boolean; Variant : Element_Type; Fix_Ever : Boolean;
                         Lat, Lon : Integer_32)
     with Pre => Lat > Integer_32'First and then Lon > Integer_32'First;

   Distance_Bound          : constant := 1_000_000_000;
   Negative_Distance_Bound : constant := 4_000_000;

   --  A distance in metres in the unit, in the small unit below a mile or a
   --  kilometre and in the large one with one or two decimals above; a
   --  negative distance prints with its sign in the small unit.
   procedure Distance_String (T : out Text; Distance_M : Integer_32; Leading : Character; Units : Unit_System)
     with Pre => Distance_M in -Negative_Distance_Bound .. Distance_Bound;

   procedure PID_Line (T : out Text; Label : String; P, I, D, D_Max : Unsigned_8; F : Unsigned_16)
     with Pre => Label'Length <= 8;

   --  The clock in local time: the reference's short date form, the month,
   --  day, hours and minutes, or the time alone; empty without a clock.
   procedure RTC_Date_Time (T : out Text; Variant : Element_Type; Has_Time : Boolean; Date : Adaflight.RTC.Date_Time;
                            Zone : Adaflight.RTC.Settings; Valid : out Boolean)
     with Pre => Date.Month in 1 .. 12;

   subtype Timer_Precision is Natural range 0 .. 15;
   Precision_Second     : constant := 0;
   Precision_Hundredths : constant := 1;
   Precision_Tenths     : constant := 2;

   --  Minutes and seconds, with hundredths or tenths by the precision.
   procedure Time_String (T : out Text; Precision : Timer_Precision; Time_Us : Unsigned_32);

   subtype Timer_Source is Natural range 0 .. 15;
   Source_On          : constant := 0;
   Source_Total_Armed : constant := 1;
   Source_Last_Armed  : constant := 2;
   Source_On_Or_Armed : constant := 3;
   Source_Launch_Time : constant := 4;

   --  The clocks a timer reads.
   type Timer_Clocks is record
      Now_Us         : Unsigned_32 := 0;
      Fly_Time_Us    : Unsigned_32 := 0;
      Armed_Time_Us  : Unsigned_32 := 0;
      Launch_Time_Us : Unsigned_32 := 0;
      Armed          : Boolean := False;
   end record;

   function Timer_Symbol (Source : Timer_Source; Armed : Boolean) return Character is
     (case Source is
        when Source_On => Symbol_On_Minutes,
        when Source_Total_Armed | Source_Last_Armed => Symbol_Fly_Minutes,
        when Source_On_Or_Armed => (if Armed then Symbol_Fly_Minutes else Symbol_On_Minutes),
        when Source_Launch_Time => 'L',
        when others => ' ');

   function Timer_Value (Source : Timer_Source; C : Timer_Clocks) return Unsigned_32 is
     (case Source is
        when Source_On => C.Now_Us,
        when Source_Total_Armed => C.Fly_Time_Us,
        when Source_Last_Armed => C.Armed_Time_Us,
        when Source_On_Or_Armed => (if C.Armed then C.Fly_Time_Us else C.Now_Us),
        when Source_Launch_Time => C.Launch_Time_Us,
        when others => 0);

   --  A timer setting: its source in the low nibble, its precision in the
   --  next, its alarm in the high byte.
   function Timer_Source_Of (Timer : Unsigned_16) return Timer_Source is (Natural (Timer and 16#0F#));
   function Timer_Precision_Of (Timer : Unsigned_16) return Timer_Precision is
     (Natural (Interfaces.Shift_Right (Timer, 4) and 16#0F#));
   function Timer_Alarm_Of (Timer : Unsigned_16) return Natural is
     (Natural (Interfaces.Shift_Right (Timer, 8) and 16#FF#));

   procedure Timer_String (T : out Text; Show_Symbol, Use_Precision : Boolean; Timer : Unsigned_16; C : Timer_Clocks);

   --  The battery symbol: the critical one, or the cell voltage's place in
   --  the profile's range over the seven fill levels.
   subtype Cell_Volts is Natural range 0 .. 65_535;
   function Battery_Symbol (Cell_Voltage : Cell_Volts; State : Adaflight.Battery.Battery_State;
                            Min_Cell, Max_Cell : Unsigned_16) return Character
     with Pre => Min_Cell /= Max_Cell;

   --  The heading's sector of the circle, centred on the sector boundaries.
   function Heading_Sector (Heading : Integer; Directions : Positive) return Natural
     with Pre  => Heading in -360 .. 360 and then Directions <= 64,
          Post => Heading_Sector'Result < Directions;

   function Direction_Symbol (Heading : Integer) return Character
     with Pre => Heading in -360 .. 360;

   function Meters_To_Unit (Meters : Integer_32; Units : Unit_System) return Float is
     (if Units = Imperial then Float (Meters) * 3.28084 else Float (Meters));
   function Meters_Symbol (Units : Unit_System) return Character is
     (if Units = Imperial then Symbol_Feet else Symbol_Metres);

   Speed_Bound : constant := 200_000;
   function Speed_To_Unit (Cm_S : Integer_32; Units : Unit_System) return Integer_32 is
     (if Units in Imperial | British then Cm_S * 10_000 / 5_080 / 88 else Cm_S * 36 / 1_000)
     with Pre => Cm_S in -Speed_Bound .. Speed_Bound;
   function Speed_Symbol (Units : Unit_System) return Character is
     (if Units in Imperial | British then Symbol_Mph else Symbol_Kph);
   function Vario_Symbol (Units : Unit_System) return Character is
     (if Units = Imperial then Symbol_Feet_S else Symbol_Metres_S);

   Temperature_Bound : constant := 1_000_000;
   function Temperature_In_Units (Celsius : Integer; Units : Unit_System) return Integer
     with Pre => Celsius in -Temperature_Bound .. Temperature_Bound;
   function Temperature_Symbol (Units : Unit_System) return Character is
     (if Units = Imperial then Symbol_Fahrenheit else Symbol_Celsius);

end Adaflight.OSD_Format;
