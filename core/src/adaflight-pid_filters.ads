--  Filter state of the PID controller: the D-term chain per axis, the yaw
--  P-term lowpass, the throttle boost lowpass, the iterm relax lowpass per
--  axis, the D-max estimators, and the anti-gravity throttle lowpass,
--  initialized from a profile and its runtime constants.

with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.PID_Config; use Adaflight.PID_Config;

package Adaflight.PID_Filters with SPARK_Mode, Pure is

   subtype Axis is Adaflight.Axes.Axis;

   D_Max_Range_Hz     : constant := 85.0;
   Attitude_Cutoff_Hz : constant := 50.0;

   subtype Level_Axis is Axis range Roll .. Pitch;

   --  One lowpass stage of a selectable kind, with every variant present
   --  so the state size is fixed.
   type Lowpass_Stage is record
      Kind : Lowpass_Kind := PID_Profile.PT1;
      Used : Boolean := False;
      P1   : Filters.PT1;
      P2   : Filters.PT2;
      P3   : Filters.PT3;
      S    : SVF_Lowpass;
   end record;

   type Axis_Notch is array (Axis) of SVF_Notch;
   type Axis_Stage is array (Axis) of Lowpass_Stage;
   type Axis_PT1 is array (Axis) of Filters.PT1;
   type Axis_PT2 is array (Axis) of Filters.PT2;
   type Level_PT3 is array (Level_Axis) of Filters.PT3;

   type State is record
      Notch_Used     : Boolean := False;
      Notch          : Axis_Notch;
      Lowpass1       : Axis_Stage;
      Lowpass2       : Axis_Stage;
      Yaw_P_Used     : Boolean := False;
      Yaw_P_Lowpass  : Filters.PT1;
      Throttle_Boost : Filters.PT1;
      Windup         : Axis_PT1;
      D_Max_Range    : Axis_PT2;
      D_Max_Lowpass  : Axis_PT2;
      Anti_Gravity   : Filters.PT2;
      Attitude       : Level_PT3;
      Angle_Feedforward : Level_PT3;
      Horizon_Smoothing : Filters.PT1;
      Horizon_Delay_Ms  : Natural range 10 .. 5000 := 500;
   end record;

   --  Center limit of the notch and the state-variable lowpass stages: 95
   --  percent of the Nyquist frequency of the loop, truncated.
   function Nyquist_Limit (Dt : Seconds) return Natural
     with Post => Nyquist_Limit'Result <= 475_000;

   procedure Init (S : out State; P : Profile; R : Runtime);

   --  The D-term chain: notch, then the two lowpass stages.
   procedure Apply_Dterm (S : in out State; A : Axis; Input : Signal; Output : out Signal);

   procedure Apply_Yaw_P (S : in out State; Input : Signal; Output : out Signal);

   --  Moves the first D-term lowpass with the throttle, as the mixer requests
   --  every loop.
   procedure Update_Dynamic_Lowpass (S : in out State; R : Runtime; Throttle : Unit_Interval);

end Adaflight.PID_Filters;
