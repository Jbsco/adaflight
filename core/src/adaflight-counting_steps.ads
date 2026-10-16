--  A unit step that counts its calls, so that a pass over such steps has
--  an effect the proof sees, in the shapes the passes' units take: bare,
--  with a flag, with a time, with a time and a period named back, with
--  a time and a tilt, and the display writes of a text and of a character.
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
     (X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; Text : String; Cost : out Interfaces.Unsigned_32)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Cost = Interfaces.Unsigned_32 (Calls);

   procedure Step_Write_Char (X : Menu.Column; Y : Menu.Column; Attr : Interfaces.Unsigned_8; C : Character)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

end Adaflight.Counting_Steps;
