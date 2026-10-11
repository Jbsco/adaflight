--  The position hold mode: engaged by its flight mode or a rescue, which
--  starts the controller, the sticks read against the deadband, the sensors
--  checked for a valid horizontal estimate and a heading where one is
--  required, the hold re-anchored when the sensors return, and the failure
--  the display shows.
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Position_Control;

package Adaflight.Position_Hold with SPARK_Mode is
   subtype Inputs is Position_Control.Inputs;

   --  The stick deadband in percent of the deflection.
   type Settings is record
      Deadband : Natural range 0 .. 50 := 5;
   end record;

   type State is record
      Enabled           : Boolean := False;
      Control_Ok        : Boolean := False;
      Sensors_Ok        : Boolean := False;
      Rescue_Was_Active : Boolean := False;
      Deadband          : Unit_Interval := 0.05;
      Control           : Position_Control.State;
   end record;

   procedure Init (S : out State; C : Settings; PC : Position_Control.Settings);

   --  One position hold task. Enable_XY asks the estimator to run the
   --  horizontal axes when the controller starts.
   procedure Update (S : in out State; PC : Position_Control.Settings; Inp : Inputs; Enable_XY : out Boolean)
     with Pre => Position_Control.Bounded (Inp);

   --  Whether a valid horizontal estimate and, where required, a heading
   --  are available; a heading recovery in progress stands in for one.
   function Sensors_Ok_Now (Inp : Inputs; Allow_Heading_Recovery : Boolean) return Boolean is
     (Inp.Valid_XY and then (not Inp.Heading_Required or else Inp.Heading_Valid or else Allow_Heading_Recovery));

   function Failure (S : State; Inp : Inputs) return Boolean is
     (Inp.Pos_Hold_Mode and then (not S.Control_Ok or else not S.Sensors_Ok));

   function Ready (Inp : Inputs) return Boolean is (Sensors_Ok_Now (Inp, False));

   function In_Control (S : State) return Boolean is (S.Enabled and then S.Control_Ok and then S.Sensors_Ok);

end Adaflight.Position_Hold;
