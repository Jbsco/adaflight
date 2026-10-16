--  The menu's navigation: the menu opened on the current display, or
--  moved to the next display while open, with the geometry from the
--  display; a change to a menu, which stacks the menu left, asks the new
--  menu's enter hook, loads its lines and selects its first page, or
--  restores the page and cursor when the menu stays; the way back, which
--  asks the leave hook and restores the stacked menu; a page selected
--  with the screen cleared; the draw with its update hook and the way
--  back it may ask for; and the exit by its kind, which asks the leave
--  hooks, saves, releases the display, and for a reboot writes the notice
--  and stops the motors before the reset. The menus come in through the
--  hook set and loading procedures, the hooks and the target's actions as
--  procedures.
with Interfaces;
with Adaflight.Menu;

generic
   with function Hooks_Of (Id : Adaflight.Menu.Menu_Id) return Adaflight.Menu.Hook_Set;
   with procedure Load (Id : Adaflight.Menu.Menu_Id; M : out Adaflight.Menu.Table);
   with procedure On_Enter (Id : Adaflight.Menu.Menu_Id; Chain_Back : out Boolean);
   with procedure On_Leave (Id : Adaflight.Menu.Menu_Id; Self : Integer; Chain_Back : out Boolean);
   with procedure On_Display_Update (Id : Adaflight.Menu.Menu_Id; Selected : Natural; Chain_Back : out Boolean);
   with procedure Act (On : Adaflight.Menu.Display_Index; A : Adaflight.Menu.Action; Arg : Integer);
   with procedure Write
     (On : Adaflight.Menu.Display_Index; X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column;
      Attr : Interfaces.Unsigned_8; Text : String; Cost : out Interfaces.Unsigned_32);
   with procedure Write_Char
     (On : Adaflight.Menu.Display_Index; X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column;
      Attr : Interfaces.Unsigned_8; C : Character);
package Adaflight.Menu_Nav with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Stack_Limit : constant := 10;
   subtype Stack_Depth is Natural range 0 .. Stack_Limit;

   --  A stacked menu: its number, hooks, page and cursor row.
   type Frame is record
      Id     : Adaflight.Menu.Menu_Id := Adaflight.Menu.Main_Menu;
      Hooks  : Adaflight.Menu.Hook_Set;
      Page   : Adaflight.Menu.Page_Number := 0;
      Cursor : Adaflight.Menu.Cursor := 0;
   end record;

   type Frames is array (1 .. Stack_Limit) of Frame;

   --  The exit kinds in the reference's numbering: a plain exit, a save,
   --  a save with a reboot, and the popup's save, save with a reboot and
   --  exit with a reboot.
   type Exit_Kind is (Plain, Save, Save_Reboot, Popup_Save, Popup_Save_Reboot, Popup_Exit_Reboot);

   type Displays is array (Adaflight.Menu.Display_Index) of Adaflight.Menu.Display;
   subtype Display_Count is Natural range 0 .. Adaflight.Menu.Max_Displays;
   subtype Display_Choice is Integer range -1 .. Adaflight.Menu.Max_Displays - 1;

   --  The navigation's state: whether the menu is open and has a menu,
   --  the current menu with its hooks, the stacked menus, the current
   --  menu's lines, the layout and selected page, the draw's context,
   --  whether the save menu is inhibited, and the registered displays with
   --  the current one.
   type State is record
      In_Menu        : Boolean := False;
      Has_Menu       : Boolean := False;
      Id             : Adaflight.Menu.Menu_Id := Adaflight.Menu.Main_Menu;
      Hooks          : Adaflight.Menu.Hook_Set;
      Stack          : Frames;
      Depth          : Stack_Depth := 0;
      Table          : Adaflight.Menu.Table;
      Layout         : Adaflight.Menu.Layout;
      Page           : Adaflight.Menu.Page_State;
      Page_Count     : Adaflight.Menu.Page_Count := 1;
      Draw           : Adaflight.Menu.Context;
      Save_Inhibited : Boolean := False;
      Ports          : Displays;
      Port_Count     : Display_Count := 0;
      Port           : Display_Choice := -1;
   end record;

   --  What holds between the operations: a current display among the
   --  registered ones, every full screen display within the text bound,
   --  and an open menu on a display whose layout keeps a value's space and
   --  fits its rows.
   function Layout_Consistent (S : State) return Boolean is
     (S.Port < S.Port_Count
      and then (for all I in 0 .. S.Port_Count - 1 =>
                  (not S.Ports (I).Full_Screen or else S.Ports (I).Columns <= Adaflight.Menu.Max_Text + 2))
      and then (if S.In_Menu
                then S.Port >= 0
                  and then S.Layout.Right_Column <= S.Layout.Left_Column + Adaflight.Menu.Max_Text + 2
                  and then S.Layout.Max_Items <= S.Ports (S.Port).Rows));

   --  A current menu with at least one line, its fixed-point values in
   --  range, its page count, and its selected page within its lines and
   --  the layout's items.
   function Page_Consistent (S : State) return Boolean is
     (S.Table.Count >= 1
      and then Adaflight.Menu.Fixed_In_Range (S.Table)
      and then S.Page_Count = Adaflight.Menu.Pages (S.Table, S.Layout)
      and then S.Page.Top + S.Page.Max_Row < S.Table.Count
      and then S.Page.Max_Row < S.Layout.Max_Items);

   function Consistent (S : State) return Boolean is
     (Layout_Consistent (S) and then (if S.Has_Menu then S.In_Menu and then Page_Consistent (S)));

   --  A display registered, up to the limit; a full screen display must
   --  keep a value's space within a text.
   procedure Register_Display (S : in out State; D : Adaflight.Menu.Display)
     with Pre  => Consistent (S) and then (not D.Full_Screen or else D.Columns <= Adaflight.Menu.Max_Text + 2),
          Post => Consistent (S);

   --  The menu opened from the start menu on the current display, with the
   --  OSD's background type for the menu; while open, the next display
   --  takes the menu over with the cursor carried as an absolute row.
   procedure Open (S : in out State; Start : Adaflight.Menu.Menu_Id; Background : Natural)
     with Pre  => Consistent (S),
          Post => Consistent (S);

   --  A change to the menu held, which the reopen on another display
   --  makes, selects the page again, so the page need not fit the layout
   --  on the way in.
   procedure Change (S : in out State; Target : Adaflight.Menu.Menu_Id)
     with Pre  => S.In_Menu and then Layout_Consistent (S)
                  and then (if S.Has_Menu
                            then S.Table.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (S.Table))
                  and then (if S.Has_Menu and then Target /= S.Id then Page_Consistent (S)),
          Post => Consistent (S);

   procedure Back (S : in out State)
     with Pre  => S.In_Menu and then S.Has_Menu and then Consistent (S),
          Post => Consistent (S);

   procedure Select_Page (S : in out State; Number : Adaflight.Menu.Page_Request)
     with Pre  => S.In_Menu and then S.Has_Menu and then Consistent (S),
          Post => Consistent (S);

   procedure Draw (S : in out State; Sl : Adaflight.Menu.Slider_Settings; Now_Us, Now_Ms, Room : Unsigned_32)
     with Pre  => S.In_Menu and then S.Has_Menu and then Consistent (S),
          Post => Consistent (S);

   procedure Exit_Menu (S : in out State; Kind : Exit_Kind)
     with Pre  => S.In_Menu and then S.Has_Menu and then Consistent (S),
          Post => Consistent (S) and then not S.In_Menu and then not S.Has_Menu;

end Adaflight.Menu_Nav;
