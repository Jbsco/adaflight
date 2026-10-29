--  The control loop on the board: the rate controller, the mixer and the
--  servo mixer with their settings from the stored configuration, run as the
--  PID loop pass over the units in the task's order, with the mix written to
--  the motors and the servos.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Axes;
with Adaflight.Config_Groups;
with Adaflight.Mixer;
with Adaflight.MSP_Motor_In;
with Adaflight.PID_Controller;
with Adaflight.RC_Command;
with Adaflight.Servo_Mixer;
package Adaflight.STM32.Control is
   subtype Time_Us is Interfaces.Unsigned_32;
   --  What the pass reads from the board: the time, the arming, the
   --  accelerometer, the failsafe and the 3D switch, the filtered rates with
   --  the gyro's overflow and yaw spin detections, the attitude with the
   --  level trims, the tilt and the throttle correction, the accelerometer's
   --  jerk, the receiver's throttle channel, the autopilot's throttle with
   --  whether the altitude estimate is below its landing altitude, and the
   --  autopilot's angles with their limit and whether it holds the position.
   type Inputs is record
      Now_Us              : Time_Us := 0;
      Armed               : Boolean := False;
      Acc_Present         : Boolean := False;
      Failsafe            : Boolean := False;
      Box_3D              : Boolean := False;
      Gyro                : Adaflight.PID_Controller.Axis_Rates := (others => 0.0);
      Gyro_Overflow       : Boolean := False;
      Yaw_Spin            : Boolean := False;
      Attitude            : Adaflight.PID_Controller.Level_Angles := (others => 0);
      Trims               : Adaflight.PID_Controller.Level_Trims := (others => 0);
      Cos_Tilt            : Float := 1.0;
      Throttle_Correction : Integer := 0;
      Jerk_Magnitude      : Float := 0.0;
      RC_Data_Throttle    : Float := 1_000.0;
      Autopilot_Throttle  : Float range 0.0 .. 1.0 := 0.0;
      Below_Landing       : Boolean := False;
      Autopilot_Angles    : Adaflight.PID_Controller.Autopilot_Angles := (others => 0.0);
      Autopilot_Max_Angle : Natural range 0 .. 90 := 50;
      Autopilot_Control   : Boolean := False;
      --  The battery's display voltage, sag-filtered cell voltage and latest
      --  voltage in hundredths of a volt.
      Battery_Voltage     : Interfaces.Unsigned_16 := 0;
      Sag_Cell_Voltage    : Natural range 0 .. 65_535 := 0;
      Battery_Latest      : Natural range 0 .. 65_535 := 0;
   end record;
   --  The settings from the configuration over the pilot's selected
   --  profiles; the states start over.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Battery_Voltage : Interfaces.Unsigned_16 := 0);
   --  The servo mixer's setup over the configuration and the build's
   --  features with the receiver's channel count at the PID loop's period in
   --  microseconds, then the servo outputs when the mixer drives servos.
   procedure Init_Servos
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Channel_Count : Natural; Loop_Time_Us : Positive);
   --  The servo mixer's settings the configuration changes while it runs:
   --  the servo parameters, the tricopter's unarmed servo, the first channel
   --  forwarded, the lowpass cutoff, the mixed tilt and the receiver's middle
   --  and aux channel count.
   procedure Set_Servo_Config (Config : Adaflight.Config_Groups.Configuration);
   --  The custom servo rules as the servo mixer's rules, which an MSP servo
   --  rule write asks for.
   procedure Load_Servo_Rules (Rules : Adaflight.Config_Groups.Servo_Mixer_Record_List_16);
   --  Whether the mixer drives servos, and a servo's value, which the MSP
   --  servo reply and the flight log read.
   function Uses_Servos return Boolean;
   function Servo (Index : Adaflight.Servo_Mixer.Servo_Index) return Interfaces.Integer_16;
   --  The values the motors take while disarmed, which the motor test of the
   --  MSP and the command line sets: all of them back to the disarm output,
   --  each motor of the mix from a request, one motor or every motor of the
   --  mix, and whether the motors run, armed or under the test.
   procedure Reset_Disarmed;
   procedure Set_Disarmed (Values : Adaflight.MSP_Motor_In.Motor_Values);
   procedure Set_Disarmed_Motor (Index : Natural; Value : Float);
   procedure Set_Disarmed_All (Value : Float);
   function Motors_Running return Boolean;
   --  Every motor of the mix at the disarm output, written to the motors,
   --  then a 50 ms wait for the timers and ESCs, which a reboot from the
   --  menus does first.
   procedure Stop_Motors;
   --  The RPM limiter's reset when a battery connects.
   procedure Reset_RPM_Limiter (Battery_Voltage : Interfaces.Unsigned_16);
   --  The mixer's throttle, which the virtual current meter reads.
   function Throttle return Float;
   --  What the arming's receiver pass asked of the controller: the
   --  stabilisation state and the zero throttle I term reset, kept until the
   --  next receiver pass.
   procedure Set_Stabilisation (Enabled : Boolean; Iterm_Reset : Boolean);
   --  What the arming's modes pass asked: the anti-gravity state.
   procedure Set_Anti_Gravity (Enabled : Boolean);
   --  One PID loop pass: the yaw reset when the sticks ask for it, the RC
   --  command, the controller with the runaway check, the mix, and the
   --  servos when the mixer drives them, with the flight log and the PID
   --  audio as the pass's conditions name them; Asked is what the runaway
   --  check asked.
   procedure Pass
     (I : Inputs; Sensed : Adaflight.Arming.Inputs; Channels : Adaflight.RC_Command.Channel_Values;
      Resets_Yaw, Log_Device, CLI_Open, PID_Audio : Boolean; Asked : out Adaflight.Arming.Outputs);
   --  Whether the mixer's throttle step changed on the last pass, which
   --  moves the gyro's dynamic lowpass, and the throttle it moved to.
   function Throttle_Step_Changed return Boolean;
   function Throttle_Step return Float;
   function Motors return Adaflight.Mixer.Motor_Outputs;
   function Motor_Count return Natural;
   --  What the flight log reads: the controller's terms and its last
   --  setpoint per axis, and the mixer's motor output range.
   function Terms (A : Adaflight.Axes.Axis) return Adaflight.PID_Controller.Terms;
   function Previous_Setpoint (A : Adaflight.Axes.Axis) return Float;
   function Output_Low return Float;
   function Disarm_Output return Float;
   function Output_High return Float;
   --  Whether the controller's crash recovery runs, which the failsafe reads.
   function Crash_Recovery_Active return Boolean;
   function PID_Sums return Adaflight.Arming.Axis_Sums;
end Adaflight.STM32.Control;
