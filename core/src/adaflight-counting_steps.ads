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

   --  A menu's hooks by its number, and its lines: one label line.
   function Step_Hooks (Id : Menu.Menu_Id) return Menu.Hook_Set is
     (Enter => Id mod 2 = 0, Leave => Id mod 3 = 0, Update => Id mod 5 = 0);

   procedure Step_Load (Id : Menu.Menu_Id; M : out Menu.Table)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then M.Count = 1 and then Menu.Fixed_In_Range (M);

   procedure Step_Hook (Id : Menu.Menu_Id; Chain_Back : out Boolean)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Chain_Back = (Calls mod 2 = 0);

   procedure Step_Leave (Id : Menu.Menu_Id; Self : Integer; Chain_Back : out Boolean)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Chain_Back = (Calls mod 2 = 0);

   procedure Step_Update (Id : Menu.Menu_Id; Selected : Natural; Chain_Back : out Boolean)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Chain_Back = (Calls mod 2 = 0);

   procedure Step_Act (On : Menu.Display_Index; A : Menu.Action; Arg : Integer)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

end Adaflight.Counting_Steps;
