--  The command line's settings: each one's name, value type, scope and
--  mode with its limits, the parameter group that holds it, and the
--  lookup tables of value names. Generated from the settings oracle.
with Interfaces;

package Adaflight.Settings_Table with SPARK_Mode is

   use type Interfaces.Integer_64;

   type Value_Type is (U8, I8, U16, I16, U32, I32);
   type Value_Scope is (Master, PID_Profile, Rate_Profile, Hardware, Battery_Profile);
   type Value_Mode is (Direct, Lookup, List, Bitset, Text, Identifier);

   type Lookup_Table is
     (Table_Off_On, Table_Unit, Table_Alignment, Table_Gps_Provider, Table_Gps_Sbas_Mode, Table_Gps_Ublox_Models,
      Table_Gps_Ublox_Utc_Standard, Table_Ap_Yaw_Mode, Table_Ap_Rx_Loss_Policy, Table_Ap_Geofence_Action,
      Table_Gps_Rescue_Sanity_Check, Table_Gps_Rescue_Alt_Mode, Table_Blackbox_Device, Table_Blackbox_Mode,
      Table_Blackbox_Sample_Rate, Table_Current_Meter, Table_Voltage_Meter, Table_Gimbal_Mode, Table_Serial_Rx,
      Table_Rx_Spi, Table_Gyro_Hardware_Lpf, Table_Acc_Hardware, Table_Baro_Hardware, Table_Mag_Hardware,
      Table_Debug, Table_Motor_Pwm_Protocol, Table_Dshot_Edt, Table_Gyro_Lpf_Type, Table_Dterm_Lpf_Type,
      Table_Failsafe, Table_Failsafe_Switch_Mode, Table_Crash_Recovery, Table_Bus_Type, Table_Max7456_Clock,
      Table_Rx_Frsky_Spi_A1_Source, Table_Rangefinder_Hardware, Table_Opticalflow_Hardware, Table_Pitot_Hardware,
      Table_Poshold_Source, Table_Gyro_Overflow_Check, Table_Rates_Type, Table_Overclock, Table_Rgb_Grb,
      Table_Throttle_Limit_Type, Table_Video_System, Table_Iterm_Relax, Table_Iterm_Relax_Type,
      Table_Acro_Trainer_Debug, Table_Rc_Smoothing_Debug, Table_Vtx_Low_Power_Disarm, Table_Sdcard_Mode,
      Table_Launch_Control_Mode, Table_Tpa_Mode, Table_Spa_Mode, Table_Led_Profile, Table_Ledstrip_Color,
      Table_Gyro_Filter_Debug, Table_Position_Alt_Source, Table_Off_On_Auto, Table_Feedforward_Averaging,
      Table_Dshot_Bitbanged_Timer, Table_Osd_Displayport_Device, Table_Vtx_Type, Table_Osd_Logo_On_Arming,
      Table_Osd_Custom_Text_Terminator, Table_Mixer_Type, Table_Simplified_Tuning_Pids_Mode,
      Table_Cms_Background, Table_Freq_Domain, Table_Transponder_Provider, Table_Baud_Rate,
      Table_Telemetry_Protocol);

   type Setting is
     (Gyro_Hardware_Lpf, Gyro_Lpf1_Type, Gyro_Lpf1_Static_Hz, Gyro_Lpf2_Type, Gyro_Lpf2_Static_Hz,
      Gyro_Notch1_Hz, Gyro_Notch1_Cutoff, Gyro_Notch2_Hz, Gyro_Notch2_Cutoff, Gyro_Calib_Duration,
      Gyro_Calib_Noise_Limit, Gyro_Offset_Yaw, Gyro_Overflow_Detect, Yaw_Spin_Recovery, Yaw_Spin_Threshold,
      Dyn_Notch_Count, Dyn_Notch_Q, Dyn_Notch_Min_Hz, Dyn_Notch_Max_Hz, Gyro_Lpf1_Dyn_Min_Hz,
      Gyro_Lpf1_Dyn_Max_Hz, Gyro_Lpf1_Dyn_Expo, Gyro_Filter_Debug_Axis, Acc_Hardware, Acc_Lpf_Hz, Acc_Trim_Pitch,
      Acc_Trim_Roll, Acc_Calibration, Align_Mag, Mag_Align_Roll, Mag_Align_Pitch, Mag_Align_Yaw, Mag_Bustype,
      Mag_I2c_Device, Mag_I2c_Address, Mag_Spi_Device, Mag_Hardware, Mag_Calibration, Baro_Bustype,
      Baro_Spi_Device, Baro_I2c_Device, Baro_I2c_Address, Baro_Hardware, Baro_Drift, Pitot_Bustype,
      Pitot_I2c_Device, Pitot_I2c_Address, Pitot_Hardware, Mid_Rc, Min_Check, Max_Check, Rssi_Channel,
      Rssi_Src_Frame_Errors, Rssi_Scale, Rssi_Offset, Rssi_Invert, Rssi_Src_Frame_Lpf_Period, Rssi_Smoothing,
      Rc_Smoothing, Rc_Smoothing_Auto_Factor, Rc_Smoothing_Auto_Factor_Throttle, Rc_Smoothing_Setpoint_Cutoff,
      Rc_Smoothing_Throttle_Cutoff, Rc_Smoothing_Debug_Axis, Fpv_Mix_Degrees, Max_Aux_Channels,
      Serialrx_Provider, Serialrx_Inverted, Spektrum_Sat_Bind, Spektrum_Sat_Bind_Autoreset, Srxl2_Unit_Id,
      Srxl2_Baud_Fast, Sbus_Baud_Fast, Crsf_Use_Negotiated_Baud, Airmode_Start_Throttle_Percent, Rx_Min_Usec,
      Rx_Max_Usec, Serialrx_Halfduplex, Rx_Uart, Msp_Override_Channels_Mask, Msp_Override_Failsafe,
      Rx_Spi_Protocol, Rx_Spi_Bus, Rx_Spi_Led_Inversion, Adc_Device, Adc_Vrefint_Calibration,
      Adc_Tempsensor_Calibration30, Adc_Tempsensor_Calibration110, Input_Filtering_Mode, Blackbox_Sample_Rate,
      Blackbox_Device, Blackbox_Disable_Pids, Blackbox_Disable_Rc, Blackbox_Disable_Setpoint,
      Blackbox_Disable_Bat, Blackbox_Disable_Mag, Blackbox_Disable_Alt, Blackbox_Disable_Rssi,
      Blackbox_Disable_Gyro, Blackbox_Disable_Gyrounfilt, Blackbox_Disable_Acc, Blackbox_Disable_Attitude,
      Blackbox_Disable_Debug, Blackbox_Disable_Motors, Blackbox_Disable_Servos, Blackbox_Disable_Rpm,
      Blackbox_Disable_Gps, Blackbox_Disable_Pitot, Blackbox_Mode, Blackbox_High_Resolution, Blackbox_Uart,
      Blackbox_Baud, Max_Throttle, Min_Command, Motor_Kv, Motor_Idle, Dshot_Burst, Dshot_Bidir, Dshot_Edt,
      Dshot_Bitbang, Dshot_Bitbang_Timer, Use_Unsynced_Pwm, Motor_Pwm_Protocol, Motor_Pwm_Rate,
      Motor_Pwm_Inversion, Motor_Poles, Motor_Output_Reordering, Thr_Corr_Value, Thr_Corr_Angle, Failsafe_Delay,
      Failsafe_Landing_Time, Failsafe_Throttle, Failsafe_Switch_Mode, Failsafe_Throttle_Low_Delay,
      Failsafe_Procedure, Failsafe_Recovery_Delay, Failsafe_Stick_Threshold, Align_Board_Roll, Align_Board_Pitch,
      Align_Board_Yaw, Gimbal_Mode, Battery_Profile_Name, Bat_Capacity, Vbat_Max_Cell_Voltage,
      Vbat_Full_Cell_Voltage, Vbat_Min_Cell_Voltage, Vbat_Warning_Cell_Voltage, Cbat_Alert_Percent,
      Force_Battery_Cell_Count, Vbat_Hysteresis, Current_Meter, Battery_Meter, Vbat_Detect_Cell_Voltage,
      Use_Vbat_Alerts, Use_Cbat_Alerts, Vbat_Cutoff_Percent, Vbat_Display_Lpf_Period, Vbat_Sag_Lpf_Period,
      Ibat_Lpf_Period, Vbat_Duration_For_Warning, Vbat_Duration_For_Critical, Vbat_Scale, Vbat_Divider,
      Vbat_Multiplier, Ibata_Scale, Ibata_Offset, Ibatv_Scale, Ibatv_Offset, Battery_Continue, Beeper_Inversion,
      Beeper_Od, Beeper_Frequency, Beeper_Dshot_Beacon_Tone, Yaw_Motors_Reversed, Mixer_Type,
      Crashflip_Motor_Percent, Crashflip_Rate, Crashflip_Auto_Rearm, Rpm_Limit, Rpm_Limit_P, Rpm_Limit_I,
      Rpm_Limit_D, Rpm_Limit_Value, Three_D_Deadband_Low, Three_D_Deadband_High, Three_D_Neutral,
      Three_D_Deadband_Throttle, Three_D_Limit_Low, Three_D_Limit_High, Three_D_Switched_Mode,
      Servo_Center_Pulse, Servo_Pwm_Rate, Servo_Lowpass_Hz, Tri_Unarmed_Servo, Channel_Forwarding_Start,
      Rateprofile_Name, Thr_Mid, Thr_Expo, Thr_Hover, Rates_Type, Quickrates_Rc_Expo, Roll_Rc_Rate,
      Pitch_Rc_Rate, Yaw_Rc_Rate, Roll_Expo, Pitch_Expo, Yaw_Expo, Roll_Srate, Pitch_Srate, Yaw_Srate,
      Throttle_Limit_Type, Throttle_Limit_Percent, Roll_Rate_Limit, Pitch_Rate_Limit, Yaw_Rate_Limit,
      Reboot_Character, Serial_Update_Rate_Hz, Imu_Dcm_Kp, Imu_Dcm_Ki, Small_Angle, Imu_Process_Denom,
      Mag_Declination, Auto_Disarm_Delay, Gyro_Cal_On_First_Arm, Prearm_Allow_Rearm, Gps_Provider, Gps_Sbas_Mode,
      Gps_Auto_Config, Gps_Auto_Baud, Gps_Ublox_Acquire_Model, Gps_Ublox_Flight_Model, Gps_Update_Rate_Hz,
      Gps_Ublox_Utc_Standard, Gps_Ublox_Use_Galileo, Gps_Ublox_Enable_Ana, Gps_Set_Home_Point_Once,
      Gps_Use_3d_Speed, Gps_Sbas_Integrity, Gps_Nmea_Custom_Commands, Gps_Uart, Gps_Baud,
      Gps_Rescue_Min_Start_Dist, Gps_Rescue_Alt_Mode, Gps_Rescue_Initial_Climb, Gps_Rescue_Ascend_Rate,
      Gps_Rescue_Return_Alt, Gps_Rescue_Ground_Speed, Gps_Rescue_Descent_Dist, Gps_Rescue_Descend_Rate,
      Gps_Rescue_Sanity_Checks, Gps_Rescue_Min_Sats, Gps_Rescue_Allow_Arming_Without_Fix, Gps_Rescue_Yaw_P,
      Gps_Lap_Timer_Gate_Lat, Gps_Lap_Timer_Gate_Lon, Gps_Lap_Timer_Min_Lap_Time_S,
      Gps_Lap_Timer_Gate_Tolerance_M, Deadband, Yaw_Deadband, Yaw_Control_Reversed, Alt_Hold_Climb_Rate,
      Alt_Hold_Deadband, Pos_Hold_Deadband, Poshold_Position_Source, Poshold_Opticalflow_Quality_Min,
      Poshold_Opticalflow_Max_Range, Pid_Process_Denom, Runaway_Takeoff_Prevention,
      Runaway_Takeoff_Deactivate_Delay, Runaway_Takeoff_Deactivate_Throttle_Percent, Profile_Name,
      Dterm_Lpf1_Dyn_Min_Hz, Dterm_Lpf1_Dyn_Max_Hz, Dterm_Lpf1_Dyn_Expo, Dterm_Lpf1_Type, Dterm_Lpf1_Static_Hz,
      Dterm_Lpf2_Type, Dterm_Lpf2_Static_Hz, Dterm_Notch_Hz, Dterm_Notch_Cutoff, Vbat_Sag_Compensation,
      Pid_At_Min_Throttle, Anti_Gravity_Gain, Anti_Gravity_Cutoff_Hz, Anti_Gravity_P_Gain, Acc_Limit_Yaw,
      Acc_Limit, Crash_Dthreshold, Crash_Gthreshold, Crash_Setpoint_Threshold, Crash_Time, Crash_Delay,
      Crash_Recovery_Angle, Crash_Recovery_Rate, Crash_Limit_Yaw, Crash_Recovery, Iterm_Rotation, Iterm_Relax,
      Iterm_Relax_Type, Iterm_Relax_Cutoff, Iterm_Windup, Pidsum_Limit, Pidsum_Limit_Yaw, Yaw_Lowpass_Hz,
      Throttle_Boost, Throttle_Boost_Cutoff, Acro_Trainer_Angle_Limit, Acro_Trainer_Lookahead_Ms,
      Acro_Trainer_Debug_Axis, Acro_Trainer_Gain, P_Pitch, I_Pitch, D_Pitch, F_Pitch, P_Roll, I_Roll, D_Roll,
      F_Roll, P_Yaw, I_Yaw, D_Yaw, F_Yaw, Angle_P_Gain, Angle_Feedforward, Angle_Feedforward_Smoothing_Ms,
      Angle_Limit, Angle_Earth_Ref, Horizon_Level_Strength, Horizon_Limit_Sticks, Horizon_Limit_Degrees,
      Horizon_Ignore_Sticks, Horizon_Delay_Ms, Chirp_Lag_Freq_Hz, Chirp_Lead_Freq_Hz, Chirp_Amplitude_Roll,
      Chirp_Amplitude_Pitch, Chirp_Amplitude_Yaw, Chirp_Frequency_Start_Deci_Hz, Chirp_Frequency_End_Deci_Hz,
      Chirp_Time_Seconds, Chirp_Repeat, D_Max_Roll, D_Max_Pitch, D_Max_Yaw, D_Max_Gain, D_Max_Advance,
      Motor_Output_Limit, Auto_Profile_Cell_Count, Launch_Control_Mode, Launch_Trigger_Allow_Reset,
      Launch_Trigger_Throttle_Percent, Launch_Angle_Limit, Launch_Control_Gain, Thrust_Linear,
      Feedforward_Transition, Feedforward_Averaging, Feedforward_Smooth_Factor, Feedforward_Jitter_Factor,
      Feedforward_Boost, Feedforward_Max_Rate_Limit, Feedforward_Yaw_Hold_Gain, Feedforward_Yaw_Hold_Time,
      Dyn_Idle_Min_Rpm, Dyn_Idle_P_Gain, Dyn_Idle_I_Gain, Dyn_Idle_D_Gain, Dyn_Idle_Max_Increase,
      Level_Race_Mode, Simplified_Pids_Mode, Simplified_Master_Multiplier, Simplified_I_Gain, Simplified_D_Gain,
      Simplified_Pi_Gain, Simplified_D_Max_Gain, Simplified_Feedforward_Gain, Simplified_Pitch_D_Gain,
      Simplified_Pitch_Pi_Gain, Simplified_Dterm_Filter, Simplified_Dterm_Filter_Multiplier,
      Simplified_Gyro_Filter, Simplified_Gyro_Filter_Multiplier, Tpa_Mode, Tpa_Rate, Tpa_Breakpoint,
      Tpa_Low_Rate, Tpa_Low_Breakpoint, Tpa_Low_Always, Ez_Landing_Threshold, Ez_Landing_Limit, Ez_Landing_Speed,
      Landing_Disarm_Threshold, Tlm_Inverted, Tlm_Halfduplex, Telemetry_1_Protocol, Telemetry_1_Uart,
      Telemetry_1_Baud, Telemetry_2_Protocol, Telemetry_2_Uart, Telemetry_2_Baud, Telemetry_3_Protocol,
      Telemetry_3_Uart, Telemetry_3_Baud, Crsf_Tlm_Accgyro, Frsky_Default_Lat, Frsky_Default_Long,
      Frsky_Gps_Format, Frsky_Unit, Frsky_Vfas_Precision, Hott_Alarm_Int, Pid_In_Tlm, Report_Cell_Voltage,
      Ibus_Sensor, Mavlink_Mah_As_Heading_Divisor, Mavlink_Min_Txbuff, Mavlink_Ext_Status_Rate,
      Mavlink_Rc_Chan_Rate, Mavlink_Pos_Rate, Mavlink_Extra1_Rate, Mavlink_Extra2_Rate, Mavlink_Extra3_Rate,
      Telemetry_Disabled_Voltage, Telemetry_Disabled_Current, Telemetry_Disabled_Fuel, Telemetry_Disabled_Mode,
      Telemetry_Disabled_Acc_X, Telemetry_Disabled_Acc_Y, Telemetry_Disabled_Acc_Z, Telemetry_Disabled_Pitch,
      Telemetry_Disabled_Roll, Telemetry_Disabled_Heading, Telemetry_Disabled_Altitude, Telemetry_Disabled_Vario,
      Telemetry_Disabled_Lat_Long, Telemetry_Disabled_Ground_Speed, Telemetry_Disabled_Distance,
      Telemetry_Disabled_Esc_Current, Telemetry_Disabled_Esc_Voltage, Telemetry_Disabled_Esc_Rpm,
      Telemetry_Disabled_Esc_Temperature, Telemetry_Disabled_Temperature, Telemetry_Disabled_Cap_Used,
      Ledstrip_Visual_Beeper, Ledstrip_Visual_Beeper_Color, Ledstrip_Grb_Rgb, Ledstrip_Profile,
      Ledstrip_Race_Color, Ledstrip_Beacon_Color, Ledstrip_Beacon_Period_Ms, Ledstrip_Beacon_Percent,
      Ledstrip_Beacon_Armed_Only, Ledstrip_Brightness, Ledstrip_Rainbow_Delta, Ledstrip_Rainbow_Freq,
      Transponder_Provider, Transponder_Data, Sdcard_Detect_Inverted, Sdcard_Mode, Osd_Units, Osd_Warn_Bitmask,
      Osd_Rssi_Alarm, Osd_Link_Quality_Alarm, Osd_Rssi_Dbm_Alarm, Osd_Rsnr_Alarm, Osd_Cap_Alarm, Osd_Alt_Alarm,
      Osd_Distance_Alarm, Osd_Esc_Temp_Alarm, Osd_Esc_Rpm_Alarm, Osd_Esc_Current_Alarm, Osd_Core_Temp_Alarm,
      Osd_Ah_Max_Pit, Osd_Ah_Max_Rol, Osd_Ah_Invert, Osd_Logo_On_Arming, Osd_Logo_On_Arming_Duration,
      Osd_Arming_Logo, Osd_Use_Quick_Menu, Osd_Show_Spec_Prearm, Osd_Tim1, Osd_Tim2, Osd_Vbat_Pos, Osd_Rssi_Pos,
      Osd_Link_Quality_Pos, Osd_Link_Tx_Power_Pos, Osd_Rssi_Dbm_Pos, Osd_Rsnr_Pos, Osd_Tim_1_Pos, Osd_Tim_2_Pos,
      Osd_Remaining_Time_Estimate_Pos, Osd_Flymode_Pos, Osd_Anti_Gravity_Pos, Osd_G_Force_Pos, Osd_Throttle_Pos,
      Osd_Vtx_Channel_Pos, Osd_Crosshairs_Pos, Osd_Ah_Sbar_Pos, Osd_Ah_Pos, Osd_Current_Pos, Osd_Mah_Drawn_Pos,
      Osd_Wh_Drawn_Pos, Osd_Motor_Diag_Pos, Osd_Craft_Name_Pos, Osd_Pilot_Name_Pos, Osd_Gps_Speed_Pos,
      Osd_Gps_Lon_Pos, Osd_Gps_Lat_Pos, Osd_Gps_Lap_Curr_Pos, Osd_Gps_Lap_Prev_Pos, Osd_Gps_Lap_Best3_Pos,
      Osd_Gps_Sats_Pos, Osd_Home_Dir_Pos, Osd_Home_Dist_Pos, Osd_Flight_Dist_Pos, Osd_Compass_Bar_Pos,
      Osd_Altitude_Pos, Osd_Pid_Roll_Pos, Osd_Pid_Pitch_Pos, Osd_Pid_Yaw_Pos, Osd_Debug_Pos, Osd_Debug2_Pos,
      Osd_Power_Pos, Osd_Pidrate_Profile_Pos, Osd_Warnings_Pos, Osd_Avg_Cell_Voltage_Pos, Osd_Pit_Ang_Pos,
      Osd_Rol_Ang_Pos, Osd_Battery_Usage_Pos, Osd_Disarmed_Pos, Osd_Nheading_Pos, Osd_Up_Down_Reference_Pos,
      Osd_Ready_Mode_Pos, Osd_Pos_Hold_Ready_Pos, Osd_Nvario_Pos, Osd_Esc_Tmp_Pos, Osd_Esc_Rpm_Pos,
      Osd_Esc_Rpm_Freq_Pos, Osd_Rtc_Date_Time_Pos, Osd_Adjustment_Range_Pos, Osd_Flip_Arrow_Pos,
      Osd_Core_Temp_Pos, Osd_Log_Status_Pos, Osd_Stick_Overlay_Left_Pos, Osd_Stick_Overlay_Right_Pos,
      Osd_Stick_Overlay_Radio_Mode, Osd_Rate_Profile_Name_Pos, Osd_Pid_Profile_Name_Pos,
      Osd_Battery_Profile_Name_Pos, Osd_Profile_Name_Pos, Osd_Rcchannels_Pos, Osd_Camera_Frame_Pos,
      Osd_Efficiency_Pos, Osd_Total_Flights_Pos, Osd_Aux_Pos, Osd_Sys_Goggle_Voltage_Pos,
      Osd_Sys_Vtx_Voltage_Pos, Osd_Sys_Bitrate_Pos, Osd_Sys_Delay_Pos, Osd_Sys_Distance_Pos, Osd_Sys_Lq_Pos,
      Osd_Sys_Goggle_Dvr_Pos, Osd_Sys_Vtx_Dvr_Pos, Osd_Sys_Warnings_Pos, Osd_Sys_Vtx_Temp_Pos,
      Osd_Sys_Fan_Speed_Pos, Osd_Stat_Bitmask, Osd_Profile, Osd_Profile_1_Name, Osd_Profile_2_Name,
      Osd_Profile_3_Name, Osd_Gps_Sats_Show_Pdop, Osd_Displayport_Device, Osd_Uart, Osd_Rcchannels,
      Osd_Camera_Frame_Width, Osd_Camera_Frame_Height, Osd_Stat_Avg_Cell_Value, Osd_Framerate_Hz,
      Osd_Menu_Background, Osd_Aux_Channel, Osd_Aux_Scale, Osd_Aux_Symbol, Osd_Craftname_Msgs,
      Osd_Lidar_Dist_Pos, Osd_Custom_Serial_Text_Pos, Osd_Custom_Serial_Text_Terminator, Osd_Custom_Text_Uart,
      Osd_Custom_Text_Baud, Osd_Wp_Number_Pos, Osd_Wp_Current_Lat_Pos, Osd_Wp_Current_Lon_Pos,
      Osd_Wp_Current_Alt_Pos, Osd_Wp_Distance_Pos, Osd_Wp_Direction_Pos, Osd_Wp_Next_Number_Pos, Osd_Wp_Eta_Pos,
      Osd_Nav_Map_Pos, Osd_Nav_Map_Mode, Osd_Nav_Map_Centre, Osd_Nav_Map_Min_Scale_M, Osd_Airspeed,
      System_Hse_Mhz, Task_Statistics, Debug_Mode, Rate_6pos_Switch, Cpu_Overclock, Pwr_On_Arm_Grace,
      Enable_Stick_Arming, Vtx_Band, Vtx_Channel, Vtx_Power, Vtx_Low_Power_Disarm, Vtx_Softserial_Alt, Vtx_Type,
      Vtx_Uart, Vtx_Freq, Vtx_Pit_Mode_Freq, Vtx_Halfduplex, Vtx_Spi_Bus, Vcd_Video_System, Vcd_H_Offset,
      Vcd_V_Offset, Max7456_Clock, Max7456_Spi_Bus, Max7456_Preinit_Opu, Displayport_Msp_Col_Adjust,
      Displayport_Msp_Row_Adjust, Displayport_Msp_Fonts, Displayport_Msp_Use_Device_Blink,
      Displayport_Max7456_Col_Adjust, Displayport_Max7456_Row_Adjust, Displayport_Max7456_Inv,
      Displayport_Max7456_Blk, Displayport_Max7456_Wht, Esc_Sensor_Halfduplex, Esc_Sensor_Current_Offset,
      Esc_Sensor_Uart, Frsky_Spi_Autobind, Frsky_Spi_Tx_Id, Frsky_Spi_Offset, Frsky_Spi_Bind_Hop_Data,
      Frsky_X_Rx_Num, Frsky_Spi_A1_Source, Cc2500_Spi_Chip_Detect, Led_Inversion, Dashboard_I2c_Bus,
      Dashboard_I2c_Addr, Rangefinder_Hardware, Rangefinder_Uart, Opticalflow_Hardware, Opticalflow_Uart,
      Opticalflow_Rotation, Opticalflow_Flip_X, Pinio_Config, Pinio_Box, Usb_Hid_Cdc, Usb_Msc_Pin_Pullup,
      Flash_Spi_Bus, Rcdevice_Init_Dev_Attempts, Rcdevice_Init_Dev_Attempt_Interval, Rcdevice_Protocol_Version,
      Rcdevice_Feature, Rcdevice_Uart, Gyro_1_Bustype, Gyro_1_Spibus, Gyro_1_I2c_Bus, Gyro_1_I2c_Address,
      I2c1_Pullup, I2c1_Clockspeed_Khz, I2c2_Pullup, I2c2_Clockspeed_Khz, I2c3_Pullup, I2c3_Clockspeed_Khz,
      Mco2_On_Pc9, Spektrum_Spi_Protocol, Spektrum_Spi_Mfg_Id, Spektrum_Spi_Num_Channels, Expresslrs_Uid,
      Expresslrs_Domain, Expresslrs_Model_Id, Scheduler_Relax_Rx, Scheduler_Relax_Osd, Scheduler_Debug_Task,
      Cpu_Late_Limit_Permille, Serialmsp_Halfduplex, Msp_1_Uart, Msp_1_Baud, Msp_2_Uart, Msp_2_Baud, Msp_3_Uart,
      Msp_3_Baud, Timezone_Offset_Minutes, Rpm_Filter_Harmonics, Rpm_Filter_Weights, Rpm_Filter_Q,
      Rpm_Filter_Min_Hz, Rpm_Filter_Fade_Range_Hz, Rpm_Filter_Lpf_Hz, Flysky_Spi_Tx_Id, Flysky_Spi_Rf_Channels,
      Stats_Min_Armed_Time_S, Stats_Total_Flights, Stats_Total_Time_S, Stats_Total_Dist_M, Stats_Save_Move_Limit,
      Stats_Mah_Used, Craft_Name, Pilot_Name, Altitude_Source, Altitude_Prefer_Baro, Altitude_Lpf,
      Rangefinder_Max_Range_Cm, Altitude_D_Lpf, Ap_Landing_Altitude_M, Ap_Hover_Throttle, Ap_Throttle_Min,
      Ap_Throttle_Max, Ap_Altitude_P, Ap_Altitude_I, Ap_Altitude_D, Ap_Altitude_A, Ap_Altitude_F, Ap_Position_P,
      Ap_Position_I, Ap_Position_D, Ap_Position_A, Ap_Position_F, Ap_Position_Cutoff, Ap_Stop_Threshold,
      Ap_Max_Angle, Ap_Max_Yaw_Rate, Ap_Yaw_P, Ap_Velocity_Drag_Coeff, Ap_Max_Velocity,
      Ap_Waypoint_Arrival_Radius, Ap_Waypoint_Hold_Radius, Ap_Stick_Deadband, Ap_Throttle_Deadband, Ap_Yaw_Mode,
      Ap_Min_Forward_Velocity, Ap_Nav_Corner_Speed, Ap_Nav_Corner_Delta_V, Ap_Nav_Decel, Ap_Nav_Accel,
      Ap_Nav_Carrot_Lead_Time, Ap_Nav_Carrot_Lead_Max, Ap_Nav_Preturn_Dist, Ap_Velocity_Buildup_Max_Pitch,
      Ap_Max_Turn_Rate, Ap_Hold_Orbit_Radius, Ap_Hold_Figure8_Width, Ap_Landing_Descent_Rate,
      Ap_Landing_Detection_Time, Ap_Landing_Spiral_Enable, Ap_Landing_Spiral_Radius, Ap_Landing_Spiral_Rate,
      Ap_Landing_Velocity_Threshold, Ap_Landing_Throttle_Threshold, Ap_L1_Enable, Ap_L1_Period,
      Ap_L1_Min_Lookahead, Ap_L1_Max_Lookahead, Ap_L1_Max_Cross_Track_Error, Ap_L1_Turn_Rate,
      Ap_Min_Nav_Altitude_M, Ap_Rx_Loss_Policy, Ap_Max_Distance_From_Home, Ap_Geofence_Action, Box_User_1_Name,
      Box_User_2_Name, Box_User_3_Name, Box_User_4_Name, Gimbal_Roll_Rc_Gain, Gimbal_Pitch_Rc_Thr_Gain,
      Gimbal_Pitch_Rc_Low_Gain, Gimbal_Pitch_Rc_High_Gain, Gimbal_Yaw_Rc_Gain, Gimbal_Roll_Gain,
      Gimbal_Roll_Offset, Gimbal_Roll_Limit, Gimbal_Pitch_Gain, Gimbal_Pitch_Offset, Gimbal_Pitch_Low_Limit,
      Gimbal_Pitch_High_Limit, Gimbal_Yaw_Gain, Gimbal_Yaw_Offset, Gimbal_Yaw_Limit, Gimbal_Stabilisation,
      Gimbal_Sensitivity, Gimbal_Uart);

   --  The bounds of the 32-bit value types.
   subtype Limit is Interfaces.Integer_64 range -2 ** 32 .. 2 ** 32;

   --  Min and Max bound a direct value; Table names a lookup; Count is an
   --  array's length, a bit's position or a text's longest length, and
   --  Min_Length a text's shortest.
   type Info is record
      Kind       : Value_Type := U8;
      Where      : Value_Scope := Master;
      How        : Value_Mode := Direct;
      Min        : Limit := 0;
      Max        : Limit := 0;
      Table      : Lookup_Table := Table_Off_On;
      Count      : Natural := 0;
      Min_Length : Natural := 0;
      Write_Once : Boolean := False;
      Group      : Natural := 0;
   end record;

   function Describe (S : Setting) return Info;

   function Name (S : Setting) return String;

   function Value_Count (T : Lookup_Table) return Natural;

   --  A value's name, empty where the build has no such value.
   function Value_Name (T : Lookup_Table; Index : Natural) return String
     with Pre => Index < Value_Count (T);

end Adaflight.Settings_Table;
