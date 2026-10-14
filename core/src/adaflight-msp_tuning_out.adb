package body Adaflight.MSP_Tuning_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Integer_32;

   function Low_Byte (V : Unsigned_16) return Unsigned_8 is (Unsigned_8 (V mod 256));

   function Word (V : Integer_32) return Unsigned_16 is (Unsigned_16 (V mod 65_536));

   function Word (V : Integer_16) return Unsigned_16 is (Unsigned_16 (Integer_32 (V) mod 65_536));

   function Byte_Of (V : Integer_8) return Unsigned_8 is (Unsigned_8 (Integer_32 (V) mod 256));

   function Built (On : Boolean; V : Unsigned_8) return Unsigned_8 is (if On then V else 0);

   function Built (On : Boolean; V : Unsigned_16) return Unsigned_16 is (if On then V else 0);

   procedure RC_Tuning (B : in out Byte_Array; S : in out Stream; R : Rate_Profile)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 24 and then S.Last = S.Last'Old
   is
   begin
      Write_U8 (B, S, R.RC_Rates (1));
      Write_U8 (B, S, R.RC_Expo (1));
      for Rate of R.Rates loop
         Write_U8 (B, S, Rate);
      end loop;
      Write_U8 (B, S, 0);
      Write_U8 (B, S, R.Throttle_Mid);
      Write_U8 (B, S, R.Throttle_Expo);
      Write_U16 (B, S, 0);
      Write_U8 (B, S, R.RC_Expo (3));
      Write_U8 (B, S, R.RC_Rates (3));
      Write_U8 (B, S, R.RC_Rates (2));
      Write_U8 (B, S, R.RC_Expo (2));
      Write_U8 (B, S, R.Throttle_Limit_Type);
      Write_U8 (B, S, R.Throttle_Limit_Percent);
      for Limit of R.Rate_Limit loop
         Write_U16 (B, S, Limit);
      end loop;
      Write_U8 (B, S, R.Rates_Type);
      Write_U8 (B, S, R.Throttle_Hover);
   end RC_Tuning;

   procedure Advanced_Config (B : in out Byte_Array; S : in out Stream; V : Snapshot)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 20 and then S.Last = S.Last'Old
   is
   begin
      Write_U8 (B, S, 1);
      Write_U8 (B, S, V.Motor.PID_Process_Denom);
      Write_U8 (B, S, V.Motor.Continuous_Update);
      Write_U8 (B, S, V.Motor.Protocol);
      Write_U16 (B, S, V.Motor.PWM_Rate);
      Write_U16 (B, S, V.Motor.Idle);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, V.Motor.Inversion);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, V.Gyro.High_FSR);
      Write_U8 (B, S, V.Gyro.Movement_Calibration_Threshold);
      Write_U16 (B, S, V.Gyro.Calibration_Duration);
      Write_U16 (B, S, Word (V.Gyro.Offset_Yaw));
      Write_U8 (B, S, V.Gyro.Check_Overflow);
      Write_U8 (B, S, V.Debug_Mode);
      Write_U8 (B, S, V.Debug_Mode_Count);
   end Advanced_Config;

   procedure Filter_Config (B : in out Byte_Array; S : in out Stream; V : Snapshot)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 56 and then S.Last = S.Last'Old
   is
      G : Gyro_Values renames V.Gyro;
      P : PID_Profile renames V.PID;
      N : Notch_Values renames V.Notches;
   begin
      Write_U8 (B, S, Low_Byte (G.LPF1_Static_Hz));
      Write_U16 (B, S, P.Dterm_LPF1_Static_Hz);
      Write_U16 (B, S, P.Yaw_Lowpass_Hz);
      Write_U16 (B, S, G.Notch_Hz_1);
      Write_U16 (B, S, G.Notch_Cutoff_1);
      Write_U16 (B, S, P.Dterm_Notch_Hz);
      Write_U16 (B, S, P.Dterm_Notch_Cutoff);
      Write_U16 (B, S, G.Notch_Hz_2);
      Write_U16 (B, S, G.Notch_Cutoff_2);
      Write_U8 (B, S, P.Dterm_LPF1_Type);
      Write_U8 (B, S, G.Hardware_LPF);
      Write_U8 (B, S, 0);
      Write_U16 (B, S, G.LPF1_Static_Hz);
      Write_U16 (B, S, G.LPF2_Static_Hz);
      Write_U8 (B, S, G.LPF1_Type);
      Write_U8 (B, S, G.LPF2_Type);
      Write_U16 (B, S, P.Dterm_LPF2_Static_Hz);
      Write_U8 (B, S, P.Dterm_LPF2_Type);
      Write_U16 (B, S, Built (V.Build.Dyn_LPF, G.LPF1_Dyn_Min_Hz));
      Write_U16 (B, S, Built (V.Build.Dyn_LPF, G.LPF1_Dyn_Max_Hz));
      Write_U16 (B, S, Built (V.Build.Dyn_LPF, P.Dterm_LPF1_Dyn_Min_Hz));
      Write_U16 (B, S, Built (V.Build.Dyn_LPF, P.Dterm_LPF1_Dyn_Max_Hz));
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U16 (B, S, Built (V.Build.Dyn_Notch, N.Dyn_Notch_Q));
      Write_U16 (B, S, Built (V.Build.Dyn_Notch, N.Dyn_Notch_Min_Hz));
      Write_U8 (B, S, Built (V.Build.RPM_Filter, N.RPM_Harmonics));
      Write_U8 (B, S, Built (V.Build.RPM_Filter, N.RPM_Min_Hz));
      Write_U16 (B, S, Built (V.Build.Dyn_Notch, N.Dyn_Notch_Max_Hz));
      Write_U8 (B, S, Built (V.Build.Dyn_LPF, P.Dterm_LPF1_Dyn_Expo));
      Write_U8 (B, S, Built (V.Build.Dyn_Notch, N.Dyn_Notch_Count));
      Write_U16 (B, S, Built (V.Build.RPM_Filter, N.RPM_Fade_Range_Hz));
      Write_U16 (B, S, Built (V.Build.RPM_Filter, N.RPM_Q));
      for Weight of N.RPM_Weights loop
         Write_U8 (B, S, Built (V.Build.RPM_Filter, Weight));
      end loop;
   end Filter_Config;

   procedure PID_Advanced (B : in out Byte_Array; S : in out Stream; V : Snapshot)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 61 and then S.Last = S.Last'Old
   is
      P  : PID_Profile renames V.PID;
      O  : Build_Options renames V.Build;
      FF : constant Boolean := O.Feedforward;
   begin
      Write_U16 (B, S, 0);
      Write_U16 (B, S, 0);
      Write_U16 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Built (FF, P.Feedforward_Transition));
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U16 (B, S, P.Rate_Accel_Limit);
      Write_U16 (B, S, P.Yaw_Rate_Accel_Limit);
      Write_U8 (B, S, P.Angle_Limit);
      Write_U8 (B, S, 0);
      Write_U16 (B, S, 0);
      Write_U16 (B, S, Unsigned_16 (P.Anti_Gravity_Gain));
      Write_U16 (B, S, 0);
      Write_U8 (B, S, P.Iterm_Rotation);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Built (O.Iterm_Relax, P.Iterm_Relax));
      Write_U8 (B, S, Built (O.Iterm_Relax, P.Iterm_Relax_Type));
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Built (O.Throttle_Boost, P.Throttle_Boost));
      Write_U8 (B, S, Built (O.Acro_Trainer, P.Acro_Trainer_Angle_Limit));
      for Axis in 1 .. Axis_Count loop
         Write_U16 (B, S, P.Gains (Axis).F);
      end loop;
      Write_U8 (B, S, 0);
      for Axis in 1 .. Axis_Count loop
         Write_U8 (B, S, Built (O.D_Max, P.D_Max (Axis)));
      end loop;
      Write_U8 (B, S, Built (O.D_Max, P.D_Max_Gain));
      Write_U8 (B, S, Built (O.D_Max, P.D_Max_Advance));
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Built (O.Iterm_Relax, P.Iterm_Relax_Cutoff));
      Write_U8 (B, S, P.Motor_Output_Limit);
      Write_U8 (B, S, Byte_Of (P.Auto_Profile_Cell_Count));
      Write_U8 (B, S, Built (O.Dyn_Idle, P.Dyn_Idle_Min_RPM));
      Write_U8 (B, S, Built (FF, P.Feedforward_Averaging));
      Write_U8 (B, S, Built (FF, P.Feedforward_Smooth_Factor));
      Write_U8 (B, S, Built (FF, P.Feedforward_Boost));
      Write_U8 (B, S, Built (FF, P.Feedforward_Max_Rate_Limit));
      Write_U8 (B, S, Built (FF, P.Feedforward_Jitter_Factor));
      Write_U8 (B, S, Built (O.Sag_Compensation, P.Sag_Compensation));
      Write_U8 (B, S, Built (O.Thrust_Linearization, P.Thrust_Linearization));
      Write_U8 (B, S, P.TPA_Mode);
      Write_U8 (B, S, P.TPA_Rate);
      Write_U16 (B, S, P.TPA_Breakpoint);
   end PID_Advanced;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      case Command is
         when Board_Alignment_Config_Command =>
            Write_U16 (B, S, Word (V.Board_Roll));
            Write_U16 (B, S, Word (V.Board_Pitch));
            Write_U16 (B, S, Word (V.Board_Yaw));
         when Arming_Config_Command =>
            Write_U8 (B, S, V.Auto_Disarm_Delay);
            Write_U8 (B, S, 0);
            Write_U8 (B, S, V.Small_Angle);
            Write_U8 (B, S, V.Gyro_Cal_On_First_Arm);
         when RC_Tuning_Command =>
            RC_Tuning (B, S, V.Rates);
         when PID_Command =>
            for G of V.PID.Gains loop
               Write_U8 (B, S, G.P);
               Write_U8 (B, S, G.I);
               Write_U8 (B, S, G.D);
            end loop;
         when PID_Names_Command =>
            Write_String (B, S, PID_Names);
         when PID_Controller_Command =>
            Write_U8 (B, S, PID_Controller);
         when Motor_3D_Config_Command =>
            Write_U16 (B, S, V.Deadband_3D_Low);
            Write_U16 (B, S, V.Deadband_3D_High);
            Write_U16 (B, S, V.Neutral_3D);
         when RC_Deadband_Command =>
            Write_U8 (B, S, V.Deadband);
            Write_U8 (B, S, V.Yaw_Deadband);
            Write_U8 (B, S, Built (V.Build.Position_Hold, V.Pos_Hold_Deadband));
            Write_U16 (B, S, V.Deadband_3D_Throttle);
         when Sensor_Alignment_Command =>
            Write_U8 (B, S, V.Gyro.Alignment);
            Write_U8 (B, S, V.Gyro.Alignment);
            Write_U8 (B, S, Built (V.Build.Mag, V.Mag_Alignment));
            Write_U8 (B, S, V.Gyro.Detected_Flags);
            Write_U8 (B, S, V.Gyro.Enabled_Bitmask);
            for Angle of V.Mag_Custom_Alignment loop
               Write_U16 (B, S, (if V.Build.Mag then Word (Angle) else 0));
            end loop;
         when Advanced_Config_Command =>
            Advanced_Config (B, S, V);
         when Filter_Config_Command =>
            Filter_Config (B, S, V);
         when PID_Advanced_Command =>
            PID_Advanced (B, S, V);
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Tuning_Out;
