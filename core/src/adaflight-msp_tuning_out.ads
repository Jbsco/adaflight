--  The MSP out messages that report the tuning: the PID gains with their
--  names and controller, the rate profile, the advanced, filter and advanced
--  PID configuration, the board and sensor alignment, the arming
--  configuration, the 3D throttle and the stick deadbands. The caller
--  gathers the active profiles, the configuration and the build's options
--  into a snapshot. Each reply narrows its values to the field widths of
--  the protocol by wrapping, as the first gyro cutoff in one byte and the
--  board alignment in sixteen bits, and a value its option leaves out of
--  the build goes out as zero.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;

package Adaflight.MSP_Tuning_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Board_Alignment_Config_Command : constant := 38;
   PID_Controller_Command         : constant := 59;
   Arming_Config_Command          : constant := 61;
   Advanced_Config_Command        : constant := 90;
   Filter_Config_Command          : constant := 92;
   PID_Advanced_Command           : constant := 94;
   RC_Tuning_Command              : constant := 111;
   PID_Command                    : constant := 112;
   PID_Names_Command              : constant := 117;
   Motor_3D_Config_Command        : constant := 124;
   RC_Deadband_Command            : constant := 125;
   Sensor_Alignment_Command       : constant := 126;

   PID_Controller   : constant := 1;
   PID_Names        : constant String := "ROLL;PITCH;YAW;LEVEL;MAG;";
   PID_Item_Count   : constant := 5;
   Axis_Count       : constant := 3;
   RPM_Harmonics    : constant := 3;
   Max_Reply_Length : constant := 64;

   type Axis_Bytes is array (1 .. Axis_Count) of Unsigned_8;
   type Axis_Words is array (1 .. Axis_Count) of Unsigned_16;
   type Axis_Alignment is array (1 .. Axis_Count) of Integer_16;
   type Harmonic_Weights is array (1 .. RPM_Harmonics) of Unsigned_8;

   --  The gains of one PID item; F applies to roll, pitch and yaw.
   type Gains is record
      P, I, D : Unsigned_8 := 0;
      F       : Unsigned_16 := 0;
   end record;
   --  Roll, pitch, yaw, level and heading.
   type Gain_Set is array (1 .. PID_Item_Count) of Gains;

   --  The options built in that the replies report.
   type Build_Options is record
      Feedforward          : Boolean := False;
      Iterm_Relax          : Boolean := False;
      Throttle_Boost       : Boolean := False;
      Acro_Trainer         : Boolean := False;
      D_Max                : Boolean := False;
      Dyn_Idle             : Boolean := False;
      Sag_Compensation     : Boolean := False;
      Thrust_Linearization : Boolean := False;
      Dyn_LPF              : Boolean := False;
      Dyn_Notch            : Boolean := False;
      RPM_Filter           : Boolean := False;
      Position_Hold        : Boolean := False;
      Mag                  : Boolean := False;
   end record;

   --  The PID profile in use.
   type PID_Profile is record
      Gains                      : Gain_Set;
      Dterm_LPF1_Static_Hz       : Unsigned_16 := 0;
      Yaw_Lowpass_Hz             : Unsigned_16 := 0;
      Dterm_Notch_Hz             : Unsigned_16 := 0;
      Dterm_Notch_Cutoff         : Unsigned_16 := 0;
      Dterm_LPF1_Type            : Unsigned_8 := 0;
      Dterm_LPF2_Static_Hz       : Unsigned_16 := 0;
      Dterm_LPF2_Type            : Unsigned_8 := 0;
      Dterm_LPF1_Dyn_Min_Hz      : Unsigned_16 := 0;
      Dterm_LPF1_Dyn_Max_Hz      : Unsigned_16 := 0;
      Dterm_LPF1_Dyn_Expo        : Unsigned_8 := 0;
      Feedforward_Transition     : Unsigned_8 := 0;
      Rate_Accel_Limit           : Unsigned_16 := 0;
      Yaw_Rate_Accel_Limit       : Unsigned_16 := 0;
      Angle_Limit                : Unsigned_8 := 0;
      Anti_Gravity_Gain          : Unsigned_8 := 0;
      Iterm_Rotation             : Unsigned_8 := 0;
      Iterm_Relax                : Unsigned_8 := 0;
      Iterm_Relax_Type           : Unsigned_8 := 0;
      Iterm_Relax_Cutoff         : Unsigned_8 := 0;
      Throttle_Boost             : Unsigned_8 := 0;
      Acro_Trainer_Angle_Limit   : Unsigned_8 := 0;
      D_Max                      : Axis_Bytes := (others => 0);
      D_Max_Gain                 : Unsigned_8 := 0;
      D_Max_Advance              : Unsigned_8 := 0;
      Motor_Output_Limit         : Unsigned_8 := 0;
      Auto_Profile_Cell_Count    : Integer_8 := 0;
      Dyn_Idle_Min_RPM           : Unsigned_8 := 0;
      Feedforward_Averaging      : Unsigned_8 := 0;
      Feedforward_Smooth_Factor  : Unsigned_8 := 0;
      Feedforward_Boost          : Unsigned_8 := 0;
      Feedforward_Max_Rate_Limit : Unsigned_8 := 0;
      Feedforward_Jitter_Factor  : Unsigned_8 := 0;
      Sag_Compensation           : Unsigned_8 := 0;
      Thrust_Linearization       : Unsigned_8 := 0;
      TPA_Mode                   : Unsigned_8 := 0;
      TPA_Rate                   : Unsigned_8 := 0;
      TPA_Breakpoint             : Unsigned_16 := 0;
   end record;

   --  The rate profile in use, roll, pitch and yaw.
   type Rate_Profile is record
      RC_Rates               : Axis_Bytes := (others => 0);
      RC_Expo                : Axis_Bytes := (others => 0);
      Rates                  : Axis_Bytes := (others => 0);
      Throttle_Mid           : Unsigned_8 := 0;
      Throttle_Expo          : Unsigned_8 := 0;
      Throttle_Limit_Type    : Unsigned_8 := 0;
      Throttle_Limit_Percent : Unsigned_8 := 0;
      Rate_Limit             : Axis_Words := (others => 0);
      Rates_Type             : Unsigned_8 := 0;
      Throttle_Hover         : Unsigned_8 := 0;
   end record;

   --  The gyro configuration, the first enabled gyro's alignment and the
   --  gyros detected.
   type Gyro_Values is record
      LPF1_Static_Hz                 : Unsigned_16 := 0;
      LPF2_Static_Hz                 : Unsigned_16 := 0;
      Notch_Hz_1                     : Unsigned_16 := 0;
      Notch_Cutoff_1                 : Unsigned_16 := 0;
      Notch_Hz_2                     : Unsigned_16 := 0;
      Notch_Cutoff_2                 : Unsigned_16 := 0;
      Hardware_LPF                   : Unsigned_8 := 0;
      LPF1_Type                      : Unsigned_8 := 0;
      LPF2_Type                      : Unsigned_8 := 0;
      LPF1_Dyn_Min_Hz                : Unsigned_16 := 0;
      LPF1_Dyn_Max_Hz                : Unsigned_16 := 0;
      High_FSR                       : Unsigned_8 := 0;
      Movement_Calibration_Threshold : Unsigned_8 := 0;
      Calibration_Duration           : Unsigned_16 := 0;
      Offset_Yaw                     : Integer_16 := 0;
      Check_Overflow                 : Unsigned_8 := 0;
      Enabled_Bitmask                : Unsigned_8 := 0;
      Alignment                      : Unsigned_8 := 0;
      Detected_Flags                 : Unsigned_8 := 0;
   end record;

   --  The dynamic notch and the RPM filter.
   type Notch_Values is record
      Dyn_Notch_Q       : Unsigned_16 := 0;
      Dyn_Notch_Min_Hz  : Unsigned_16 := 0;
      Dyn_Notch_Max_Hz  : Unsigned_16 := 0;
      Dyn_Notch_Count   : Unsigned_8 := 0;
      RPM_Harmonics     : Unsigned_8 := 0;
      RPM_Min_Hz        : Unsigned_8 := 0;
      RPM_Fade_Range_Hz : Unsigned_16 := 0;
      RPM_Q             : Unsigned_16 := 0;
      RPM_Weights       : Harmonic_Weights := (others => 0);
   end record;

   --  The PID loop's divider and the motor output.
   type Motor_Values is record
      PID_Process_Denom : Unsigned_8 := 0;
      Continuous_Update : Unsigned_8 := 0;
      Protocol          : Unsigned_8 := 0;
      PWM_Rate          : Unsigned_16 := 0;
      Idle              : Unsigned_16 := 0;
      Inversion         : Unsigned_8 := 0;
   end record;

   type Snapshot is record
      Build                 : Build_Options;
      PID                   : PID_Profile;
      Rates                 : Rate_Profile;
      Gyro                  : Gyro_Values;
      Notches               : Notch_Values;
      Motor                 : Motor_Values;
      Debug_Mode            : Unsigned_8 := 0;
      Debug_Mode_Count      : Unsigned_8 := 0;
      Auto_Disarm_Delay     : Unsigned_8 := 0;
      Small_Angle           : Unsigned_8 := 0;
      Gyro_Cal_On_First_Arm : Unsigned_8 := 0;
      Board_Roll            : Interfaces.Integer_32 := 0;
      Board_Pitch           : Interfaces.Integer_32 := 0;
      Board_Yaw             : Interfaces.Integer_32 := 0;
      Deadband_3D_Low       : Unsigned_16 := 0;
      Deadband_3D_High      : Unsigned_16 := 0;
      Neutral_3D            : Unsigned_16 := 0;
      Deadband_3D_Throttle  : Unsigned_16 := 0;
      Deadband              : Unsigned_8 := 0;
      Yaw_Deadband          : Unsigned_8 := 0;
      Pos_Hold_Deadband     : Unsigned_8 := 0;
      Mag_Alignment         : Unsigned_8 := 0;
      Mag_Custom_Alignment  : Axis_Alignment := (others => 0);
   end record;

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in Board_Alignment_Config_Command | PID_Controller_Command | Arming_Config_Command
               | Advanced_Config_Command | Filter_Config_Command | PID_Advanced_Command | RC_Tuning_Command
               | PID_Command | PID_Names_Command | Motor_3D_Config_Command | RC_Deadband_Command
               | Sensor_Alignment_Command);

   --  The reply to one of these out messages; any other command writes
   --  nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Handles (Command) then S.Next = S.Next'Old);

end Adaflight.MSP_Tuning_Out;
