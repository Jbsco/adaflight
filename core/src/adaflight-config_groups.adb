with Adaflight.Config_Codec;

package body Adaflight.Config_Groups with SPARK_Mode is

   --  The number of bytes before the first zero.
   function Text_Length (B : Bytes) return Natural
     with Pre  => B'First = 0 and then B'Last < 4_096,
          Post => Text_Length'Result <= B'Length
   is
   begin
      for I in B'Range loop
         if B (I) = 0 then
            return I - B'First;
         end if;
      end loop;
      return B'Length;
   end Text_Length;

   function Text_Of (B : Bytes) return String
     with Pre => B'First = 0 and then B'Last < 4_096
   is
      Length : constant Natural := Text_Length (B);
   begin
      return Result : String (1 .. Length) do
         for I in 1 .. Length loop
            Result (I) := Character'Val (B (B'First + I - 1));
         end loop;
      end return;
   end Text_Of;

   --  Each setting's value in the bytes of its group or of its profile's element: a number of
   --  one, two or four bytes, signed or not, a bit of such a word, or a text the numbers leave out.
   type Value_Kind is (Number, Bit, Text);
   subtype Value_Width is Positive range 1 .. 4;
   type Value_Format is record
      Kind   : Value_Kind;
      Width  : Value_Width;
      Signed : Boolean;
   end record with Pack;

   U8         : constant Value_Format := (Number, 1, False);
   I8         : constant Value_Format := (Number, 1, True);
   U16        : constant Value_Format := (Number, 2, False);
   I16        : constant Value_Format := (Number, 2, True);
   U32        : constant Value_Format := (Number, 4, False);
   I32        : constant Value_Format := (Number, 4, True);
   Bits_32    : constant Value_Format := (Bit, 4, False);
   Text_Value : constant Value_Format := (Text, 1, False);

   type Value_Offset is range 0 .. 210;

   Value_Offsets : constant array (Setting) of Value_Offset :=
     (Gyro_Hardware_Lpf => 1, Gyro_Lpf1_Type => 18, Gyro_Lpf1_Static_Hz => 3, Gyro_Lpf2_Type => 19,
      Gyro_Lpf2_Static_Hz => 5, Gyro_Notch1_Hz => 7, Gyro_Notch1_Cutoff => 9, Gyro_Notch2_Hz => 11,
      Gyro_Notch2_Cutoff => 13, Gyro_Calib_Duration => 23, Gyro_Calib_Noise_Limit => 0, Gyro_Offset_Yaw => 15,
      Gyro_Overflow_Detect => 17, Yaw_Spin_Recovery => 20, Yaw_Spin_Threshold => 21, Dyn_Notch_Count => 6,
      Dyn_Notch_Q => 4, Dyn_Notch_Min_Hz => 0, Dyn_Notch_Max_Hz => 2, Gyro_Lpf1_Dyn_Min_Hz => 25,
      Gyro_Lpf1_Dyn_Max_Hz => 27, Gyro_Lpf1_Dyn_Expo => 31, Gyro_Filter_Debug_Axis => 29, Acc_Hardware => 2,
      Acc_Lpf_Hz => 0, Acc_Trim_Pitch => 14, Acc_Trim_Roll => 12, Acc_Calibration => 4, Align_Mag => 0,
      Mag_Align_Roll => 16, Mag_Align_Pitch => 18, Mag_Align_Yaw => 20, Mag_Bustype => 2, Mag_I2c_Device => 3,
      Mag_I2c_Address => 4, Mag_Spi_Device => 5, Mag_Hardware => 1, Mag_Calibration => 8, Baro_Bustype => 0,
      Baro_Spi_Device => 1, Baro_I2c_Device => 3, Baro_I2c_Address => 4, Baro_Hardware => 5, Baro_Drift => 8,
      Pitot_Bustype => 0, Pitot_I2c_Device => 1, Pitot_I2c_Address => 2, Pitot_Hardware => 3, Mid_Rc => 18,
      Min_Check => 20, Max_Check => 22, Rssi_Channel => 15, Rssi_Src_Frame_Errors => 31, Rssi_Scale => 16,
      Rssi_Offset => 32, Rssi_Invert => 17, Rssi_Src_Frame_Lpf_Period => 39, Rssi_Smoothing => 40,
      Rc_Smoothing => 33, Rc_Smoothing_Auto_Factor => 37, Rc_Smoothing_Auto_Factor_Throttle => 38,
      Rc_Smoothing_Setpoint_Cutoff => 34, Rc_Smoothing_Throttle_Cutoff => 35, Rc_Smoothing_Debug_Axis => 36,
      Fpv_Mix_Degrees => 24, Max_Aux_Channels => 30, Serialrx_Provider => 8, Serialrx_Inverted => 9,
      Spektrum_Sat_Bind => 13, Spektrum_Sat_Bind_Autoreset => 14, Srxl2_Unit_Id => 41, Srxl2_Baud_Fast => 42,
      Sbus_Baud_Fast => 43, Crsf_Use_Negotiated_Baud => 49, Airmode_Start_Throttle_Percent => 25,
      Rx_Min_Usec => 26, Rx_Max_Usec => 28, Serialrx_Halfduplex => 10, Rx_Uart => 50,
      Msp_Override_Channels_Mask => 44, Msp_Override_Failsafe => 48, Rx_Spi_Protocol => 0, Rx_Spi_Bus => 7,
      Rx_Spi_Led_Inversion => 10, Adc_Device => 12, Adc_Vrefint_Calibration => 13,
      Adc_Tempsensor_Calibration30 => 15, Adc_Tempsensor_Calibration110 => 17, Input_Filtering_Mode => 8,
      Blackbox_Sample_Rate => 4, Blackbox_Device => 5, Blackbox_Disable_Pids => 0, Blackbox_Disable_Rc => 0,
      Blackbox_Disable_Setpoint => 0, Blackbox_Disable_Bat => 0, Blackbox_Disable_Mag => 0,
      Blackbox_Disable_Alt => 0, Blackbox_Disable_Rssi => 0, Blackbox_Disable_Gyro => 0,
      Blackbox_Disable_Gyrounfilt => 0, Blackbox_Disable_Acc => 0, Blackbox_Disable_Attitude => 0,
      Blackbox_Disable_Debug => 0, Blackbox_Disable_Motors => 0, Blackbox_Disable_Servos => 0,
      Blackbox_Disable_Rpm => 0, Blackbox_Disable_Gps => 0, Blackbox_Disable_Pitot => 0, Blackbox_Mode => 6,
      Blackbox_High_Resolution => 7, Blackbox_Uart => 8, Blackbox_Baud => 9, Max_Throttle => 29,
      Min_Command => 31, Motor_Kv => 33, Motor_Idle => 27, Dshot_Burst => 5, Dshot_Bidir => 6, Dshot_Edt => 7,
      Dshot_Bitbang => 17, Dshot_Bitbang_Timer => 18, Use_Unsynced_Pwm => 4, Motor_Pwm_Protocol => 2,
      Motor_Pwm_Rate => 0, Motor_Pwm_Inversion => 3, Motor_Poles => 35, Motor_Output_Reordering => 19,
      Thr_Corr_Value => 2, Thr_Corr_Angle => 0, Failsafe_Delay => 4, Failsafe_Landing_Time => 5,
      Failsafe_Throttle => 0, Failsafe_Switch_Mode => 6, Failsafe_Throttle_Low_Delay => 2,
      Failsafe_Procedure => 7, Failsafe_Recovery_Delay => 8, Failsafe_Stick_Threshold => 10,
      Align_Board_Roll => 0, Align_Board_Pitch => 4, Align_Board_Yaw => 8, Gimbal_Mode => 0,
      Battery_Profile_Name => 0, Bat_Capacity => 8, Vbat_Max_Cell_Voltage => 0, Vbat_Full_Cell_Voltage => 6,
      Vbat_Min_Cell_Voltage => 2, Vbat_Warning_Cell_Voltage => 4, Cbat_Alert_Percent => 11,
      Force_Battery_Cell_Count => 10, Vbat_Hysteresis => 7, Current_Meter => 4, Battery_Meter => 3,
      Vbat_Detect_Cell_Voltage => 0, Use_Vbat_Alerts => 5, Use_Cbat_Alerts => 6, Vbat_Cutoff_Percent => 2,
      Vbat_Display_Lpf_Period => 8, Vbat_Sag_Lpf_Period => 12, Ibat_Lpf_Period => 9,
      Vbat_Duration_For_Warning => 10, Vbat_Duration_For_Critical => 11, Vbat_Scale => 0, Vbat_Divider => 1,
      Vbat_Multiplier => 2, Ibata_Scale => 0, Ibata_Offset => 2, Ibatv_Scale => 0, Ibatv_Offset => 2,
      Battery_Continue => 13, Beeper_Inversion => 1, Beeper_Od => 2, Beeper_Frequency => 3,
      Beeper_Dshot_Beacon_Tone => 4, Yaw_Motors_Reversed => 1, Mixer_Type => 5, Crashflip_Motor_Percent => 2,
      Crashflip_Rate => 3, Crashflip_Auto_Rearm => 4, Rpm_Limit => 6, Rpm_Limit_P => 7, Rpm_Limit_I => 9,
      Rpm_Limit_D => 11, Rpm_Limit_Value => 13, Three_D_Deadband_Low => 0, Three_D_Deadband_High => 2,
      Three_D_Neutral => 4, Three_D_Deadband_Throttle => 6, Three_D_Limit_Low => 8, Three_D_Limit_High => 10,
      Three_D_Switched_Mode => 12, Servo_Center_Pulse => 0, Servo_Pwm_Rate => 2, Servo_Lowpass_Hz => 12,
      Tri_Unarmed_Servo => 14, Channel_Forwarding_Start => 15, Rateprofile_Name => 0, Thr_Mid => 0,
      Thr_Expo => 1, Thr_Hover => 30, Rates_Type => 2, Quickrates_Rc_Expo => 29, Roll_Rc_Rate => 3,
      Pitch_Rc_Rate => 4, Yaw_Rc_Rate => 5, Roll_Expo => 6, Pitch_Expo => 7, Yaw_Expo => 8, Roll_Srate => 9,
      Pitch_Srate => 10, Yaw_Srate => 11, Throttle_Limit_Type => 12, Throttle_Limit_Percent => 13,
      Roll_Rate_Limit => 14, Pitch_Rate_Limit => 16, Yaw_Rate_Limit => 18, Reboot_Character => 2,
      Serial_Update_Rate_Hz => 0, Imu_Dcm_Kp => 0, Imu_Dcm_Ki => 2, Small_Angle => 4, Imu_Process_Denom => 5,
      Mag_Declination => 6, Auto_Disarm_Delay => 1, Gyro_Cal_On_First_Arm => 0, Prearm_Allow_Rearm => 2,
      Gps_Provider => 0, Gps_Sbas_Mode => 1, Gps_Auto_Config => 2, Gps_Auto_Baud => 3,
      Gps_Ublox_Acquire_Model => 4, Gps_Ublox_Flight_Model => 5, Gps_Update_Rate_Hz => 6,
      Gps_Ublox_Utc_Standard => 11, Gps_Ublox_Use_Galileo => 7, Gps_Ublox_Enable_Ana => 12,
      Gps_Set_Home_Point_Once => 8, Gps_Use_3d_Speed => 9, Gps_Sbas_Integrity => 10,
      Gps_Nmea_Custom_Commands => 0, Gps_Uart => 78, Gps_Baud => 79, Gps_Rescue_Min_Start_Dist => 0,
      Gps_Rescue_Alt_Mode => 2, Gps_Rescue_Initial_Climb => 3, Gps_Rescue_Ascend_Rate => 5,
      Gps_Rescue_Return_Alt => 7, Gps_Rescue_Ground_Speed => 9, Gps_Rescue_Descent_Dist => 11,
      Gps_Rescue_Descend_Rate => 13, Gps_Rescue_Sanity_Checks => 15, Gps_Rescue_Min_Sats => 16,
      Gps_Rescue_Allow_Arming_Without_Fix => 17, Gps_Rescue_Yaw_P => 18, Gps_Lap_Timer_Gate_Lat => 0,
      Gps_Lap_Timer_Gate_Lon => 4, Gps_Lap_Timer_Min_Lap_Time_S => 8, Gps_Lap_Timer_Gate_Tolerance_M => 10,
      Deadband => 0, Yaw_Deadband => 1, Yaw_Control_Reversed => 2, Alt_Hold_Climb_Rate => 0,
      Alt_Hold_Deadband => 1, Pos_Hold_Deadband => 0, Poshold_Position_Source => 1,
      Poshold_Opticalflow_Quality_Min => 2, Poshold_Opticalflow_Max_Range => 3, Pid_Process_Denom => 0,
      Runaway_Takeoff_Prevention => 1, Runaway_Takeoff_Deactivate_Delay => 2,
      Runaway_Takeoff_Deactivate_Throttle_Percent => 4, Profile_Name => 0, Dterm_Lpf1_Dyn_Min_Hz => 84,
      Dterm_Lpf1_Dyn_Max_Hz => 86, Dterm_Lpf1_Dyn_Expo => 123, Dterm_Lpf1_Type => 38,
      Dterm_Lpf1_Static_Hz => 2, Dterm_Lpf2_Type => 83, Dterm_Lpf2_Static_Hz => 69, Dterm_Notch_Hz => 4,
      Dterm_Notch_Cutoff => 6, Vbat_Sag_Compensation => 125, Pid_At_Min_Throttle => 44,
      Anti_Gravity_Gain => 48, Anti_Gravity_Cutoff_Hz => 137, Anti_Gravity_P_Gain => 138, Acc_Limit_Yaw => 49,
      Acc_Limit => 51, Crash_Dthreshold => 53, Crash_Gthreshold => 55, Crash_Setpoint_Threshold => 57,
      Crash_Time => 59, Crash_Delay => 61, Crash_Recovery_Angle => 63, Crash_Recovery_Rate => 64,
      Crash_Limit_Yaw => 65, Crash_Recovery => 71, Iterm_Rotation => 74, Iterm_Relax => 77,
      Iterm_Relax_Type => 75, Iterm_Relax_Cutoff => 76, Iterm_Windup => 39, Pidsum_Limit => 40,
      Pidsum_Limit_Yaw => 42, Yaw_Lowpass_Hz => 0, Throttle_Boost => 72, Throttle_Boost_Cutoff => 73,
      Acro_Trainer_Angle_Limit => 78, Acro_Trainer_Lookahead_Ms => 81, Acro_Trainer_Debug_Axis => 79,
      Acro_Trainer_Gain => 80, P_Pitch => 14, I_Pitch => 15, D_Pitch => 16, F_Pitch => 17, P_Roll => 8,
      I_Roll => 9, D_Roll => 10, F_Roll => 11, P_Yaw => 20, I_Yaw => 21, D_Yaw => 22, F_Yaw => 23,
      Angle_P_Gain => 26, Angle_Feedforward => 29, Angle_Feedforward_Smoothing_Ms => 143, Angle_Limit => 45,
      Angle_Earth_Ref => 144, Horizon_Level_Strength => 27, Horizon_Limit_Sticks => 28,
      Horizon_Limit_Degrees => 46, Horizon_Ignore_Sticks => 47, Horizon_Delay_Ms => 145,
      Chirp_Lag_Freq_Hz => 197, Chirp_Lead_Freq_Hz => 198, Chirp_Amplitude_Roll => 199,
      Chirp_Amplitude_Pitch => 201, Chirp_Amplitude_Yaw => 203, Chirp_Frequency_Start_Deci_Hz => 205,
      Chirp_Frequency_End_Deci_Hz => 207, Chirp_Time_Seconds => 209, Chirp_Repeat => 210, D_Max_Roll => 94,
      D_Max_Pitch => 95, D_Max_Yaw => 96, D_Max_Gain => 97, D_Max_Advance => 98, Motor_Output_Limit => 99,
      Auto_Profile_Cell_Count => 100, Launch_Control_Mode => 88, Launch_Trigger_Allow_Reset => 92,
      Launch_Trigger_Throttle_Percent => 89, Launch_Angle_Limit => 90, Launch_Control_Gain => 91,
      Thrust_Linear => 93, Feedforward_Transition => 115, Feedforward_Averaging => 116,
      Feedforward_Smooth_Factor => 117, Feedforward_Jitter_Factor => 118, Feedforward_Boost => 119,
      Feedforward_Max_Rate_Limit => 120, Feedforward_Yaw_Hold_Gain => 121, Feedforward_Yaw_Hold_Time => 122,
      Dyn_Idle_Min_Rpm => 110, Dyn_Idle_P_Gain => 111, Dyn_Idle_I_Gain => 112, Dyn_Idle_D_Gain => 113,
      Dyn_Idle_Max_Increase => 114, Level_Race_Mode => 124, Simplified_Pids_Mode => 126,
      Simplified_Master_Multiplier => 127, Simplified_I_Gain => 129, Simplified_D_Gain => 130,
      Simplified_Pi_Gain => 131, Simplified_D_Max_Gain => 132, Simplified_Feedforward_Gain => 133,
      Simplified_Pitch_D_Gain => 128, Simplified_Pitch_Pi_Gain => 136, Simplified_Dterm_Filter => 134,
      Simplified_Dterm_Filter_Multiplier => 135, Simplified_Gyro_Filter => 32,
      Simplified_Gyro_Filter_Multiplier => 33, Tpa_Mode => 139, Tpa_Rate => 140, Tpa_Breakpoint => 141,
      Tpa_Low_Rate => 147, Tpa_Low_Breakpoint => 148, Tpa_Low_Always => 150, Ez_Landing_Threshold => 151,
      Ez_Landing_Limit => 152, Ez_Landing_Speed => 153, Landing_Disarm_Threshold => 154, Tlm_Inverted => 4,
      Tlm_Halfduplex => 5, Telemetry_1_Protocol => 41, Telemetry_1_Uart => 42, Telemetry_1_Baud => 43,
      Telemetry_2_Protocol => 44, Telemetry_2_Uart => 45, Telemetry_2_Baud => 46, Telemetry_3_Protocol => 47,
      Telemetry_3_Uart => 48, Telemetry_3_Baud => 49, Crsf_Tlm_Accgyro => 40, Frsky_Default_Lat => 0,
      Frsky_Default_Long => 2, Frsky_Gps_Format => 6, Frsky_Unit => 7, Frsky_Vfas_Precision => 8,
      Hott_Alarm_Int => 9, Pid_In_Tlm => 10, Report_Cell_Voltage => 11, Ibus_Sensor => 12,
      Mavlink_Mah_As_Heading_Divisor => 27, Mavlink_Min_Txbuff => 33, Mavlink_Ext_Status_Rate => 34,
      Mavlink_Rc_Chan_Rate => 35, Mavlink_Pos_Rate => 36, Mavlink_Extra1_Rate => 37,
      Mavlink_Extra2_Rate => 38, Mavlink_Extra3_Rate => 39, Telemetry_Disabled_Voltage => 29,
      Telemetry_Disabled_Current => 29, Telemetry_Disabled_Fuel => 29, Telemetry_Disabled_Mode => 29,
      Telemetry_Disabled_Acc_X => 29, Telemetry_Disabled_Acc_Y => 29, Telemetry_Disabled_Acc_Z => 29,
      Telemetry_Disabled_Pitch => 29, Telemetry_Disabled_Roll => 29, Telemetry_Disabled_Heading => 29,
      Telemetry_Disabled_Altitude => 29, Telemetry_Disabled_Vario => 29, Telemetry_Disabled_Lat_Long => 29,
      Telemetry_Disabled_Ground_Speed => 29, Telemetry_Disabled_Distance => 29,
      Telemetry_Disabled_Esc_Current => 29, Telemetry_Disabled_Esc_Voltage => 29,
      Telemetry_Disabled_Esc_Rpm => 29, Telemetry_Disabled_Esc_Temperature => 29,
      Telemetry_Disabled_Temperature => 29, Telemetry_Disabled_Cap_Used => 29, Ledstrip_Visual_Beeper => 0,
      Ledstrip_Visual_Beeper_Color => 10, Ledstrip_Grb_Rgb => 2, Ledstrip_Profile => 3,
      Ledstrip_Race_Color => 4, Ledstrip_Beacon_Color => 5, Ledstrip_Beacon_Period_Ms => 6,
      Ledstrip_Beacon_Percent => 8, Ledstrip_Beacon_Armed_Only => 9, Ledstrip_Brightness => 11,
      Ledstrip_Rainbow_Delta => 12, Ledstrip_Rainbow_Freq => 14, Transponder_Provider => 0,
      Transponder_Data => 2, Sdcard_Detect_Inverted => 3, Sdcard_Mode => 4, Sdcard_Spi_Bus => 0,
      Osd_Units => 5, Osd_Warn_Bitmask => 10, Osd_Rssi_Alarm => 4, Osd_Link_Quality_Alarm => 80,
      Osd_Rssi_Dbm_Alarm => 82, Osd_Rsnr_Alarm => 84, Osd_Cap_Alarm => 0, Osd_Alt_Alarm => 2,
      Osd_Distance_Alarm => 92, Osd_Esc_Temp_Alarm => 20, Osd_Esc_Rpm_Alarm => 21,
      Osd_Esc_Current_Alarm => 23, Osd_Core_Temp_Alarm => 25, Osd_Ah_Max_Pit => 14, Osd_Ah_Max_Rol => 15,
      Osd_Ah_Invert => 26, Osd_Logo_On_Arming => 94, Osd_Logo_On_Arming_Duration => 95,
      Osd_Arming_Logo => 111, Osd_Use_Quick_Menu => 109, Osd_Show_Spec_Prearm => 110, Osd_Tim1 => 6,
      Osd_Tim2 => 8, Osd_Vbat_Pos => 2, Osd_Rssi_Pos => 0, Osd_Link_Quality_Pos => 92,
      Osd_Link_Tx_Power_Pos => 122, Osd_Rssi_Dbm_Pos => 110, Osd_Rsnr_Pos => 130, Osd_Tim_1_Pos => 10,
      Osd_Tim_2_Pos => 12, Osd_Remaining_Time_Estimate_Pos => 74, Osd_Flymode_Pos => 14,
      Osd_Anti_Gravity_Pos => 82, Osd_G_Force_Pos => 84, Osd_Throttle_Pos => 18, Osd_Vtx_Channel_Pos => 20,
      Osd_Crosshairs_Pos => 4, Osd_Ah_Sbar_Pos => 8, Osd_Ah_Pos => 6, Osd_Current_Pos => 22,
      Osd_Mah_Drawn_Pos => 24, Osd_Wh_Drawn_Pos => 124, Osd_Motor_Diag_Pos => 86, Osd_Craft_Name_Pos => 16,
      Osd_Pilot_Name_Pos => 100, Osd_Gps_Speed_Pos => 26, Osd_Gps_Lon_Pos => 46, Osd_Gps_Lat_Pos => 48,
      Osd_Gps_Lap_Curr_Pos => 154, Osd_Gps_Lap_Prev_Pos => 156, Osd_Gps_Lap_Best3_Pos => 158,
      Osd_Gps_Sats_Pos => 28, Osd_Home_Dir_Pos => 60, Osd_Home_Dist_Pos => 62, Osd_Flight_Dist_Pos => 94,
      Osd_Compass_Bar_Pos => 68, Osd_Altitude_Pos => 30, Osd_Pid_Roll_Pos => 32, Osd_Pid_Pitch_Pos => 34,
      Osd_Pid_Yaw_Pos => 36, Osd_Debug_Pos => 50, Osd_Debug2_Pos => 160, Osd_Power_Pos => 38,
      Osd_Pidrate_Profile_Pos => 40, Osd_Warnings_Pos => 42, Osd_Avg_Cell_Voltage_Pos => 44,
      Osd_Pit_Ang_Pos => 52, Osd_Rol_Ang_Pos => 54, Osd_Battery_Usage_Pos => 56, Osd_Disarmed_Pos => 58,
      Osd_Nheading_Pos => 64, Osd_Up_Down_Reference_Pos => 120, Osd_Ready_Mode_Pos => 128,
      Osd_Pos_Hold_Ready_Pos => 194, Osd_Nvario_Pos => 66, Osd_Esc_Tmp_Pos => 70, Osd_Esc_Rpm_Pos => 72,
      Osd_Esc_Rpm_Freq_Pos => 102, Osd_Rtc_Date_Time_Pos => 76, Osd_Adjustment_Range_Pos => 78,
      Osd_Flip_Arrow_Pos => 90, Osd_Core_Temp_Pos => 80, Osd_Log_Status_Pos => 88,
      Osd_Stick_Overlay_Left_Pos => 96, Osd_Stick_Overlay_Right_Pos => 98, Osd_Stick_Overlay_Radio_Mode => 28,
      Osd_Rate_Profile_Name_Pos => 104, Osd_Pid_Profile_Name_Pos => 106, Osd_Battery_Profile_Name_Pos => 174,
      Osd_Profile_Name_Pos => 108, Osd_Rcchannels_Pos => 112, Osd_Camera_Frame_Pos => 114,
      Osd_Efficiency_Pos => 116, Osd_Total_Flights_Pos => 118, Osd_Aux_Pos => 126,
      Osd_Sys_Goggle_Voltage_Pos => 132, Osd_Sys_Vtx_Voltage_Pos => 134, Osd_Sys_Bitrate_Pos => 136,
      Osd_Sys_Delay_Pos => 138, Osd_Sys_Distance_Pos => 140, Osd_Sys_Lq_Pos => 142,
      Osd_Sys_Goggle_Dvr_Pos => 144, Osd_Sys_Vtx_Dvr_Pos => 146, Osd_Sys_Warnings_Pos => 148,
      Osd_Sys_Vtx_Temp_Pos => 150, Osd_Sys_Fan_Speed_Pos => 152, Osd_Stat_Bitmask => 16, Osd_Profile => 27,
      Osd_Profile_1_Name => 0, Osd_Profile_2_Name => 0, Osd_Profile_3_Name => 0, Osd_Gps_Sats_Show_Pdop => 86,
      Osd_Displayport_Device => 91, Osd_Uart => 112, Osd_Rcchannels => 87, Osd_Camera_Frame_Width => 96,
      Osd_Camera_Frame_Height => 97, Osd_Stat_Avg_Cell_Value => 101, Osd_Framerate_Hz => 98,
      Osd_Menu_Background => 100, Osd_Aux_Channel => 103, Osd_Aux_Scale => 104, Osd_Aux_Symbol => 106,
      Osd_Craftname_Msgs => 102, Osd_Lidar_Dist_Pos => 170, Osd_Custom_Serial_Text_Pos => 172,
      Osd_Custom_Serial_Text_Terminator => 0, Osd_Custom_Text_Uart => 113, Osd_Custom_Text_Baud => 114,
      Osd_Wp_Number_Pos => 176, Osd_Wp_Current_Lat_Pos => 178, Osd_Wp_Current_Lon_Pos => 180,
      Osd_Wp_Current_Alt_Pos => 182, Osd_Wp_Distance_Pos => 184, Osd_Wp_Direction_Pos => 186,
      Osd_Wp_Next_Number_Pos => 188, Osd_Wp_Eta_Pos => 190, Osd_Nav_Map_Pos => 192, Osd_Nav_Map_Mode => 0,
      Osd_Nav_Map_Centre => 1, Osd_Nav_Map_Min_Scale_M => 2, Osd_Airspeed => 196, System_Hse_Mhz => 13,
      Task_Statistics => 3, Debug_Mode => 2, Rate_6pos_Switch => 4, Cpu_Overclock => 5, Pwr_On_Arm_Grace => 6,
      Enable_Stick_Arming => 15, Vtx_Band => 0, Vtx_Channel => 1, Vtx_Power => 2, Vtx_Low_Power_Disarm => 7,
      Vtx_Softserial_Alt => 8, Vtx_Type => 9, Vtx_Uart => 10, Vtx_Freq => 3, Vtx_Pit_Mode_Freq => 5,
      Vtx_Halfduplex => 60, Vtx_Spi_Bus => 4, Vcd_Video_System => 0, Vcd_H_Offset => 1, Vcd_V_Offset => 2,
      Max7456_Clock => 0, Max7456_Spi_Bus => 2, Max7456_Preinit_Opu => 3, Displayport_Msp_Col_Adjust => 0,
      Displayport_Msp_Row_Adjust => 1, Displayport_Msp_Fonts => 5, Displayport_Msp_Use_Device_Blink => 9,
      Displayport_Max7456_Col_Adjust => 0, Displayport_Max7456_Row_Adjust => 1, Displayport_Max7456_Inv => 2,
      Displayport_Max7456_Blk => 3, Displayport_Max7456_Wht => 4, Esc_Sensor_Halfduplex => 0,
      Esc_Sensor_Current_Offset => 1, Esc_Sensor_Uart => 3, Frsky_Spi_Autobind => 0, Frsky_Spi_Tx_Id => 1,
      Frsky_Spi_Offset => 4, Frsky_Spi_Bind_Hop_Data => 5, Frsky_X_Rx_Num => 55, Frsky_Spi_A1_Source => 56,
      Cc2500_Spi_Chip_Detect => 57, Led_Inversion => 3, Dashboard_I2c_Bus => 0, Dashboard_I2c_Addr => 4,
      Camera_Control_Mode => 0, Camera_Control_Ref_Voltage => 1, Camera_Control_Key_Delay => 3,
      Camera_Control_Internal_Resistance => 5, Camera_Control_Button_Resistance => 9,
      Camera_Control_Inverted => 8, Rangefinder_Hardware => 0, Rangefinder_Uart => 1,
      Opticalflow_Hardware => 0, Opticalflow_Uart => 4, Opticalflow_Rotation => 1, Opticalflow_Flip_X => 3,
      Pinio_Config => 4, Pinio_Box => 0, Usb_Hid_Cdc => 0, Usb_Msc_Pin_Pullup => 2, Flash_Spi_Bus => 1,
      Rcdevice_Init_Dev_Attempts => 0, Rcdevice_Init_Dev_Attempt_Interval => 1,
      Rcdevice_Protocol_Version => 9, Rcdevice_Feature => 5, Rcdevice_Uart => 10, Gyro_1_Bustype => 1,
      Gyro_1_Spibus => 2, Gyro_1_I2c_Bus => 4, Gyro_1_I2c_Address => 5, I2c1_Pullup => 2,
      I2c1_Clockspeed_Khz => 3, I2c2_Pullup => 7, I2c2_Clockspeed_Khz => 8, I2c3_Pullup => 12,
      I2c3_Clockspeed_Khz => 13, Mco2_On_Pc9 => 3, Spektrum_Spi_Protocol => 0, Spektrum_Spi_Mfg_Id => 1,
      Spektrum_Spi_Num_Channels => 5, Expresslrs_Uid => 2, Expresslrs_Domain => 8, Expresslrs_Model_Id => 10,
      Scheduler_Relax_Rx => 0, Scheduler_Relax_Osd => 2, Scheduler_Debug_Task => 6,
      Cpu_Late_Limit_Permille => 4, Serialmsp_Halfduplex => 0, Msp_1_Uart => 1, Msp_1_Baud => 4,
      Msp_2_Uart => 2, Msp_2_Baud => 5, Msp_3_Uart => 3, Msp_3_Baud => 6, Timezone_Offset_Minutes => 0,
      Rpm_Filter_Harmonics => 0, Rpm_Filter_Weights => 1, Rpm_Filter_Q => 7, Rpm_Filter_Min_Hz => 4,
      Rpm_Filter_Fade_Range_Hz => 5, Rpm_Filter_Lpf_Hz => 9, Flysky_Spi_Tx_Id => 0,
      Flysky_Spi_Rf_Channels => 4, Stats_Min_Armed_Time_S => 12, Stats_Total_Flights => 0,
      Stats_Total_Time_S => 4, Stats_Total_Dist_M => 8, Stats_Save_Move_Limit => 17, Stats_Mah_Used => 13,
      Craft_Name => 0, Pilot_Name => 0, Altitude_Source => 0, Altitude_Prefer_Baro => 1, Altitude_Lpf => 2,
      Rangefinder_Max_Range_Cm => 6, Altitude_D_Lpf => 4, Ap_Landing_Altitude_M => 0, Ap_Hover_Throttle => 1,
      Ap_Throttle_Min => 3, Ap_Throttle_Max => 5, Ap_Altitude_P => 7, Ap_Altitude_I => 8, Ap_Altitude_D => 9,
      Ap_Altitude_A => 10, Ap_Altitude_F => 11, Ap_Position_P => 12, Ap_Position_I => 13, Ap_Position_D => 14,
      Ap_Position_A => 15, Ap_Position_F => 16, Ap_Position_Cutoff => 17, Ap_Stop_Threshold => 18,
      Ap_Max_Angle => 19, Ap_Max_Yaw_Rate => 46, Ap_Yaw_P => 45, Ap_Velocity_Drag_Coeff => 20,
      Ap_Max_Velocity => 21, Ap_Waypoint_Arrival_Radius => 23, Ap_Waypoint_Hold_Radius => 25,
      Ap_Stick_Deadband => 27, Ap_Throttle_Deadband => 29, Ap_Yaw_Mode => 44, Ap_Min_Forward_Velocity => 47,
      Ap_Nav_Corner_Speed => 31, Ap_Nav_Corner_Delta_V => 33, Ap_Nav_Decel => 35, Ap_Nav_Accel => 37,
      Ap_Nav_Carrot_Lead_Time => 39, Ap_Nav_Carrot_Lead_Max => 40, Ap_Nav_Preturn_Dist => 42,
      Ap_Velocity_Buildup_Max_Pitch => 49, Ap_Max_Turn_Rate => 50, Ap_Hold_Orbit_Radius => 51,
      Ap_Hold_Figure8_Width => 53, Ap_Landing_Descent_Rate => 55, Ap_Landing_Detection_Time => 56,
      Ap_Landing_Spiral_Enable => 57, Ap_Landing_Spiral_Radius => 58, Ap_Landing_Spiral_Rate => 60,
      Ap_Landing_Velocity_Threshold => 61, Ap_Landing_Throttle_Threshold => 62, Ap_L1_Enable => 64,
      Ap_L1_Period => 65, Ap_L1_Min_Lookahead => 67, Ap_L1_Max_Lookahead => 69,
      Ap_L1_Max_Cross_Track_Error => 71, Ap_L1_Turn_Rate => 73, Ap_Min_Nav_Altitude_M => 74,
      Ap_Rx_Loss_Policy => 75, Ap_Max_Distance_From_Home => 76, Ap_Geofence_Action => 78,
      Box_User_1_Name => 0, Box_User_2_Name => 0, Box_User_3_Name => 0, Box_User_4_Name => 0,
      Gimbal_Roll_Rc_Gain => 0, Gimbal_Pitch_Rc_Thr_Gain => 1, Gimbal_Pitch_Rc_Low_Gain => 2,
      Gimbal_Pitch_Rc_High_Gain => 3, Gimbal_Yaw_Rc_Gain => 4, Gimbal_Roll_Gain => 5, Gimbal_Roll_Offset => 6,
      Gimbal_Roll_Limit => 7, Gimbal_Pitch_Gain => 8, Gimbal_Pitch_Offset => 9, Gimbal_Pitch_Low_Limit => 10,
      Gimbal_Pitch_High_Limit => 11, Gimbal_Yaw_Gain => 12, Gimbal_Yaw_Offset => 13, Gimbal_Yaw_Limit => 14,
      Gimbal_Stabilisation => 15, Gimbal_Sensitivity => 16, Gimbal_Uart => 17);
   Value_Formats : constant array (Setting) of Value_Format :=
     (Gyro_Hardware_Lpf => U8, Gyro_Lpf1_Type => U8, Gyro_Lpf1_Static_Hz => U16, Gyro_Lpf2_Type => U8,
      Gyro_Lpf2_Static_Hz => U16, Gyro_Notch1_Hz => U16, Gyro_Notch1_Cutoff => U16, Gyro_Notch2_Hz => U16,
      Gyro_Notch2_Cutoff => U16, Gyro_Calib_Duration => U16, Gyro_Calib_Noise_Limit => U8,
      Gyro_Offset_Yaw => I16, Gyro_Overflow_Detect => U8, Yaw_Spin_Recovery => U8, Yaw_Spin_Threshold => U16,
      Dyn_Notch_Count => U8, Dyn_Notch_Q => U16, Dyn_Notch_Min_Hz => U16, Dyn_Notch_Max_Hz => U16,
      Gyro_Lpf1_Dyn_Min_Hz => U16, Gyro_Lpf1_Dyn_Max_Hz => U16, Gyro_Lpf1_Dyn_Expo => U8,
      Gyro_Filter_Debug_Axis => U8, Acc_Hardware => U8, Acc_Lpf_Hz => U16, Acc_Trim_Pitch => I16,
      Acc_Trim_Roll => I16, Acc_Calibration => I16, Align_Mag => U8, Mag_Align_Roll => I16,
      Mag_Align_Pitch => I16, Mag_Align_Yaw => I16, Mag_Bustype => U8, Mag_I2c_Device => U8,
      Mag_I2c_Address => U8, Mag_Spi_Device => U8, Mag_Hardware => U8, Mag_Calibration => I16,
      Baro_Bustype => U8, Baro_Spi_Device => U8, Baro_I2c_Device => U8, Baro_I2c_Address => U8,
      Baro_Hardware => U8, Baro_Drift => I16, Pitot_Bustype => U8, Pitot_I2c_Device => U8,
      Pitot_I2c_Address => U8, Pitot_Hardware => U8, Mid_Rc => U16, Min_Check => U16, Max_Check => U16,
      Rssi_Channel => I8, Rssi_Src_Frame_Errors => I8, Rssi_Scale => U8, Rssi_Offset => I8, Rssi_Invert => I8,
      Rssi_Src_Frame_Lpf_Period => U8, Rssi_Smoothing => U8, Rc_Smoothing => U8,
      Rc_Smoothing_Auto_Factor => U8, Rc_Smoothing_Auto_Factor_Throttle => U8,
      Rc_Smoothing_Setpoint_Cutoff => U8, Rc_Smoothing_Throttle_Cutoff => U8, Rc_Smoothing_Debug_Axis => U8,
      Fpv_Mix_Degrees => U8, Max_Aux_Channels => U8, Serialrx_Provider => U8, Serialrx_Inverted => U8,
      Spektrum_Sat_Bind => U8, Spektrum_Sat_Bind_Autoreset => U8, Srxl2_Unit_Id => U8, Srxl2_Baud_Fast => U8,
      Sbus_Baud_Fast => U8, Crsf_Use_Negotiated_Baud => U8, Airmode_Start_Throttle_Percent => U8,
      Rx_Min_Usec => U16, Rx_Max_Usec => U16, Serialrx_Halfduplex => U8, Rx_Uart => I8,
      Msp_Override_Channels_Mask => U32, Msp_Override_Failsafe => U8, Rx_Spi_Protocol => U8, Rx_Spi_Bus => U8,
      Rx_Spi_Led_Inversion => U8, Adc_Device => I8, Adc_Vrefint_Calibration => U16,
      Adc_Tempsensor_Calibration30 => U16, Adc_Tempsensor_Calibration110 => U16, Input_Filtering_Mode => I8,
      Blackbox_Sample_Rate => U8, Blackbox_Device => U8, Blackbox_Disable_Pids => Bits_32,
      Blackbox_Disable_Rc => Bits_32, Blackbox_Disable_Setpoint => Bits_32, Blackbox_Disable_Bat => Bits_32,
      Blackbox_Disable_Mag => Bits_32, Blackbox_Disable_Alt => Bits_32, Blackbox_Disable_Rssi => Bits_32,
      Blackbox_Disable_Gyro => Bits_32, Blackbox_Disable_Gyrounfilt => Bits_32,
      Blackbox_Disable_Acc => Bits_32, Blackbox_Disable_Attitude => Bits_32,
      Blackbox_Disable_Debug => Bits_32, Blackbox_Disable_Motors => Bits_32,
      Blackbox_Disable_Servos => Bits_32, Blackbox_Disable_Rpm => Bits_32, Blackbox_Disable_Gps => Bits_32,
      Blackbox_Disable_Pitot => Bits_32, Blackbox_Mode => U8, Blackbox_High_Resolution => U8,
      Blackbox_Uart => I8, Blackbox_Baud => U8, Max_Throttle => U16, Min_Command => U16, Motor_Kv => U16,
      Motor_Idle => U16, Dshot_Burst => U8, Dshot_Bidir => U8, Dshot_Edt => U8, Dshot_Bitbang => U8,
      Dshot_Bitbang_Timer => U8, Use_Unsynced_Pwm => U8, Motor_Pwm_Protocol => U8, Motor_Pwm_Rate => U16,
      Motor_Pwm_Inversion => U8, Motor_Poles => U8, Motor_Output_Reordering => U8, Thr_Corr_Value => U8,
      Thr_Corr_Angle => U16, Failsafe_Delay => U8, Failsafe_Landing_Time => U8, Failsafe_Throttle => U16,
      Failsafe_Switch_Mode => U8, Failsafe_Throttle_Low_Delay => U16, Failsafe_Procedure => U8,
      Failsafe_Recovery_Delay => U16, Failsafe_Stick_Threshold => U8, Align_Board_Roll => I16,
      Align_Board_Pitch => I16, Align_Board_Yaw => I16, Gimbal_Mode => U8, Battery_Profile_Name => Text_Value,
      Bat_Capacity => U16, Vbat_Max_Cell_Voltage => U16, Vbat_Full_Cell_Voltage => U16,
      Vbat_Min_Cell_Voltage => U16, Vbat_Warning_Cell_Voltage => U16, Cbat_Alert_Percent => U8,
      Force_Battery_Cell_Count => U8, Vbat_Hysteresis => U8, Current_Meter => U8, Battery_Meter => U8,
      Vbat_Detect_Cell_Voltage => U16, Use_Vbat_Alerts => U8, Use_Cbat_Alerts => U8,
      Vbat_Cutoff_Percent => U8, Vbat_Display_Lpf_Period => U8, Vbat_Sag_Lpf_Period => U8,
      Ibat_Lpf_Period => U8, Vbat_Duration_For_Warning => U8, Vbat_Duration_For_Critical => U8,
      Vbat_Scale => U8, Vbat_Divider => U8, Vbat_Multiplier => U8, Ibata_Scale => I16, Ibata_Offset => I16,
      Ibatv_Scale => I16, Ibatv_Offset => U16, Battery_Continue => U8, Beeper_Inversion => U8,
      Beeper_Od => U8, Beeper_Frequency => I16, Beeper_Dshot_Beacon_Tone => U8, Yaw_Motors_Reversed => U8,
      Mixer_Type => U8, Crashflip_Motor_Percent => U8, Crashflip_Rate => U8, Crashflip_Auto_Rearm => U8,
      Rpm_Limit => U8, Rpm_Limit_P => U16, Rpm_Limit_I => U16, Rpm_Limit_D => U16, Rpm_Limit_Value => U16,
      Three_D_Deadband_Low => U16, Three_D_Deadband_High => U16, Three_D_Neutral => U16,
      Three_D_Deadband_Throttle => U16, Three_D_Limit_Low => U16, Three_D_Limit_High => U16,
      Three_D_Switched_Mode => U8, Servo_Center_Pulse => U16, Servo_Pwm_Rate => U16, Servo_Lowpass_Hz => U16,
      Tri_Unarmed_Servo => I8, Channel_Forwarding_Start => U8, Rateprofile_Name => Text_Value, Thr_Mid => U8,
      Thr_Expo => U8, Thr_Hover => U8, Rates_Type => U8, Quickrates_Rc_Expo => U8, Roll_Rc_Rate => U8,
      Pitch_Rc_Rate => U8, Yaw_Rc_Rate => U8, Roll_Expo => U8, Pitch_Expo => U8, Yaw_Expo => U8,
      Roll_Srate => U8, Pitch_Srate => U8, Yaw_Srate => U8, Throttle_Limit_Type => U8,
      Throttle_Limit_Percent => U8, Roll_Rate_Limit => U16, Pitch_Rate_Limit => U16, Yaw_Rate_Limit => U16,
      Reboot_Character => U8, Serial_Update_Rate_Hz => U16, Imu_Dcm_Kp => U16, Imu_Dcm_Ki => U16,
      Small_Angle => U8, Imu_Process_Denom => U8, Mag_Declination => I16, Auto_Disarm_Delay => U8,
      Gyro_Cal_On_First_Arm => U8, Prearm_Allow_Rearm => U8, Gps_Provider => U8, Gps_Sbas_Mode => U8,
      Gps_Auto_Config => U8, Gps_Auto_Baud => U8, Gps_Ublox_Acquire_Model => U8, Gps_Ublox_Flight_Model => U8,
      Gps_Update_Rate_Hz => U8, Gps_Ublox_Utc_Standard => U8, Gps_Ublox_Use_Galileo => U8,
      Gps_Ublox_Enable_Ana => U8, Gps_Set_Home_Point_Once => U8, Gps_Use_3d_Speed => U8,
      Gps_Sbas_Integrity => U8, Gps_Nmea_Custom_Commands => Text_Value, Gps_Uart => I8, Gps_Baud => U8,
      Gps_Rescue_Min_Start_Dist => U16, Gps_Rescue_Alt_Mode => U8, Gps_Rescue_Initial_Climb => U16,
      Gps_Rescue_Ascend_Rate => U16, Gps_Rescue_Return_Alt => U16, Gps_Rescue_Ground_Speed => U16,
      Gps_Rescue_Descent_Dist => U16, Gps_Rescue_Descend_Rate => U16, Gps_Rescue_Sanity_Checks => U8,
      Gps_Rescue_Min_Sats => U8, Gps_Rescue_Allow_Arming_Without_Fix => U8, Gps_Rescue_Yaw_P => U8,
      Gps_Lap_Timer_Gate_Lat => I32, Gps_Lap_Timer_Gate_Lon => I32, Gps_Lap_Timer_Min_Lap_Time_S => U16,
      Gps_Lap_Timer_Gate_Tolerance_M => U8, Deadband => U8, Yaw_Deadband => U8, Yaw_Control_Reversed => U8,
      Alt_Hold_Climb_Rate => U8, Alt_Hold_Deadband => U8, Pos_Hold_Deadband => U8,
      Poshold_Position_Source => U8, Poshold_Opticalflow_Quality_Min => U8,
      Poshold_Opticalflow_Max_Range => U16, Pid_Process_Denom => U8, Runaway_Takeoff_Prevention => U8,
      Runaway_Takeoff_Deactivate_Delay => U16, Runaway_Takeoff_Deactivate_Throttle_Percent => U8,
      Profile_Name => Text_Value, Dterm_Lpf1_Dyn_Min_Hz => U16, Dterm_Lpf1_Dyn_Max_Hz => U16,
      Dterm_Lpf1_Dyn_Expo => U8, Dterm_Lpf1_Type => U8, Dterm_Lpf1_Static_Hz => I16, Dterm_Lpf2_Type => U8,
      Dterm_Lpf2_Static_Hz => I16, Dterm_Notch_Hz => U16, Dterm_Notch_Cutoff => U16,
      Vbat_Sag_Compensation => U8, Pid_At_Min_Throttle => U8, Anti_Gravity_Gain => U8,
      Anti_Gravity_Cutoff_Hz => U8, Anti_Gravity_P_Gain => U8, Acc_Limit_Yaw => U16, Acc_Limit => U16,
      Crash_Dthreshold => U16, Crash_Gthreshold => U16, Crash_Setpoint_Threshold => U16, Crash_Time => U16,
      Crash_Delay => U16, Crash_Recovery_Angle => U8, Crash_Recovery_Rate => U8, Crash_Limit_Yaw => U16,
      Crash_Recovery => U8, Iterm_Rotation => U8, Iterm_Relax => U8, Iterm_Relax_Type => U8,
      Iterm_Relax_Cutoff => U8, Iterm_Windup => U8, Pidsum_Limit => U16, Pidsum_Limit_Yaw => U16,
      Yaw_Lowpass_Hz => U16, Throttle_Boost => U8, Throttle_Boost_Cutoff => U8,
      Acro_Trainer_Angle_Limit => U8, Acro_Trainer_Lookahead_Ms => U16, Acro_Trainer_Debug_Axis => U8,
      Acro_Trainer_Gain => U8, P_Pitch => U8, I_Pitch => U8, D_Pitch => U8, F_Pitch => U16, P_Roll => U8,
      I_Roll => U8, D_Roll => U8, F_Roll => U16, P_Yaw => U8, I_Yaw => U8, D_Yaw => U8, F_Yaw => U16,
      Angle_P_Gain => U8, Angle_Feedforward => U8, Angle_Feedforward_Smoothing_Ms => U8, Angle_Limit => U8,
      Angle_Earth_Ref => U8, Horizon_Level_Strength => U8, Horizon_Limit_Sticks => U8,
      Horizon_Limit_Degrees => U8, Horizon_Ignore_Sticks => U8, Horizon_Delay_Ms => U16,
      Chirp_Lag_Freq_Hz => U8, Chirp_Lead_Freq_Hz => U8, Chirp_Amplitude_Roll => U16,
      Chirp_Amplitude_Pitch => U16, Chirp_Amplitude_Yaw => U16, Chirp_Frequency_Start_Deci_Hz => U16,
      Chirp_Frequency_End_Deci_Hz => U16, Chirp_Time_Seconds => U8, Chirp_Repeat => U8, D_Max_Roll => U8,
      D_Max_Pitch => U8, D_Max_Yaw => U8, D_Max_Gain => U8, D_Max_Advance => U8, Motor_Output_Limit => U8,
      Auto_Profile_Cell_Count => I8, Launch_Control_Mode => U8, Launch_Trigger_Allow_Reset => U8,
      Launch_Trigger_Throttle_Percent => U8, Launch_Angle_Limit => U8, Launch_Control_Gain => U8,
      Thrust_Linear => U8, Feedforward_Transition => U8, Feedforward_Averaging => U8,
      Feedforward_Smooth_Factor => U8, Feedforward_Jitter_Factor => U8, Feedforward_Boost => U8,
      Feedforward_Max_Rate_Limit => U8, Feedforward_Yaw_Hold_Gain => U8, Feedforward_Yaw_Hold_Time => U8,
      Dyn_Idle_Min_Rpm => U8, Dyn_Idle_P_Gain => U8, Dyn_Idle_I_Gain => U8, Dyn_Idle_D_Gain => U8,
      Dyn_Idle_Max_Increase => U8, Level_Race_Mode => U8, Simplified_Pids_Mode => U8,
      Simplified_Master_Multiplier => U8, Simplified_I_Gain => U8, Simplified_D_Gain => U8,
      Simplified_Pi_Gain => U8, Simplified_D_Max_Gain => U8, Simplified_Feedforward_Gain => U8,
      Simplified_Pitch_D_Gain => U8, Simplified_Pitch_Pi_Gain => U8, Simplified_Dterm_Filter => U8,
      Simplified_Dterm_Filter_Multiplier => U8, Simplified_Gyro_Filter => U8,
      Simplified_Gyro_Filter_Multiplier => U8, Tpa_Mode => U8, Tpa_Rate => U8, Tpa_Breakpoint => U16,
      Tpa_Low_Rate => I8, Tpa_Low_Breakpoint => U16, Tpa_Low_Always => U8, Ez_Landing_Threshold => U8,
      Ez_Landing_Limit => U8, Ez_Landing_Speed => U8, Landing_Disarm_Threshold => U8, Tlm_Inverted => U8,
      Tlm_Halfduplex => U8, Telemetry_1_Protocol => U8, Telemetry_1_Uart => I8, Telemetry_1_Baud => U8,
      Telemetry_2_Protocol => U8, Telemetry_2_Uart => I8, Telemetry_2_Baud => U8, Telemetry_3_Protocol => U8,
      Telemetry_3_Uart => I8, Telemetry_3_Baud => U8, Crsf_Tlm_Accgyro => U8, Frsky_Default_Lat => I16,
      Frsky_Default_Long => I16, Frsky_Gps_Format => U8, Frsky_Unit => U8, Frsky_Vfas_Precision => U8,
      Hott_Alarm_Int => U8, Pid_In_Tlm => U8, Report_Cell_Voltage => U8, Ibus_Sensor => U8,
      Mavlink_Mah_As_Heading_Divisor => U16, Mavlink_Min_Txbuff => U8, Mavlink_Ext_Status_Rate => U8,
      Mavlink_Rc_Chan_Rate => U8, Mavlink_Pos_Rate => U8, Mavlink_Extra1_Rate => U8,
      Mavlink_Extra2_Rate => U8, Mavlink_Extra3_Rate => U8, Telemetry_Disabled_Voltage => Bits_32,
      Telemetry_Disabled_Current => Bits_32, Telemetry_Disabled_Fuel => Bits_32,
      Telemetry_Disabled_Mode => Bits_32, Telemetry_Disabled_Acc_X => Bits_32,
      Telemetry_Disabled_Acc_Y => Bits_32, Telemetry_Disabled_Acc_Z => Bits_32,
      Telemetry_Disabled_Pitch => Bits_32, Telemetry_Disabled_Roll => Bits_32,
      Telemetry_Disabled_Heading => Bits_32, Telemetry_Disabled_Altitude => Bits_32,
      Telemetry_Disabled_Vario => Bits_32, Telemetry_Disabled_Lat_Long => Bits_32,
      Telemetry_Disabled_Ground_Speed => Bits_32, Telemetry_Disabled_Distance => Bits_32,
      Telemetry_Disabled_Esc_Current => Bits_32, Telemetry_Disabled_Esc_Voltage => Bits_32,
      Telemetry_Disabled_Esc_Rpm => Bits_32, Telemetry_Disabled_Esc_Temperature => Bits_32,
      Telemetry_Disabled_Temperature => Bits_32, Telemetry_Disabled_Cap_Used => Bits_32,
      Ledstrip_Visual_Beeper => U8, Ledstrip_Visual_Beeper_Color => U8, Ledstrip_Grb_Rgb => U8,
      Ledstrip_Profile => U8, Ledstrip_Race_Color => U8, Ledstrip_Beacon_Color => U8,
      Ledstrip_Beacon_Period_Ms => U16, Ledstrip_Beacon_Percent => U8, Ledstrip_Beacon_Armed_Only => U8,
      Ledstrip_Brightness => U8, Ledstrip_Rainbow_Delta => U16, Ledstrip_Rainbow_Freq => U16,
      Transponder_Provider => U8, Transponder_Data => U8, Sdcard_Detect_Inverted => U8, Sdcard_Mode => U8,
      Sdcard_Spi_Bus => U8, Osd_Units => U8, Osd_Warn_Bitmask => U32, Osd_Rssi_Alarm => U8,
      Osd_Link_Quality_Alarm => U16, Osd_Rssi_Dbm_Alarm => I16, Osd_Rsnr_Alarm => I16, Osd_Cap_Alarm => U16,
      Osd_Alt_Alarm => U16, Osd_Distance_Alarm => U16, Osd_Esc_Temp_Alarm => U8, Osd_Esc_Rpm_Alarm => I16,
      Osd_Esc_Current_Alarm => I16, Osd_Core_Temp_Alarm => U8, Osd_Ah_Max_Pit => U8, Osd_Ah_Max_Rol => U8,
      Osd_Ah_Invert => U8, Osd_Logo_On_Arming => U8, Osd_Logo_On_Arming_Duration => U8, Osd_Arming_Logo => U8,
      Osd_Use_Quick_Menu => U8, Osd_Show_Spec_Prearm => U8, Osd_Tim1 => U16, Osd_Tim2 => U16,
      Osd_Vbat_Pos => U16, Osd_Rssi_Pos => U16, Osd_Link_Quality_Pos => U16, Osd_Link_Tx_Power_Pos => U16,
      Osd_Rssi_Dbm_Pos => U16, Osd_Rsnr_Pos => U16, Osd_Tim_1_Pos => U16, Osd_Tim_2_Pos => U16,
      Osd_Remaining_Time_Estimate_Pos => U16, Osd_Flymode_Pos => U16, Osd_Anti_Gravity_Pos => U16,
      Osd_G_Force_Pos => U16, Osd_Throttle_Pos => U16, Osd_Vtx_Channel_Pos => U16, Osd_Crosshairs_Pos => U16,
      Osd_Ah_Sbar_Pos => U16, Osd_Ah_Pos => U16, Osd_Current_Pos => U16, Osd_Mah_Drawn_Pos => U16,
      Osd_Wh_Drawn_Pos => U16, Osd_Motor_Diag_Pos => U16, Osd_Craft_Name_Pos => U16,
      Osd_Pilot_Name_Pos => U16, Osd_Gps_Speed_Pos => U16, Osd_Gps_Lon_Pos => U16, Osd_Gps_Lat_Pos => U16,
      Osd_Gps_Lap_Curr_Pos => U16, Osd_Gps_Lap_Prev_Pos => U16, Osd_Gps_Lap_Best3_Pos => U16,
      Osd_Gps_Sats_Pos => U16, Osd_Home_Dir_Pos => U16, Osd_Home_Dist_Pos => U16, Osd_Flight_Dist_Pos => U16,
      Osd_Compass_Bar_Pos => U16, Osd_Altitude_Pos => U16, Osd_Pid_Roll_Pos => U16, Osd_Pid_Pitch_Pos => U16,
      Osd_Pid_Yaw_Pos => U16, Osd_Debug_Pos => U16, Osd_Debug2_Pos => U16, Osd_Power_Pos => U16,
      Osd_Pidrate_Profile_Pos => U16, Osd_Warnings_Pos => U16, Osd_Avg_Cell_Voltage_Pos => U16,
      Osd_Pit_Ang_Pos => U16, Osd_Rol_Ang_Pos => U16, Osd_Battery_Usage_Pos => U16, Osd_Disarmed_Pos => U16,
      Osd_Nheading_Pos => U16, Osd_Up_Down_Reference_Pos => U16, Osd_Ready_Mode_Pos => U16,
      Osd_Pos_Hold_Ready_Pos => U16, Osd_Nvario_Pos => U16, Osd_Esc_Tmp_Pos => U16, Osd_Esc_Rpm_Pos => U16,
      Osd_Esc_Rpm_Freq_Pos => U16, Osd_Rtc_Date_Time_Pos => U16, Osd_Adjustment_Range_Pos => U16,
      Osd_Flip_Arrow_Pos => U16, Osd_Core_Temp_Pos => U16, Osd_Log_Status_Pos => U16,
      Osd_Stick_Overlay_Left_Pos => U16, Osd_Stick_Overlay_Right_Pos => U16,
      Osd_Stick_Overlay_Radio_Mode => U8, Osd_Rate_Profile_Name_Pos => U16, Osd_Pid_Profile_Name_Pos => U16,
      Osd_Battery_Profile_Name_Pos => U16, Osd_Profile_Name_Pos => U16, Osd_Rcchannels_Pos => U16,
      Osd_Camera_Frame_Pos => U16, Osd_Efficiency_Pos => U16, Osd_Total_Flights_Pos => U16,
      Osd_Aux_Pos => U16, Osd_Sys_Goggle_Voltage_Pos => U16, Osd_Sys_Vtx_Voltage_Pos => U16,
      Osd_Sys_Bitrate_Pos => U16, Osd_Sys_Delay_Pos => U16, Osd_Sys_Distance_Pos => U16,
      Osd_Sys_Lq_Pos => U16, Osd_Sys_Goggle_Dvr_Pos => U16, Osd_Sys_Vtx_Dvr_Pos => U16,
      Osd_Sys_Warnings_Pos => U16, Osd_Sys_Vtx_Temp_Pos => U16, Osd_Sys_Fan_Speed_Pos => U16,
      Osd_Stat_Bitmask => U32, Osd_Profile => U8, Osd_Profile_1_Name => Text_Value,
      Osd_Profile_2_Name => Text_Value, Osd_Profile_3_Name => Text_Value, Osd_Gps_Sats_Show_Pdop => U8,
      Osd_Displayport_Device => U8, Osd_Uart => I8, Osd_Rcchannels => I8, Osd_Camera_Frame_Width => U8,
      Osd_Camera_Frame_Height => U8, Osd_Stat_Avg_Cell_Value => U8, Osd_Framerate_Hz => U16,
      Osd_Menu_Background => U8, Osd_Aux_Channel => U8, Osd_Aux_Scale => U16, Osd_Aux_Symbol => U8,
      Osd_Craftname_Msgs => U8, Osd_Lidar_Dist_Pos => U16, Osd_Custom_Serial_Text_Pos => U16,
      Osd_Custom_Serial_Text_Terminator => U8, Osd_Custom_Text_Uart => I8, Osd_Custom_Text_Baud => U8,
      Osd_Wp_Number_Pos => U16, Osd_Wp_Current_Lat_Pos => U16, Osd_Wp_Current_Lon_Pos => U16,
      Osd_Wp_Current_Alt_Pos => U16, Osd_Wp_Distance_Pos => U16, Osd_Wp_Direction_Pos => U16,
      Osd_Wp_Next_Number_Pos => U16, Osd_Wp_Eta_Pos => U16, Osd_Nav_Map_Pos => U16, Osd_Nav_Map_Mode => U8,
      Osd_Nav_Map_Centre => U8, Osd_Nav_Map_Min_Scale_M => U16, Osd_Airspeed => U16, System_Hse_Mhz => U8,
      Task_Statistics => I8, Debug_Mode => U8, Rate_6pos_Switch => U8, Cpu_Overclock => U8,
      Pwr_On_Arm_Grace => U8, Enable_Stick_Arming => U8, Vtx_Band => U8, Vtx_Channel => U8, Vtx_Power => U8,
      Vtx_Low_Power_Disarm => U8, Vtx_Softserial_Alt => U8, Vtx_Type => U8, Vtx_Uart => I8, Vtx_Freq => U16,
      Vtx_Pit_Mode_Freq => U16, Vtx_Halfduplex => U8, Vtx_Spi_Bus => U8, Vcd_Video_System => U8,
      Vcd_H_Offset => I8, Vcd_V_Offset => I8, Max7456_Clock => U8, Max7456_Spi_Bus => U8,
      Max7456_Preinit_Opu => U8, Displayport_Msp_Col_Adjust => I8, Displayport_Msp_Row_Adjust => I8,
      Displayport_Msp_Fonts => U8, Displayport_Msp_Use_Device_Blink => U8,
      Displayport_Max7456_Col_Adjust => I8, Displayport_Max7456_Row_Adjust => I8,
      Displayport_Max7456_Inv => U8, Displayport_Max7456_Blk => U8, Displayport_Max7456_Wht => U8,
      Esc_Sensor_Halfduplex => U8, Esc_Sensor_Current_Offset => U16, Esc_Sensor_Uart => I8,
      Frsky_Spi_Autobind => U8, Frsky_Spi_Tx_Id => U8, Frsky_Spi_Offset => I8, Frsky_Spi_Bind_Hop_Data => U8,
      Frsky_X_Rx_Num => U8, Frsky_Spi_A1_Source => U8, Cc2500_Spi_Chip_Detect => U8, Led_Inversion => U8,
      Dashboard_I2c_Bus => U8, Dashboard_I2c_Addr => U8, Camera_Control_Mode => U8,
      Camera_Control_Ref_Voltage => U16, Camera_Control_Key_Delay => U16,
      Camera_Control_Internal_Resistance => U16, Camera_Control_Button_Resistance => U16,
      Camera_Control_Inverted => U8, Rangefinder_Hardware => U8, Rangefinder_Uart => I8,
      Opticalflow_Hardware => U8, Opticalflow_Uart => I8, Opticalflow_Rotation => I16,
      Opticalflow_Flip_X => U8, Pinio_Config => U8, Pinio_Box => U8, Usb_Hid_Cdc => U8,
      Usb_Msc_Pin_Pullup => U8, Flash_Spi_Bus => U8, Rcdevice_Init_Dev_Attempts => U8,
      Rcdevice_Init_Dev_Attempt_Interval => U32, Rcdevice_Protocol_Version => U8, Rcdevice_Feature => U16,
      Rcdevice_Uart => I8, Gyro_1_Bustype => U8, Gyro_1_Spibus => U8, Gyro_1_I2c_Bus => U8,
      Gyro_1_I2c_Address => U8, I2c1_Pullup => U8, I2c1_Clockspeed_Khz => U16, I2c2_Pullup => U8,
      I2c2_Clockspeed_Khz => U16, I2c3_Pullup => U8, I2c3_Clockspeed_Khz => U16, Mco2_On_Pc9 => U8,
      Spektrum_Spi_Protocol => U8, Spektrum_Spi_Mfg_Id => U8, Spektrum_Spi_Num_Channels => U8,
      Expresslrs_Uid => U8, Expresslrs_Domain => U8, Expresslrs_Model_Id => U8, Scheduler_Relax_Rx => U16,
      Scheduler_Relax_Osd => U16, Scheduler_Debug_Task => U8, Cpu_Late_Limit_Permille => U8,
      Serialmsp_Halfduplex => U8, Msp_1_Uart => I8, Msp_1_Baud => U8, Msp_2_Uart => I8, Msp_2_Baud => U8,
      Msp_3_Uart => I8, Msp_3_Baud => U8, Timezone_Offset_Minutes => I16, Rpm_Filter_Harmonics => U8,
      Rpm_Filter_Weights => U8, Rpm_Filter_Q => U16, Rpm_Filter_Min_Hz => U8, Rpm_Filter_Fade_Range_Hz => U16,
      Rpm_Filter_Lpf_Hz => U16, Flysky_Spi_Tx_Id => U32, Flysky_Spi_Rf_Channels => U8,
      Stats_Min_Armed_Time_S => I8, Stats_Total_Flights => U32, Stats_Total_Time_S => U32,
      Stats_Total_Dist_M => U32, Stats_Save_Move_Limit => U8, Stats_Mah_Used => U32, Craft_Name => Text_Value,
      Pilot_Name => Text_Value, Altitude_Source => I8, Altitude_Prefer_Baro => I8, Altitude_Lpf => U16,
      Rangefinder_Max_Range_Cm => U16, Altitude_D_Lpf => U16, Ap_Landing_Altitude_M => U8,
      Ap_Hover_Throttle => U16, Ap_Throttle_Min => U16, Ap_Throttle_Max => U16, Ap_Altitude_P => U8,
      Ap_Altitude_I => U8, Ap_Altitude_D => U8, Ap_Altitude_A => U8, Ap_Altitude_F => U8, Ap_Position_P => U8,
      Ap_Position_I => U8, Ap_Position_D => U8, Ap_Position_A => U8, Ap_Position_F => U8,
      Ap_Position_Cutoff => U8, Ap_Stop_Threshold => U8, Ap_Max_Angle => U8, Ap_Max_Yaw_Rate => U8,
      Ap_Yaw_P => U8, Ap_Velocity_Drag_Coeff => U8, Ap_Max_Velocity => U16, Ap_Waypoint_Arrival_Radius => U16,
      Ap_Waypoint_Hold_Radius => U16, Ap_Stick_Deadband => U16, Ap_Throttle_Deadband => U16,
      Ap_Yaw_Mode => U8, Ap_Min_Forward_Velocity => U16, Ap_Nav_Corner_Speed => U16,
      Ap_Nav_Corner_Delta_V => U16, Ap_Nav_Decel => U16, Ap_Nav_Accel => U16, Ap_Nav_Carrot_Lead_Time => U8,
      Ap_Nav_Carrot_Lead_Max => U16, Ap_Nav_Preturn_Dist => U16, Ap_Velocity_Buildup_Max_Pitch => U8,
      Ap_Max_Turn_Rate => U8, Ap_Hold_Orbit_Radius => U16, Ap_Hold_Figure8_Width => U16,
      Ap_Landing_Descent_Rate => U8, Ap_Landing_Detection_Time => U8, Ap_Landing_Spiral_Enable => U8,
      Ap_Landing_Spiral_Radius => U16, Ap_Landing_Spiral_Rate => U8, Ap_Landing_Velocity_Threshold => U8,
      Ap_Landing_Throttle_Threshold => U16, Ap_L1_Enable => U8, Ap_L1_Period => U16,
      Ap_L1_Min_Lookahead => U16, Ap_L1_Max_Lookahead => U16, Ap_L1_Max_Cross_Track_Error => U16,
      Ap_L1_Turn_Rate => U8, Ap_Min_Nav_Altitude_M => U8, Ap_Rx_Loss_Policy => U8,
      Ap_Max_Distance_From_Home => U16, Ap_Geofence_Action => U8, Box_User_1_Name => Text_Value,
      Box_User_2_Name => Text_Value, Box_User_3_Name => Text_Value, Box_User_4_Name => Text_Value,
      Gimbal_Roll_Rc_Gain => I8, Gimbal_Pitch_Rc_Thr_Gain => I8, Gimbal_Pitch_Rc_Low_Gain => I8,
      Gimbal_Pitch_Rc_High_Gain => I8, Gimbal_Yaw_Rc_Gain => I8, Gimbal_Roll_Gain => I8,
      Gimbal_Roll_Offset => I8, Gimbal_Roll_Limit => I8, Gimbal_Pitch_Gain => I8, Gimbal_Pitch_Offset => I8,
      Gimbal_Pitch_Low_Limit => I8, Gimbal_Pitch_High_Limit => I8, Gimbal_Yaw_Gain => I8,
      Gimbal_Yaw_Offset => I8, Gimbal_Yaw_Limit => I8, Gimbal_Stabilisation => I8, Gimbal_Sensitivity => I8,
      Gimbal_Uart => I8);

   --  The word of a setting's bytes at its element, low byte first.
   function Word_At (D : Config_Codec.Group_Data; S : Setting; Index : Natural) return Unsigned_32
     with Pre => Index < Element_Count (S)
   is
      Width : constant Value_Width := Value_Formats (S).Width;
      Pos   : constant Natural := Natural (Value_Offsets (S)) + Index * Width;
      Word  : Unsigned_32 := 0;
   begin
      for K in reverse 0 .. Width - 1 loop
         Word := Shift_Left (Word, 8) or Unsigned_32 (D (Pos + K));
      end loop;
      return Word;
   end Word_At;

   function Get (C : Configuration; S : Setting; Profile : Natural := 0; Index : Natural := 0)
     return Integer_64
   is
      F    : constant Value_Format := Value_Formats (S);
      D    : Config_Codec.Group_Data;
      Word : Unsigned_32;
   begin
      if F.Kind = Text then
         return 0;
      end if;
      Config_Codec.Encode_Group (C, Describe (S).Group, Profile, D);
      Word := Word_At (D, S, Index);
      if F.Kind = Bit then
         return Integer_64 (Shift_Right (Word, Describe (S).Count) and 1);
      elsif F.Signed and then Word >= 2 ** (8 * F.Width - 1) then
         return Integer_64 (Word) - 2 ** (8 * F.Width);
      end if;
      return Integer_64 (Word);
   end Get;

   function Get_Text (C : Configuration; S : Setting; Profile : Natural := 0) return String is
     (case S is
        when Battery_Profile_Name => Text_Of (C.Battery_Profiles (Profile).Profile_Name),
        when Rateprofile_Name => Text_Of (C.Control_Rate_Profiles (Profile).Profile_Name),
        when Gps_Nmea_Custom_Commands => Text_Of (C.Gps_Config.Nmea_Custom_Commands),
        when Profile_Name => Text_Of (C.Pid_Profiles (Profile).Profile_Name),
        when Osd_Profile_1_Name => Text_Of (C.Osd_Config.Profile (0)),
        when Osd_Profile_2_Name => Text_Of (C.Osd_Config.Profile (1)),
        when Osd_Profile_3_Name => Text_Of (C.Osd_Config.Profile (2)),
        when Craft_Name => Text_Of (C.Pilot_Config.Craft_Name),
        when Pilot_Name => Text_Of (C.Pilot_Config.Pilot_Name),
        when Box_User_1_Name => Text_Of (C.Mode_Activation_Config.Box_User_Names (0)),
        when Box_User_2_Name => Text_Of (C.Mode_Activation_Config.Box_User_Names (1)),
        when Box_User_3_Name => Text_Of (C.Mode_Activation_Config.Box_User_Names (2)),
        when Box_User_4_Name => Text_Of (C.Mode_Activation_Config.Box_User_Names (3)),
        when others => "");

   function Lowest (S : Setting) return Integer_64 is
     (case S is
        when Gps_Lap_Timer_Gate_Lat | Gps_Lap_Timer_Gate_Lon => -2147483648,
        when Gyro_Offset_Yaw | Acc_Trim_Pitch | Acc_Trim_Roll | Acc_Calibration | Mag_Align_Roll | Mag_Align_Pitch |
          Mag_Align_Yaw | Mag_Calibration | Baro_Drift | Align_Board_Roll | Align_Board_Pitch | Align_Board_Yaw |
          Ibata_Scale | Ibata_Offset | Ibatv_Scale | Beeper_Frequency | Mag_Declination | Dterm_Lpf1_Static_Hz |
          Dterm_Lpf2_Static_Hz | Frsky_Default_Lat | Frsky_Default_Long | Osd_Rssi_Dbm_Alarm | Osd_Rsnr_Alarm |
          Osd_Esc_Rpm_Alarm | Osd_Esc_Current_Alarm | Opticalflow_Rotation | Timezone_Offset_Minutes => -32768,
        when Rssi_Channel | Rssi_Src_Frame_Errors | Rssi_Offset | Rssi_Invert | Rx_Uart | Adc_Device |
          Input_Filtering_Mode | Blackbox_Uart | Tri_Unarmed_Servo | Gps_Uart | Auto_Profile_Cell_Count | Tpa_Low_Rate
          | Telemetry_1_Uart | Telemetry_2_Uart | Telemetry_3_Uart | Osd_Uart | Osd_Rcchannels | Osd_Custom_Text_Uart
          | Task_Statistics | Vtx_Uart | Vcd_H_Offset | Vcd_V_Offset | Displayport_Msp_Col_Adjust |
          Displayport_Msp_Row_Adjust | Displayport_Max7456_Col_Adjust | Displayport_Max7456_Row_Adjust |
          Esc_Sensor_Uart | Frsky_Spi_Offset | Rangefinder_Uart | Opticalflow_Uart | Rcdevice_Uart | Msp_1_Uart |
          Msp_2_Uart | Msp_3_Uart | Stats_Min_Armed_Time_S | Altitude_Source | Altitude_Prefer_Baro |
          Gimbal_Roll_Rc_Gain | Gimbal_Pitch_Rc_Thr_Gain | Gimbal_Pitch_Rc_Low_Gain | Gimbal_Pitch_Rc_High_Gain |
          Gimbal_Yaw_Rc_Gain | Gimbal_Roll_Gain | Gimbal_Roll_Offset | Gimbal_Roll_Limit | Gimbal_Pitch_Gain |
          Gimbal_Pitch_Offset | Gimbal_Pitch_Low_Limit | Gimbal_Pitch_High_Limit | Gimbal_Yaw_Gain | Gimbal_Yaw_Offset
          | Gimbal_Yaw_Limit | Gimbal_Stabilisation | Gimbal_Sensitivity | Gimbal_Uart => -128,
        when Blackbox_Disable_Pids | Blackbox_Disable_Rc | Blackbox_Disable_Setpoint | Blackbox_Disable_Bat |
          Blackbox_Disable_Mag | Blackbox_Disable_Alt | Blackbox_Disable_Rssi | Blackbox_Disable_Gyro |
          Blackbox_Disable_Gyrounfilt | Blackbox_Disable_Acc | Blackbox_Disable_Attitude | Blackbox_Disable_Debug |
          Blackbox_Disable_Motors | Blackbox_Disable_Servos | Blackbox_Disable_Rpm | Blackbox_Disable_Gps |
          Blackbox_Disable_Pitot | Use_Vbat_Alerts | Use_Cbat_Alerts | Battery_Continue | Yaw_Motors_Reversed |
          Crashflip_Auto_Rearm | Rpm_Limit | Gps_Ublox_Use_Galileo | Gps_Ublox_Enable_Ana | Gps_Set_Home_Point_Once |
          Gps_Use_3d_Speed | Gps_Sbas_Integrity | Yaw_Control_Reversed | Telemetry_Disabled_Voltage |
          Telemetry_Disabled_Current | Telemetry_Disabled_Fuel | Telemetry_Disabled_Mode | Telemetry_Disabled_Acc_X |
          Telemetry_Disabled_Acc_Y | Telemetry_Disabled_Acc_Z | Telemetry_Disabled_Pitch | Telemetry_Disabled_Roll |
          Telemetry_Disabled_Heading | Telemetry_Disabled_Altitude | Telemetry_Disabled_Vario |
          Telemetry_Disabled_Lat_Long | Telemetry_Disabled_Ground_Speed | Telemetry_Disabled_Distance |
          Telemetry_Disabled_Esc_Current | Telemetry_Disabled_Esc_Voltage | Telemetry_Disabled_Esc_Rpm |
          Telemetry_Disabled_Esc_Temperature | Telemetry_Disabled_Temperature | Telemetry_Disabled_Cap_Used |
          Max7456_Preinit_Opu | Displayport_Max7456_Inv | I2c1_Pullup | I2c2_Pullup | I2c3_Pullup => 0,
        when Gyro_Hardware_Lpf | Gyro_Lpf1_Type | Gyro_Lpf2_Type | Gyro_Calib_Noise_Limit | Gyro_Overflow_Detect |
          Yaw_Spin_Recovery | Dyn_Notch_Count | Gyro_Lpf1_Dyn_Expo | Gyro_Filter_Debug_Axis | Acc_Hardware | Align_Mag
          | Mag_Bustype | Mag_I2c_Device | Mag_I2c_Address | Mag_Spi_Device | Mag_Hardware | Baro_Bustype |
          Baro_Spi_Device | Baro_I2c_Device | Baro_I2c_Address | Baro_Hardware | Pitot_Bustype | Pitot_I2c_Device |
          Pitot_I2c_Address | Pitot_Hardware | Rssi_Scale | Rssi_Src_Frame_Lpf_Period | Rssi_Smoothing | Rc_Smoothing
          | Rc_Smoothing_Auto_Factor | Rc_Smoothing_Auto_Factor_Throttle | Rc_Smoothing_Setpoint_Cutoff |
          Rc_Smoothing_Throttle_Cutoff | Rc_Smoothing_Debug_Axis | Fpv_Mix_Degrees | Max_Aux_Channels |
          Serialrx_Provider | Serialrx_Inverted | Spektrum_Sat_Bind | Spektrum_Sat_Bind_Autoreset | Srxl2_Unit_Id |
          Srxl2_Baud_Fast | Sbus_Baud_Fast | Crsf_Use_Negotiated_Baud | Airmode_Start_Throttle_Percent |
          Serialrx_Halfduplex | Msp_Override_Failsafe | Rx_Spi_Protocol | Rx_Spi_Bus | Rx_Spi_Led_Inversion |
          Blackbox_Sample_Rate | Blackbox_Device | Blackbox_Mode | Blackbox_High_Resolution | Blackbox_Baud |
          Dshot_Burst | Dshot_Bidir | Dshot_Edt | Dshot_Bitbang | Dshot_Bitbang_Timer | Use_Unsynced_Pwm |
          Motor_Pwm_Protocol | Motor_Pwm_Inversion | Motor_Poles | Motor_Output_Reordering | Thr_Corr_Value |
          Failsafe_Delay | Failsafe_Landing_Time | Failsafe_Switch_Mode | Failsafe_Procedure |
          Failsafe_Stick_Threshold | Gimbal_Mode | Cbat_Alert_Percent | Force_Battery_Cell_Count | Vbat_Hysteresis |
          Current_Meter | Battery_Meter | Vbat_Cutoff_Percent | Vbat_Display_Lpf_Period | Vbat_Sag_Lpf_Period |
          Ibat_Lpf_Period | Vbat_Duration_For_Warning | Vbat_Duration_For_Critical | Vbat_Scale | Vbat_Divider |
          Vbat_Multiplier | Beeper_Inversion | Beeper_Od | Beeper_Dshot_Beacon_Tone | Mixer_Type |
          Crashflip_Motor_Percent | Crashflip_Rate | Three_D_Switched_Mode | Channel_Forwarding_Start | Thr_Mid |
          Thr_Expo | Thr_Hover | Rates_Type | Quickrates_Rc_Expo | Roll_Rc_Rate | Pitch_Rc_Rate | Yaw_Rc_Rate |
          Roll_Expo | Pitch_Expo | Yaw_Expo | Roll_Srate | Pitch_Srate | Yaw_Srate | Throttle_Limit_Type |
          Throttle_Limit_Percent | Reboot_Character | Small_Angle | Imu_Process_Denom | Auto_Disarm_Delay |
          Gyro_Cal_On_First_Arm | Prearm_Allow_Rearm | Gps_Provider | Gps_Sbas_Mode | Gps_Auto_Config | Gps_Auto_Baud
          | Gps_Ublox_Acquire_Model | Gps_Ublox_Flight_Model | Gps_Update_Rate_Hz | Gps_Ublox_Utc_Standard | Gps_Baud
          | Gps_Rescue_Alt_Mode | Gps_Rescue_Sanity_Checks | Gps_Rescue_Min_Sats | Gps_Rescue_Allow_Arming_Without_Fix
          | Gps_Rescue_Yaw_P | Gps_Lap_Timer_Gate_Tolerance_M | Deadband | Yaw_Deadband | Alt_Hold_Climb_Rate |
          Alt_Hold_Deadband | Pos_Hold_Deadband | Poshold_Position_Source | Poshold_Opticalflow_Quality_Min |
          Pid_Process_Denom | Runaway_Takeoff_Prevention | Runaway_Takeoff_Deactivate_Throttle_Percent |
          Dterm_Lpf1_Dyn_Expo | Dterm_Lpf1_Type | Dterm_Lpf2_Type | Vbat_Sag_Compensation | Pid_At_Min_Throttle |
          Anti_Gravity_Gain | Anti_Gravity_Cutoff_Hz | Anti_Gravity_P_Gain | Crash_Recovery_Angle |
          Crash_Recovery_Rate | Crash_Recovery | Iterm_Rotation | Iterm_Relax | Iterm_Relax_Type | Iterm_Relax_Cutoff
          | Iterm_Windup | Throttle_Boost | Throttle_Boost_Cutoff | Acro_Trainer_Angle_Limit | Acro_Trainer_Debug_Axis
          | Acro_Trainer_Gain | P_Pitch | I_Pitch | D_Pitch | P_Roll | I_Roll | D_Roll | P_Yaw | I_Yaw | D_Yaw |
          Angle_P_Gain | Angle_Feedforward | Angle_Feedforward_Smoothing_Ms | Angle_Limit | Angle_Earth_Ref |
          Horizon_Level_Strength | Horizon_Limit_Sticks | Horizon_Limit_Degrees | Horizon_Ignore_Sticks |
          Chirp_Lag_Freq_Hz | Chirp_Lead_Freq_Hz | Chirp_Time_Seconds | Chirp_Repeat | D_Max_Roll | D_Max_Pitch |
          D_Max_Yaw | D_Max_Gain | D_Max_Advance | Motor_Output_Limit | Launch_Control_Mode |
          Launch_Trigger_Allow_Reset | Launch_Trigger_Throttle_Percent | Launch_Angle_Limit | Launch_Control_Gain |
          Thrust_Linear | Feedforward_Transition | Feedforward_Averaging | Feedforward_Smooth_Factor |
          Feedforward_Jitter_Factor | Feedforward_Boost | Feedforward_Max_Rate_Limit | Feedforward_Yaw_Hold_Gain |
          Feedforward_Yaw_Hold_Time | Dyn_Idle_Min_Rpm | Dyn_Idle_P_Gain | Dyn_Idle_I_Gain | Dyn_Idle_D_Gain |
          Dyn_Idle_Max_Increase | Level_Race_Mode | Simplified_Pids_Mode | Simplified_Master_Multiplier |
          Simplified_I_Gain | Simplified_D_Gain | Simplified_Pi_Gain | Simplified_D_Max_Gain |
          Simplified_Feedforward_Gain | Simplified_Pitch_D_Gain | Simplified_Pitch_Pi_Gain | Simplified_Dterm_Filter |
          Simplified_Dterm_Filter_Multiplier | Simplified_Gyro_Filter | Simplified_Gyro_Filter_Multiplier | Tpa_Mode |
          Tpa_Rate | Tpa_Low_Always | Ez_Landing_Threshold | Ez_Landing_Limit | Ez_Landing_Speed |
          Landing_Disarm_Threshold | Tlm_Inverted | Tlm_Halfduplex | Telemetry_1_Protocol | Telemetry_1_Baud |
          Telemetry_2_Protocol | Telemetry_2_Baud | Telemetry_3_Protocol | Telemetry_3_Baud | Crsf_Tlm_Accgyro |
          Frsky_Gps_Format | Frsky_Unit | Frsky_Vfas_Precision | Hott_Alarm_Int | Pid_In_Tlm | Report_Cell_Voltage |
          Ibus_Sensor | Mavlink_Min_Txbuff | Mavlink_Ext_Status_Rate | Mavlink_Rc_Chan_Rate | Mavlink_Pos_Rate |
          Mavlink_Extra1_Rate | Mavlink_Extra2_Rate | Mavlink_Extra3_Rate | Ledstrip_Visual_Beeper |
          Ledstrip_Visual_Beeper_Color | Ledstrip_Grb_Rgb | Ledstrip_Profile | Ledstrip_Race_Color |
          Ledstrip_Beacon_Color | Ledstrip_Beacon_Percent | Ledstrip_Beacon_Armed_Only | Ledstrip_Brightness |
          Transponder_Provider | Transponder_Data | Sdcard_Detect_Inverted | Sdcard_Mode | Sdcard_Spi_Bus | Osd_Units
          | Osd_Rssi_Alarm | Osd_Esc_Temp_Alarm | Osd_Core_Temp_Alarm | Osd_Ah_Max_Pit | Osd_Ah_Max_Rol |
          Osd_Ah_Invert | Osd_Logo_On_Arming | Osd_Logo_On_Arming_Duration | Osd_Arming_Logo | Osd_Use_Quick_Menu |
          Osd_Show_Spec_Prearm | Osd_Stick_Overlay_Radio_Mode | Osd_Profile | Osd_Gps_Sats_Show_Pdop |
          Osd_Displayport_Device | Osd_Camera_Frame_Width | Osd_Camera_Frame_Height | Osd_Stat_Avg_Cell_Value |
          Osd_Menu_Background | Osd_Aux_Channel | Osd_Aux_Symbol | Osd_Craftname_Msgs |
          Osd_Custom_Serial_Text_Terminator | Osd_Custom_Text_Baud | Osd_Nav_Map_Mode | Osd_Nav_Map_Centre |
          System_Hse_Mhz | Debug_Mode | Rate_6pos_Switch | Cpu_Overclock | Pwr_On_Arm_Grace | Enable_Stick_Arming |
          Vtx_Band | Vtx_Channel | Vtx_Power | Vtx_Low_Power_Disarm | Vtx_Softserial_Alt | Vtx_Type | Vtx_Halfduplex |
          Vtx_Spi_Bus | Vcd_Video_System | Max7456_Clock | Max7456_Spi_Bus | Displayport_Msp_Fonts |
          Displayport_Msp_Use_Device_Blink | Displayport_Max7456_Blk | Displayport_Max7456_Wht | Esc_Sensor_Halfduplex
          | Frsky_Spi_Autobind | Frsky_Spi_Tx_Id | Frsky_Spi_Bind_Hop_Data | Frsky_X_Rx_Num | Frsky_Spi_A1_Source |
          Cc2500_Spi_Chip_Detect | Led_Inversion | Dashboard_I2c_Bus | Dashboard_I2c_Addr | Camera_Control_Mode |
          Camera_Control_Inverted | Rangefinder_Hardware | Opticalflow_Hardware | Opticalflow_Flip_X | Pinio_Config |
          Pinio_Box | Usb_Hid_Cdc | Usb_Msc_Pin_Pullup | Flash_Spi_Bus | Rcdevice_Init_Dev_Attempts |
          Rcdevice_Protocol_Version | Gyro_1_Bustype | Gyro_1_Spibus | Gyro_1_I2c_Bus | Gyro_1_I2c_Address |
          Mco2_On_Pc9 | Spektrum_Spi_Protocol | Spektrum_Spi_Mfg_Id | Spektrum_Spi_Num_Channels | Expresslrs_Uid |
          Expresslrs_Domain | Expresslrs_Model_Id | Cpu_Late_Limit_Permille | Serialmsp_Halfduplex | Msp_1_Baud |
          Msp_2_Baud | Msp_3_Baud | Rpm_Filter_Harmonics | Rpm_Filter_Weights | Rpm_Filter_Min_Hz |
          Flysky_Spi_Rf_Channels | Stats_Save_Move_Limit | Ap_Landing_Altitude_M | Ap_Altitude_P | Ap_Altitude_I |
          Ap_Altitude_D | Ap_Altitude_A | Ap_Altitude_F | Ap_Position_P | Ap_Position_I | Ap_Position_D |
          Ap_Position_A | Ap_Position_F | Ap_Position_Cutoff | Ap_Stop_Threshold | Ap_Max_Angle | Ap_Max_Yaw_Rate |
          Ap_Yaw_P | Ap_Velocity_Drag_Coeff | Ap_Yaw_Mode | Ap_Nav_Carrot_Lead_Time | Ap_Velocity_Buildup_Max_Pitch |
          Ap_Max_Turn_Rate | Ap_Landing_Descent_Rate | Ap_Landing_Detection_Time | Ap_Landing_Spiral_Enable |
          Ap_Landing_Spiral_Rate | Ap_Landing_Velocity_Threshold | Ap_L1_Enable | Ap_L1_Turn_Rate |
          Ap_Min_Nav_Altitude_M | Ap_Rx_Loss_Policy | Ap_Geofence_Action => 0,
        when Gyro_Lpf1_Static_Hz | Gyro_Lpf2_Static_Hz | Gyro_Notch1_Hz | Gyro_Notch1_Cutoff | Gyro_Notch2_Hz |
          Gyro_Notch2_Cutoff | Gyro_Calib_Duration | Yaw_Spin_Threshold | Dyn_Notch_Q | Dyn_Notch_Min_Hz |
          Dyn_Notch_Max_Hz | Gyro_Lpf1_Dyn_Min_Hz | Gyro_Lpf1_Dyn_Max_Hz | Acc_Lpf_Hz | Mid_Rc | Min_Check | Max_Check
          | Rx_Min_Usec | Rx_Max_Usec | Adc_Vrefint_Calibration | Adc_Tempsensor_Calibration30 |
          Adc_Tempsensor_Calibration110 | Max_Throttle | Min_Command | Motor_Kv | Motor_Idle | Motor_Pwm_Rate |
          Thr_Corr_Angle | Failsafe_Throttle | Failsafe_Throttle_Low_Delay | Failsafe_Recovery_Delay | Bat_Capacity |
          Vbat_Max_Cell_Voltage | Vbat_Full_Cell_Voltage | Vbat_Min_Cell_Voltage | Vbat_Warning_Cell_Voltage |
          Vbat_Detect_Cell_Voltage | Ibatv_Offset | Rpm_Limit_P | Rpm_Limit_I | Rpm_Limit_D | Rpm_Limit_Value |
          Three_D_Deadband_Low | Three_D_Deadband_High | Three_D_Neutral | Three_D_Deadband_Throttle |
          Three_D_Limit_Low | Three_D_Limit_High | Servo_Center_Pulse | Servo_Pwm_Rate | Servo_Lowpass_Hz |
          Roll_Rate_Limit | Pitch_Rate_Limit | Yaw_Rate_Limit | Serial_Update_Rate_Hz | Imu_Dcm_Kp | Imu_Dcm_Ki |
          Gps_Rescue_Min_Start_Dist | Gps_Rescue_Initial_Climb | Gps_Rescue_Ascend_Rate | Gps_Rescue_Return_Alt |
          Gps_Rescue_Ground_Speed | Gps_Rescue_Descent_Dist | Gps_Rescue_Descend_Rate | Gps_Lap_Timer_Min_Lap_Time_S |
          Poshold_Opticalflow_Max_Range | Runaway_Takeoff_Deactivate_Delay | Dterm_Lpf1_Dyn_Min_Hz |
          Dterm_Lpf1_Dyn_Max_Hz | Dterm_Notch_Hz | Dterm_Notch_Cutoff | Acc_Limit_Yaw | Acc_Limit | Crash_Dthreshold |
          Crash_Gthreshold | Crash_Setpoint_Threshold | Crash_Time | Crash_Delay | Crash_Limit_Yaw | Pidsum_Limit |
          Pidsum_Limit_Yaw | Yaw_Lowpass_Hz | Acro_Trainer_Lookahead_Ms | F_Pitch | F_Roll | F_Yaw | Horizon_Delay_Ms
          | Chirp_Amplitude_Roll | Chirp_Amplitude_Pitch | Chirp_Amplitude_Yaw | Chirp_Frequency_Start_Deci_Hz |
          Chirp_Frequency_End_Deci_Hz | Tpa_Breakpoint | Tpa_Low_Breakpoint | Mavlink_Mah_As_Heading_Divisor |
          Ledstrip_Beacon_Period_Ms | Ledstrip_Rainbow_Delta | Ledstrip_Rainbow_Freq | Osd_Link_Quality_Alarm |
          Osd_Cap_Alarm | Osd_Alt_Alarm | Osd_Distance_Alarm | Osd_Tim1 | Osd_Tim2 | Osd_Vbat_Pos | Osd_Rssi_Pos |
          Osd_Link_Quality_Pos | Osd_Link_Tx_Power_Pos | Osd_Rssi_Dbm_Pos | Osd_Rsnr_Pos | Osd_Tim_1_Pos |
          Osd_Tim_2_Pos | Osd_Remaining_Time_Estimate_Pos | Osd_Flymode_Pos | Osd_Anti_Gravity_Pos | Osd_G_Force_Pos |
          Osd_Throttle_Pos | Osd_Vtx_Channel_Pos | Osd_Crosshairs_Pos | Osd_Ah_Sbar_Pos | Osd_Ah_Pos | Osd_Current_Pos
          | Osd_Mah_Drawn_Pos | Osd_Wh_Drawn_Pos | Osd_Motor_Diag_Pos | Osd_Craft_Name_Pos | Osd_Pilot_Name_Pos |
          Osd_Gps_Speed_Pos | Osd_Gps_Lon_Pos | Osd_Gps_Lat_Pos | Osd_Gps_Lap_Curr_Pos | Osd_Gps_Lap_Prev_Pos |
          Osd_Gps_Lap_Best3_Pos | Osd_Gps_Sats_Pos | Osd_Home_Dir_Pos | Osd_Home_Dist_Pos | Osd_Flight_Dist_Pos |
          Osd_Compass_Bar_Pos | Osd_Altitude_Pos | Osd_Pid_Roll_Pos | Osd_Pid_Pitch_Pos | Osd_Pid_Yaw_Pos |
          Osd_Debug_Pos | Osd_Debug2_Pos | Osd_Power_Pos | Osd_Pidrate_Profile_Pos | Osd_Warnings_Pos |
          Osd_Avg_Cell_Voltage_Pos | Osd_Pit_Ang_Pos | Osd_Rol_Ang_Pos | Osd_Battery_Usage_Pos | Osd_Disarmed_Pos |
          Osd_Nheading_Pos | Osd_Up_Down_Reference_Pos | Osd_Ready_Mode_Pos | Osd_Pos_Hold_Ready_Pos | Osd_Nvario_Pos
          | Osd_Esc_Tmp_Pos | Osd_Esc_Rpm_Pos | Osd_Esc_Rpm_Freq_Pos | Osd_Rtc_Date_Time_Pos |
          Osd_Adjustment_Range_Pos | Osd_Flip_Arrow_Pos | Osd_Core_Temp_Pos | Osd_Log_Status_Pos |
          Osd_Stick_Overlay_Left_Pos | Osd_Stick_Overlay_Right_Pos | Osd_Rate_Profile_Name_Pos |
          Osd_Pid_Profile_Name_Pos | Osd_Battery_Profile_Name_Pos | Osd_Profile_Name_Pos | Osd_Rcchannels_Pos |
          Osd_Camera_Frame_Pos | Osd_Efficiency_Pos | Osd_Total_Flights_Pos | Osd_Aux_Pos | Osd_Sys_Goggle_Voltage_Pos
          | Osd_Sys_Vtx_Voltage_Pos | Osd_Sys_Bitrate_Pos | Osd_Sys_Delay_Pos | Osd_Sys_Distance_Pos | Osd_Sys_Lq_Pos
          | Osd_Sys_Goggle_Dvr_Pos | Osd_Sys_Vtx_Dvr_Pos | Osd_Sys_Warnings_Pos | Osd_Sys_Vtx_Temp_Pos |
          Osd_Sys_Fan_Speed_Pos | Osd_Framerate_Hz | Osd_Aux_Scale | Osd_Lidar_Dist_Pos | Osd_Custom_Serial_Text_Pos |
          Osd_Wp_Number_Pos | Osd_Wp_Current_Lat_Pos | Osd_Wp_Current_Lon_Pos | Osd_Wp_Current_Alt_Pos |
          Osd_Wp_Distance_Pos | Osd_Wp_Direction_Pos | Osd_Wp_Next_Number_Pos | Osd_Wp_Eta_Pos | Osd_Nav_Map_Pos |
          Osd_Nav_Map_Min_Scale_M | Osd_Airspeed | Vtx_Freq | Vtx_Pit_Mode_Freq | Esc_Sensor_Current_Offset |
          Camera_Control_Ref_Voltage | Camera_Control_Key_Delay | Camera_Control_Internal_Resistance |
          Camera_Control_Button_Resistance | Rcdevice_Feature | I2c1_Clockspeed_Khz | I2c2_Clockspeed_Khz |
          I2c3_Clockspeed_Khz | Scheduler_Relax_Rx | Scheduler_Relax_Osd | Scheduler_Debug_Task | Rpm_Filter_Q |
          Rpm_Filter_Fade_Range_Hz | Rpm_Filter_Lpf_Hz | Altitude_Lpf | Rangefinder_Max_Range_Cm | Altitude_D_Lpf |
          Ap_Hover_Throttle | Ap_Throttle_Min | Ap_Throttle_Max | Ap_Max_Velocity | Ap_Waypoint_Arrival_Radius |
          Ap_Waypoint_Hold_Radius | Ap_Stick_Deadband | Ap_Throttle_Deadband | Ap_Min_Forward_Velocity |
          Ap_Nav_Corner_Speed | Ap_Nav_Corner_Delta_V | Ap_Nav_Decel | Ap_Nav_Accel | Ap_Nav_Carrot_Lead_Max |
          Ap_Nav_Preturn_Dist | Ap_Hold_Orbit_Radius | Ap_Hold_Figure8_Width | Ap_Landing_Spiral_Radius |
          Ap_Landing_Throttle_Threshold | Ap_L1_Period | Ap_L1_Min_Lookahead | Ap_L1_Max_Lookahead |
          Ap_L1_Max_Cross_Track_Error | Ap_Max_Distance_From_Home => 0,
        when Msp_Override_Channels_Mask | Osd_Warn_Bitmask | Osd_Stat_Bitmask | Rcdevice_Init_Dev_Attempt_Interval |
          Flysky_Spi_Tx_Id | Stats_Total_Flights | Stats_Total_Time_S | Stats_Total_Dist_M | Stats_Mah_Used => 0,
        when others => 0);

   function Highest (S : Setting) return Integer_64 is
     (case S is
        when Gps_Lap_Timer_Gate_Lat | Gps_Lap_Timer_Gate_Lon => 2147483647,
        when Gyro_Offset_Yaw | Acc_Trim_Pitch | Acc_Trim_Roll | Acc_Calibration | Mag_Align_Roll | Mag_Align_Pitch |
          Mag_Align_Yaw | Mag_Calibration | Baro_Drift | Align_Board_Roll | Align_Board_Pitch | Align_Board_Yaw |
          Ibata_Scale | Ibata_Offset | Ibatv_Scale | Beeper_Frequency | Mag_Declination | Dterm_Lpf1_Static_Hz |
          Dterm_Lpf2_Static_Hz | Frsky_Default_Lat | Frsky_Default_Long | Osd_Rssi_Dbm_Alarm | Osd_Rsnr_Alarm |
          Osd_Esc_Rpm_Alarm | Osd_Esc_Current_Alarm | Opticalflow_Rotation | Timezone_Offset_Minutes => 32767,
        when Rssi_Channel | Rssi_Src_Frame_Errors | Rssi_Offset | Rssi_Invert | Rx_Uart | Adc_Device |
          Input_Filtering_Mode | Blackbox_Uart | Tri_Unarmed_Servo | Gps_Uart | Auto_Profile_Cell_Count | Tpa_Low_Rate
          | Telemetry_1_Uart | Telemetry_2_Uart | Telemetry_3_Uart | Osd_Uart | Osd_Rcchannels | Osd_Custom_Text_Uart
          | Task_Statistics | Vtx_Uart | Vcd_H_Offset | Vcd_V_Offset | Displayport_Msp_Col_Adjust |
          Displayport_Msp_Row_Adjust | Displayport_Max7456_Col_Adjust | Displayport_Max7456_Row_Adjust |
          Esc_Sensor_Uart | Frsky_Spi_Offset | Rangefinder_Uart | Opticalflow_Uart | Rcdevice_Uart | Msp_1_Uart |
          Msp_2_Uart | Msp_3_Uart | Stats_Min_Armed_Time_S | Altitude_Source | Altitude_Prefer_Baro |
          Gimbal_Roll_Rc_Gain | Gimbal_Pitch_Rc_Thr_Gain | Gimbal_Pitch_Rc_Low_Gain | Gimbal_Pitch_Rc_High_Gain |
          Gimbal_Yaw_Rc_Gain | Gimbal_Roll_Gain | Gimbal_Roll_Offset | Gimbal_Roll_Limit | Gimbal_Pitch_Gain |
          Gimbal_Pitch_Offset | Gimbal_Pitch_Low_Limit | Gimbal_Pitch_High_Limit | Gimbal_Yaw_Gain | Gimbal_Yaw_Offset
          | Gimbal_Yaw_Limit | Gimbal_Stabilisation | Gimbal_Sensitivity | Gimbal_Uart => 127,
        when Blackbox_Disable_Pids | Blackbox_Disable_Rc | Blackbox_Disable_Setpoint | Blackbox_Disable_Bat |
          Blackbox_Disable_Mag | Blackbox_Disable_Alt | Blackbox_Disable_Rssi | Blackbox_Disable_Gyro |
          Blackbox_Disable_Gyrounfilt | Blackbox_Disable_Acc | Blackbox_Disable_Attitude | Blackbox_Disable_Debug |
          Blackbox_Disable_Motors | Blackbox_Disable_Servos | Blackbox_Disable_Rpm | Blackbox_Disable_Gps |
          Blackbox_Disable_Pitot | Use_Vbat_Alerts | Use_Cbat_Alerts | Battery_Continue | Yaw_Motors_Reversed |
          Crashflip_Auto_Rearm | Rpm_Limit | Gps_Ublox_Use_Galileo | Gps_Ublox_Enable_Ana | Gps_Set_Home_Point_Once |
          Gps_Use_3d_Speed | Gps_Sbas_Integrity | Yaw_Control_Reversed | Telemetry_Disabled_Voltage |
          Telemetry_Disabled_Current | Telemetry_Disabled_Fuel | Telemetry_Disabled_Mode | Telemetry_Disabled_Acc_X |
          Telemetry_Disabled_Acc_Y | Telemetry_Disabled_Acc_Z | Telemetry_Disabled_Pitch | Telemetry_Disabled_Roll |
          Telemetry_Disabled_Heading | Telemetry_Disabled_Altitude | Telemetry_Disabled_Vario |
          Telemetry_Disabled_Lat_Long | Telemetry_Disabled_Ground_Speed | Telemetry_Disabled_Distance |
          Telemetry_Disabled_Esc_Current | Telemetry_Disabled_Esc_Voltage | Telemetry_Disabled_Esc_Rpm |
          Telemetry_Disabled_Esc_Temperature | Telemetry_Disabled_Temperature | Telemetry_Disabled_Cap_Used |
          Max7456_Preinit_Opu | Displayport_Max7456_Inv | I2c1_Pullup | I2c2_Pullup | I2c3_Pullup => 1,
        when Gyro_Hardware_Lpf | Gyro_Lpf1_Type | Gyro_Lpf2_Type | Gyro_Calib_Noise_Limit | Gyro_Overflow_Detect |
          Yaw_Spin_Recovery | Dyn_Notch_Count | Gyro_Lpf1_Dyn_Expo | Gyro_Filter_Debug_Axis | Acc_Hardware | Align_Mag
          | Mag_Bustype | Mag_I2c_Device | Mag_I2c_Address | Mag_Spi_Device | Mag_Hardware | Baro_Bustype |
          Baro_Spi_Device | Baro_I2c_Device | Baro_I2c_Address | Baro_Hardware | Pitot_Bustype | Pitot_I2c_Device |
          Pitot_I2c_Address | Pitot_Hardware | Rssi_Scale | Rssi_Src_Frame_Lpf_Period | Rssi_Smoothing | Rc_Smoothing
          | Rc_Smoothing_Auto_Factor | Rc_Smoothing_Auto_Factor_Throttle | Rc_Smoothing_Setpoint_Cutoff |
          Rc_Smoothing_Throttle_Cutoff | Rc_Smoothing_Debug_Axis | Fpv_Mix_Degrees | Max_Aux_Channels |
          Serialrx_Provider | Serialrx_Inverted | Spektrum_Sat_Bind | Spektrum_Sat_Bind_Autoreset | Srxl2_Unit_Id |
          Srxl2_Baud_Fast | Sbus_Baud_Fast | Crsf_Use_Negotiated_Baud | Airmode_Start_Throttle_Percent |
          Serialrx_Halfduplex | Msp_Override_Failsafe | Rx_Spi_Protocol | Rx_Spi_Bus | Rx_Spi_Led_Inversion |
          Blackbox_Sample_Rate | Blackbox_Device | Blackbox_Mode | Blackbox_High_Resolution | Blackbox_Baud |
          Dshot_Burst | Dshot_Bidir | Dshot_Edt | Dshot_Bitbang | Dshot_Bitbang_Timer | Use_Unsynced_Pwm |
          Motor_Pwm_Protocol | Motor_Pwm_Inversion | Motor_Poles | Motor_Output_Reordering | Thr_Corr_Value |
          Failsafe_Delay | Failsafe_Landing_Time | Failsafe_Switch_Mode | Failsafe_Procedure |
          Failsafe_Stick_Threshold | Gimbal_Mode | Cbat_Alert_Percent | Force_Battery_Cell_Count | Vbat_Hysteresis |
          Current_Meter | Battery_Meter | Vbat_Cutoff_Percent | Vbat_Display_Lpf_Period | Vbat_Sag_Lpf_Period |
          Ibat_Lpf_Period | Vbat_Duration_For_Warning | Vbat_Duration_For_Critical | Vbat_Scale | Vbat_Divider |
          Vbat_Multiplier | Beeper_Inversion | Beeper_Od | Beeper_Dshot_Beacon_Tone | Mixer_Type |
          Crashflip_Motor_Percent | Crashflip_Rate | Three_D_Switched_Mode | Channel_Forwarding_Start | Thr_Mid |
          Thr_Expo | Thr_Hover | Rates_Type | Quickrates_Rc_Expo | Roll_Rc_Rate | Pitch_Rc_Rate | Yaw_Rc_Rate |
          Roll_Expo | Pitch_Expo | Yaw_Expo | Roll_Srate | Pitch_Srate | Yaw_Srate | Throttle_Limit_Type |
          Throttle_Limit_Percent | Reboot_Character | Small_Angle | Imu_Process_Denom | Auto_Disarm_Delay |
          Gyro_Cal_On_First_Arm | Prearm_Allow_Rearm | Gps_Provider | Gps_Sbas_Mode | Gps_Auto_Config | Gps_Auto_Baud
          | Gps_Ublox_Acquire_Model | Gps_Ublox_Flight_Model | Gps_Update_Rate_Hz | Gps_Ublox_Utc_Standard | Gps_Baud
          | Gps_Rescue_Alt_Mode | Gps_Rescue_Sanity_Checks | Gps_Rescue_Min_Sats | Gps_Rescue_Allow_Arming_Without_Fix
          | Gps_Rescue_Yaw_P | Gps_Lap_Timer_Gate_Tolerance_M | Deadband | Yaw_Deadband | Alt_Hold_Climb_Rate |
          Alt_Hold_Deadband | Pos_Hold_Deadband | Poshold_Position_Source | Poshold_Opticalflow_Quality_Min |
          Pid_Process_Denom | Runaway_Takeoff_Prevention | Runaway_Takeoff_Deactivate_Throttle_Percent |
          Dterm_Lpf1_Dyn_Expo | Dterm_Lpf1_Type | Dterm_Lpf2_Type | Vbat_Sag_Compensation | Pid_At_Min_Throttle |
          Anti_Gravity_Gain | Anti_Gravity_Cutoff_Hz | Anti_Gravity_P_Gain | Crash_Recovery_Angle |
          Crash_Recovery_Rate | Crash_Recovery | Iterm_Rotation | Iterm_Relax | Iterm_Relax_Type | Iterm_Relax_Cutoff
          | Iterm_Windup | Throttle_Boost | Throttle_Boost_Cutoff | Acro_Trainer_Angle_Limit | Acro_Trainer_Debug_Axis
          | Acro_Trainer_Gain | P_Pitch | I_Pitch | D_Pitch | P_Roll | I_Roll | D_Roll | P_Yaw | I_Yaw | D_Yaw |
          Angle_P_Gain | Angle_Feedforward | Angle_Feedforward_Smoothing_Ms | Angle_Limit | Angle_Earth_Ref |
          Horizon_Level_Strength | Horizon_Limit_Sticks | Horizon_Limit_Degrees | Horizon_Ignore_Sticks |
          Chirp_Lag_Freq_Hz | Chirp_Lead_Freq_Hz | Chirp_Time_Seconds | Chirp_Repeat | D_Max_Roll | D_Max_Pitch |
          D_Max_Yaw | D_Max_Gain | D_Max_Advance | Motor_Output_Limit | Launch_Control_Mode |
          Launch_Trigger_Allow_Reset | Launch_Trigger_Throttle_Percent | Launch_Angle_Limit | Launch_Control_Gain |
          Thrust_Linear | Feedforward_Transition | Feedforward_Averaging | Feedforward_Smooth_Factor |
          Feedforward_Jitter_Factor | Feedforward_Boost | Feedforward_Max_Rate_Limit | Feedforward_Yaw_Hold_Gain |
          Feedforward_Yaw_Hold_Time | Dyn_Idle_Min_Rpm | Dyn_Idle_P_Gain | Dyn_Idle_I_Gain | Dyn_Idle_D_Gain |
          Dyn_Idle_Max_Increase | Level_Race_Mode | Simplified_Pids_Mode | Simplified_Master_Multiplier |
          Simplified_I_Gain | Simplified_D_Gain | Simplified_Pi_Gain | Simplified_D_Max_Gain |
          Simplified_Feedforward_Gain | Simplified_Pitch_D_Gain | Simplified_Pitch_Pi_Gain | Simplified_Dterm_Filter |
          Simplified_Dterm_Filter_Multiplier | Simplified_Gyro_Filter | Simplified_Gyro_Filter_Multiplier | Tpa_Mode |
          Tpa_Rate | Tpa_Low_Always | Ez_Landing_Threshold | Ez_Landing_Limit | Ez_Landing_Speed |
          Landing_Disarm_Threshold | Tlm_Inverted | Tlm_Halfduplex | Telemetry_1_Protocol | Telemetry_1_Baud |
          Telemetry_2_Protocol | Telemetry_2_Baud | Telemetry_3_Protocol | Telemetry_3_Baud | Crsf_Tlm_Accgyro |
          Frsky_Gps_Format | Frsky_Unit | Frsky_Vfas_Precision | Hott_Alarm_Int | Pid_In_Tlm | Report_Cell_Voltage |
          Ibus_Sensor | Mavlink_Min_Txbuff | Mavlink_Ext_Status_Rate | Mavlink_Rc_Chan_Rate | Mavlink_Pos_Rate |
          Mavlink_Extra1_Rate | Mavlink_Extra2_Rate | Mavlink_Extra3_Rate | Ledstrip_Visual_Beeper |
          Ledstrip_Visual_Beeper_Color | Ledstrip_Grb_Rgb | Ledstrip_Profile | Ledstrip_Race_Color |
          Ledstrip_Beacon_Color | Ledstrip_Beacon_Percent | Ledstrip_Beacon_Armed_Only | Ledstrip_Brightness |
          Transponder_Provider | Transponder_Data | Sdcard_Detect_Inverted | Sdcard_Mode | Sdcard_Spi_Bus | Osd_Units
          | Osd_Rssi_Alarm | Osd_Esc_Temp_Alarm | Osd_Core_Temp_Alarm | Osd_Ah_Max_Pit | Osd_Ah_Max_Rol |
          Osd_Ah_Invert | Osd_Logo_On_Arming | Osd_Logo_On_Arming_Duration | Osd_Arming_Logo | Osd_Use_Quick_Menu |
          Osd_Show_Spec_Prearm | Osd_Stick_Overlay_Radio_Mode | Osd_Profile | Osd_Gps_Sats_Show_Pdop |
          Osd_Displayport_Device | Osd_Camera_Frame_Width | Osd_Camera_Frame_Height | Osd_Stat_Avg_Cell_Value |
          Osd_Menu_Background | Osd_Aux_Channel | Osd_Aux_Symbol | Osd_Craftname_Msgs |
          Osd_Custom_Serial_Text_Terminator | Osd_Custom_Text_Baud | Osd_Nav_Map_Mode | Osd_Nav_Map_Centre |
          System_Hse_Mhz | Debug_Mode | Rate_6pos_Switch | Cpu_Overclock | Pwr_On_Arm_Grace | Enable_Stick_Arming |
          Vtx_Band | Vtx_Channel | Vtx_Power | Vtx_Low_Power_Disarm | Vtx_Softserial_Alt | Vtx_Type | Vtx_Halfduplex |
          Vtx_Spi_Bus | Vcd_Video_System | Max7456_Clock | Max7456_Spi_Bus | Displayport_Msp_Fonts |
          Displayport_Msp_Use_Device_Blink | Displayport_Max7456_Blk | Displayport_Max7456_Wht | Esc_Sensor_Halfduplex
          | Frsky_Spi_Autobind | Frsky_Spi_Tx_Id | Frsky_Spi_Bind_Hop_Data | Frsky_X_Rx_Num | Frsky_Spi_A1_Source |
          Cc2500_Spi_Chip_Detect | Led_Inversion | Dashboard_I2c_Bus | Dashboard_I2c_Addr | Camera_Control_Mode |
          Camera_Control_Inverted | Rangefinder_Hardware | Opticalflow_Hardware | Opticalflow_Flip_X | Pinio_Config |
          Pinio_Box | Usb_Hid_Cdc | Usb_Msc_Pin_Pullup | Flash_Spi_Bus | Rcdevice_Init_Dev_Attempts |
          Rcdevice_Protocol_Version | Gyro_1_Bustype | Gyro_1_Spibus | Gyro_1_I2c_Bus | Gyro_1_I2c_Address |
          Mco2_On_Pc9 | Spektrum_Spi_Protocol | Spektrum_Spi_Mfg_Id | Spektrum_Spi_Num_Channels | Expresslrs_Uid |
          Expresslrs_Domain | Expresslrs_Model_Id | Cpu_Late_Limit_Permille | Serialmsp_Halfduplex | Msp_1_Baud |
          Msp_2_Baud | Msp_3_Baud | Rpm_Filter_Harmonics | Rpm_Filter_Weights | Rpm_Filter_Min_Hz |
          Flysky_Spi_Rf_Channels | Stats_Save_Move_Limit | Ap_Landing_Altitude_M | Ap_Altitude_P | Ap_Altitude_I |
          Ap_Altitude_D | Ap_Altitude_A | Ap_Altitude_F | Ap_Position_P | Ap_Position_I | Ap_Position_D |
          Ap_Position_A | Ap_Position_F | Ap_Position_Cutoff | Ap_Stop_Threshold | Ap_Max_Angle | Ap_Max_Yaw_Rate |
          Ap_Yaw_P | Ap_Velocity_Drag_Coeff | Ap_Yaw_Mode | Ap_Nav_Carrot_Lead_Time | Ap_Velocity_Buildup_Max_Pitch |
          Ap_Max_Turn_Rate | Ap_Landing_Descent_Rate | Ap_Landing_Detection_Time | Ap_Landing_Spiral_Enable |
          Ap_Landing_Spiral_Rate | Ap_Landing_Velocity_Threshold | Ap_L1_Enable | Ap_L1_Turn_Rate |
          Ap_Min_Nav_Altitude_M | Ap_Rx_Loss_Policy | Ap_Geofence_Action => 255,
        when Gyro_Lpf1_Static_Hz | Gyro_Lpf2_Static_Hz | Gyro_Notch1_Hz | Gyro_Notch1_Cutoff | Gyro_Notch2_Hz |
          Gyro_Notch2_Cutoff | Gyro_Calib_Duration | Yaw_Spin_Threshold | Dyn_Notch_Q | Dyn_Notch_Min_Hz |
          Dyn_Notch_Max_Hz | Gyro_Lpf1_Dyn_Min_Hz | Gyro_Lpf1_Dyn_Max_Hz | Acc_Lpf_Hz | Mid_Rc | Min_Check | Max_Check
          | Rx_Min_Usec | Rx_Max_Usec | Adc_Vrefint_Calibration | Adc_Tempsensor_Calibration30 |
          Adc_Tempsensor_Calibration110 | Max_Throttle | Min_Command | Motor_Kv | Motor_Idle | Motor_Pwm_Rate |
          Thr_Corr_Angle | Failsafe_Throttle | Failsafe_Throttle_Low_Delay | Failsafe_Recovery_Delay | Bat_Capacity |
          Vbat_Max_Cell_Voltage | Vbat_Full_Cell_Voltage | Vbat_Min_Cell_Voltage | Vbat_Warning_Cell_Voltage |
          Vbat_Detect_Cell_Voltage | Ibatv_Offset | Rpm_Limit_P | Rpm_Limit_I | Rpm_Limit_D | Rpm_Limit_Value |
          Three_D_Deadband_Low | Three_D_Deadband_High | Three_D_Neutral | Three_D_Deadband_Throttle |
          Three_D_Limit_Low | Three_D_Limit_High | Servo_Center_Pulse | Servo_Pwm_Rate | Servo_Lowpass_Hz |
          Roll_Rate_Limit | Pitch_Rate_Limit | Yaw_Rate_Limit | Serial_Update_Rate_Hz | Imu_Dcm_Kp | Imu_Dcm_Ki |
          Gps_Rescue_Min_Start_Dist | Gps_Rescue_Initial_Climb | Gps_Rescue_Ascend_Rate | Gps_Rescue_Return_Alt |
          Gps_Rescue_Ground_Speed | Gps_Rescue_Descent_Dist | Gps_Rescue_Descend_Rate | Gps_Lap_Timer_Min_Lap_Time_S |
          Poshold_Opticalflow_Max_Range | Runaway_Takeoff_Deactivate_Delay | Dterm_Lpf1_Dyn_Min_Hz |
          Dterm_Lpf1_Dyn_Max_Hz | Dterm_Notch_Hz | Dterm_Notch_Cutoff | Acc_Limit_Yaw | Acc_Limit | Crash_Dthreshold |
          Crash_Gthreshold | Crash_Setpoint_Threshold | Crash_Time | Crash_Delay | Crash_Limit_Yaw | Pidsum_Limit |
          Pidsum_Limit_Yaw | Yaw_Lowpass_Hz | Acro_Trainer_Lookahead_Ms | F_Pitch | F_Roll | F_Yaw | Horizon_Delay_Ms
          | Chirp_Amplitude_Roll | Chirp_Amplitude_Pitch | Chirp_Amplitude_Yaw | Chirp_Frequency_Start_Deci_Hz |
          Chirp_Frequency_End_Deci_Hz | Tpa_Breakpoint | Tpa_Low_Breakpoint | Mavlink_Mah_As_Heading_Divisor |
          Ledstrip_Beacon_Period_Ms | Ledstrip_Rainbow_Delta | Ledstrip_Rainbow_Freq | Osd_Link_Quality_Alarm |
          Osd_Cap_Alarm | Osd_Alt_Alarm | Osd_Distance_Alarm | Osd_Tim1 | Osd_Tim2 | Osd_Vbat_Pos | Osd_Rssi_Pos |
          Osd_Link_Quality_Pos | Osd_Link_Tx_Power_Pos | Osd_Rssi_Dbm_Pos | Osd_Rsnr_Pos | Osd_Tim_1_Pos |
          Osd_Tim_2_Pos | Osd_Remaining_Time_Estimate_Pos | Osd_Flymode_Pos | Osd_Anti_Gravity_Pos | Osd_G_Force_Pos |
          Osd_Throttle_Pos | Osd_Vtx_Channel_Pos | Osd_Crosshairs_Pos | Osd_Ah_Sbar_Pos | Osd_Ah_Pos | Osd_Current_Pos
          | Osd_Mah_Drawn_Pos | Osd_Wh_Drawn_Pos | Osd_Motor_Diag_Pos | Osd_Craft_Name_Pos | Osd_Pilot_Name_Pos |
          Osd_Gps_Speed_Pos | Osd_Gps_Lon_Pos | Osd_Gps_Lat_Pos | Osd_Gps_Lap_Curr_Pos | Osd_Gps_Lap_Prev_Pos |
          Osd_Gps_Lap_Best3_Pos | Osd_Gps_Sats_Pos | Osd_Home_Dir_Pos | Osd_Home_Dist_Pos | Osd_Flight_Dist_Pos |
          Osd_Compass_Bar_Pos | Osd_Altitude_Pos | Osd_Pid_Roll_Pos | Osd_Pid_Pitch_Pos | Osd_Pid_Yaw_Pos |
          Osd_Debug_Pos | Osd_Debug2_Pos | Osd_Power_Pos | Osd_Pidrate_Profile_Pos | Osd_Warnings_Pos |
          Osd_Avg_Cell_Voltage_Pos | Osd_Pit_Ang_Pos | Osd_Rol_Ang_Pos | Osd_Battery_Usage_Pos | Osd_Disarmed_Pos |
          Osd_Nheading_Pos | Osd_Up_Down_Reference_Pos | Osd_Ready_Mode_Pos | Osd_Pos_Hold_Ready_Pos | Osd_Nvario_Pos
          | Osd_Esc_Tmp_Pos | Osd_Esc_Rpm_Pos | Osd_Esc_Rpm_Freq_Pos | Osd_Rtc_Date_Time_Pos |
          Osd_Adjustment_Range_Pos | Osd_Flip_Arrow_Pos | Osd_Core_Temp_Pos | Osd_Log_Status_Pos |
          Osd_Stick_Overlay_Left_Pos | Osd_Stick_Overlay_Right_Pos | Osd_Rate_Profile_Name_Pos |
          Osd_Pid_Profile_Name_Pos | Osd_Battery_Profile_Name_Pos | Osd_Profile_Name_Pos | Osd_Rcchannels_Pos |
          Osd_Camera_Frame_Pos | Osd_Efficiency_Pos | Osd_Total_Flights_Pos | Osd_Aux_Pos | Osd_Sys_Goggle_Voltage_Pos
          | Osd_Sys_Vtx_Voltage_Pos | Osd_Sys_Bitrate_Pos | Osd_Sys_Delay_Pos | Osd_Sys_Distance_Pos | Osd_Sys_Lq_Pos
          | Osd_Sys_Goggle_Dvr_Pos | Osd_Sys_Vtx_Dvr_Pos | Osd_Sys_Warnings_Pos | Osd_Sys_Vtx_Temp_Pos |
          Osd_Sys_Fan_Speed_Pos | Osd_Framerate_Hz | Osd_Aux_Scale | Osd_Lidar_Dist_Pos | Osd_Custom_Serial_Text_Pos |
          Osd_Wp_Number_Pos | Osd_Wp_Current_Lat_Pos | Osd_Wp_Current_Lon_Pos | Osd_Wp_Current_Alt_Pos |
          Osd_Wp_Distance_Pos | Osd_Wp_Direction_Pos | Osd_Wp_Next_Number_Pos | Osd_Wp_Eta_Pos | Osd_Nav_Map_Pos |
          Osd_Nav_Map_Min_Scale_M | Osd_Airspeed | Vtx_Freq | Vtx_Pit_Mode_Freq | Esc_Sensor_Current_Offset |
          Camera_Control_Ref_Voltage | Camera_Control_Key_Delay | Camera_Control_Internal_Resistance |
          Camera_Control_Button_Resistance | Rcdevice_Feature | I2c1_Clockspeed_Khz | I2c2_Clockspeed_Khz |
          I2c3_Clockspeed_Khz | Scheduler_Relax_Rx | Scheduler_Relax_Osd | Scheduler_Debug_Task | Rpm_Filter_Q |
          Rpm_Filter_Fade_Range_Hz | Rpm_Filter_Lpf_Hz | Altitude_Lpf | Rangefinder_Max_Range_Cm | Altitude_D_Lpf |
          Ap_Hover_Throttle | Ap_Throttle_Min | Ap_Throttle_Max | Ap_Max_Velocity | Ap_Waypoint_Arrival_Radius |
          Ap_Waypoint_Hold_Radius | Ap_Stick_Deadband | Ap_Throttle_Deadband | Ap_Min_Forward_Velocity |
          Ap_Nav_Corner_Speed | Ap_Nav_Corner_Delta_V | Ap_Nav_Decel | Ap_Nav_Accel | Ap_Nav_Carrot_Lead_Max |
          Ap_Nav_Preturn_Dist | Ap_Hold_Orbit_Radius | Ap_Hold_Figure8_Width | Ap_Landing_Spiral_Radius |
          Ap_Landing_Throttle_Threshold | Ap_L1_Period | Ap_L1_Min_Lookahead | Ap_L1_Max_Lookahead |
          Ap_L1_Max_Cross_Track_Error | Ap_Max_Distance_From_Home => 65535,
        when Msp_Override_Channels_Mask | Osd_Warn_Bitmask | Osd_Stat_Bitmask | Rcdevice_Init_Dev_Attempt_Interval |
          Flysky_Spi_Tx_Id | Stats_Total_Flights | Stats_Total_Time_S | Stats_Total_Dist_M | Stats_Mah_Used =>
          4294967295,
        when others => 0);

   procedure Set (C : in out Configuration; S : Setting; Value : Integer_64; Profile : Natural := 0;
                  Index : Natural := 0)
   is
      F    : constant Value_Format := Value_Formats (S);
      Pos  : constant Natural := Natural (Value_Offsets (S)) + Index * F.Width;
      Mask : constant Unsigned_32 := Shift_Left (1, Describe (S).Count);
      D    : Config_Codec.Group_Data;
      Word : Unsigned_32;
   begin
      if F.Kind = Text then
         return;
      end if;
      Config_Codec.Encode_Group (C, Describe (S).Group, Profile, D);
      if F.Kind = Bit then
         Word := Word_At (D, S, Index);
         Word := (if Value /= 0 then Word or Mask else Word and not Mask);
      else
         Word := Unsigned_32'Mod (Value);
      end if;
      for K in 0 .. F.Width - 1 loop
         D (Pos + K) := Unsigned_8 (Shift_Right (Word, 8 * K) and 16#FF#);
      end loop;
      Config_Codec.Decode_Group (D, Describe (S).Group, Profile, C);
   end Set;

   --  The first Max bytes cleared, then the text, cut at Max.
   procedure Put_Text (B : in out Bytes; Max : Natural; Text : String) is
      Last : constant Natural := Natural'Min (Max, B'Length);
   begin
      for I in 0 .. Last - 1 loop
         B (B'First + I) := 0;
      end loop;
      for I in 0 .. Natural'Min (Text'Length, Last) - 1 loop
         B (B'First + I) := Character'Pos (Text (Text'First + I));
      end loop;
   end Put_Text;

   procedure Set_Text_Battery_Profiles_Profile (G : in out Battery_Profile_Record; S : Setting; Text : String)
     with Pre => S in Battery_Profile_Name
   is
   begin
      case S is
         when Battery_Profile_Name =>
            Put_Text (G.Profile_Name, 8, Text);
         when others =>
            null;
      end case;
   end Set_Text_Battery_Profiles_Profile;

   procedure Set_Text_Control_Rate_Profiles_Profile (G : in out Control_Rate_Config_Record; S : Setting; Text : String)
     with Pre => S in Rateprofile_Name
   is
   begin
      case S is
         when Rateprofile_Name =>
            Put_Text (G.Profile_Name, 8, Text);
         when others =>
            null;
      end case;
   end Set_Text_Control_Rate_Profiles_Profile;

   procedure Set_Text_Gps_Config (G : in out Gps_Config_Record; S : Setting; Text : String)
     with Pre => S in Gps_Nmea_Custom_Commands
   is
   begin
      case S is
         when Gps_Nmea_Custom_Commands =>
            Put_Text (G.Nmea_Custom_Commands, 64, Text);
         when others =>
            null;
      end case;
   end Set_Text_Gps_Config;

   procedure Set_Text_Pid_Profiles_Profile (G : in out Pid_Profile_Record; S : Setting; Text : String)
     with Pre => S in Profile_Name
   is
   begin
      case S is
         when Profile_Name =>
            Put_Text (G.Profile_Name, 8, Text);
         when others =>
            null;
      end case;
   end Set_Text_Pid_Profiles_Profile;

   procedure Set_Text_Osd_Config (G : in out Osd_Config_Record; S : Setting; Text : String)
     with Pre => S in Osd_Profile_1_Name | Osd_Profile_2_Name | Osd_Profile_3_Name
   is
   begin
      case S is
         when Osd_Profile_1_Name =>
            Put_Text (G.Profile (0), 16, Text);
         when Osd_Profile_2_Name =>
            Put_Text (G.Profile (1), 16, Text);
         when Osd_Profile_3_Name =>
            Put_Text (G.Profile (2), 16, Text);
         when others =>
            null;
      end case;
   end Set_Text_Osd_Config;

   procedure Set_Text_Pilot_Config (G : in out Pilot_Config_Record; S : Setting; Text : String)
     with Pre => S in Craft_Name | Pilot_Name
   is
   begin
      case S is
         when Craft_Name =>
            Put_Text (G.Craft_Name, 16, Text);
         when Pilot_Name =>
            Put_Text (G.Pilot_Name, 16, Text);
         when others =>
            null;
      end case;
   end Set_Text_Pilot_Config;

   procedure Set_Text_Mode_Activation_Config (G : in out Mode_Activation_Config_Record; S : Setting; Text : String)
     with Pre => S in Box_User_1_Name | Box_User_2_Name | Box_User_3_Name | Box_User_4_Name
   is
   begin
      case S is
         when Box_User_1_Name =>
            Put_Text (G.Box_User_Names (0), 16, Text);
         when Box_User_2_Name =>
            Put_Text (G.Box_User_Names (1), 16, Text);
         when Box_User_3_Name =>
            Put_Text (G.Box_User_Names (2), 16, Text);
         when Box_User_4_Name =>
            Put_Text (G.Box_User_Names (3), 16, Text);
         when others =>
            null;
      end case;
   end Set_Text_Mode_Activation_Config;

   procedure Set_Text (C : in out Configuration; S : Setting; Text : String; Profile : Natural := 0) is
   begin
      case S is
         when Battery_Profile_Name =>
            Set_Text_Battery_Profiles_Profile (C.Battery_Profiles (Profile), S, Text);
         when Rateprofile_Name =>
            Set_Text_Control_Rate_Profiles_Profile (C.Control_Rate_Profiles (Profile), S, Text);
         when Gps_Nmea_Custom_Commands =>
            Set_Text_Gps_Config (C.Gps_Config, S, Text);
         when Profile_Name =>
            Set_Text_Pid_Profiles_Profile (C.Pid_Profiles (Profile), S, Text);
         when Osd_Profile_1_Name | Osd_Profile_2_Name | Osd_Profile_3_Name =>
            Set_Text_Osd_Config (C.Osd_Config, S, Text);
         when Craft_Name | Pilot_Name =>
            Set_Text_Pilot_Config (C.Pilot_Config, S, Text);
         when Box_User_1_Name | Box_User_2_Name | Box_User_3_Name | Box_User_4_Name =>
            Set_Text_Mode_Activation_Config (C.Mode_Activation_Config, S, Text);
         when others =>
            null;
      end case;
   end Set_Text;

end Adaflight.Config_Groups;
