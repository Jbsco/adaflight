--  The menu's navigation: the menu opened on the current display, or
--  moved to the next display while open, with the geometry from the
--  display; a change to a menu, which stacks the menu left, loads its
--  lines, asks the new menu's enter hook with the change it makes, and
--  selects its first page, or
--  restores the page and cursor when the menu stays; the way back, which
--  asks the leave hook and restores the stacked menu; a page selected
--  with the screen cleared; the draw with its update hook and the way
--  back it may ask for; and the exit by its kind, which asks the leave
--  hooks, saves, releases the display, and for a reboot writes the notice
--  and stops the motors before the reset; and the keys: the menu key moves
--  the menu to the next display, escape ends an edit or takes the way
--  back, the save key opens the save menu for the reboot state, up and
--  down move the cursor over the rows and pages, and left and right edit
--  the line under the cursor in its element's form, enter a submenu, call
--  a function line or an exit line's function with the change or exit it
--  makes, each edit written to the target's value as
--  the reference writes the line's variable; and the update on every
--  pass: the menu opened on the stick gesture while closed, and while
--  open the sticks read as a key, handled when its delay has run out and
--  repeated while held, then the draw, the display's heartbeat every half
--  second, all within a drawing transaction. The menus come in through
--  the hook set and loading procedures, the hooks, the value store, the
--  refresh of the current menu's lines from the target's variables where
--  the reference reads them, the lookup of a table's text and the
--  target's actions as procedures; all but the hook sets and the actions
--  work on the target's state, which every operation passes on.
with Interfaces;
with Adaflight.Menu;

generic
   type Target_State is private;
   with function Hooks_Of (Id : Adaflight.Menu.Menu_Id) return Adaflight.Menu.Hook_Set;
   with procedure Load (T : Target_State; Id : Adaflight.Menu.Menu_Id; M : out Adaflight.Menu.Table);
   with procedure On_Enter (T : in out Target_State; Id : Adaflight.Menu.Menu_Id; Reply : out Adaflight.Menu.Answer);
   with procedure On_Leave
     (T : in out Target_State; Id : Adaflight.Menu.Menu_Id; Self : Integer; Chain_Back : out Boolean;
      Save : out Boolean);
   with procedure On_Display_Update
     (T : in out Target_State; Id : Adaflight.Menu.Menu_Id; Selected : Natural; Chain_Back : out Boolean);
   with procedure Line_Call
     (T : in out Target_State; Id : Adaflight.Menu.Menu_Id; Line : Natural; Reply : out Adaflight.Menu.Answer);
   with procedure Set_Value
     (T : in out Target_State; Id : Adaflight.Menu.Menu_Id; Line : Natural; Value : Interfaces.Integer_32);
   with procedure Refresh (T : Target_State; Id : Adaflight.Menu.Menu_Id; M : in out Adaflight.Menu.Table);
   with function Lookup (T : Target_State; Id : Adaflight.Menu.Menu_Id; Line : Natural; Index : Natural)
     return Adaflight.Menu.Label_Text;
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
   subtype Exit_Kind is Adaflight.Menu.Exit_Kind;

   --  The keys in the reference's numbering, and what the keys need: the
   --  start menu and background type the menu key's reopen takes, and the
   --  save menus for either reboot state.
   type Key_Code is (None, Up, Down, Left, Right, Esc, Menu_Key, Save_Menu);

   type Key_Settings is record
      Start            : Adaflight.Menu.Menu_Id := Adaflight.Menu.Main_Menu;
      Background       : Natural := 0;
      Save_Exit        : Adaflight.Menu.Menu_Id := Adaflight.Menu.Main_Menu;
      Save_Exit_Reboot : Adaflight.Menu.Menu_Id := Adaflight.Menu.Main_Menu;
   end record;

   Button_Time  : constant := 250;
   Button_Pause : constant := 500;
   subtype Key_Delay is Natural range 0 .. 65_535;

   --  What the update reads on a pass: the sticks, the arming flag, the
   --  paralyze and stick command disable modes, and a camera device menu
   --  or a joystick in use, which hold the menu off.
   type Stick_Inputs is record
      Throttle                : Float := 1500.0;
      Yaw                     : Float := 1500.0;
      Pitch                   : Float := 1500.0;
      Roll                    : Float := 1500.0;
      Armed                   : Boolean := False;
      Paralyzed               : Boolean := False;
      Stick_Commands_Disabled : Boolean := False;
      Device_In_Menu          : Boolean := False;
      Joystick_Active         : Boolean := False;
   end record;

   Stick_High         : constant := 1750.0;
   Stick_Low          : constant := 1250.0;
   Hold_Repeat_Start  : constant := 20;
   Repeat_Delay_Limit : constant := 50;
   Repeat_Limit       : constant := 5;
   Heartbeat_Ms       : constant := 500;
   Reset_Drawing      : constant := 2;
   subtype Repeat_Count is Positive range 1 .. Repeat_Limit;
   subtype Delay_Ms_Left is Integer range -32_768 .. 32_767;

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
      Rc_Delay_Ms    : Delay_Ms_Left := Button_Time;
      Last_Called_Ms : Unsigned_32 := 0;
      Last_Beat_Ms   : Unsigned_32 := 0;
      Hold_Count     : Interfaces.Integer_32 := 1;
      Repeat         : Repeat_Count := 1;
      Repeat_Base    : Interfaces.Integer_32 := 0;
      Extern_Key     : Key_Code := None;
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
   procedure Open (S : in out State; T : in out Target_State; Start : Adaflight.Menu.Menu_Id; Background : Natural)
     with Pre  => Consistent (S),
          Post => Consistent (S);

   --  A change to the menu held, which the reopen on another display
   --  makes, selects the page again, so the page need not fit the layout
   --  on the way in.
   procedure Change (S : in out State; T : in out Target_State; Target : Adaflight.Menu.Menu_Id)
     with Pre  => S.In_Menu and then Layout_Consistent (S)
                  and then (if S.Has_Menu
                            then S.Table.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (S.Table))
                  and then (if S.Has_Menu and then Target /= S.Id then Page_Consistent (S)),
          Post => Consistent (S) and then S.In_Menu and then S.Has_Menu;

   procedure Back (S : in out State; T : in out Target_State)
     with Pre  => S.In_Menu and then S.Has_Menu and then Consistent (S),
          Post => Consistent (S) and then S.In_Menu and then S.Has_Menu;

   procedure Select_Page (S : in out State; Number : Adaflight.Menu.Page_Request)
     with Pre  => S.In_Menu and then S.Has_Menu and then Consistent (S),
          Post => Consistent (S) and then S.In_Menu and then S.Has_Menu;

   --  The draw, which does nothing while the menu is closed.
   procedure Draw
     (S      : in out State;
      T      : in out Target_State;
      Sl     : Adaflight.Menu.Slider_Settings;
      Now_Us : Unsigned_32;
      Now_Ms : Unsigned_32;
      Room   : Unsigned_32)
     with Pre  => Consistent (S),
          Post => Consistent (S);

   --  A key handled, with the delay in milliseconds before the next; a
   --  key with the menu closed does nothing.
   procedure Handle_Key
     (S               : in out State;
      T               : in out Target_State;
      Key             : Key_Code;
      K               : Key_Settings;
      Sl              : Adaflight.Menu.Slider_Settings;
      Reboot_Required : Boolean;
      Delay_Ms        : out Key_Delay)
     with Pre  => Consistent (S),
          Post => Consistent (S);

   procedure Exit_Menu (S : in out State; T : in out Target_State; Kind : Exit_Kind)
     with Pre  => S.In_Menu and then S.Has_Menu and then Consistent (S),
          Post => Consistent (S) and then not S.In_Menu and then not S.Has_Menu and then S.Port = S.Port'Old;

   --  A key from outside the sticks, kept until the next pass reads it.
   procedure Set_Extern_Key (S : in out State; Key : Key_Code);

   --  One pass of the update at the pass's time in microseconds, with the
   --  clock in milliseconds the pass ends on, and the display's room.
   procedure Update
     (S               : in out State;
      T               : in out Target_State;
      K               : Key_Settings;
      Sl              : Adaflight.Menu.Slider_Settings;
      Sticks          : Stick_Inputs;
      Reboot_Required : Boolean;
      Now_Us          : Unsigned_32;
      Millis          : Unsigned_32;
      Room            : Unsigned_32)
     with Pre  => Consistent (S),
          Post => Consistent (S);

end Adaflight.Menu_Nav;
