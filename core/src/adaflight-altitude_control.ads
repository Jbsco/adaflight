--  The autopilot's altitude controller: the integral relaxed past two
--  metres of error, the proportional term held to the velocity limit
--  through the derivative gain, the derivative boosted above five metres
--  per second, the acceleration and feedforward terms, the hover offset,
--  the tilt compensation, and the throttle limits into a fraction of the
--  receiver's range. The altitude hold and the rescue drive it.
with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Position_Filter;

package Adaflight.Altitude_Control with SPARK_Mode is
   use type Interfaces.Integer_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Altitude_Cm is Position_Filter.Value;

   --  The configuration interface's ranges: the hover throttle in
   --  microseconds (zero to capture it from the stick), the throttle limits,
   --  the five altitude gains, and the receiver's minimum check.
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
      Min_Check      : Natural range 750 .. 1_999 := 1_050;
   end record;

   Task_Rate_Hz        : constant := 100;
   Nominal_Interval_Us : constant := 1_000_000 / Task_Rate_Hz;
   Interval_Min_Us     : constant Integer_32 := Nominal_Interval_Us / 4;
   Interval_Max_Us     : constant Integer_32 := Nominal_Interval_Us * 4;
   subtype Interval_Us is Integer_32 range Interval_Min_Us .. Interval_Max_Us;

   subtype Cosine is Float range -1.0 .. 1.0;
   subtype Gain is Float range 0.0 .. 8.0;
   subtype Integral is Float range -150.0 .. 150.0;
   subtype Captured_Throttle is Natural range 0 .. 1_700;
   subtype Climb_Rate_Cms is Float range 0.0 .. 8_000.0;
   subtype Target_Velocity is Float range -2.0 ** 16 .. 2.0 ** 16;

   --  The altitude estimate's control values and the attitude's cosine of
   --  tilt.
   type Inputs is record
      Altitude_Cm           : Altitude_Control.Altitude_Cm := 0.0;
      Vertical_Velocity     : Altitude_Control.Altitude_Cm := 0.0;
      Vertical_Acceleration : Altitude_Control.Altitude_Cm := 0.0;
      Cos_Tilt              : Cosine := 1.0;
   end record;

   type State is record
      Kp             : Gain := 0.0;
      Ki             : Gain := 0.0;
      Kd             : Gain := 0.0;
      Ka             : Gain := 0.0;
      Kf             : Gain := 0.0;
      Altitude_I     : Integral := 0.0;
      Throttle_Out   : Unit_Interval := 0.0;
      Captured_Hover : Captured_Throttle := 0;
   end record;

   --  The gains from their settings.
   procedure Init (S : out State; C : Settings);

   --  The integral and the throttle back to zero.
   procedure Reset (S : in out State);

   --  The hover throttle in use: the setting, else the stick captured at
   --  engagement, else the default.
   function Hover_Throttle (S : State; C : Settings) return Positive
     with Post => Hover_Throttle'Result <= 1_700;

   --  The hover throttle captured from the stick while no setting gives one.
   procedure Capture_Hover (S : in out State; C : Settings; Throttle_Command : Float)
     with Pre => Throttle_Command in 750.0 .. 2_250.0;
   procedure Clear_Hover (S : in out State);

   --  The task's measured interval held between a quarter and four times
   --  the nominal one, and the nominal one before the first measurement.
   function Task_Interval (Measured : Integer_32) return Interval_Us is
     (if Measured <= 0 then Nominal_Interval_Us
      else Integer_32'Max (Interval_Min_Us, Integer_32'Min (Interval_Max_Us, Measured)));

   --  One pass of the controller toward the target at the target velocity,
   --  within the velocity limit (the default limit when it is a centimetre
   --  a second or less).
   procedure Control (S : in out State; C : Settings; Inp : Inputs; Target_Altitude_Cm : Altitude_Cm;
                      Interval : Interval_Us; Target : Target_Velocity; Velocity_Limit : Climb_Rate_Cms);

end Adaflight.Altitude_Control;
