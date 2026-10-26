with Adaflight.Config_Fix;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Format;
with Adaflight.OSD_Stats;
with Adaflight.Settings_Table;

package body Adaflight.MSP_Views with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   --  The characters of a stored name up to its first zero byte.
   function To_Text (B : Bytes) return MSP_Text_Out.Text is
      T : MSP_Text_Out.Text;
   begin
      for K in B'Range loop
         pragma Loop_Invariant (T.Length = K - B'First);
         exit when B (K) = 0 or else T.Length = MSP_Text_Out.Max_Text;
         T.Length := T.Length + 1;
         T.Data (T.Length) := Character'Val (B (K));
      end loop;
      return T;
   end To_Text;

   function Box_Names (C : Configuration) return MSP_Box.User_Names is
      N : MSP_Box.User_Names;
   begin
      for B in N'Range loop
         declare
            Index  : constant Natural := MSP_Box.User_Box'Pos (B) - MSP_Box.User_Box'Pos (MSP_Box.User_Box'First);
            Stored : Bytes_16 renames C.Mode_Activation_Config.Box_User_Names (Index);
         begin
            for K in Stored'Range loop
               pragma Loop_Invariant (N (B).Length = K);
               exit when Stored (K) = 0;
               N (B).Length := K + 1;
               N (B).Text (K + 1) := Character'Val (Stored (K));
            end loop;
         end;
      end loop;
      return N;
   end Box_Names;

   function Mode_Conditions (C : Configuration) return Modes.Conditions is
      R : Modes.Conditions := (others => Modes.Empty);
   begin
      for I in R'Range loop
         declare
            M : Mode_Activation_Condition_Record renames C.Mode_Activation_Conditions (I);
         begin
            if Natural (M.Mode_Id) <= Modes.Box'Pos (Modes.Box'Last)
              and then Natural (M.Linked_To) <= Modes.Box'Pos (Modes.Box'Last)
              and then Natural (M.Aux_Channel_Index) < Modes.Aux_Channel_Count
              and then Natural (M.Range_Value.Start_Step) <= Modes.Max_Range_Step
              and then Natural (M.Range_Value.End_Step) <= Modes.Max_Range_Step
              and then M.Mode_Logic <= 1
            then
               R (I) := (Mode      => Modes.Box'Val (M.Mode_Id),
                         Aux       => Natural (M.Aux_Channel_Index),
                         Span      => (Start_Step => Natural (M.Range_Value.Start_Step),
                                       End_Step   => Natural (M.Range_Value.End_Step)),
                         Combine   => Modes.Logic'Val (M.Mode_Logic),
                         Linked_To => Modes.Box'Val (M.Linked_To));
            end if;
         end;
      end loop;
      return R;
   end Mode_Conditions;

   function Adjustment_Ranges (C : Configuration) return Adjustments.Ranges is
      R : Adjustments.Ranges := (others => Adjustments.Unset);
   begin
      for I in R'Range loop
         declare
            A : Adjustment_Range_Record renames C.Adjustment_Ranges (I);
         begin
            if Natural (A.Adjustment_Config) <= Adjustments.Function_Kind'Pos (Adjustments.Function_Kind'Last)
              and then Natural (A.Aux_Channel_Index) < Modes.Aux_Channel_Count
              and then Natural (A.Aux_Switch_Channel_Index) < Modes.Aux_Channel_Count
              and then Natural (A.Range_Value.Start_Step) <= Modes.Max_Range_Step
              and then Natural (A.Range_Value.End_Step) <= Modes.Max_Range_Step
            then
               R (I) := (Aux        => Natural (A.Aux_Channel_Index),
                         Span       => (Start_Step => Natural (A.Range_Value.Start_Step),
                                        End_Step   => Natural (A.Range_Value.End_Step)),
                         Kind       => Adjustments.Function_Kind'Val (A.Adjustment_Config),
                         Switch_Aux => Natural (A.Aux_Switch_Channel_Index),
                         Center     => Natural (A.Adjustment_Center),
                         Scale      => Natural (A.Adjustment_Scale));
            end if;
         end;
      end loop;
      return R;
   end Adjustment_Ranges;

   function Channel_Map (C : Configuration) return Receiver.Channel_Map is
      M : Receiver.Channel_Map;
   begin
      for I in M'Range loop
         M (I) := (if Natural (C.Rx_Config.Rcmap (I)) < Receiver.Channel_Count
                   then Natural (C.Rx_Config.Rcmap (I)) else I);
      end loop;
      return M;
   end Channel_Map;

   function Failsafe_Channels (C : Configuration) return Receiver.Failsafe_Channels is
      F : Receiver.Failsafe_Channels;
   begin
      for I in F'Range loop
         declare
            S : Rx_Failsafe_Channel_Config_Record renames C.Rx_Failsafe_Channel_Configs (I);
         begin
            F (I) := (Mode => (if S.Mode <= 3 then Receiver.Failsafe_Mode'Val (S.Mode) else Receiver.Invalid),
                      Step => Natural'Min (Natural (S.Step), Receiver.Max_Failsafe_Step));
         end;
      end loop;
      return F;
   end Failsafe_Channels;

   function Tuning_View
     (C : Configuration; Build : MSP_Tuning_Out.Build_Options; Detected_Flags : Unsigned_8)
      return MSP_Tuning_Out.Snapshot
   is
      P  : Pid_Profile_Record renames C.Pid_Profiles (Natural (C.System_Config.Pid_Profile_Index));
      RP : Control_Rate_Config_Record renames C.Control_Rate_Profiles (Natural (C.System_Config.Active_Rate_Profile));
      G  : Gyro_Config_Record renames C.Gyro_Config;
      V  : MSP_Tuning_Out.Snapshot;
   begin
      V.Build := Build;
      for I in V.PID.Gains'Range loop
         V.PID.Gains (I) := (P => P.Pid (I - 1).P, I => P.Pid (I - 1).I, D => P.Pid (I - 1).D, F => P.Pid (I - 1).F);
      end loop;
      V.PID.Dterm_LPF1_Static_Hz := P.Dterm_Lpf1_Static_Hz;
      V.PID.Yaw_Lowpass_Hz := P.Yaw_Lowpass_Hz;
      V.PID.Dterm_Notch_Hz := P.Dterm_Notch_Hz;
      V.PID.Dterm_Notch_Cutoff := P.Dterm_Notch_Cutoff;
      V.PID.Dterm_LPF1_Type := P.Dterm_Lpf1_Type;
      V.PID.Dterm_LPF2_Static_Hz := P.Dterm_Lpf2_Static_Hz;
      V.PID.Dterm_LPF2_Type := P.Dterm_Lpf2_Type;
      V.PID.Dterm_LPF1_Dyn_Min_Hz := P.Dterm_Lpf1_Dyn_Min_Hz;
      V.PID.Dterm_LPF1_Dyn_Max_Hz := P.Dterm_Lpf1_Dyn_Max_Hz;
      V.PID.Dterm_LPF1_Dyn_Expo := P.Dterm_Lpf1_Dyn_Expo;
      V.PID.Feedforward_Transition := P.Feedforward_Transition;
      V.PID.Rate_Accel_Limit := P.Rate_Accel_Limit;
      V.PID.Yaw_Rate_Accel_Limit := P.Yaw_Rate_Accel_Limit;
      V.PID.Angle_Limit := P.Angle_Limit;
      V.PID.Anti_Gravity_Gain := P.Anti_Gravity_Gain;
      V.PID.Iterm_Rotation := P.Iterm_Rotation;
      V.PID.Iterm_Relax := P.Iterm_Relax;
      V.PID.Iterm_Relax_Type := P.Iterm_Relax_Type;
      V.PID.Iterm_Relax_Cutoff := P.Iterm_Relax_Cutoff;
      V.PID.Throttle_Boost := P.Throttle_Boost;
      V.PID.Acro_Trainer_Angle_Limit := P.Acro_Trainer_Angle_Limit;
      for A in V.PID.D_Max'Range loop
         V.PID.D_Max (A) := P.D_Max (A - 1);
      end loop;
      V.PID.D_Max_Gain := P.D_Max_Gain;
      V.PID.D_Max_Advance := P.D_Max_Advance;
      V.PID.Motor_Output_Limit := P.Motor_Output_Limit;
      V.PID.Auto_Profile_Cell_Count := P.Auto_Profile_Cell_Count;
      V.PID.Dyn_Idle_Min_RPM := P.Dyn_Idle_Min_Rpm;
      V.PID.Feedforward_Averaging := P.Feedforward_Averaging;
      V.PID.Feedforward_Smooth_Factor := P.Feedforward_Smooth_Factor;
      V.PID.Feedforward_Boost := P.Feedforward_Boost;
      V.PID.Feedforward_Max_Rate_Limit := P.Feedforward_Max_Rate_Limit;
      V.PID.Feedforward_Jitter_Factor := P.Feedforward_Jitter_Factor;
      V.PID.Sag_Compensation := P.Vbat_Sag_Compensation;
      V.PID.Thrust_Linearization := P.Thrust_Linearization;
      V.PID.TPA_Mode := P.Tpa_Mode;
      V.PID.TPA_Rate := P.Tpa_Rate;
      V.PID.TPA_Breakpoint := P.Tpa_Breakpoint;
      for A in V.Rates.RC_Rates'Range loop
         V.Rates.RC_Rates (A) := RP.Rc_Rates (A - 1);
         V.Rates.RC_Expo (A) := RP.Rc_Expo (A - 1);
         V.Rates.Rates (A) := RP.Rates (A - 1);
         V.Rates.Rate_Limit (A) := RP.Rate_Limit (A - 1);
      end loop;
      V.Rates.Throttle_Mid := RP.Thr_Mid8;
      V.Rates.Throttle_Expo := RP.Thr_Expo8;
      V.Rates.Throttle_Limit_Type := RP.Throttle_Limit_Type;
      V.Rates.Throttle_Limit_Percent := RP.Throttle_Limit_Percent;
      V.Rates.Rates_Type := RP.Rates_Type;
      V.Rates.Throttle_Hover := RP.Thr_Hover8;
      V.Gyro.LPF1_Static_Hz := G.Gyro_Lpf1_Static_Hz;
      V.Gyro.LPF2_Static_Hz := G.Gyro_Lpf2_Static_Hz;
      V.Gyro.Notch_Hz_1 := G.Gyro_Soft_Notch_Hz_1;
      V.Gyro.Notch_Cutoff_1 := G.Gyro_Soft_Notch_Cutoff_1;
      V.Gyro.Notch_Hz_2 := G.Gyro_Soft_Notch_Hz_2;
      V.Gyro.Notch_Cutoff_2 := G.Gyro_Soft_Notch_Cutoff_2;
      V.Gyro.Hardware_LPF := G.Gyro_Hardware_Lpf;
      V.Gyro.LPF1_Type := G.Gyro_Lpf1_Type;
      V.Gyro.LPF2_Type := G.Gyro_Lpf2_Type;
      V.Gyro.LPF1_Dyn_Min_Hz := G.Gyro_Lpf1_Dyn_Min_Hz;
      V.Gyro.LPF1_Dyn_Max_Hz := G.Gyro_Lpf1_Dyn_Max_Hz;
      V.Gyro.High_FSR := G.Gyro_High_Fsr;
      V.Gyro.Movement_Calibration_Threshold := G.Gyro_Movement_Calibration_Threshold;
      V.Gyro.Calibration_Duration := G.Gyro_Calibration_Duration;
      V.Gyro.Offset_Yaw := G.Gyro_Offset_Yaw;
      V.Gyro.Check_Overflow := G.Check_Overflow;
      V.Gyro.Enabled_Bitmask := G.Gyro_Enabled_Bitmask;
      V.Gyro.Alignment := C.Gyro_Device_Config (0).Alignment;
      V.Gyro.Detected_Flags := Detected_Flags;
      V.Notches.Dyn_Notch_Q := C.Dyn_Notch_Config.Dyn_Notch_Q;
      V.Notches.Dyn_Notch_Min_Hz := C.Dyn_Notch_Config.Dyn_Notch_Min_Hz;
      V.Notches.Dyn_Notch_Max_Hz := C.Dyn_Notch_Config.Dyn_Notch_Max_Hz;
      V.Notches.Dyn_Notch_Count := C.Dyn_Notch_Config.Dyn_Notch_Count;
      V.Notches.RPM_Harmonics := C.Rpm_Filter_Config.Rpm_Filter_Harmonics;
      V.Notches.RPM_Min_Hz := C.Rpm_Filter_Config.Rpm_Filter_Min_Hz;
      V.Notches.RPM_Fade_Range_Hz := C.Rpm_Filter_Config.Rpm_Filter_Fade_Range_Hz;
      V.Notches.RPM_Q := C.Rpm_Filter_Config.Rpm_Filter_Q;
      for H in V.Notches.RPM_Weights'Range loop
         V.Notches.RPM_Weights (H) := C.Rpm_Filter_Config.Rpm_Filter_Weights (H - 1);
      end loop;
      V.Motor.PID_Process_Denom := C.Pid_Config.Pid_Process_Denom;
      V.Motor.Continuous_Update := C.Motor_Config.Dev.Use_Continuous_Update;
      V.Motor.Protocol := C.Motor_Config.Dev.Motor_Protocol;
      V.Motor.PWM_Rate := C.Motor_Config.Dev.Motor_Pwm_Rate;
      V.Motor.Idle := C.Motor_Config.Motor_Idle;
      V.Motor.Inversion := C.Motor_Config.Dev.Motor_Inversion;
      V.Debug_Mode := C.System_Config.Debug_Mode;
      V.Debug_Mode_Count := Unsigned_8 (Natural'Min (Settings_Table.Value_Count (Settings_Table.Table_Debug), 255));
      V.Auto_Disarm_Delay := C.Arming_Config.Auto_Disarm_Delay;
      V.Small_Angle := C.Imu_Config.Small_Angle;
      V.Gyro_Cal_On_First_Arm := C.Arming_Config.Gyro_Cal_On_First_Arm;
      V.Board_Roll := C.Board_Alignment.Roll_Degrees;
      V.Board_Pitch := C.Board_Alignment.Pitch_Degrees;
      V.Board_Yaw := C.Board_Alignment.Yaw_Degrees;
      V.Deadband_3D_Low := C.Flight3_D_Config.Deadband3d_Low;
      V.Deadband_3D_High := C.Flight3_D_Config.Deadband3d_High;
      V.Neutral_3D := C.Flight3_D_Config.Neutral3d;
      V.Deadband_3D_Throttle := C.Flight3_D_Config.Deadband3d_Throttle;
      V.Deadband := C.Rc_Controls_Config.Deadband;
      V.Yaw_Deadband := C.Rc_Controls_Config.Yaw_Deadband;
      V.Pos_Hold_Deadband := C.Pos_Hold_Config.Deadband;
      V.Mag_Alignment := C.Compass_Config.Mag_Alignment;
      for A in V.Mag_Custom_Alignment'Range loop
         V.Mag_Custom_Alignment (A) := C.Compass_Config.Mag_Custom_Alignment (A - 1);
      end loop;
      return V;
   end Tuning_View;

   function Receiver_View (C : Configuration; O : Receiver_Options) return MSP_Receiver_Out.Snapshot is
      RX : Rx_Config_Record renames C.Rx_Config;
      FS : Failsafe_Config_Record renames C.Failsafe_Config;
      V  : MSP_Receiver_Out.Snapshot;
   begin
      V.Conditions := Mode_Conditions (C);
      V.Adjustments := Adjustment_Ranges (C);
      V.RX.Provider := RX.Serialrx_Provider;
      V.RX.Max_Check := RX.Maxcheck;
      V.RX.Mid_RC := RX.Midrc;
      V.RX.Min_Check := RX.Mincheck;
      V.RX.Spektrum_Sat_Bind := RX.Spektrum_Sat_Bind;
      V.RX.Min_Usec := RX.Rx_Min_Usec;
      V.RX.Max_Usec := RX.Rx_Max_Usec;
      V.RX.Airmode_Threshold := RX.Air_Mode_Activate_Threshold;
      V.RX.RX_SPI := O.RX_SPI;
      V.RX.SPI_Protocol := C.Rx_Spi_Config.Rx_Spi_Protocol;
      V.RX.SPI_Id := C.Rx_Spi_Config.Rx_Spi_Id;
      V.RX.SPI_Channel_Count := C.Rx_Spi_Config.Rx_Spi_Rf_Channel_Count;
      V.RX.FPV_Cam_Angle := RX.Fpv_Cam_Angle_Degrees;
      V.RX.RC_Smoothing := O.RC_Smoothing;
      V.RX.Setpoint_Cutoff := RX.Rc_Smoothing_Setpoint_Cutoff;
      V.RX.Throttle_Cutoff := RX.Rc_Smoothing_Throttle_Cutoff;
      V.RX.Auto_Factor_Throttle := RX.Rc_Smoothing_Auto_Factor_Throttle;
      V.RX.Auto_Factor_RPY := RX.Rc_Smoothing_Auto_Factor_Rpy;
      V.RX.Smoothing := RX.Rc_Smoothing;
      V.RX.USB_HID := O.USB_HID;
      V.RX.USB_Type := C.Usb_Dev_Config.Type_Value;
      V.RX.ExpressLRS := O.ExpressLRS;
      for K in V.RX.UID'Range loop
         V.RX.UID (K) := C.Rx_Express_Lrs_Spi_Config.Uid (K - 1);
      end loop;
      V.RX.Model_Id := C.Rx_Express_Lrs_Spi_Config.Model_Id;
      V.RX.RSSI_Channel := RX.Rssi_Channel;
      V.Map := Channel_Map (C);
      V.Failsafe := (Failsafe_Delay     => FS.Failsafe_Delay,
                     Landing_Time       => FS.Failsafe_Landing_Time,
                     Throttle           => FS.Failsafe_Throttle,
                     Switch_Mode        => FS.Failsafe_Switch_Mode,
                     Throttle_Low_Delay => FS.Failsafe_Throttle_Low_Delay,
                     Procedure_Kind     => FS.Failsafe_Procedure);
      V.Channels := Failsafe_Channels (C);
      V.Channel_Count := O.Channel_Count;
      return V;
   end Receiver_View;

   function Hardware_View (C : Configuration; R : Hardware_Runtime) return MSP_Hardware_Out.Snapshot is
      AP : Autopilot_Config_Record renames C.Autopilot_Config;
      GR : Gps_Rescue_Record renames C.Gps_Rescue_Config;
      V  : MSP_Hardware_Out.Snapshot;
   begin
      V.Mixer_Mode := C.Mixer_Config.Mixer_Mode;
      V.Yaw_Reversed := C.Mixer_Config.Yaw_Motors_Reversed;
      V.Motor := (Max_Throttle        => C.Motor_Config.Maxthrottle,
                  Min_Command         => C.Motor_Config.Mincommand,
                  Motor_Count         => R.Motor_Count,
                  Pole_Count          => C.Motor_Config.Motor_Pole_Count,
                  DShot_Telemetry     => R.DShot_Telemetry,
                  Use_DShot_Telemetry => R.Use_DShot_Telemetry,
                  ESC_Sensor          => R.ESC_Sensor,
                  ESC_Sensor_Feature  => (C.Feature_Config.Enabled_Features and 2 ** 27) /= 0,
                  KV                  => C.Motor_Config.Kv);
      V.Mag_Declination := C.Imu_Config.Mag_Declination;
      V.GPS := R.GPS;
      V.GPS_Provider := C.Gps_Config.Provider;
      V.SBAS_Mode := C.Gps_Config.Sbas_Mode;
      V.Auto_Config := C.Gps_Config.Auto_Config;
      V.Auto_Baud := C.Gps_Config.Auto_Baud;
      V.Set_Home_Once := C.Gps_Config.Gps_Set_Home_Point_Once;
      V.Use_Galileo := C.Gps_Config.Gps_Ublox_Use_Galileo;
      V.Rescue := R.Rescue;
      V.Rescue_Settings := (Max_Angle                => AP.Max_Angle,
                            Return_Altitude_M        => GR.Return_Altitude_M,
                            Descent_Distance_M       => GR.Descent_Distance_M,
                            Ground_Speed_Cm_S        => GR.Ground_Speed_Cm_S,
                            Throttle_Min             => AP.Throttle_Min,
                            Throttle_Max             => AP.Throttle_Max,
                            Hover_Throttle           => AP.Hover_Throttle,
                            Sanity_Checks            => GR.Sanity_Checks,
                            Min_Sats                 => GR.Min_Sats,
                            Ascend_Rate              => GR.Ascend_Rate,
                            Descend_Rate             => GR.Descend_Rate,
                            Allow_Arming_Without_Fix => GR.Allow_Arming_Without_Fix,
                            Altitude_Mode            => GR.Altitude_Mode,
                            Min_Start_Dist_M         => GR.Min_Start_Dist_M,
                            Initial_Climb_M          => GR.Initial_Climb_M,
                            Altitude_P               => AP.Altitude_P,
                            Altitude_I               => AP.Altitude_I,
                            Altitude_D               => AP.Altitude_D,
                            Position_P               => AP.Position_P,
                            Position_I               => AP.Position_I,
                            Position_D               => AP.Position_D,
                            Yaw_P                    => GR.Yaw_P);
      V.Trim_Pitch := C.Accelerometer_Config.Accelerometer_Trims (1);
      V.Trim_Roll := C.Accelerometer_Config.Accelerometer_Trims (0);
      V.Blackbox := (Built           => R.Blackbox,
                     Device          => C.Blackbox_Config.Device,
                     Rate_Denom      => R.Rate_Denom,
                     P_Ratio         => R.P_Ratio,
                     Sample_Rate     => C.Blackbox_Config.Sample_Rate,
                     Fields_Disabled => C.Blackbox_Config.Fields_Disabled_Mask);
      V.Built := R.Built;
      V.Selected := (MSP_Hardware_Out.Gyro         => 0,
                     MSP_Hardware_Out.Acc          => C.Accelerometer_Config.Acc_Hardware,
                     MSP_Hardware_Out.Baro         => C.Barometer_Config.Baro_Hardware,
                     MSP_Hardware_Out.Mag          => C.Compass_Config.Mag_Hardware,
                     MSP_Hardware_Out.Rangefinder  => C.Rangefinder_Config.Rangefinder_Hardware,
                     MSP_Hardware_Out.Optical_Flow => C.Opticalflow_Config.Opticalflow_Hardware,
                     MSP_Hardware_Out.Pitot        => C.Pitot_Config.Pitot_Hardware);
      V.Detected := R.Detected;
      V.Gyro_Count := R.Gyro_Count;
      V.Detected_Gyros := R.Detected_Gyros;
      V.Flash := R.Flash;
      V.SD_Card := R.SD_Card;
      return V;
   end Hardware_View;

   function Peripheral_View (C : Configuration; R : Peripheral_Runtime) return MSP_Peripheral_Out.Snapshot is
      P  : Pid_Profile_Record renames C.Pid_Profiles (Natural (C.System_Config.Pid_Profile_Index));
      LS : Led_Strip_Status_Mode_Config_Record renames C.Led_Strip_Status_Mode_Config;
      VS : Vtx_Settings_Config_Record renames C.Vtx_Settings_Config;
      V  : MSP_Peripheral_Out.Snapshot;
   begin
      V.Servos := R.Servos;
      V.Servo_Count := R.Servo_Count;
      V.Outputs := R.Outputs;
      for I in V.Params'Range loop
         V.Params (I) := (Min                  => C.Servo_Params (I - 1).Min,
                          Max                  => C.Servo_Params (I - 1).Max,
                          Middle               => C.Servo_Params (I - 1).Middle,
                          Rate                 => C.Servo_Params (I - 1).Rate,
                          Forward_From_Channel => C.Servo_Params (I - 1).Forward_From_Channel,
                          Reversed_Sources     => C.Servo_Params (I - 1).Reversed_Sources);
      end loop;
      for I in V.Rules'Range loop
         V.Rules (I) := (Target_Channel => C.Custom_Servo_Mixers (I - 1).Target_Channel,
                         Input_Source   => C.Custom_Servo_Mixers (I - 1).Input_Source,
                         Rate           => C.Custom_Servo_Mixers (I - 1).Rate,
                         Speed          => C.Custom_Servo_Mixers (I - 1).Speed,
                         Min            => C.Custom_Servo_Mixers (I - 1).Min,
                         Max            => C.Custom_Servo_Mixers (I - 1).Max,
                         Box            => C.Custom_Servo_Mixers (I - 1).Box);
      end loop;
      for I in V.Motors'Range loop
         V.Motors (I) := C.Motor_Config.Dev.Motor_Output_Reordering (I - 1);
      end loop;
      V.LED.Strip := R.LED_Strip;
      V.LED.Status_Mode := R.Status_Mode;
      V.LED.Length := LS.Led_Configs'Length;
      for I in V.LED.Colors'Range loop
         V.LED.Colors (I) := (H => LS.Colors (I - 1).H, S => LS.Colors (I - 1).S, V => LS.Colors (I - 1).V);
      end loop;
      for I in LS.Led_Configs'Range loop
         V.LED.Configs (I + 1) := LS.Led_Configs (I);
      end loop;
      for M in V.LED.Modes'Range loop
         for D in V.LED.Modes (M)'Range loop
            V.LED.Modes (M) (D) := LS.Mode_Colors (M - 1).Color (D - 1);
         end loop;
      end loop;
      for I in V.LED.Specials'Range loop
         V.LED.Specials (I) := LS.Special_Colors.Color (I - 1);
      end loop;
      V.LED.Aux_Channel := LS.Ledstrip_Aux_Channel;
      V.LED.Profile := C.Led_Strip_Config.Ledstrip_Profile;
      V.VTX := (Built            => R.VTX_Built,
                Device           => R.VTX_Device,
                Device_Type      => R.VTX_Type,
                Pit_Mode         => R.VTX_Pit_Mode,
                Ready            => R.VTX_Ready,
                Band             => VS.Band,
                Channel          => VS.Channel,
                Power            => VS.Power,
                Frequency        => VS.Freq,
                Low_Power_Disarm => VS.Low_Power_Disarm,
                Pit_Frequency    => VS.Pit_Mode_Freq,
                Table            => R.VTX_Table,
                Table_Bands      => C.Vtx_Table_Config.Bands,
                Table_Channels   => C.Vtx_Table_Config.Channels,
                Table_Powers     => C.Vtx_Table_Config.Power_Levels);
      for A in V.Wing.S_Gains'Range loop
         V.Wing.S_Gains (A) := P.Pid (A - 1).S;
         V.Wing.SPA_Center (A) := P.Spa_Center (A - 1);
         V.Wing.SPA_Width (A) := P.Spa_Width (A - 1);
         V.Wing.SPA_Mode (A) := P.Spa_Mode (A - 1);
      end loop;
      V.Wing.TPA_Curve_Type := P.Tpa_Curve_Type;
      V.Wing.TPA_Curve_Stall := P.Tpa_Curve_Stall_Throttle;
      V.Wing.TPA_Curve_PID_Thr0 := P.Tpa_Curve_Pid_Thr0;
      V.Wing.TPA_Curve_PID_Thr100 := P.Tpa_Curve_Pid_Thr100;
      V.Wing.TPA_Curve_Expo := P.Tpa_Curve_Expo;
      V.Wing.TPA_Speed_Type := P.Tpa_Speed_Type;
      V.Wing.TPA_Speed_Delay := P.Tpa_Speed_Basic_Delay;
      V.Wing.TPA_Speed_Gravity := P.Tpa_Speed_Basic_Gravity;
      V.Wing.TPA_Speed_Prop_Pitch := P.Tpa_Speed_Adv_Prop_Pitch;
      V.Wing.TPA_Speed_Mass := P.Tpa_Speed_Adv_Mass;
      V.Wing.TPA_Speed_Drag_K := P.Tpa_Speed_Adv_Drag_K;
      V.Wing.TPA_Speed_Thrust := P.Tpa_Speed_Adv_Thrust;
      V.Wing.TPA_Speed_Max_Voltage := P.Tpa_Speed_Max_Voltage;
      V.Wing.TPA_Speed_Pitch_Offset := P.Tpa_Speed_Pitch_Offset;
      V.Wing.Yaw_Type := P.Yaw_Type;
      V.Wing.Angle_Pitch_Offset := P.Angle_Pitch_Offset;
      return V;
   end Peripheral_View;

   function Serial_View
     (C : Configuration; Ports : MSP_Serial_Out.Port_Entries; Count : Natural) return MSP_Serial_Out.Snapshot is
   begin
      return (Options     => Config_Fix.Serial_Options,
              Assignments => Config_Fix.Serial_Assignments (C),
              Port_Count  => Count,
              Ports       => Ports);
   end Serial_View;

   function Text_View (C : Configuration; R : Text_Runtime) return MSP_Text_Out.Snapshot is
      T : Vtx_Table_Config_Record renames C.Vtx_Table_Config;
      V : MSP_Text_Out.Snapshot;
   begin
      V.Pilot_Name := To_Text (C.Pilot_Config.Pilot_Name);
      V.Craft_Name := To_Text (C.Pilot_Config.Craft_Name);
      V.PID_Profile_Name := To_Text (C.Pid_Profiles (Natural (C.System_Config.Pid_Profile_Index)).Profile_Name);
      V.Rate_Profile_Name :=
        To_Text (C.Control_Rate_Profiles (Natural (C.System_Config.Active_Rate_Profile)).Profile_Name);
      V.Build_Key := R.Build_Key;
      V.Release_Name := R.Release_Name;
      for I in V.Batteries'Range loop
         V.Batteries (I) := (Min_Cell            => C.Battery_Profiles (I).Vbatmincellvoltage,
                             Max_Cell            => C.Battery_Profiles (I).Vbatmaxcellvoltage,
                             Warning_Cell        => C.Battery_Profiles (I).Vbatwarningcellvoltage,
                             Full_Cell           => C.Battery_Profiles (I).Vbatfullcellvoltage,
                             Capacity            => C.Battery_Profiles (I).Battery_Capacity,
                             Force_Cell_Count    => C.Battery_Profiles (I).Force_Battery_Cell_Count,
                             Consumption_Warning => C.Battery_Profiles (I).Consumption_Warning_Percentage,
                             Name                => To_Text (C.Battery_Profiles (I).Profile_Name));
      end loop;
      V.Active_Battery := Natural (C.System_Config.Active_Battery_Profile);
      V.LED_Strip := R.LED_Strip;
      V.Brightness := C.Led_Strip_Config.Ledstrip_Brightness;
      V.Rainbow_Delta := C.Led_Strip_Config.Ledstrip_Rainbow_Delta;
      V.Rainbow_Freq := C.Led_Strip_Config.Ledstrip_Rainbow_Freq;
      V.Table.Built := R.Table;
      V.Table.Channels := Natural'Min (Natural (T.Channels), MSP_Text_Out.Channel_Count);
      for B in V.Table.Names'Range loop
         for K in V.Table.Names (B)'Range loop
            V.Table.Names (B) (K) := T.Band_Names (B - 1) (K - 1);
         end loop;
         V.Table.Letters (B) := T.Band_Letters (B - 1);
         V.Table.Factory (B) := (if T.Is_Factory_Band (B - 1) then 1 else 0);
         for Ch in V.Table.Frequencies (B)'Range loop
            V.Table.Frequencies (B) (Ch) := T.Frequency (B - 1) (Ch - 1);
         end loop;
      end loop;
      for L in V.Table.Powers'Range loop
         V.Table.Powers (L) := T.Power_Values (L - 1);
         for K in V.Table.Labels (L)'Range loop
            V.Table.Labels (L) (K) := T.Power_Labels (L - 1) (K - 1);
         end loop;
      end loop;
      return V;
   end Text_View;

   function OSD_View (C : Configuration; R : OSD_Runtime) return MSP_OSD_Out.Snapshot is
      O : Osd_Config_Record renames C.Osd_Config;
      V : MSP_OSD_Out.Snapshot;
   begin
      V.OSD := R.OSD;
      V.Video_System_Option := R.Video_System_Option;
      V.Profiles := R.Profiles;
      V.Stick_Overlay := R.Stick_Overlay;
      V.Display_Port_Font := R.Display_Port_Font;
      V.Frame_Buffer_OSD := R.Frame_Buffer_OSD;
      V.VTX_Port := R.VTX_Port;
      V.Device := R.Device;
      V.Device_Ready := R.Device_Ready;
      V.Video_System := C.Vcd_Profile.Video_System;
      V.Units := (if O.Units <= OSD_Format.Unit_System'Pos (OSD_Format.Unit_System'Last)
                  then OSD_Format.Unit_System'Val (O.Units) else OSD_Format.Metric);
      V.RSSI_Alarm := O.Rssi_Alarm;
      V.Cap_Alarm := O.Cap_Alarm;
      V.Alt_Alarm := O.Alt_Alarm;
      for I in V.Positions'Range loop
         V.Positions (I) := C.Osd_Element_Config.Item_Pos (OSD_Elements.Item'Pos (I));
      end loop;
      for St in V.Stats'Range loop
         V.Stats (St) := (O.Enabled_Stats and Interfaces.Shift_Left (1, OSD_Stats.Stat'Pos (St))) /= 0;
      end loop;
      for I in V.Timers'Range loop
         V.Timers (I) := O.Timers (I);
      end loop;
      for W in V.Warnings'Range loop
         V.Warnings (W) := (O.Enabled_Warnings and Interfaces.Shift_Left (1, OSD_Warnings.Warning_Kind'Pos (W))) /= 0;
      end loop;
      V.Profile_Index := (if O.Osd_Profile_Index in 1 .. OSD_Elements.Profile_Count
                          then Natural (O.Osd_Profile_Index) else 1);
      V.Overlay_Radio_Mode := O.Overlay_Radio_Mode;
      V.Camera_Frame_Width := O.Camera_Frame_Width;
      V.Camera_Frame_Height := O.Camera_Frame_Height;
      V.Link_Quality_Alarm := O.Link_Quality_Alarm;
      V.RSSI_Dbm_Alarm := O.Rssi_Dbm_Alarm;
      V.Warning_Line := R.Warning_Line;
      V.Warning_Blinking := R.Warning_Blinking;
      V.Warning_Severity := R.Warning_Severity;
      return V;
   end OSD_View;

   procedure Common_View (C : Configuration; V : in out MSP_Common_Out.Snapshot) is
      B : Battery_Profile_Record renames C.Battery_Profiles (Natural (C.System_Config.Active_Battery_Profile));
   begin
      V.Features := C.Feature_Config.Enabled_Features;
      V.Beeper_Off_Flags := C.Beeper_Config.Beeper_Off_Flags;
      V.Beacon_Tone := C.Beeper_Config.Dshot_Beacon_Tone;
      V.Beacon_Off_Flags := C.Beeper_Config.Dshot_Beacon_Off_Flags;
      V.Battery := (Min_Cell       => B.Vbatmincellvoltage,
                    Max_Cell       => B.Vbatmaxcellvoltage,
                    Warning_Cell   => B.Vbatwarningcellvoltage,
                    Capacity       => B.Battery_Capacity,
                    Voltage_Source => C.Battery_Config.Voltage_Meter_Source,
                    Current_Source => C.Battery_Config.Current_Meter_Source);
      V.Meters.Sensor_Count := 1;
      V.Meters.Sensors (1) := (Id         => 10,
                               Scale      => C.Voltage_Sensor_Adc_Config (0).Vbatscale,
                               Divider    => C.Voltage_Sensor_Adc_Config (0).Vbatresdivval,
                               Multiplier => C.Voltage_Sensor_Adc_Config (0).Vbatresdivmultiplier);
      V.Meters.Current_Scale := C.Current_Sensor_Adc_Config.Scale;
      V.Meters.Current_Offset := C.Current_Sensor_Adc_Config.Offset;
      V.Meters.Virtual_Scale := C.Current_Sensor_Virtual_Config.Scale;
      V.Meters.Virtual_Offset :=
        (if C.Current_Sensor_Virtual_Config.Offset >= 2 ** 15
         then Interfaces.Integer_16 (Integer (C.Current_Sensor_Virtual_Config.Offset) - 2 ** 16)
         else Interfaces.Integer_16 (C.Current_Sensor_Virtual_Config.Offset));
      V.Transponder.Provider :=
        (if Natural (C.Transponder_Config.Provider) <= MSP_Common_Out.Transponder_Provider'Last
         then Natural (C.Transponder_Config.Provider) else 0);
      for K in V.Transponder.Data'Range loop
         V.Transponder.Data (K) := C.Transponder_Config.Data (K - 1);
      end loop;
      V.Canvas_Columns := C.Osd_Config.Canvas_Cols;
      V.Canvas_Rows := C.Osd_Config.Canvas_Rows;
   end Common_View;

end Adaflight.MSP_Views;
