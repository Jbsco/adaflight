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
   end record
     with Dynamic_Predicate =>
       Config.Output_Low < Config.Output_High and then Config.Disarm_Output <= Config.Output_High;

   subtype RC_Throttle_Value is Float range 1000.0 .. 2000.0;

   type Inputs is record
      RC_Throttle               : RC_Throttle_Value := 1000.0;
      Throttle_Angle_Correction : Integer range -1000 .. 1000 := 0;
      Time_Us                   : Unsigned_32 := 0;
      Armed                     : Boolean := False;
      Airmode                   : Boolean := False;
      Failsafe                  : Boolean := False;
      Max_Deflection            : Unit_Interval := 0.0;
      Speed                     : Float range 0.0 .. 1000.0 := 0.0;
   end record;

   type State is record
      Motors                  : Motor_Outputs := (others => 0.0);
      Throttle                : Unit_Interval := 0.0;
      RC_Throttle             : Unit_Interval := 0.0;
      Mix_Range               : Signal := 0.0;
      Dyn_LPF_Last_Update_Us  : Unsigned_32 := 0;
      Dyn_LPF_Previous_Step   : Integer range -1 .. Dyn_LPF_Throttle_Steps := -1;
   end record;

   --  One loop of the mixer after the controller, with the throttle-side
   --  updates the controller and filters take from the mixer.
   procedure Update
     (S   : in out State; C : Config; Ctl : in out PID_Controller.State;
      R   : Runtime; P : Profile; Inp : Inputs)
     with Post =>
       (for all M in 0 .. C.Count - 1 =>
          S.Motors (M) in Float'Min (C.Disarm_Output, C.Output_Low) .. C.Output_High);

end Adaflight.Mixer;
