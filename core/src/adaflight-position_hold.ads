--  The position hold mode: engaged by its flight mode or a rescue, which
--  starts the controller, the sticks read against the deadband, the sensors
--  checked for a valid horizontal estimate and a heading where one is
--  required, the hold re-anchored when the sensors return, and the failure
--  the display shows.
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Position_Control;
with Adaflight.Position_Nav;

package Adaflight.Position_Hold with SPARK_Mode is
   subtype Inputs is Position_Control.Inputs;
   subtype Navigator is Position_Nav.Navigator;

   --  The stick deadband in percent of the deflection.
   type Settings is record
      Deadband : Natural range 0 .. 50 := 5;
   end record;

   --  What the debug values read of the enabled updates: the sensor status
   --  the last one judged, zero for good, one for no horizontal estimate and
   --  two for a heading not good to fly by. The tap holds what its site last
   --  wrote.
   type Debug_Taps is record
      Status_Set    : Boolean := False;
      Sensor_Status : Natural range 0 .. 2 := 0;
   end record;

   type State is record
      Enabled           : Boolean := False;
      Control_Ok        : Boolean := False;
      Sensors_Ok        : Boolean := False;
      Rescue_Was_Active : Boolean := False;
      Deadband          : Unit_Interval := 0.05;
      Control           : Position_Control.State;
      Taps              : Debug_Taps;
   end record;

   procedure Init (S : out State; C : Settings; PC : Position_Control.Settings);

   --  One position hold task over the navigator, a reached leg finishing
   --  with no owner to hand it to. Enable_XY asks the estimator to run the
   --  horizontal axes when the controller starts.
   procedure Update
     (S : in out State; PC : Position_Control.Settings; Inp : Inputs; N : in out Navigator; Enable_XY : out Boolean)
     with Pre => Position_Control.Bounded (Inp);

   --  The task up to the navigator's update. Proceed asks the caller to
   --  update the navigator, hand a reached leg to its owner and call
   --  Finish_Update.
   procedure Begin_Update
     (S : in out State; PC : Position_Control.Settings; Inp : Inputs; N : in out Navigator; Enable_XY : out Boolean;
      Proceed : out Boolean)
     with Pre => Position_Control.Bounded (Inp);

   procedure Finish_Update (S : in out State; PC : Position_Control.Settings; Inp : Inputs; N : Navigator)
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
