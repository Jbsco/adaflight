--  A unit step that counts its calls, so that a pass over such steps has
--  an effect the proof sees, in the shapes the passes' units take: bare,
--  with a flag, with a time, with a time and a period named back, and
--  with a time and a tilt.
with Adaflight.Scheduler;

package Adaflight.Counting_Steps with SPARK_Mode, Initializes => Calls is
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

end Adaflight.Counting_Steps;
