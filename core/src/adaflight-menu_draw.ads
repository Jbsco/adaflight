--  The menu's draw: a page's labels, values and cursor written to the
--  display within the bytes it has room for, every row after the screen
--  was cleared and else the values marked for a print, the dynamic ones
--  every tenth of a second; the cursor moved past the rows it skips and
--  erased from its old row; each value in its element's form in a field
--  aligned to the right column, a lookup table's text in the space its
--  label leaves, the visibility marks of the OSD profiles with the editing
--  cursor's blink; the slider mark beside an overridden value; and the
--  page arrows after a clear. The display's writes come in as the
--  instantiation's procedures, with the bytes a string write takes.
with Interfaces;
with Adaflight.Menu;

generic
   with procedure Write
     (X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column; Attr : Interfaces.Unsigned_8; Text : String;
      Cost : out Interfaces.Unsigned_32);
   with procedure Write_Char
     (X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column; Attr : Interfaces.Unsigned_8; C : Character);
package Adaflight.Menu_Draw with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Adaflight.Menu.Element;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Poll_Interval_Us      : constant := 100_000;
   Draw_Buffer_Length    : constant := 12;
   Table_Value_Length    : constant := 30;
   Number_Field_Length   : constant := 5;
   Cursor_Blink_Delay_Ms : constant := 500;
   Ticker_Start_Cycles   : constant := 20;
   Ticker_Scroll_Cycles  : constant := 3;
   Room_Floor            : constant := 30;
   Profile_Count         : constant := 3;
   Profile_Bits_Position : constant := 11;

   Normal            : constant Unsigned_8 := 0;
   Symbol_Arrow_Up   : constant Character := Character'Val (16#75#);
   Symbol_Arrow_Down : constant Character := Character'Val (16#76#);

   --  The cursor's row in the page, which runs past the page's rows up to
   --  the end marker when every row below it is skipped.
   subtype Cursor is Natural range 0 .. Adaflight.Menu.Max_Lines;
   subtype Profile_Number is Positive range 1 .. Profile_Count;

   --  The display's state the draw reads and writes: its rows, whether its
   --  screen was cleared since the last draw, the row its cursor was drawn
   --  on (none after a clear), and whether it draws the OSD symbols.
   type Display is record
      Rows             : Adaflight.Menu.Screen_Rows := 8;
      Cleared          : Boolean := False;
      Cursor_Row       : Integer range -1 .. Adaflight.Menu.Max_Lines := -1;
      Supports_Symbols : Boolean := False;
   end record;

   --  A lookup table's ticker: its loop counter and the scroll position.
   type Ticker is record
      Loop_Counter : Unsigned_8 := 0;
      State        : Unsigned_8 := 0;
   end record;

   type Tickers is array (Adaflight.Menu.Row) of Ticker;

   --  The draw's context: the cursor row in the page, when the dynamic
   --  values were last polled, the OSD element editing with its profile
   --  cursor, and the lookup tables' tickers.
   type Context is record
      Cursor_Row      : Cursor := 0;
      Last_Polled_Us  : Unsigned_32 := 0;
      Element_Editing : Boolean := False;
      Profile_Cursor  : Profile_Number := 1;
      Table_Tickers   : Tickers := (others => (0, 0));
   end record;

   --  The screen cleared: the display forgets its cursor row.
   procedure Clear_Screen (D : in out Display)
     with Post => D.Cleared and then D.Cursor_Row = -1;

   --  The draw of the selected page. The layout's columns must leave a
   --  value's space within a text, as every display's do.
   procedure Draw
     (M      : Adaflight.Menu.Table;
      L      : Adaflight.Menu.Layout;
      P      : in out Adaflight.Menu.Page_State;
      C      : in out Context;
      D      : in out Display;
      S      : Adaflight.Menu.Slider_Settings;
      Now_Us : Unsigned_32;
      Now_Ms : Unsigned_32;
      Room   : Unsigned_32)
     with Pre => M.Count >= 1
       and then P.Top + P.Max_Row < M.Count
       and then P.Max_Row < D.Rows
       and then L.Right_Column <= L.Left_Column + Adaflight.Menu.Max_Text + 2
       and then (for all I in 0 .. M.Count - 1 =>
                   (if Adaflight.Menu.Element_Of (M.Lines (I).Flags) = Adaflight.Menu.Fixed
                    then M.Lines (I).Value in Adaflight.Menu.Fixed_Value));

end Adaflight.Menu_Draw;
