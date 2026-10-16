package body Adaflight.Counting_Steps with SPARK_Mode is

   procedure Step is
   begin
      Calls := Counted (Calls);
   end Step;

   procedure Step_Flag (Flag : Boolean) is
      pragma Unreferenced (Flag);
   begin
      Calls := Counted (Calls);
   end Step_Flag;

   procedure Step_At (Now_Us : Scheduler.Time_Us) is
      pragma Unreferenced (Now_Us);
   begin
      Calls := Counted (Calls);
   end Step_At;

   procedure Step_Period (Now_Us : Scheduler.Time_Us; Next_Period_Us : out Scheduler.Time_Delta) is
      pragma Unreferenced (Now_Us);
   begin
      Calls := Counted (Calls);
      Next_Period_Us := Scheduler.Time_Delta (Calls);
   end Step_Period;

   procedure Step_Tilt (Now_Us : Scheduler.Time_Us; Cos_Tilt : Float) is
      pragma Unreferenced (Now_Us, Cos_Tilt);
   begin
      Calls := Counted (Calls);
   end Step_Tilt;

   procedure Step_Write
     (On : Menu.Display_Index; X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; Text : String;
      Cost : out Interfaces.Unsigned_32)
   is
      pragma Unreferenced (On, X, Y, Attr, Text);
   begin
      Calls := Counted (Calls);
      Cost := Interfaces.Unsigned_32 (Calls);
   end Step_Write;

   procedure Step_Write_Char
     (On : Menu.Display_Index; X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; C : Character)
   is
      pragma Unreferenced (On, X, Y, Attr, C);
   begin
      Calls := Counted (Calls);
   end Step_Write_Char;

   procedure Step_Load (Id : Menu.Menu_Id; M : out Menu.Table) is
      pragma Unreferenced (Id);
   begin
      Calls := Counted (Calls);
      M := (Lines => (others => <>), Count => 1);
   end Step_Load;

   procedure Step_Hook (Id : Menu.Menu_Id; Chain_Back : out Boolean) is
      pragma Unreferenced (Id);
   begin
      Calls := Counted (Calls);
      Chain_Back := Calls mod 2 = 0;
   end Step_Hook;

   procedure Step_Leave (Id : Menu.Menu_Id; Self : Integer; Chain_Back : out Boolean) is
      pragma Unreferenced (Id, Self);
   begin
      Calls := Counted (Calls);
      Chain_Back := Calls mod 2 = 0;
   end Step_Leave;

   procedure Step_Update (Id : Menu.Menu_Id; Selected : Natural; Chain_Back : out Boolean) is
      pragma Unreferenced (Id, Selected);
   begin
      Calls := Counted (Calls);
      Chain_Back := Calls mod 2 = 0;
   end Step_Update;

   procedure Step_Act (On : Menu.Display_Index; A : Menu.Action; Arg : Integer) is
      pragma Unreferenced (On, A, Arg);
   begin
      Calls := Counted (Calls);
   end Step_Act;

end Adaflight.Counting_Steps;
