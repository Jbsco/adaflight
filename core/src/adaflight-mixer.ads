--  The motor mixer: scales the controller sums into the motor mix, shapes the
--  throttle through the limit, the throttle-side updates, the boost, and the
--  thrust compensation, applies the airmode and mixer-kind adjustments, and
--  writes every motor output within the configured range.

with Interfaces;
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.PID_Config; use Adaflight.PID_Config;
with Adaflight.PID_Controller;
with Adaflight.Filters;

package Adaflight.Mixer with SPARK_Mode, Pure is

   subtype Axis is Adaflight.Axes.Axis;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   PID_Mixer_Scaling : constant Float := 1000.0;
   Dyn_LPF_Throttle_Steps : constant := 100;
   Dyn_LPF_Update_Delay_Us : constant := 5000;

   Max_Motors : constant := 8;
   subtype Motor_Count is Positive range 1 .. Max_Motors;
   subtype Motor_Index is Natural range 0 .. Max_Motors - 1;

   subtype Weight is Float range -2.0 .. 2.0;
   type Motor_Weights is record
      Throttle : Weight := 0.0;
      Roll     : Weight := 0.0;
      Pitch    : Weight := 0.0;
      Yaw      : Weight := 0.0;
   end record;
   type Mix_Table is array (Motor_Index) of Motor_Weights;

   Quad_X : constant Mix_Table :=
     (0 => (1.0, -1.0, 1.0, -1.0), 1 => (1.0, -1.0, -1.0, 1.0),
      2 => (1.0, 1.0, 1.0, 1.0), 3 => (1.0, 1.0, -1.0, -1.0), others => <>);

   type Mixer_Kind is (Legacy, Linear, Dynamic, Ez_Landing);
   type Throttle_Limit_Kind is (Off, Scale, Clip);

   --  Motor output values as the protocol takes them, DShot up to 2047.
   subtype Motor_Value is Float range 0.0 .. 2048.0;
   type Motor_Outputs is array (Motor_Index) of Motor_Value;

   type Config is record
      Count                  : Motor_Count := 4;
      Table                  : Mix_Table := Quad_X;
      Kind                   : Mixer_Kind := Legacy;
      Yaw_Reversed           : Boolean := False;
      Throttle_Limit         : Throttle_Limit_Kind := Off;
      Throttle_Limit_Percent : Natural range 25 .. 100 := 100;
      Output_Low             : Motor_Value := 1000.0;
      Output_High            : Motor_Value := 2000.0;
      Disarm_Output          : Motor_Value := 1000.0;
      Motor_Stop             : Boolean := False;
      Min_Check              : Natural range 1000 .. 2000 := 1050;
      Launch_Table           : Mix_Table := Quad_X;
      --  The RPM limiter: whether it runs, its limit in RPM, its P, I and D
      --  settings, the motor KV, the motors' maximum output, and the stick's
      --  maximum check.
      RPM_Limit              : Boolean := False;
      RPM_Limit_Value        : Positive range 1 .. 65_535 := 18_000;
      RPM_Limit_P            : Natural range 0 .. 100 := 25;
      RPM_Limit_I            : Natural range 0 .. 1_000 := 10;
      RPM_Limit_D            : Natural range 0 .. 100 := 8;
      Motor_KV               : Positive range 1 .. 40_000 := 1_960;
      Max_Throttle           : Natural range 750 .. 2_250 := 2_000;
      Max_Check              : Natural range 750 .. 2_250 := 1_900;
      --  The crash flip: the percentage of their mix the motors not used for
      --  the flip take, and the roll or pitch rate, in tens of degrees per
      --  second, at which the drive reaches zero.
      Crashflip_Motor_Percent : Natural range 0 .. 100 := 0;
      Crashflip_Rate         : Natural range 0 .. 250 := 0;
      --  A DShot protocol, whose values below the low end are commands, so
      --  that the failsafe sends the disarm output for any output below it.
      DShot                  : Boolean := False;
      --  The battery sag compensation: the PID profile's compensation in
      --  percent and the battery profile's warning cell voltage in
      --  hundredths of a volt.
      Sag_Compensation       : Natural range 0 .. 150 := 0;
      Warning_Cell_Voltage   : Natural range 100 .. 500 := 350;
   end record
     with Dynamic_Predicate =>
       Config.Output_Low < Config.Output_High and then Config.Disarm_Output <= Config.Output_High;

   subtype RC_Throttle_Value is Float range 1000.0 .. 2000.0;

   subtype Deflection_Value is Float range -1.0 .. 1.0;
   type Axis_Deflections is array (Axis) of Deflection_Value;
   type Axis_Magnitudes is array (Axis) of Unit_Interval;
   type Motor_Flags is array (Motor_Index) of Boolean;

   type Inputs is record
      RC_Throttle               : RC_Throttle_Value := 1000.0;
      Throttle_Angle_Correction : Integer range -1000 .. 1000 := 0;
      Time_Us                   : Unsigned_32 := 0;
      Armed                     : Boolean := False;
      Airmode                   : Boolean := False;
      Failsafe                  : Boolean := False;
      Max_Deflection            : Unit_Interval := 0.0;
      Speed                     : Float range 0.0 .. 1000.0 := 0.0;
      --  Launch control mixes pitch-only launches through the launch table,
      --  holds the throttle at zero and counts as airmode; altitude hold and
      --  GPS rescue take the autopilot's throttle when it has one; these
      --  and position hold keep the motors from stopping.
      Launch_Control_Active     : Boolean := False;
      GPS_Rescue_Mode           : Boolean := False;
      Alt_Hold_Mode             : Boolean := False;
      Pos_Hold_Mode             : Boolean := False;
      Autopilot_Throttle_Valid  : Boolean := False;
      Autopilot_Throttle        : Unit_Interval := 0.0;
      --  The gyro's yaw spin detection lifts the yaw sum limit to its
      --  largest and, without airmode, sets half throttle.
      Yaw_Spin_Detected         : Boolean := False;
      --  The RPM limiter reads whether the motors report DShot telemetry,
      --  their averaged RPM, and the battery voltage in centivolts.
      DShot_Telemetry           : Boolean := False;
      RPM_Average               : Float range 0.0 .. 2.0E9 := 0.0;
      Battery_Voltage           : Interfaces.Unsigned_16 := 0;
      --  The crash flip takes the stick's direction from the deflections the
      --  controller reads, smoothed with RC smoothing on, and its strength
      --  from the magnitudes of the raw deflections. The roll and pitch
      --  rates, and with the accelerometer the cosine of the tilt, take the
      --  drive off as the craft turns over.
      Crash_Flip_Active         : Boolean := False;
      Deflection                : Axis_Deflections := (others => 0.0);
      Deflection_Abs            : Axis_Magnitudes := (others => 0.0);
      Gyro                      : PID_Controller.Axis_Rates := (others => 0.0);
      Acc_Present               : Boolean := False;
      Cos_Tilt                  : Cosine := 1.0;
      --  The battery's sag-filtered cell voltage in hundredths of a volt.
      Sag_Cell_Voltage          : Natural range 0 .. 65_535 := 0;
      --  A wing's airspeed TPA reads the battery's latest voltage in
      --  hundredths of a volt and the roll and pitch in decidegrees.
      Battery_Voltage_Latest    : Natural range 0 .. 65_535 := 0;
      Attitude                  : PID_Controller.Level_Angles := (others => 0);
      --  A wing launch's throttle, while valid, blends into the throttle by
      --  the handover in the launch mode, which also keeps the motors from
      --  stopping. The RMS output counts the enabled motors of an enabled
      --  motor device.
      Launch_Mode               : Boolean := False;
      Launch_Throttle_Valid     : Boolean := False;
      Launch_Throttle           : Unit_Interval := 0.0;
      Launch_Handover           : Unit_Interval := 0.0;
      --  The dynamic idle reads the slowest motor's frequency in hertz and
      --  whether the throttle has risen since arming.
      Min_Motor_Frequency       : Float range 0.0 .. 1.0e6 := 0.0;
      Throttle_Raised           : Boolean := False;
      Motors_Enabled            : Boolean := True;
      Motor_Enabled             : Motor_Flags := (others => True);
   end record;

   type State is record
      Motors                  : Motor_Outputs := (others => 0.0);
      Throttle                : Unit_Interval := 0.0;
      RC_Throttle             : Unit_Interval := 0.0;
      Mix_Range               : Signal := 0.0;
      Dyn_LPF_Last_Update_Us  : Unsigned_32 := 0;
      Dyn_LPF_Previous_Step   : Integer range -1 .. Dyn_LPF_Throttle_Steps := -1;
      Limiter_P_Gain          : Float range 0.0 .. 0.002 := 0.0;
      Limiter_I_Gain          : Float range 0.0 .. 0.2 := 0.0;
      Limiter_D_Gain          : Float range 0.0 .. 40.0 := 0.0;
      Limiter_I               : Float range 0.0 .. 1.0E30 := 0.0;
      Limiter_Scale           : Unit_Interval := 1.0;
      Limiter_Initial_Scale   : Unit_Interval := 1.0;
      Limiter_Previous_Error  : Float range -2.0 ** 33 .. 2.0 ** 33 := 0.0;
      Limiter_Average         : Filters.PT1;
      Limiter_Offset          : Filters.PT1;
      Flip_Tilt_Set           : Boolean := False;
      Flip_Tilt_Start         : Cosine := 1.0;
      --  The motors' RMS output over their range, which a wing's airspeed
      --  TPA reads.
      Motor_Output_RMS        : PID_Controller.Motor_RMS := 0.0;
      --  The dynamic idle: the slowest motor's target frequency, zero when
      --  off, the gains, the largest increase in flight and before takeoff,
      --  the delay on the motor frequency, the I term, the delayed frequency,
      --  and the increase of the motor range's low end.
      Dyn_Idle_Min_Rps        : Float range 0.0 .. 334.0 := 0.0;
      Dyn_Idle_P_Gain         : Float range 0.0 .. 0.04 := 0.0;
      Dyn_Idle_I_Gain         : Float range 0.0 .. 0.26 := 0.0;
      Dyn_Idle_D_Gain         : Float range 0.0 .. 0.76 := 0.0;
      Dyn_Idle_Max_Increase   : Float range 0.0 .. 0.26 := 0.0;
      Dyn_Idle_Start_Increase : Float range 0.0 .. 0.21 := 0.0;
      Dyn_Idle_Delay_K        : Float range 0.0 .. 4.1 := 0.0;
      Dyn_Idle_I              : Float range 0.0 .. 0.26 := 0.0;
      Dyn_Idle_Prev_Min_Rps   : Signal := 0.0;
      Range_Min_Increase      : Float range 0.0 .. 0.26 := 0.0;
   end record;

   --  The sag compensation's full cell voltage in hundredths of a volt, its
   --  range down to the warning cell voltage, and its factor, zero with the
   --  RPM limit on or without a range.
   Sag_Full_Cell_Voltage : constant := 420;

   function Sag_Range (C : Config) return Float is
     (Float (Sag_Full_Cell_Voltage) - Float (C.Warning_Cell_Voltage));

   function Sag_Factor (C : Config) return Float is
     (if C.Sag_Compensation > 0 and then not C.RPM_Limit and then C.Warning_Cell_Voltage < Sag_Full_Cell_Voltage
      then Float (C.Sag_Compensation) / 100.0 else 0.0);

   --  The RPM limiter as the mixer's profile sets it up: its gains from the
   --  settings and the loop time, its filters, and the reset.
   procedure Init_RPM_Limiter
     (S : in out State; C : Config; R : Runtime; Battery_Voltage : Interfaces.Unsigned_16);

   --  The limiter's reset at arming: no I term, and the throttle scale of
   --  the limit over the motors' estimated top RPM.
   procedure Reset_RPM_Limiter (S : in out State; C : Config; Battery_Voltage : Interfaces.Unsigned_16);

   --  The dynamic idle as the mixer's profile sets it up: off without DShot
   --  telemetry, its gains from the settings and the loop time, the motor
   --  idle as its limit before takeoff, and the motor range's low end at the
   --  DShot minimum while it runs.
   DShot_Min_Throttle : constant := 48.0;
   procedure Init_Dyn_Idle
     (S : in out State; C : in out Config; R : Runtime; P : Profile; DShot_Telemetry : Boolean;
      Motor_Idle : Natural)
     with Pre => Motor_Idle <= 2_000;

   --  One loop of the mixer after the controller, with the throttle-side
   --  updates the controller and filters take from the mixer. The crash flip
   --  drives the motors by itself and leaves the throttle-side updates out.
   procedure Update
     (S   : in out State; C : Config; Ctl : in out PID_Controller.State;
      R   : Runtime; P : Profile; Inp : Inputs)
     with Post =>
       (for all M in 0 .. C.Count - 1 =>
          S.Motors (M) >= Float'Min (C.Disarm_Output, C.Output_Low)
          and then (Inp.Crash_Flip_Active or else S.Motors (M) <= C.Output_High));

end Adaflight.Mixer;
