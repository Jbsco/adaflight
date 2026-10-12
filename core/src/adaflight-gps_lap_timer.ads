--  The GPS lap timer: a gate set from the averaged fixes while setting, the
--  distance and bearing to the gate on every fix, a lap recorded when the
--  craft leaves the gate's circle at the time it came closest to the centre,
--  the best lap and the best three in a row. The reset switch and the display
--  stay with the target.
with Interfaces;
with Adaflight.Maths;
with Adaflight.GPS_Frames;

package Adaflight.GPS_Lap_Timer with SPARK_Mode is
   use type Interfaces.Integer_64;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Integer_64 is Interfaces.Integer_64;
   subtype Location is GPS_Frames.Location;
   subtype Cosine is Adaflight.Maths.Cosine;

   Previous_Laps_Kept    : constant := 3;
   Max_Gate_Set_Readings : constant := 1000;

   --  The gate in ten-millionths of a degree, the shortest lap accepted and
   --  the gate's radius.
   type Settings is record
      Gate_Lat           : Integer_32 := 0;
      Gate_Lon           : Integer_32 := 0;
      Minimum_Lap_Time_S : Unsigned_16 := 10;
      Gate_Tolerance_M   : Unsigned_8 := 9;
   end record;

   subtype Lap_Index is Natural range 0 .. Previous_Laps_Kept - 1;
   type Lap_Times is array (Lap_Index) of Unsigned_32;
   subtype Reading_Count is Unsigned_16 range 0 .. Max_Gate_Set_Readings;
   subtype Reading_Sum is Integer_64 range
     Max_Gate_Set_Readings * Integer_64 (Integer_32'First) .. Max_Gate_Set_Readings * Integer_64 (Integer_32'Last);
   subtype Bearing is Integer_32 range 0 .. 36_000;

   --  While the gate is being set, the sums hold the readings counted, so
   --  their averages fit the gate.
   type Timer is record
      Gate                : Location;
      Previous            : Lap_Times := (others => 0);
      Best_Lap_Time       : Unsigned_32 := 0;
      Best_Three          : Unsigned_32 := 0;
      Distance_To_Gate_Cm : Unsigned_32 := 0;
      Direction_To_Gate   : Bearing := 0;
      Time_Of_Last_Lap    : Unsigned_32 := 0;
      Set_Readings        : Reading_Count := 0;
      Laps_Recorded       : Unsigned_16 := 0;
      Timer_Running       : Boolean := False;
      Setting_Gate        : Boolean := False;
      Lat_Sum             : Reading_Sum := 0;
      Lon_Sum             : Reading_Sum := 0;
      Min_Distance        : Unsigned_32 := Unsigned_32'Last;
      Min_Distance_Time   : Unsigned_32 := 0;
      Was_In_Circle       : Boolean := False;
   end record
     with Dynamic_Predicate =>
       (if Timer.Setting_Gate then
          Timer.Lat_Sum in Integer_64 (Timer.Set_Readings) * Integer_64 (Integer_32'First)
                           .. Integer_64 (Timer.Set_Readings) * Integer_64 (Integer_32'Last)
          and then Timer.Lon_Sum in Integer_64 (Timer.Set_Readings) * Integer_64 (Integer_32'First)
                           .. Integer_64 (Timer.Set_Readings) * Integer_64 (Integer_32'Last));

   --  The gate from the settings and every lap figure cleared; the circle
   --  tracking keeps its values.
   procedure Init (T : in out Timer; C : Settings)
     with Pre => not T.Setting_Gate;

   procedure Start_Set_Gate (T : in out Timer)
     with Post => T.Setting_Gate;

   --  The averaged gate becomes the settings' gate.
   procedure End_Set_Gate (T : in out Timer; C : in out Settings)
     with Post => not T.Setting_Gate;

   --  One fix: the distance and bearing to the gate, then the gate average
   --  while setting, the reset, or the lap detection.
   procedure New_GPS_Data (T : in out Timer; C : Settings; Position : Location; Time_Ms : Unsigned_32;
                           Cos_Lat : Cosine; Reset_Mode : Boolean);

end Adaflight.GPS_Lap_Timer;
