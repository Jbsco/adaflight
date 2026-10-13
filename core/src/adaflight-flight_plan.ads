--  The stored flight plan: up to 30 waypoints with their position, speed,
--  duration, climb rate, type, hold pattern and yaw behaviour, kept as the
--  configuration stores them.
with Interfaces;

package Adaflight.Flight_Plan with SPARK_Mode is
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_8 is Interfaces.Unsigned_8;

   Max_Waypoints : constant := 30;

   --  The waypoint types. The modifier types change the executor's state
   --  and pass on to the next positional waypoint.
   Type_Flyover    : constant := 0;
   Type_Flyby      : constant := 1;
   Type_Hold       : constant := 2;
   Type_Land       : constant := 3;
   Type_Takeoff    : constant := 4;
   Type_Alt_Change : constant := 5;
   Type_Delay      : constant := 6;
   Type_Yaw_Rate   : constant := 7;

   Pattern_None     : constant := 0;
   Pattern_Orbit    : constant := 1;
   Pattern_Figure_8 : constant := 2;

   Yaw_Default     : constant := 0;
   Yaw_Face_Target : constant := 1;
   Yaw_Face_Next   : constant := 2;
   Yaw_Hold        : constant := 3;

   --  Latitude and longitude in 1e-7 degrees, altitude in centimeters above
   --  mean sea level, speed and climb rate in cm/s with 0 for the default,
   --  duration in tenths of a second.
   type Waypoint is record
      Latitude      : Integer_32 := 0;
      Longitude     : Integer_32 := 0;
      Altitude      : Integer_32 := 0;
      Speed         : Unsigned_16 := 0;
      Duration_Ds   : Unsigned_16 := 0;
      Vert_Rate     : Unsigned_16 := 0;
      Kind          : Unsigned_8 := Type_Flyover;
      Pattern       : Unsigned_8 := Pattern_None;
      Yaw_Behaviour : Unsigned_8 := Yaw_Default;
   end record;

   subtype Waypoint_Count is Natural range 0 .. Max_Waypoints;
   type Waypoint_List is array (0 .. Max_Waypoints - 1) of Waypoint;

   type Plan is record
      Count     : Waypoint_Count := 0;
      Waypoints : Waypoint_List := (others => (others => <>));
   end record;

end Adaflight.Flight_Plan;
