--  The PID rate loop: the P, I, D, and F terms per axis from the gyro rate
--  and the setpoint, with the acceleration limit, iterm relax, iterm
--  rotation, the D-term filter chain and D-max, the throttle-side TPA factor
--  and anti-gravity terms, in the operation order of the reference.

with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.PID_Config; use Adaflight.PID_Config;
with Adaflight.PID_Filters;

package Adaflight.PID_Controller with SPARK_Mode, Pure is

   subtype Axis is Adaflight.Axes.Axis;

   Anti_Gravity_KI : constant Float := 0.34;
   Iterm_Relax_Setpoint_Threshold : constant Float := 40.0;

   --  Rates in degrees per second as the gyro and the setpoint provide them.
   Rate_Bound : constant := 2.0 ** 13;
   subtype Rate is Float range -Rate_Bound .. Rate_Bound;
   type Axis_Rates is array (Axis) of Rate;

   --  The anti-gravity throttle derivative saturates here before the gain.
   Throttle_D_Bound : constant := 2.0 ** 24;
   subtype Throttle_D is Float range 0.0 .. Throttle_D_Bound;

   --  The I term stays within its limit after every loop; the bound leaves
   --  room for the rotation between loops.
   Iterm_Bound : constant := 2.0 ** 22;
   subtype Iterm is Float range -Iterm_Bound .. Iterm_Bound;

   type Terms is record
      P   : Signal := 0.0;
      I   : Iterm := 0.0;
      D   : Signal := 0.0;
      F   : Signal := 0.0;
      Sum : Signal := 0.0;
   end record;

   type Axis_Terms is array (Axis) of Terms;

   type Inputs is record
      Gyro                      : Axis_Rates := (others => 0.0);
      Setpoint                  : Axis_Rates := (others => 0.0);
      Feedforward               : Axis_Rates := (others => 0.0);
      Anti_Gravity_Enabled      : Boolean := False;
      Zero_Throttle_Iterm_Reset : Boolean := False;
   end record;

   type State is record
      Data                    : Axis_Terms;
      Filters                 : PID_Filters.State;
      Previous_Gyro_Dterm     : Axis_Signals := (others => 0.0);
      Previous_Setpoint       : Axis_Rates := (others => 0.0);
      Previous_PID_Setpoint   : Axis_Rates := (others => 0.0);
      Iterm_Accelerator       : Float range 0.0 .. Throttle_D_Bound * 251.0 * 0.35 := 0.0;
      Anti_Gravity_Throttle_D : Float range 0.0 .. Throttle_D_Bound * 251.0 := 0.0;
      Previous_Throttle       : Unit_Interval := 0.0;
      TPA_Factor              : Signal := 0.0;
      TPA_Low_Faded           : Boolean := False;
      Stabilisation_Enabled   : Boolean := False;
   end record;

   --  Prepares the controller from a profile and its runtime constants.
   procedure Init (S : out State; P : Profile; R : Runtime);

   --  The throttle-side terms the mixer refreshes every loop: the
   --  anti-gravity throttle derivative and the TPA factor.
   procedure Update_Throttle_Terms (S : in out State; R : Runtime; Throttle : Unit_Interval);

   procedure Set_Stabilisation (S : in out State; Enabled : Boolean);

   --  Motor output shaped so that thrust grows with the command, and the
   --  inverse applied to the base throttle so hover is preserved.
   function Apply_Thrust_Linearization (R : Runtime; Motor : Unit_Interval) return Float
     with Post => Apply_Thrust_Linearization'Result in -8.0 .. 8.0;
   function Compensate_Thrust_Linearization (R : Runtime; Throttle : Unit_Interval) return Float
     with Post => Compensate_Thrust_Linearization'Result in -1.0 .. 1.0;

   --  One loop of the rate controller.
   procedure Update (S : in out State; R : Runtime; P : Profile; Inp : Inputs);

end Adaflight.PID_Controller;
