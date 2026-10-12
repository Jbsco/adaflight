--  The navigation trail: the breadcrumb line of a flight for the OSD map,
--  positions in whole metres east and north of home laid down by distance
--  flown rather than time, the store halved and the spacing doubled when
--  it fills. The position relative to home comes from the platform at
--  each poll; the GPS and the arming state stay with the target.
with Interfaces;

package Adaflight.Nav_Trail with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_16;

   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;

   Capacity           : constant := 240;
   Spacing_M          : constant := 5;
   Max_Spacing_M      : constant := 5000;
   Update_Interval_Us : constant := 100_000;

   type Point is record
      East_M  : Integer_16 := 0;
      North_M : Integer_16 := 0;
   end record;

   subtype Count is Natural range 0 .. Capacity;
   subtype Index is Natural range 0 .. Capacity - 1;
   type Point_Array is array (Index) of Point;
   subtype Spacing is Unsigned_16 range Spacing_M .. Max_Spacing_M;

   --  A position relative to home in centimetres, bounded far past the
   --  range the stored metres can hold.
   subtype Position_Cm is Float range -1.0e9 .. 1.0e9;

   type Trail is record
      Points         : Point_Array := (others => (East_M => 0, North_M => 0));
      Length         : Count := 0;
      Spacing_Now    : Spacing := Spacing_M;
      Was_Armed      : Boolean := False;
      Last_Update_Us : Unsigned_32 := 0;
   end record;

   --  The line starts over: no points and the base spacing.
   procedure Reset (T : in out Trail)
     with Post => T.Length = 0 and then T.Spacing_Now = Spacing_M;

   --  One position through the distance gate: the first point is stored,
   --  a later one when it lies at least the spacing from the last.
   procedure Ingest (T : in out Trail; East_Cm, North_Cm : Position_Cm);

   --  One poll: the line starts over on the arm edge, the poll runs at ten
   --  hertz, and the position is taken while armed with a fix and a home.
   procedure Update (T : in out Trail; Now_Us : Unsigned_32; Armed, Fix, Fix_Home : Boolean;
                     East_Cm, North_Cm : Position_Cm);

   function Point_At (T : Trail; I : Natural) return Point
     with Pre => I < T.Length;

end Adaflight.Nav_Trail;
