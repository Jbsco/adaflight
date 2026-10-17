--  Runtime constants of the PID controller derived from a profile and the
--  loop time, in the operation order of the reference.

with Interfaces;
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.PWL;

package Adaflight.PID_Config with SPARK_Mode, Pure is

   use type Interfaces.Integer_32;

   subtype Integer_32 is Interfaces.Integer_32;

   P_Term_Scale       : constant Float := 0.032029;
   I_Term_Scale       : constant Float := 0.244381;
   D_Term_Scale       : constant Float := 0.000529;
   Feedforward_Scale  : constant Float := 0.013754;
   Anti_Gravity_KP    : constant Float := 0.0034;
   D_Max_Lowpass_Hz   : constant Float := 35.0;
   D_Max_Gain_Factor  : constant Float := 0.00008;
   Feedforward_Rx_Dt  : constant Float := 1.0 / 250.0;
   TPA_Curve_Points   : constant := 17;
   S_Term_Scale       : constant Float := 0.01;
   G_Acceleration     : constant Float := 9.806_65;

   subtype Loop_Time_Us is Natural range 100 .. 100_000;
   subtype Seconds is Float range 1.0e-4 .. 0.1;
   subtype Frequency is Float range 10.0 .. 1.0e4;

   type Coefficients is record
      Kp : Float range 0.0 .. 8.1 := 0.0;
      Ki : Float range 0.0 .. 153.0 := 0.0;
      Kd : Float range 0.0 .. 0.14 := 0.0;
      Kf : Float range 0.0 .. 0.14 := 0.0;
   end record;

   type Axis_Coefficients is array (Axis) of Coefficients;
   subtype Velocity is Float range 0.0 .. 5000.0;
   subtype D_Max_Ratio is Float range 1.0 .. 250.0;
   type Axis_Velocities is array (Axis) of Velocity;
   type Axis_Ratios is array (Axis) of D_Max_Ratio;

   type Dyn_Lowpass is (None, PT1, SVF, PT2, PT3);

   --  The battery's full voltage in volts, zero when unset.
   subtype Full_Voltage is Float range 0.0 .. 656.0
     with Dynamic_Predicate => Full_Voltage = 0.0 or else Full_Voltage >= 0.0099;

   --  A wing's airspeed model for the TPA: the thrust to weight ratio, the
   --  drag over the mass, the inverse of the propeller's pitch speed, the
   --  battery's full voltage, the pitch offset in radians, and the top
   --  speed that scales the airspeed into the TPA argument.
   type TPA_Speed_Model is record
      Thrust_Weight      : Float range 0.0 .. 1.0e5 := 0.0;
      Drag_Mass          : Float range 0.0 .. 1.0e11 := 0.0;
      Inverse_Prop_Speed : Float range 0.0 .. 1.0e8 := 0.0;
      Max_Voltage        : Full_Voltage := 0.0;
      Pitch_Offset       : Float range -58.0 .. 58.0 := 0.0;
      Max_Speed          : Float range 0.01 .. 1.0e20 := 1.0;
   end record;

   --  A wing build's airframe: whether the mixer flies a fixed wing, and
   --  the motor KV the advanced airspeed model reads.
   type Wing_Setup is record
      Build      : Boolean := False;
      Fixed_Wing : Boolean := False;
      Motor_KV   : Natural range 0 .. 65_535 := 1_960;
   end record;

   No_Wing : constant Wing_Setup := (others => <>);

   type Runtime is record
      Dt                         : Seconds := 1.0e-3;
      PID_Frequency              : Frequency := 1000.0;
      Coefficient                : Axis_Coefficients;
      Angle_Gain                 : Float range 0.0 .. 20.0 := 0.0;
      Angle_Feedforward_Gain     : Float range 0.0 .. 2.0 := 0.0;
      Angle_Earth_Ref            : Float range 0.0 .. 1.0 := 0.0;
      Horizon_Gain               : Float range 0.0 .. 1.0 := 0.0;
      Horizon_Ignore_Sticks      : Float range 0.0 .. 1.0 := 0.0;
      Horizon_Limit_Sticks       : Float range 0.1 .. 2.0 := 1.0;
      Horizon_Limit_Sticks_Inv   : Float range 0.49 .. 10.1 := 1.0;
      Horizon_Limit_Degrees      : Float range 10.0 .. 250.0 := 135.0;
      Horizon_Limit_Degrees_Inv  : Float range 0.0039 .. 0.11 := 0.0074;
      Max_Velocity               : Axis_Velocities := (others => 0.0);
      Anti_Gravity_Gain          : Gain := 0;
      Anti_Gravity_Osd_Cutoff    : Float range 0.0 .. 6.25 := 0.0;
      Anti_Gravity_P_Gain        : Float range 0.0 .. 0.0085 := 0.0;
      Crash_Time_Limit_Us        : Integer_32 := 0;
      Crash_Time_Delay_Us        : Integer_32 := 0;
      Crash_Recovery_Angle_Dd    : Integer_32 := 0;
      Crash_Recovery_Rate        : Float range 50.0 .. 255.0 := 100.0;
      Crash_Gyro_Threshold       : Float range 100.0 .. 2000.0 := 400.0;
      Crash_Dterm_Threshold      : Float range 10_000.0 .. 2_000_000.0 := 50_000.0;
      Crash_Setpoint_Threshold   : Float range 50.0 .. 2000.0 := 350.0;
      Crash_Limit_Yaw            : Float range 0.0 .. 1000.0 := 200.0;
      Iterm_Limit                : Float range 0.0 .. 1001.0 := 0.0;
      Iterm_Limit_Yaw            : Float range 0.0 .. 1001.0 := 0.0;
      Iterm_Rotation             : Boolean := False;
      Iterm_Relax                : Iterm_Relax_Mode := Off;
      Iterm_Relax_Type           : Iterm_Relax_Source := Setpoint;
      Iterm_Relax_Cutoff         : Natural range 1 .. 50 := 15;
      Acro_Trainer_Angle_Limit   : Float range 10.0 .. 80.0 := 20.0;
      Acro_Trainer_Lookahead     : Float range 0.01 .. 0.2 := 0.05;
      Acro_Trainer_Debug_Axis    : Natural range 0 .. 1 := 0;
      Acro_Trainer_Gain          : Float range 2.5 .. 25.5 := 7.5;
      Dyn_LPF_Filter             : Dyn_Lowpass := None;
      Dyn_LPF_Min                : Hertz := 0;
      Dyn_LPF_Max                : Hertz := 0;
      Dyn_LPF_Curve_Expo         : Natural range 0 .. 10 := 0;
      Launch_Control             : Launch_Control_Mode := Normal;
      Launch_Control_Angle_Limit : Natural range 0 .. 80 := 0;
      Launch_Control_Ki          : Float range 0.0 .. 49.0 := 0.0;
      Thrust_Linearization       : Float range 0.0 .. 1.5 := 0.0;
      D_Max_Percent              : Axis_Ratios := (others => 1.0);
      D_Max_Gyro_Gain            : Float range 0.0 .. 0.00023 := 0.0;
      D_Max_Setpoint_Gain        : Float range 0.0 .. 0.00046 := 0.0;
      Feedforward_Transition     : Float range 0.0 .. 1.0 := 0.0;
      Feedforward_Transition_Inv : Float range 0.0 .. 100.0 := 0.0;
      Feedforward_Average        : Feedforward_Averaging := Off;
      Feedforward_Smooth_Factor  : Float range 0.0 .. 0.08 := 0.0;
      Feedforward_Jitter_Factor  : Natural range 0 .. 20 := 0;
      Feedforward_Jitter_Factor_Inv : Float range 0.047 .. 1.0 := 1.0;
      Feedforward_Boost_Factor   : Float range 0.0 .. 0.05 := 0.0;
      Feedforward_Max_Rate_Limit : Natural range 0 .. 200 := 0;
      Feedforward_Interpolate    : Boolean := True;
      Feedforward_Yaw_Hold_Time  : Float range 0.01 .. 0.25 := 0.1;
      Feedforward_Yaw_Hold_Gain  : Float range 0.0 .. 250.0 := 0.0;
      Level_Race_Mode            : Boolean := False;
      TPA_Breakpoint             : Float range 0.0 .. 0.99 := 0.35;
      TPA_Multiplier             : Float range 0.0 .. 101.0 := 0.0;
      TPA_Low_Breakpoint         : Float range 0.0 .. 1.0 := 0.05;
      TPA_Low_Multiplier         : Float range -1281.0 .. 1281.0 := 0.0;
      TPA_Low_Always             : Boolean := False;
      TPA_Curve_Type             : TPA_Curve_Kind := Classic;
      TPA_Curve                  : PWL.Table;
      Use_Ez_Disarm              : Boolean := False;
      Landing_Disarm_Threshold   : Float range 0.0 .. 2500.0 := 0.0;
      Throttle_Boost             : Float range 0.0 .. 10.0 := 0.5;
      Wing_Build                 : Boolean := False;
      Fixed_Wing                 : Boolean := False;
      TPA_Speed                  : TPA_Speed_Model;
   end record;

   --  Derives the runtime constants. Has_Acc enables the launch control
   --  angle limit; Serial_Rx_Is_CRSF selects feedforward interpolation; a
   --  wing build adds the airspeed model.
   procedure Configure
     (R : out Runtime; P : Profile; Loop_Time : Loop_Time_Us;
      Has_Acc : Boolean; Serial_Rx_Is_CRSF : Boolean; Wing : Wing_Setup := No_Wing);

end Adaflight.PID_Config;
