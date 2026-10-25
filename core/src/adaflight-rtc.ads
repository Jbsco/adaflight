--  The real-time clock: milliseconds since 1970 kept as the value at boot
--  plus the running millisecond clock, converted to and from a calendar
--  date in the reference's four-year leap cycle, moved by a time zone in
--  minutes, formatted in ISO 8601 and split into date and time, and kept
--  as two words across a reset. The time source stays with the target.
with Interfaces;

package Adaflight.RTC with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;

   --  Milliseconds since the first of January 1970, within a span the
   --  arithmetic on the millisecond clock cannot leave.
   subtype Time is Interfaces.Integer_64 range -2 ** 62 .. 2 ** 62;
   subtype Started_Time is Interfaces.Integer_64 range -2 ** 62 - 2 ** 32 .. 2 ** 62;

   Reference_Year    : constant := 2000;
   Epoch_2000_Offset : constant := 946_684_800;
   Millis_Per_Second : constant := 1000;

   type Date_Time is record
      Year    : Unsigned_16 := 0;
      Month   : Unsigned_8 := 1;
      Day     : Unsigned_8 := 1;
      Hours   : Unsigned_8 := 0;
      Minutes : Unsigned_8 := 0;
      Seconds : Unsigned_8 := 0;
      Millis  : Unsigned_16 := 0;
   end record;

   Default_Date : constant Date_Time := (Year => 0, Month => 1, Day => 1, Hours => 0, Minutes => 0, Seconds => 0,
                                         Millis => 0);

   subtype Zone_Minutes is Integer_16 range -780 .. 780;

   type Settings is record
      Zone : Zone_Minutes := 0;
   end record;

   --  The clock: the time at boot, and whether a time was set.
   type Clock is record
      Started : Started_Time := 0;
      Is_Set  : Boolean := False;
   end record;

   function Has_Time (C : Clock) return Boolean is (C.Is_Set);

   subtype Seconds_Count is Interfaces.Integer_64 range -2 ** 52 .. 2 ** 52;

   function Make (Seconds : Seconds_Count; Millis : Unsigned_16) return Time is
     (Seconds * Millis_Per_Second + Interfaces.Integer_64 (Millis));

   function Seconds_Of (T : Interfaces.Integer_64) return Interfaces.Integer_64;
   function Millis_Of (T : Interfaces.Integer_64) return Unsigned_16;

   --  A date in the reference's leap cycle, with the month indexing the
   --  day table and the seconds counted in 64 bits; every other field wraps
   --  as the reference's arithmetic.
   function Date_To_Time (D : Date_Time) return Time
     with Pre => D.Month in 1 .. 12;

   function Time_To_Date (T : Interfaces.Integer_64) return Date_Time;

   function Is_Valid (D : Date_Time) return Boolean is
     (D.Year >= Reference_Year and then D.Month in 1 .. 12 and then D.Day in 1 .. 31 and then D.Hours <= 23
      and then D.Minutes <= 59 and then D.Seconds <= 59 and then D.Millis <= 999);

   --  The date moved by a time zone, through the time and back.
   function With_Offset (D : Date_Time; Minutes : Zone_Minutes) return Date_Time
     with Pre => D.Month in 1 .. 12;

   --  The text of a date, 4-digit fields padded with zeros as the reference
   --  prints them: the long form in ISO 8601 with the zone, the short form
   --  without the zone and the milliseconds. Valid says the date was shown
   --  rather than the default.
   Text_Length : constant := 30;
   subtype Formatted is String (1 .. Text_Length);

   procedure Format (D : Date_Time; Zone : Zone_Minutes; Short : Boolean; Text : out Formatted;
                     Length : out Natural; Valid : out Boolean)
     with Post => Length <= Text_Length;

   procedure Format_UTC (D : Date_Time; Text : out Formatted; Length : out Natural; Valid : out Boolean)
     with Post => Length <= Text_Length;

   procedure Format_Local (D : Date_Time; C : Settings; Text : out Formatted; Length : out Natural;
                           Valid : out Boolean)
     with Post => Length <= Text_Length;

   procedure Format_Local_Short (D : Date_Time; C : Settings; Text : out Formatted; Length : out Natural;
                                 Valid : out Boolean)
     with Post => Length <= Text_Length;

   function UTC_To_Local (D : Date_Time; C : Settings) return Date_Time
     with Pre => D.Month in 1 .. 12;

   --  The position of the first 'T' in a formatted date, which separates
   --  the date from the time.
   procedure Split (Text : String; Position : out Natural; Found : out Boolean)
     with Post => (if Found then Position in Text'Range);

   function Get (C : Clock; Now_Ms : Unsigned_32) return Interfaces.Integer_64 is
     (C.Started + Interfaces.Integer_64 (Now_Ms));

   procedure Set (C : out Clock; T : Time; Now_Ms : Unsigned_32);

   procedure Get_Date_Time (C : Clock; Now_Ms : Unsigned_32; D : out Date_Time; OK : out Boolean);

   procedure Set_Date_Time (C : out Clock; D : Date_Time; Now_Ms : Unsigned_32)
     with Pre => D.Month in 1 .. 12;

   --  The time with the zone applied as two words for the persistent
   --  registers, both zero while no time was set.
   procedure Persist_Write (C : Clock; Now_Ms : Unsigned_32; Minutes : Zone_Minutes; High, Low : out Unsigned_32);

   --  The time from the two words; OK says a time was stored and lies
   --  within the settable span.
   procedure Persist_Read (High, Low : Unsigned_32; T : out Time; OK : out Boolean);

end Adaflight.RTC;
