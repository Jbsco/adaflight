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

   procedure Step_Load (T : Menu_Target; Id : Menu.Menu_Id; M : out Menu.Table) is
      pragma Unreferenced (T, Id);
   begin
      Calls := Counted (Calls);
      M := (Lines => (others => <>), Count => 1);
   end Step_Load;

   procedure Step_Enter (T : in out Menu_Target; Id : Menu.Menu_Id; Reply : out Menu.Answer) is
      pragma Unreferenced (Id);
   begin
      T := Counted (T);
      Reply := (Done         => (if T mod 3 = 0 then Menu.Changed else Menu.Nothing),
                Target       => T mod Menu.Max_Menus,
                Kind         => Menu.Plain,
                Chain_Back   => T mod 2 = 0,
                Inhibit_Save => T mod 5 = 0,
                Screens      => T mod 4,
                Screen       => Step_Screen (T));
   end Step_Enter;

   procedure Step_Call (T : in out Menu_Target; Id : Menu.Menu_Id; Line : Natural; Reply : out Menu.Answer) is
      pragma Unreferenced (Id, Line);
   begin
      T := Counted (T);
      Reply := (Done         => Menu.Effect'Val (T mod 3),
                Target       => T mod Menu.Max_Menus,
                Kind         => Menu.Exit_Kind'Val (T mod 6),
                Chain_Back   => T mod 2 = 0,
                Inhibit_Save => T mod 5 = 0,
                Screens      => T mod 4,
                Screen       => Step_Screen (T));
   end Step_Call;

   procedure Step_Leave
     (T : in out Menu_Target; Id : Menu.Menu_Id; Self : Integer; Chain_Back : out Boolean; Save : out Boolean)
   is
      pragma Unreferenced (Id, Self);
   begin
      Save := False;
      T := Counted (T);
      Chain_Back := T mod 2 = 0;
   end Step_Leave;

   procedure Step_Update (T : in out Menu_Target; Id : Menu.Menu_Id; Selected : Natural; Chain_Back : out Boolean) is
      pragma Unreferenced (Id, Selected);
   begin
      T := Counted (T);
      Chain_Back := T mod 2 = 0;
   end Step_Update;

   procedure Step_Refresh (T : Menu_Target; Id : Menu.Menu_Id; M : in out Menu.Table) is
      pragma Unreferenced (T, Id, M);
   begin
      Calls := Counted (Calls);
   end Step_Refresh;

   procedure Step_Set_Value
     (T : in out Menu_Target; Id : Menu.Menu_Id; Line : Natural; Value : Interfaces.Integer_32)
   is
      pragma Unreferenced (Id, Line, Value);
   begin
      T := Counted (T);
   end Step_Set_Value;

   procedure Step_Act (On : Menu.Display_Index; A : Menu.Action; Arg : Integer) is
      pragma Unreferenced (On, A, Arg);
   begin
      Calls := Counted (Calls);
   end Step_Act;

   ---------------------
   -- Step_Read_Block --
   ---------------------

   procedure Step_Read_Block
     (Card : in out Card_Target; Sector : Interfaces.Unsigned_32; Buffer : FAT.Cache_Index; Accepted : out Boolean)
   is
      pragma Unreferenced (Sector, Buffer);
   begin
      Card := Counted (Card);
      Accepted := Card mod 2 = 0;
   end Step_Read_Block;

   ----------------------
   -- Step_Write_Block --
   ----------------------

   procedure Step_Write_Block
     (Card   : in out Card_Target;
      Sector : Interfaces.Unsigned_32;
      Buffer : FAT.Cache_Index;
      Data   : FAT.Sector_Bytes;
      Status : out FAT.Card_Status)
   is
      pragma Unreferenced (Sector, Buffer, Data);
   begin
      Card := Counted (Card);
      Status := FAT.Card_Status'Val (Card mod 4);
   end Step_Write_Block;

   -----------------------------
   -- Step_Begin_Write_Blocks --
   -----------------------------

   procedure Step_Begin_Write_Blocks
     (Card : in out Card_Target; Sector : Interfaces.Unsigned_32; Count : Interfaces.Unsigned_16)
   is
      pragma Unreferenced (Sector, Count);
   begin
      Card := Counted (Card);
   end Step_Begin_Write_Blocks;

   ---------------------
   -- Step_Read_Clock --
   ---------------------

   procedure Step_Read_Clock (Card : in out Card_Target; Valid : out Boolean; Local : out FAT.Clock_Reading) is
   begin
      Card := Counted (Card);
      Valid := Card mod 2 = 0;
      Local := (Year => 2026, Month => 10, Day => 17, Hours => 12, Minutes => 0, Seconds => 0);
   end Step_Read_Clock;

end Adaflight.Counting_Steps;
