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

   function Signed (V : Unsigned_8) return Integer_8 is
     (if V > 127 then Integer_8 (Integer (V) - 256) else Integer_8 (V));

   function Signed (V : Unsigned_16) return Integer_16 is
     (if V > 32_767 then Integer_16 (Integer (V) - 65_536) else Integer_16 (V));

   function Signed (V : Unsigned_32) return Integer_32 is
     (if V > 2 ** 31 - 1 then Integer_32 (Integer_64 (V) - 2 ** 32) else Integer_32 (V));

   function Signed_8 (V : Unsigned_8) return Integer_64 is
     (if V > 127 then Integer_64 (V) - 256 else Integer_64 (V));

   function Signed_16 (V : Unsigned_16) return Integer_64 is
     (if V > 32_767 then Integer_64 (V) - 65_536 else Integer_64 (V));

   function Get (C : Configuration; S : Setting; Profile : Natural := 0; Index : Natural := 0)
     return Integer_64 is
     (case S is
        when Gyro_Hardware_Lpf => Integer_64 (C.Gyro_Config.Gyro_Hardware_Lpf),
        when Gyro_Lpf1_Type => Integer_64 (C.Gyro_Config.Gyro_Lpf1_Type),
        when Gyro_Lpf1_Static_Hz => Integer_64 (C.Gyro_Config.Gyro_Lpf1_Static_Hz),
        when Gyro_Lpf2_Type => Integer_64 (C.Gyro_Config.Gyro_Lpf2_Type),
        when Gyro_Lpf2_Static_Hz => Integer_64 (C.Gyro_Config.Gyro_Lpf2_Static_Hz),
        when Gyro_Notch1_Hz => Integer_64 (C.Gyro_Config.Gyro_Soft_Notch_Hz_1),
        when Gyro_Notch1_Cutoff => Integer_64 (C.Gyro_Config.Gyro_Soft_Notch_Cutoff_1),
        when Gyro_Notch2_Hz => Integer_64 (C.Gyro_Config.Gyro_Soft_Notch_Hz_2),
        when Gyro_Notch2_Cutoff => Integer_64 (C.Gyro_Config.Gyro_Soft_Notch_Cutoff_2),
        when Gyro_Calib_Duration => Integer_64 (C.Gyro_Config.Gyro_Calibration_Duration),
        when Gyro_Calib_Noise_Limit => Integer_64 (C.Gyro_Config.Gyro_Movement_Calibration_Threshold),
        when Gyro_Offset_Yaw => Integer_64 (C.Gyro_Config.Gyro_Offset_Yaw),
        when Gyro_Overflow_Detect => Integer_64 (C.Gyro_Config.Check_Overflow),
        when Yaw_Spin_Recovery => Integer_64 (C.Gyro_Config.Yaw_Spin_Recovery),
        when Yaw_Spin_Threshold => Integer_64 (C.Gyro_Config.Yaw_Spin_Threshold) mod 65536,
        when Dyn_Notch_Count => Integer_64 (C.Dyn_Notch_Config.Dyn_Notch_Count),
        when Dyn_Notch_Q => Integer_64 (C.Dyn_Notch_Config.Dyn_Notch_Q),
        when Dyn_Notch_Min_Hz => Integer_64 (C.Dyn_Notch_Config.Dyn_Notch_Min_Hz),
        when Dyn_Notch_Max_Hz => Integer_64 (C.Dyn_Notch_Config.Dyn_Notch_Max_Hz),
        when Gyro_Lpf1_Dyn_Min_Hz => Integer_64 (C.Gyro_Config.Gyro_Lpf1_Dyn_Min_Hz),
        when Gyro_Lpf1_Dyn_Max_Hz => Integer_64 (C.Gyro_Config.Gyro_Lpf1_Dyn_Max_Hz),
        when Gyro_Lpf1_Dyn_Expo => Integer_64 (C.Gyro_Config.Gyro_Lpf1_Dyn_Expo),
        when Gyro_Filter_Debug_Axis => Integer_64 (C.Gyro_Config.Gyro_Filter_Debug_Axis),
        when Acc_Hardware => Integer_64 (C.Accelerometer_Config.Acc_Hardware),
        when Acc_Lpf_Hz => Integer_64 (C.Accelerometer_Config.Acc_Lpf_Hz),
        when Acc_Trim_Pitch => Integer_64 (C.Accelerometer_Config.Accelerometer_Trims (1)),
        when Acc_Trim_Roll => Integer_64 (C.Accelerometer_Config.Accelerometer_Trims (0)),
        when Acc_Calibration => Integer_64 (C.Accelerometer_Config.Acc_Zero (Index)),
        when Align_Mag => Integer_64 (C.Compass_Config.Mag_Alignment),
        when Mag_Align_Roll => Integer_64 (C.Compass_Config.Mag_Custom_Alignment (0)),
        when Mag_Align_Pitch => Integer_64 (C.Compass_Config.Mag_Custom_Alignment (1)),
        when Mag_Align_Yaw => Integer_64 (C.Compass_Config.Mag_Custom_Alignment (2)),
        when Mag_Bustype => Integer_64 (C.Compass_Config.Mag_Bus_Type),
        when Mag_I2c_Device => Integer_64 (C.Compass_Config.Mag_I2c_Device),
        when Mag_I2c_Address => Integer_64 (C.Compass_Config.Mag_I2c_Address),
        when Mag_Spi_Device => Integer_64 (C.Compass_Config.Mag_Spi_Device),
        when Mag_Hardware => Integer_64 (C.Compass_Config.Mag_Hardware),
        when Mag_Calibration => Integer_64 (C.Compass_Config.Mag_Zero (Index)),
        when Baro_Bustype => Integer_64 (C.Barometer_Config.Baro_Bus_Type),
        when Baro_Spi_Device => Integer_64 (C.Barometer_Config.Baro_Spi_Device),
        when Baro_I2c_Device => Integer_64 (C.Barometer_Config.Baro_I2c_Device),
        when Baro_I2c_Address => Integer_64 (C.Barometer_Config.Baro_I2c_Address),
        when Baro_Hardware => Integer_64 (C.Barometer_Config.Baro_Hardware),
        when Baro_Drift => Integer_64 (C.Barometer_Config.Baro_Temp_Drift_Cm_Per10_C),
        when Pitot_Bustype => Integer_64 (C.Pitot_Config.Pitot_Bus_Type),
        when Pitot_I2c_Device => Integer_64 (C.Pitot_Config.Pitot_I2c_Device),
        when Pitot_I2c_Address => Integer_64 (C.Pitot_Config.Pitot_I2c_Address),
        when Pitot_Hardware => Integer_64 (C.Pitot_Config.Pitot_Hardware),
        when Mid_Rc => Integer_64 (C.Rx_Config.Midrc),
        when Min_Check => Integer_64 (C.Rx_Config.Mincheck),
        when Max_Check => Integer_64 (C.Rx_Config.Maxcheck),
        when Rssi_Channel => Signed_8 (C.Rx_Config.Rssi_Channel),
        when Rssi_Src_Frame_Errors => Signed_8 (C.Rx_Config.Rssi_Src_Frame_Errors),
        when Rssi_Scale => Integer_64 (C.Rx_Config.Rssi_Scale),
        when Rssi_Offset => Integer_64 (C.Rx_Config.Rssi_Offset),
        when Rssi_Invert => Signed_8 (C.Rx_Config.Rssi_Invert),
        when Rssi_Src_Frame_Lpf_Period => Integer_64 (C.Rx_Config.Rssi_Src_Frame_Lpf_Period),
        when Rssi_Smoothing => Integer_64 (C.Rx_Config.Rssi_Smoothing),
        when Rc_Smoothing => Integer_64 (C.Rx_Config.Rc_Smoothing),
        when Rc_Smoothing_Auto_Factor => Integer_64 (C.Rx_Config.Rc_Smoothing_Auto_Factor_Rpy),
        when Rc_Smoothing_Auto_Factor_Throttle => Integer_64 (C.Rx_Config.Rc_Smoothing_Auto_Factor_Throttle),
        when Rc_Smoothing_Setpoint_Cutoff => Integer_64 (C.Rx_Config.Rc_Smoothing_Setpoint_Cutoff),
        when Rc_Smoothing_Throttle_Cutoff => Integer_64 (C.Rx_Config.Rc_Smoothing_Throttle_Cutoff),
        when Rc_Smoothing_Debug_Axis => Integer_64 (C.Rx_Config.Rc_Smoothing_Debug_Axis),
        when Fpv_Mix_Degrees => Integer_64 (C.Rx_Config.Fpv_Cam_Angle_Degrees),
        when Max_Aux_Channels => Integer_64 (C.Rx_Config.Max_Aux_Channel),
        when Serialrx_Provider => Integer_64 (C.Rx_Config.Serialrx_Provider),
        when Serialrx_Inverted => Integer_64 (C.Rx_Config.Serialrx_Inverted),
        when Spektrum_Sat_Bind => Integer_64 (C.Rx_Config.Spektrum_Sat_Bind),
        when Spektrum_Sat_Bind_Autoreset => Integer_64 (C.Rx_Config.Spektrum_Sat_Bind_Autoreset),
        when Srxl2_Unit_Id => Integer_64 (C.Rx_Config.Srxl2_Unit_Id),
        when Srxl2_Baud_Fast => Integer_64 (C.Rx_Config.Srxl2_Baud_Fast),
        when Sbus_Baud_Fast => Integer_64 (C.Rx_Config.Sbus_Baud_Fast),
        when Crsf_Use_Negotiated_Baud => Integer_64 (C.Rx_Config.Crsf_Use_Negotiated_Baud),
        when Airmode_Start_Throttle_Percent => Integer_64 (C.Rx_Config.Air_Mode_Activate_Threshold),
        when Rx_Min_Usec => Integer_64 (C.Rx_Config.Rx_Min_Usec),
        when Rx_Max_Usec => Integer_64 (C.Rx_Config.Rx_Max_Usec),
        when Serialrx_Halfduplex => Integer_64 (C.Rx_Config.Half_Duplex),
        when Rx_Uart => Integer_64 (C.Rx_Config.Rx_Uart),
        when Msp_Override_Channels_Mask => Integer_64 (C.Rx_Config.Msp_Override_Channels_Mask),
        when Msp_Override_Failsafe => Integer_64 (C.Rx_Config.Msp_Override_Failsafe),
        when Rx_Spi_Protocol => Integer_64 (C.Rx_Spi_Config.Rx_Spi_Protocol),
        when Rx_Spi_Bus => Integer_64 (C.Rx_Spi_Config.Spibus),
        when Rx_Spi_Led_Inversion => Integer_64 (C.Rx_Spi_Config.Led_Inversion),
        when Adc_Device => Integer_64 (C.Adc_Config.Device),
        when Adc_Vrefint_Calibration => Integer_64 (C.Adc_Config.Vref_Int_Calibration),
        when Adc_Tempsensor_Calibration30 => Integer_64 (C.Adc_Config.Temp_Sensor_Calibration1),
        when Adc_Tempsensor_Calibration110 => Integer_64 (C.Adc_Config.Temp_Sensor_Calibration2),
        when Input_Filtering_Mode => Signed_8 (C.Pwm_Config.Input_Filtering_Mode),
        when Blackbox_Sample_Rate => Integer_64 (C.Blackbox_Config.Sample_Rate),
        when Blackbox_Device => Integer_64 (C.Blackbox_Config.Device),
        when Blackbox_Disable_Pids => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 0) and 1),
        when Blackbox_Disable_Rc => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 1) and 1),
        when Blackbox_Disable_Setpoint => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 2) and 1),
        when Blackbox_Disable_Bat => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 3) and 1),
        when Blackbox_Disable_Mag => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 4) and 1),
        when Blackbox_Disable_Alt => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 5) and 1),
        when Blackbox_Disable_Rssi => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 6) and 1),
        when Blackbox_Disable_Gyro => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 7) and 1),
        when Blackbox_Disable_Gyrounfilt => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 14) and 1),
        when Blackbox_Disable_Acc => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 9) and 1),
        when Blackbox_Disable_Attitude => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 8) and 1),
        when Blackbox_Disable_Debug => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 10) and 1),
        when Blackbox_Disable_Motors => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 11) and 1),
        when Blackbox_Disable_Servos => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 15) and 1),
        when Blackbox_Disable_Rpm => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 13) and 1),
        when Blackbox_Disable_Gps => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 12) and 1),
        when Blackbox_Disable_Pitot => Integer_64 (Shift_Right (C.Blackbox_Config.Fields_Disabled_Mask, 16) and 1),
        when Blackbox_Mode => Integer_64 (C.Blackbox_Config.Mode),
        when Blackbox_High_Resolution => Integer_64 (C.Blackbox_Config.High_Resolution),
        when Blackbox_Uart => Integer_64 (C.Blackbox_Config.Blackbox_Uart),
        when Blackbox_Baud => Integer_64 (C.Blackbox_Config.Blackbox_Baud),
        when Max_Throttle => Integer_64 (C.Motor_Config.Maxthrottle),
        when Min_Command => Integer_64 (C.Motor_Config.Mincommand),
        when Motor_Kv => Integer_64 (C.Motor_Config.Kv),
        when Motor_Idle => Integer_64 (C.Motor_Config.Motor_Idle),
        when Dshot_Burst => Integer_64 (C.Motor_Config.Dev.Use_Burst_Dshot),
        when Dshot_Bidir => Integer_64 (C.Motor_Config.Dev.Use_Dshot_Telemetry),
        when Dshot_Edt => Integer_64 (C.Motor_Config.Dev.Use_Dshot_Edt),
        when Dshot_Bitbang => Integer_64 (C.Motor_Config.Dev.Use_Dshot_Bitbang),
        when Dshot_Bitbang_Timer => Integer_64 (C.Motor_Config.Dev.Use_Dshot_Bitbanged_Timer),
        when Use_Unsynced_Pwm => Integer_64 (C.Motor_Config.Dev.Use_Continuous_Update),
        when Motor_Pwm_Protocol => Integer_64 (C.Motor_Config.Dev.Motor_Protocol),
        when Motor_Pwm_Rate => Integer_64 (C.Motor_Config.Dev.Motor_Pwm_Rate),
        when Motor_Pwm_Inversion => Integer_64 (C.Motor_Config.Dev.Motor_Inversion),
        when Motor_Poles => Integer_64 (C.Motor_Config.Motor_Pole_Count),
        when Motor_Output_Reordering => Integer_64 (C.Motor_Config.Dev.Motor_Output_Reordering (Index)),
        when Thr_Corr_Value => Integer_64 (C.Throttle_Correction_Config.Throttle_Correction_Value),
        when Thr_Corr_Angle => Integer_64 (C.Throttle_Correction_Config.Throttle_Correction_Angle),
        when Failsafe_Delay => Integer_64 (C.Failsafe_Config.Failsafe_Delay),
        when Failsafe_Landing_Time => Integer_64 (C.Failsafe_Config.Failsafe_Landing_Time),
        when Failsafe_Throttle => Integer_64 (C.Failsafe_Config.Failsafe_Throttle),
        when Failsafe_Switch_Mode => Integer_64 (C.Failsafe_Config.Failsafe_Switch_Mode),
        when Failsafe_Throttle_Low_Delay => Integer_64 (C.Failsafe_Config.Failsafe_Throttle_Low_Delay),
        when Failsafe_Procedure => Integer_64 (C.Failsafe_Config.Failsafe_Procedure),
        when Failsafe_Recovery_Delay => Integer_64 (C.Failsafe_Config.Failsafe_Recovery_Delay),
        when Failsafe_Stick_Threshold => Integer_64 (C.Failsafe_Config.Failsafe_Stick_Threshold),
        when Align_Board_Roll => Signed_16 (Unsigned_16 (Unsigned_32'Mod (Integer_64 (C.Board_Alignment.Roll_Degrees))
           and 16#FFFF#)),
        when Align_Board_Pitch => Signed_16 (Unsigned_16 (Unsigned_32'Mod (Integer_64
           (C.Board_Alignment.Pitch_Degrees)) and 16#FFFF#)),
        when Align_Board_Yaw => Signed_16 (Unsigned_16 (Unsigned_32'Mod (Integer_64 (C.Board_Alignment.Yaw_Degrees))
           and 16#FFFF#)),
        when Gimbal_Mode => Integer_64 (C.Gimbal_Config.Mode),
        when Bat_Capacity => Integer_64 (C.Battery_Profiles (Profile).Battery_Capacity),
        when Vbat_Max_Cell_Voltage => Integer_64 (C.Battery_Profiles (Profile).Vbatmaxcellvoltage),
        when Vbat_Full_Cell_Voltage => Integer_64 (C.Battery_Profiles (Profile).Vbatfullcellvoltage),
        when Vbat_Min_Cell_Voltage => Integer_64 (C.Battery_Profiles (Profile).Vbatmincellvoltage),
        when Vbat_Warning_Cell_Voltage => Integer_64 (C.Battery_Profiles (Profile).Vbatwarningcellvoltage),
        when Cbat_Alert_Percent => Integer_64 (C.Battery_Profiles (Profile).Consumption_Warning_Percentage),
        when Force_Battery_Cell_Count => Integer_64 (C.Battery_Profiles (Profile).Force_Battery_Cell_Count),
        when Vbat_Hysteresis => Integer_64 (C.Battery_Config.Vbathysteresis),
        when Current_Meter => Integer_64 (C.Battery_Config.Current_Meter_Source),
        when Battery_Meter => Integer_64 (C.Battery_Config.Voltage_Meter_Source),
        when Vbat_Detect_Cell_Voltage => Integer_64 (C.Battery_Config.Vbatnotpresentcellvoltage),
        when Use_Vbat_Alerts => Boolean'Pos (C.Battery_Config.Use_V_Bat_Alerts),
        when Use_Cbat_Alerts => Boolean'Pos (C.Battery_Config.Use_Consumption_Alerts),
        when Vbat_Cutoff_Percent => Integer_64 (C.Battery_Config.Lvc_Percentage),
        when Vbat_Display_Lpf_Period => Integer_64 (C.Battery_Config.Vbat_Display_Lpf_Period),
        when Vbat_Sag_Lpf_Period => Integer_64 (C.Battery_Config.Vbat_Sag_Lpf_Period),
        when Ibat_Lpf_Period => Integer_64 (C.Battery_Config.Ibat_Lpf_Period),
        when Vbat_Duration_For_Warning => Integer_64 (C.Battery_Config.Vbat_Duration_For_Warning),
        when Vbat_Duration_For_Critical => Integer_64 (C.Battery_Config.Vbat_Duration_For_Critical),
        when Vbat_Scale => Integer_64 (C.Voltage_Sensor_Adc_Config (0).Vbatscale),
        when Vbat_Divider => Integer_64 (C.Voltage_Sensor_Adc_Config (0).Vbatresdivval),
        when Vbat_Multiplier => Integer_64 (C.Voltage_Sensor_Adc_Config (0).Vbatresdivmultiplier),
        when Ibata_Scale => Integer_64 (C.Current_Sensor_Adc_Config.Scale),
        when Ibata_Offset => Integer_64 (C.Current_Sensor_Adc_Config.Offset),
        when Ibatv_Scale => Integer_64 (C.Current_Sensor_Virtual_Config.Scale),
        when Ibatv_Offset => Integer_64 (C.Current_Sensor_Virtual_Config.Offset),
        when Battery_Continue => Boolean'Pos (C.Battery_Config.Is_Battery_Continue_Enabled),
        when Beeper_Inversion => Integer_64 (C.Beeper_Dev_Config.Is_Inverted),
        when Beeper_Od => Integer_64 (C.Beeper_Dev_Config.Is_Open_Drain),
        when Beeper_Frequency => Signed_16 (C.Beeper_Dev_Config.Frequency),
        when Beeper_Dshot_Beacon_Tone => Integer_64 (C.Beeper_Config.Dshot_Beacon_Tone),
        when Yaw_Motors_Reversed => Boolean'Pos (C.Mixer_Config.Yaw_Motors_Reversed),
        when Mixer_Type => Integer_64 (C.Mixer_Config.Mixer_Type),
        when Crashflip_Motor_Percent => Integer_64 (C.Mixer_Config.Crashflip_Motor_Percent),
        when Crashflip_Rate => Integer_64 (C.Mixer_Config.Crashflip_Rate),
        when Crashflip_Auto_Rearm => Boolean'Pos (C.Mixer_Config.Crashflip_Auto_Rearm),
        when Rpm_Limit => Boolean'Pos (C.Mixer_Config.Rpm_Limit),
        when Rpm_Limit_P => Integer_64 (C.Mixer_Config.Rpm_Limit_P),
        when Rpm_Limit_I => Integer_64 (C.Mixer_Config.Rpm_Limit_I),
        when Rpm_Limit_D => Integer_64 (C.Mixer_Config.Rpm_Limit_D),
        when Rpm_Limit_Value => Integer_64 (C.Mixer_Config.Rpm_Limit_Value),
        when Three_D_Deadband_Low => Integer_64 (C.Flight3_D_Config.Deadband3d_Low),
        when Three_D_Deadband_High => Integer_64 (C.Flight3_D_Config.Deadband3d_High),
        when Three_D_Neutral => Integer_64 (C.Flight3_D_Config.Neutral3d),
        when Three_D_Deadband_Throttle => Integer_64 (C.Flight3_D_Config.Deadband3d_Throttle),
        when Three_D_Limit_Low => Integer_64 (C.Flight3_D_Config.Limit3d_Low),
        when Three_D_Limit_High => Integer_64 (C.Flight3_D_Config.Limit3d_High),
        when Three_D_Switched_Mode => Integer_64 (C.Flight3_D_Config.Switched_Mode3d),
        when Servo_Center_Pulse => Integer_64 (C.Servo_Config.Dev.Servo_Center_Pulse),
        when Servo_Pwm_Rate => Integer_64 (C.Servo_Config.Dev.Servo_Pwm_Rate),
        when Servo_Lowpass_Hz => Integer_64 (C.Servo_Config.Servo_Lowpass_Freq),
        when Tri_Unarmed_Servo => Signed_8 (C.Servo_Config.Tri_Unarmed_Servo),
        when Channel_Forwarding_Start => Integer_64 (C.Servo_Config.Channel_Forwarding_Start_Channel),
        when Thr_Mid => Integer_64 (C.Control_Rate_Profiles (Profile).Thr_Mid8),
        when Thr_Expo => Integer_64 (C.Control_Rate_Profiles (Profile).Thr_Expo8),
        when Thr_Hover => Integer_64 (C.Control_Rate_Profiles (Profile).Thr_Hover8),
        when Rates_Type => Integer_64 (C.Control_Rate_Profiles (Profile).Rates_Type),
        when Quickrates_Rc_Expo => Integer_64 (C.Control_Rate_Profiles (Profile).Quick_Rates_Rc_Expo),
        when Roll_Rc_Rate => Integer_64 (C.Control_Rate_Profiles (Profile).Rc_Rates (0)),
        when Pitch_Rc_Rate => Integer_64 (C.Control_Rate_Profiles (Profile).Rc_Rates (1)),
        when Yaw_Rc_Rate => Integer_64 (C.Control_Rate_Profiles (Profile).Rc_Rates (2)),
        when Roll_Expo => Integer_64 (C.Control_Rate_Profiles (Profile).Rc_Expo (0)),
        when Pitch_Expo => Integer_64 (C.Control_Rate_Profiles (Profile).Rc_Expo (1)),
        when Yaw_Expo => Integer_64 (C.Control_Rate_Profiles (Profile).Rc_Expo (2)),
        when Roll_Srate => Integer_64 (C.Control_Rate_Profiles (Profile).Rates (0)),
        when Pitch_Srate => Integer_64 (C.Control_Rate_Profiles (Profile).Rates (1)),
        when Yaw_Srate => Integer_64 (C.Control_Rate_Profiles (Profile).Rates (2)),
        when Throttle_Limit_Type => Integer_64 (C.Control_Rate_Profiles (Profile).Throttle_Limit_Type),
        when Throttle_Limit_Percent => Integer_64 (C.Control_Rate_Profiles (Profile).Throttle_Limit_Percent),
        when Roll_Rate_Limit => Integer_64 (C.Control_Rate_Profiles (Profile).Rate_Limit (0)),
        when Pitch_Rate_Limit => Integer_64 (C.Control_Rate_Profiles (Profile).Rate_Limit (1)),
        when Yaw_Rate_Limit => Integer_64 (C.Control_Rate_Profiles (Profile).Rate_Limit (2)),
        when Reboot_Character => Integer_64 (C.Serial_Config.Reboot_Character),
        when Serial_Update_Rate_Hz => Integer_64 (C.Serial_Config.Serial_Update_Rate_Hz),
        when Imu_Dcm_Kp => Integer_64 (C.Imu_Config.Imu_Dcm_Kp),
        when Imu_Dcm_Ki => Integer_64 (C.Imu_Config.Imu_Dcm_Ki),
        when Small_Angle => Integer_64 (C.Imu_Config.Small_Angle),
        when Imu_Process_Denom => Integer_64 (C.Imu_Config.Imu_Process_Denom),
        when Mag_Declination => Integer_64 (C.Imu_Config.Mag_Declination),
        when Auto_Disarm_Delay => Integer_64 (C.Arming_Config.Auto_Disarm_Delay),
        when Gyro_Cal_On_First_Arm => Integer_64 (C.Arming_Config.Gyro_Cal_On_First_Arm),
        when Prearm_Allow_Rearm => Integer_64 (C.Arming_Config.Prearm_Allow_Rearm),
        when Gps_Provider => Integer_64 (C.Gps_Config.Provider),
        when Gps_Sbas_Mode => Integer_64 (C.Gps_Config.Sbas_Mode),
        when Gps_Auto_Config => Integer_64 (C.Gps_Config.Auto_Config),
        when Gps_Auto_Baud => Integer_64 (C.Gps_Config.Auto_Baud),
        when Gps_Ublox_Acquire_Model => Integer_64 (C.Gps_Config.Gps_Ublox_Acquire_Model),
        when Gps_Ublox_Flight_Model => Integer_64 (C.Gps_Config.Gps_Ublox_Flight_Model),
        when Gps_Update_Rate_Hz => Integer_64 (C.Gps_Config.Gps_Update_Rate_Hz),
        when Gps_Ublox_Utc_Standard => Integer_64 (C.Gps_Config.Gps_Ublox_Utc_Standard),
        when Gps_Ublox_Use_Galileo => Boolean'Pos (C.Gps_Config.Gps_Ublox_Use_Galileo),
        when Gps_Ublox_Enable_Ana => Boolean'Pos (C.Gps_Config.Gps_Ublox_Enable_Ana),
        when Gps_Set_Home_Point_Once => Boolean'Pos (C.Gps_Config.Gps_Set_Home_Point_Once),
        when Gps_Use_3d_Speed => Boolean'Pos (C.Gps_Config.Gps_Use_3d_Speed),
        when Gps_Sbas_Integrity => Boolean'Pos (C.Gps_Config.Sbas_Integrity),
        when Gps_Uart => Integer_64 (C.Gps_Config.Gps_Uart),
        when Gps_Baud => Integer_64 (C.Gps_Config.Gps_Baud),
        when Gps_Rescue_Min_Start_Dist => Integer_64 (C.Gps_Rescue_Config.Min_Start_Dist_M),
        when Gps_Rescue_Alt_Mode => Integer_64 (C.Gps_Rescue_Config.Altitude_Mode),
        when Gps_Rescue_Initial_Climb => Integer_64 (C.Gps_Rescue_Config.Initial_Climb_M),
        when Gps_Rescue_Ascend_Rate => Integer_64 (C.Gps_Rescue_Config.Ascend_Rate),
        when Gps_Rescue_Return_Alt => Integer_64 (C.Gps_Rescue_Config.Return_Altitude_M),
        when Gps_Rescue_Ground_Speed => Integer_64 (C.Gps_Rescue_Config.Ground_Speed_Cm_S),
        when Gps_Rescue_Descent_Dist => Integer_64 (C.Gps_Rescue_Config.Descent_Distance_M),
        when Gps_Rescue_Descend_Rate => Integer_64 (C.Gps_Rescue_Config.Descend_Rate),
        when Gps_Rescue_Sanity_Checks => Integer_64 (C.Gps_Rescue_Config.Sanity_Checks),
        when Gps_Rescue_Min_Sats => Integer_64 (C.Gps_Rescue_Config.Min_Sats),
        when Gps_Rescue_Allow_Arming_Without_Fix => Integer_64 (C.Gps_Rescue_Config.Allow_Arming_Without_Fix),
        when Gps_Rescue_Yaw_P => Integer_64 (C.Gps_Rescue_Config.Yaw_P),
        when Gps_Lap_Timer_Gate_Lat => Integer_64 (C.Gps_Lap_Timer_Config.Gate_Lat),
        when Gps_Lap_Timer_Gate_Lon => Integer_64 (C.Gps_Lap_Timer_Config.Gate_Lon),
        when Gps_Lap_Timer_Min_Lap_Time_S => Integer_64 (C.Gps_Lap_Timer_Config.Minimum_Lap_Time_Seconds),
        when Gps_Lap_Timer_Gate_Tolerance_M => Integer_64 (C.Gps_Lap_Timer_Config.Gate_Tolerance_M),
        when Deadband => Integer_64 (C.Rc_Controls_Config.Deadband),
        when Yaw_Deadband => Integer_64 (C.Rc_Controls_Config.Yaw_Deadband),
        when Yaw_Control_Reversed => Boolean'Pos (C.Rc_Controls_Config.Yaw_Control_Reversed),
        when Alt_Hold_Climb_Rate => Integer_64 (C.Alt_Hold_Config.Climb_Rate),
        when Alt_Hold_Deadband => Integer_64 (C.Alt_Hold_Config.Deadband),
        when Pos_Hold_Deadband => Integer_64 (C.Pos_Hold_Config.Deadband),
        when Poshold_Position_Source => Integer_64 (C.Pos_Hold_Config.Position_Source),
        when Poshold_Opticalflow_Quality_Min => Integer_64 (C.Pos_Hold_Config.Opticalflow_Quality_Min),
        when Poshold_Opticalflow_Max_Range => Integer_64 (C.Pos_Hold_Config.Opticalflow_Max_Range),
        when Pid_Process_Denom => Integer_64 (C.Pid_Config.Pid_Process_Denom),
        when Runaway_Takeoff_Prevention => Integer_64 (C.Pid_Config.Runaway_Takeoff_Prevention),
        when Runaway_Takeoff_Deactivate_Delay => Integer_64 (C.Pid_Config.Runaway_Takeoff_Deactivate_Delay),
        when Runaway_Takeoff_Deactivate_Throttle_Percent => Integer_64
           (C.Pid_Config.Runaway_Takeoff_Deactivate_Throttle),
        when Dterm_Lpf1_Dyn_Min_Hz => Integer_64 (C.Pid_Profiles (Profile).Dterm_Lpf1_Dyn_Min_Hz),
        when Dterm_Lpf1_Dyn_Max_Hz => Integer_64 (C.Pid_Profiles (Profile).Dterm_Lpf1_Dyn_Max_Hz),
        when Dterm_Lpf1_Dyn_Expo => Integer_64 (C.Pid_Profiles (Profile).Dterm_Lpf1_Dyn_Expo),
        when Dterm_Lpf1_Type => Integer_64 (C.Pid_Profiles (Profile).Dterm_Lpf1_Type),
        when Dterm_Lpf1_Static_Hz => Signed_16 (C.Pid_Profiles (Profile).Dterm_Lpf1_Static_Hz),
        when Dterm_Lpf2_Type => Integer_64 (C.Pid_Profiles (Profile).Dterm_Lpf2_Type),
        when Dterm_Lpf2_Static_Hz => Signed_16 (C.Pid_Profiles (Profile).Dterm_Lpf2_Static_Hz),
        when Dterm_Notch_Hz => Integer_64 (C.Pid_Profiles (Profile).Dterm_Notch_Hz),
        when Dterm_Notch_Cutoff => Integer_64 (C.Pid_Profiles (Profile).Dterm_Notch_Cutoff),
        when Vbat_Sag_Compensation => Integer_64 (C.Pid_Profiles (Profile).Vbat_Sag_Compensation),
        when Pid_At_Min_Throttle => Integer_64 (C.Pid_Profiles (Profile).Pid_At_Min_Throttle),
        when Anti_Gravity_Gain => Integer_64 (C.Pid_Profiles (Profile).Anti_Gravity_Gain),
        when Anti_Gravity_Cutoff_Hz => Integer_64 (C.Pid_Profiles (Profile).Anti_Gravity_Cutoff_Hz),
        when Anti_Gravity_P_Gain => Integer_64 (C.Pid_Profiles (Profile).Anti_Gravity_P_Gain),
        when Acc_Limit_Yaw => Integer_64 (C.Pid_Profiles (Profile).Yaw_Rate_Accel_Limit),
        when Acc_Limit => Integer_64 (C.Pid_Profiles (Profile).Rate_Accel_Limit),
        when Crash_Dthreshold => Integer_64 (C.Pid_Profiles (Profile).Crash_Dthreshold),
        when Crash_Gthreshold => Integer_64 (C.Pid_Profiles (Profile).Crash_Gthreshold),
        when Crash_Setpoint_Threshold => Integer_64 (C.Pid_Profiles (Profile).Crash_Setpoint_Threshold),
        when Crash_Time => Integer_64 (C.Pid_Profiles (Profile).Crash_Time),
        when Crash_Delay => Integer_64 (C.Pid_Profiles (Profile).Crash_Delay),
        when Crash_Recovery_Angle => Integer_64 (C.Pid_Profiles (Profile).Crash_Recovery_Angle),
        when Crash_Recovery_Rate => Integer_64 (C.Pid_Profiles (Profile).Crash_Recovery_Rate),
        when Crash_Limit_Yaw => Integer_64 (C.Pid_Profiles (Profile).Crash_Limit_Yaw),
        when Crash_Recovery => Integer_64 (C.Pid_Profiles (Profile).Crash_Recovery),
        when Iterm_Rotation => Integer_64 (C.Pid_Profiles (Profile).Iterm_Rotation),
        when Iterm_Relax => Integer_64 (C.Pid_Profiles (Profile).Iterm_Relax),
        when Iterm_Relax_Type => Integer_64 (C.Pid_Profiles (Profile).Iterm_Relax_Type),
        when Iterm_Relax_Cutoff => Integer_64 (C.Pid_Profiles (Profile).Iterm_Relax_Cutoff),
        when Iterm_Windup => Integer_64 (C.Pid_Profiles (Profile).Iterm_Windup),
        when Pidsum_Limit => Integer_64 (C.Pid_Profiles (Profile).Pid_Sum_Limit),
        when Pidsum_Limit_Yaw => Integer_64 (C.Pid_Profiles (Profile).Pid_Sum_Limit_Yaw),
        when Yaw_Lowpass_Hz => Integer_64 (C.Pid_Profiles (Profile).Yaw_Lowpass_Hz),
        when Throttle_Boost => Integer_64 (C.Pid_Profiles (Profile).Throttle_Boost),
        when Throttle_Boost_Cutoff => Integer_64 (C.Pid_Profiles (Profile).Throttle_Boost_Cutoff),
        when Acro_Trainer_Angle_Limit => Integer_64 (C.Pid_Profiles (Profile).Acro_Trainer_Angle_Limit),
        when Acro_Trainer_Lookahead_Ms => Integer_64 (C.Pid_Profiles (Profile).Acro_Trainer_Lookahead_Ms),
        when Acro_Trainer_Debug_Axis => Integer_64 (C.Pid_Profiles (Profile).Acro_Trainer_Debug_Axis),
        when Acro_Trainer_Gain => Integer_64 (C.Pid_Profiles (Profile).Acro_Trainer_Gain),
        when P_Pitch => Integer_64 (C.Pid_Profiles (Profile).Pid (1).P),
        when I_Pitch => Integer_64 (C.Pid_Profiles (Profile).Pid (1).I),
        when D_Pitch => Integer_64 (C.Pid_Profiles (Profile).Pid (1).D),
        when F_Pitch => Integer_64 (C.Pid_Profiles (Profile).Pid (1).F),
        when P_Roll => Integer_64 (C.Pid_Profiles (Profile).Pid (0).P),
        when I_Roll => Integer_64 (C.Pid_Profiles (Profile).Pid (0).I),
        when D_Roll => Integer_64 (C.Pid_Profiles (Profile).Pid (0).D),
        when F_Roll => Integer_64 (C.Pid_Profiles (Profile).Pid (0).F),
        when P_Yaw => Integer_64 (C.Pid_Profiles (Profile).Pid (2).P),
        when I_Yaw => Integer_64 (C.Pid_Profiles (Profile).Pid (2).I),
        when D_Yaw => Integer_64 (C.Pid_Profiles (Profile).Pid (2).D),
        when F_Yaw => Integer_64 (C.Pid_Profiles (Profile).Pid (2).F),
        when Angle_P_Gain => Integer_64 (C.Pid_Profiles (Profile).Pid (3).P),
        when Angle_Feedforward => Integer_64 (Unsigned_8 (Unsigned_32 (C.Pid_Profiles (Profile).Pid (3).F) and 16#FF#)),
        when Angle_Feedforward_Smoothing_Ms => Integer_64 (C.Pid_Profiles (Profile).Angle_Feedforward_Smoothing_Ms),
        when Angle_Limit => Integer_64 (C.Pid_Profiles (Profile).Angle_Limit),
        when Angle_Earth_Ref => Integer_64 (C.Pid_Profiles (Profile).Angle_Earth_Ref),
        when Horizon_Level_Strength => Integer_64 (C.Pid_Profiles (Profile).Pid (3).I),
        when Horizon_Limit_Sticks => Integer_64 (C.Pid_Profiles (Profile).Pid (3).D),
        when Horizon_Limit_Degrees => Integer_64 (C.Pid_Profiles (Profile).Horizon_Limit_Degrees),
        when Horizon_Ignore_Sticks => Integer_64 (C.Pid_Profiles (Profile).Horizon_Ignore_Sticks),
        when Horizon_Delay_Ms => Integer_64 (C.Pid_Profiles (Profile).Horizon_Delay_Ms),
        when Chirp_Lag_Freq_Hz => Integer_64 (C.Pid_Profiles (Profile).Chirp_Lag_Freq_Hz),
        when Chirp_Lead_Freq_Hz => Integer_64 (C.Pid_Profiles (Profile).Chirp_Lead_Freq_Hz),
        when Chirp_Amplitude_Roll => Integer_64 (C.Pid_Profiles (Profile).Chirp_Amplitude_Roll),
        when Chirp_Amplitude_Pitch => Integer_64 (C.Pid_Profiles (Profile).Chirp_Amplitude_Pitch),
        when Chirp_Amplitude_Yaw => Integer_64 (C.Pid_Profiles (Profile).Chirp_Amplitude_Yaw),
        when Chirp_Frequency_Start_Deci_Hz => Integer_64 (C.Pid_Profiles (Profile).Chirp_Frequency_Start_Deci_Hz),
        when Chirp_Frequency_End_Deci_Hz => Integer_64 (C.Pid_Profiles (Profile).Chirp_Frequency_End_Deci_Hz),
        when Chirp_Time_Seconds => Integer_64 (C.Pid_Profiles (Profile).Chirp_Time_Seconds),
        when Chirp_Repeat => Integer_64 (C.Pid_Profiles (Profile).Chirp_Repeat),
        when D_Max_Roll => Integer_64 (C.Pid_Profiles (Profile).D_Max (0)),
        when D_Max_Pitch => Integer_64 (C.Pid_Profiles (Profile).D_Max (1)),
        when D_Max_Yaw => Integer_64 (C.Pid_Profiles (Profile).D_Max (2)),
        when D_Max_Gain => Integer_64 (C.Pid_Profiles (Profile).D_Max_Gain),
        when D_Max_Advance => Integer_64 (C.Pid_Profiles (Profile).D_Max_Advance),
        when Motor_Output_Limit => Integer_64 (C.Pid_Profiles (Profile).Motor_Output_Limit),
        when Auto_Profile_Cell_Count => Integer_64 (C.Pid_Profiles (Profile).Auto_Profile_Cell_Count),
        when Launch_Control_Mode => Integer_64 (C.Pid_Profiles (Profile).Launch_Control_Mode),
        when Launch_Trigger_Allow_Reset => Integer_64 (C.Pid_Profiles (Profile).Launch_Control_Allow_Trigger_Reset),
        when Launch_Trigger_Throttle_Percent => Integer_64 (C.Pid_Profiles (Profile).Launch_Control_Throttle_Percent),
        when Launch_Angle_Limit => Integer_64 (C.Pid_Profiles (Profile).Launch_Control_Angle_Limit),
        when Launch_Control_Gain => Integer_64 (C.Pid_Profiles (Profile).Launch_Control_Gain),
        when Thrust_Linear => Integer_64 (C.Pid_Profiles (Profile).Thrust_Linearization),
        when Feedforward_Transition => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Transition),
        when Feedforward_Averaging => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Averaging),
        when Feedforward_Smooth_Factor => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Smooth_Factor),
        when Feedforward_Jitter_Factor => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Jitter_Factor),
        when Feedforward_Boost => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Boost),
        when Feedforward_Max_Rate_Limit => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Max_Rate_Limit),
        when Feedforward_Yaw_Hold_Gain => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Yaw_Hold_Gain),
        when Feedforward_Yaw_Hold_Time => Integer_64 (C.Pid_Profiles (Profile).Feedforward_Yaw_Hold_Time),
        when Dyn_Idle_Min_Rpm => Integer_64 (C.Pid_Profiles (Profile).Dyn_Idle_Min_Rpm),
        when Dyn_Idle_P_Gain => Integer_64 (C.Pid_Profiles (Profile).Dyn_Idle_P_Gain),
        when Dyn_Idle_I_Gain => Integer_64 (C.Pid_Profiles (Profile).Dyn_Idle_I_Gain),
        when Dyn_Idle_D_Gain => Integer_64 (C.Pid_Profiles (Profile).Dyn_Idle_D_Gain),
        when Dyn_Idle_Max_Increase => Integer_64 (C.Pid_Profiles (Profile).Dyn_Idle_Max_Increase),
        when Level_Race_Mode => Integer_64 (C.Pid_Profiles (Profile).Level_Race_Mode),
        when Simplified_Pids_Mode => Integer_64 (C.Pid_Profiles (Profile).Simplified_Pids_Mode),
        when Simplified_Master_Multiplier => Integer_64 (C.Pid_Profiles (Profile).Simplified_Master_Multiplier),
        when Simplified_I_Gain => Integer_64 (C.Pid_Profiles (Profile).Simplified_I_Gain),
        when Simplified_D_Gain => Integer_64 (C.Pid_Profiles (Profile).Simplified_D_Gain),
        when Simplified_Pi_Gain => Integer_64 (C.Pid_Profiles (Profile).Simplified_Pi_Gain),
        when Simplified_D_Max_Gain => Integer_64 (C.Pid_Profiles (Profile).Simplified_D_Max_Gain),
        when Simplified_Feedforward_Gain => Integer_64 (C.Pid_Profiles (Profile).Simplified_Feedforward_Gain),
        when Simplified_Pitch_D_Gain => Integer_64 (C.Pid_Profiles (Profile).Simplified_Roll_Pitch_Ratio),
        when Simplified_Pitch_Pi_Gain => Integer_64 (C.Pid_Profiles (Profile).Simplified_Pitch_Pi_Gain),
        when Simplified_Dterm_Filter => Integer_64 (C.Pid_Profiles (Profile).Simplified_Dterm_Filter),
        when Simplified_Dterm_Filter_Multiplier => Integer_64 (C.Pid_Profiles
           (Profile).Simplified_Dterm_Filter_Multiplier),
        when Simplified_Gyro_Filter => Integer_64 (C.Gyro_Config.Simplified_Gyro_Filter),
        when Simplified_Gyro_Filter_Multiplier => Integer_64 (C.Gyro_Config.Simplified_Gyro_Filter_Multiplier),
        when Tpa_Mode => Integer_64 (C.Pid_Profiles (Profile).Tpa_Mode),
        when Tpa_Rate => Integer_64 (C.Pid_Profiles (Profile).Tpa_Rate),
        when Tpa_Breakpoint => Integer_64 (C.Pid_Profiles (Profile).Tpa_Breakpoint),
        when Tpa_Low_Rate => Integer_64 (C.Pid_Profiles (Profile).Tpa_Low_Rate),
        when Tpa_Low_Breakpoint => Integer_64 (C.Pid_Profiles (Profile).Tpa_Low_Breakpoint),
        when Tpa_Low_Always => Integer_64 (C.Pid_Profiles (Profile).Tpa_Low_Always),
        when Ez_Landing_Threshold => Integer_64 (C.Pid_Profiles (Profile).Ez_Landing_Threshold),
        when Ez_Landing_Limit => Integer_64 (C.Pid_Profiles (Profile).Ez_Landing_Limit),
        when Ez_Landing_Speed => Integer_64 (C.Pid_Profiles (Profile).Ez_Landing_Speed),
        when Landing_Disarm_Threshold => Integer_64 (C.Pid_Profiles (Profile).Landing_Disarm_Threshold),
        when Tlm_Inverted => Integer_64 (C.Telemetry_Config.Telemetry_Inverted),
        when Tlm_Halfduplex => Integer_64 (C.Telemetry_Config.Half_Duplex),
        when Telemetry_1_Protocol => Integer_64 (C.Telemetry_Config.Providers (0).Protocol),
        when Telemetry_1_Uart => Integer_64 (C.Telemetry_Config.Providers (0).Uart),
        when Telemetry_1_Baud => Integer_64 (C.Telemetry_Config.Providers (0).Baud),
        when Telemetry_2_Protocol => Integer_64 (C.Telemetry_Config.Providers (1).Protocol),
        when Telemetry_2_Uart => Integer_64 (C.Telemetry_Config.Providers (1).Uart),
        when Telemetry_2_Baud => Integer_64 (C.Telemetry_Config.Providers (1).Baud),
        when Telemetry_3_Protocol => Integer_64 (C.Telemetry_Config.Providers (2).Protocol),
        when Telemetry_3_Uart => Integer_64 (C.Telemetry_Config.Providers (2).Uart),
        when Telemetry_3_Baud => Integer_64 (C.Telemetry_Config.Providers (2).Baud),
        when Crsf_Tlm_Accgyro => Integer_64 (C.Telemetry_Config.Crsf_Tlm_Accgyro),
        when Frsky_Default_Lat => Integer_64 (C.Telemetry_Config.Gps_No_Fix_Latitude),
        when Frsky_Default_Long => Integer_64 (C.Telemetry_Config.Gps_No_Fix_Longitude),
        when Frsky_Gps_Format => Integer_64 (C.Telemetry_Config.Frsky_Coordinate_Format),
        when Frsky_Unit => Integer_64 (C.Telemetry_Config.Frsky_Unit),
        when Frsky_Vfas_Precision => Integer_64 (C.Telemetry_Config.Frsky_Vfas_Precision),
        when Hott_Alarm_Int => Integer_64 (C.Telemetry_Config.Hott_Alarm_Sound_Interval),
        when Pid_In_Tlm => Integer_64 (C.Telemetry_Config.Pid_Values_As_Telemetry),
        when Report_Cell_Voltage => Integer_64 (C.Telemetry_Config.Report_Cell_Voltage),
        when Ibus_Sensor => Integer_64 (C.Telemetry_Config.Flysky_Sensors (Index)),
        when Mavlink_Mah_As_Heading_Divisor => Integer_64 (C.Telemetry_Config.Mavlink_Mah_As_Heading_Divisor),
        when Mavlink_Min_Txbuff => Integer_64 (C.Telemetry_Config.Mavlink_Min_Txbuff),
        when Mavlink_Ext_Status_Rate => Integer_64 (C.Telemetry_Config.Mavlink_Extended_Status_Rate),
        when Mavlink_Rc_Chan_Rate => Integer_64 (C.Telemetry_Config.Mavlink_Rc_Channels_Rate),
        when Mavlink_Pos_Rate => Integer_64 (C.Telemetry_Config.Mavlink_Position_Rate),
        when Mavlink_Extra1_Rate => Integer_64 (C.Telemetry_Config.Mavlink_Extra1_Rate),
        when Mavlink_Extra2_Rate => Integer_64 (C.Telemetry_Config.Mavlink_Extra2_Rate),
        when Mavlink_Extra3_Rate => Integer_64 (C.Telemetry_Config.Mavlink_Extra3_Rate),
        when Telemetry_Disabled_Voltage => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 0) and 1),
        when Telemetry_Disabled_Current => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 1) and 1),
        when Telemetry_Disabled_Fuel => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 2) and 1),
        when Telemetry_Disabled_Mode => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 3) and 1),
        when Telemetry_Disabled_Acc_X => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 4) and 1),
        when Telemetry_Disabled_Acc_Y => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 5) and 1),
        when Telemetry_Disabled_Acc_Z => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 6) and 1),
        when Telemetry_Disabled_Pitch => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 7) and 1),
        when Telemetry_Disabled_Roll => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 8) and 1),
        when Telemetry_Disabled_Heading => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 9) and 1),
        when Telemetry_Disabled_Altitude => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 10) and 1),
        when Telemetry_Disabled_Vario => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 11) and 1),
        when Telemetry_Disabled_Lat_Long => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 12) and 1),
        when Telemetry_Disabled_Ground_Speed => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 13) and
           1),
        when Telemetry_Disabled_Distance => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 14) and 1),
        when Telemetry_Disabled_Esc_Current => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 15) and 1),
        when Telemetry_Disabled_Esc_Voltage => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 16) and 1),
        when Telemetry_Disabled_Esc_Rpm => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 17) and 1),
        when Telemetry_Disabled_Esc_Temperature => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 18)
           and 1),
        when Telemetry_Disabled_Temperature => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 19) and 1),
        when Telemetry_Disabled_Cap_Used => Integer_64 (Shift_Right (C.Telemetry_Config.Disabled_Sensors, 20) and 1),
        when Ledstrip_Visual_Beeper => Integer_64 (C.Led_Strip_Config.Ledstrip_Visual_Beeper),
        when Ledstrip_Visual_Beeper_Color => Integer_64 (C.Led_Strip_Config.Ledstrip_Visual_Beeper_Color),
        when Ledstrip_Grb_Rgb => Integer_64 (C.Led_Strip_Config.Ledstrip_Grb_Rgb),
        when Ledstrip_Profile => Integer_64 (C.Led_Strip_Config.Ledstrip_Profile),
        when Ledstrip_Race_Color => Integer_64 (C.Led_Strip_Config.Ledstrip_Race_Color),
        when Ledstrip_Beacon_Color => Integer_64 (C.Led_Strip_Config.Ledstrip_Beacon_Color),
        when Ledstrip_Beacon_Period_Ms => Integer_64 (C.Led_Strip_Config.Ledstrip_Beacon_Period_Ms),
        when Ledstrip_Beacon_Percent => Integer_64 (C.Led_Strip_Config.Ledstrip_Beacon_Percent),
        when Ledstrip_Beacon_Armed_Only => Integer_64 (C.Led_Strip_Config.Ledstrip_Beacon_Armed_Only),
        when Ledstrip_Brightness => Integer_64 (C.Led_Strip_Config.Ledstrip_Brightness),
        when Ledstrip_Rainbow_Delta => Integer_64 (C.Led_Strip_Config.Ledstrip_Rainbow_Delta),
        when Ledstrip_Rainbow_Freq => Integer_64 (C.Led_Strip_Config.Ledstrip_Rainbow_Freq),
        when Transponder_Provider => Integer_64 (C.Transponder_Config.Provider),
        when Transponder_Data => Integer_64 (C.Transponder_Config.Data (Index)),
        when Sdcard_Detect_Inverted => Integer_64 (C.Sdcard_Config.Card_Detect_Inverted),
        when Sdcard_Mode => Integer_64 (C.Sdcard_Config.Mode),
        when Osd_Units => Integer_64 (C.Osd_Config.Units),
        when Osd_Warn_Bitmask => Integer_64 (C.Osd_Config.Enabled_Warnings),
        when Osd_Rssi_Alarm => Integer_64 (C.Osd_Config.Rssi_Alarm),
        when Osd_Link_Quality_Alarm => Integer_64 (C.Osd_Config.Link_Quality_Alarm),
        when Osd_Rssi_Dbm_Alarm => Integer_64 (C.Osd_Config.Rssi_Dbm_Alarm),
        when Osd_Rsnr_Alarm => Integer_64 (C.Osd_Config.Rsnr_Alarm),
        when Osd_Cap_Alarm => Integer_64 (C.Osd_Config.Cap_Alarm),
        when Osd_Alt_Alarm => Integer_64 (C.Osd_Config.Alt_Alarm),
        when Osd_Distance_Alarm => Integer_64 (C.Osd_Config.Distance_Alarm),
        when Osd_Esc_Temp_Alarm => Integer_64 (C.Osd_Config.Esc_Temp_Alarm),
        when Osd_Esc_Rpm_Alarm => Integer_64 (C.Osd_Config.Esc_Rpm_Alarm),
        when Osd_Esc_Current_Alarm => Integer_64 (C.Osd_Config.Esc_Current_Alarm),
        when Osd_Core_Temp_Alarm => Integer_64 (C.Osd_Config.Core_Temp_Alarm),
        when Osd_Ah_Max_Pit => Integer_64 (C.Osd_Config.Ah_Max_Pitch),
        when Osd_Ah_Max_Rol => Integer_64 (C.Osd_Config.Ah_Max_Roll),
        when Osd_Ah_Invert => Integer_64 (C.Osd_Config.Ah_Invert),
        when Osd_Logo_On_Arming => Integer_64 (C.Osd_Config.Logo_On_Arming),
        when Osd_Logo_On_Arming_Duration => Integer_64 (C.Osd_Config.Logo_On_Arming_Duration),
        when Osd_Arming_Logo => Integer_64 (C.Osd_Config.Arming_Logo),
        when Osd_Use_Quick_Menu => Integer_64 (C.Osd_Config.Osd_Use_Quick_Menu),
        when Osd_Show_Spec_Prearm => Integer_64 (C.Osd_Config.Osd_Show_Spec_Prearm),
        when Osd_Tim1 => Integer_64 (C.Osd_Config.Timers (0)),
        when Osd_Tim2 => Integer_64 (C.Osd_Config.Timers (1)),
        when Osd_Vbat_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (1)),
        when Osd_Rssi_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (0)),
        when Osd_Link_Quality_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (46)),
        when Osd_Link_Tx_Power_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (61)),
        when Osd_Rssi_Dbm_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (55)),
        when Osd_Rsnr_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (65)),
        when Osd_Tim_1_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (5)),
        when Osd_Tim_2_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (6)),
        when Osd_Remaining_Time_Estimate_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (37)),
        when Osd_Flymode_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (7)),
        when Osd_Anti_Gravity_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (41)),
        when Osd_G_Force_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (42)),
        when Osd_Throttle_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (9)),
        when Osd_Vtx_Channel_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (10)),
        when Osd_Crosshairs_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (2)),
        when Osd_Ah_Sbar_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (4)),
        when Osd_Ah_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (3)),
        when Osd_Current_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (11)),
        when Osd_Mah_Drawn_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (12)),
        when Osd_Wh_Drawn_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (62)),
        when Osd_Motor_Diag_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (43)),
        when Osd_Craft_Name_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (8)),
        when Osd_Pilot_Name_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (50)),
        when Osd_Gps_Speed_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (13)),
        when Osd_Gps_Lon_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (23)),
        when Osd_Gps_Lat_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (24)),
        when Osd_Gps_Lap_Curr_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (77)),
        when Osd_Gps_Lap_Prev_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (78)),
        when Osd_Gps_Lap_Best3_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (79)),
        when Osd_Gps_Sats_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (14)),
        when Osd_Home_Dir_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (30)),
        when Osd_Home_Dist_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (31)),
        when Osd_Flight_Dist_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (47)),
        when Osd_Compass_Bar_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (34)),
        when Osd_Altitude_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (15)),
        when Osd_Pid_Roll_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (16)),
        when Osd_Pid_Pitch_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (17)),
        when Osd_Pid_Yaw_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (18)),
        when Osd_Debug_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (25)),
        when Osd_Debug2_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (80)),
        when Osd_Power_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (19)),
        when Osd_Pidrate_Profile_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (20)),
        when Osd_Warnings_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (21)),
        when Osd_Avg_Cell_Voltage_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (22)),
        when Osd_Pit_Ang_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (26)),
        when Osd_Rol_Ang_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (27)),
        when Osd_Battery_Usage_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (28)),
        when Osd_Disarmed_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (29)),
        when Osd_Nheading_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (32)),
        when Osd_Up_Down_Reference_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (60)),
        when Osd_Ready_Mode_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (64)),
        when Osd_Pos_Hold_Ready_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (97)),
        when Osd_Nvario_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (33)),
        when Osd_Esc_Tmp_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (35)),
        when Osd_Esc_Rpm_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (36)),
        when Osd_Esc_Rpm_Freq_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (51)),
        when Osd_Rtc_Date_Time_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (38)),
        when Osd_Adjustment_Range_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (39)),
        when Osd_Flip_Arrow_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (45)),
        when Osd_Core_Temp_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (40)),
        when Osd_Log_Status_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (44)),
        when Osd_Stick_Overlay_Left_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (48)),
        when Osd_Stick_Overlay_Right_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (49)),
        when Osd_Stick_Overlay_Radio_Mode => Integer_64 (C.Osd_Config.Overlay_Radio_Mode),
        when Osd_Rate_Profile_Name_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (52)),
        when Osd_Pid_Profile_Name_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (53)),
        when Osd_Battery_Profile_Name_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (87)),
        when Osd_Profile_Name_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (54)),
        when Osd_Rcchannels_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (56)),
        when Osd_Camera_Frame_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (57)),
        when Osd_Efficiency_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (58)),
        when Osd_Total_Flights_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (59)),
        when Osd_Aux_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (63)),
        when Osd_Sys_Goggle_Voltage_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (66)),
        when Osd_Sys_Vtx_Voltage_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (67)),
        when Osd_Sys_Bitrate_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (68)),
        when Osd_Sys_Delay_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (69)),
        when Osd_Sys_Distance_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (70)),
        when Osd_Sys_Lq_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (71)),
        when Osd_Sys_Goggle_Dvr_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (72)),
        when Osd_Sys_Vtx_Dvr_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (73)),
        when Osd_Sys_Warnings_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (74)),
        when Osd_Sys_Vtx_Temp_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (75)),
        when Osd_Sys_Fan_Speed_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (76)),
        when Osd_Stat_Bitmask => Integer_64 (C.Osd_Config.Enabled_Stats),
        when Osd_Profile => Integer_64 (C.Osd_Config.Osd_Profile_Index),
        when Osd_Gps_Sats_Show_Pdop => Integer_64 (C.Osd_Config.Gps_Sats_Show_Pdop),
        when Osd_Displayport_Device => Integer_64 (C.Osd_Config.Display_Port_Device),
        when Osd_Uart => Integer_64 (C.Osd_Config.Osd_Uart),
        when Osd_Rcchannels => Integer_64 (C.Osd_Config.Rc_Channels (Index)),
        when Osd_Camera_Frame_Width => Integer_64 (C.Osd_Config.Camera_Frame_Width),
        when Osd_Camera_Frame_Height => Integer_64 (C.Osd_Config.Camera_Frame_Height),
        when Osd_Stat_Avg_Cell_Value => Integer_64 (C.Osd_Config.Stat_Show_Cell_Value),
        when Osd_Framerate_Hz => Integer_64 (C.Osd_Config.Framerate_Hz),
        when Osd_Menu_Background => Integer_64 (C.Osd_Config.Cms_Background_Type),
        when Osd_Aux_Channel => Integer_64 (C.Osd_Config.Aux_Channel),
        when Osd_Aux_Scale => Integer_64 (C.Osd_Config.Aux_Scale),
        when Osd_Aux_Symbol => Integer_64 (C.Osd_Config.Aux_Symbol),
        when Osd_Craftname_Msgs => Integer_64 (C.Osd_Config.Osd_Craftname_Msgs),
        when Osd_Lidar_Dist_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (85)),
        when Osd_Custom_Serial_Text_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (86)),
        when Osd_Custom_Serial_Text_Terminator => Integer_64 (C.Osd_Custom_Text_Config.Terminator),
        when Osd_Custom_Text_Uart => Integer_64 (C.Osd_Config.Osd_Custom_Text_Uart),
        when Osd_Custom_Text_Baud => Integer_64 (C.Osd_Config.Osd_Custom_Text_Baud),
        when Osd_Wp_Number_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (88)),
        when Osd_Wp_Current_Lat_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (89)),
        when Osd_Wp_Current_Lon_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (90)),
        when Osd_Wp_Current_Alt_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (91)),
        when Osd_Wp_Distance_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (92)),
        when Osd_Wp_Direction_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (93)),
        when Osd_Wp_Next_Number_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (94)),
        when Osd_Wp_Eta_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (95)),
        when Osd_Nav_Map_Pos => Integer_64 (C.Osd_Element_Config.Item_Pos (96)),
        when Osd_Nav_Map_Mode => Integer_64 (C.Osd_Nav_Map_Config.Mode),
        when Osd_Nav_Map_Centre => Integer_64 (C.Osd_Nav_Map_Config.Centre),
        when Osd_Nav_Map_Min_Scale_M => Integer_64 (C.Osd_Nav_Map_Config.Min_Scale_M),
        when Osd_Airspeed => Integer_64 (C.Osd_Element_Config.Item_Pos (98)),
        when System_Hse_Mhz => Integer_64 (C.System_Config.Hse_Mhz),
        when Task_Statistics => Signed_8 (C.System_Config.Task_Statistics),
        when Debug_Mode => Integer_64 (C.System_Config.Debug_Mode),
        when Rate_6pos_Switch => Integer_64 (C.System_Config.Rate_Profile6_Pos_Switch),
        when Cpu_Overclock => Integer_64 (C.System_Config.Cpu_Overclock),
        when Pwr_On_Arm_Grace => Integer_64 (C.System_Config.Power_On_Arming_Grace_Time),
        when Enable_Stick_Arming => Integer_64 (C.System_Config.Enable_Stick_Arming),
        when Vtx_Band => Integer_64 (C.Vtx_Settings_Config.Band),
        when Vtx_Channel => Integer_64 (C.Vtx_Settings_Config.Channel),
        when Vtx_Power => Integer_64 (C.Vtx_Settings_Config.Power),
        when Vtx_Low_Power_Disarm => Integer_64 (C.Vtx_Settings_Config.Low_Power_Disarm),
        when Vtx_Softserial_Alt => Integer_64 (C.Vtx_Settings_Config.Softserial_Alt),
        when Vtx_Type => Integer_64 (C.Vtx_Settings_Config.Vtx_Type),
        when Vtx_Uart => Integer_64 (C.Vtx_Settings_Config.Vtx_Uart),
        when Vtx_Freq => Integer_64 (C.Vtx_Settings_Config.Freq),
        when Vtx_Pit_Mode_Freq => Integer_64 (C.Vtx_Settings_Config.Pit_Mode_Freq),
        when Vtx_Halfduplex => Integer_64 (C.Vtx_Config.Half_Duplex),
        when Vtx_Spi_Bus => Integer_64 (C.Vtx_Io_Config.Spi_Device),
        when Vcd_Video_System => Integer_64 (C.Vcd_Profile.Video_System),
        when Vcd_H_Offset => Integer_64 (C.Vcd_Profile.H_Offset),
        when Vcd_V_Offset => Integer_64 (C.Vcd_Profile.V_Offset),
        when Max7456_Clock => Integer_64 (C.Max7456_Config.Clock_Config),
        when Max7456_Spi_Bus => Integer_64 (C.Max7456_Config.Spi_Device),
        when Max7456_Preinit_Opu => Boolean'Pos (C.Max7456_Config.Pre_Init_Opu),
        when Displayport_Msp_Col_Adjust => Integer_64 (C.Display_Port_Profile_Msp.Col_Adjust),
        when Displayport_Msp_Row_Adjust => Integer_64 (C.Display_Port_Profile_Msp.Row_Adjust),
        when Displayport_Msp_Fonts => Integer_64 (C.Display_Port_Profile_Msp.Font_Selection (Index)),
        when Displayport_Msp_Use_Device_Blink => Integer_64 (C.Display_Port_Profile_Msp.Use_Device_Blink),
        when Displayport_Max7456_Col_Adjust => Integer_64 (C.Display_Port_Profile_Max7456.Col_Adjust),
        when Displayport_Max7456_Row_Adjust => Integer_64 (C.Display_Port_Profile_Max7456.Row_Adjust),
        when Displayport_Max7456_Inv => Boolean'Pos (C.Display_Port_Profile_Max7456.Invert),
        when Displayport_Max7456_Blk => Integer_64 (C.Display_Port_Profile_Max7456.Black_Brightness),
        when Displayport_Max7456_Wht => Integer_64 (C.Display_Port_Profile_Max7456.White_Brightness),
        when Esc_Sensor_Halfduplex => Integer_64 (C.Esc_Sensor_Config.Half_Duplex),
        when Esc_Sensor_Current_Offset => Integer_64 (C.Esc_Sensor_Config.Offset),
        when Esc_Sensor_Uart => Integer_64 (C.Esc_Sensor_Config.Esc_Sensor_Uart),
        when Frsky_Spi_Autobind => Integer_64 (C.Rx_Cc2500_Spi_Config.Auto_Bind),
        when Frsky_Spi_Tx_Id => Integer_64 (C.Rx_Cc2500_Spi_Config.Bind_Tx_Id (Index)),
        when Frsky_Spi_Offset => Integer_64 (C.Rx_Cc2500_Spi_Config.Bind_Offset),
        when Frsky_Spi_Bind_Hop_Data => Integer_64 (C.Rx_Cc2500_Spi_Config.Bind_Hop_Data (Index)),
        when Frsky_X_Rx_Num => Integer_64 (C.Rx_Cc2500_Spi_Config.Rx_Num),
        when Frsky_Spi_A1_Source => Integer_64 (C.Rx_Cc2500_Spi_Config.A1_Source),
        when Cc2500_Spi_Chip_Detect => Integer_64 (C.Rx_Cc2500_Spi_Config.Chip_Detect_Enabled),
        when Led_Inversion => Integer_64 (C.Status_Led_Config.Inversion),
        when Dashboard_I2c_Bus => Integer_64 (Unsigned_8 (Unsigned_32'Mod (Integer_64 (C.Dashboard_Config.Device)) and
           16#FF#)),
        when Dashboard_I2c_Addr => Integer_64 (C.Dashboard_Config.Address),
        when Rangefinder_Hardware => Integer_64 (C.Rangefinder_Config.Rangefinder_Hardware),
        when Rangefinder_Uart => Integer_64 (C.Rangefinder_Config.Rangefinder_Uart),
        when Opticalflow_Hardware => Integer_64 (C.Opticalflow_Config.Opticalflow_Hardware),
        when Opticalflow_Uart => Integer_64 (C.Opticalflow_Config.Opticalflow_Uart),
        when Opticalflow_Rotation => Signed_16 (C.Opticalflow_Config.Rotation),
        when Opticalflow_Flip_X => Integer_64 (C.Opticalflow_Config.Flip_X),
        when Pinio_Config => Integer_64 (C.Pinio_Config.Config (Index)),
        when Pinio_Box => Integer_64 (C.Pinio_Box_Config.Permanent_Id (Index)),
        when Usb_Hid_Cdc => Integer_64 (C.Usb_Dev_Config.Type_Value),
        when Usb_Msc_Pin_Pullup => Integer_64 (C.Usb_Dev_Config.Msc_Button_Use_Pullup),
        when Flash_Spi_Bus => Integer_64 (C.Flash_Config.Spi_Device),
        when Rcdevice_Init_Dev_Attempts => Integer_64 (C.Rcdevice_Config.Init_Device_Attempts),
        when Rcdevice_Init_Dev_Attempt_Interval => Integer_64 (C.Rcdevice_Config.Init_Device_Attempt_Interval),
        when Rcdevice_Protocol_Version => Integer_64 (C.Rcdevice_Config.Protocol_Version),
        when Rcdevice_Feature => Integer_64 (Unsigned_16 (C.Rcdevice_Config.Feature and 16#FFFF#)),
        when Rcdevice_Uart => Integer_64 (C.Rcdevice_Config.Rcdevice_Uart),
        when Gyro_1_Bustype => Integer_64 (C.Gyro_Device_Config (0).Bus_Type),
        when Gyro_1_Spibus => Integer_64 (C.Gyro_Device_Config (0).Spi_Bus),
        when Gyro_1_I2c_Bus => Integer_64 (C.Gyro_Device_Config (0).I2c_Bus),
        when Gyro_1_I2c_Address => Integer_64 (C.Gyro_Device_Config (0).I2c_Address),
        when I2c1_Pullup => Boolean'Pos (C.I2c_Config (0).Pull_Up),
        when I2c1_Clockspeed_Khz => Integer_64 (C.I2c_Config (0).Clock_Speed),
        when I2c2_Pullup => Boolean'Pos (C.I2c_Config (1).Pull_Up),
        when I2c2_Clockspeed_Khz => Integer_64 (C.I2c_Config (1).Clock_Speed),
        when I2c3_Pullup => Boolean'Pos (C.I2c_Config (2).Pull_Up),
        when I2c3_Clockspeed_Khz => Integer_64 (C.I2c_Config (2).Clock_Speed),
        when Mco2_On_Pc9 => Integer_64 (C.Mco_Config (1).Enabled),
        when Spektrum_Spi_Protocol => Integer_64 (C.Spektrum_Config.Protocol),
        when Spektrum_Spi_Mfg_Id => Integer_64 (C.Spektrum_Config.Mfg_Id (Index)),
        when Spektrum_Spi_Num_Channels => Integer_64 (C.Spektrum_Config.Num_Channels),
        when Expresslrs_Uid => Integer_64 (C.Rx_Express_Lrs_Spi_Config.Uid (Index)),
        when Expresslrs_Domain => Integer_64 (C.Rx_Express_Lrs_Spi_Config.Domain),
        when Expresslrs_Model_Id => Integer_64 (C.Rx_Express_Lrs_Spi_Config.Model_Id),
        when Scheduler_Relax_Rx => Integer_64 (C.Scheduler_Config.Rx_Relax_Determinism),
        when Scheduler_Relax_Osd => Integer_64 (C.Scheduler_Config.Osd_Relax_Determinism),
        when Scheduler_Debug_Task => Integer_64 (C.Scheduler_Config.Debug_Task),
        when Cpu_Late_Limit_Permille => Integer_64 (Unsigned_8 (Unsigned_32
           (C.Scheduler_Config.Cpu_Late_Percentage_Limit) and 16#FF#)),
        when Serialmsp_Halfduplex => Integer_64 (C.Msp_Config.Half_Duplex),
        when Msp_1_Uart => Integer_64 (C.Msp_Config.Msp_Uart (0)),
        when Msp_1_Baud => Integer_64 (C.Msp_Config.Msp_Baud (0)),
        when Msp_2_Uart => Integer_64 (C.Msp_Config.Msp_Uart (1)),
        when Msp_2_Baud => Integer_64 (C.Msp_Config.Msp_Baud (1)),
        when Msp_3_Uart => Integer_64 (C.Msp_Config.Msp_Uart (2)),
        when Msp_3_Baud => Integer_64 (C.Msp_Config.Msp_Baud (2)),
        when Timezone_Offset_Minutes => Integer_64 (C.Time_Config.Tz_Offset_Minutes),
        when Rpm_Filter_Harmonics => Integer_64 (C.Rpm_Filter_Config.Rpm_Filter_Harmonics),
        when Rpm_Filter_Weights => Integer_64 (C.Rpm_Filter_Config.Rpm_Filter_Weights (Index)),
        when Rpm_Filter_Q => Integer_64 (C.Rpm_Filter_Config.Rpm_Filter_Q),
        when Rpm_Filter_Min_Hz => Integer_64 (C.Rpm_Filter_Config.Rpm_Filter_Min_Hz),
        when Rpm_Filter_Fade_Range_Hz => Integer_64 (C.Rpm_Filter_Config.Rpm_Filter_Fade_Range_Hz),
        when Rpm_Filter_Lpf_Hz => Integer_64 (C.Rpm_Filter_Config.Rpm_Filter_Lpf_Hz),
        when Flysky_Spi_Tx_Id => Integer_64 (C.Fly_Sky_Config.Tx_Id),
        when Flysky_Spi_Rf_Channels => Integer_64 (C.Fly_Sky_Config.Rf_Channel_Map (Index)),
        when Stats_Min_Armed_Time_S => Integer_64 (C.Stats_Config.Stats_Min_Armed_Time_S),
        when Stats_Total_Flights => Integer_64 (C.Stats_Config.Stats_Total_Flights),
        when Stats_Total_Time_S => Integer_64 (C.Stats_Config.Stats_Total_Time_S),
        when Stats_Total_Dist_M => Integer_64 (C.Stats_Config.Stats_Total_Dist_M),
        when Stats_Save_Move_Limit => Integer_64 (C.Stats_Config.Stats_Save_Move_Limit),
        when Stats_Mah_Used => Integer_64 (C.Stats_Config.Stats_Mah_Used),
        when Altitude_Source => Signed_8 (C.Position_Config.Altitude_Source),
        when Altitude_Prefer_Baro => Signed_8 (C.Position_Config.Altitude_Prefer_Baro),
        when Altitude_Lpf => Integer_64 (C.Position_Config.Altitude_Lpf),
        when Rangefinder_Max_Range_Cm => Integer_64 (C.Position_Config.Rangefinder_Max_Range_Cm),
        when Altitude_D_Lpf => Integer_64 (C.Position_Config.Altitude_D_Lpf),
        when Ap_Landing_Altitude_M => Integer_64 (C.Autopilot_Config.Landing_Altitude_M),
        when Ap_Hover_Throttle => Integer_64 (C.Autopilot_Config.Hover_Throttle),
        when Ap_Throttle_Min => Integer_64 (C.Autopilot_Config.Throttle_Min),
        when Ap_Throttle_Max => Integer_64 (C.Autopilot_Config.Throttle_Max),
        when Ap_Altitude_P => Integer_64 (C.Autopilot_Config.Altitude_P),
        when Ap_Altitude_I => Integer_64 (C.Autopilot_Config.Altitude_I),
        when Ap_Altitude_D => Integer_64 (C.Autopilot_Config.Altitude_D),
        when Ap_Altitude_A => Integer_64 (C.Autopilot_Config.Altitude_A),
        when Ap_Altitude_F => Integer_64 (C.Autopilot_Config.Altitude_F),
        when Ap_Position_P => Integer_64 (C.Autopilot_Config.Position_P),
        when Ap_Position_I => Integer_64 (C.Autopilot_Config.Position_I),
        when Ap_Position_D => Integer_64 (C.Autopilot_Config.Position_D),
        when Ap_Position_A => Integer_64 (C.Autopilot_Config.Position_A),
        when Ap_Position_F => Integer_64 (C.Autopilot_Config.Position_F),
        when Ap_Position_Cutoff => Integer_64 (C.Autopilot_Config.Position_Cutoff),
        when Ap_Stop_Threshold => Integer_64 (C.Autopilot_Config.Stop_Threshold),
        when Ap_Max_Angle => Integer_64 (C.Autopilot_Config.Max_Angle),
        when Ap_Max_Yaw_Rate => Integer_64 (C.Autopilot_Config.Max_Yaw_Rate),
        when Ap_Yaw_P => Integer_64 (C.Autopilot_Config.Yaw_P),
        when Ap_Velocity_Drag_Coeff => Integer_64 (C.Autopilot_Config.Velocity_Drag_Coeff),
        when Ap_Max_Velocity => Integer_64 (C.Autopilot_Config.Max_Velocity),
        when Ap_Waypoint_Arrival_Radius => Integer_64 (C.Autopilot_Config.Waypoint_Arrival_Radius),
        when Ap_Waypoint_Hold_Radius => Integer_64 (C.Autopilot_Config.Waypoint_Hold_Radius),
        when Ap_Stick_Deadband => Integer_64 (C.Autopilot_Config.Stick_Deadband),
        when Ap_Throttle_Deadband => Integer_64 (C.Autopilot_Config.Throttle_Deadband),
        when Ap_Yaw_Mode => Integer_64 (C.Autopilot_Config.Yaw_Mode),
        when Ap_Min_Forward_Velocity => Integer_64 (C.Autopilot_Config.Min_Forward_Velocity),
        when Ap_Nav_Corner_Speed => Integer_64 (C.Autopilot_Config.Nav_Corner_Speed),
        when Ap_Nav_Corner_Delta_V => Integer_64 (C.Autopilot_Config.Nav_Corner_Delta_V),
        when Ap_Nav_Decel => Integer_64 (C.Autopilot_Config.Nav_Decel),
        when Ap_Nav_Accel => Integer_64 (C.Autopilot_Config.Nav_Accel),
        when Ap_Nav_Carrot_Lead_Time => Integer_64 (C.Autopilot_Config.Nav_Carrot_Lead_Time),
        when Ap_Nav_Carrot_Lead_Max => Integer_64 (C.Autopilot_Config.Nav_Carrot_Lead_Max),
        when Ap_Nav_Preturn_Dist => Integer_64 (C.Autopilot_Config.Nav_Preturn_Dist),
        when Ap_Velocity_Buildup_Max_Pitch => Integer_64 (C.Autopilot_Config.Velocity_Buildup_Max_Pitch),
        when Ap_Max_Turn_Rate => Integer_64 (C.Autopilot_Config.Max_Turn_Rate),
        when Ap_Hold_Orbit_Radius => Integer_64 (C.Autopilot_Config.Hold_Orbit_Radius),
        when Ap_Hold_Figure8_Width => Integer_64 (C.Autopilot_Config.Hold_Figure8_Width),
        when Ap_Landing_Descent_Rate => Integer_64 (C.Autopilot_Config.Landing_Descent_Rate),
        when Ap_Landing_Detection_Time => Integer_64 (C.Autopilot_Config.Landing_Detection_Time),
        when Ap_Landing_Spiral_Enable => Integer_64 (C.Autopilot_Config.Landing_Spiral_Enable),
        when Ap_Landing_Spiral_Radius => Integer_64 (C.Autopilot_Config.Landing_Spiral_Radius),
        when Ap_Landing_Spiral_Rate => Integer_64 (C.Autopilot_Config.Landing_Spiral_Rate),
        when Ap_Landing_Velocity_Threshold => Integer_64 (C.Autopilot_Config.Landing_Velocity_Threshold),
        when Ap_Landing_Throttle_Threshold => Integer_64 (C.Autopilot_Config.Landing_Throttle_Threshold),
        when Ap_L1_Enable => Integer_64 (C.Autopilot_Config.L1_Enable),
        when Ap_L1_Period => Integer_64 (C.Autopilot_Config.L1_Period),
        when Ap_L1_Min_Lookahead => Integer_64 (C.Autopilot_Config.L1_Min_Lookahead),
        when Ap_L1_Max_Lookahead => Integer_64 (C.Autopilot_Config.L1_Max_Lookahead),
        when Ap_L1_Max_Cross_Track_Error => Integer_64 (C.Autopilot_Config.L1_Max_Cross_Track_Error),
        when Ap_L1_Turn_Rate => Integer_64 (C.Autopilot_Config.L1_Turn_Rate),
        when Ap_Min_Nav_Altitude_M => Integer_64 (C.Autopilot_Config.Min_Nav_Altitude_M),
        when Ap_Rx_Loss_Policy => Integer_64 (C.Autopilot_Config.Rx_Loss_Policy),
        when Ap_Max_Distance_From_Home => Integer_64 (C.Autopilot_Config.Max_Distance_From_Home_M),
        when Ap_Geofence_Action => Integer_64 (C.Autopilot_Config.Geofence_Action),
        when Gimbal_Roll_Rc_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Roll_Rc_Gain),
        when Gimbal_Pitch_Rc_Thr_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Pitch_Rc_Thr_Gain),
        when Gimbal_Pitch_Rc_Low_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Pitch_Rc_Low_Gain),
        when Gimbal_Pitch_Rc_High_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Pitch_Rc_High_Gain),
        when Gimbal_Yaw_Rc_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Yaw_Rc_Gain),
        when Gimbal_Roll_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Roll_Gain),
        when Gimbal_Roll_Offset => Integer_64 (C.Gimbal_Track_Config.Gimbal_Roll_Offset),
        when Gimbal_Roll_Limit => Integer_64 (C.Gimbal_Track_Config.Gimbal_Roll_Limit),
        when Gimbal_Pitch_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Pitch_Gain),
        when Gimbal_Pitch_Offset => Integer_64 (C.Gimbal_Track_Config.Gimbal_Pitch_Offset),
        when Gimbal_Pitch_Low_Limit => Integer_64 (C.Gimbal_Track_Config.Gimbal_Pitch_Low_Limit),
        when Gimbal_Pitch_High_Limit => Integer_64 (C.Gimbal_Track_Config.Gimbal_Pitch_High_Limit),
        when Gimbal_Yaw_Gain => Integer_64 (C.Gimbal_Track_Config.Gimbal_Yaw_Gain),
        when Gimbal_Yaw_Offset => Integer_64 (C.Gimbal_Track_Config.Gimbal_Yaw_Offset),
        when Gimbal_Yaw_Limit => Integer_64 (C.Gimbal_Track_Config.Gimbal_Yaw_Limit),
        when Gimbal_Stabilisation => Integer_64 (C.Gimbal_Track_Config.Gimbal_Stabilisation),
        when Gimbal_Sensitivity => Integer_64 (C.Gimbal_Track_Config.Gimbal_Sensitivity),
        when Gimbal_Uart => Integer_64 (C.Gimbal_Track_Config.Gimbal_Uart),
        when others => 0);

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
          Transponder_Provider | Transponder_Data | Sdcard_Detect_Inverted | Sdcard_Mode | Osd_Units | Osd_Rssi_Alarm
          | Osd_Esc_Temp_Alarm | Osd_Core_Temp_Alarm | Osd_Ah_Max_Pit | Osd_Ah_Max_Rol | Osd_Ah_Invert |
          Osd_Logo_On_Arming | Osd_Logo_On_Arming_Duration | Osd_Arming_Logo | Osd_Use_Quick_Menu |
          Osd_Show_Spec_Prearm | Osd_Stick_Overlay_Radio_Mode | Osd_Profile | Osd_Gps_Sats_Show_Pdop |
          Osd_Displayport_Device | Osd_Camera_Frame_Width | Osd_Camera_Frame_Height | Osd_Stat_Avg_Cell_Value |
          Osd_Menu_Background | Osd_Aux_Channel | Osd_Aux_Symbol | Osd_Craftname_Msgs |
          Osd_Custom_Serial_Text_Terminator | Osd_Custom_Text_Baud | Osd_Nav_Map_Mode | Osd_Nav_Map_Centre |
          System_Hse_Mhz | Debug_Mode | Rate_6pos_Switch | Cpu_Overclock | Pwr_On_Arm_Grace | Enable_Stick_Arming |
          Vtx_Band | Vtx_Channel | Vtx_Power | Vtx_Low_Power_Disarm | Vtx_Softserial_Alt | Vtx_Type | Vtx_Halfduplex |
          Vtx_Spi_Bus | Vcd_Video_System | Max7456_Clock | Max7456_Spi_Bus | Displayport_Msp_Fonts |
          Displayport_Msp_Use_Device_Blink | Displayport_Max7456_Blk | Displayport_Max7456_Wht | Esc_Sensor_Halfduplex
          | Frsky_Spi_Autobind | Frsky_Spi_Tx_Id | Frsky_Spi_Bind_Hop_Data | Frsky_X_Rx_Num | Frsky_Spi_A1_Source |
          Cc2500_Spi_Chip_Detect | Led_Inversion | Dashboard_I2c_Bus | Dashboard_I2c_Addr | Rangefinder_Hardware |
          Opticalflow_Hardware | Opticalflow_Flip_X | Pinio_Config | Pinio_Box | Usb_Hid_Cdc | Usb_Msc_Pin_Pullup |
          Flash_Spi_Bus | Rcdevice_Init_Dev_Attempts | Rcdevice_Protocol_Version | Gyro_1_Bustype | Gyro_1_Spibus |
          Gyro_1_I2c_Bus | Gyro_1_I2c_Address | Mco2_On_Pc9 | Spektrum_Spi_Protocol | Spektrum_Spi_Mfg_Id |
          Spektrum_Spi_Num_Channels | Expresslrs_Uid | Expresslrs_Domain | Expresslrs_Model_Id |
          Cpu_Late_Limit_Permille | Serialmsp_Halfduplex | Msp_1_Baud | Msp_2_Baud | Msp_3_Baud | Rpm_Filter_Harmonics
          | Rpm_Filter_Weights | Rpm_Filter_Min_Hz | Flysky_Spi_Rf_Channels | Stats_Save_Move_Limit |
          Ap_Landing_Altitude_M | Ap_Altitude_P | Ap_Altitude_I | Ap_Altitude_D | Ap_Altitude_A | Ap_Altitude_F |
          Ap_Position_P | Ap_Position_I | Ap_Position_D | Ap_Position_A | Ap_Position_F | Ap_Position_Cutoff |
          Ap_Stop_Threshold | Ap_Max_Angle | Ap_Max_Yaw_Rate | Ap_Yaw_P | Ap_Velocity_Drag_Coeff | Ap_Yaw_Mode |
          Ap_Nav_Carrot_Lead_Time | Ap_Velocity_Buildup_Max_Pitch | Ap_Max_Turn_Rate | Ap_Landing_Descent_Rate |
          Ap_Landing_Detection_Time | Ap_Landing_Spiral_Enable | Ap_Landing_Spiral_Rate |
          Ap_Landing_Velocity_Threshold | Ap_L1_Enable | Ap_L1_Turn_Rate | Ap_Min_Nav_Altitude_M | Ap_Rx_Loss_Policy |
          Ap_Geofence_Action => 0,
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
          Rcdevice_Feature | I2c1_Clockspeed_Khz | I2c2_Clockspeed_Khz | I2c3_Clockspeed_Khz | Scheduler_Relax_Rx |
          Scheduler_Relax_Osd | Scheduler_Debug_Task | Rpm_Filter_Q | Rpm_Filter_Fade_Range_Hz | Rpm_Filter_Lpf_Hz |
          Altitude_Lpf | Rangefinder_Max_Range_Cm | Altitude_D_Lpf | Ap_Hover_Throttle | Ap_Throttle_Min |
          Ap_Throttle_Max | Ap_Max_Velocity | Ap_Waypoint_Arrival_Radius | Ap_Waypoint_Hold_Radius | Ap_Stick_Deadband
          | Ap_Throttle_Deadband | Ap_Min_Forward_Velocity | Ap_Nav_Corner_Speed | Ap_Nav_Corner_Delta_V |
          Ap_Nav_Decel | Ap_Nav_Accel | Ap_Nav_Carrot_Lead_Max | Ap_Nav_Preturn_Dist | Ap_Hold_Orbit_Radius |
          Ap_Hold_Figure8_Width | Ap_Landing_Spiral_Radius | Ap_Landing_Throttle_Threshold | Ap_L1_Period |
          Ap_L1_Min_Lookahead | Ap_L1_Max_Lookahead | Ap_L1_Max_Cross_Track_Error | Ap_Max_Distance_From_Home => 0,
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
          Transponder_Provider | Transponder_Data | Sdcard_Detect_Inverted | Sdcard_Mode | Osd_Units | Osd_Rssi_Alarm
          | Osd_Esc_Temp_Alarm | Osd_Core_Temp_Alarm | Osd_Ah_Max_Pit | Osd_Ah_Max_Rol | Osd_Ah_Invert |
          Osd_Logo_On_Arming | Osd_Logo_On_Arming_Duration | Osd_Arming_Logo | Osd_Use_Quick_Menu |
          Osd_Show_Spec_Prearm | Osd_Stick_Overlay_Radio_Mode | Osd_Profile | Osd_Gps_Sats_Show_Pdop |
          Osd_Displayport_Device | Osd_Camera_Frame_Width | Osd_Camera_Frame_Height | Osd_Stat_Avg_Cell_Value |
          Osd_Menu_Background | Osd_Aux_Channel | Osd_Aux_Symbol | Osd_Craftname_Msgs |
          Osd_Custom_Serial_Text_Terminator | Osd_Custom_Text_Baud | Osd_Nav_Map_Mode | Osd_Nav_Map_Centre |
          System_Hse_Mhz | Debug_Mode | Rate_6pos_Switch | Cpu_Overclock | Pwr_On_Arm_Grace | Enable_Stick_Arming |
          Vtx_Band | Vtx_Channel | Vtx_Power | Vtx_Low_Power_Disarm | Vtx_Softserial_Alt | Vtx_Type | Vtx_Halfduplex |
          Vtx_Spi_Bus | Vcd_Video_System | Max7456_Clock | Max7456_Spi_Bus | Displayport_Msp_Fonts |
          Displayport_Msp_Use_Device_Blink | Displayport_Max7456_Blk | Displayport_Max7456_Wht | Esc_Sensor_Halfduplex
          | Frsky_Spi_Autobind | Frsky_Spi_Tx_Id | Frsky_Spi_Bind_Hop_Data | Frsky_X_Rx_Num | Frsky_Spi_A1_Source |
          Cc2500_Spi_Chip_Detect | Led_Inversion | Dashboard_I2c_Bus | Dashboard_I2c_Addr | Rangefinder_Hardware |
          Opticalflow_Hardware | Opticalflow_Flip_X | Pinio_Config | Pinio_Box | Usb_Hid_Cdc | Usb_Msc_Pin_Pullup |
          Flash_Spi_Bus | Rcdevice_Init_Dev_Attempts | Rcdevice_Protocol_Version | Gyro_1_Bustype | Gyro_1_Spibus |
          Gyro_1_I2c_Bus | Gyro_1_I2c_Address | Mco2_On_Pc9 | Spektrum_Spi_Protocol | Spektrum_Spi_Mfg_Id |
          Spektrum_Spi_Num_Channels | Expresslrs_Uid | Expresslrs_Domain | Expresslrs_Model_Id |
          Cpu_Late_Limit_Permille | Serialmsp_Halfduplex | Msp_1_Baud | Msp_2_Baud | Msp_3_Baud | Rpm_Filter_Harmonics
          | Rpm_Filter_Weights | Rpm_Filter_Min_Hz | Flysky_Spi_Rf_Channels | Stats_Save_Move_Limit |
          Ap_Landing_Altitude_M | Ap_Altitude_P | Ap_Altitude_I | Ap_Altitude_D | Ap_Altitude_A | Ap_Altitude_F |
          Ap_Position_P | Ap_Position_I | Ap_Position_D | Ap_Position_A | Ap_Position_F | Ap_Position_Cutoff |
          Ap_Stop_Threshold | Ap_Max_Angle | Ap_Max_Yaw_Rate | Ap_Yaw_P | Ap_Velocity_Drag_Coeff | Ap_Yaw_Mode |
          Ap_Nav_Carrot_Lead_Time | Ap_Velocity_Buildup_Max_Pitch | Ap_Max_Turn_Rate | Ap_Landing_Descent_Rate |
          Ap_Landing_Detection_Time | Ap_Landing_Spiral_Enable | Ap_Landing_Spiral_Rate |
          Ap_Landing_Velocity_Threshold | Ap_L1_Enable | Ap_L1_Turn_Rate | Ap_Min_Nav_Altitude_M | Ap_Rx_Loss_Policy |
          Ap_Geofence_Action => 255,
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
          Rcdevice_Feature | I2c1_Clockspeed_Khz | I2c2_Clockspeed_Khz | I2c3_Clockspeed_Khz | Scheduler_Relax_Rx |
          Scheduler_Relax_Osd | Scheduler_Debug_Task | Rpm_Filter_Q | Rpm_Filter_Fade_Range_Hz | Rpm_Filter_Lpf_Hz |
          Altitude_Lpf | Rangefinder_Max_Range_Cm | Altitude_D_Lpf | Ap_Hover_Throttle | Ap_Throttle_Min |
          Ap_Throttle_Max | Ap_Max_Velocity | Ap_Waypoint_Arrival_Radius | Ap_Waypoint_Hold_Radius | Ap_Stick_Deadband
          | Ap_Throttle_Deadband | Ap_Min_Forward_Velocity | Ap_Nav_Corner_Speed | Ap_Nav_Corner_Delta_V |
          Ap_Nav_Decel | Ap_Nav_Accel | Ap_Nav_Carrot_Lead_Max | Ap_Nav_Preturn_Dist | Ap_Hold_Orbit_Radius |
          Ap_Hold_Figure8_Width | Ap_Landing_Spiral_Radius | Ap_Landing_Throttle_Threshold | Ap_L1_Period |
          Ap_L1_Min_Lookahead | Ap_L1_Max_Lookahead | Ap_L1_Max_Cross_Track_Error | Ap_Max_Distance_From_Home => 65535,
        when Msp_Override_Channels_Mask | Osd_Warn_Bitmask | Osd_Stat_Bitmask | Rcdevice_Init_Dev_Attempt_Interval |
          Flysky_Spi_Tx_Id | Stats_Total_Flights | Stats_Total_Time_S | Stats_Total_Dist_M | Stats_Mah_Used =>
          4294967295,
        when others => 0);

   procedure Set_Gyro_Config (G : in out Gyro_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Gyro_Hardware_Lpf | Gyro_Lpf1_Type | Gyro_Lpf1_Static_Hz | Gyro_Lpf2_Type |
       Gyro_Lpf2_Static_Hz | Gyro_Notch1_Hz | Gyro_Notch1_Cutoff | Gyro_Notch2_Hz | Gyro_Notch2_Cutoff |
       Gyro_Calib_Duration | Gyro_Calib_Noise_Limit | Gyro_Offset_Yaw | Gyro_Overflow_Detect | Yaw_Spin_Recovery |
       Yaw_Spin_Threshold | Gyro_Lpf1_Dyn_Min_Hz | Gyro_Lpf1_Dyn_Max_Hz | Gyro_Lpf1_Dyn_Expo |
       Gyro_Filter_Debug_Axis | Simplified_Gyro_Filter | Simplified_Gyro_Filter_Multiplier) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Gyro_Hardware_Lpf =>
            G.Gyro_Hardware_Lpf := Unsigned_8'Mod (Value);
         when Gyro_Lpf1_Type =>
            G.Gyro_Lpf1_Type := Unsigned_8'Mod (Value);
         when Gyro_Lpf1_Static_Hz =>
            G.Gyro_Lpf1_Static_Hz := Unsigned_16'Mod (Value);
         when Gyro_Lpf2_Type =>
            G.Gyro_Lpf2_Type := Unsigned_8'Mod (Value);
         when Gyro_Lpf2_Static_Hz =>
            G.Gyro_Lpf2_Static_Hz := Unsigned_16'Mod (Value);
         when Gyro_Notch1_Hz =>
            G.Gyro_Soft_Notch_Hz_1 := Unsigned_16'Mod (Value);
         when Gyro_Notch1_Cutoff =>
            G.Gyro_Soft_Notch_Cutoff_1 := Unsigned_16'Mod (Value);
         when Gyro_Notch2_Hz =>
            G.Gyro_Soft_Notch_Hz_2 := Unsigned_16'Mod (Value);
         when Gyro_Notch2_Cutoff =>
            G.Gyro_Soft_Notch_Cutoff_2 := Unsigned_16'Mod (Value);
         when Gyro_Calib_Duration =>
            G.Gyro_Calibration_Duration := Unsigned_16'Mod (Value);
         when Gyro_Calib_Noise_Limit =>
            G.Gyro_Movement_Calibration_Threshold := Unsigned_8'Mod (Value);
         when Gyro_Offset_Yaw =>
            G.Gyro_Offset_Yaw := Signed (Unsigned_16'Mod (Value));
         when Gyro_Overflow_Detect =>
            G.Check_Overflow := Unsigned_8'Mod (Value);
         when Yaw_Spin_Recovery =>
            G.Yaw_Spin_Recovery := Unsigned_8'Mod (Value);
         when Yaw_Spin_Threshold =>
            G.Yaw_Spin_Threshold := Signed (Unsigned_16'Mod (Value));
         when Gyro_Lpf1_Dyn_Min_Hz =>
            G.Gyro_Lpf1_Dyn_Min_Hz := Unsigned_16'Mod (Value);
         when Gyro_Lpf1_Dyn_Max_Hz =>
            G.Gyro_Lpf1_Dyn_Max_Hz := Unsigned_16'Mod (Value);
         when Gyro_Lpf1_Dyn_Expo =>
            G.Gyro_Lpf1_Dyn_Expo := Unsigned_8'Mod (Value);
         when Gyro_Filter_Debug_Axis =>
            G.Gyro_Filter_Debug_Axis := Unsigned_8'Mod (Value);
         when Simplified_Gyro_Filter =>
            G.Simplified_Gyro_Filter := Unsigned_8'Mod (Value);
         when Simplified_Gyro_Filter_Multiplier =>
            G.Simplified_Gyro_Filter_Multiplier := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Gyro_Config;

   procedure Set_Dyn_Notch_Config (G : in out Dyn_Notch_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Dyn_Notch_Count | Dyn_Notch_Q | Dyn_Notch_Min_Hz | Dyn_Notch_Max_Hz) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Dyn_Notch_Count =>
            G.Dyn_Notch_Count := Unsigned_8'Mod (Value);
         when Dyn_Notch_Q =>
            G.Dyn_Notch_Q := Unsigned_16'Mod (Value);
         when Dyn_Notch_Min_Hz =>
            G.Dyn_Notch_Min_Hz := Unsigned_16'Mod (Value);
         when Dyn_Notch_Max_Hz =>
            G.Dyn_Notch_Max_Hz := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Dyn_Notch_Config;

   procedure Set_Accelerometer_Config (G : in out Accelerometer_Config_Record; S : Setting; Value : Integer_64; Index
      : Natural)
     with Pre => (S in Acc_Hardware | Acc_Lpf_Hz | Acc_Trim_Pitch | Acc_Trim_Roll | Acc_Calibration) and then
       Index < Element_Count (S)
   is
   begin
      case S is
         when Acc_Hardware =>
            G.Acc_Hardware := Unsigned_8'Mod (Value);
         when Acc_Lpf_Hz =>
            G.Acc_Lpf_Hz := Unsigned_16'Mod (Value);
         when Acc_Trim_Pitch =>
            G.Accelerometer_Trims (1) := Signed (Unsigned_16'Mod (Value));
         when Acc_Trim_Roll =>
            G.Accelerometer_Trims (0) := Signed (Unsigned_16'Mod (Value));
         when Acc_Calibration =>
            G.Acc_Zero (Index) := Signed (Unsigned_16'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Accelerometer_Config;

   procedure Set_Compass_Config (G : in out Compass_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Align_Mag | Mag_Align_Roll | Mag_Align_Pitch | Mag_Align_Yaw | Mag_Bustype |
       Mag_I2c_Device | Mag_I2c_Address | Mag_Spi_Device | Mag_Hardware | Mag_Calibration) and then Index <
       Element_Count (S)
   is
   begin
      case S is
         when Align_Mag =>
            G.Mag_Alignment := Unsigned_8'Mod (Value);
         when Mag_Align_Roll =>
            G.Mag_Custom_Alignment (0) := Signed (Unsigned_16'Mod (Value));
         when Mag_Align_Pitch =>
            G.Mag_Custom_Alignment (1) := Signed (Unsigned_16'Mod (Value));
         when Mag_Align_Yaw =>
            G.Mag_Custom_Alignment (2) := Signed (Unsigned_16'Mod (Value));
         when Mag_Bustype =>
            G.Mag_Bus_Type := Unsigned_8'Mod (Value);
         when Mag_I2c_Device =>
            G.Mag_I2c_Device := Unsigned_8'Mod (Value);
         when Mag_I2c_Address =>
            G.Mag_I2c_Address := Unsigned_8'Mod (Value);
         when Mag_Spi_Device =>
            G.Mag_Spi_Device := Unsigned_8'Mod (Value);
         when Mag_Hardware =>
            G.Mag_Hardware := Unsigned_8'Mod (Value);
         when Mag_Calibration =>
            G.Mag_Zero (Index) := Signed (Unsigned_16'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Compass_Config;

   procedure Set_Barometer_Config (G : in out Barometer_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Baro_Bustype | Baro_Spi_Device | Baro_I2c_Device | Baro_I2c_Address | Baro_Hardware |
       Baro_Drift) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Baro_Bustype =>
            G.Baro_Bus_Type := Unsigned_8'Mod (Value);
         when Baro_Spi_Device =>
            G.Baro_Spi_Device := Unsigned_8'Mod (Value);
         when Baro_I2c_Device =>
            G.Baro_I2c_Device := Unsigned_8'Mod (Value);
         when Baro_I2c_Address =>
            G.Baro_I2c_Address := Unsigned_8'Mod (Value);
         when Baro_Hardware =>
            G.Baro_Hardware := Unsigned_8'Mod (Value);
         when Baro_Drift =>
            G.Baro_Temp_Drift_Cm_Per10_C := Signed (Unsigned_16'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Barometer_Config;

   procedure Set_Pitot_Config (G : in out Pitot_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Pitot_Bustype | Pitot_I2c_Device | Pitot_I2c_Address | Pitot_Hardware) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Pitot_Bustype =>
            G.Pitot_Bus_Type := Unsigned_8'Mod (Value);
         when Pitot_I2c_Device =>
            G.Pitot_I2c_Device := Unsigned_8'Mod (Value);
         when Pitot_I2c_Address =>
            G.Pitot_I2c_Address := Unsigned_8'Mod (Value);
         when Pitot_Hardware =>
            G.Pitot_Hardware := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Pitot_Config;

   procedure Set_Rx_Config (G : in out Rx_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Mid_Rc | Min_Check | Max_Check | Rssi_Channel | Rssi_Src_Frame_Errors | Rssi_Scale |
       Rssi_Offset | Rssi_Invert | Rssi_Src_Frame_Lpf_Period | Rssi_Smoothing | Rc_Smoothing |
       Rc_Smoothing_Auto_Factor | Rc_Smoothing_Auto_Factor_Throttle | Rc_Smoothing_Setpoint_Cutoff |
       Rc_Smoothing_Throttle_Cutoff | Rc_Smoothing_Debug_Axis | Fpv_Mix_Degrees | Max_Aux_Channels |
       Serialrx_Provider | Serialrx_Inverted | Spektrum_Sat_Bind | Spektrum_Sat_Bind_Autoreset | Srxl2_Unit_Id |
       Srxl2_Baud_Fast | Sbus_Baud_Fast | Crsf_Use_Negotiated_Baud | Airmode_Start_Throttle_Percent | Rx_Min_Usec |
       Rx_Max_Usec | Serialrx_Halfduplex | Rx_Uart | Msp_Override_Channels_Mask | Msp_Override_Failsafe) and then
       Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Mid_Rc =>
            G.Midrc := Unsigned_16'Mod (Value);
         when Min_Check =>
            G.Mincheck := Unsigned_16'Mod (Value);
         when Max_Check =>
            G.Maxcheck := Unsigned_16'Mod (Value);
         when Rssi_Channel =>
            G.Rssi_Channel := Unsigned_8'Mod (Value);
         when Rssi_Src_Frame_Errors =>
            G.Rssi_Src_Frame_Errors := Unsigned_8'Mod (Value);
         when Rssi_Scale =>
            G.Rssi_Scale := Unsigned_8'Mod (Value);
         when Rssi_Offset =>
            G.Rssi_Offset := Signed (Unsigned_8'Mod (Value));
         when Rssi_Invert =>
            G.Rssi_Invert := Unsigned_8'Mod (Value);
         when Rssi_Src_Frame_Lpf_Period =>
            G.Rssi_Src_Frame_Lpf_Period := Unsigned_8'Mod (Value);
         when Rssi_Smoothing =>
            G.Rssi_Smoothing := Unsigned_8'Mod (Value);
         when Rc_Smoothing =>
            G.Rc_Smoothing := Unsigned_8'Mod (Value);
         when Rc_Smoothing_Auto_Factor =>
            G.Rc_Smoothing_Auto_Factor_Rpy := Unsigned_8'Mod (Value);
         when Rc_Smoothing_Auto_Factor_Throttle =>
            G.Rc_Smoothing_Auto_Factor_Throttle := Unsigned_8'Mod (Value);
         when Rc_Smoothing_Setpoint_Cutoff =>
            G.Rc_Smoothing_Setpoint_Cutoff := Unsigned_8'Mod (Value);
         when Rc_Smoothing_Throttle_Cutoff =>
            G.Rc_Smoothing_Throttle_Cutoff := Unsigned_8'Mod (Value);
         when Rc_Smoothing_Debug_Axis =>
            G.Rc_Smoothing_Debug_Axis := Unsigned_8'Mod (Value);
         when Fpv_Mix_Degrees =>
            G.Fpv_Cam_Angle_Degrees := Unsigned_8'Mod (Value);
         when Max_Aux_Channels =>
            G.Max_Aux_Channel := Unsigned_8'Mod (Value);
         when Serialrx_Provider =>
            G.Serialrx_Provider := Unsigned_8'Mod (Value);
         when Serialrx_Inverted =>
            G.Serialrx_Inverted := Unsigned_8'Mod (Value);
         when Spektrum_Sat_Bind =>
            G.Spektrum_Sat_Bind := Unsigned_8'Mod (Value);
         when Spektrum_Sat_Bind_Autoreset =>
            G.Spektrum_Sat_Bind_Autoreset := Unsigned_8'Mod (Value);
         when Srxl2_Unit_Id =>
            G.Srxl2_Unit_Id := Unsigned_8'Mod (Value);
         when Srxl2_Baud_Fast =>
            G.Srxl2_Baud_Fast := Unsigned_8'Mod (Value);
         when Sbus_Baud_Fast =>
            G.Sbus_Baud_Fast := Unsigned_8'Mod (Value);
         when Crsf_Use_Negotiated_Baud =>
            G.Crsf_Use_Negotiated_Baud := Unsigned_8'Mod (Value);
         when Airmode_Start_Throttle_Percent =>
            G.Air_Mode_Activate_Threshold := Unsigned_8'Mod (Value);
         when Rx_Min_Usec =>
            G.Rx_Min_Usec := Unsigned_16'Mod (Value);
         when Rx_Max_Usec =>
            G.Rx_Max_Usec := Unsigned_16'Mod (Value);
         when Serialrx_Halfduplex =>
            G.Half_Duplex := Unsigned_8'Mod (Value);
         when Rx_Uart =>
            G.Rx_Uart := Signed (Unsigned_8'Mod (Value));
         when Msp_Override_Channels_Mask =>
            G.Msp_Override_Channels_Mask := Unsigned_32'Mod (Value);
         when Msp_Override_Failsafe =>
            G.Msp_Override_Failsafe := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Rx_Config;

   procedure Set_Rx_Spi_Config (G : in out Rx_Spi_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Rx_Spi_Protocol | Rx_Spi_Bus | Rx_Spi_Led_Inversion) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Rx_Spi_Protocol =>
            G.Rx_Spi_Protocol := Unsigned_8'Mod (Value);
         when Rx_Spi_Bus =>
            G.Spibus := Unsigned_8'Mod (Value);
         when Rx_Spi_Led_Inversion =>
            G.Led_Inversion := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Rx_Spi_Config;

   procedure Set_Adc_Config (G : in out Adc_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Adc_Device | Adc_Vrefint_Calibration | Adc_Tempsensor_Calibration30 |
       Adc_Tempsensor_Calibration110) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Adc_Device =>
            G.Device := Signed (Unsigned_8'Mod (Value));
         when Adc_Vrefint_Calibration =>
            G.Vref_Int_Calibration := Unsigned_16'Mod (Value);
         when Adc_Tempsensor_Calibration30 =>
            G.Temp_Sensor_Calibration1 := Unsigned_16'Mod (Value);
         when Adc_Tempsensor_Calibration110 =>
            G.Temp_Sensor_Calibration2 := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Adc_Config;

   procedure Set_Pwm_Config (G : in out Pwm_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Input_Filtering_Mode) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Input_Filtering_Mode =>
            G.Input_Filtering_Mode := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Pwm_Config;

   procedure Set_Blackbox_Config (G : in out Blackbox_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Blackbox_Sample_Rate | Blackbox_Device | Blackbox_Disable_Pids | Blackbox_Disable_Rc |
       Blackbox_Disable_Setpoint | Blackbox_Disable_Bat | Blackbox_Disable_Mag | Blackbox_Disable_Alt |
       Blackbox_Disable_Rssi | Blackbox_Disable_Gyro | Blackbox_Disable_Gyrounfilt | Blackbox_Disable_Acc |
       Blackbox_Disable_Attitude | Blackbox_Disable_Debug | Blackbox_Disable_Motors | Blackbox_Disable_Servos |
       Blackbox_Disable_Rpm | Blackbox_Disable_Gps | Blackbox_Disable_Pitot | Blackbox_Mode |
       Blackbox_High_Resolution | Blackbox_Uart | Blackbox_Baud) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Blackbox_Sample_Rate =>
            G.Sample_Rate := Unsigned_8'Mod (Value);
         when Blackbox_Device =>
            G.Device := Unsigned_8'Mod (Value);
         when Blackbox_Disable_Pids =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 0) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 0));
         when Blackbox_Disable_Rc =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 1) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 1));
         when Blackbox_Disable_Setpoint =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 2) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 2));
         when Blackbox_Disable_Bat =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 3) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 3));
         when Blackbox_Disable_Mag =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 4) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 4));
         when Blackbox_Disable_Alt =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 5) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 5));
         when Blackbox_Disable_Rssi =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 6) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 6));
         when Blackbox_Disable_Gyro =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 7) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 7));
         when Blackbox_Disable_Gyrounfilt =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 14) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 14));
         when Blackbox_Disable_Acc =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 9) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 9));
         when Blackbox_Disable_Attitude =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 8) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 8));
         when Blackbox_Disable_Debug =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 10) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 10));
         when Blackbox_Disable_Motors =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 11) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 11));
         when Blackbox_Disable_Servos =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 15) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 15));
         when Blackbox_Disable_Rpm =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 13) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 13));
         when Blackbox_Disable_Gps =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 12) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 12));
         when Blackbox_Disable_Pitot =>
            G.Fields_Disabled_Mask := (if Value /= 0 then G.Fields_Disabled_Mask or Unsigned_32 (2 ** 16) else
               G.Fields_Disabled_Mask and not Unsigned_32 (2 ** 16));
         when Blackbox_Mode =>
            G.Mode := Unsigned_8'Mod (Value);
         when Blackbox_High_Resolution =>
            G.High_Resolution := Unsigned_8'Mod (Value);
         when Blackbox_Uart =>
            G.Blackbox_Uart := Signed (Unsigned_8'Mod (Value));
         when Blackbox_Baud =>
            G.Blackbox_Baud := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Blackbox_Config;

   procedure Set_Motor_Config (G : in out Motor_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Max_Throttle | Min_Command | Motor_Kv | Motor_Idle | Dshot_Burst | Dshot_Bidir | Dshot_Edt
       | Dshot_Bitbang | Dshot_Bitbang_Timer | Use_Unsynced_Pwm | Motor_Pwm_Protocol | Motor_Pwm_Rate |
       Motor_Pwm_Inversion | Motor_Poles | Motor_Output_Reordering) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Max_Throttle =>
            G.Maxthrottle := Unsigned_16'Mod (Value);
         when Min_Command =>
            G.Mincommand := Unsigned_16'Mod (Value);
         when Motor_Kv =>
            G.Kv := Unsigned_16'Mod (Value);
         when Motor_Idle =>
            G.Motor_Idle := Unsigned_16'Mod (Value);
         when Dshot_Burst =>
            G.Dev.Use_Burst_Dshot := Unsigned_8'Mod (Value);
         when Dshot_Bidir =>
            G.Dev.Use_Dshot_Telemetry := Unsigned_8'Mod (Value);
         when Dshot_Edt =>
            G.Dev.Use_Dshot_Edt := Unsigned_8'Mod (Value);
         when Dshot_Bitbang =>
            G.Dev.Use_Dshot_Bitbang := Unsigned_8'Mod (Value);
         when Dshot_Bitbang_Timer =>
            G.Dev.Use_Dshot_Bitbanged_Timer := Unsigned_8'Mod (Value);
         when Use_Unsynced_Pwm =>
            G.Dev.Use_Continuous_Update := Unsigned_8'Mod (Value);
         when Motor_Pwm_Protocol =>
            G.Dev.Motor_Protocol := Unsigned_8'Mod (Value);
         when Motor_Pwm_Rate =>
            G.Dev.Motor_Pwm_Rate := Unsigned_16'Mod (Value);
         when Motor_Pwm_Inversion =>
            G.Dev.Motor_Inversion := Unsigned_8'Mod (Value);
         when Motor_Poles =>
            G.Motor_Pole_Count := Unsigned_8'Mod (Value);
         when Motor_Output_Reordering =>
            G.Dev.Motor_Output_Reordering (Index) := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Motor_Config;

   procedure Set_Throttle_Correction_Config (G : in out Throttle_Correction_Config_Record; S : Setting; Value :
      Integer_64; Index : Natural)
     with Pre => (S in Thr_Corr_Value | Thr_Corr_Angle) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Thr_Corr_Value =>
            G.Throttle_Correction_Value := Unsigned_8'Mod (Value);
         when Thr_Corr_Angle =>
            G.Throttle_Correction_Angle := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Throttle_Correction_Config;

   procedure Set_Failsafe_Config (G : in out Failsafe_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Failsafe_Delay | Failsafe_Landing_Time | Failsafe_Throttle | Failsafe_Switch_Mode |
       Failsafe_Throttle_Low_Delay | Failsafe_Procedure | Failsafe_Recovery_Delay | Failsafe_Stick_Threshold) and
       then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Failsafe_Delay =>
            G.Failsafe_Delay := Unsigned_8'Mod (Value);
         when Failsafe_Landing_Time =>
            G.Failsafe_Landing_Time := Unsigned_8'Mod (Value);
         when Failsafe_Throttle =>
            G.Failsafe_Throttle := Unsigned_16'Mod (Value);
         when Failsafe_Switch_Mode =>
            G.Failsafe_Switch_Mode := Unsigned_8'Mod (Value);
         when Failsafe_Throttle_Low_Delay =>
            G.Failsafe_Throttle_Low_Delay := Unsigned_16'Mod (Value);
         when Failsafe_Procedure =>
            G.Failsafe_Procedure := Unsigned_8'Mod (Value);
         when Failsafe_Recovery_Delay =>
            G.Failsafe_Recovery_Delay := Unsigned_16'Mod (Value);
         when Failsafe_Stick_Threshold =>
            G.Failsafe_Stick_Threshold := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Failsafe_Config;

   procedure Set_Board_Alignment (G : in out Board_Alignment_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Align_Board_Roll | Align_Board_Pitch | Align_Board_Yaw) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Align_Board_Roll =>
            G.Roll_Degrees := Signed ((Unsigned_32'Mod (Integer_64 (G.Roll_Degrees)) and 16#FFFF_0000#) or Unsigned_32
               (Unsigned_16'Mod (Value)));
         when Align_Board_Pitch =>
            G.Pitch_Degrees := Signed ((Unsigned_32'Mod (Integer_64 (G.Pitch_Degrees)) and 16#FFFF_0000#) or
               Unsigned_32 (Unsigned_16'Mod (Value)));
         when Align_Board_Yaw =>
            G.Yaw_Degrees := Signed ((Unsigned_32'Mod (Integer_64 (G.Yaw_Degrees)) and 16#FFFF_0000#) or Unsigned_32
               (Unsigned_16'Mod (Value)));
         when others =>
            null;
      end case;
   end Set_Board_Alignment;

   procedure Set_Gimbal_Config (G : in out Gimbal_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Gimbal_Mode) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Gimbal_Mode =>
            G.Mode := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Gimbal_Config;

   procedure Set_Battery_Profiles_Profile (G : in out Battery_Profile_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Bat_Capacity | Vbat_Max_Cell_Voltage | Vbat_Full_Cell_Voltage | Vbat_Min_Cell_Voltage |
       Vbat_Warning_Cell_Voltage | Cbat_Alert_Percent | Force_Battery_Cell_Count) and then Index < Element_Count
       (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Bat_Capacity =>
            G.Battery_Capacity := Unsigned_16'Mod (Value);
         when Vbat_Max_Cell_Voltage =>
            G.Vbatmaxcellvoltage := Unsigned_16'Mod (Value);
         when Vbat_Full_Cell_Voltage =>
            G.Vbatfullcellvoltage := Unsigned_16'Mod (Value);
         when Vbat_Min_Cell_Voltage =>
            G.Vbatmincellvoltage := Unsigned_16'Mod (Value);
         when Vbat_Warning_Cell_Voltage =>
            G.Vbatwarningcellvoltage := Unsigned_16'Mod (Value);
         when Cbat_Alert_Percent =>
            G.Consumption_Warning_Percentage := Unsigned_8'Mod (Value);
         when Force_Battery_Cell_Count =>
            G.Force_Battery_Cell_Count := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Battery_Profiles_Profile;

   procedure Set_Battery_Config (G : in out Battery_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Vbat_Hysteresis | Current_Meter | Battery_Meter | Vbat_Detect_Cell_Voltage |
       Use_Vbat_Alerts | Use_Cbat_Alerts | Vbat_Cutoff_Percent | Vbat_Display_Lpf_Period | Vbat_Sag_Lpf_Period |
       Ibat_Lpf_Period | Vbat_Duration_For_Warning | Vbat_Duration_For_Critical | Battery_Continue) and then Index
       < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Vbat_Hysteresis =>
            G.Vbathysteresis := Unsigned_8'Mod (Value);
         when Current_Meter =>
            G.Current_Meter_Source := Unsigned_8'Mod (Value);
         when Battery_Meter =>
            G.Voltage_Meter_Source := Unsigned_8'Mod (Value);
         when Vbat_Detect_Cell_Voltage =>
            G.Vbatnotpresentcellvoltage := Unsigned_16'Mod (Value);
         when Use_Vbat_Alerts =>
            G.Use_V_Bat_Alerts := Value mod 256 /= 0;
         when Use_Cbat_Alerts =>
            G.Use_Consumption_Alerts := Value mod 256 /= 0;
         when Vbat_Cutoff_Percent =>
            G.Lvc_Percentage := Unsigned_8'Mod (Value);
         when Vbat_Display_Lpf_Period =>
            G.Vbat_Display_Lpf_Period := Unsigned_8'Mod (Value);
         when Vbat_Sag_Lpf_Period =>
            G.Vbat_Sag_Lpf_Period := Unsigned_8'Mod (Value);
         when Ibat_Lpf_Period =>
            G.Ibat_Lpf_Period := Unsigned_8'Mod (Value);
         when Vbat_Duration_For_Warning =>
            G.Vbat_Duration_For_Warning := Unsigned_8'Mod (Value);
         when Vbat_Duration_For_Critical =>
            G.Vbat_Duration_For_Critical := Unsigned_8'Mod (Value);
         when Battery_Continue =>
            G.Is_Battery_Continue_Enabled := Value mod 256 /= 0;
         when others =>
            null;
      end case;
   end Set_Battery_Config;

   procedure Set_Voltage_Sensor_Adc_Config (G : in out Voltage_Sensor_Adc_Config_Record_List_1; S : Setting; Value :
      Integer_64; Index : Natural)
     with Pre => (S in Vbat_Scale | Vbat_Divider | Vbat_Multiplier) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Vbat_Scale =>
            G (0).Vbatscale := Unsigned_8'Mod (Value);
         when Vbat_Divider =>
            G (0).Vbatresdivval := Unsigned_8'Mod (Value);
         when Vbat_Multiplier =>
            G (0).Vbatresdivmultiplier := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Voltage_Sensor_Adc_Config;

   procedure Set_Current_Sensor_Adc_Config (G : in out Current_Sensor_Adc_Config_Record; S : Setting; Value :
      Integer_64; Index : Natural)
     with Pre => (S in Ibata_Scale | Ibata_Offset) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Ibata_Scale =>
            G.Scale := Signed (Unsigned_16'Mod (Value));
         when Ibata_Offset =>
            G.Offset := Signed (Unsigned_16'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Current_Sensor_Adc_Config;

   procedure Set_Current_Sensor_Virtual_Config (G : in out Current_Sensor_Virtual_Config_Record; S : Setting; Value :
      Integer_64; Index : Natural)
     with Pre => (S in Ibatv_Scale | Ibatv_Offset) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Ibatv_Scale =>
            G.Scale := Signed (Unsigned_16'Mod (Value));
         when Ibatv_Offset =>
            G.Offset := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Current_Sensor_Virtual_Config;

   procedure Set_Beeper_Dev_Config (G : in out Beeper_Dev_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Beeper_Inversion | Beeper_Od | Beeper_Frequency) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Beeper_Inversion =>
            G.Is_Inverted := Unsigned_8'Mod (Value);
         when Beeper_Od =>
            G.Is_Open_Drain := Unsigned_8'Mod (Value);
         when Beeper_Frequency =>
            G.Frequency := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Beeper_Dev_Config;

   procedure Set_Beeper_Config (G : in out Beeper_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Beeper_Dshot_Beacon_Tone) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Beeper_Dshot_Beacon_Tone =>
            G.Dshot_Beacon_Tone := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Beeper_Config;

   procedure Set_Mixer_Config (G : in out Mixer_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Yaw_Motors_Reversed | Mixer_Type | Crashflip_Motor_Percent | Crashflip_Rate |
       Crashflip_Auto_Rearm | Rpm_Limit | Rpm_Limit_P | Rpm_Limit_I | Rpm_Limit_D | Rpm_Limit_Value) and then Index
       < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Yaw_Motors_Reversed =>
            G.Yaw_Motors_Reversed := Value mod 256 /= 0;
         when Mixer_Type =>
            G.Mixer_Type := Unsigned_8'Mod (Value);
         when Crashflip_Motor_Percent =>
            G.Crashflip_Motor_Percent := Unsigned_8'Mod (Value);
         when Crashflip_Rate =>
            G.Crashflip_Rate := Unsigned_8'Mod (Value);
         when Crashflip_Auto_Rearm =>
            G.Crashflip_Auto_Rearm := Value mod 256 /= 0;
         when Rpm_Limit =>
            G.Rpm_Limit := Value mod 256 /= 0;
         when Rpm_Limit_P =>
            G.Rpm_Limit_P := Unsigned_16'Mod (Value);
         when Rpm_Limit_I =>
            G.Rpm_Limit_I := Unsigned_16'Mod (Value);
         when Rpm_Limit_D =>
            G.Rpm_Limit_D := Unsigned_16'Mod (Value);
         when Rpm_Limit_Value =>
            G.Rpm_Limit_Value := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Mixer_Config;

   procedure Set_Flight3_D_Config (G : in out Flight3_D_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Three_D_Deadband_Low | Three_D_Deadband_High | Three_D_Neutral | Three_D_Deadband_Throttle
       | Three_D_Limit_Low | Three_D_Limit_High | Three_D_Switched_Mode) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Three_D_Deadband_Low =>
            G.Deadband3d_Low := Unsigned_16'Mod (Value);
         when Three_D_Deadband_High =>
            G.Deadband3d_High := Unsigned_16'Mod (Value);
         when Three_D_Neutral =>
            G.Neutral3d := Unsigned_16'Mod (Value);
         when Three_D_Deadband_Throttle =>
            G.Deadband3d_Throttle := Unsigned_16'Mod (Value);
         when Three_D_Limit_Low =>
            G.Limit3d_Low := Unsigned_16'Mod (Value);
         when Three_D_Limit_High =>
            G.Limit3d_High := Unsigned_16'Mod (Value);
         when Three_D_Switched_Mode =>
            G.Switched_Mode3d := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Flight3_D_Config;

   procedure Set_Servo_Config (G : in out Servo_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Servo_Center_Pulse | Servo_Pwm_Rate | Servo_Lowpass_Hz | Tri_Unarmed_Servo |
       Channel_Forwarding_Start) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Servo_Center_Pulse =>
            G.Dev.Servo_Center_Pulse := Unsigned_16'Mod (Value);
         when Servo_Pwm_Rate =>
            G.Dev.Servo_Pwm_Rate := Unsigned_16'Mod (Value);
         when Servo_Lowpass_Hz =>
            G.Servo_Lowpass_Freq := Unsigned_16'Mod (Value);
         when Tri_Unarmed_Servo =>
            G.Tri_Unarmed_Servo := Unsigned_8'Mod (Value);
         when Channel_Forwarding_Start =>
            G.Channel_Forwarding_Start_Channel := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Servo_Config;

   procedure Set_Control_Rate_Profiles_Profile (G : in out Control_Rate_Config_Record; S : Setting; Value :
      Integer_64; Index : Natural)
     with Pre => (S in Thr_Mid | Thr_Expo | Thr_Hover | Rates_Type | Quickrates_Rc_Expo | Roll_Rc_Rate |
       Pitch_Rc_Rate | Yaw_Rc_Rate | Roll_Expo | Pitch_Expo | Yaw_Expo | Roll_Srate | Pitch_Srate | Yaw_Srate |
       Throttle_Limit_Type | Throttle_Limit_Percent | Roll_Rate_Limit | Pitch_Rate_Limit | Yaw_Rate_Limit) and then
       Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Thr_Mid =>
            G.Thr_Mid8 := Unsigned_8'Mod (Value);
         when Thr_Expo =>
            G.Thr_Expo8 := Unsigned_8'Mod (Value);
         when Thr_Hover =>
            G.Thr_Hover8 := Unsigned_8'Mod (Value);
         when Rates_Type =>
            G.Rates_Type := Unsigned_8'Mod (Value);
         when Quickrates_Rc_Expo =>
            G.Quick_Rates_Rc_Expo := Unsigned_8'Mod (Value);
         when Roll_Rc_Rate =>
            G.Rc_Rates (0) := Unsigned_8'Mod (Value);
         when Pitch_Rc_Rate =>
            G.Rc_Rates (1) := Unsigned_8'Mod (Value);
         when Yaw_Rc_Rate =>
            G.Rc_Rates (2) := Unsigned_8'Mod (Value);
         when Roll_Expo =>
            G.Rc_Expo (0) := Unsigned_8'Mod (Value);
         when Pitch_Expo =>
            G.Rc_Expo (1) := Unsigned_8'Mod (Value);
         when Yaw_Expo =>
            G.Rc_Expo (2) := Unsigned_8'Mod (Value);
         when Roll_Srate =>
            G.Rates (0) := Unsigned_8'Mod (Value);
         when Pitch_Srate =>
            G.Rates (1) := Unsigned_8'Mod (Value);
         when Yaw_Srate =>
            G.Rates (2) := Unsigned_8'Mod (Value);
         when Throttle_Limit_Type =>
            G.Throttle_Limit_Type := Unsigned_8'Mod (Value);
         when Throttle_Limit_Percent =>
            G.Throttle_Limit_Percent := Unsigned_8'Mod (Value);
         when Roll_Rate_Limit =>
            G.Rate_Limit (0) := Unsigned_16'Mod (Value);
         when Pitch_Rate_Limit =>
            G.Rate_Limit (1) := Unsigned_16'Mod (Value);
         when Yaw_Rate_Limit =>
            G.Rate_Limit (2) := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Control_Rate_Profiles_Profile;

   procedure Set_Serial_Config (G : in out Serial_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Reboot_Character | Serial_Update_Rate_Hz) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Reboot_Character =>
            G.Reboot_Character := Unsigned_8'Mod (Value);
         when Serial_Update_Rate_Hz =>
            G.Serial_Update_Rate_Hz := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Serial_Config;

   procedure Set_Imu_Config (G : in out Imu_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Imu_Dcm_Kp | Imu_Dcm_Ki | Small_Angle | Imu_Process_Denom | Mag_Declination) and then
       Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Imu_Dcm_Kp =>
            G.Imu_Dcm_Kp := Unsigned_16'Mod (Value);
         when Imu_Dcm_Ki =>
            G.Imu_Dcm_Ki := Unsigned_16'Mod (Value);
         when Small_Angle =>
            G.Small_Angle := Unsigned_8'Mod (Value);
         when Imu_Process_Denom =>
            G.Imu_Process_Denom := Unsigned_8'Mod (Value);
         when Mag_Declination =>
            G.Mag_Declination := Signed (Unsigned_16'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Imu_Config;

   procedure Set_Arming_Config (G : in out Arming_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Auto_Disarm_Delay | Gyro_Cal_On_First_Arm | Prearm_Allow_Rearm) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Auto_Disarm_Delay =>
            G.Auto_Disarm_Delay := Unsigned_8'Mod (Value);
         when Gyro_Cal_On_First_Arm =>
            G.Gyro_Cal_On_First_Arm := Unsigned_8'Mod (Value);
         when Prearm_Allow_Rearm =>
            G.Prearm_Allow_Rearm := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Arming_Config;

   procedure Set_Gps_Config (G : in out Gps_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Gps_Provider | Gps_Sbas_Mode | Gps_Auto_Config | Gps_Auto_Baud | Gps_Ublox_Acquire_Model |
       Gps_Ublox_Flight_Model | Gps_Update_Rate_Hz | Gps_Ublox_Utc_Standard | Gps_Ublox_Use_Galileo |
       Gps_Ublox_Enable_Ana | Gps_Set_Home_Point_Once | Gps_Use_3d_Speed | Gps_Sbas_Integrity | Gps_Uart |
       Gps_Baud) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Gps_Provider =>
            G.Provider := Unsigned_8'Mod (Value);
         when Gps_Sbas_Mode =>
            G.Sbas_Mode := Unsigned_8'Mod (Value);
         when Gps_Auto_Config =>
            G.Auto_Config := Unsigned_8'Mod (Value);
         when Gps_Auto_Baud =>
            G.Auto_Baud := Unsigned_8'Mod (Value);
         when Gps_Ublox_Acquire_Model =>
            G.Gps_Ublox_Acquire_Model := Unsigned_8'Mod (Value);
         when Gps_Ublox_Flight_Model =>
            G.Gps_Ublox_Flight_Model := Unsigned_8'Mod (Value);
         when Gps_Update_Rate_Hz =>
            G.Gps_Update_Rate_Hz := Unsigned_8'Mod (Value);
         when Gps_Ublox_Utc_Standard =>
            G.Gps_Ublox_Utc_Standard := Unsigned_8'Mod (Value);
         when Gps_Ublox_Use_Galileo =>
            G.Gps_Ublox_Use_Galileo := Value mod 256 /= 0;
         when Gps_Ublox_Enable_Ana =>
            G.Gps_Ublox_Enable_Ana := Value mod 256 /= 0;
         when Gps_Set_Home_Point_Once =>
            G.Gps_Set_Home_Point_Once := Value mod 256 /= 0;
         when Gps_Use_3d_Speed =>
            G.Gps_Use_3d_Speed := Value mod 256 /= 0;
         when Gps_Sbas_Integrity =>
            G.Sbas_Integrity := Value mod 256 /= 0;
         when Gps_Uart =>
            G.Gps_Uart := Signed (Unsigned_8'Mod (Value));
         when Gps_Baud =>
            G.Gps_Baud := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Gps_Config;

   procedure Set_Gps_Rescue_Config (G : in out Gps_Rescue_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Gps_Rescue_Min_Start_Dist | Gps_Rescue_Alt_Mode | Gps_Rescue_Initial_Climb |
       Gps_Rescue_Ascend_Rate | Gps_Rescue_Return_Alt | Gps_Rescue_Ground_Speed | Gps_Rescue_Descent_Dist |
       Gps_Rescue_Descend_Rate | Gps_Rescue_Sanity_Checks | Gps_Rescue_Min_Sats |
       Gps_Rescue_Allow_Arming_Without_Fix | Gps_Rescue_Yaw_P) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Gps_Rescue_Min_Start_Dist =>
            G.Min_Start_Dist_M := Unsigned_16'Mod (Value);
         when Gps_Rescue_Alt_Mode =>
            G.Altitude_Mode := Unsigned_8'Mod (Value);
         when Gps_Rescue_Initial_Climb =>
            G.Initial_Climb_M := Unsigned_16'Mod (Value);
         when Gps_Rescue_Ascend_Rate =>
            G.Ascend_Rate := Unsigned_16'Mod (Value);
         when Gps_Rescue_Return_Alt =>
            G.Return_Altitude_M := Unsigned_16'Mod (Value);
         when Gps_Rescue_Ground_Speed =>
            G.Ground_Speed_Cm_S := Unsigned_16'Mod (Value);
         when Gps_Rescue_Descent_Dist =>
            G.Descent_Distance_M := Unsigned_16'Mod (Value);
         when Gps_Rescue_Descend_Rate =>
            G.Descend_Rate := Unsigned_16'Mod (Value);
         when Gps_Rescue_Sanity_Checks =>
            G.Sanity_Checks := Unsigned_8'Mod (Value);
         when Gps_Rescue_Min_Sats =>
            G.Min_Sats := Unsigned_8'Mod (Value);
         when Gps_Rescue_Allow_Arming_Without_Fix =>
            G.Allow_Arming_Without_Fix := Unsigned_8'Mod (Value);
         when Gps_Rescue_Yaw_P =>
            G.Yaw_P := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Gps_Rescue_Config;

   procedure Set_Gps_Lap_Timer_Config (G : in out Gps_Lap_Timer_Config_Record; S : Setting; Value : Integer_64; Index
      : Natural)
     with Pre => (S in Gps_Lap_Timer_Gate_Lat | Gps_Lap_Timer_Gate_Lon | Gps_Lap_Timer_Min_Lap_Time_S |
       Gps_Lap_Timer_Gate_Tolerance_M) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Gps_Lap_Timer_Gate_Lat =>
            G.Gate_Lat := Signed (Unsigned_32'Mod (Value));
         when Gps_Lap_Timer_Gate_Lon =>
            G.Gate_Lon := Signed (Unsigned_32'Mod (Value));
         when Gps_Lap_Timer_Min_Lap_Time_S =>
            G.Minimum_Lap_Time_Seconds := Unsigned_16'Mod (Value);
         when Gps_Lap_Timer_Gate_Tolerance_M =>
            G.Gate_Tolerance_M := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Gps_Lap_Timer_Config;

   procedure Set_Rc_Controls_Config (G : in out Rc_Controls_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Deadband | Yaw_Deadband | Yaw_Control_Reversed) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Deadband =>
            G.Deadband := Unsigned_8'Mod (Value);
         when Yaw_Deadband =>
            G.Yaw_Deadband := Unsigned_8'Mod (Value);
         when Yaw_Control_Reversed =>
            G.Yaw_Control_Reversed := Value mod 256 /= 0;
         when others =>
            null;
      end case;
   end Set_Rc_Controls_Config;

   procedure Set_Alt_Hold_Config (G : in out Alt_Hold_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Alt_Hold_Climb_Rate | Alt_Hold_Deadband) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Alt_Hold_Climb_Rate =>
            G.Climb_Rate := Unsigned_8'Mod (Value);
         when Alt_Hold_Deadband =>
            G.Deadband := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Alt_Hold_Config;

   procedure Set_Pos_Hold_Config (G : in out Pos_Hold_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Pos_Hold_Deadband | Poshold_Position_Source | Poshold_Opticalflow_Quality_Min |
       Poshold_Opticalflow_Max_Range) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Pos_Hold_Deadband =>
            G.Deadband := Unsigned_8'Mod (Value);
         when Poshold_Position_Source =>
            G.Position_Source := Unsigned_8'Mod (Value);
         when Poshold_Opticalflow_Quality_Min =>
            G.Opticalflow_Quality_Min := Unsigned_8'Mod (Value);
         when Poshold_Opticalflow_Max_Range =>
            G.Opticalflow_Max_Range := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Pos_Hold_Config;

   procedure Set_Pid_Config (G : in out Pid_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Pid_Process_Denom | Runaway_Takeoff_Prevention | Runaway_Takeoff_Deactivate_Delay |
       Runaway_Takeoff_Deactivate_Throttle_Percent) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Pid_Process_Denom =>
            G.Pid_Process_Denom := Unsigned_8'Mod (Value);
         when Runaway_Takeoff_Prevention =>
            G.Runaway_Takeoff_Prevention := Unsigned_8'Mod (Value);
         when Runaway_Takeoff_Deactivate_Delay =>
            G.Runaway_Takeoff_Deactivate_Delay := Unsigned_16'Mod (Value);
         when Runaway_Takeoff_Deactivate_Throttle_Percent =>
            G.Runaway_Takeoff_Deactivate_Throttle := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Pid_Config;

   procedure Set_Pid_Profiles_Profile (G : in out Pid_Profile_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Dterm_Lpf1_Dyn_Min_Hz | Dterm_Lpf1_Dyn_Max_Hz | Dterm_Lpf1_Dyn_Expo | Dterm_Lpf1_Type |
       Dterm_Lpf1_Static_Hz | Dterm_Lpf2_Type | Dterm_Lpf2_Static_Hz | Dterm_Notch_Hz | Dterm_Notch_Cutoff |
       Vbat_Sag_Compensation | Pid_At_Min_Throttle | Anti_Gravity_Gain | Anti_Gravity_Cutoff_Hz |
       Anti_Gravity_P_Gain | Acc_Limit_Yaw | Acc_Limit | Crash_Dthreshold | Crash_Gthreshold |
       Crash_Setpoint_Threshold | Crash_Time | Crash_Delay | Crash_Recovery_Angle | Crash_Recovery_Rate |
       Crash_Limit_Yaw | Crash_Recovery | Iterm_Rotation | Iterm_Relax | Iterm_Relax_Type | Iterm_Relax_Cutoff |
       Iterm_Windup | Pidsum_Limit | Pidsum_Limit_Yaw | Yaw_Lowpass_Hz | Throttle_Boost | Throttle_Boost_Cutoff |
       Acro_Trainer_Angle_Limit | Acro_Trainer_Lookahead_Ms | Acro_Trainer_Debug_Axis | Acro_Trainer_Gain | P_Pitch
       | I_Pitch | D_Pitch | F_Pitch | P_Roll | I_Roll | D_Roll | F_Roll | P_Yaw | I_Yaw | D_Yaw | F_Yaw |
       Angle_P_Gain | Angle_Feedforward | Angle_Feedforward_Smoothing_Ms | Angle_Limit | Angle_Earth_Ref |
       Horizon_Level_Strength | Horizon_Limit_Sticks | Horizon_Limit_Degrees | Horizon_Ignore_Sticks |
       Horizon_Delay_Ms | Chirp_Lag_Freq_Hz | Chirp_Lead_Freq_Hz | Chirp_Amplitude_Roll | Chirp_Amplitude_Pitch |
       Chirp_Amplitude_Yaw | Chirp_Frequency_Start_Deci_Hz | Chirp_Frequency_End_Deci_Hz | Chirp_Time_Seconds |
       Chirp_Repeat | D_Max_Roll | D_Max_Pitch | D_Max_Yaw | D_Max_Gain | D_Max_Advance | Motor_Output_Limit |
       Auto_Profile_Cell_Count | Launch_Control_Mode | Launch_Trigger_Allow_Reset | Launch_Trigger_Throttle_Percent
       | Launch_Angle_Limit | Launch_Control_Gain | Thrust_Linear | Feedforward_Transition | Feedforward_Averaging
       | Feedforward_Smooth_Factor | Feedforward_Jitter_Factor | Feedforward_Boost | Feedforward_Max_Rate_Limit |
       Feedforward_Yaw_Hold_Gain | Feedforward_Yaw_Hold_Time | Dyn_Idle_Min_Rpm | Dyn_Idle_P_Gain | Dyn_Idle_I_Gain
       | Dyn_Idle_D_Gain | Dyn_Idle_Max_Increase | Level_Race_Mode | Simplified_Pids_Mode |
       Simplified_Master_Multiplier | Simplified_I_Gain | Simplified_D_Gain | Simplified_Pi_Gain |
       Simplified_D_Max_Gain | Simplified_Feedforward_Gain | Simplified_Pitch_D_Gain | Simplified_Pitch_Pi_Gain |
       Simplified_Dterm_Filter | Simplified_Dterm_Filter_Multiplier | Tpa_Mode | Tpa_Rate | Tpa_Breakpoint |
       Tpa_Low_Rate | Tpa_Low_Breakpoint | Tpa_Low_Always | Ez_Landing_Threshold | Ez_Landing_Limit |
       Ez_Landing_Speed | Landing_Disarm_Threshold) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Dterm_Lpf1_Dyn_Min_Hz =>
            G.Dterm_Lpf1_Dyn_Min_Hz := Unsigned_16'Mod (Value);
         when Dterm_Lpf1_Dyn_Max_Hz =>
            G.Dterm_Lpf1_Dyn_Max_Hz := Unsigned_16'Mod (Value);
         when Dterm_Lpf1_Dyn_Expo =>
            G.Dterm_Lpf1_Dyn_Expo := Unsigned_8'Mod (Value);
         when Dterm_Lpf1_Type =>
            G.Dterm_Lpf1_Type := Unsigned_8'Mod (Value);
         when Dterm_Lpf1_Static_Hz =>
            G.Dterm_Lpf1_Static_Hz := Unsigned_16'Mod (Value);
         when Dterm_Lpf2_Type =>
            G.Dterm_Lpf2_Type := Unsigned_8'Mod (Value);
         when Dterm_Lpf2_Static_Hz =>
            G.Dterm_Lpf2_Static_Hz := Unsigned_16'Mod (Value);
         when Dterm_Notch_Hz =>
            G.Dterm_Notch_Hz := Unsigned_16'Mod (Value);
         when Dterm_Notch_Cutoff =>
            G.Dterm_Notch_Cutoff := Unsigned_16'Mod (Value);
         when Vbat_Sag_Compensation =>
            G.Vbat_Sag_Compensation := Unsigned_8'Mod (Value);
         when Pid_At_Min_Throttle =>
            G.Pid_At_Min_Throttle := Unsigned_8'Mod (Value);
         when Anti_Gravity_Gain =>
            G.Anti_Gravity_Gain := Unsigned_8'Mod (Value);
         when Anti_Gravity_Cutoff_Hz =>
            G.Anti_Gravity_Cutoff_Hz := Unsigned_8'Mod (Value);
         when Anti_Gravity_P_Gain =>
            G.Anti_Gravity_P_Gain := Unsigned_8'Mod (Value);
         when Acc_Limit_Yaw =>
            G.Yaw_Rate_Accel_Limit := Unsigned_16'Mod (Value);
         when Acc_Limit =>
            G.Rate_Accel_Limit := Unsigned_16'Mod (Value);
         when Crash_Dthreshold =>
            G.Crash_Dthreshold := Unsigned_16'Mod (Value);
         when Crash_Gthreshold =>
            G.Crash_Gthreshold := Unsigned_16'Mod (Value);
         when Crash_Setpoint_Threshold =>
            G.Crash_Setpoint_Threshold := Unsigned_16'Mod (Value);
         when Crash_Time =>
            G.Crash_Time := Unsigned_16'Mod (Value);
         when Crash_Delay =>
            G.Crash_Delay := Unsigned_16'Mod (Value);
         when Crash_Recovery_Angle =>
            G.Crash_Recovery_Angle := Unsigned_8'Mod (Value);
         when Crash_Recovery_Rate =>
            G.Crash_Recovery_Rate := Unsigned_8'Mod (Value);
         when Crash_Limit_Yaw =>
            G.Crash_Limit_Yaw := Unsigned_16'Mod (Value);
         when Crash_Recovery =>
            G.Crash_Recovery := Unsigned_8'Mod (Value);
         when Iterm_Rotation =>
            G.Iterm_Rotation := Unsigned_8'Mod (Value);
         when Iterm_Relax =>
            G.Iterm_Relax := Unsigned_8'Mod (Value);
         when Iterm_Relax_Type =>
            G.Iterm_Relax_Type := Unsigned_8'Mod (Value);
         when Iterm_Relax_Cutoff =>
            G.Iterm_Relax_Cutoff := Unsigned_8'Mod (Value);
         when Iterm_Windup =>
            G.Iterm_Windup := Unsigned_8'Mod (Value);
         when Pidsum_Limit =>
            G.Pid_Sum_Limit := Unsigned_16'Mod (Value);
         when Pidsum_Limit_Yaw =>
            G.Pid_Sum_Limit_Yaw := Unsigned_16'Mod (Value);
         when Yaw_Lowpass_Hz =>
            G.Yaw_Lowpass_Hz := Unsigned_16'Mod (Value);
         when Throttle_Boost =>
            G.Throttle_Boost := Unsigned_8'Mod (Value);
         when Throttle_Boost_Cutoff =>
            G.Throttle_Boost_Cutoff := Unsigned_8'Mod (Value);
         when Acro_Trainer_Angle_Limit =>
            G.Acro_Trainer_Angle_Limit := Unsigned_8'Mod (Value);
         when Acro_Trainer_Lookahead_Ms =>
            G.Acro_Trainer_Lookahead_Ms := Unsigned_16'Mod (Value);
         when Acro_Trainer_Debug_Axis =>
            G.Acro_Trainer_Debug_Axis := Unsigned_8'Mod (Value);
         when Acro_Trainer_Gain =>
            G.Acro_Trainer_Gain := Unsigned_8'Mod (Value);
         when P_Pitch =>
            G.Pid (1).P := Unsigned_8'Mod (Value);
         when I_Pitch =>
            G.Pid (1).I := Unsigned_8'Mod (Value);
         when D_Pitch =>
            G.Pid (1).D := Unsigned_8'Mod (Value);
         when F_Pitch =>
            G.Pid (1).F := Unsigned_16'Mod (Value);
         when P_Roll =>
            G.Pid (0).P := Unsigned_8'Mod (Value);
         when I_Roll =>
            G.Pid (0).I := Unsigned_8'Mod (Value);
         when D_Roll =>
            G.Pid (0).D := Unsigned_8'Mod (Value);
         when F_Roll =>
            G.Pid (0).F := Unsigned_16'Mod (Value);
         when P_Yaw =>
            G.Pid (2).P := Unsigned_8'Mod (Value);
         when I_Yaw =>
            G.Pid (2).I := Unsigned_8'Mod (Value);
         when D_Yaw =>
            G.Pid (2).D := Unsigned_8'Mod (Value);
         when F_Yaw =>
            G.Pid (2).F := Unsigned_16'Mod (Value);
         when Angle_P_Gain =>
            G.Pid (3).P := Unsigned_8'Mod (Value);
         when Angle_Feedforward =>
            G.Pid (3).F := (G.Pid (3).F and 16#FF00#) or Unsigned_16 (Unsigned_8'Mod (Value));
         when Angle_Feedforward_Smoothing_Ms =>
            G.Angle_Feedforward_Smoothing_Ms := Unsigned_8'Mod (Value);
         when Angle_Limit =>
            G.Angle_Limit := Unsigned_8'Mod (Value);
         when Angle_Earth_Ref =>
            G.Angle_Earth_Ref := Unsigned_8'Mod (Value);
         when Horizon_Level_Strength =>
            G.Pid (3).I := Unsigned_8'Mod (Value);
         when Horizon_Limit_Sticks =>
            G.Pid (3).D := Unsigned_8'Mod (Value);
         when Horizon_Limit_Degrees =>
            G.Horizon_Limit_Degrees := Unsigned_8'Mod (Value);
         when Horizon_Ignore_Sticks =>
            G.Horizon_Ignore_Sticks := Unsigned_8'Mod (Value);
         when Horizon_Delay_Ms =>
            G.Horizon_Delay_Ms := Unsigned_16'Mod (Value);
         when Chirp_Lag_Freq_Hz =>
            G.Chirp_Lag_Freq_Hz := Unsigned_8'Mod (Value);
         when Chirp_Lead_Freq_Hz =>
            G.Chirp_Lead_Freq_Hz := Unsigned_8'Mod (Value);
         when Chirp_Amplitude_Roll =>
            G.Chirp_Amplitude_Roll := Unsigned_16'Mod (Value);
         when Chirp_Amplitude_Pitch =>
            G.Chirp_Amplitude_Pitch := Unsigned_16'Mod (Value);
         when Chirp_Amplitude_Yaw =>
            G.Chirp_Amplitude_Yaw := Unsigned_16'Mod (Value);
         when Chirp_Frequency_Start_Deci_Hz =>
            G.Chirp_Frequency_Start_Deci_Hz := Unsigned_16'Mod (Value);
         when Chirp_Frequency_End_Deci_Hz =>
            G.Chirp_Frequency_End_Deci_Hz := Unsigned_16'Mod (Value);
         when Chirp_Time_Seconds =>
            G.Chirp_Time_Seconds := Unsigned_8'Mod (Value);
         when Chirp_Repeat =>
            G.Chirp_Repeat := Unsigned_8'Mod (Value);
         when D_Max_Roll =>
            G.D_Max (0) := Unsigned_8'Mod (Value);
         when D_Max_Pitch =>
            G.D_Max (1) := Unsigned_8'Mod (Value);
         when D_Max_Yaw =>
            G.D_Max (2) := Unsigned_8'Mod (Value);
         when D_Max_Gain =>
            G.D_Max_Gain := Unsigned_8'Mod (Value);
         when D_Max_Advance =>
            G.D_Max_Advance := Unsigned_8'Mod (Value);
         when Motor_Output_Limit =>
            G.Motor_Output_Limit := Unsigned_8'Mod (Value);
         when Auto_Profile_Cell_Count =>
            G.Auto_Profile_Cell_Count := Signed (Unsigned_8'Mod (Value));
         when Launch_Control_Mode =>
            G.Launch_Control_Mode := Unsigned_8'Mod (Value);
         when Launch_Trigger_Allow_Reset =>
            G.Launch_Control_Allow_Trigger_Reset := Unsigned_8'Mod (Value);
         when Launch_Trigger_Throttle_Percent =>
            G.Launch_Control_Throttle_Percent := Unsigned_8'Mod (Value);
         when Launch_Angle_Limit =>
            G.Launch_Control_Angle_Limit := Unsigned_8'Mod (Value);
         when Launch_Control_Gain =>
            G.Launch_Control_Gain := Unsigned_8'Mod (Value);
         when Thrust_Linear =>
            G.Thrust_Linearization := Unsigned_8'Mod (Value);
         when Feedforward_Transition =>
            G.Feedforward_Transition := Unsigned_8'Mod (Value);
         when Feedforward_Averaging =>
            G.Feedforward_Averaging := Unsigned_8'Mod (Value);
         when Feedforward_Smooth_Factor =>
            G.Feedforward_Smooth_Factor := Unsigned_8'Mod (Value);
         when Feedforward_Jitter_Factor =>
            G.Feedforward_Jitter_Factor := Unsigned_8'Mod (Value);
         when Feedforward_Boost =>
            G.Feedforward_Boost := Unsigned_8'Mod (Value);
         when Feedforward_Max_Rate_Limit =>
            G.Feedforward_Max_Rate_Limit := Unsigned_8'Mod (Value);
         when Feedforward_Yaw_Hold_Gain =>
            G.Feedforward_Yaw_Hold_Gain := Unsigned_8'Mod (Value);
         when Feedforward_Yaw_Hold_Time =>
            G.Feedforward_Yaw_Hold_Time := Unsigned_8'Mod (Value);
         when Dyn_Idle_Min_Rpm =>
            G.Dyn_Idle_Min_Rpm := Unsigned_8'Mod (Value);
         when Dyn_Idle_P_Gain =>
            G.Dyn_Idle_P_Gain := Unsigned_8'Mod (Value);
         when Dyn_Idle_I_Gain =>
            G.Dyn_Idle_I_Gain := Unsigned_8'Mod (Value);
         when Dyn_Idle_D_Gain =>
            G.Dyn_Idle_D_Gain := Unsigned_8'Mod (Value);
         when Dyn_Idle_Max_Increase =>
            G.Dyn_Idle_Max_Increase := Unsigned_8'Mod (Value);
         when Level_Race_Mode =>
            G.Level_Race_Mode := Unsigned_8'Mod (Value);
         when Simplified_Pids_Mode =>
            G.Simplified_Pids_Mode := Unsigned_8'Mod (Value);
         when Simplified_Master_Multiplier =>
            G.Simplified_Master_Multiplier := Unsigned_8'Mod (Value);
         when Simplified_I_Gain =>
            G.Simplified_I_Gain := Unsigned_8'Mod (Value);
         when Simplified_D_Gain =>
            G.Simplified_D_Gain := Unsigned_8'Mod (Value);
         when Simplified_Pi_Gain =>
            G.Simplified_Pi_Gain := Unsigned_8'Mod (Value);
         when Simplified_D_Max_Gain =>
            G.Simplified_D_Max_Gain := Unsigned_8'Mod (Value);
         when Simplified_Feedforward_Gain =>
            G.Simplified_Feedforward_Gain := Unsigned_8'Mod (Value);
         when Simplified_Pitch_D_Gain =>
            G.Simplified_Roll_Pitch_Ratio := Unsigned_8'Mod (Value);
         when Simplified_Pitch_Pi_Gain =>
            G.Simplified_Pitch_Pi_Gain := Unsigned_8'Mod (Value);
         when Simplified_Dterm_Filter =>
            G.Simplified_Dterm_Filter := Unsigned_8'Mod (Value);
         when Simplified_Dterm_Filter_Multiplier =>
            G.Simplified_Dterm_Filter_Multiplier := Unsigned_8'Mod (Value);
         when Tpa_Mode =>
            G.Tpa_Mode := Unsigned_8'Mod (Value);
         when Tpa_Rate =>
            G.Tpa_Rate := Unsigned_8'Mod (Value);
         when Tpa_Breakpoint =>
            G.Tpa_Breakpoint := Unsigned_16'Mod (Value);
         when Tpa_Low_Rate =>
            G.Tpa_Low_Rate := Signed (Unsigned_8'Mod (Value));
         when Tpa_Low_Breakpoint =>
            G.Tpa_Low_Breakpoint := Unsigned_16'Mod (Value);
         when Tpa_Low_Always =>
            G.Tpa_Low_Always := Unsigned_8'Mod (Value);
         when Ez_Landing_Threshold =>
            G.Ez_Landing_Threshold := Unsigned_8'Mod (Value);
         when Ez_Landing_Limit =>
            G.Ez_Landing_Limit := Unsigned_8'Mod (Value);
         when Ez_Landing_Speed =>
            G.Ez_Landing_Speed := Unsigned_8'Mod (Value);
         when Landing_Disarm_Threshold =>
            G.Landing_Disarm_Threshold := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Pid_Profiles_Profile;

   procedure Set_Telemetry_Config (G : in out Telemetry_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Tlm_Inverted | Tlm_Halfduplex | Telemetry_1_Protocol | Telemetry_1_Uart | Telemetry_1_Baud
       | Telemetry_2_Protocol | Telemetry_2_Uart | Telemetry_2_Baud | Telemetry_3_Protocol | Telemetry_3_Uart |
       Telemetry_3_Baud | Crsf_Tlm_Accgyro | Frsky_Default_Lat | Frsky_Default_Long | Frsky_Gps_Format | Frsky_Unit
       | Frsky_Vfas_Precision | Hott_Alarm_Int | Pid_In_Tlm | Report_Cell_Voltage | Ibus_Sensor |
       Mavlink_Mah_As_Heading_Divisor | Mavlink_Min_Txbuff | Mavlink_Ext_Status_Rate | Mavlink_Rc_Chan_Rate |
       Mavlink_Pos_Rate | Mavlink_Extra1_Rate | Mavlink_Extra2_Rate | Mavlink_Extra3_Rate |
       Telemetry_Disabled_Voltage | Telemetry_Disabled_Current | Telemetry_Disabled_Fuel | Telemetry_Disabled_Mode
       | Telemetry_Disabled_Acc_X | Telemetry_Disabled_Acc_Y | Telemetry_Disabled_Acc_Z | Telemetry_Disabled_Pitch
       | Telemetry_Disabled_Roll | Telemetry_Disabled_Heading | Telemetry_Disabled_Altitude |
       Telemetry_Disabled_Vario | Telemetry_Disabled_Lat_Long | Telemetry_Disabled_Ground_Speed |
       Telemetry_Disabled_Distance | Telemetry_Disabled_Esc_Current | Telemetry_Disabled_Esc_Voltage |
       Telemetry_Disabled_Esc_Rpm | Telemetry_Disabled_Esc_Temperature | Telemetry_Disabled_Temperature |
       Telemetry_Disabled_Cap_Used) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Tlm_Inverted =>
            G.Telemetry_Inverted := Unsigned_8'Mod (Value);
         when Tlm_Halfduplex =>
            G.Half_Duplex := Unsigned_8'Mod (Value);
         when Telemetry_1_Protocol =>
            G.Providers (0).Protocol := Unsigned_8'Mod (Value);
         when Telemetry_1_Uart =>
            G.Providers (0).Uart := Signed (Unsigned_8'Mod (Value));
         when Telemetry_1_Baud =>
            G.Providers (0).Baud := Unsigned_8'Mod (Value);
         when Telemetry_2_Protocol =>
            G.Providers (1).Protocol := Unsigned_8'Mod (Value);
         when Telemetry_2_Uart =>
            G.Providers (1).Uart := Signed (Unsigned_8'Mod (Value));
         when Telemetry_2_Baud =>
            G.Providers (1).Baud := Unsigned_8'Mod (Value);
         when Telemetry_3_Protocol =>
            G.Providers (2).Protocol := Unsigned_8'Mod (Value);
         when Telemetry_3_Uart =>
            G.Providers (2).Uart := Signed (Unsigned_8'Mod (Value));
         when Telemetry_3_Baud =>
            G.Providers (2).Baud := Unsigned_8'Mod (Value);
         when Crsf_Tlm_Accgyro =>
            G.Crsf_Tlm_Accgyro := Unsigned_8'Mod (Value);
         when Frsky_Default_Lat =>
            G.Gps_No_Fix_Latitude := Signed (Unsigned_16'Mod (Value));
         when Frsky_Default_Long =>
            G.Gps_No_Fix_Longitude := Signed (Unsigned_16'Mod (Value));
         when Frsky_Gps_Format =>
            G.Frsky_Coordinate_Format := Unsigned_8'Mod (Value);
         when Frsky_Unit =>
            G.Frsky_Unit := Unsigned_8'Mod (Value);
         when Frsky_Vfas_Precision =>
            G.Frsky_Vfas_Precision := Unsigned_8'Mod (Value);
         when Hott_Alarm_Int =>
            G.Hott_Alarm_Sound_Interval := Unsigned_8'Mod (Value);
         when Pid_In_Tlm =>
            G.Pid_Values_As_Telemetry := Unsigned_8'Mod (Value);
         when Report_Cell_Voltage =>
            G.Report_Cell_Voltage := Unsigned_8'Mod (Value);
         when Ibus_Sensor =>
            G.Flysky_Sensors (Index) := Unsigned_8'Mod (Value);
         when Mavlink_Mah_As_Heading_Divisor =>
            G.Mavlink_Mah_As_Heading_Divisor := Unsigned_16'Mod (Value);
         when Mavlink_Min_Txbuff =>
            G.Mavlink_Min_Txbuff := Unsigned_8'Mod (Value);
         when Mavlink_Ext_Status_Rate =>
            G.Mavlink_Extended_Status_Rate := Unsigned_8'Mod (Value);
         when Mavlink_Rc_Chan_Rate =>
            G.Mavlink_Rc_Channels_Rate := Unsigned_8'Mod (Value);
         when Mavlink_Pos_Rate =>
            G.Mavlink_Position_Rate := Unsigned_8'Mod (Value);
         when Mavlink_Extra1_Rate =>
            G.Mavlink_Extra1_Rate := Unsigned_8'Mod (Value);
         when Mavlink_Extra2_Rate =>
            G.Mavlink_Extra2_Rate := Unsigned_8'Mod (Value);
         when Mavlink_Extra3_Rate =>
            G.Mavlink_Extra3_Rate := Unsigned_8'Mod (Value);
         when Telemetry_Disabled_Voltage =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 0) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 0));
         when Telemetry_Disabled_Current =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 1) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 1));
         when Telemetry_Disabled_Fuel =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 2) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 2));
         when Telemetry_Disabled_Mode =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 3) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 3));
         when Telemetry_Disabled_Acc_X =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 4) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 4));
         when Telemetry_Disabled_Acc_Y =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 5) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 5));
         when Telemetry_Disabled_Acc_Z =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 6) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 6));
         when Telemetry_Disabled_Pitch =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 7) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 7));
         when Telemetry_Disabled_Roll =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 8) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 8));
         when Telemetry_Disabled_Heading =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 9) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 9));
         when Telemetry_Disabled_Altitude =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 10) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 10));
         when Telemetry_Disabled_Vario =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 11) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 11));
         when Telemetry_Disabled_Lat_Long =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 12) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 12));
         when Telemetry_Disabled_Ground_Speed =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 13) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 13));
         when Telemetry_Disabled_Distance =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 14) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 14));
         when Telemetry_Disabled_Esc_Current =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 15) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 15));
         when Telemetry_Disabled_Esc_Voltage =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 16) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 16));
         when Telemetry_Disabled_Esc_Rpm =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 17) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 17));
         when Telemetry_Disabled_Esc_Temperature =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 18) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 18));
         when Telemetry_Disabled_Temperature =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 19) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 19));
         when Telemetry_Disabled_Cap_Used =>
            G.Disabled_Sensors := (if Value /= 0 then G.Disabled_Sensors or Unsigned_32 (2 ** 20) else
               G.Disabled_Sensors and not Unsigned_32 (2 ** 20));
         when others =>
            null;
      end case;
   end Set_Telemetry_Config;

   procedure Set_Led_Strip_Config (G : in out Led_Strip_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Ledstrip_Visual_Beeper | Ledstrip_Visual_Beeper_Color | Ledstrip_Grb_Rgb |
       Ledstrip_Profile | Ledstrip_Race_Color | Ledstrip_Beacon_Color | Ledstrip_Beacon_Period_Ms |
       Ledstrip_Beacon_Percent | Ledstrip_Beacon_Armed_Only | Ledstrip_Brightness | Ledstrip_Rainbow_Delta |
       Ledstrip_Rainbow_Freq) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Ledstrip_Visual_Beeper =>
            G.Ledstrip_Visual_Beeper := Unsigned_8'Mod (Value);
         when Ledstrip_Visual_Beeper_Color =>
            G.Ledstrip_Visual_Beeper_Color := Unsigned_8'Mod (Value);
         when Ledstrip_Grb_Rgb =>
            G.Ledstrip_Grb_Rgb := Unsigned_8'Mod (Value);
         when Ledstrip_Profile =>
            G.Ledstrip_Profile := Unsigned_8'Mod (Value);
         when Ledstrip_Race_Color =>
            G.Ledstrip_Race_Color := Unsigned_8'Mod (Value);
         when Ledstrip_Beacon_Color =>
            G.Ledstrip_Beacon_Color := Unsigned_8'Mod (Value);
         when Ledstrip_Beacon_Period_Ms =>
            G.Ledstrip_Beacon_Period_Ms := Unsigned_16'Mod (Value);
         when Ledstrip_Beacon_Percent =>
            G.Ledstrip_Beacon_Percent := Unsigned_8'Mod (Value);
         when Ledstrip_Beacon_Armed_Only =>
            G.Ledstrip_Beacon_Armed_Only := Unsigned_8'Mod (Value);
         when Ledstrip_Brightness =>
            G.Ledstrip_Brightness := Unsigned_8'Mod (Value);
         when Ledstrip_Rainbow_Delta =>
            G.Ledstrip_Rainbow_Delta := Unsigned_16'Mod (Value);
         when Ledstrip_Rainbow_Freq =>
            G.Ledstrip_Rainbow_Freq := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Led_Strip_Config;

   procedure Set_Transponder_Config (G : in out Transponder_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Transponder_Provider | Transponder_Data) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Transponder_Provider =>
            G.Provider := Unsigned_8'Mod (Value);
         when Transponder_Data =>
            G.Data (Index) := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Transponder_Config;

   procedure Set_Sdcard_Config (G : in out Sdcard_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Sdcard_Detect_Inverted | Sdcard_Mode) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Sdcard_Detect_Inverted =>
            G.Card_Detect_Inverted := Unsigned_8'Mod (Value);
         when Sdcard_Mode =>
            G.Mode := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Sdcard_Config;

   procedure Set_Osd_Config (G : in out Osd_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Osd_Units | Osd_Warn_Bitmask | Osd_Rssi_Alarm | Osd_Link_Quality_Alarm |
       Osd_Rssi_Dbm_Alarm | Osd_Rsnr_Alarm | Osd_Cap_Alarm | Osd_Alt_Alarm | Osd_Distance_Alarm |
       Osd_Esc_Temp_Alarm | Osd_Esc_Rpm_Alarm | Osd_Esc_Current_Alarm | Osd_Core_Temp_Alarm | Osd_Ah_Max_Pit |
       Osd_Ah_Max_Rol | Osd_Ah_Invert | Osd_Logo_On_Arming | Osd_Logo_On_Arming_Duration | Osd_Arming_Logo |
       Osd_Use_Quick_Menu | Osd_Show_Spec_Prearm | Osd_Tim1 | Osd_Tim2 | Osd_Stick_Overlay_Radio_Mode |
       Osd_Stat_Bitmask | Osd_Profile | Osd_Gps_Sats_Show_Pdop | Osd_Displayport_Device | Osd_Uart | Osd_Rcchannels
       | Osd_Camera_Frame_Width | Osd_Camera_Frame_Height | Osd_Stat_Avg_Cell_Value | Osd_Framerate_Hz |
       Osd_Menu_Background | Osd_Aux_Channel | Osd_Aux_Scale | Osd_Aux_Symbol | Osd_Craftname_Msgs |
       Osd_Custom_Text_Uart | Osd_Custom_Text_Baud) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Osd_Units =>
            G.Units := Unsigned_8'Mod (Value);
         when Osd_Warn_Bitmask =>
            G.Enabled_Warnings := Unsigned_32'Mod (Value);
         when Osd_Rssi_Alarm =>
            G.Rssi_Alarm := Unsigned_8'Mod (Value);
         when Osd_Link_Quality_Alarm =>
            G.Link_Quality_Alarm := Unsigned_16'Mod (Value);
         when Osd_Rssi_Dbm_Alarm =>
            G.Rssi_Dbm_Alarm := Signed (Unsigned_16'Mod (Value));
         when Osd_Rsnr_Alarm =>
            G.Rsnr_Alarm := Signed (Unsigned_16'Mod (Value));
         when Osd_Cap_Alarm =>
            G.Cap_Alarm := Unsigned_16'Mod (Value);
         when Osd_Alt_Alarm =>
            G.Alt_Alarm := Unsigned_16'Mod (Value);
         when Osd_Distance_Alarm =>
            G.Distance_Alarm := Unsigned_16'Mod (Value);
         when Osd_Esc_Temp_Alarm =>
            G.Esc_Temp_Alarm := Unsigned_8'Mod (Value);
         when Osd_Esc_Rpm_Alarm =>
            G.Esc_Rpm_Alarm := Signed (Unsigned_16'Mod (Value));
         when Osd_Esc_Current_Alarm =>
            G.Esc_Current_Alarm := Signed (Unsigned_16'Mod (Value));
         when Osd_Core_Temp_Alarm =>
            G.Core_Temp_Alarm := Unsigned_8'Mod (Value);
         when Osd_Ah_Max_Pit =>
            G.Ah_Max_Pitch := Unsigned_8'Mod (Value);
         when Osd_Ah_Max_Rol =>
            G.Ah_Max_Roll := Unsigned_8'Mod (Value);
         when Osd_Ah_Invert =>
            G.Ah_Invert := Unsigned_8'Mod (Value);
         when Osd_Logo_On_Arming =>
            G.Logo_On_Arming := Unsigned_8'Mod (Value);
         when Osd_Logo_On_Arming_Duration =>
            G.Logo_On_Arming_Duration := Unsigned_8'Mod (Value);
         when Osd_Arming_Logo =>
            G.Arming_Logo := Unsigned_8'Mod (Value);
         when Osd_Use_Quick_Menu =>
            G.Osd_Use_Quick_Menu := Unsigned_8'Mod (Value);
         when Osd_Show_Spec_Prearm =>
            G.Osd_Show_Spec_Prearm := Unsigned_8'Mod (Value);
         when Osd_Tim1 =>
            G.Timers (0) := Unsigned_16'Mod (Value);
         when Osd_Tim2 =>
            G.Timers (1) := Unsigned_16'Mod (Value);
         when Osd_Stick_Overlay_Radio_Mode =>
            G.Overlay_Radio_Mode := Unsigned_8'Mod (Value);
         when Osd_Stat_Bitmask =>
            G.Enabled_Stats := Unsigned_32'Mod (Value);
         when Osd_Profile =>
            G.Osd_Profile_Index := Unsigned_8'Mod (Value);
         when Osd_Gps_Sats_Show_Pdop =>
            G.Gps_Sats_Show_Pdop := Unsigned_8'Mod (Value);
         when Osd_Displayport_Device =>
            G.Display_Port_Device := Unsigned_8'Mod (Value);
         when Osd_Uart =>
            G.Osd_Uart := Signed (Unsigned_8'Mod (Value));
         when Osd_Rcchannels =>
            G.Rc_Channels (Index) := Signed (Unsigned_8'Mod (Value));
         when Osd_Camera_Frame_Width =>
            G.Camera_Frame_Width := Unsigned_8'Mod (Value);
         when Osd_Camera_Frame_Height =>
            G.Camera_Frame_Height := Unsigned_8'Mod (Value);
         when Osd_Stat_Avg_Cell_Value =>
            G.Stat_Show_Cell_Value := Unsigned_8'Mod (Value);
         when Osd_Framerate_Hz =>
            G.Framerate_Hz := Unsigned_16'Mod (Value);
         when Osd_Menu_Background =>
            G.Cms_Background_Type := Unsigned_8'Mod (Value);
         when Osd_Aux_Channel =>
            G.Aux_Channel := Unsigned_8'Mod (Value);
         when Osd_Aux_Scale =>
            G.Aux_Scale := Unsigned_16'Mod (Value);
         when Osd_Aux_Symbol =>
            G.Aux_Symbol := Unsigned_8'Mod (Value);
         when Osd_Craftname_Msgs =>
            G.Osd_Craftname_Msgs := Unsigned_8'Mod (Value);
         when Osd_Custom_Text_Uart =>
            G.Osd_Custom_Text_Uart := Signed (Unsigned_8'Mod (Value));
         when Osd_Custom_Text_Baud =>
            G.Osd_Custom_Text_Baud := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Osd_Config;

   procedure Set_Osd_Element_Config (G : in out Osd_Element_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Osd_Vbat_Pos | Osd_Rssi_Pos | Osd_Link_Quality_Pos | Osd_Link_Tx_Power_Pos |
       Osd_Rssi_Dbm_Pos | Osd_Rsnr_Pos | Osd_Tim_1_Pos | Osd_Tim_2_Pos | Osd_Remaining_Time_Estimate_Pos |
       Osd_Flymode_Pos | Osd_Anti_Gravity_Pos | Osd_G_Force_Pos | Osd_Throttle_Pos | Osd_Vtx_Channel_Pos |
       Osd_Crosshairs_Pos | Osd_Ah_Sbar_Pos | Osd_Ah_Pos | Osd_Current_Pos | Osd_Mah_Drawn_Pos | Osd_Wh_Drawn_Pos |
       Osd_Motor_Diag_Pos | Osd_Craft_Name_Pos | Osd_Pilot_Name_Pos | Osd_Gps_Speed_Pos | Osd_Gps_Lon_Pos |
       Osd_Gps_Lat_Pos | Osd_Gps_Lap_Curr_Pos | Osd_Gps_Lap_Prev_Pos | Osd_Gps_Lap_Best3_Pos | Osd_Gps_Sats_Pos |
       Osd_Home_Dir_Pos | Osd_Home_Dist_Pos | Osd_Flight_Dist_Pos | Osd_Compass_Bar_Pos | Osd_Altitude_Pos |
       Osd_Pid_Roll_Pos | Osd_Pid_Pitch_Pos | Osd_Pid_Yaw_Pos | Osd_Debug_Pos | Osd_Debug2_Pos | Osd_Power_Pos |
       Osd_Pidrate_Profile_Pos | Osd_Warnings_Pos | Osd_Avg_Cell_Voltage_Pos | Osd_Pit_Ang_Pos | Osd_Rol_Ang_Pos |
       Osd_Battery_Usage_Pos | Osd_Disarmed_Pos | Osd_Nheading_Pos | Osd_Up_Down_Reference_Pos | Osd_Ready_Mode_Pos
       | Osd_Pos_Hold_Ready_Pos | Osd_Nvario_Pos | Osd_Esc_Tmp_Pos | Osd_Esc_Rpm_Pos | Osd_Esc_Rpm_Freq_Pos |
       Osd_Rtc_Date_Time_Pos | Osd_Adjustment_Range_Pos | Osd_Flip_Arrow_Pos | Osd_Core_Temp_Pos |
       Osd_Log_Status_Pos | Osd_Stick_Overlay_Left_Pos | Osd_Stick_Overlay_Right_Pos | Osd_Rate_Profile_Name_Pos |
       Osd_Pid_Profile_Name_Pos | Osd_Battery_Profile_Name_Pos | Osd_Profile_Name_Pos | Osd_Rcchannels_Pos |
       Osd_Camera_Frame_Pos | Osd_Efficiency_Pos | Osd_Total_Flights_Pos | Osd_Aux_Pos | Osd_Sys_Goggle_Voltage_Pos
       | Osd_Sys_Vtx_Voltage_Pos | Osd_Sys_Bitrate_Pos | Osd_Sys_Delay_Pos | Osd_Sys_Distance_Pos | Osd_Sys_Lq_Pos
       | Osd_Sys_Goggle_Dvr_Pos | Osd_Sys_Vtx_Dvr_Pos | Osd_Sys_Warnings_Pos | Osd_Sys_Vtx_Temp_Pos |
       Osd_Sys_Fan_Speed_Pos | Osd_Lidar_Dist_Pos | Osd_Custom_Serial_Text_Pos | Osd_Wp_Number_Pos |
       Osd_Wp_Current_Lat_Pos | Osd_Wp_Current_Lon_Pos | Osd_Wp_Current_Alt_Pos | Osd_Wp_Distance_Pos |
       Osd_Wp_Direction_Pos | Osd_Wp_Next_Number_Pos | Osd_Wp_Eta_Pos | Osd_Nav_Map_Pos | Osd_Airspeed) and then
       Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Osd_Vbat_Pos =>
            G.Item_Pos (1) := Unsigned_16'Mod (Value);
         when Osd_Rssi_Pos =>
            G.Item_Pos (0) := Unsigned_16'Mod (Value);
         when Osd_Link_Quality_Pos =>
            G.Item_Pos (46) := Unsigned_16'Mod (Value);
         when Osd_Link_Tx_Power_Pos =>
            G.Item_Pos (61) := Unsigned_16'Mod (Value);
         when Osd_Rssi_Dbm_Pos =>
            G.Item_Pos (55) := Unsigned_16'Mod (Value);
         when Osd_Rsnr_Pos =>
            G.Item_Pos (65) := Unsigned_16'Mod (Value);
         when Osd_Tim_1_Pos =>
            G.Item_Pos (5) := Unsigned_16'Mod (Value);
         when Osd_Tim_2_Pos =>
            G.Item_Pos (6) := Unsigned_16'Mod (Value);
         when Osd_Remaining_Time_Estimate_Pos =>
            G.Item_Pos (37) := Unsigned_16'Mod (Value);
         when Osd_Flymode_Pos =>
            G.Item_Pos (7) := Unsigned_16'Mod (Value);
         when Osd_Anti_Gravity_Pos =>
            G.Item_Pos (41) := Unsigned_16'Mod (Value);
         when Osd_G_Force_Pos =>
            G.Item_Pos (42) := Unsigned_16'Mod (Value);
         when Osd_Throttle_Pos =>
            G.Item_Pos (9) := Unsigned_16'Mod (Value);
         when Osd_Vtx_Channel_Pos =>
            G.Item_Pos (10) := Unsigned_16'Mod (Value);
         when Osd_Crosshairs_Pos =>
            G.Item_Pos (2) := Unsigned_16'Mod (Value);
         when Osd_Ah_Sbar_Pos =>
            G.Item_Pos (4) := Unsigned_16'Mod (Value);
         when Osd_Ah_Pos =>
            G.Item_Pos (3) := Unsigned_16'Mod (Value);
         when Osd_Current_Pos =>
            G.Item_Pos (11) := Unsigned_16'Mod (Value);
         when Osd_Mah_Drawn_Pos =>
            G.Item_Pos (12) := Unsigned_16'Mod (Value);
         when Osd_Wh_Drawn_Pos =>
            G.Item_Pos (62) := Unsigned_16'Mod (Value);
         when Osd_Motor_Diag_Pos =>
            G.Item_Pos (43) := Unsigned_16'Mod (Value);
         when Osd_Craft_Name_Pos =>
            G.Item_Pos (8) := Unsigned_16'Mod (Value);
         when Osd_Pilot_Name_Pos =>
            G.Item_Pos (50) := Unsigned_16'Mod (Value);
         when Osd_Gps_Speed_Pos =>
            G.Item_Pos (13) := Unsigned_16'Mod (Value);
         when Osd_Gps_Lon_Pos =>
            G.Item_Pos (23) := Unsigned_16'Mod (Value);
         when Osd_Gps_Lat_Pos =>
            G.Item_Pos (24) := Unsigned_16'Mod (Value);
         when Osd_Gps_Lap_Curr_Pos =>
            G.Item_Pos (77) := Unsigned_16'Mod (Value);
         when Osd_Gps_Lap_Prev_Pos =>
            G.Item_Pos (78) := Unsigned_16'Mod (Value);
         when Osd_Gps_Lap_Best3_Pos =>
            G.Item_Pos (79) := Unsigned_16'Mod (Value);
         when Osd_Gps_Sats_Pos =>
            G.Item_Pos (14) := Unsigned_16'Mod (Value);
         when Osd_Home_Dir_Pos =>
            G.Item_Pos (30) := Unsigned_16'Mod (Value);
         when Osd_Home_Dist_Pos =>
            G.Item_Pos (31) := Unsigned_16'Mod (Value);
         when Osd_Flight_Dist_Pos =>
            G.Item_Pos (47) := Unsigned_16'Mod (Value);
         when Osd_Compass_Bar_Pos =>
            G.Item_Pos (34) := Unsigned_16'Mod (Value);
         when Osd_Altitude_Pos =>
            G.Item_Pos (15) := Unsigned_16'Mod (Value);
         when Osd_Pid_Roll_Pos =>
            G.Item_Pos (16) := Unsigned_16'Mod (Value);
         when Osd_Pid_Pitch_Pos =>
            G.Item_Pos (17) := Unsigned_16'Mod (Value);
         when Osd_Pid_Yaw_Pos =>
            G.Item_Pos (18) := Unsigned_16'Mod (Value);
         when Osd_Debug_Pos =>
            G.Item_Pos (25) := Unsigned_16'Mod (Value);
         when Osd_Debug2_Pos =>
            G.Item_Pos (80) := Unsigned_16'Mod (Value);
         when Osd_Power_Pos =>
            G.Item_Pos (19) := Unsigned_16'Mod (Value);
         when Osd_Pidrate_Profile_Pos =>
            G.Item_Pos (20) := Unsigned_16'Mod (Value);
         when Osd_Warnings_Pos =>
            G.Item_Pos (21) := Unsigned_16'Mod (Value);
         when Osd_Avg_Cell_Voltage_Pos =>
            G.Item_Pos (22) := Unsigned_16'Mod (Value);
         when Osd_Pit_Ang_Pos =>
            G.Item_Pos (26) := Unsigned_16'Mod (Value);
         when Osd_Rol_Ang_Pos =>
            G.Item_Pos (27) := Unsigned_16'Mod (Value);
         when Osd_Battery_Usage_Pos =>
            G.Item_Pos (28) := Unsigned_16'Mod (Value);
         when Osd_Disarmed_Pos =>
            G.Item_Pos (29) := Unsigned_16'Mod (Value);
         when Osd_Nheading_Pos =>
            G.Item_Pos (32) := Unsigned_16'Mod (Value);
         when Osd_Up_Down_Reference_Pos =>
            G.Item_Pos (60) := Unsigned_16'Mod (Value);
         when Osd_Ready_Mode_Pos =>
            G.Item_Pos (64) := Unsigned_16'Mod (Value);
         when Osd_Pos_Hold_Ready_Pos =>
            G.Item_Pos (97) := Unsigned_16'Mod (Value);
         when Osd_Nvario_Pos =>
            G.Item_Pos (33) := Unsigned_16'Mod (Value);
         when Osd_Esc_Tmp_Pos =>
            G.Item_Pos (35) := Unsigned_16'Mod (Value);
         when Osd_Esc_Rpm_Pos =>
            G.Item_Pos (36) := Unsigned_16'Mod (Value);
         when Osd_Esc_Rpm_Freq_Pos =>
            G.Item_Pos (51) := Unsigned_16'Mod (Value);
         when Osd_Rtc_Date_Time_Pos =>
            G.Item_Pos (38) := Unsigned_16'Mod (Value);
         when Osd_Adjustment_Range_Pos =>
            G.Item_Pos (39) := Unsigned_16'Mod (Value);
         when Osd_Flip_Arrow_Pos =>
            G.Item_Pos (45) := Unsigned_16'Mod (Value);
         when Osd_Core_Temp_Pos =>
            G.Item_Pos (40) := Unsigned_16'Mod (Value);
         when Osd_Log_Status_Pos =>
            G.Item_Pos (44) := Unsigned_16'Mod (Value);
         when Osd_Stick_Overlay_Left_Pos =>
            G.Item_Pos (48) := Unsigned_16'Mod (Value);
         when Osd_Stick_Overlay_Right_Pos =>
            G.Item_Pos (49) := Unsigned_16'Mod (Value);
         when Osd_Rate_Profile_Name_Pos =>
            G.Item_Pos (52) := Unsigned_16'Mod (Value);
         when Osd_Pid_Profile_Name_Pos =>
            G.Item_Pos (53) := Unsigned_16'Mod (Value);
         when Osd_Battery_Profile_Name_Pos =>
            G.Item_Pos (87) := Unsigned_16'Mod (Value);
         when Osd_Profile_Name_Pos =>
            G.Item_Pos (54) := Unsigned_16'Mod (Value);
         when Osd_Rcchannels_Pos =>
            G.Item_Pos (56) := Unsigned_16'Mod (Value);
         when Osd_Camera_Frame_Pos =>
            G.Item_Pos (57) := Unsigned_16'Mod (Value);
         when Osd_Efficiency_Pos =>
            G.Item_Pos (58) := Unsigned_16'Mod (Value);
         when Osd_Total_Flights_Pos =>
            G.Item_Pos (59) := Unsigned_16'Mod (Value);
         when Osd_Aux_Pos =>
            G.Item_Pos (63) := Unsigned_16'Mod (Value);
         when Osd_Sys_Goggle_Voltage_Pos =>
            G.Item_Pos (66) := Unsigned_16'Mod (Value);
         when Osd_Sys_Vtx_Voltage_Pos =>
            G.Item_Pos (67) := Unsigned_16'Mod (Value);
         when Osd_Sys_Bitrate_Pos =>
            G.Item_Pos (68) := Unsigned_16'Mod (Value);
         when Osd_Sys_Delay_Pos =>
            G.Item_Pos (69) := Unsigned_16'Mod (Value);
         when Osd_Sys_Distance_Pos =>
            G.Item_Pos (70) := Unsigned_16'Mod (Value);
         when Osd_Sys_Lq_Pos =>
            G.Item_Pos (71) := Unsigned_16'Mod (Value);
         when Osd_Sys_Goggle_Dvr_Pos =>
            G.Item_Pos (72) := Unsigned_16'Mod (Value);
         when Osd_Sys_Vtx_Dvr_Pos =>
            G.Item_Pos (73) := Unsigned_16'Mod (Value);
         when Osd_Sys_Warnings_Pos =>
            G.Item_Pos (74) := Unsigned_16'Mod (Value);
         when Osd_Sys_Vtx_Temp_Pos =>
            G.Item_Pos (75) := Unsigned_16'Mod (Value);
         when Osd_Sys_Fan_Speed_Pos =>
            G.Item_Pos (76) := Unsigned_16'Mod (Value);
         when Osd_Lidar_Dist_Pos =>
            G.Item_Pos (85) := Unsigned_16'Mod (Value);
         when Osd_Custom_Serial_Text_Pos =>
            G.Item_Pos (86) := Unsigned_16'Mod (Value);
         when Osd_Wp_Number_Pos =>
            G.Item_Pos (88) := Unsigned_16'Mod (Value);
         when Osd_Wp_Current_Lat_Pos =>
            G.Item_Pos (89) := Unsigned_16'Mod (Value);
         when Osd_Wp_Current_Lon_Pos =>
            G.Item_Pos (90) := Unsigned_16'Mod (Value);
         when Osd_Wp_Current_Alt_Pos =>
            G.Item_Pos (91) := Unsigned_16'Mod (Value);
         when Osd_Wp_Distance_Pos =>
            G.Item_Pos (92) := Unsigned_16'Mod (Value);
         when Osd_Wp_Direction_Pos =>
            G.Item_Pos (93) := Unsigned_16'Mod (Value);
         when Osd_Wp_Next_Number_Pos =>
            G.Item_Pos (94) := Unsigned_16'Mod (Value);
         when Osd_Wp_Eta_Pos =>
            G.Item_Pos (95) := Unsigned_16'Mod (Value);
         when Osd_Nav_Map_Pos =>
            G.Item_Pos (96) := Unsigned_16'Mod (Value);
         when Osd_Airspeed =>
            G.Item_Pos (98) := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Osd_Element_Config;

   procedure Set_Osd_Custom_Text_Config (G : in out Osd_Custom_Text_Config_Record; S : Setting; Value : Integer_64;
      Index : Natural)
     with Pre => (S in Osd_Custom_Serial_Text_Terminator) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Osd_Custom_Serial_Text_Terminator =>
            G.Terminator := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Osd_Custom_Text_Config;

   procedure Set_Osd_Nav_Map_Config (G : in out Osd_Nav_Map_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Osd_Nav_Map_Mode | Osd_Nav_Map_Centre | Osd_Nav_Map_Min_Scale_M) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Osd_Nav_Map_Mode =>
            G.Mode := Unsigned_8'Mod (Value);
         when Osd_Nav_Map_Centre =>
            G.Centre := Unsigned_8'Mod (Value);
         when Osd_Nav_Map_Min_Scale_M =>
            G.Min_Scale_M := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Osd_Nav_Map_Config;

   procedure Set_System_Config (G : in out System_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in System_Hse_Mhz | Task_Statistics | Debug_Mode | Rate_6pos_Switch | Cpu_Overclock |
       Pwr_On_Arm_Grace | Enable_Stick_Arming) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when System_Hse_Mhz =>
            G.Hse_Mhz := Unsigned_8'Mod (Value);
         when Task_Statistics =>
            G.Task_Statistics := Unsigned_8'Mod (Value);
         when Debug_Mode =>
            G.Debug_Mode := Unsigned_8'Mod (Value);
         when Rate_6pos_Switch =>
            G.Rate_Profile6_Pos_Switch := Unsigned_8'Mod (Value);
         when Cpu_Overclock =>
            G.Cpu_Overclock := Unsigned_8'Mod (Value);
         when Pwr_On_Arm_Grace =>
            G.Power_On_Arming_Grace_Time := Unsigned_8'Mod (Value);
         when Enable_Stick_Arming =>
            G.Enable_Stick_Arming := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_System_Config;

   procedure Set_Vtx_Settings_Config (G : in out Vtx_Settings_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Vtx_Band | Vtx_Channel | Vtx_Power | Vtx_Low_Power_Disarm | Vtx_Softserial_Alt | Vtx_Type
       | Vtx_Uart | Vtx_Freq | Vtx_Pit_Mode_Freq) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Vtx_Band =>
            G.Band := Unsigned_8'Mod (Value);
         when Vtx_Channel =>
            G.Channel := Unsigned_8'Mod (Value);
         when Vtx_Power =>
            G.Power := Unsigned_8'Mod (Value);
         when Vtx_Low_Power_Disarm =>
            G.Low_Power_Disarm := Unsigned_8'Mod (Value);
         when Vtx_Softserial_Alt =>
            G.Softserial_Alt := Unsigned_8'Mod (Value);
         when Vtx_Type =>
            G.Vtx_Type := Unsigned_8'Mod (Value);
         when Vtx_Uart =>
            G.Vtx_Uart := Signed (Unsigned_8'Mod (Value));
         when Vtx_Freq =>
            G.Freq := Unsigned_16'Mod (Value);
         when Vtx_Pit_Mode_Freq =>
            G.Pit_Mode_Freq := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Vtx_Settings_Config;

   procedure Set_Vtx_Config (G : in out Vtx_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Vtx_Halfduplex) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Vtx_Halfduplex =>
            G.Half_Duplex := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Vtx_Config;

   procedure Set_Vtx_Io_Config (G : in out Vtx_Io_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Vtx_Spi_Bus) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Vtx_Spi_Bus =>
            G.Spi_Device := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Vtx_Io_Config;

   procedure Set_Vcd_Profile (G : in out Vcd_Profile_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Vcd_Video_System | Vcd_H_Offset | Vcd_V_Offset) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Vcd_Video_System =>
            G.Video_System := Unsigned_8'Mod (Value);
         when Vcd_H_Offset =>
            G.H_Offset := Signed (Unsigned_8'Mod (Value));
         when Vcd_V_Offset =>
            G.V_Offset := Signed (Unsigned_8'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Vcd_Profile;

   procedure Set_Max7456_Config (G : in out Max7456_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Max7456_Clock | Max7456_Spi_Bus | Max7456_Preinit_Opu) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Max7456_Clock =>
            G.Clock_Config := Unsigned_8'Mod (Value);
         when Max7456_Spi_Bus =>
            G.Spi_Device := Unsigned_8'Mod (Value);
         when Max7456_Preinit_Opu =>
            G.Pre_Init_Opu := Value mod 256 /= 0;
         when others =>
            null;
      end case;
   end Set_Max7456_Config;

   procedure Set_Display_Port_Profile_Msp (G : in out Display_Port_Profile_Record; S : Setting; Value : Integer_64;
      Index : Natural)
     with Pre => (S in Displayport_Msp_Col_Adjust | Displayport_Msp_Row_Adjust | Displayport_Msp_Fonts |
       Displayport_Msp_Use_Device_Blink) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Displayport_Msp_Col_Adjust =>
            G.Col_Adjust := Signed (Unsigned_8'Mod (Value));
         when Displayport_Msp_Row_Adjust =>
            G.Row_Adjust := Signed (Unsigned_8'Mod (Value));
         when Displayport_Msp_Fonts =>
            G.Font_Selection (Index) := Unsigned_8'Mod (Value);
         when Displayport_Msp_Use_Device_Blink =>
            G.Use_Device_Blink := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Display_Port_Profile_Msp;

   procedure Set_Display_Port_Profile_Max7456 (G : in out Display_Port_Profile_Record; S : Setting; Value :
      Integer_64; Index : Natural)
     with Pre => (S in Displayport_Max7456_Col_Adjust | Displayport_Max7456_Row_Adjust | Displayport_Max7456_Inv
       | Displayport_Max7456_Blk | Displayport_Max7456_Wht) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Displayport_Max7456_Col_Adjust =>
            G.Col_Adjust := Signed (Unsigned_8'Mod (Value));
         when Displayport_Max7456_Row_Adjust =>
            G.Row_Adjust := Signed (Unsigned_8'Mod (Value));
         when Displayport_Max7456_Inv =>
            G.Invert := Value mod 256 /= 0;
         when Displayport_Max7456_Blk =>
            G.Black_Brightness := Unsigned_8'Mod (Value);
         when Displayport_Max7456_Wht =>
            G.White_Brightness := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Display_Port_Profile_Max7456;

   procedure Set_Esc_Sensor_Config (G : in out Esc_Sensor_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Esc_Sensor_Halfduplex | Esc_Sensor_Current_Offset | Esc_Sensor_Uart) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Esc_Sensor_Halfduplex =>
            G.Half_Duplex := Unsigned_8'Mod (Value);
         when Esc_Sensor_Current_Offset =>
            G.Offset := Unsigned_16'Mod (Value);
         when Esc_Sensor_Uart =>
            G.Esc_Sensor_Uart := Signed (Unsigned_8'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Esc_Sensor_Config;

   procedure Set_Rx_Cc2500_Spi_Config (G : in out Rx_Cc2500_Spi_Config_Record; S : Setting; Value : Integer_64; Index
      : Natural)
     with Pre => (S in Frsky_Spi_Autobind | Frsky_Spi_Tx_Id | Frsky_Spi_Offset | Frsky_Spi_Bind_Hop_Data |
       Frsky_X_Rx_Num | Frsky_Spi_A1_Source | Cc2500_Spi_Chip_Detect) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Frsky_Spi_Autobind =>
            G.Auto_Bind := Unsigned_8'Mod (Value);
         when Frsky_Spi_Tx_Id =>
            G.Bind_Tx_Id (Index) := Unsigned_8'Mod (Value);
         when Frsky_Spi_Offset =>
            G.Bind_Offset := Signed (Unsigned_8'Mod (Value));
         when Frsky_Spi_Bind_Hop_Data =>
            G.Bind_Hop_Data (Index) := Unsigned_8'Mod (Value);
         when Frsky_X_Rx_Num =>
            G.Rx_Num := Unsigned_8'Mod (Value);
         when Frsky_Spi_A1_Source =>
            G.A1_Source := Unsigned_8'Mod (Value);
         when Cc2500_Spi_Chip_Detect =>
            G.Chip_Detect_Enabled := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Rx_Cc2500_Spi_Config;

   procedure Set_Status_Led_Config (G : in out Status_Led_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Led_Inversion) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Led_Inversion =>
            G.Inversion := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Status_Led_Config;

   procedure Set_Dashboard_Config (G : in out Dashboard_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Dashboard_I2c_Bus | Dashboard_I2c_Addr) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Dashboard_I2c_Bus =>
            G.Device := Signed ((Unsigned_32'Mod (Integer_64 (G.Device)) and 16#FFFF_FF00#) or Unsigned_32
               (Unsigned_8'Mod (Value)));
         when Dashboard_I2c_Addr =>
            G.Address := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Dashboard_Config;

   procedure Set_Rangefinder_Config (G : in out Rangefinder_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Rangefinder_Hardware | Rangefinder_Uart) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Rangefinder_Hardware =>
            G.Rangefinder_Hardware := Unsigned_8'Mod (Value);
         when Rangefinder_Uart =>
            G.Rangefinder_Uart := Signed (Unsigned_8'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Rangefinder_Config;

   procedure Set_Opticalflow_Config (G : in out Opticalflow_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Opticalflow_Hardware | Opticalflow_Uart | Opticalflow_Rotation | Opticalflow_Flip_X) and
       then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Opticalflow_Hardware =>
            G.Opticalflow_Hardware := Unsigned_8'Mod (Value);
         when Opticalflow_Uart =>
            G.Opticalflow_Uart := Signed (Unsigned_8'Mod (Value));
         when Opticalflow_Rotation =>
            G.Rotation := Unsigned_16'Mod (Value);
         when Opticalflow_Flip_X =>
            G.Flip_X := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Opticalflow_Config;

   procedure Set_Pinio_Config (G : in out Pinio_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Pinio_Config) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Pinio_Config =>
            G.Config (Index) := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Pinio_Config;

   procedure Set_Pinio_Box_Config (G : in out Pinio_Box_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Pinio_Box) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Pinio_Box =>
            G.Permanent_Id (Index) := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Pinio_Box_Config;

   procedure Set_Usb_Dev_Config (G : in out Usb_Dev_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Usb_Hid_Cdc | Usb_Msc_Pin_Pullup) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Usb_Hid_Cdc =>
            G.Type_Value := Unsigned_8'Mod (Value);
         when Usb_Msc_Pin_Pullup =>
            G.Msc_Button_Use_Pullup := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Usb_Dev_Config;

   procedure Set_Flash_Config (G : in out Flash_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Flash_Spi_Bus) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Flash_Spi_Bus =>
            G.Spi_Device := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Flash_Config;

   procedure Set_Rcdevice_Config (G : in out Rcdevice_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Rcdevice_Init_Dev_Attempts | Rcdevice_Init_Dev_Attempt_Interval |
       Rcdevice_Protocol_Version | Rcdevice_Feature | Rcdevice_Uart) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Rcdevice_Init_Dev_Attempts =>
            G.Init_Device_Attempts := Unsigned_8'Mod (Value);
         when Rcdevice_Init_Dev_Attempt_Interval =>
            G.Init_Device_Attempt_Interval := Unsigned_32'Mod (Value);
         when Rcdevice_Protocol_Version =>
            G.Protocol_Version := Unsigned_8'Mod (Value);
         when Rcdevice_Feature =>
            G.Feature := (G.Feature and 16#FFFF_0000#) or Unsigned_32 (Unsigned_16'Mod (Value));
         when Rcdevice_Uart =>
            G.Rcdevice_Uart := Signed (Unsigned_8'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Rcdevice_Config;

   procedure Set_Gyro_Device_Config (G : in out Gyro_Device_Config_Record_List_1; S : Setting; Value : Integer_64;
      Index : Natural)
     with Pre => (S in Gyro_1_Bustype | Gyro_1_Spibus | Gyro_1_I2c_Bus | Gyro_1_I2c_Address) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Gyro_1_Bustype =>
            G (0).Bus_Type := Unsigned_8'Mod (Value);
         when Gyro_1_Spibus =>
            G (0).Spi_Bus := Unsigned_8'Mod (Value);
         when Gyro_1_I2c_Bus =>
            G (0).I2c_Bus := Unsigned_8'Mod (Value);
         when Gyro_1_I2c_Address =>
            G (0).I2c_Address := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Gyro_Device_Config;

   procedure Set_I2c_Config (G : in out I2c_Config_Record_List_3; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in I2c1_Pullup | I2c1_Clockspeed_Khz | I2c2_Pullup | I2c2_Clockspeed_Khz | I2c3_Pullup |
       I2c3_Clockspeed_Khz) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when I2c1_Pullup =>
            G (0).Pull_Up := Value mod 256 /= 0;
         when I2c1_Clockspeed_Khz =>
            G (0).Clock_Speed := Unsigned_16'Mod (Value);
         when I2c2_Pullup =>
            G (1).Pull_Up := Value mod 256 /= 0;
         when I2c2_Clockspeed_Khz =>
            G (1).Clock_Speed := Unsigned_16'Mod (Value);
         when I2c3_Pullup =>
            G (2).Pull_Up := Value mod 256 /= 0;
         when I2c3_Clockspeed_Khz =>
            G (2).Clock_Speed := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_I2c_Config;

   procedure Set_Mco_Config (G : in out Mco_Config_Record_List_2; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Mco2_On_Pc9) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Mco2_On_Pc9 =>
            G (1).Enabled := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Mco_Config;

   procedure Set_Spektrum_Config (G : in out Spektrum_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Spektrum_Spi_Protocol | Spektrum_Spi_Mfg_Id | Spektrum_Spi_Num_Channels) and then Index <
       Element_Count (S)
   is
   begin
      case S is
         when Spektrum_Spi_Protocol =>
            G.Protocol := Unsigned_8'Mod (Value);
         when Spektrum_Spi_Mfg_Id =>
            G.Mfg_Id (Index) := Unsigned_8'Mod (Value);
         when Spektrum_Spi_Num_Channels =>
            G.Num_Channels := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Spektrum_Config;

   procedure Set_Rx_Express_Lrs_Spi_Config (G : in out Rx_Express_Lrs_Spi_Config_Record; S : Setting; Value :
      Integer_64; Index : Natural)
     with Pre => (S in Expresslrs_Uid | Expresslrs_Domain | Expresslrs_Model_Id) and then Index < Element_Count
       (S)
   is
   begin
      case S is
         when Expresslrs_Uid =>
            G.Uid (Index) := Unsigned_8'Mod (Value);
         when Expresslrs_Domain =>
            G.Domain := Unsigned_8'Mod (Value);
         when Expresslrs_Model_Id =>
            G.Model_Id := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Rx_Express_Lrs_Spi_Config;

   procedure Set_Scheduler_Config (G : in out Scheduler_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Scheduler_Relax_Rx | Scheduler_Relax_Osd | Scheduler_Debug_Task | Cpu_Late_Limit_Permille)
       and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Scheduler_Relax_Rx =>
            G.Rx_Relax_Determinism := Unsigned_16'Mod (Value);
         when Scheduler_Relax_Osd =>
            G.Osd_Relax_Determinism := Unsigned_16'Mod (Value);
         when Scheduler_Debug_Task =>
            G.Debug_Task := Unsigned_8'Mod (Value);
         when Cpu_Late_Limit_Permille =>
            G.Cpu_Late_Percentage_Limit := (G.Cpu_Late_Percentage_Limit and 16#FF00#) or Unsigned_16 (Unsigned_8'Mod
               (Value));
         when others =>
            null;
      end case;
   end Set_Scheduler_Config;

   procedure Set_Msp_Config (G : in out Msp_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Serialmsp_Halfduplex | Msp_1_Uart | Msp_1_Baud | Msp_2_Uart | Msp_2_Baud | Msp_3_Uart |
       Msp_3_Baud) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Serialmsp_Halfduplex =>
            G.Half_Duplex := Unsigned_8'Mod (Value);
         when Msp_1_Uart =>
            G.Msp_Uart (0) := Signed (Unsigned_8'Mod (Value));
         when Msp_1_Baud =>
            G.Msp_Baud (0) := Unsigned_8'Mod (Value);
         when Msp_2_Uart =>
            G.Msp_Uart (1) := Signed (Unsigned_8'Mod (Value));
         when Msp_2_Baud =>
            G.Msp_Baud (1) := Unsigned_8'Mod (Value);
         when Msp_3_Uart =>
            G.Msp_Uart (2) := Signed (Unsigned_8'Mod (Value));
         when Msp_3_Baud =>
            G.Msp_Baud (2) := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Msp_Config;

   procedure Set_Time_Config (G : in out Time_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Timezone_Offset_Minutes) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Timezone_Offset_Minutes =>
            G.Tz_Offset_Minutes := Signed (Unsigned_16'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Time_Config;

   procedure Set_Rpm_Filter_Config (G : in out Rpm_Filter_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Rpm_Filter_Harmonics | Rpm_Filter_Weights | Rpm_Filter_Q | Rpm_Filter_Min_Hz |
       Rpm_Filter_Fade_Range_Hz | Rpm_Filter_Lpf_Hz) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Rpm_Filter_Harmonics =>
            G.Rpm_Filter_Harmonics := Unsigned_8'Mod (Value);
         when Rpm_Filter_Weights =>
            G.Rpm_Filter_Weights (Index) := Unsigned_8'Mod (Value);
         when Rpm_Filter_Q =>
            G.Rpm_Filter_Q := Unsigned_16'Mod (Value);
         when Rpm_Filter_Min_Hz =>
            G.Rpm_Filter_Min_Hz := Unsigned_8'Mod (Value);
         when Rpm_Filter_Fade_Range_Hz =>
            G.Rpm_Filter_Fade_Range_Hz := Unsigned_16'Mod (Value);
         when Rpm_Filter_Lpf_Hz =>
            G.Rpm_Filter_Lpf_Hz := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Rpm_Filter_Config;

   procedure Set_Fly_Sky_Config (G : in out Fly_Sky_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Flysky_Spi_Tx_Id | Flysky_Spi_Rf_Channels) and then Index < Element_Count (S)
   is
   begin
      case S is
         when Flysky_Spi_Tx_Id =>
            G.Tx_Id := Unsigned_32'Mod (Value);
         when Flysky_Spi_Rf_Channels =>
            G.Rf_Channel_Map (Index) := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Fly_Sky_Config;

   procedure Set_Stats_Config (G : in out Stats_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Stats_Min_Armed_Time_S | Stats_Total_Flights | Stats_Total_Time_S | Stats_Total_Dist_M |
       Stats_Save_Move_Limit | Stats_Mah_Used) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Stats_Min_Armed_Time_S =>
            G.Stats_Min_Armed_Time_S := Signed (Unsigned_8'Mod (Value));
         when Stats_Total_Flights =>
            G.Stats_Total_Flights := Unsigned_32'Mod (Value);
         when Stats_Total_Time_S =>
            G.Stats_Total_Time_S := Unsigned_32'Mod (Value);
         when Stats_Total_Dist_M =>
            G.Stats_Total_Dist_M := Unsigned_32'Mod (Value);
         when Stats_Save_Move_Limit =>
            G.Stats_Save_Move_Limit := Unsigned_8'Mod (Value);
         when Stats_Mah_Used =>
            G.Stats_Mah_Used := Unsigned_32'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Stats_Config;

   procedure Set_Position_Config (G : in out Position_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Altitude_Source | Altitude_Prefer_Baro | Altitude_Lpf | Rangefinder_Max_Range_Cm |
       Altitude_D_Lpf) and then Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Altitude_Source =>
            G.Altitude_Source := Unsigned_8'Mod (Value);
         when Altitude_Prefer_Baro =>
            G.Altitude_Prefer_Baro := Unsigned_8'Mod (Value);
         when Altitude_Lpf =>
            G.Altitude_Lpf := Unsigned_16'Mod (Value);
         when Rangefinder_Max_Range_Cm =>
            G.Rangefinder_Max_Range_Cm := Unsigned_16'Mod (Value);
         when Altitude_D_Lpf =>
            G.Altitude_D_Lpf := Unsigned_16'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Position_Config;

   procedure Set_Autopilot_Config (G : in out Autopilot_Config_Record; S : Setting; Value : Integer_64; Index : Natural)
     with Pre => (S in Ap_Landing_Altitude_M | Ap_Hover_Throttle | Ap_Throttle_Min | Ap_Throttle_Max |
       Ap_Altitude_P | Ap_Altitude_I | Ap_Altitude_D | Ap_Altitude_A | Ap_Altitude_F | Ap_Position_P |
       Ap_Position_I | Ap_Position_D | Ap_Position_A | Ap_Position_F | Ap_Position_Cutoff | Ap_Stop_Threshold |
       Ap_Max_Angle | Ap_Max_Yaw_Rate | Ap_Yaw_P | Ap_Velocity_Drag_Coeff | Ap_Max_Velocity |
       Ap_Waypoint_Arrival_Radius | Ap_Waypoint_Hold_Radius | Ap_Stick_Deadband | Ap_Throttle_Deadband |
       Ap_Yaw_Mode | Ap_Min_Forward_Velocity | Ap_Nav_Corner_Speed | Ap_Nav_Corner_Delta_V | Ap_Nav_Decel |
       Ap_Nav_Accel | Ap_Nav_Carrot_Lead_Time | Ap_Nav_Carrot_Lead_Max | Ap_Nav_Preturn_Dist |
       Ap_Velocity_Buildup_Max_Pitch | Ap_Max_Turn_Rate | Ap_Hold_Orbit_Radius | Ap_Hold_Figure8_Width |
       Ap_Landing_Descent_Rate | Ap_Landing_Detection_Time | Ap_Landing_Spiral_Enable | Ap_Landing_Spiral_Radius |
       Ap_Landing_Spiral_Rate | Ap_Landing_Velocity_Threshold | Ap_Landing_Throttle_Threshold | Ap_L1_Enable |
       Ap_L1_Period | Ap_L1_Min_Lookahead | Ap_L1_Max_Lookahead | Ap_L1_Max_Cross_Track_Error | Ap_L1_Turn_Rate |
       Ap_Min_Nav_Altitude_M | Ap_Rx_Loss_Policy | Ap_Max_Distance_From_Home | Ap_Geofence_Action) and then Index <
       Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Ap_Landing_Altitude_M =>
            G.Landing_Altitude_M := Unsigned_8'Mod (Value);
         when Ap_Hover_Throttle =>
            G.Hover_Throttle := Unsigned_16'Mod (Value);
         when Ap_Throttle_Min =>
            G.Throttle_Min := Unsigned_16'Mod (Value);
         when Ap_Throttle_Max =>
            G.Throttle_Max := Unsigned_16'Mod (Value);
         when Ap_Altitude_P =>
            G.Altitude_P := Unsigned_8'Mod (Value);
         when Ap_Altitude_I =>
            G.Altitude_I := Unsigned_8'Mod (Value);
         when Ap_Altitude_D =>
            G.Altitude_D := Unsigned_8'Mod (Value);
         when Ap_Altitude_A =>
            G.Altitude_A := Unsigned_8'Mod (Value);
         when Ap_Altitude_F =>
            G.Altitude_F := Unsigned_8'Mod (Value);
         when Ap_Position_P =>
            G.Position_P := Unsigned_8'Mod (Value);
         when Ap_Position_I =>
            G.Position_I := Unsigned_8'Mod (Value);
         when Ap_Position_D =>
            G.Position_D := Unsigned_8'Mod (Value);
         when Ap_Position_A =>
            G.Position_A := Unsigned_8'Mod (Value);
         when Ap_Position_F =>
            G.Position_F := Unsigned_8'Mod (Value);
         when Ap_Position_Cutoff =>
            G.Position_Cutoff := Unsigned_8'Mod (Value);
         when Ap_Stop_Threshold =>
            G.Stop_Threshold := Unsigned_8'Mod (Value);
         when Ap_Max_Angle =>
            G.Max_Angle := Unsigned_8'Mod (Value);
         when Ap_Max_Yaw_Rate =>
            G.Max_Yaw_Rate := Unsigned_8'Mod (Value);
         when Ap_Yaw_P =>
            G.Yaw_P := Unsigned_8'Mod (Value);
         when Ap_Velocity_Drag_Coeff =>
            G.Velocity_Drag_Coeff := Unsigned_8'Mod (Value);
         when Ap_Max_Velocity =>
            G.Max_Velocity := Unsigned_16'Mod (Value);
         when Ap_Waypoint_Arrival_Radius =>
            G.Waypoint_Arrival_Radius := Unsigned_16'Mod (Value);
         when Ap_Waypoint_Hold_Radius =>
            G.Waypoint_Hold_Radius := Unsigned_16'Mod (Value);
         when Ap_Stick_Deadband =>
            G.Stick_Deadband := Unsigned_16'Mod (Value);
         when Ap_Throttle_Deadband =>
            G.Throttle_Deadband := Unsigned_16'Mod (Value);
         when Ap_Yaw_Mode =>
            G.Yaw_Mode := Unsigned_8'Mod (Value);
         when Ap_Min_Forward_Velocity =>
            G.Min_Forward_Velocity := Unsigned_16'Mod (Value);
         when Ap_Nav_Corner_Speed =>
            G.Nav_Corner_Speed := Unsigned_16'Mod (Value);
         when Ap_Nav_Corner_Delta_V =>
            G.Nav_Corner_Delta_V := Unsigned_16'Mod (Value);
         when Ap_Nav_Decel =>
            G.Nav_Decel := Unsigned_16'Mod (Value);
         when Ap_Nav_Accel =>
            G.Nav_Accel := Unsigned_16'Mod (Value);
         when Ap_Nav_Carrot_Lead_Time =>
            G.Nav_Carrot_Lead_Time := Unsigned_8'Mod (Value);
         when Ap_Nav_Carrot_Lead_Max =>
            G.Nav_Carrot_Lead_Max := Unsigned_16'Mod (Value);
         when Ap_Nav_Preturn_Dist =>
            G.Nav_Preturn_Dist := Unsigned_16'Mod (Value);
         when Ap_Velocity_Buildup_Max_Pitch =>
            G.Velocity_Buildup_Max_Pitch := Unsigned_8'Mod (Value);
         when Ap_Max_Turn_Rate =>
            G.Max_Turn_Rate := Unsigned_8'Mod (Value);
         when Ap_Hold_Orbit_Radius =>
            G.Hold_Orbit_Radius := Unsigned_16'Mod (Value);
         when Ap_Hold_Figure8_Width =>
            G.Hold_Figure8_Width := Unsigned_16'Mod (Value);
         when Ap_Landing_Descent_Rate =>
            G.Landing_Descent_Rate := Unsigned_8'Mod (Value);
         when Ap_Landing_Detection_Time =>
            G.Landing_Detection_Time := Unsigned_8'Mod (Value);
         when Ap_Landing_Spiral_Enable =>
            G.Landing_Spiral_Enable := Unsigned_8'Mod (Value);
         when Ap_Landing_Spiral_Radius =>
            G.Landing_Spiral_Radius := Unsigned_16'Mod (Value);
         when Ap_Landing_Spiral_Rate =>
            G.Landing_Spiral_Rate := Unsigned_8'Mod (Value);
         when Ap_Landing_Velocity_Threshold =>
            G.Landing_Velocity_Threshold := Unsigned_8'Mod (Value);
         when Ap_Landing_Throttle_Threshold =>
            G.Landing_Throttle_Threshold := Unsigned_16'Mod (Value);
         when Ap_L1_Enable =>
            G.L1_Enable := Unsigned_8'Mod (Value);
         when Ap_L1_Period =>
            G.L1_Period := Unsigned_16'Mod (Value);
         when Ap_L1_Min_Lookahead =>
            G.L1_Min_Lookahead := Unsigned_16'Mod (Value);
         when Ap_L1_Max_Lookahead =>
            G.L1_Max_Lookahead := Unsigned_16'Mod (Value);
         when Ap_L1_Max_Cross_Track_Error =>
            G.L1_Max_Cross_Track_Error := Unsigned_16'Mod (Value);
         when Ap_L1_Turn_Rate =>
            G.L1_Turn_Rate := Unsigned_8'Mod (Value);
         when Ap_Min_Nav_Altitude_M =>
            G.Min_Nav_Altitude_M := Unsigned_8'Mod (Value);
         when Ap_Rx_Loss_Policy =>
            G.Rx_Loss_Policy := Unsigned_8'Mod (Value);
         when Ap_Max_Distance_From_Home =>
            G.Max_Distance_From_Home_M := Unsigned_16'Mod (Value);
         when Ap_Geofence_Action =>
            G.Geofence_Action := Unsigned_8'Mod (Value);
         when others =>
            null;
      end case;
   end Set_Autopilot_Config;

   procedure Set_Gimbal_Track_Config (G : in out Gimbal_Track_Config_Record; S : Setting; Value : Integer_64; Index :
      Natural)
     with Pre => (S in Gimbal_Roll_Rc_Gain | Gimbal_Pitch_Rc_Thr_Gain | Gimbal_Pitch_Rc_Low_Gain |
       Gimbal_Pitch_Rc_High_Gain | Gimbal_Yaw_Rc_Gain | Gimbal_Roll_Gain | Gimbal_Roll_Offset | Gimbal_Roll_Limit |
       Gimbal_Pitch_Gain | Gimbal_Pitch_Offset | Gimbal_Pitch_Low_Limit | Gimbal_Pitch_High_Limit | Gimbal_Yaw_Gain
       | Gimbal_Yaw_Offset | Gimbal_Yaw_Limit | Gimbal_Stabilisation | Gimbal_Sensitivity | Gimbal_Uart) and then
       Index < Element_Count (S)
   is
      pragma Unreferenced (Index);
   begin
      case S is
         when Gimbal_Roll_Rc_Gain =>
            G.Gimbal_Roll_Rc_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Pitch_Rc_Thr_Gain =>
            G.Gimbal_Pitch_Rc_Thr_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Pitch_Rc_Low_Gain =>
            G.Gimbal_Pitch_Rc_Low_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Pitch_Rc_High_Gain =>
            G.Gimbal_Pitch_Rc_High_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Yaw_Rc_Gain =>
            G.Gimbal_Yaw_Rc_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Roll_Gain =>
            G.Gimbal_Roll_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Roll_Offset =>
            G.Gimbal_Roll_Offset := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Roll_Limit =>
            G.Gimbal_Roll_Limit := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Pitch_Gain =>
            G.Gimbal_Pitch_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Pitch_Offset =>
            G.Gimbal_Pitch_Offset := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Pitch_Low_Limit =>
            G.Gimbal_Pitch_Low_Limit := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Pitch_High_Limit =>
            G.Gimbal_Pitch_High_Limit := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Yaw_Gain =>
            G.Gimbal_Yaw_Gain := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Yaw_Offset =>
            G.Gimbal_Yaw_Offset := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Yaw_Limit =>
            G.Gimbal_Yaw_Limit := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Stabilisation =>
            G.Gimbal_Stabilisation := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Sensitivity =>
            G.Gimbal_Sensitivity := Signed (Unsigned_8'Mod (Value));
         when Gimbal_Uart =>
            G.Gimbal_Uart := Signed (Unsigned_8'Mod (Value));
         when others =>
            null;
      end case;
   end Set_Gimbal_Track_Config;

   procedure Set (C : in out Configuration; S : Setting; Value : Integer_64; Profile : Natural := 0;
                  Index : Natural := 0)
   is
   begin
      case S is
         when Gyro_Hardware_Lpf | Gyro_Lpf1_Type | Gyro_Lpf1_Static_Hz | Gyro_Lpf2_Type | Gyro_Lpf2_Static_Hz |
           Gyro_Notch1_Hz | Gyro_Notch1_Cutoff | Gyro_Notch2_Hz | Gyro_Notch2_Cutoff | Gyro_Calib_Duration |
           Gyro_Calib_Noise_Limit | Gyro_Offset_Yaw | Gyro_Overflow_Detect | Yaw_Spin_Recovery | Yaw_Spin_Threshold
           | Gyro_Lpf1_Dyn_Min_Hz | Gyro_Lpf1_Dyn_Max_Hz | Gyro_Lpf1_Dyn_Expo | Gyro_Filter_Debug_Axis |
           Simplified_Gyro_Filter | Simplified_Gyro_Filter_Multiplier =>
            Set_Gyro_Config (C.Gyro_Config, S, Value, Index);
         when Dyn_Notch_Count | Dyn_Notch_Q | Dyn_Notch_Min_Hz | Dyn_Notch_Max_Hz =>
            Set_Dyn_Notch_Config (C.Dyn_Notch_Config, S, Value, Index);
         when Acc_Hardware | Acc_Lpf_Hz | Acc_Trim_Pitch | Acc_Trim_Roll | Acc_Calibration =>
            Set_Accelerometer_Config (C.Accelerometer_Config, S, Value, Index);
         when Align_Mag | Mag_Align_Roll | Mag_Align_Pitch | Mag_Align_Yaw | Mag_Bustype | Mag_I2c_Device |
           Mag_I2c_Address | Mag_Spi_Device | Mag_Hardware | Mag_Calibration =>
            Set_Compass_Config (C.Compass_Config, S, Value, Index);
         when Baro_Bustype | Baro_Spi_Device | Baro_I2c_Device | Baro_I2c_Address | Baro_Hardware | Baro_Drift =>
            Set_Barometer_Config (C.Barometer_Config, S, Value, Index);
         when Pitot_Bustype | Pitot_I2c_Device | Pitot_I2c_Address | Pitot_Hardware =>
            Set_Pitot_Config (C.Pitot_Config, S, Value, Index);
         when Mid_Rc | Min_Check | Max_Check | Rssi_Channel | Rssi_Src_Frame_Errors | Rssi_Scale | Rssi_Offset |
           Rssi_Invert | Rssi_Src_Frame_Lpf_Period | Rssi_Smoothing | Rc_Smoothing | Rc_Smoothing_Auto_Factor |
           Rc_Smoothing_Auto_Factor_Throttle | Rc_Smoothing_Setpoint_Cutoff | Rc_Smoothing_Throttle_Cutoff |
           Rc_Smoothing_Debug_Axis | Fpv_Mix_Degrees | Max_Aux_Channels | Serialrx_Provider | Serialrx_Inverted |
           Spektrum_Sat_Bind | Spektrum_Sat_Bind_Autoreset | Srxl2_Unit_Id | Srxl2_Baud_Fast | Sbus_Baud_Fast |
           Crsf_Use_Negotiated_Baud | Airmode_Start_Throttle_Percent | Rx_Min_Usec | Rx_Max_Usec |
           Serialrx_Halfduplex | Rx_Uart | Msp_Override_Channels_Mask | Msp_Override_Failsafe =>
            Set_Rx_Config (C.Rx_Config, S, Value, Index);
         when Rx_Spi_Protocol | Rx_Spi_Bus | Rx_Spi_Led_Inversion =>
            Set_Rx_Spi_Config (C.Rx_Spi_Config, S, Value, Index);
         when Adc_Device | Adc_Vrefint_Calibration | Adc_Tempsensor_Calibration30 | Adc_Tempsensor_Calibration110
           =>
            Set_Adc_Config (C.Adc_Config, S, Value, Index);
         when Input_Filtering_Mode =>
            Set_Pwm_Config (C.Pwm_Config, S, Value, Index);
         when Blackbox_Sample_Rate | Blackbox_Device | Blackbox_Disable_Pids | Blackbox_Disable_Rc |
           Blackbox_Disable_Setpoint | Blackbox_Disable_Bat | Blackbox_Disable_Mag | Blackbox_Disable_Alt |
           Blackbox_Disable_Rssi | Blackbox_Disable_Gyro | Blackbox_Disable_Gyrounfilt | Blackbox_Disable_Acc |
           Blackbox_Disable_Attitude | Blackbox_Disable_Debug | Blackbox_Disable_Motors | Blackbox_Disable_Servos |
           Blackbox_Disable_Rpm | Blackbox_Disable_Gps | Blackbox_Disable_Pitot | Blackbox_Mode |
           Blackbox_High_Resolution | Blackbox_Uart | Blackbox_Baud =>
            Set_Blackbox_Config (C.Blackbox_Config, S, Value, Index);
         when Max_Throttle | Min_Command | Motor_Kv | Motor_Idle | Dshot_Burst | Dshot_Bidir | Dshot_Edt |
           Dshot_Bitbang | Dshot_Bitbang_Timer | Use_Unsynced_Pwm | Motor_Pwm_Protocol | Motor_Pwm_Rate |
           Motor_Pwm_Inversion | Motor_Poles | Motor_Output_Reordering =>
            Set_Motor_Config (C.Motor_Config, S, Value, Index);
         when Thr_Corr_Value | Thr_Corr_Angle =>
            Set_Throttle_Correction_Config (C.Throttle_Correction_Config, S, Value, Index);
         when Failsafe_Delay | Failsafe_Landing_Time | Failsafe_Throttle | Failsafe_Switch_Mode |
           Failsafe_Throttle_Low_Delay | Failsafe_Procedure | Failsafe_Recovery_Delay | Failsafe_Stick_Threshold =>
            Set_Failsafe_Config (C.Failsafe_Config, S, Value, Index);
         when Align_Board_Roll | Align_Board_Pitch | Align_Board_Yaw =>
            Set_Board_Alignment (C.Board_Alignment, S, Value, Index);
         when Gimbal_Mode =>
            Set_Gimbal_Config (C.Gimbal_Config, S, Value, Index);
         when Bat_Capacity | Vbat_Max_Cell_Voltage | Vbat_Full_Cell_Voltage | Vbat_Min_Cell_Voltage |
           Vbat_Warning_Cell_Voltage | Cbat_Alert_Percent | Force_Battery_Cell_Count =>
            Set_Battery_Profiles_Profile (C.Battery_Profiles (Profile), S, Value, Index);
         when Vbat_Hysteresis | Current_Meter | Battery_Meter | Vbat_Detect_Cell_Voltage | Use_Vbat_Alerts |
           Use_Cbat_Alerts | Vbat_Cutoff_Percent | Vbat_Display_Lpf_Period | Vbat_Sag_Lpf_Period | Ibat_Lpf_Period
           | Vbat_Duration_For_Warning | Vbat_Duration_For_Critical | Battery_Continue =>
            Set_Battery_Config (C.Battery_Config, S, Value, Index);
         when Vbat_Scale | Vbat_Divider | Vbat_Multiplier =>
            Set_Voltage_Sensor_Adc_Config (C.Voltage_Sensor_Adc_Config, S, Value, Index);
         when Ibata_Scale | Ibata_Offset =>
            Set_Current_Sensor_Adc_Config (C.Current_Sensor_Adc_Config, S, Value, Index);
         when Ibatv_Scale | Ibatv_Offset =>
            Set_Current_Sensor_Virtual_Config (C.Current_Sensor_Virtual_Config, S, Value, Index);
         when Beeper_Inversion | Beeper_Od | Beeper_Frequency =>
            Set_Beeper_Dev_Config (C.Beeper_Dev_Config, S, Value, Index);
         when Beeper_Dshot_Beacon_Tone =>
            Set_Beeper_Config (C.Beeper_Config, S, Value, Index);
         when Yaw_Motors_Reversed | Mixer_Type | Crashflip_Motor_Percent | Crashflip_Rate | Crashflip_Auto_Rearm
           | Rpm_Limit | Rpm_Limit_P | Rpm_Limit_I | Rpm_Limit_D | Rpm_Limit_Value =>
            Set_Mixer_Config (C.Mixer_Config, S, Value, Index);
         when Three_D_Deadband_Low | Three_D_Deadband_High | Three_D_Neutral | Three_D_Deadband_Throttle |
           Three_D_Limit_Low | Three_D_Limit_High | Three_D_Switched_Mode =>
            Set_Flight3_D_Config (C.Flight3_D_Config, S, Value, Index);
         when Servo_Center_Pulse | Servo_Pwm_Rate | Servo_Lowpass_Hz | Tri_Unarmed_Servo |
           Channel_Forwarding_Start =>
            Set_Servo_Config (C.Servo_Config, S, Value, Index);
         when Thr_Mid | Thr_Expo | Thr_Hover | Rates_Type | Quickrates_Rc_Expo | Roll_Rc_Rate | Pitch_Rc_Rate |
           Yaw_Rc_Rate | Roll_Expo | Pitch_Expo | Yaw_Expo | Roll_Srate | Pitch_Srate | Yaw_Srate |
           Throttle_Limit_Type | Throttle_Limit_Percent | Roll_Rate_Limit | Pitch_Rate_Limit | Yaw_Rate_Limit =>
            Set_Control_Rate_Profiles_Profile (C.Control_Rate_Profiles (Profile), S, Value, Index);
         when Reboot_Character | Serial_Update_Rate_Hz =>
            Set_Serial_Config (C.Serial_Config, S, Value, Index);
         when Imu_Dcm_Kp | Imu_Dcm_Ki | Small_Angle | Imu_Process_Denom | Mag_Declination =>
            Set_Imu_Config (C.Imu_Config, S, Value, Index);
         when Auto_Disarm_Delay | Gyro_Cal_On_First_Arm | Prearm_Allow_Rearm =>
            Set_Arming_Config (C.Arming_Config, S, Value, Index);
         when Gps_Provider | Gps_Sbas_Mode | Gps_Auto_Config | Gps_Auto_Baud | Gps_Ublox_Acquire_Model |
           Gps_Ublox_Flight_Model | Gps_Update_Rate_Hz | Gps_Ublox_Utc_Standard | Gps_Ublox_Use_Galileo |
           Gps_Ublox_Enable_Ana | Gps_Set_Home_Point_Once | Gps_Use_3d_Speed | Gps_Sbas_Integrity | Gps_Uart |
           Gps_Baud =>
            Set_Gps_Config (C.Gps_Config, S, Value, Index);
         when Gps_Rescue_Min_Start_Dist | Gps_Rescue_Alt_Mode | Gps_Rescue_Initial_Climb | Gps_Rescue_Ascend_Rate
           | Gps_Rescue_Return_Alt | Gps_Rescue_Ground_Speed | Gps_Rescue_Descent_Dist | Gps_Rescue_Descend_Rate |
           Gps_Rescue_Sanity_Checks | Gps_Rescue_Min_Sats | Gps_Rescue_Allow_Arming_Without_Fix | Gps_Rescue_Yaw_P
           =>
            Set_Gps_Rescue_Config (C.Gps_Rescue_Config, S, Value, Index);
         when Gps_Lap_Timer_Gate_Lat | Gps_Lap_Timer_Gate_Lon | Gps_Lap_Timer_Min_Lap_Time_S |
           Gps_Lap_Timer_Gate_Tolerance_M =>
            Set_Gps_Lap_Timer_Config (C.Gps_Lap_Timer_Config, S, Value, Index);
         when Deadband | Yaw_Deadband | Yaw_Control_Reversed =>
            Set_Rc_Controls_Config (C.Rc_Controls_Config, S, Value, Index);
         when Alt_Hold_Climb_Rate | Alt_Hold_Deadband =>
            Set_Alt_Hold_Config (C.Alt_Hold_Config, S, Value, Index);
         when Pos_Hold_Deadband | Poshold_Position_Source | Poshold_Opticalflow_Quality_Min |
           Poshold_Opticalflow_Max_Range =>
            Set_Pos_Hold_Config (C.Pos_Hold_Config, S, Value, Index);
         when Pid_Process_Denom | Runaway_Takeoff_Prevention | Runaway_Takeoff_Deactivate_Delay |
           Runaway_Takeoff_Deactivate_Throttle_Percent =>
            Set_Pid_Config (C.Pid_Config, S, Value, Index);
         when Dterm_Lpf1_Dyn_Min_Hz | Dterm_Lpf1_Dyn_Max_Hz | Dterm_Lpf1_Dyn_Expo | Dterm_Lpf1_Type |
           Dterm_Lpf1_Static_Hz | Dterm_Lpf2_Type | Dterm_Lpf2_Static_Hz | Dterm_Notch_Hz | Dterm_Notch_Cutoff |
           Vbat_Sag_Compensation | Pid_At_Min_Throttle | Anti_Gravity_Gain | Anti_Gravity_Cutoff_Hz |
           Anti_Gravity_P_Gain | Acc_Limit_Yaw | Acc_Limit | Crash_Dthreshold | Crash_Gthreshold |
           Crash_Setpoint_Threshold | Crash_Time | Crash_Delay | Crash_Recovery_Angle | Crash_Recovery_Rate |
           Crash_Limit_Yaw | Crash_Recovery | Iterm_Rotation | Iterm_Relax | Iterm_Relax_Type | Iterm_Relax_Cutoff
           | Iterm_Windup | Pidsum_Limit | Pidsum_Limit_Yaw | Yaw_Lowpass_Hz | Throttle_Boost |
           Throttle_Boost_Cutoff | Acro_Trainer_Angle_Limit | Acro_Trainer_Lookahead_Ms | Acro_Trainer_Debug_Axis |
           Acro_Trainer_Gain | P_Pitch | I_Pitch | D_Pitch | F_Pitch | P_Roll | I_Roll | D_Roll | F_Roll | P_Yaw |
           I_Yaw | D_Yaw | F_Yaw | Angle_P_Gain | Angle_Feedforward | Angle_Feedforward_Smoothing_Ms | Angle_Limit
           | Angle_Earth_Ref | Horizon_Level_Strength | Horizon_Limit_Sticks | Horizon_Limit_Degrees |
           Horizon_Ignore_Sticks | Horizon_Delay_Ms | Chirp_Lag_Freq_Hz | Chirp_Lead_Freq_Hz | Chirp_Amplitude_Roll
           | Chirp_Amplitude_Pitch | Chirp_Amplitude_Yaw | Chirp_Frequency_Start_Deci_Hz |
           Chirp_Frequency_End_Deci_Hz | Chirp_Time_Seconds | Chirp_Repeat | D_Max_Roll | D_Max_Pitch | D_Max_Yaw |
           D_Max_Gain | D_Max_Advance | Motor_Output_Limit | Auto_Profile_Cell_Count | Launch_Control_Mode |
           Launch_Trigger_Allow_Reset | Launch_Trigger_Throttle_Percent | Launch_Angle_Limit | Launch_Control_Gain
           | Thrust_Linear | Feedforward_Transition | Feedforward_Averaging | Feedforward_Smooth_Factor |
           Feedforward_Jitter_Factor | Feedforward_Boost | Feedforward_Max_Rate_Limit | Feedforward_Yaw_Hold_Gain |
           Feedforward_Yaw_Hold_Time | Dyn_Idle_Min_Rpm | Dyn_Idle_P_Gain | Dyn_Idle_I_Gain | Dyn_Idle_D_Gain |
           Dyn_Idle_Max_Increase | Level_Race_Mode | Simplified_Pids_Mode | Simplified_Master_Multiplier |
           Simplified_I_Gain | Simplified_D_Gain | Simplified_Pi_Gain | Simplified_D_Max_Gain |
           Simplified_Feedforward_Gain | Simplified_Pitch_D_Gain | Simplified_Pitch_Pi_Gain |
           Simplified_Dterm_Filter | Simplified_Dterm_Filter_Multiplier | Tpa_Mode | Tpa_Rate | Tpa_Breakpoint |
           Tpa_Low_Rate | Tpa_Low_Breakpoint | Tpa_Low_Always | Ez_Landing_Threshold | Ez_Landing_Limit |
           Ez_Landing_Speed | Landing_Disarm_Threshold =>
            Set_Pid_Profiles_Profile (C.Pid_Profiles (Profile), S, Value, Index);
         when Tlm_Inverted | Tlm_Halfduplex | Telemetry_1_Protocol | Telemetry_1_Uart | Telemetry_1_Baud |
           Telemetry_2_Protocol | Telemetry_2_Uart | Telemetry_2_Baud | Telemetry_3_Protocol | Telemetry_3_Uart |
           Telemetry_3_Baud | Crsf_Tlm_Accgyro | Frsky_Default_Lat | Frsky_Default_Long | Frsky_Gps_Format |
           Frsky_Unit | Frsky_Vfas_Precision | Hott_Alarm_Int | Pid_In_Tlm | Report_Cell_Voltage | Ibus_Sensor |
           Mavlink_Mah_As_Heading_Divisor | Mavlink_Min_Txbuff | Mavlink_Ext_Status_Rate | Mavlink_Rc_Chan_Rate |
           Mavlink_Pos_Rate | Mavlink_Extra1_Rate | Mavlink_Extra2_Rate | Mavlink_Extra3_Rate |
           Telemetry_Disabled_Voltage | Telemetry_Disabled_Current | Telemetry_Disabled_Fuel |
           Telemetry_Disabled_Mode | Telemetry_Disabled_Acc_X | Telemetry_Disabled_Acc_Y | Telemetry_Disabled_Acc_Z
           | Telemetry_Disabled_Pitch | Telemetry_Disabled_Roll | Telemetry_Disabled_Heading |
           Telemetry_Disabled_Altitude | Telemetry_Disabled_Vario | Telemetry_Disabled_Lat_Long |
           Telemetry_Disabled_Ground_Speed | Telemetry_Disabled_Distance | Telemetry_Disabled_Esc_Current |
           Telemetry_Disabled_Esc_Voltage | Telemetry_Disabled_Esc_Rpm | Telemetry_Disabled_Esc_Temperature |
           Telemetry_Disabled_Temperature | Telemetry_Disabled_Cap_Used =>
            Set_Telemetry_Config (C.Telemetry_Config, S, Value, Index);
         when Ledstrip_Visual_Beeper | Ledstrip_Visual_Beeper_Color | Ledstrip_Grb_Rgb | Ledstrip_Profile |
           Ledstrip_Race_Color | Ledstrip_Beacon_Color | Ledstrip_Beacon_Period_Ms | Ledstrip_Beacon_Percent |
           Ledstrip_Beacon_Armed_Only | Ledstrip_Brightness | Ledstrip_Rainbow_Delta | Ledstrip_Rainbow_Freq =>
            Set_Led_Strip_Config (C.Led_Strip_Config, S, Value, Index);
         when Transponder_Provider | Transponder_Data =>
            Set_Transponder_Config (C.Transponder_Config, S, Value, Index);
         when Sdcard_Detect_Inverted | Sdcard_Mode =>
            Set_Sdcard_Config (C.Sdcard_Config, S, Value, Index);
         when Osd_Units | Osd_Warn_Bitmask | Osd_Rssi_Alarm | Osd_Link_Quality_Alarm | Osd_Rssi_Dbm_Alarm |
           Osd_Rsnr_Alarm | Osd_Cap_Alarm | Osd_Alt_Alarm | Osd_Distance_Alarm | Osd_Esc_Temp_Alarm |
           Osd_Esc_Rpm_Alarm | Osd_Esc_Current_Alarm | Osd_Core_Temp_Alarm | Osd_Ah_Max_Pit | Osd_Ah_Max_Rol |
           Osd_Ah_Invert | Osd_Logo_On_Arming | Osd_Logo_On_Arming_Duration | Osd_Arming_Logo | Osd_Use_Quick_Menu
           | Osd_Show_Spec_Prearm | Osd_Tim1 | Osd_Tim2 | Osd_Stick_Overlay_Radio_Mode | Osd_Stat_Bitmask |
           Osd_Profile | Osd_Gps_Sats_Show_Pdop | Osd_Displayport_Device | Osd_Uart | Osd_Rcchannels |
           Osd_Camera_Frame_Width | Osd_Camera_Frame_Height | Osd_Stat_Avg_Cell_Value | Osd_Framerate_Hz |
           Osd_Menu_Background | Osd_Aux_Channel | Osd_Aux_Scale | Osd_Aux_Symbol | Osd_Craftname_Msgs |
           Osd_Custom_Text_Uart | Osd_Custom_Text_Baud =>
            Set_Osd_Config (C.Osd_Config, S, Value, Index);
         when Osd_Vbat_Pos | Osd_Rssi_Pos | Osd_Link_Quality_Pos | Osd_Link_Tx_Power_Pos | Osd_Rssi_Dbm_Pos |
           Osd_Rsnr_Pos | Osd_Tim_1_Pos | Osd_Tim_2_Pos | Osd_Remaining_Time_Estimate_Pos | Osd_Flymode_Pos |
           Osd_Anti_Gravity_Pos | Osd_G_Force_Pos | Osd_Throttle_Pos | Osd_Vtx_Channel_Pos | Osd_Crosshairs_Pos |
           Osd_Ah_Sbar_Pos | Osd_Ah_Pos | Osd_Current_Pos | Osd_Mah_Drawn_Pos | Osd_Wh_Drawn_Pos |
           Osd_Motor_Diag_Pos | Osd_Craft_Name_Pos | Osd_Pilot_Name_Pos | Osd_Gps_Speed_Pos | Osd_Gps_Lon_Pos |
           Osd_Gps_Lat_Pos | Osd_Gps_Lap_Curr_Pos | Osd_Gps_Lap_Prev_Pos | Osd_Gps_Lap_Best3_Pos | Osd_Gps_Sats_Pos
           | Osd_Home_Dir_Pos | Osd_Home_Dist_Pos | Osd_Flight_Dist_Pos | Osd_Compass_Bar_Pos | Osd_Altitude_Pos |
           Osd_Pid_Roll_Pos | Osd_Pid_Pitch_Pos | Osd_Pid_Yaw_Pos | Osd_Debug_Pos | Osd_Debug2_Pos | Osd_Power_Pos
           | Osd_Pidrate_Profile_Pos | Osd_Warnings_Pos | Osd_Avg_Cell_Voltage_Pos | Osd_Pit_Ang_Pos |
           Osd_Rol_Ang_Pos | Osd_Battery_Usage_Pos | Osd_Disarmed_Pos | Osd_Nheading_Pos |
           Osd_Up_Down_Reference_Pos | Osd_Ready_Mode_Pos | Osd_Pos_Hold_Ready_Pos | Osd_Nvario_Pos |
           Osd_Esc_Tmp_Pos | Osd_Esc_Rpm_Pos | Osd_Esc_Rpm_Freq_Pos | Osd_Rtc_Date_Time_Pos |
           Osd_Adjustment_Range_Pos | Osd_Flip_Arrow_Pos | Osd_Core_Temp_Pos | Osd_Log_Status_Pos |
           Osd_Stick_Overlay_Left_Pos | Osd_Stick_Overlay_Right_Pos | Osd_Rate_Profile_Name_Pos |
           Osd_Pid_Profile_Name_Pos | Osd_Battery_Profile_Name_Pos | Osd_Profile_Name_Pos | Osd_Rcchannels_Pos |
           Osd_Camera_Frame_Pos | Osd_Efficiency_Pos | Osd_Total_Flights_Pos | Osd_Aux_Pos |
           Osd_Sys_Goggle_Voltage_Pos | Osd_Sys_Vtx_Voltage_Pos | Osd_Sys_Bitrate_Pos | Osd_Sys_Delay_Pos |
           Osd_Sys_Distance_Pos | Osd_Sys_Lq_Pos | Osd_Sys_Goggle_Dvr_Pos | Osd_Sys_Vtx_Dvr_Pos |
           Osd_Sys_Warnings_Pos | Osd_Sys_Vtx_Temp_Pos | Osd_Sys_Fan_Speed_Pos | Osd_Lidar_Dist_Pos |
           Osd_Custom_Serial_Text_Pos | Osd_Wp_Number_Pos | Osd_Wp_Current_Lat_Pos | Osd_Wp_Current_Lon_Pos |
           Osd_Wp_Current_Alt_Pos | Osd_Wp_Distance_Pos | Osd_Wp_Direction_Pos | Osd_Wp_Next_Number_Pos |
           Osd_Wp_Eta_Pos | Osd_Nav_Map_Pos | Osd_Airspeed =>
            Set_Osd_Element_Config (C.Osd_Element_Config, S, Value, Index);
         when Osd_Custom_Serial_Text_Terminator =>
            Set_Osd_Custom_Text_Config (C.Osd_Custom_Text_Config, S, Value, Index);
         when Osd_Nav_Map_Mode | Osd_Nav_Map_Centre | Osd_Nav_Map_Min_Scale_M =>
            Set_Osd_Nav_Map_Config (C.Osd_Nav_Map_Config, S, Value, Index);
         when System_Hse_Mhz | Task_Statistics | Debug_Mode | Rate_6pos_Switch | Cpu_Overclock | Pwr_On_Arm_Grace
           | Enable_Stick_Arming =>
            Set_System_Config (C.System_Config, S, Value, Index);
         when Vtx_Band | Vtx_Channel | Vtx_Power | Vtx_Low_Power_Disarm | Vtx_Softserial_Alt | Vtx_Type |
           Vtx_Uart | Vtx_Freq | Vtx_Pit_Mode_Freq =>
            Set_Vtx_Settings_Config (C.Vtx_Settings_Config, S, Value, Index);
         when Vtx_Halfduplex =>
            Set_Vtx_Config (C.Vtx_Config, S, Value, Index);
         when Vtx_Spi_Bus =>
            Set_Vtx_Io_Config (C.Vtx_Io_Config, S, Value, Index);
         when Vcd_Video_System | Vcd_H_Offset | Vcd_V_Offset =>
            Set_Vcd_Profile (C.Vcd_Profile, S, Value, Index);
         when Max7456_Clock | Max7456_Spi_Bus | Max7456_Preinit_Opu =>
            Set_Max7456_Config (C.Max7456_Config, S, Value, Index);
         when Displayport_Msp_Col_Adjust | Displayport_Msp_Row_Adjust | Displayport_Msp_Fonts |
           Displayport_Msp_Use_Device_Blink =>
            Set_Display_Port_Profile_Msp (C.Display_Port_Profile_Msp, S, Value, Index);
         when Displayport_Max7456_Col_Adjust | Displayport_Max7456_Row_Adjust | Displayport_Max7456_Inv |
           Displayport_Max7456_Blk | Displayport_Max7456_Wht =>
            Set_Display_Port_Profile_Max7456 (C.Display_Port_Profile_Max7456, S, Value, Index);
         when Esc_Sensor_Halfduplex | Esc_Sensor_Current_Offset | Esc_Sensor_Uart =>
            Set_Esc_Sensor_Config (C.Esc_Sensor_Config, S, Value, Index);
         when Frsky_Spi_Autobind | Frsky_Spi_Tx_Id | Frsky_Spi_Offset | Frsky_Spi_Bind_Hop_Data | Frsky_X_Rx_Num
           | Frsky_Spi_A1_Source | Cc2500_Spi_Chip_Detect =>
            Set_Rx_Cc2500_Spi_Config (C.Rx_Cc2500_Spi_Config, S, Value, Index);
         when Led_Inversion =>
            Set_Status_Led_Config (C.Status_Led_Config, S, Value, Index);
         when Dashboard_I2c_Bus | Dashboard_I2c_Addr =>
            Set_Dashboard_Config (C.Dashboard_Config, S, Value, Index);
         when Rangefinder_Hardware | Rangefinder_Uart =>
            Set_Rangefinder_Config (C.Rangefinder_Config, S, Value, Index);
         when Opticalflow_Hardware | Opticalflow_Uart | Opticalflow_Rotation | Opticalflow_Flip_X =>
            Set_Opticalflow_Config (C.Opticalflow_Config, S, Value, Index);
         when Pinio_Config =>
            Set_Pinio_Config (C.Pinio_Config, S, Value, Index);
         when Pinio_Box =>
            Set_Pinio_Box_Config (C.Pinio_Box_Config, S, Value, Index);
         when Usb_Hid_Cdc | Usb_Msc_Pin_Pullup =>
            Set_Usb_Dev_Config (C.Usb_Dev_Config, S, Value, Index);
         when Flash_Spi_Bus =>
            Set_Flash_Config (C.Flash_Config, S, Value, Index);
         when Rcdevice_Init_Dev_Attempts | Rcdevice_Init_Dev_Attempt_Interval | Rcdevice_Protocol_Version |
           Rcdevice_Feature | Rcdevice_Uart =>
            Set_Rcdevice_Config (C.Rcdevice_Config, S, Value, Index);
         when Gyro_1_Bustype | Gyro_1_Spibus | Gyro_1_I2c_Bus | Gyro_1_I2c_Address =>
            Set_Gyro_Device_Config (C.Gyro_Device_Config, S, Value, Index);
         when I2c1_Pullup | I2c1_Clockspeed_Khz | I2c2_Pullup | I2c2_Clockspeed_Khz | I2c3_Pullup |
           I2c3_Clockspeed_Khz =>
            Set_I2c_Config (C.I2c_Config, S, Value, Index);
         when Mco2_On_Pc9 =>
            Set_Mco_Config (C.Mco_Config, S, Value, Index);
         when Spektrum_Spi_Protocol | Spektrum_Spi_Mfg_Id | Spektrum_Spi_Num_Channels =>
            Set_Spektrum_Config (C.Spektrum_Config, S, Value, Index);
         when Expresslrs_Uid | Expresslrs_Domain | Expresslrs_Model_Id =>
            Set_Rx_Express_Lrs_Spi_Config (C.Rx_Express_Lrs_Spi_Config, S, Value, Index);
         when Scheduler_Relax_Rx | Scheduler_Relax_Osd | Scheduler_Debug_Task | Cpu_Late_Limit_Permille =>
            Set_Scheduler_Config (C.Scheduler_Config, S, Value, Index);
         when Serialmsp_Halfduplex | Msp_1_Uart | Msp_1_Baud | Msp_2_Uart | Msp_2_Baud | Msp_3_Uart | Msp_3_Baud
           =>
            Set_Msp_Config (C.Msp_Config, S, Value, Index);
         when Timezone_Offset_Minutes =>
            Set_Time_Config (C.Time_Config, S, Value, Index);
         when Rpm_Filter_Harmonics | Rpm_Filter_Weights | Rpm_Filter_Q | Rpm_Filter_Min_Hz |
           Rpm_Filter_Fade_Range_Hz | Rpm_Filter_Lpf_Hz =>
            Set_Rpm_Filter_Config (C.Rpm_Filter_Config, S, Value, Index);
         when Flysky_Spi_Tx_Id | Flysky_Spi_Rf_Channels =>
            Set_Fly_Sky_Config (C.Fly_Sky_Config, S, Value, Index);
         when Stats_Min_Armed_Time_S | Stats_Total_Flights | Stats_Total_Time_S | Stats_Total_Dist_M |
           Stats_Save_Move_Limit | Stats_Mah_Used =>
            Set_Stats_Config (C.Stats_Config, S, Value, Index);
         when Altitude_Source | Altitude_Prefer_Baro | Altitude_Lpf | Rangefinder_Max_Range_Cm | Altitude_D_Lpf
           =>
            Set_Position_Config (C.Position_Config, S, Value, Index);
         when Ap_Landing_Altitude_M | Ap_Hover_Throttle | Ap_Throttle_Min | Ap_Throttle_Max | Ap_Altitude_P |
           Ap_Altitude_I | Ap_Altitude_D | Ap_Altitude_A | Ap_Altitude_F | Ap_Position_P | Ap_Position_I |
           Ap_Position_D | Ap_Position_A | Ap_Position_F | Ap_Position_Cutoff | Ap_Stop_Threshold | Ap_Max_Angle |
           Ap_Max_Yaw_Rate | Ap_Yaw_P | Ap_Velocity_Drag_Coeff | Ap_Max_Velocity | Ap_Waypoint_Arrival_Radius |
           Ap_Waypoint_Hold_Radius | Ap_Stick_Deadband | Ap_Throttle_Deadband | Ap_Yaw_Mode |
           Ap_Min_Forward_Velocity | Ap_Nav_Corner_Speed | Ap_Nav_Corner_Delta_V | Ap_Nav_Decel | Ap_Nav_Accel |
           Ap_Nav_Carrot_Lead_Time | Ap_Nav_Carrot_Lead_Max | Ap_Nav_Preturn_Dist | Ap_Velocity_Buildup_Max_Pitch |
           Ap_Max_Turn_Rate | Ap_Hold_Orbit_Radius | Ap_Hold_Figure8_Width | Ap_Landing_Descent_Rate |
           Ap_Landing_Detection_Time | Ap_Landing_Spiral_Enable | Ap_Landing_Spiral_Radius | Ap_Landing_Spiral_Rate
           | Ap_Landing_Velocity_Threshold | Ap_Landing_Throttle_Threshold | Ap_L1_Enable | Ap_L1_Period |
           Ap_L1_Min_Lookahead | Ap_L1_Max_Lookahead | Ap_L1_Max_Cross_Track_Error | Ap_L1_Turn_Rate |
           Ap_Min_Nav_Altitude_M | Ap_Rx_Loss_Policy | Ap_Max_Distance_From_Home | Ap_Geofence_Action =>
            Set_Autopilot_Config (C.Autopilot_Config, S, Value, Index);
         when Gimbal_Roll_Rc_Gain | Gimbal_Pitch_Rc_Thr_Gain | Gimbal_Pitch_Rc_Low_Gain |
           Gimbal_Pitch_Rc_High_Gain | Gimbal_Yaw_Rc_Gain | Gimbal_Roll_Gain | Gimbal_Roll_Offset |
           Gimbal_Roll_Limit | Gimbal_Pitch_Gain | Gimbal_Pitch_Offset | Gimbal_Pitch_Low_Limit |
           Gimbal_Pitch_High_Limit | Gimbal_Yaw_Gain | Gimbal_Yaw_Offset | Gimbal_Yaw_Limit | Gimbal_Stabilisation
           | Gimbal_Sensitivity | Gimbal_Uart =>
            Set_Gimbal_Track_Config (C.Gimbal_Track_Config, S, Value, Index);
         when others =>
            null;
      end case;
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
