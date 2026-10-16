--  The menu system's lines and page layout: a line's element and flags
--  in the reference's encoding, a menu as a bounded table with its count
--  before the end marker, the screen geometry from the display's size,
--  the page count, the page selected by number with its top line, last
--  row and the lines' flags copied for the draw, the cursor's absolute
--  row, the rows the cursor skips, and the value text helpers: a
--  fixed-point value with its trailing zeros cut, a value aligned right
--  in its field, and the display's character set. The menus, their
--  lines' values and the display stay with the target.
with Interfaces;
with Adaflight.PID_Profile;

package Adaflight.Menu with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Adaflight.PID_Profile.Simplified_Mode;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Integer_32 is Interfaces.Integer_32;

   --  The element types in the reference's numbering; Guard is the debug
   --  type and every code above it.
   type Element is
     (Label, Back, OSD_Exit, Submenu, Funcall, Bool, Int8, UInt8, UInt16, Int16, UInt32, Int32, Str, Fixed,
      Visible, Tab, End_Marker, Guard);

   Element_Mask     : constant Unsigned_16 := 16#001F#;
   Print_Value      : constant Unsigned_16 := 16#0020#;
   Print_Label      : constant Unsigned_16 := 16#0040#;
   Dynamic          : constant Unsigned_16 := 16#0080#;
   Opt_String       : constant Unsigned_16 := 16#0100#;
   Reboot_Required  : constant Unsigned_16 := 16#0200#;
   Scrolling_Ticker : constant Unsigned_16 := 16#0400#;
   Slider_RP        : constant Unsigned_16 := 16#0800#;
   Slider_RPY       : constant Unsigned_16 := 16#1000#;
   Slider_Gyro      : constant Unsigned_16 := 16#2000#;
   Slider_DTerm     : constant Unsigned_16 := 16#4000#;

   function Element_Of (Flags : Unsigned_16) return Element is
     (if (Flags and Element_Mask) <= Element'Pos (Guard) then Element'Val (Flags and Element_Mask) else Guard);

   Max_Text : constant := 31;
   subtype Text_Length is Natural range 0 .. Max_Text;

   type Label_Text is record
      Data   : String (1 .. Max_Text) := (others => ' ');
      Length : Text_Length := 0;
   end record;

   --  A line: its text, its element and flags, whether it has data, and
   --  the data behind it: the number of a numeric, boolean, visibility or
   --  fixed-point line (the fixed-point one already multiplied), and the
   --  text of a string, label or function call line or a lookup table's
   --  text at the line's value.
   type Line is record
      Text       : Label_Text;
      Flags      : Unsigned_16 := 0;
      Has_Data   : Boolean := False;
      Value      : Integer_32 := 0;
      Value_Text : Label_Text;
   end record;

   Max_Lines : constant := 192;
   subtype Line_Index is Natural range 0 .. Max_Lines - 1;
   subtype Line_Count is Natural range 0 .. Max_Lines;
   type Line_Table is array (Line_Index) of Line;

   --  A menu: its lines before the end marker.
   type Table is record
      Lines : Line_Table;
      Count : Line_Count := 0;
   end record;

   Max_Rows : constant := 31;
   subtype Row is Natural range 0 .. Max_Rows - 1;

   --  The geometry from the display's size: a small screen below eighteen
   --  columns takes two lines per item and all its columns, a normal one
   --  up to thirty columns starts two columns in from each edge, a large
   --  one takes thirteen columns to each side of its middle, and a full
   --  screen display gives every column and row. The smallest display has
   --  eight rows, which keeps four items on a page.
   subtype Screen_Columns is Positive range 1 .. 255;
   subtype Screen_Rows is Positive range 8 .. 255;
   subtype Column is Natural range 0 .. 255;
   subtype Item_Count is Positive range 4 .. 255;

   type Layout is record
      Small_Screen   : Boolean := False;
      Lines_Per_Item : Positive range 1 .. 2 := 1;
      Left_Column    : Column := 0;
      Right_Column   : Column := 0;
      Max_Items      : Item_Count := 4;
   end record;

   function Layout_Of (Columns : Screen_Columns; Rows : Screen_Rows; Full_Screen : Boolean) return Layout;

   Max_Pages : constant := (Max_Lines - 1) / Item_Count'First + 1;
   subtype Page_Count is Positive range 1 .. Max_Pages;
   subtype Page_Number is Natural range 0 .. Max_Pages - 1;

   function Pages (M : Table; L : Layout) return Page_Count is ((M.Count - 1) / L.Max_Items + 1)
     with Pre => M.Count >= 1;

   --  The draw keeps a line's flags in a byte, which drops the flags above
   --  the dynamic one.
   type Runtime_Flags is array (Row) of Unsigned_8;

   --  The selected page: its number, its top line, its last row, and the
   --  lines' flags as the draw keeps them.
   type Page_State is record
      Page    : Page_Number := 0;
      Top     : Line_Index := 0;
      Max_Row : Row := 0;
      Flags   : Runtime_Flags := (others => 0);
   end record;

   --  The page by number, wrapped within the count; its last row from the
   --  lines left, the items on a page and the row limit; the flags of its
   --  lines copied.
   procedure Select_Page (M : Table; L : Layout; Number : Integer; P : in out Page_State)
     with Pre  => M.Count >= 1 and then Number in -1 .. Pages (M, L),
          Post => P.Page < Pages (M, L) and then P.Top < M.Count;

   function Cursor_Absolute (P : Page_State; L : Layout; Cursor : Row) return Natural is
     (Cursor + P.Page * L.Max_Items);

   --  The slider settings the skip rule reads: the simplified tuning mode
   --  and the gyro and D term filter sliders.
   type Slider_Settings is record
      Mode         : Adaflight.PID_Profile.Simplified_Mode := Adaflight.PID_Profile.Off;
      Gyro_Filter  : Boolean := False;
      DTerm_Filter : Boolean := False;
   end record;

   --  A value a slider overrides, by the line's slider flags.
   function Slider_Override (Flags : Unsigned_16; S : Slider_Settings) return Boolean;

   --  The rows the cursor skips: labels, strings, and the narrow numbers
   --  a slider overrides.
   function Skippable (E : Line; S : Slider_Settings) return Boolean;

   --  A value in thousandths as two integer digits, a point and the
   --  decimals, the trailing zeros cut down to the first decimal and a
   --  leading zero blanked.
   Max_Fixed : constant := 255 * 65_535;
   subtype Fixed_Value is Integer_32 range 0 .. Max_Fixed;

   function Format_Fixed (Value : Fixed_Value) return Label_Text;

   --  A value cut to its field and aligned right in it.
   procedure Pad_Left (T : in out Label_Text; Size : Text_Length)
     with Post => T.Length = Size;

   --  The display's character set: letters in upper case, and anything
   --  outside the space to underscore range a space.
   function Sanitized (T : Label_Text) return Label_Text
     with Post => Sanitized'Result.Length = T.Length;

end Adaflight.Menu;
