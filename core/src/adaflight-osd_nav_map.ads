--  The OSD navigation map: a map of fourteen by eight characters with home,
--  the flight plan's waypoints and the flown trail, drawn one row per call
--  of the element. A frame is prepared at its first row: the craft's and
--  the waypoints' positions east and north of home, the view centred on
--  home or the craft and turned with the craft's heading when asked, and a
--  width from a table of steps that grows at once to fit the craft and the
--  first nine waypoints and shrinks only once the content fits the smaller
--  step well. The border shows which way is up and, for a while after the
--  width changes, the width. A row past the screen ends the frame.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Maths;
with Adaflight.Nav_Trail;
with Adaflight.OSD_Format;

package Adaflight.OSD_Nav_Map with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   Cols : constant := 14;
   Rows : constant := 8;
   subtype Col_Index is Natural range 0 .. Cols - 1;
   subtype Row_Index is Natural range 0 .. Rows - 1;
   type Row_Text is array (Col_Index) of Byte;
   type Grid is array (Row_Index) of Row_Text;

   Max_Waypoints : constant := 30;
   subtype Waypoint_Index is Natural range 0 .. Max_Waypoints - 1;

   --  A waypoint's type, position in degrees times ten million and altitude
   --  in centimetres.
   type Waypoint is record
      Kind      : Byte := 0;
      Latitude  : Integer_32 := 0;
      Longitude : Integer_32 := 0;
      Altitude  : Integer_32 := 0;
   end record;
   type Waypoint_List is array (Waypoint_Index) of Waypoint;

   type Location is record
      Latitude  : Integer_32 := 0;
      Longitude : Integer_32 := 0;
   end record;

   type Settings is record
      Heading_Up   : Boolean := False;
      Centre_Craft : Boolean := False;
      Min_Scale_M  : Interfaces.Unsigned_16 := 0;
      Units        : OSD_Format.Unit_System := OSD_Format.Metric;
   end record;

   --  The frame's inputs: the fixes, home and the craft, the cosine of
   --  home's latitude, the heading in tenths of a degree, the flight plan
   --  with the executor's waypoint, and the trail.
   type Inputs is record
      Fix_Home       : Boolean := False;
      Fix            : Boolean := False;
      Home           : Location;
      Craft          : Location;
      Cos_Lat        : Maths.Cosine := 1.0;
      Yaw_Deci       : Interfaces.Integer_16 := 0;
      Waypoint_Count : Byte := 0;
      Waypoints      : Waypoint_List;
      Nav_Active     : Boolean := False;
      Nav_Index      : Byte := 0;
      Trail_Count    : Nav_Trail.Count := 0;
      Trail          : Nav_Trail.Point_Array;
   end record;

   subtype Position_Cm is Float range -2.5e9 .. 2.5e9;
   subtype View_Cm is Float range -1.0e10 .. 1.0e10;
   subtype Cell_Size is Float range 160.0 .. 1_000_000.0;

   type Bar_Rows is array (Col_Index) of Byte;

   --  A map width in metres, zero before the first frame.
   subtype Scale_Value is Unsigned_32 range 0 .. 65_535
     with Static_Predicate => Scale_Value in 0 | 20 .. 65_535;

   type State is record
      Frame          : Grid := (others => (others => 16#20#));
      Center_East    : Position_Cm := 0.0;
      Center_North   : Position_Cm := 0.0;
      Cm_Per_Col     : Cell_Size := 160.0;
      Cm_Per_Row     : Cell_Size := 240.0;
      Sin_Rot        : Maths.Cosine := 0.0;
      Cos_Rot        : Maths.Cosine := 1.0;
      Rotated        : Boolean := False;
      Prepared       : Boolean := False;
      Render_Row     : Natural range 0 .. Rows := 0;
      Auto_Scale_M   : Scale_Value := 0;
      Anim_Phase     : Byte := 0;
      Bar_Row        : Bar_Rows := (others => 0);
      Last_Scale_M   : Scale_Value := 0;
      Flash_Frames   : Byte := 0;
      Zoomed_Out     : Boolean := False;
   end record;

   --  One call: the row's text with its offset, whether it is drawn and
   --  whether the element is complete.
   type Output is record
      Line     : Row_Text := (others => 0);
      Length   : Natural range 0 .. Cols := 0;
      Offset_Y : Byte := 0;
      Draw     : Boolean := True;
      Rendered : Boolean := True;
   end record;

   --  The map's width for a required width in metres.
   function Select_Scale_M (Required_M : Unsigned_32) return Unsigned_32
     with Post => Select_Scale_M'Result in 20 .. 51_200;

   procedure Render (S : in out State; C : Settings; Inp : Inputs; Pos_X, Pos_Y : Byte; Screen_Rows, Screen_Cols : Byte;
                     O : out Output);

end Adaflight.OSD_Nav_Map;
