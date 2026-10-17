--  The PID rate loop: the P, I, D, and F terms per axis from the gyro rate
--  and the setpoint, with the acceleration limit, the angle and horizon
--  level modes that turn the setpoint into an angle error rate, iterm relax,
--  iterm rotation, the D-term filter chain and D-max, the throttle-side TPA
--  factor and anti-gravity terms, and a wing build's airspeed TPA, S term
--  and setpoint scaling, in the operation order of the reference.

with Interfaces;
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
      S   : Signal := 0.0;
      Sum : Signal := 0.0;
   end record;

   type Axis_Terms is array (Axis) of Terms;

   --  The level modes read the attitude in decidegrees less the trims, the
   --  stick deflections, and the rate the rates give at full deflection.
   subtype Level_Axis is PID_Filters.Level_Axis;
   subtype Decidegrees is Integer range -1_800 .. 1_800;
   subtype Trim is Integer range -300 .. 300;
   subtype Deflection is Float range -1.0 .. 1.0;
   subtype Max_Rate is Float range 0.5 .. 2_000.0;
   subtype Angle_Degrees is Float range -90.0 .. 90.0;
   type Level_Angles is array (Level_Axis) of Decidegrees;
   type Level_Trims is array (Level_Axis) of Trim;
   type Level_Deflections is array (Level_Axis) of Deflection;
   type Axis_Max_Rates is array (Axis) of Max_Rate;
   type Level_Targets is array (Level_Axis) of Angle_Degrees;
   type Axis_Flags is array (Axis) of Boolean;

   type Inputs is record
      Gyro                      : Axis_Rates := (others => 0.0);
      Setpoint                  : Axis_Rates := (others => 0.0);
      Feedforward               : Axis_Rates := (others => 0.0);
      Anti_Gravity_Enabled      : Boolean := False;
      Zero_Throttle_Iterm_Reset : Boolean := False;
      Angle_Mode                : Boolean := False;
      Horizon_Mode              : Boolean := False;
      Attitude                  : Level_Angles := (others => 0);
      Trims                     : Level_Trims := (others => 0);
      Deflection                : Level_Deflections := (others => 0.0);
      Max_RC_Rate               : Axis_Max_Rates := (others => 670.0);
      Now_Us                    : Interfaces.Unsigned_32 := 0;
      --  The crash recovery reads the arming state, the accelerometer's
      --  presence, the gyro overflow, and the mixer's motor range.
      Armed                     : Boolean := False;
      Acc_Present               : Boolean := False;
      Gyro_Overflow             : Boolean := False;
      Motor_Mix_Range           : Signal := 0.0;
      --  Launch control holds the setpoints to the stick's small deflections
      --  while the craft sits on the ground; the yaw deflection joins the
      --  level axes' for its full mode.
      Launch_Control_Active     : Boolean := False;
      Yaw_Deflection            : Float range -1.0 .. 1.0 := 0.0;
      --  The modes an autopilot drives, with its roll and pitch angles in
      --  degrees, its largest angle, and whether it holds the position
      --  itself.
      GPS_Rescue_Mode           : Boolean := False;
      Alt_Hold_Mode             : Boolean := False;
      Pos_Hold_Mode             : Boolean := False;
      Autopilot_Angle           : Level_Targets := (others => 0.0);
      Autopilot_Max_Angle       : Natural range 0 .. 90 := 50;
      Autopilot_In_Control      : Boolean := False;
      --  The gyro's yaw spin detection: the yaw setpoint drops to zero, the
      --  I terms clear, and roll and pitch keep no terms.
      Yaw_Spin_Detected         : Boolean := False;
      --  The landing disarm reads whether the throttle has risen since
      --  arming, whether the craft is below the autopilot's landing
      --  altitude, the largest stick deflection, the RC throttle, and the
      --  accelerometer's jerk magnitude.
      Throttle_Raised           : Boolean := False;
      Below_Landing_Altitude    : Boolean := False;
      Max_Deflection            : Float range 0.0 .. 1.0 := 0.0;
      RC_Throttle               : Float range 0.0 .. 1.0 := 0.0;
      Jerk_Magnitude            : Float range 0.0 .. 1.0E30 := 0.0;
   end record;

   --  A wing's airspeed model reads the motors' RMS output over their range,
   --  the battery's latest voltage in hundredths of a volt, and the attitude.
   subtype Motor_RMS is Float range 0.0 .. 2.0;
   type Wing_Inputs is record
      Motor_Output_RMS : Motor_RMS := 0.0;
      Battery_Latest   : Natural range 0 .. 65_535 := 0;
      Roll             : Decidegrees := 0;
      Pitch            : Decidegrees := 0;
   end record;

   --  The airspeed holds within this bound, far above any flight.
   Wing_Speed_Bound : constant := 1.0e10;

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
      TPA_Factor_Yaw          : Signal := 0.0;
      TPA_Factor_S            : Axis_Signals := (others => 0.0);
      Wing_Speed              : Float range 0.0 .. Wing_Speed_Bound := 0.0;
      Stabilisation_Enabled   : Boolean := False;
      Angle_Target            : Level_Targets := (others => 0.0);
      Angle_Yaw_Setpoint      : Rate := 0.0;
      Axis_In_Angle_Mode      : Axis_Flags := (others => False);
      Level_Mode_Start_Us     : Interfaces.Unsigned_32 := 0;
      Previous_External       : Boolean := False;
      In_Crash_Recovery       : Boolean := False;
      Crash_Detected_Us       : Interfaces.Unsigned_32 := 0;
      Crash_Beep              : Boolean := False;
      Crash_Disarm_Requested  : Boolean := False;
      Landing_Disarm_Requested : Boolean := False;
   end record;

   --  Prepares the controller from a profile and its runtime constants.
   procedure Init (S : out State; P : Profile; R : Runtime);

   --  The throttle-side terms the mixer refreshes every loop: the
   --  anti-gravity throttle derivative and the TPA factor, from the throttle
   --  or, for a fixed wing in a wing build, from the airspeed; a wing build
   --  adds the yaw and S term factors.
   procedure Update_Throttle_Terms
     (S : in out State; R : Runtime; P : Profile; Throttle : Unit_Interval; Wing : Wing_Inputs);

   --  The airspeed back to rest, as the wing launch arms.
   procedure Reset_TPA_Speed (S : in out State);

   procedure Set_Stabilisation (S : in out State; Enabled : Boolean);

   function Crash_Recovery_Active (S : State) return Boolean is (S.In_Crash_Recovery);

   --  Motor output shaped so that thrust grows with the command, and the
   --  inverse applied to the base throttle so hover is preserved.
   subtype Motor_Command is Float range -512.0 .. 512.0;
   function Apply_Thrust_Linearization (R : Runtime; Motor : Motor_Command) return Float
     with Post => Apply_Thrust_Linearization'Result in -2.0 ** 30 .. 2.0 ** 30;
   function Compensate_Thrust_Linearization (R : Runtime; Throttle : Unit_Interval) return Float
     with Post => Compensate_Thrust_Linearization'Result in -1.0 .. 1.0;

   --  One loop of the rate controller.
   procedure Update (S : in out State; R : Runtime; P : Profile; Inp : Inputs);

end Adaflight.PID_Controller;
