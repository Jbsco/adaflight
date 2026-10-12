--  The wing launch: armed with the launch switch on and the airframe at
--  rest, the state machine waits for the throttle, ramps the motor to idle
--  with the climb angle, holds for a throw, a bungee pull or a ground
--  speed over the threshold, delays the motor, spins up, climbs out until
--  the altitude, the timeout or the sticks, and hands the aircraft back
--  over a cross-fade. The sensors, the receiver and the modes stay with
--  the target; the unit reports the throttle, the angle targets and the
--  handover factor.
with Interfaces;

package Adaflight.Wing_Launch with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   type State is (Idle, Wait_Throttle, Motor_Idle, Wait_Detection, Motor_Delay, Spinup, In_Progress, Finish, Flying,
                  Aborted);

   type Exit_Reason is (None, Sticks, Attitude, Altitude, Timeout, Handover, Mode_Off);

   Idle_Ramp_Ms         : constant := 1500;
   Attitude_Hold_Ms     : constant := 100;
   Swing_Min_Yaw_Dps    : constant Float := 100.0;
   Gravity_Cmss         : constant Float := 980.665;
   Stationary_Speed_Cms : constant := 50;
   Stationary_Acc_Band  : constant Float := 0.15;
   Stationary_Gyro_Dps  : constant Float := 25.0;
   Stationary_Vario_Cms : constant Float := 100.0;
   Min_Sats             : constant := 5;

   type Settings is record
      Climb_Angle_Deg        : Unsigned_8 := 18;
      Max_Angle_Deg          : Unsigned_8 := 45;
      Detect_Accel_Decig     : Unsigned_8 := 19;
      Detect_Velocity_Cms    : Unsigned_16 := 300;
      Detect_Time_Ms         : Unsigned_16 := 40;
      Idle_Throttle_Percent  : Unsigned_8 := 5;
      Idle_Delay_Ms          : Unsigned_16 := 0;
      Throttle_Percent       : Unsigned_8 := 80;
      Motor_Delay_Ms         : Unsigned_16 := 500;
      Spinup_Time_Ms         : Unsigned_16 := 100;
      Min_Time_Ms            : Unsigned_16 := 0;
      Timeout_Ms             : Unsigned_16 := 5000;
      Max_Altitude_M         : Unsigned_16 := 0;
      End_Time_Ms            : Unsigned_16 := 3000;
      Abort_Deadband_Percent : Unsigned_8 := 20;
      Abort_Angle_Deg        : Unsigned_8 := 60;
   end record;

   --  Rates in degrees per second, accelerations in sensor counts or in g,
   --  altitudes in centimetres, all bounded far past any sensor.
   subtype Rate is Float range -1.0e6 .. 1.0e6;
   subtype Acceleration is Float range -1.0e6 .. 1.0e6;
   subtype Scale is Float range 0.0 .. 1.0;
   subtype Height_Cm is Float range -1.0e7 .. 1.0e7;
   subtype Deflection is Float range 0.0 .. 1.0;
   subtype Cosine is Float range -1.0 .. 1.0;

   type Inputs is record
      Now_Us              : Unsigned_32 := 0;
      Launch_Mode         : Boolean := False;
      Failsafe_Active     : Boolean := False;
      Throttle_Low        : Boolean := True;
      Roll_Deflection     : Deflection := 0.0;
      Pitch_Deflection    : Deflection := 0.0;
      Attitude_Roll       : Integer_16 := 0;
      Attitude_Pitch      : Integer_16 := 0;
      Acc_X               : Acceleration := 0.0;
      Acc_Y               : Acceleration := 0.0;
      Acc_1G_Rec          : Scale := 0.0;
      Acc_Magnitude       : Acceleration := 1.0;
      Gyro_Roll           : Rate := 0.0;
      Gyro_Pitch          : Rate := 0.0;
      Gyro_Yaw            : Rate := 0.0;
      Cos_Tilt            : Cosine := 1.0;
      Altitude_Available  : Boolean := False;
      Altitude_Cm         : Height_Cm := 0.0;
      Altitude_Derivative : Rate := 0.0;
      GPS_Fix             : Boolean := False;
      Num_Sat             : Unsigned_8 := 0;
      Ground_Speed_Cms    : Unsigned_16 := 0;
   end record;

   subtype Throttle_Value is Float range -10.0 .. 10.0;
   subtype Angle_Deg is Float range -255.0 .. 255.0;
   subtype Factor is Float range 0.0 .. 1.0;

   type Launch is record
      Current          : State := Idle;
      Latched          : Boolean := False;
      State_Entered_Us : Unsigned_32 := 0;
      Detected_Us      : Unsigned_32 := 0;
      Attitude_Lost_Us : Unsigned_32 := 0;
      Pitch_Target_Deg : Angle_Deg := 0.0;
      Throttle         : Throttle_Value := 0.0;
      Handover         : Factor := 0.0;
      Why              : Exit_Reason := None;
   end record;

   function Is_Terminal (L : Launch) return Boolean is (L.Current in Flying | Aborted);
   function Is_Active (L : Launch) return Boolean is (L.Current > Idle and then not Is_Terminal (L));
   function Is_Pre_Launch (L : Launch) return Boolean is (L.Current in Wait_Throttle .. Wait_Detection);
   function Throttle_Valid (L : Launch) return Boolean is (Is_Active (L));
   function Holds_Iterm (L : Launch) return Boolean is (Is_Active (L) and then L.Current < Spinup);

   --  At rest: the specific force within 0.15 g of one g, every gyro rate
   --  under 25 degrees per second, the vertical speed under a metre per
   --  second when an altitude exists, and the ground speed under half a
   --  metre per second when the fix has five satellites.
   function Is_Stationary (Inp : Inputs) return Boolean;

   procedure Init (L : out Launch);

   --  On arming: the launch latches with the switch on, a fixed wing, an
   --  accelerometer and the airframe at rest.
   procedure Arm (L : out Launch; Switch_On, Fixed_Wing, Acc_Present : Boolean; Inp : Inputs);

   --  The switch went off while the launch ran: the launch ends and the
   --  aircraft goes back to the pilot.
   procedure Switch_Off (L : in out Launch);

   --  One pass with the angle targets the level controller reads, written
   --  while the launch owns the aircraft.
   procedure Update (L : in out Launch; C : Settings; Inp : Inputs; Angle_Roll, Angle_Pitch : in out Angle_Deg);

end Adaflight.Wing_Launch;
