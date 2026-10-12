--  The altitude hold: the hold's engagement from the flight mode with the
--  hover throttle captured from the stick, the target altitude moved by the
--  stick outside its deadband or driven down by a failsafe or an emergency
--  descent, and the autopilot's altitude controller that turns the error
--  into a throttle fraction.
with Interfaces;
with Adaflight.Altitude_Control;
with Adaflight.Position_Filter;

package Adaflight.Altitude_Hold with SPARK_Mode is
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Altitude_Cm is Position_Filter.Value;

   --  The configuration interface's ranges: the hover throttle in
   --  microseconds (zero to capture it from the stick), the throttle limits,
   --  the five altitude gains, the climb rate in tens of centimeters per
   --  second, the stick deadband in percent, and the receiver's minimum
   --  check.
   subtype Gain_Setting is Natural range 0 .. 200;
   type Settings is record
      Hover_Throttle : Natural range 0 .. 1_700 := 1_275;
      Throttle_Min   : Positive range 1_050 .. 1_400 := 1_100;
      Throttle_Max   : Positive range 1_400 .. 2_000 := 1_900;
      Altitude_P     : Gain_Setting := 30;
      Altitude_I     : Gain_Setting := 30;
      Altitude_D     : Gain_Setting := 30;
      Altitude_A     : Gain_Setting := 30;
      Altitude_F     : Gain_Setting := 30;
      Climb_Rate     : Natural range 0 .. 200 := 50;
      Deadband       : Natural range 0 .. 70 := 20;
      Min_Check      : Natural range 750 .. 1_999 := 1_050;
   end record;

   Task_Rate_Hz : constant := 100;
   Nominal_Interval_Us : constant := 1_000_000 / Task_Rate_Hz;

   subtype Throttle_Us is Float range 750.0 .. 2_250.0;
   subtype Climb_Rate_Cms is Float range 0.0 .. 4_000.0;
   subtype Cosine is Float range -1.0 .. 1.0;

   --  The flight mode, the task's measured interval (nonpositive before the
   --  first measurement), the throttle stick and its low status, the
   --  failsafe, the emergency descent request with its rate, the altitude
   --  estimate's control values, and the attitude's cosine of tilt.
   type Inputs is record
      Hold_Mode             : Boolean := False;
      Interval_Us           : Integer_32 := 0;
      Throttle_Command      : Throttle_Us := 1_000.0;
      Throttle_Low          : Boolean := False;
      Failsafe_Active       : Boolean := False;
      Emergency_Descent     : Boolean := False;
      Emergency_Rate_Cms    : Climb_Rate_Cms := 0.0;
      Altitude_Cm           : Altitude_Hold.Altitude_Cm := 0.0;
      Vertical_Velocity     : Altitude_Hold.Altitude_Cm := 0.0;
      Vertical_Acceleration : Altitude_Hold.Altitude_Cm := 0.0;
      Cos_Tilt              : Cosine := 1.0;
   end record;

   subtype Deadband_Fraction is Float range 0.0 .. 0.7;
   subtype Climb_Limit is Float range 0.0 .. 2_000.0;
   subtype Target_Velocity is Float range -2.0 ** 16 .. 2.0 ** 16;

   --  The autopilot's altitude controller's share of the settings.
   function Control_Settings (C : Settings) return Altitude_Control.Settings is
     (Hover_Throttle => C.Hover_Throttle, Throttle_Min => C.Throttle_Min, Throttle_Max => C.Throttle_Max,
      Altitude_P => C.Altitude_P, Altitude_I => C.Altitude_I, Altitude_D => C.Altitude_D,
      Altitude_A => C.Altitude_A, Altitude_F => C.Altitude_F, Min_Check => C.Min_Check);

   type State is record
      Active             : Boolean := False;
      Target_Altitude_Cm : Altitude_Cm := 0.0;
      Max_Climb_Rate     : Climb_Limit := 500.0;
      Target_Velocity    : Altitude_Hold.Target_Velocity := 0.0;
      Deadband           : Deadband_Fraction := 0.2;
      Allow_Stick        : Boolean := True;
      Emergency_Rate     : Climb_Rate_Cms := 0.0;
      Control            : Altitude_Control.State;
   end record;

   --  The gains from their settings, the deadband and climb rate, and the
   --  target at the current altitude.
   procedure Init (S : out State; C : Settings; Altitude_Cm : Altitude_Hold.Altitude_Cm);

   --  The hover throttle in use: the setting, else the stick captured at
   --  engagement, else the default.
   function Hover_Throttle (S : State; C : Settings) return Positive is
     (Altitude_Control.Hover_Throttle (S.Control, Control_Settings (C)))
     with Post => Hover_Throttle'Result <= 1_700;

   --  One hold task: the engagement or release with the controller reset,
   --  then while engaged the target moved by the stick, the failsafe, or the
   --  emergency descent at the measured interval, and the controller's
   --  throttle fraction.
   procedure Update (S : in out State; C : Settings; Inp : Inputs);

end Adaflight.Altitude_Hold;
