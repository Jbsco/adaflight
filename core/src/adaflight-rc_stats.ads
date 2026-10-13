--  RC statistics for the OSD statistics page: once the throttle passes 15%
--  after arming, each update while armed and out of crash flip counts a
--  sample, adds the throttle percentage to a sum, and times full throttle
--  with the number of times it was reached. Arming clears only the raised
--  flag, so the statistics run from power-on. The average throttle is the
--  sum over the count, rounded.
with Interfaces;

package Adaflight.RC_Stats with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Throttle_Percent is Integer range -100 .. 100;

   --  The last update's time, the raised flag, the sample count, the
   --  throttle sum as an unsigned 32-bit value, the full throttle time and
   --  count, and the last throttle percentage.
   type Stats is record
      Previous_Us       : Unsigned_32 := 0;
      Throttle_Raised   : Boolean := False;
      Count             : Unsigned_32 := 0;
      Total             : Unsigned_32 := 0;
      Full_Throttle_Us  : Unsigned_32 := 0;
      Full_Throttles    : Unsigned_32 := 0;
      Previous_Percent  : Throttle_Percent := 0;
   end record;

   --  One update at the statistics rate.
   procedure Update (S : in out Stats; Now_Us : Unsigned_32; Armed, Crash_Flip : Boolean; Percent : Throttle_Percent)
     with Global => null;

   --  Arming clears the raised flag.
   procedure Notify_Arming (S : in out Stats)
     with Global => null;

   --  The rounded average throttle: 0 before the first sample, and 127 when
   --  a wrapped sum puts the quotient past the 8-bit range.
   function Average_Throttle (S : Stats) return Integer_8
     with Global => null;

end Adaflight.RC_Stats;
