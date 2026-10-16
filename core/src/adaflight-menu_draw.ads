--  The menu's draw: a page's labels, values and cursor written to the
--  display within the bytes it has room for, every row after the screen
--  was cleared and else the values marked for a print, the dynamic ones
--  every tenth of a second; the cursor moved past the rows it skips and
--  erased from its old row; the menu's display update hook, which can ask
--  for the way back; each value in its element's form in a field aligned
--  to the right column, a lookup table's text in the space its label
--  leaves, the visibility marks of the OSD profiles with the editing
--  cursor's blink; the slider mark beside an overridden value; and the
--  page arrows after a clear. The display's writes, the hook and the
--  refresh of the lines from the target's variables after the hook come
--  in as the instantiation's procedures, with the bytes a string write
--  takes; the hook and the refresh work on the target's state, which the
--  draw passes on.
with Interfaces;
with Adaflight.Menu;

generic
   type Target_State is private;
   with procedure Write
     (On : Adaflight.Menu.Display_Index; X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column;
      Attr : Interfaces.Unsigned_8; Text : String; Cost : out Interfaces.Unsigned_32);
   with procedure Write_Char
     (On : Adaflight.Menu.Display_Index; X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column;
      Attr : Interfaces.Unsigned_8; C : Character);
   with procedure Display_Update
     (T : in out Target_State; Id : Adaflight.Menu.Menu_Id; Selected : Natural; Chain_Back : out Boolean);
   with procedure Refresh (T : Target_State; Id : Adaflight.Menu.Menu_Id; M : in out Adaflight.Menu.Table);
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
   Room_Floor            : constant := 30;
   Profile_Bits_Position : constant := 11;

   Normal            : constant Unsigned_8 := 0;
   Symbol_Arrow_Up   : constant Character := Character'Val (16#75#);
   Symbol_Arrow_Down : constant Character := Character'Val (16#76#);

   --  The draw of the selected page of menu Id on display On. The
   --  layout's columns must leave a value's space within a text, as every
   --  display's do. Back_Requested says the hook asked for the way back.
   procedure Draw
     (T              : in out Target_State;
      On             : Adaflight.Menu.Display_Index;
      M              : in out Adaflight.Menu.Table;
      Id             : Adaflight.Menu.Menu_Id;
      Has_Update     : Boolean;
      L              : Adaflight.Menu.Layout;
      P              : in out Adaflight.Menu.Page_State;
      C              : in out Adaflight.Menu.Context;
      D              : in out Adaflight.Menu.Display;
      S              : Adaflight.Menu.Slider_Settings;
      Now_Us         : Unsigned_32;
      Now_Ms         : Unsigned_32;
      Room           : Unsigned_32;
      Back_Requested : out Boolean)
     with Pre  => M.Count >= 1
       and then P.Top + P.Max_Row < M.Count
       and then P.Max_Row < D.Rows
       and then L.Right_Column <= L.Left_Column + Adaflight.Menu.Max_Text + 2
       and then Adaflight.Menu.Fixed_In_Range (M),
          Post => P.Page = P.Page'Old and then P.Top = P.Top'Old and then P.Max_Row = P.Max_Row'Old
       and then Adaflight.Menu.Same_Size (D, D'Old)
       and then M.Count = M.Count'Old and then Adaflight.Menu.Fixed_In_Range (M);

end Adaflight.Menu_Draw;
