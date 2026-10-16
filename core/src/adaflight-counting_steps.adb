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
     (X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; Text : String; Cost : out Interfaces.Unsigned_32)
   is
      pragma Unreferenced (X, Y, Attr, Text);
   begin
      Calls := Counted (Calls);
      Cost := Interfaces.Unsigned_32 (Calls);
   end Step_Write;

   procedure Step_Write_Char (X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; C : Character) is
      pragma Unreferenced (X, Y, Attr, C);
   begin
      Calls := Counted (Calls);
   end Step_Write_Char;

end Adaflight.Counting_Steps;
