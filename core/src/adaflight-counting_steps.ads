--  A unit step that counts its calls, so that a pass over such steps has
--  an effect the proof sees, in the shapes the passes' units take: bare,
--  with a flag, with a time, with a time and a period named back, with
--  a time and a tilt, the display writes of a text and of a character,
--  the menu hooks and the menu loading, and the target's actions.
with Interfaces;
with Adaflight.Menu;
with Adaflight.Scheduler;

package Adaflight.Counting_Steps with SPARK_Mode, Initializes => Calls is
   use type Interfaces.Unsigned_32;
   use type Scheduler.Time_Delta;
   use type Menu.Answer;
   use type Menu.Table;

   Calls : Natural := 0;

   function Counted (Before : Natural) return Natural is
     (if Before < Natural'Last then Before + 1 else 0);

   procedure Step
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_Flag (Flag : Boolean)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_At (Now_Us : Scheduler.Time_Us)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_Period (Now_Us : Scheduler.Time_Us; Next_Period_Us : out Scheduler.Time_Delta)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Next_Period_Us = Scheduler.Time_Delta (Calls);

   procedure Step_Tilt (Now_Us : Scheduler.Time_Us; Cos_Tilt : Float)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_Write
     (On : Menu.Display_Index; X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; Text : String;
      Cost : out Interfaces.Unsigned_32)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Cost = Interfaces.Unsigned_32 (Calls);

   procedure Step_Write_Char
     (On : Menu.Display_Index; X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; C : Character)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   --  A menu's hooks by its number, and its lines: one label line. The
   --  menus' target state counts the hooks that work on it.
   function Step_Hooks (Id : Menu.Menu_Id) return Menu.Hook_Set is
     (Enter => Id mod 2 = 0, Leave => Id mod 3 = 0, Update => Id mod 5 = 0);

   subtype Menu_Target is Natural;

   --  The display operations a counted hook makes: of a kind, at a place
   --  and of a length by the count.
   function Step_Screen (T : Menu_Target) return Menu.Screen_Ops is
     (others => (Kind   => Menu.Screen_Kind'Val (T mod 4),
                 X      => T mod 32,
                 Y      => T mod 16,
                 Attr   => 0,
                 Text   => (others => 'A'),
                 Length => T mod (Menu.Max_Screen_Text + 1)));

   procedure Step_Load (T : Menu_Target; Id : Menu.Menu_Id; M : out Menu.Table)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then M.Count = 1 and then Menu.Fixed_In_Range (M);

   procedure Step_Enter (T : in out Menu_Target; Id : Menu.Menu_Id; Reply : out Menu.Answer)
     with Global => null,
          Post   => T = Counted (T'Old)
                    and then Reply = (Done         => (if T mod 3 = 0 then Menu.Changed else Menu.Nothing),
                                      Target       => T mod Menu.Max_Menus,
                                      Kind         => Menu.Plain,
                                      Chain_Back   => T mod 2 = 0,
                                      Inhibit_Save => T mod 5 = 0,
                                      Screens      => T mod 4,
                                      Screen       => Step_Screen (T));

   procedure Step_Call (T : in out Menu_Target; Id : Menu.Menu_Id; Line : Natural; Reply : out Menu.Answer)
     with Global => null,
          Post   => T = Counted (T'Old)
                    and then Reply = (Done         => Menu.Effect'Val (T mod 3),
                                      Target       => T mod Menu.Max_Menus,
                                      Kind         => Menu.Exit_Kind'Val (T mod 6),
                                      Chain_Back   => T mod 2 = 0,
                                      Inhibit_Save => T mod 5 = 0,
                                      Screens      => T mod 4,
                                      Screen       => Step_Screen (T));

   procedure Step_Leave (T : in out Menu_Target; Id : Menu.Menu_Id; Self : Integer; Chain_Back : out Boolean)
     with Global => null,
          Post   => T = Counted (T'Old) and then Chain_Back = (T mod 2 = 0);

   procedure Step_Update (T : in out Menu_Target; Id : Menu.Menu_Id; Selected : Natural; Chain_Back : out Boolean)
     with Global => null,
          Post   => T = Counted (T'Old) and then Chain_Back = (T mod 2 = 0);

   procedure Step_Act (On : Menu.Display_Index; A : Menu.Action; Arg : Integer)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_Refresh (T : Menu_Target; Id : Menu.Menu_Id; M : in out Menu.Table)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then M = M'Old;

   procedure Step_Set_Value (T : in out Menu_Target; Id : Menu.Menu_Id; Line : Natural; Value : Interfaces.Integer_32)
     with Global => null,
          Post   => T = Counted (T'Old);

   --  A lookup table's text by line and index: blank, as long as its
   --  arguments' sum within the bound.
   function Step_Lookup (T : Menu_Target; Id : Menu.Menu_Id; Line : Natural; Index : Natural) return Menu.Label_Text is
     (Data => (others => ' '), Length => (Id + Line mod 64 + Index mod 64 + T mod 64) mod (Menu.Max_Text + 1));

end Adaflight.Counting_Steps;
