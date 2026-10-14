package body Adaflight.Settings_Table with SPARK_Mode is
   use type Interfaces.Integer_64;

   Infos : constant array (Setting) of Info :=
     (Gyro_Hardware_Lpf =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gyro_Hardware_Lpf, Group => 10, others => <>),
      Gyro_Lpf1_Type =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gyro_Lpf_Type, Group => 10, others => <>),
      Gyro_Lpf1_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Lpf2_Type =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gyro_Lpf_Type, Group => 10, others => <>),
      Gyro_Lpf2_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Notch1_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Notch1_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Notch2_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Notch2_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Calib_Duration =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 3000, Group => 10, others => <>),
      Gyro_Calib_Noise_Limit =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 10, others => <>),
      Gyro_Offset_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Min => -1000, Max => 1000, Group => 10, others => <>),
      Gyro_Overflow_Detect =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gyro_Overflow_Check, Group => 10, others => <>),
      Yaw_Spin_Recovery =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On_Auto, Group => 10, others => <>),
      Yaw_Spin_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Min => 500, Max => 1950, Group => 10, others => <>),
      Dyn_Notch_Count =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 7, Group => 554, others => <>),
      Dyn_Notch_Q =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 1000, Group => 554, others => <>),
      Dyn_Notch_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 250, Group => 554, others => <>),
      Dyn_Notch_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 200, Max => 1000, Group => 554, others => <>),
      Gyro_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 10, others => <>),
      Gyro_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 10, Group => 10, others => <>),
      Gyro_Filter_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gyro_Filter_Debug, Group => 10, others => <>),
      Acc_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Acc_Hardware, Group => 35, others => <>),
      Acc_Lpf_Hz => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 500, Group => 35, others => <>),
      Acc_Trim_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Min => -300, Max => 300, Group => 35, others => <>),
      Acc_Trim_Roll =>
        (Kind => I16, Where => Master, How => Direct, Min => -300, Max => 300, Group => 35, others => <>),
      Acc_Calibration => (Kind => I16, Where => Master, How => List, Count => 4, Group => 35, others => <>),
      Align_Mag =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Alignment, Group => 40, others => <>),
      Mag_Align_Roll =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -3600, Max => 3600, Group => 40, others => <>),
      Mag_Align_Pitch =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -3600, Max => 3600, Group => 40, others => <>),
      Mag_Align_Yaw =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -3600, Max => 3600, Group => 40, others => <>),
      Mag_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Bus_Type, Group => 40, others => <>),
      Mag_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 40, others => <>),
      Mag_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Group => 40, others => <>),
      Mag_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 40, others => <>),
      Mag_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Mag_Hardware, Group => 40, others => <>),
      Mag_Calibration => (Kind => I16, Where => Master, How => List, Count => 3, Group => 40, others => <>),
      Baro_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Bus_Type, Group => 38, others => <>),
      Baro_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 5, Group => 38, others => <>),
      Baro_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 5, Group => 38, others => <>),
      Baro_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Group => 38, others => <>),
      Baro_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baro_Hardware, Group => 38, others => <>),
      Baro_Drift =>
        (Kind => I16, Where => Master, How => Direct, Min => -500, Max => 500, Group => 38, others => <>),
      Pitot_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Bus_Type, Group => 569, others => <>),
      Pitot_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 5, Group => 569, others => <>),
      Pitot_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Group => 569, others => <>),
      Pitot_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Pitot_Hardware, Group => 569, others => <>),
      Mid_Rc => (Kind => U16, Where => Master, How => Direct, Min => 1200, Max => 1700, Group => 24, others => <>),
      Min_Check => (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 24, others => <>),
      Max_Check => (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 24, others => <>),
      Rssi_Channel => (Kind => I8, Where => Master, How => Direct, Min => 0, Max => 18, Group => 24, others => <>),
      Rssi_Src_Frame_Errors =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Rssi_Scale => (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Group => 24, others => <>),
      Rssi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 24, others => <>),
      Rssi_Invert => (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Rssi_Src_Frame_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 24, others => <>),
      Rssi_Smoothing =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 24, others => <>),
      Rc_Smoothing => (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Rc_Smoothing_Auto_Factor =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Group => 24, others => <>),
      Rc_Smoothing_Auto_Factor_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Group => 24, others => <>),
      Rc_Smoothing_Setpoint_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 24, others => <>),
      Rc_Smoothing_Throttle_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 24, others => <>),
      Rc_Smoothing_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Rc_Smoothing_Debug, Group => 24, others => <>),
      Fpv_Mix_Degrees =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Group => 24, others => <>),
      Max_Aux_Channels =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 14, Group => 24, others => <>),
      Serialrx_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Serial_Rx, Group => 24, others => <>),
      Serialrx_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Spektrum_Sat_Bind =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 10, Group => 24, others => <>),
      Spektrum_Sat_Bind_Autoreset =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Srxl2_Unit_Id => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 15, Group => 24, others => <>),
      Srxl2_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Sbus_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Crsf_Use_Negotiated_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Airmode_Start_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 24, others => <>),
      Rx_Min_Usec =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 24, others => <>),
      Rx_Max_Usec =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 24, others => <>),
      Serialrx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Rx_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 24, others => <>),
      Msp_Override_Channels_Mask =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 262143, Group => 24, others => <>),
      Msp_Override_Failsafe =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 24, others => <>),
      Rx_Spi_Protocol =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Rx_Spi, Group => 537, others => <>),
      Rx_Spi_Bus => (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 537, others => <>),
      Rx_Spi_Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 537, others => <>),
      Adc_Device => (Kind => I8, Where => Hardware, How => Direct, Min => 0, Max => 1, Group => 510, others => <>),
      Adc_Vrefint_Calibration =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Group => 510, others => <>),
      Adc_Tempsensor_Calibration30 =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Group => 510, others => <>),
      Adc_Tempsensor_Calibration110 =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Group => 510, others => <>),
      Input_Filtering_Mode =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 508, others => <>),
      Blackbox_Sample_Rate =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Blackbox_Sample_Rate, Group => 5, others => <>),
      Blackbox_Device =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Blackbox_Device, Group => 5, others => <>),
      Blackbox_Disable_Pids => (Kind => U32, Where => Master, How => Bitset, Count => 0, Group => 5, others => <>),
      Blackbox_Disable_Rc => (Kind => U32, Where => Master, How => Bitset, Count => 1, Group => 5, others => <>),
      Blackbox_Disable_Setpoint =>
        (Kind => U32, Where => Master, How => Bitset, Count => 2, Group => 5, others => <>),
      Blackbox_Disable_Bat => (Kind => U32, Where => Master, How => Bitset, Count => 3, Group => 5, others => <>),
      Blackbox_Disable_Mag => (Kind => U32, Where => Master, How => Bitset, Count => 4, Group => 5, others => <>),
      Blackbox_Disable_Alt => (Kind => U32, Where => Master, How => Bitset, Count => 5, Group => 5, others => <>),
      Blackbox_Disable_Rssi => (Kind => U32, Where => Master, How => Bitset, Count => 6, Group => 5, others => <>),
      Blackbox_Disable_Gyro => (Kind => U32, Where => Master, How => Bitset, Count => 7, Group => 5, others => <>),
      Blackbox_Disable_Gyrounfilt =>
        (Kind => U32, Where => Master, How => Bitset, Count => 14, Group => 5, others => <>),
      Blackbox_Disable_Acc => (Kind => U32, Where => Master, How => Bitset, Count => 9, Group => 5, others => <>),
      Blackbox_Disable_Attitude =>
        (Kind => U32, Where => Master, How => Bitset, Count => 8, Group => 5, others => <>),
      Blackbox_Disable_Debug => (Kind => U32, Where => Master, How => Bitset, Count => 10, Group => 5, others => <>),
      Blackbox_Disable_Motors =>
        (Kind => U32, Where => Master, How => Bitset, Count => 11, Group => 5, others => <>),
      Blackbox_Disable_Servos =>
        (Kind => U32, Where => Master, How => Bitset, Count => 15, Group => 5, others => <>),
      Blackbox_Disable_Rpm => (Kind => U32, Where => Master, How => Bitset, Count => 13, Group => 5, others => <>),
      Blackbox_Disable_Gps => (Kind => U32, Where => Master, How => Bitset, Count => 12, Group => 5, others => <>),
      Blackbox_Disable_Pitot => (Kind => U32, Where => Master, How => Bitset, Count => 16, Group => 5, others => <>),
      Blackbox_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Blackbox_Mode, Group => 5, others => <>),
      Blackbox_High_Resolution =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 5, others => <>),
      Blackbox_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 5, others => <>),
      Blackbox_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 5, others => <>),
      Max_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 6, others => <>),
      Min_Command =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 6, others => <>),
      Motor_Kv => (Kind => U16, Where => Hardware, How => Direct, Min => 1, Max => 40000, Group => 6, others => <>),
      Motor_Idle => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Group => 6, others => <>),
      Dshot_Burst =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On_Auto, Group => 6, others => <>),
      Dshot_Bidir => (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 6, others => <>),
      Dshot_Edt => (Kind => U8, Where => Master, How => Lookup, Table => Table_Dshot_Edt, Group => 6, others => <>),
      Dshot_Bitbang =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On_Auto, Group => 6, others => <>),
      Dshot_Bitbang_Timer =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Dshot_Bitbanged_Timer, Group => 6, others => <>),
      Use_Unsynced_Pwm =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 6, others => <>),
      Motor_Pwm_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Motor_Pwm_Protocol, Group => 6, others => <>),
      Motor_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 200, Max => 32000, Group => 6, others => <>),
      Motor_Pwm_Inversion =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 6, others => <>),
      Motor_Poles => (Kind => U8, Where => Master, How => Direct, Min => 4, Max => 255, Group => 6, others => <>),
      Motor_Output_Reordering => (Kind => U8, Where => Master, How => List, Count => 8, Group => 6, others => <>),
      Thr_Corr_Value =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 150, Group => 39, others => <>),
      Thr_Corr_Angle =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 900, Group => 39, others => <>),
      Failsafe_Delay => (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 200, Group => 1, others => <>),
      Failsafe_Landing_Time =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Group => 1, others => <>),
      Failsafe_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 1, others => <>),
      Failsafe_Switch_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Failsafe_Switch_Mode, Group => 1, others => <>),
      Failsafe_Throttle_Low_Delay =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 300, Group => 1, others => <>),
      Failsafe_Procedure =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Failsafe, Group => 1, others => <>),
      Failsafe_Recovery_Delay =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 200, Group => 1, others => <>),
      Failsafe_Stick_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 1, others => <>),
      Align_Board_Roll =>
        (Kind => I16, Where => Master, How => Direct, Min => -180, Max => 360, Group => 2, others => <>),
      Align_Board_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Min => -180, Max => 360, Group => 2, others => <>),
      Align_Board_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Min => -180, Max => 360, Group => 2, others => <>),
      Gimbal_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gimbal_Mode, Group => 3, others => <>),
      Battery_Profile_Name =>
        (Kind => U8, Where => Battery_Profile, How => Text, Min_Length => 1, Count => 8, Write_Once => False, Group =>
         561, others => <>),
      Bat_Capacity =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 0, Max => 20000, Group => 561, others => <>),
      Vbat_Max_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Group => 561, others => <>),
      Vbat_Full_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Group => 561, others => <>),
      Vbat_Min_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Group => 561, others => <>),
      Vbat_Warning_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Group => 561, others => <>),
      Cbat_Alert_Percent =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Min => 0, Max => 100, Group => 561, others => <>),
      Force_Battery_Cell_Count =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Min => 0, Max => 24, Group => 561, others => <>),
      Vbat_Hysteresis =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Group => 11, others => <>),
      Current_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Current_Meter, Group => 11, others => <>),
      Battery_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Voltage_Meter, Group => 11, others => <>),
      Vbat_Detect_Cell_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Group => 11, others => <>),
      Use_Vbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 11, others => <>),
      Use_Cbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 11, others => <>),
      Vbat_Cutoff_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 11, others => <>),
      Vbat_Display_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Group => 11, others => <>),
      Vbat_Sag_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Group => 11, others => <>),
      Ibat_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 11, others => <>),
      Vbat_Duration_For_Warning =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 150, Group => 11, others => <>),
      Vbat_Duration_For_Critical =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 150, Group => 11, others => <>),
      Vbat_Scale => (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 255, Group => 258, others => <>),
      Vbat_Divider => (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Group => 258, others => <>),
      Vbat_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Group => 258, others => <>),
      Ibata_Scale =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -16000, Max => 16000, Group => 256, others => <>),
      Ibata_Offset =>
        (Kind => I16, Where => Master, How => Direct, Min => -32000, Max => 32000, Group => 256, others => <>),
      Ibatv_Scale =>
        (Kind => I16, Where => Master, How => Direct, Min => -16000, Max => 16000, Group => 257, others => <>),
      Ibatv_Offset =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 16000, Group => 257, others => <>),
      Battery_Continue =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 11, others => <>),
      Beeper_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 503, others => <>),
      Beeper_Od => (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 503, others => <>),
      Beeper_Frequency =>
        (Kind => I16, Where => Hardware, How => Direct, Min => 0, Max => 16000, Group => 503, others => <>),
      Beeper_Dshot_Beacon_Tone =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 5, Group => 502, others => <>),
      Yaw_Motors_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 20, others => <>),
      Mixer_Type =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Mixer_Type, Group => 20, others => <>),
      Crashflip_Motor_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 20, others => <>),
      Crashflip_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Group => 20, others => <>),
      Crashflip_Auto_Rearm =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 20, others => <>),
      Rpm_Limit => (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 20, others => <>),
      Rpm_Limit_P => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Group => 20, others => <>),
      Rpm_Limit_I => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 20, others => <>),
      Rpm_Limit_D => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Group => 20, others => <>),
      Rpm_Limit_Value =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 65535, Group => 20, others => <>),
      Three_D_Deadband_Low =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 1500, Group => 26, others => <>),
      Three_D_Deadband_High =>
        (Kind => U16, Where => Master, How => Direct, Min => 1500, Max => 2250, Group => 26, others => <>),
      Three_D_Neutral =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 26, others => <>),
      Three_D_Deadband_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 100, Group => 26, others => <>),
      Three_D_Limit_Low =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 1500, Group => 26, others => <>),
      Three_D_Limit_High =>
        (Kind => U16, Where => Master, How => Direct, Min => 1500, Max => 2250, Group => 26, others => <>),
      Three_D_Switched_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 26, others => <>),
      Servo_Center_Pulse =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Group => 52, others => <>),
      Servo_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 498, Group => 52, others => <>),
      Servo_Lowpass_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 400, Group => 52, others => <>),
      Tri_Unarmed_Servo =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 52, others => <>),
      Channel_Forwarding_Start =>
        (Kind => U8, Where => Master, How => Direct, Min => 4, Max => 18, Group => 52, others => <>),
      Rateprofile_Name =>
        (Kind => U8, Where => Rate_Profile, How => Text, Min_Length => 1, Count => 8, Write_Once => False, Group =>
         12, others => <>),
      Thr_Mid => (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Group => 12, others => <>),
      Thr_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Group => 12, others => <>),
      Thr_Hover =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Group => 12, others => <>),
      Rates_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Table => Table_Rates_Type, Group => 12, others => <>),
      Quickrates_Rc_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Table => Table_Off_On, Group => 12, others => <>),
      Roll_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 1, Max => 255, Group => 12, others => <>),
      Pitch_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 1, Max => 255, Group => 12, others => <>),
      Yaw_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 1, Max => 255, Group => 12, others => <>),
      Roll_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Group => 12, others => <>),
      Pitch_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Group => 12, others => <>),
      Yaw_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Group => 12, others => <>),
      Roll_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 255, Group => 12, others => <>),
      Pitch_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 255, Group => 12, others => <>),
      Yaw_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 255, Group => 12, others => <>),
      Throttle_Limit_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Table => Table_Throttle_Limit_Type, Group => 12, others =>
         <>),
      Throttle_Limit_Percent =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 25, Max => 100, Group => 12, others => <>),
      Roll_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Min => 200, Max => 1998, Group => 12, others => <>),
      Pitch_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Min => 200, Max => 1998, Group => 12, others => <>),
      Yaw_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Min => 200, Max => 1998, Group => 12, others => <>),
      Reboot_Character =>
        (Kind => U8, Where => Master, How => Direct, Min => 48, Max => 126, Group => 13, others => <>),
      Serial_Update_Rate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 2000, Group => 13, others => <>),
      Imu_Dcm_Kp => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32000, Group => 22, others => <>),
      Imu_Dcm_Ki => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32000, Group => 22, others => <>),
      Small_Angle => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 180, Group => 22, others => <>),
      Imu_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 4, Group => 22, others => <>),
      Mag_Declination =>
        (Kind => I16, Where => Master, How => Direct, Min => -300, Max => 300, Group => 22, others => <>),
      Auto_Disarm_Delay =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 60, Group => 16, others => <>),
      Gyro_Cal_On_First_Arm =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 16, others => <>),
      Prearm_Allow_Rearm =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 16, others => <>),
      Gps_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gps_Provider, Group => 30, others => <>),
      Gps_Sbas_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gps_Sbas_Mode, Group => 30, others => <>),
      Gps_Auto_Config =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 30, others => <>),
      Gps_Auto_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 30, others => <>),
      Gps_Ublox_Acquire_Model =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gps_Ublox_Models, Group => 30, others => <>),
      Gps_Ublox_Flight_Model =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gps_Ublox_Models, Group => 30, others => <>),
      Gps_Update_Rate_Hz =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 20, Group => 30, others => <>),
      Gps_Ublox_Utc_Standard =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gps_Ublox_Utc_Standard, Group => 30, others => <>),
      Gps_Ublox_Use_Galileo =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 30, others => <>),
      Gps_Ublox_Enable_Ana =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 30, others => <>),
      Gps_Set_Home_Point_Once =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 30, others => <>),
      Gps_Use_3d_Speed =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 30, others => <>),
      Gps_Sbas_Integrity =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 30, others => <>),
      Gps_Nmea_Custom_Commands =>
        (Kind => U8, Where => Master, How => Text, Min_Length => 1, Count => 64, Write_Once => False, Group => 30,
         others => <>),
      Gps_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 30, others => <>),
      Gps_Baud => (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 30, others => <>),
      Gps_Rescue_Min_Start_Dist =>
        (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 30, Group => 55, others => <>),
      Gps_Rescue_Alt_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gps_Rescue_Alt_Mode, Group => 55, others => <>),
      Gps_Rescue_Initial_Climb =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Group => 55, others => <>),
      Gps_Rescue_Ascend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 2500, Group => 55, others => <>),
      Gps_Rescue_Return_Alt =>
        (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 1000, Group => 55, others => <>),
      Gps_Rescue_Ground_Speed =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 3000, Group => 55, others => <>),
      Gps_Rescue_Descent_Dist =>
        (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 500, Group => 55, others => <>),
      Gps_Rescue_Descend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 25, Max => 500, Group => 55, others => <>),
      Gps_Rescue_Sanity_Checks =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Gps_Rescue_Sanity_Check, Group => 55, others => <>),
      Gps_Rescue_Min_Sats =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Group => 55, others => <>),
      Gps_Rescue_Allow_Arming_Without_Fix =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 55, others => <>),
      Gps_Rescue_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 55, others => <>),
      Gps_Lap_Timer_Gate_Lat =>
        (Kind => I32, Where => Master, How => Direct, Min => -900000000, Max => 900000000, Group => 58, others => <>),
      Gps_Lap_Timer_Gate_Lon =>
        (Kind => I32, Where => Master, How => Direct, Min => -1800000000, Max => 1800000000, Group => 58, others => <>),
      Gps_Lap_Timer_Min_Lap_Time_S =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 3000, Group => 58, others => <>),
      Gps_Lap_Timer_Gate_Tolerance_M =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 100, Group => 58, others => <>),
      Deadband => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 32, Group => 25, others => <>),
      Yaw_Deadband => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 25, others => <>),
      Yaw_Control_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 25, others => <>),
      Alt_Hold_Climb_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 59, others => <>),
      Alt_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 70, Group => 59, others => <>),
      Pos_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 61, others => <>),
      Poshold_Position_Source =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Poshold_Source, Group => 61, others => <>),
      Poshold_Opticalflow_Quality_Min =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 61, others => <>),
      Poshold_Opticalflow_Max_Range =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 1000, Group => 61, others => <>),
      Pid_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 16, Group => 504, others => <>),
      Runaway_Takeoff_Prevention =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 504, others => <>),
      Runaway_Takeoff_Deactivate_Delay =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 1000, Group => 504, others => <>),
      Runaway_Takeoff_Deactivate_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 504, others => <>),
      Profile_Name =>
        (Kind => U8, Where => PID_Profile, How => Text, Min_Length => 1, Count => 8, Write_Once => False, Group => 14,
         others => <>),
      Dterm_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Dterm_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Dterm_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 10, Group => 14, others => <>),
      Dterm_Lpf1_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Dterm_Lpf_Type, Group => 14, others => <>),
      Dterm_Lpf1_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Dterm_Lpf2_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Dterm_Lpf_Type, Group => 14, others => <>),
      Dterm_Lpf2_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Dterm_Notch_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Dterm_Notch_Cutoff =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Vbat_Sag_Compensation =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 150, Group => 14, others => <>),
      Pid_At_Min_Throttle =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Off_On, Group => 14, others => <>),
      Anti_Gravity_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      Anti_Gravity_Cutoff_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 2, Max => 50, Group => 14, others => <>),
      Anti_Gravity_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      Acc_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Group => 14, others => <>),
      Acc_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Group => 14, others => <>),
      Crash_Dthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 10, Max => 2000, Group => 14, others => <>),
      Crash_Gthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 2000, Group => 14, others => <>),
      Crash_Setpoint_Threshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 50, Max => 2000, Group => 14, others => <>),
      Crash_Time =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 5000, Group => 14, others => <>),
      Crash_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Group => 14, others => <>),
      Crash_Recovery_Angle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 5, Max => 30, Group => 14, others => <>),
      Crash_Recovery_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 50, Max => 255, Group => 14, others => <>),
      Crash_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Crash_Recovery =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Crash_Recovery, Group => 14, others => <>),
      Iterm_Rotation =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Off_On, Group => 14, others => <>),
      Iterm_Relax =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Iterm_Relax, Group => 14, others => <>),
      Iterm_Relax_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Iterm_Relax_Type, Group => 14, others => <>),
      Iterm_Relax_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 50, Group => 14, others => <>),
      Iterm_Windup =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 20, Max => 100, Group => 14, others => <>),
      Pidsum_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 1000, Group => 14, others => <>),
      Pidsum_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 1000, Group => 14, others => <>),
      Yaw_Lowpass_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Group => 14, others => <>),
      Throttle_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      Throttle_Boost_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 5, Max => 50, Group => 14, others => <>),
      Acro_Trainer_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 80, Group => 14, others => <>),
      Acro_Trainer_Lookahead_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 10, Max => 200, Group => 14, others => <>),
      Acro_Trainer_Debug_Axis =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Acro_Trainer_Debug, Group => 14, others => <>),
      Acro_Trainer_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 25, Max => 255, Group => 14, others => <>),
      P_Pitch => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      I_Pitch => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      D_Pitch => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      F_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      P_Roll => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      I_Roll => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      D_Roll => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      F_Roll => (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      P_Yaw => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      I_Yaw => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      D_Yaw => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      F_Yaw => (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Group => 14, others => <>),
      Angle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Angle_Feedforward =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Angle_Feedforward_Smoothing_Ms =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 250, Group => 14, others => <>),
      Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 80, Group => 14, others => <>),
      Angle_Earth_Ref =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      Horizon_Level_Strength =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      Horizon_Limit_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 200, Group => 14, others => <>),
      Horizon_Limit_Degrees =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 250, Group => 14, others => <>),
      Horizon_Ignore_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Off_On, Group => 14, others => <>),
      Horizon_Delay_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 10, Max => 5000, Group => 14, others => <>),
      Chirp_Lag_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 255, Group => 14, others => <>),
      Chirp_Lead_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 255, Group => 14, others => <>),
      Chirp_Amplitude_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Group => 14, others => <>),
      Chirp_Amplitude_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Group => 14, others => <>),
      Chirp_Amplitude_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Group => 14, others => <>),
      Chirp_Frequency_Start_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1, Max => 1000, Group => 14, others => <>),
      Chirp_Frequency_End_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1, Max => 10000, Group => 14, others => <>),
      Chirp_Time_Seconds =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 255, Group => 14, others => <>),
      Chirp_Repeat =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 9, Group => 14, others => <>),
      D_Max_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      D_Max_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      D_Max_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      D_Max_Advance =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Motor_Output_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 100, Group => 14, others => <>),
      Auto_Profile_Cell_Count =>
        (Kind => I8, Where => PID_Profile, How => Direct, Min => -1, Max => 8, Group => 14, others => <>),
      Launch_Control_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Launch_Control_Mode, Group => 14, others =>
         <>),
      Launch_Trigger_Allow_Reset =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Off_On, Group => 14, others => <>),
      Launch_Trigger_Throttle_Percent =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 90, Group => 14, others => <>),
      Launch_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 80, Group => 14, others => <>),
      Launch_Control_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Thrust_Linear =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 150, Group => 14, others => <>),
      Feedforward_Transition =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      Feedforward_Averaging =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Feedforward_Averaging, Group => 14, others =>
         <>),
      Feedforward_Smooth_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 95, Group => 14, others => <>),
      Feedforward_Jitter_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 20, Group => 14, others => <>),
      Feedforward_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 50, Group => 14, others => <>),
      Feedforward_Max_Rate_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Feedforward_Yaw_Hold_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      Feedforward_Yaw_Hold_Time =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 250, Group => 14, others => <>),
      Dyn_Idle_Min_Rpm =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Dyn_Idle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 250, Group => 14, others => <>),
      Dyn_Idle_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 250, Group => 14, others => <>),
      Dyn_Idle_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      Dyn_Idle_Max_Increase =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 255, Group => 14, others => <>),
      Level_Race_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Off_On, Group => 14, others => <>),
      Simplified_Pids_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Simplified_Tuning_Pids_Mode, Group => 14,
         others => <>),
      Simplified_Master_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_Feedforward_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_Pitch_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_Pitch_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Simplified_Dterm_Filter =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Off_On, Group => 14, others => <>),
      Simplified_Dterm_Filter_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 200, Group => 14, others => <>),
      Simplified_Gyro_Filter =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 10, others => <>),
      Simplified_Gyro_Filter_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 200, Group => 10, others => <>),
      Tpa_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Tpa_Mode, Group => 14, others => <>),
      Tpa_Rate => (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      Tpa_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1000, Max => 2000, Group => 14, others => <>),
      Tpa_Low_Rate =>
        (Kind => I8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Group => 14, others => <>),
      Tpa_Low_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1000, Max => 2000, Group => 14, others => <>),
      Tpa_Low_Always =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Table => Table_Off_On, Group => 14, others => <>),
      Ez_Landing_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Group => 14, others => <>),
      Ez_Landing_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 75, Group => 14, others => <>),
      Ez_Landing_Speed =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      Landing_Disarm_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Group => 14, others => <>),
      Tlm_Inverted => (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 31, others => <>),
      Tlm_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 31, others => <>),
      Telemetry_1_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Telemetry_Protocol, Group => 31, others => <>),
      Telemetry_1_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 31, others => <>),
      Telemetry_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 31, others => <>),
      Telemetry_2_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Telemetry_Protocol, Group => 31, others => <>),
      Telemetry_2_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 31, others => <>),
      Telemetry_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 31, others => <>),
      Telemetry_3_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Telemetry_Protocol, Group => 31, others => <>),
      Telemetry_3_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 31, others => <>),
      Telemetry_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 31, others => <>),
      Crsf_Tlm_Accgyro =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 31, others => <>),
      Frsky_Default_Lat =>
        (Kind => I16, Where => Master, How => Direct, Min => -9000, Max => 9000, Group => 31, others => <>),
      Frsky_Default_Long =>
        (Kind => I16, Where => Master, How => Direct, Min => -18000, Max => 18000, Group => 31, others => <>),
      Frsky_Gps_Format =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Group => 31, others => <>),
      Frsky_Unit => (Kind => U8, Where => Master, How => Lookup, Table => Table_Unit, Group => 31, others => <>),
      Frsky_Vfas_Precision =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Group => 31, others => <>),
      Hott_Alarm_Int =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 120, Group => 31, others => <>),
      Pid_In_Tlm => (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 31, others => <>),
      Report_Cell_Voltage =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 31, others => <>),
      Ibus_Sensor => (Kind => U8, Where => Master, How => List, Count => 15, Group => 31, others => <>),
      Mavlink_Mah_As_Heading_Divisor =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 30000, Group => 31, others => <>),
      Mavlink_Min_Txbuff =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 100, Group => 31, others => <>),
      Mavlink_Ext_Status_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 31, others => <>),
      Mavlink_Rc_Chan_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 31, others => <>),
      Mavlink_Pos_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 31, others => <>),
      Mavlink_Extra1_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 31, others => <>),
      Mavlink_Extra2_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 31, others => <>),
      Mavlink_Extra3_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 31, others => <>),
      Telemetry_Disabled_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Count => 0, Group => 31, others => <>),
      Telemetry_Disabled_Current =>
        (Kind => U32, Where => Master, How => Bitset, Count => 1, Group => 31, others => <>),
      Telemetry_Disabled_Fuel =>
        (Kind => U32, Where => Master, How => Bitset, Count => 2, Group => 31, others => <>),
      Telemetry_Disabled_Mode =>
        (Kind => U32, Where => Master, How => Bitset, Count => 3, Group => 31, others => <>),
      Telemetry_Disabled_Acc_X =>
        (Kind => U32, Where => Master, How => Bitset, Count => 4, Group => 31, others => <>),
      Telemetry_Disabled_Acc_Y =>
        (Kind => U32, Where => Master, How => Bitset, Count => 5, Group => 31, others => <>),
      Telemetry_Disabled_Acc_Z =>
        (Kind => U32, Where => Master, How => Bitset, Count => 6, Group => 31, others => <>),
      Telemetry_Disabled_Pitch =>
        (Kind => U32, Where => Master, How => Bitset, Count => 7, Group => 31, others => <>),
      Telemetry_Disabled_Roll =>
        (Kind => U32, Where => Master, How => Bitset, Count => 8, Group => 31, others => <>),
      Telemetry_Disabled_Heading =>
        (Kind => U32, Where => Master, How => Bitset, Count => 9, Group => 31, others => <>),
      Telemetry_Disabled_Altitude =>
        (Kind => U32, Where => Master, How => Bitset, Count => 10, Group => 31, others => <>),
      Telemetry_Disabled_Vario =>
        (Kind => U32, Where => Master, How => Bitset, Count => 11, Group => 31, others => <>),
      Telemetry_Disabled_Lat_Long =>
        (Kind => U32, Where => Master, How => Bitset, Count => 12, Group => 31, others => <>),
      Telemetry_Disabled_Ground_Speed =>
        (Kind => U32, Where => Master, How => Bitset, Count => 13, Group => 31, others => <>),
      Telemetry_Disabled_Distance =>
        (Kind => U32, Where => Master, How => Bitset, Count => 14, Group => 31, others => <>),
      Telemetry_Disabled_Esc_Current =>
        (Kind => U32, Where => Master, How => Bitset, Count => 15, Group => 31, others => <>),
      Telemetry_Disabled_Esc_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Count => 16, Group => 31, others => <>),
      Telemetry_Disabled_Esc_Rpm =>
        (Kind => U32, Where => Master, How => Bitset, Count => 17, Group => 31, others => <>),
      Telemetry_Disabled_Esc_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Count => 18, Group => 31, others => <>),
      Telemetry_Disabled_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Count => 19, Group => 31, others => <>),
      Telemetry_Disabled_Cap_Used =>
        (Kind => U32, Where => Master, How => Bitset, Count => 20, Group => 31, others => <>),
      Ledstrip_Visual_Beeper =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 27, others => <>),
      Ledstrip_Visual_Beeper_Color =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Ledstrip_Color, Group => 27, others => <>),
      Ledstrip_Grb_Rgb =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Rgb_Grb, Group => 27, others => <>),
      Ledstrip_Profile =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Led_Profile, Group => 27, others => <>),
      Ledstrip_Race_Color =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Ledstrip_Color, Group => 27, others => <>),
      Ledstrip_Beacon_Color =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Ledstrip_Color, Group => 27, others => <>),
      Ledstrip_Beacon_Period_Ms =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 10000, Group => 27, others => <>),
      Ledstrip_Beacon_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 27, others => <>),
      Ledstrip_Beacon_Armed_Only =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 27, others => <>),
      Ledstrip_Brightness =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 100, Group => 27, others => <>),
      Ledstrip_Rainbow_Delta =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 359, Group => 27, others => <>),
      Ledstrip_Rainbow_Freq =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 2000, Group => 27, others => <>),
      Transponder_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Transponder_Provider, Group => 17, others => <>),
      Transponder_Data => (Kind => U8, Where => Master, How => List, Count => 9, Group => 17, others => <>),
      Sdcard_Detect_Inverted =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 511, others => <>),
      Sdcard_Mode =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Sdcard_Mode, Group => 511, others => <>),
      Osd_Units => (Kind => U8, Where => Master, How => Lookup, Table => Table_Unit, Group => 501, others => <>),
      Osd_Warn_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Group => 501, others => <>),
      Osd_Rssi_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 501, others => <>),
      Osd_Link_Quality_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Group => 501, others => <>),
      Osd_Rssi_Dbm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -130, Max => 0, Group => 501, others => <>),
      Osd_Rsnr_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -30, Max => 20, Group => 501, others => <>),
      Osd_Cap_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 20000, Group => 501, others => <>),
      Osd_Alt_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 10000, Group => 501, others => <>),
      Osd_Distance_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 501, others => <>),
      Osd_Esc_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 501, others => <>),
      Osd_Esc_Rpm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -1, Max => 32767, Group => 501, others => <>),
      Osd_Esc_Current_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -1, Max => 32767, Group => 501, others => <>),
      Osd_Core_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 501, others => <>),
      Osd_Ah_Max_Pit =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Group => 501, others => <>),
      Osd_Ah_Max_Rol =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Group => 501, others => <>),
      Osd_Ah_Invert =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 501, others => <>),
      Osd_Logo_On_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Osd_Logo_On_Arming, Group => 501, others => <>),
      Osd_Logo_On_Arming_Duration =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Group => 501, others => <>),
      Osd_Arming_Logo =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Group => 501, others => <>),
      Osd_Use_Quick_Menu =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 501, others => <>),
      Osd_Show_Spec_Prearm =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 501, others => <>),
      Osd_Tim1 => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32767, Group => 501, others => <>),
      Osd_Tim2 => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32767, Group => 501, others => <>),
      Osd_Vbat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Rssi_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Link_Quality_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Link_Tx_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Rssi_Dbm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Rsnr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Tim_1_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Tim_2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Remaining_Time_Estimate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Flymode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Anti_Gravity_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_G_Force_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Throttle_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Vtx_Channel_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Crosshairs_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Ah_Sbar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Ah_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Current_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Mah_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wh_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Motor_Diag_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Craft_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pilot_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Gps_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Gps_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Gps_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Gps_Lap_Curr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Gps_Lap_Prev_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Gps_Lap_Best3_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Gps_Sats_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Home_Dir_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Home_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Flight_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Compass_Bar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Altitude_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pid_Roll_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pid_Pitch_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pid_Yaw_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Debug_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Debug2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pidrate_Profile_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Avg_Cell_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pit_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Rol_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Battery_Usage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Disarmed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Nheading_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Up_Down_Reference_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Ready_Mode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pos_Hold_Ready_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Nvario_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Esc_Tmp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Esc_Rpm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Esc_Rpm_Freq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Rtc_Date_Time_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Adjustment_Range_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Flip_Arrow_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Core_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Log_Status_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Stick_Overlay_Left_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Stick_Overlay_Right_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Stick_Overlay_Radio_Mode =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 4, Group => 501, others => <>),
      Osd_Rate_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Pid_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Battery_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Rcchannels_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Camera_Frame_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Efficiency_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Total_Flights_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Aux_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Goggle_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Vtx_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Bitrate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Delay_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Lq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Goggle_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Vtx_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Vtx_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Sys_Fan_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Stat_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Group => 501, others => <>),
      Osd_Profile => (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 3, Group => 501, others => <>),
      Osd_Profile_1_Name =>
        (Kind => U8, Where => Master, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 501,
         others => <>),
      Osd_Profile_2_Name =>
        (Kind => U8, Where => Master, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 501,
         others => <>),
      Osd_Profile_3_Name =>
        (Kind => U8, Where => Master, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 501,
         others => <>),
      Osd_Gps_Sats_Show_Pdop =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 501, others => <>),
      Osd_Displayport_Device =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Osd_Displayport_Device, Group => 501, others => <>),
      Osd_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 501, others => <>),
      Osd_Rcchannels => (Kind => I8, Where => Master, How => List, Count => 4, Group => 501, others => <>),
      Osd_Camera_Frame_Width =>
        (Kind => U8, Where => Master, How => Direct, Min => 2, Max => 30, Group => 501, others => <>),
      Osd_Camera_Frame_Height =>
        (Kind => U8, Where => Master, How => Direct, Min => 2, Max => 16, Group => 501, others => <>),
      Osd_Stat_Avg_Cell_Value =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 501, others => <>),
      Osd_Framerate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 60, Group => 501, others => <>),
      Osd_Menu_Background =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Cms_Background, Group => 501, others => <>),
      Osd_Aux_Channel =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 18, Group => 501, others => <>),
      Osd_Aux_Scale =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 1000, Group => 501, others => <>),
      Osd_Aux_Symbol =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 501, others => <>),
      Osd_Craftname_Msgs =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 501, others => <>),
      Osd_Lidar_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Custom_Serial_Text_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Custom_Serial_Text_Terminator =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Osd_Custom_Text_Terminator, Group => 2044, others
         => <>),
      Osd_Custom_Text_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 501, others => <>),
      Osd_Custom_Text_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 501, others => <>),
      Osd_Wp_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wp_Current_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wp_Current_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wp_Current_Alt_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wp_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wp_Direction_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wp_Next_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Wp_Eta_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Nav_Map_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      Osd_Nav_Map_Mode =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Group => 568, others => <>),
      Osd_Nav_Map_Centre =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Group => 568, others => <>),
      Osd_Nav_Map_Min_Scale_M =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 5000, Group => 568, others => <>),
      Osd_Airspeed =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 2045, others => <>),
      System_Hse_Mhz =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 30, Group => 18, others => <>),
      Task_Statistics =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 18, others => <>),
      Debug_Mode => (Kind => U8, Where => Master, How => Lookup, Table => Table_Debug, Group => 18, others => <>),
      Rate_6pos_Switch =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 18, others => <>),
      Cpu_Overclock =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Overclock, Group => 18, others => <>),
      Pwr_On_Arm_Grace =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 30, Group => 18, others => <>),
      Enable_Stick_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 18, others => <>),
      Vtx_Band => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 8, Group => 259, others => <>),
      Vtx_Channel => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 8, Group => 259, others => <>),
      Vtx_Power => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 7, Group => 259, others => <>),
      Vtx_Low_Power_Disarm =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Vtx_Low_Power_Disarm, Group => 259, others => <>),
      Vtx_Softserial_Alt =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 259, others => <>),
      Vtx_Type => (Kind => U8, Where => Master, How => Lookup, Table => Table_Vtx_Type, Group => 259, others => <>),
      Vtx_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 259, others => <>),
      Vtx_Freq => (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 5999, Group => 259, others => <>),
      Vtx_Pit_Mode_Freq =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 5999, Group => 259, others => <>),
      Vtx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 515, others => <>),
      Vtx_Spi_Bus => (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 57, others => <>),
      Vcd_Video_System =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Video_System, Group => 514, others => <>),
      Vcd_H_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -32, Max => 31, Group => 514, others => <>),
      Vcd_V_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -15, Max => 16, Group => 514, others => <>),
      Max7456_Clock =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Max7456_Clock, Group => 524, others => <>),
      Max7456_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 524, others => <>),
      Max7456_Preinit_Opu =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 524, others => <>),
      Displayport_Msp_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -6, Max => 0, Group => 512, others => <>),
      Displayport_Msp_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -3, Max => 0, Group => 512, others => <>),
      Displayport_Msp_Fonts => (Kind => U8, Where => Master, How => List, Count => 4, Group => 512, others => <>),
      Displayport_Msp_Use_Device_Blink =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 512, others => <>),
      Displayport_Max7456_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -6, Max => 0, Group => 513, others => <>),
      Displayport_Max7456_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -3, Max => 0, Group => 513, others => <>),
      Displayport_Max7456_Inv =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 513, others => <>),
      Displayport_Max7456_Blk =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Group => 513, others => <>),
      Displayport_Max7456_Wht =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Group => 513, others => <>),
      Esc_Sensor_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 517, others => <>),
      Esc_Sensor_Current_Offset =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 16000, Group => 517, others => <>),
      Esc_Sensor_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 517, others => <>),
      Frsky_Spi_Autobind =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 523, others => <>),
      Frsky_Spi_Tx_Id => (Kind => U8, Where => Master, How => List, Count => 3, Group => 523, others => <>),
      Frsky_Spi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -127, Max => 127, Group => 523, others => <>),
      Frsky_Spi_Bind_Hop_Data => (Kind => U8, Where => Master, How => List, Count => 50, Group => 523, others => <>),
      Frsky_X_Rx_Num =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 523, others => <>),
      Frsky_Spi_A1_Source =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Rx_Frsky_Spi_A1_Source, Group => 523, others => <>),
      Cc2500_Spi_Chip_Detect =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 523, others => <>),
      Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 7, Group => 505, others => <>),
      Dashboard_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 519, others => <>),
      Dashboard_I2c_Addr =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 8, Max => 119, Group => 519, others => <>),
      Rangefinder_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Rangefinder_Hardware, Group => 527, others => <>),
      Rangefinder_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 527, others => <>),
      Opticalflow_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Opticalflow_Hardware, Group => 560, others => <>),
      Opticalflow_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 560, others => <>),
      Opticalflow_Rotation =>
        (Kind => I16, Where => Master, How => Direct, Min => 0, Max => 359, Group => 560, others => <>),
      Opticalflow_Flip_X =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 560, others => <>),
      Pinio_Config => (Kind => U8, Where => Hardware, How => List, Count => 4, Group => 529, others => <>),
      Pinio_Box => (Kind => U8, Where => Hardware, How => List, Count => 4, Group => 530, others => <>),
      Usb_Hid_Cdc => (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 531, others => <>),
      Usb_Msc_Pin_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 531, others => <>),
      Flash_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 506, others => <>),
      Rcdevice_Init_Dev_Attempts =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 10, Group => 539, others => <>),
      Rcdevice_Init_Dev_Attempt_Interval =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 5000, Group => 539, others => <>),
      Rcdevice_Protocol_Version =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Group => 539, others => <>),
      Rcdevice_Feature =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Group => 539, others => <>),
      Rcdevice_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 539, others => <>),
      Gyro_1_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Bus_Type, Group => 540, others => <>),
      Gyro_1_Spibus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 540, others => <>),
      Gyro_1_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Group => 540, others => <>),
      Gyro_1_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Group => 540, others => <>),
      I2c1_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 518, others => <>),
      I2c1_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 100, Max => 1300, Group => 518, others => <>),
      I2c2_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 518, others => <>),
      I2c2_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 100, Max => 1300, Group => 518, others => <>),
      I2c3_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 518, others => <>),
      I2c3_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 100, Max => 1300, Group => 518, others => <>),
      Mco2_On_Pc9 =>
        (Kind => U8, Where => Hardware, How => Lookup, Table => Table_Off_On, Group => 541, others => <>),
      Spektrum_Spi_Protocol =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 542, others => <>),
      Spektrum_Spi_Mfg_Id => (Kind => U8, Where => Master, How => List, Count => 4, Group => 542, others => <>),
      Spektrum_Spi_Num_Channels =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 12, Group => 542, others => <>),
      Expresslrs_Uid => (Kind => U8, Where => Master, How => List, Count => 6, Group => 555, others => <>),
      Expresslrs_Domain =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Freq_Domain, Group => 555, others => <>),
      Expresslrs_Model_Id =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 555, others => <>),
      Scheduler_Relax_Rx =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 0, Max => 500, Group => 556, others => <>),
      Scheduler_Relax_Osd =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 0, Max => 500, Group => 556, others => <>),
      Scheduler_Debug_Task =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 0, Max => 40, Group => 556, others => <>),
      Cpu_Late_Limit_Permille =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 556, others => <>),
      Serialmsp_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 557, others => <>),
      Msp_1_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 557, others => <>),
      Msp_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 557, others => <>),
      Msp_2_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 557, others => <>),
      Msp_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 557, others => <>),
      Msp_3_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 557, others => <>),
      Msp_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Baud_Rate, Group => 557, others => <>),
      Timezone_Offset_Minutes =>
        (Kind => I16, Where => Master, How => Direct, Min => -780, Max => 780, Group => 526, others => <>),
      Rpm_Filter_Harmonics =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Group => 544, others => <>),
      Rpm_Filter_Weights => (Kind => U8, Where => Master, How => List, Count => 3, Group => 544, others => <>),
      Rpm_Filter_Q =>
        (Kind => U16, Where => Master, How => Direct, Min => 250, Max => 3000, Group => 544, others => <>),
      Rpm_Filter_Min_Hz =>
        (Kind => U8, Where => Master, How => Direct, Min => 30, Max => 200, Group => 544, others => <>),
      Rpm_Filter_Fade_Range_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Group => 544, others => <>),
      Rpm_Filter_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 500, Group => 544, others => <>),
      Flysky_Spi_Tx_Id =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Group => 525, others => <>),
      Flysky_Spi_Rf_Channels => (Kind => U8, Where => Master, How => List, Count => 16, Group => 525, others => <>),
      Stats_Min_Armed_Time_S =>
        (Kind => I8, Where => Master, How => Direct, Min => -1, Max => 127, Group => 547, others => <>),
      Stats_Total_Flights =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Group => 547, others => <>),
      Stats_Total_Time_S =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Group => 547, others => <>),
      Stats_Total_Dist_M =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Group => 547, others => <>),
      Stats_Save_Move_Limit =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Group => 547, others => <>),
      Stats_Mah_Used =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Group => 547, others => <>),
      Craft_Name =>
        (Kind => U8, Where => Master, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 47,
         others => <>),
      Pilot_Name =>
        (Kind => U8, Where => Master, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 47,
         others => <>),
      Altitude_Source =>
        (Kind => I8, Where => Master, How => Lookup, Table => Table_Position_Alt_Source, Group => 56, others => <>),
      Altitude_Prefer_Baro =>
        (Kind => I8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 56, others => <>),
      Altitude_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 5000, Group => 56, others => <>),
      Rangefinder_Max_Range_Cm =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 1000, Group => 56, others => <>),
      Altitude_D_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 5000, Group => 56, others => <>),
      Ap_Landing_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Hover_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1700, Group => 60, others => <>),
      Ap_Throttle_Min =>
        (Kind => U16, Where => Master, How => Direct, Min => 1050, Max => 1400, Group => 60, others => <>),
      Ap_Throttle_Max =>
        (Kind => U16, Where => Master, How => Direct, Min => 1400, Max => 2000, Group => 60, others => <>),
      Ap_Altitude_P => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Altitude_I => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Altitude_D => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Altitude_A => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Altitude_F => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Position_P => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Position_I => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Position_D => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Position_A => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Position_F => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Position_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 50, Group => 60, others => <>),
      Ap_Stop_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Group => 60, others => <>),
      Ap_Max_Angle => (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 70, Group => 60, others => <>),
      Ap_Max_Yaw_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 250, Group => 60, others => <>),
      Ap_Yaw_P => (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Group => 60, others => <>),
      Ap_Velocity_Drag_Coeff =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Group => 60, others => <>),
      Ap_Max_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 5000, Group => 60, others => <>),
      Ap_Waypoint_Arrival_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 5000, Group => 60, others => <>),
      Ap_Waypoint_Hold_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 1000, Group => 60, others => <>),
      Ap_Stick_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 500, Group => 60, others => <>),
      Ap_Throttle_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 500, Group => 60, others => <>),
      Ap_Yaw_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Ap_Yaw_Mode, Group => 60, others => <>),
      Ap_Min_Forward_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 500, Group => 60, others => <>),
      Ap_Nav_Corner_Speed =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 2000, Group => 60, others => <>),
      Ap_Nav_Corner_Delta_V =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 4000, Group => 60, others => <>),
      Ap_Nav_Decel =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 1000, Group => 60, others => <>),
      Ap_Nav_Accel =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 1000, Group => 60, others => <>),
      Ap_Nav_Carrot_Lead_Time =>
        (Kind => U8, Where => Master, How => Direct, Min => 2, Max => 40, Group => 60, others => <>),
      Ap_Nav_Carrot_Lead_Max =>
        (Kind => U16, Where => Master, How => Direct, Min => 600, Max => 6000, Group => 60, others => <>),
      Ap_Nav_Preturn_Dist =>
        (Kind => U16, Where => Master, How => Direct, Min => 500, Max => 5000, Group => 60, others => <>),
      Ap_Velocity_Buildup_Max_Pitch =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 20, Group => 60, others => <>),
      Ap_Max_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 90, Group => 60, others => <>),
      Ap_Hold_Orbit_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 300, Max => 5000, Group => 60, others => <>),
      Ap_Hold_Figure8_Width =>
        (Kind => U16, Where => Master, How => Direct, Min => 500, Max => 10000, Group => 60, others => <>),
      Ap_Landing_Descent_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 200, Group => 60, others => <>),
      Ap_Landing_Detection_Time =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Group => 60, others => <>),
      Ap_Landing_Spiral_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 60, others => <>),
      Ap_Landing_Spiral_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 2000, Group => 60, others => <>),
      Ap_Landing_Spiral_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 45, Group => 60, others => <>),
      Ap_Landing_Velocity_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 200, Group => 60, others => <>),
      Ap_Landing_Throttle_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 500, Group => 60, others => <>),
      Ap_L1_Enable => (Kind => U8, Where => Master, How => Lookup, Table => Table_Off_On, Group => 60, others => <>),
      Ap_L1_Period => (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 100, Group => 60, others => <>),
      Ap_L1_Min_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 5000, Group => 60, others => <>),
      Ap_L1_Max_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Min => 1000, Max => 50000, Group => 60, others => <>),
      Ap_L1_Max_Cross_Track_Error =>
        (Kind => U16, Where => Master, How => Direct, Min => 1000, Max => 50000, Group => 60, others => <>),
      Ap_L1_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Group => 60, others => <>),
      Ap_Min_Nav_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Group => 60, others => <>),
      Ap_Rx_Loss_Policy =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Ap_Rx_Loss_Policy, Group => 60, others => <>),
      Ap_Max_Distance_From_Home =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 10000, Group => 60, others => <>),
      Ap_Geofence_Action =>
        (Kind => U8, Where => Master, How => Lookup, Table => Table_Ap_Geofence_Action, Group => 60, others => <>),
      Box_User_1_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 553,
         others => <>),
      Box_User_2_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 553,
         others => <>),
      Box_User_3_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 553,
         others => <>),
      Box_User_4_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min_Length => 1, Count => 16, Write_Once => False, Group => 553,
         others => <>),
      Gimbal_Roll_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Pitch_Rc_Thr_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Pitch_Rc_Low_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Pitch_Rc_High_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Yaw_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Roll_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Roll_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Roll_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Pitch_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Pitch_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Pitch_Low_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Pitch_High_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Yaw_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Yaw_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Yaw_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Group => 559, others => <>),
      Gimbal_Stabilisation =>
        (Kind => I8, Where => Master, How => Direct, Min => 0, Max => 7, Group => 559, others => <>),
      Gimbal_Sensitivity =>
        (Kind => I8, Where => Master, How => Direct, Min => -16, Max => 15, Group => 559, others => <>),
      Gimbal_Uart => (Kind => I8, Where => Master, How => Identifier, Count => 0, Group => 559, others => <>));

   function Describe (S : Setting) return Info is (Infos (S));

   function Name (S : Setting) return String is
     (case S is
        when Gyro_Hardware_Lpf => "gyro_hardware_lpf",
        when Gyro_Lpf1_Type => "gyro_lpf1_type",
        when Gyro_Lpf1_Static_Hz => "gyro_lpf1_static_hz",
        when Gyro_Lpf2_Type => "gyro_lpf2_type",
        when Gyro_Lpf2_Static_Hz => "gyro_lpf2_static_hz",
        when Gyro_Notch1_Hz => "gyro_notch1_hz",
        when Gyro_Notch1_Cutoff => "gyro_notch1_cutoff",
        when Gyro_Notch2_Hz => "gyro_notch2_hz",
        when Gyro_Notch2_Cutoff => "gyro_notch2_cutoff",
        when Gyro_Calib_Duration => "gyro_calib_duration",
        when Gyro_Calib_Noise_Limit => "gyro_calib_noise_limit",
        when Gyro_Offset_Yaw => "gyro_offset_yaw",
        when Gyro_Overflow_Detect => "gyro_overflow_detect",
        when Yaw_Spin_Recovery => "yaw_spin_recovery",
        when Yaw_Spin_Threshold => "yaw_spin_threshold",
        when Dyn_Notch_Count => "dyn_notch_count",
        when Dyn_Notch_Q => "dyn_notch_q",
        when Dyn_Notch_Min_Hz => "dyn_notch_min_hz",
        when Dyn_Notch_Max_Hz => "dyn_notch_max_hz",
        when Gyro_Lpf1_Dyn_Min_Hz => "gyro_lpf1_dyn_min_hz",
        when Gyro_Lpf1_Dyn_Max_Hz => "gyro_lpf1_dyn_max_hz",
        when Gyro_Lpf1_Dyn_Expo => "gyro_lpf1_dyn_expo",
        when Gyro_Filter_Debug_Axis => "gyro_filter_debug_axis",
        when Acc_Hardware => "acc_hardware",
        when Acc_Lpf_Hz => "acc_lpf_hz",
        when Acc_Trim_Pitch => "acc_trim_pitch",
        when Acc_Trim_Roll => "acc_trim_roll",
        when Acc_Calibration => "acc_calibration",
        when Align_Mag => "align_mag",
        when Mag_Align_Roll => "mag_align_roll",
        when Mag_Align_Pitch => "mag_align_pitch",
        when Mag_Align_Yaw => "mag_align_yaw",
        when Mag_Bustype => "mag_bustype",
        when Mag_I2c_Device => "mag_i2c_device",
        when Mag_I2c_Address => "mag_i2c_address",
        when Mag_Spi_Device => "mag_spi_device",
        when Mag_Hardware => "mag_hardware",
        when Mag_Calibration => "mag_calibration",
        when Baro_Bustype => "baro_bustype",
        when Baro_Spi_Device => "baro_spi_device",
        when Baro_I2c_Device => "baro_i2c_device",
        when Baro_I2c_Address => "baro_i2c_address",
        when Baro_Hardware => "baro_hardware",
        when Baro_Drift => "baro_drift",
        when Pitot_Bustype => "pitot_bustype",
        when Pitot_I2c_Device => "pitot_i2c_device",
        when Pitot_I2c_Address => "pitot_i2c_address",
        when Pitot_Hardware => "pitot_hardware",
        when Mid_Rc => "mid_rc",
        when Min_Check => "min_check",
        when Max_Check => "max_check",
        when Rssi_Channel => "rssi_channel",
        when Rssi_Src_Frame_Errors => "rssi_src_frame_errors",
        when Rssi_Scale => "rssi_scale",
        when Rssi_Offset => "rssi_offset",
        when Rssi_Invert => "rssi_invert",
        when Rssi_Src_Frame_Lpf_Period => "rssi_src_frame_lpf_period",
        when Rssi_Smoothing => "rssi_smoothing",
        when Rc_Smoothing => "rc_smoothing",
        when Rc_Smoothing_Auto_Factor => "rc_smoothing_auto_factor",
        when Rc_Smoothing_Auto_Factor_Throttle => "rc_smoothing_auto_factor_throttle",
        when Rc_Smoothing_Setpoint_Cutoff => "rc_smoothing_setpoint_cutoff",
        when Rc_Smoothing_Throttle_Cutoff => "rc_smoothing_throttle_cutoff",
        when Rc_Smoothing_Debug_Axis => "rc_smoothing_debug_axis",
        when Fpv_Mix_Degrees => "fpv_mix_degrees",
        when Max_Aux_Channels => "max_aux_channels",
        when Serialrx_Provider => "serialrx_provider",
        when Serialrx_Inverted => "serialrx_inverted",
        when Spektrum_Sat_Bind => "spektrum_sat_bind",
        when Spektrum_Sat_Bind_Autoreset => "spektrum_sat_bind_autoreset",
        when Srxl2_Unit_Id => "srxl2_unit_id",
        when Srxl2_Baud_Fast => "srxl2_baud_fast",
        when Sbus_Baud_Fast => "sbus_baud_fast",
        when Crsf_Use_Negotiated_Baud => "crsf_use_negotiated_baud",
        when Airmode_Start_Throttle_Percent => "airmode_start_throttle_percent",
        when Rx_Min_Usec => "rx_min_usec",
        when Rx_Max_Usec => "rx_max_usec",
        when Serialrx_Halfduplex => "serialrx_halfduplex",
        when Rx_Uart => "rx_uart",
        when Msp_Override_Channels_Mask => "msp_override_channels_mask",
        when Msp_Override_Failsafe => "msp_override_failsafe",
        when Rx_Spi_Protocol => "rx_spi_protocol",
        when Rx_Spi_Bus => "rx_spi_bus",
        when Rx_Spi_Led_Inversion => "rx_spi_led_inversion",
        when Adc_Device => "adc_device",
        when Adc_Vrefint_Calibration => "adc_vrefint_calibration",
        when Adc_Tempsensor_Calibration30 => "adc_tempsensor_calibration30",
        when Adc_Tempsensor_Calibration110 => "adc_tempsensor_calibration110",
        when Input_Filtering_Mode => "input_filtering_mode",
        when Blackbox_Sample_Rate => "blackbox_sample_rate",
        when Blackbox_Device => "blackbox_device",
        when Blackbox_Disable_Pids => "blackbox_disable_pids",
        when Blackbox_Disable_Rc => "blackbox_disable_rc",
        when Blackbox_Disable_Setpoint => "blackbox_disable_setpoint",
        when Blackbox_Disable_Bat => "blackbox_disable_bat",
        when Blackbox_Disable_Mag => "blackbox_disable_mag",
        when Blackbox_Disable_Alt => "blackbox_disable_alt",
        when Blackbox_Disable_Rssi => "blackbox_disable_rssi",
        when Blackbox_Disable_Gyro => "blackbox_disable_gyro",
        when Blackbox_Disable_Gyrounfilt => "blackbox_disable_gyrounfilt",
        when Blackbox_Disable_Acc => "blackbox_disable_acc",
        when Blackbox_Disable_Attitude => "blackbox_disable_attitude",
        when Blackbox_Disable_Debug => "blackbox_disable_debug",
        when Blackbox_Disable_Motors => "blackbox_disable_motors",
        when Blackbox_Disable_Servos => "blackbox_disable_servos",
        when Blackbox_Disable_Rpm => "blackbox_disable_rpm",
        when Blackbox_Disable_Gps => "blackbox_disable_gps",
        when Blackbox_Disable_Pitot => "blackbox_disable_pitot",
        when Blackbox_Mode => "blackbox_mode",
        when Blackbox_High_Resolution => "blackbox_high_resolution",
        when Blackbox_Uart => "blackbox_uart",
        when Blackbox_Baud => "blackbox_baud",
        when Max_Throttle => "max_throttle",
        when Min_Command => "min_command",
        when Motor_Kv => "motor_kv",
        when Motor_Idle => "motor_idle",
        when Dshot_Burst => "dshot_burst",
        when Dshot_Bidir => "dshot_bidir",
        when Dshot_Edt => "dshot_edt",
        when Dshot_Bitbang => "dshot_bitbang",
        when Dshot_Bitbang_Timer => "dshot_bitbang_timer",
        when Use_Unsynced_Pwm => "use_unsynced_pwm",
        when Motor_Pwm_Protocol => "motor_pwm_protocol",
        when Motor_Pwm_Rate => "motor_pwm_rate",
        when Motor_Pwm_Inversion => "motor_pwm_inversion",
        when Motor_Poles => "motor_poles",
        when Motor_Output_Reordering => "motor_output_reordering",
        when Thr_Corr_Value => "thr_corr_value",
        when Thr_Corr_Angle => "thr_corr_angle",
        when Failsafe_Delay => "failsafe_delay",
        when Failsafe_Landing_Time => "failsafe_landing_time",
        when Failsafe_Throttle => "failsafe_throttle",
        when Failsafe_Switch_Mode => "failsafe_switch_mode",
        when Failsafe_Throttle_Low_Delay => "failsafe_throttle_low_delay",
        when Failsafe_Procedure => "failsafe_procedure",
        when Failsafe_Recovery_Delay => "failsafe_recovery_delay",
        when Failsafe_Stick_Threshold => "failsafe_stick_threshold",
        when Align_Board_Roll => "align_board_roll",
        when Align_Board_Pitch => "align_board_pitch",
        when Align_Board_Yaw => "align_board_yaw",
        when Gimbal_Mode => "gimbal_mode",
        when Battery_Profile_Name => "battery_profile_name",
        when Bat_Capacity => "bat_capacity",
        when Vbat_Max_Cell_Voltage => "vbat_max_cell_voltage",
        when Vbat_Full_Cell_Voltage => "vbat_full_cell_voltage",
        when Vbat_Min_Cell_Voltage => "vbat_min_cell_voltage",
        when Vbat_Warning_Cell_Voltage => "vbat_warning_cell_voltage",
        when Cbat_Alert_Percent => "cbat_alert_percent",
        when Force_Battery_Cell_Count => "force_battery_cell_count",
        when Vbat_Hysteresis => "vbat_hysteresis",
        when Current_Meter => "current_meter",
        when Battery_Meter => "battery_meter",
        when Vbat_Detect_Cell_Voltage => "vbat_detect_cell_voltage",
        when Use_Vbat_Alerts => "use_vbat_alerts",
        when Use_Cbat_Alerts => "use_cbat_alerts",
        when Vbat_Cutoff_Percent => "vbat_cutoff_percent",
        when Vbat_Display_Lpf_Period => "vbat_display_lpf_period",
        when Vbat_Sag_Lpf_Period => "vbat_sag_lpf_period",
        when Ibat_Lpf_Period => "ibat_lpf_period",
        when Vbat_Duration_For_Warning => "vbat_duration_for_warning",
        when Vbat_Duration_For_Critical => "vbat_duration_for_critical",
        when Vbat_Scale => "vbat_scale",
        when Vbat_Divider => "vbat_divider",
        when Vbat_Multiplier => "vbat_multiplier",
        when Ibata_Scale => "ibata_scale",
        when Ibata_Offset => "ibata_offset",
        when Ibatv_Scale => "ibatv_scale",
        when Ibatv_Offset => "ibatv_offset",
        when Battery_Continue => "battery_continue",
        when Beeper_Inversion => "beeper_inversion",
        when Beeper_Od => "beeper_od",
        when Beeper_Frequency => "beeper_frequency",
        when Beeper_Dshot_Beacon_Tone => "beeper_dshot_beacon_tone",
        when Yaw_Motors_Reversed => "yaw_motors_reversed",
        when Mixer_Type => "mixer_type",
        when Crashflip_Motor_Percent => "crashflip_motor_percent",
        when Crashflip_Rate => "crashflip_rate",
        when Crashflip_Auto_Rearm => "crashflip_auto_rearm",
        when Rpm_Limit => "rpm_limit",
        when Rpm_Limit_P => "rpm_limit_p",
        when Rpm_Limit_I => "rpm_limit_i",
        when Rpm_Limit_D => "rpm_limit_d",
        when Rpm_Limit_Value => "rpm_limit_value",
        when Three_D_Deadband_Low => "3d_deadband_low",
        when Three_D_Deadband_High => "3d_deadband_high",
        when Three_D_Neutral => "3d_neutral",
        when Three_D_Deadband_Throttle => "3d_deadband_throttle",
        when Three_D_Limit_Low => "3d_limit_low",
        when Three_D_Limit_High => "3d_limit_high",
        when Three_D_Switched_Mode => "3d_switched_mode",
        when Servo_Center_Pulse => "servo_center_pulse",
        when Servo_Pwm_Rate => "servo_pwm_rate",
        when Servo_Lowpass_Hz => "servo_lowpass_hz",
        when Tri_Unarmed_Servo => "tri_unarmed_servo",
        when Channel_Forwarding_Start => "channel_forwarding_start",
        when Rateprofile_Name => "rateprofile_name",
        when Thr_Mid => "thr_mid",
        when Thr_Expo => "thr_expo",
        when Thr_Hover => "thr_hover",
        when Rates_Type => "rates_type",
        when Quickrates_Rc_Expo => "quickrates_rc_expo",
        when Roll_Rc_Rate => "roll_rc_rate",
        when Pitch_Rc_Rate => "pitch_rc_rate",
        when Yaw_Rc_Rate => "yaw_rc_rate",
        when Roll_Expo => "roll_expo",
        when Pitch_Expo => "pitch_expo",
        when Yaw_Expo => "yaw_expo",
        when Roll_Srate => "roll_srate",
        when Pitch_Srate => "pitch_srate",
        when Yaw_Srate => "yaw_srate",
        when Throttle_Limit_Type => "throttle_limit_type",
        when Throttle_Limit_Percent => "throttle_limit_percent",
        when Roll_Rate_Limit => "roll_rate_limit",
        when Pitch_Rate_Limit => "pitch_rate_limit",
        when Yaw_Rate_Limit => "yaw_rate_limit",
        when Reboot_Character => "reboot_character",
        when Serial_Update_Rate_Hz => "serial_update_rate_hz",
        when Imu_Dcm_Kp => "imu_dcm_kp",
        when Imu_Dcm_Ki => "imu_dcm_ki",
        when Small_Angle => "small_angle",
        when Imu_Process_Denom => "imu_process_denom",
        when Mag_Declination => "mag_declination",
        when Auto_Disarm_Delay => "auto_disarm_delay",
        when Gyro_Cal_On_First_Arm => "gyro_cal_on_first_arm",
        when Prearm_Allow_Rearm => "prearm_allow_rearm",
        when Gps_Provider => "gps_provider",
        when Gps_Sbas_Mode => "gps_sbas_mode",
        when Gps_Auto_Config => "gps_auto_config",
        when Gps_Auto_Baud => "gps_auto_baud",
        when Gps_Ublox_Acquire_Model => "gps_ublox_acquire_model",
        when Gps_Ublox_Flight_Model => "gps_ublox_flight_model",
        when Gps_Update_Rate_Hz => "gps_update_rate_hz",
        when Gps_Ublox_Utc_Standard => "gps_ublox_utc_standard",
        when Gps_Ublox_Use_Galileo => "gps_ublox_use_galileo",
        when Gps_Ublox_Enable_Ana => "gps_ublox_enable_ana",
        when Gps_Set_Home_Point_Once => "gps_set_home_point_once",
        when Gps_Use_3d_Speed => "gps_use_3d_speed",
        when Gps_Sbas_Integrity => "gps_sbas_integrity",
        when Gps_Nmea_Custom_Commands => "gps_nmea_custom_commands",
        when Gps_Uart => "gps_uart",
        when Gps_Baud => "gps_baud",
        when Gps_Rescue_Min_Start_Dist => "gps_rescue_min_start_dist",
        when Gps_Rescue_Alt_Mode => "gps_rescue_alt_mode",
        when Gps_Rescue_Initial_Climb => "gps_rescue_initial_climb",
        when Gps_Rescue_Ascend_Rate => "gps_rescue_ascend_rate",
        when Gps_Rescue_Return_Alt => "gps_rescue_return_alt",
        when Gps_Rescue_Ground_Speed => "gps_rescue_ground_speed",
        when Gps_Rescue_Descent_Dist => "gps_rescue_descent_dist",
        when Gps_Rescue_Descend_Rate => "gps_rescue_descend_rate",
        when Gps_Rescue_Sanity_Checks => "gps_rescue_sanity_checks",
        when Gps_Rescue_Min_Sats => "gps_rescue_min_sats",
        when Gps_Rescue_Allow_Arming_Without_Fix => "gps_rescue_allow_arming_without_fix",
        when Gps_Rescue_Yaw_P => "gps_rescue_yaw_p",
        when Gps_Lap_Timer_Gate_Lat => "gps_lap_timer_gate_lat",
        when Gps_Lap_Timer_Gate_Lon => "gps_lap_timer_gate_lon",
        when Gps_Lap_Timer_Min_Lap_Time_S => "gps_lap_timer_min_lap_time_s",
        when Gps_Lap_Timer_Gate_Tolerance_M => "gps_lap_timer_gate_tolerance_m",
        when Deadband => "deadband",
        when Yaw_Deadband => "yaw_deadband",
        when Yaw_Control_Reversed => "yaw_control_reversed",
        when Alt_Hold_Climb_Rate => "alt_hold_climb_rate",
        when Alt_Hold_Deadband => "alt_hold_deadband",
        when Pos_Hold_Deadband => "pos_hold_deadband",
        when Poshold_Position_Source => "poshold_position_source",
        when Poshold_Opticalflow_Quality_Min => "poshold_opticalflow_quality_min",
        when Poshold_Opticalflow_Max_Range => "poshold_opticalflow_max_range",
        when Pid_Process_Denom => "pid_process_denom",
        when Runaway_Takeoff_Prevention => "runaway_takeoff_prevention",
        when Runaway_Takeoff_Deactivate_Delay => "runaway_takeoff_deactivate_delay",
        when Runaway_Takeoff_Deactivate_Throttle_Percent => "runaway_takeoff_deactivate_throttle_percent",
        when Profile_Name => "profile_name",
        when Dterm_Lpf1_Dyn_Min_Hz => "dterm_lpf1_dyn_min_hz",
        when Dterm_Lpf1_Dyn_Max_Hz => "dterm_lpf1_dyn_max_hz",
        when Dterm_Lpf1_Dyn_Expo => "dterm_lpf1_dyn_expo",
        when Dterm_Lpf1_Type => "dterm_lpf1_type",
        when Dterm_Lpf1_Static_Hz => "dterm_lpf1_static_hz",
        when Dterm_Lpf2_Type => "dterm_lpf2_type",
        when Dterm_Lpf2_Static_Hz => "dterm_lpf2_static_hz",
        when Dterm_Notch_Hz => "dterm_notch_hz",
        when Dterm_Notch_Cutoff => "dterm_notch_cutoff",
        when Vbat_Sag_Compensation => "vbat_sag_compensation",
        when Pid_At_Min_Throttle => "pid_at_min_throttle",
        when Anti_Gravity_Gain => "anti_gravity_gain",
        when Anti_Gravity_Cutoff_Hz => "anti_gravity_cutoff_hz",
        when Anti_Gravity_P_Gain => "anti_gravity_p_gain",
        when Acc_Limit_Yaw => "acc_limit_yaw",
        when Acc_Limit => "acc_limit",
        when Crash_Dthreshold => "crash_dthreshold",
        when Crash_Gthreshold => "crash_gthreshold",
        when Crash_Setpoint_Threshold => "crash_setpoint_threshold",
        when Crash_Time => "crash_time",
        when Crash_Delay => "crash_delay",
        when Crash_Recovery_Angle => "crash_recovery_angle",
        when Crash_Recovery_Rate => "crash_recovery_rate",
        when Crash_Limit_Yaw => "crash_limit_yaw",
        when Crash_Recovery => "crash_recovery",
        when Iterm_Rotation => "iterm_rotation",
        when Iterm_Relax => "iterm_relax",
        when Iterm_Relax_Type => "iterm_relax_type",
        when Iterm_Relax_Cutoff => "iterm_relax_cutoff",
        when Iterm_Windup => "iterm_windup",
        when Pidsum_Limit => "pidsum_limit",
        when Pidsum_Limit_Yaw => "pidsum_limit_yaw",
        when Yaw_Lowpass_Hz => "yaw_lowpass_hz",
        when Throttle_Boost => "throttle_boost",
        when Throttle_Boost_Cutoff => "throttle_boost_cutoff",
        when Acro_Trainer_Angle_Limit => "acro_trainer_angle_limit",
        when Acro_Trainer_Lookahead_Ms => "acro_trainer_lookahead_ms",
        when Acro_Trainer_Debug_Axis => "acro_trainer_debug_axis",
        when Acro_Trainer_Gain => "acro_trainer_gain",
        when P_Pitch => "p_pitch",
        when I_Pitch => "i_pitch",
        when D_Pitch => "d_pitch",
        when F_Pitch => "f_pitch",
        when P_Roll => "p_roll",
        when I_Roll => "i_roll",
        when D_Roll => "d_roll",
        when F_Roll => "f_roll",
        when P_Yaw => "p_yaw",
        when I_Yaw => "i_yaw",
        when D_Yaw => "d_yaw",
        when F_Yaw => "f_yaw",
        when Angle_P_Gain => "angle_p_gain",
        when Angle_Feedforward => "angle_feedforward",
        when Angle_Feedforward_Smoothing_Ms => "angle_feedforward_smoothing_ms",
        when Angle_Limit => "angle_limit",
        when Angle_Earth_Ref => "angle_earth_ref",
        when Horizon_Level_Strength => "horizon_level_strength",
        when Horizon_Limit_Sticks => "horizon_limit_sticks",
        when Horizon_Limit_Degrees => "horizon_limit_degrees",
        when Horizon_Ignore_Sticks => "horizon_ignore_sticks",
        when Horizon_Delay_Ms => "horizon_delay_ms",
        when Chirp_Lag_Freq_Hz => "chirp_lag_freq_hz",
        when Chirp_Lead_Freq_Hz => "chirp_lead_freq_hz",
        when Chirp_Amplitude_Roll => "chirp_amplitude_roll",
        when Chirp_Amplitude_Pitch => "chirp_amplitude_pitch",
        when Chirp_Amplitude_Yaw => "chirp_amplitude_yaw",
        when Chirp_Frequency_Start_Deci_Hz => "chirp_frequency_start_deci_hz",
        when Chirp_Frequency_End_Deci_Hz => "chirp_frequency_end_deci_hz",
        when Chirp_Time_Seconds => "chirp_time_seconds",
        when Chirp_Repeat => "chirp_repeat",
        when D_Max_Roll => "d_max_roll",
        when D_Max_Pitch => "d_max_pitch",
        when D_Max_Yaw => "d_max_yaw",
        when D_Max_Gain => "d_max_gain",
        when D_Max_Advance => "d_max_advance",
        when Motor_Output_Limit => "motor_output_limit",
        when Auto_Profile_Cell_Count => "auto_profile_cell_count",
        when Launch_Control_Mode => "launch_control_mode",
        when Launch_Trigger_Allow_Reset => "launch_trigger_allow_reset",
        when Launch_Trigger_Throttle_Percent => "launch_trigger_throttle_percent",
        when Launch_Angle_Limit => "launch_angle_limit",
        when Launch_Control_Gain => "launch_control_gain",
        when Thrust_Linear => "thrust_linear",
        when Feedforward_Transition => "feedforward_transition",
        when Feedforward_Averaging => "feedforward_averaging",
        when Feedforward_Smooth_Factor => "feedforward_smooth_factor",
        when Feedforward_Jitter_Factor => "feedforward_jitter_factor",
        when Feedforward_Boost => "feedforward_boost",
        when Feedforward_Max_Rate_Limit => "feedforward_max_rate_limit",
        when Feedforward_Yaw_Hold_Gain => "feedforward_yaw_hold_gain",
        when Feedforward_Yaw_Hold_Time => "feedforward_yaw_hold_time",
        when Dyn_Idle_Min_Rpm => "dyn_idle_min_rpm",
        when Dyn_Idle_P_Gain => "dyn_idle_p_gain",
        when Dyn_Idle_I_Gain => "dyn_idle_i_gain",
        when Dyn_Idle_D_Gain => "dyn_idle_d_gain",
        when Dyn_Idle_Max_Increase => "dyn_idle_max_increase",
        when Level_Race_Mode => "level_race_mode",
        when Simplified_Pids_Mode => "simplified_pids_mode",
        when Simplified_Master_Multiplier => "simplified_master_multiplier",
        when Simplified_I_Gain => "simplified_i_gain",
        when Simplified_D_Gain => "simplified_d_gain",
        when Simplified_Pi_Gain => "simplified_pi_gain",
        when Simplified_D_Max_Gain => "simplified_d_max_gain",
        when Simplified_Feedforward_Gain => "simplified_feedforward_gain",
        when Simplified_Pitch_D_Gain => "simplified_pitch_d_gain",
        when Simplified_Pitch_Pi_Gain => "simplified_pitch_pi_gain",
        when Simplified_Dterm_Filter => "simplified_dterm_filter",
        when Simplified_Dterm_Filter_Multiplier => "simplified_dterm_filter_multiplier",
        when Simplified_Gyro_Filter => "simplified_gyro_filter",
        when Simplified_Gyro_Filter_Multiplier => "simplified_gyro_filter_multiplier",
        when Tpa_Mode => "tpa_mode",
        when Tpa_Rate => "tpa_rate",
        when Tpa_Breakpoint => "tpa_breakpoint",
        when Tpa_Low_Rate => "tpa_low_rate",
        when Tpa_Low_Breakpoint => "tpa_low_breakpoint",
        when Tpa_Low_Always => "tpa_low_always",
        when Ez_Landing_Threshold => "ez_landing_threshold",
        when Ez_Landing_Limit => "ez_landing_limit",
        when Ez_Landing_Speed => "ez_landing_speed",
        when Landing_Disarm_Threshold => "landing_disarm_threshold",
        when Tlm_Inverted => "tlm_inverted",
        when Tlm_Halfduplex => "tlm_halfduplex",
        when Telemetry_1_Protocol => "telemetry_1_protocol",
        when Telemetry_1_Uart => "telemetry_1_uart",
        when Telemetry_1_Baud => "telemetry_1_baud",
        when Telemetry_2_Protocol => "telemetry_2_protocol",
        when Telemetry_2_Uart => "telemetry_2_uart",
        when Telemetry_2_Baud => "telemetry_2_baud",
        when Telemetry_3_Protocol => "telemetry_3_protocol",
        when Telemetry_3_Uart => "telemetry_3_uart",
        when Telemetry_3_Baud => "telemetry_3_baud",
        when Crsf_Tlm_Accgyro => "crsf_tlm_accgyro",
        when Frsky_Default_Lat => "frsky_default_lat",
        when Frsky_Default_Long => "frsky_default_long",
        when Frsky_Gps_Format => "frsky_gps_format",
        when Frsky_Unit => "frsky_unit",
        when Frsky_Vfas_Precision => "frsky_vfas_precision",
        when Hott_Alarm_Int => "hott_alarm_int",
        when Pid_In_Tlm => "pid_in_tlm",
        when Report_Cell_Voltage => "report_cell_voltage",
        when Ibus_Sensor => "ibus_sensor",
        when Mavlink_Mah_As_Heading_Divisor => "mavlink_mah_as_heading_divisor",
        when Mavlink_Min_Txbuff => "mavlink_min_txbuff",
        when Mavlink_Ext_Status_Rate => "mavlink_ext_status_rate",
        when Mavlink_Rc_Chan_Rate => "mavlink_rc_chan_rate",
        when Mavlink_Pos_Rate => "mavlink_pos_rate",
        when Mavlink_Extra1_Rate => "mavlink_extra1_rate",
        when Mavlink_Extra2_Rate => "mavlink_extra2_rate",
        when Mavlink_Extra3_Rate => "mavlink_extra3_rate",
        when Telemetry_Disabled_Voltage => "telemetry_disabled_voltage",
        when Telemetry_Disabled_Current => "telemetry_disabled_current",
        when Telemetry_Disabled_Fuel => "telemetry_disabled_fuel",
        when Telemetry_Disabled_Mode => "telemetry_disabled_mode",
        when Telemetry_Disabled_Acc_X => "telemetry_disabled_acc_x",
        when Telemetry_Disabled_Acc_Y => "telemetry_disabled_acc_y",
        when Telemetry_Disabled_Acc_Z => "telemetry_disabled_acc_z",
        when Telemetry_Disabled_Pitch => "telemetry_disabled_pitch",
        when Telemetry_Disabled_Roll => "telemetry_disabled_roll",
        when Telemetry_Disabled_Heading => "telemetry_disabled_heading",
        when Telemetry_Disabled_Altitude => "telemetry_disabled_altitude",
        when Telemetry_Disabled_Vario => "telemetry_disabled_vario",
        when Telemetry_Disabled_Lat_Long => "telemetry_disabled_lat_long",
        when Telemetry_Disabled_Ground_Speed => "telemetry_disabled_ground_speed",
        when Telemetry_Disabled_Distance => "telemetry_disabled_distance",
        when Telemetry_Disabled_Esc_Current => "telemetry_disabled_esc_current",
        when Telemetry_Disabled_Esc_Voltage => "telemetry_disabled_esc_voltage",
        when Telemetry_Disabled_Esc_Rpm => "telemetry_disabled_esc_rpm",
        when Telemetry_Disabled_Esc_Temperature => "telemetry_disabled_esc_temperature",
        when Telemetry_Disabled_Temperature => "telemetry_disabled_temperature",
        when Telemetry_Disabled_Cap_Used => "telemetry_disabled_cap_used",
        when Ledstrip_Visual_Beeper => "ledstrip_visual_beeper",
        when Ledstrip_Visual_Beeper_Color => "ledstrip_visual_beeper_color",
        when Ledstrip_Grb_Rgb => "ledstrip_grb_rgb",
        when Ledstrip_Profile => "ledstrip_profile",
        when Ledstrip_Race_Color => "ledstrip_race_color",
        when Ledstrip_Beacon_Color => "ledstrip_beacon_color",
        when Ledstrip_Beacon_Period_Ms => "ledstrip_beacon_period_ms",
        when Ledstrip_Beacon_Percent => "ledstrip_beacon_percent",
        when Ledstrip_Beacon_Armed_Only => "ledstrip_beacon_armed_only",
        when Ledstrip_Brightness => "ledstrip_brightness",
        when Ledstrip_Rainbow_Delta => "ledstrip_rainbow_delta",
        when Ledstrip_Rainbow_Freq => "ledstrip_rainbow_freq",
        when Transponder_Provider => "transponder_provider",
        when Transponder_Data => "transponder_data",
        when Sdcard_Detect_Inverted => "sdcard_detect_inverted",
        when Sdcard_Mode => "sdcard_mode",
        when Osd_Units => "osd_units",
        when Osd_Warn_Bitmask => "osd_warn_bitmask",
        when Osd_Rssi_Alarm => "osd_rssi_alarm",
        when Osd_Link_Quality_Alarm => "osd_link_quality_alarm",
        when Osd_Rssi_Dbm_Alarm => "osd_rssi_dbm_alarm",
        when Osd_Rsnr_Alarm => "osd_rsnr_alarm",
        when Osd_Cap_Alarm => "osd_cap_alarm",
        when Osd_Alt_Alarm => "osd_alt_alarm",
        when Osd_Distance_Alarm => "osd_distance_alarm",
        when Osd_Esc_Temp_Alarm => "osd_esc_temp_alarm",
        when Osd_Esc_Rpm_Alarm => "osd_esc_rpm_alarm",
        when Osd_Esc_Current_Alarm => "osd_esc_current_alarm",
        when Osd_Core_Temp_Alarm => "osd_core_temp_alarm",
        when Osd_Ah_Max_Pit => "osd_ah_max_pit",
        when Osd_Ah_Max_Rol => "osd_ah_max_rol",
        when Osd_Ah_Invert => "osd_ah_invert",
        when Osd_Logo_On_Arming => "osd_logo_on_arming",
        when Osd_Logo_On_Arming_Duration => "osd_logo_on_arming_duration",
        when Osd_Arming_Logo => "osd_arming_logo",
        when Osd_Use_Quick_Menu => "osd_use_quick_menu",
        when Osd_Show_Spec_Prearm => "osd_show_spec_prearm",
        when Osd_Tim1 => "osd_tim1",
        when Osd_Tim2 => "osd_tim2",
        when Osd_Vbat_Pos => "osd_vbat_pos",
        when Osd_Rssi_Pos => "osd_rssi_pos",
        when Osd_Link_Quality_Pos => "osd_link_quality_pos",
        when Osd_Link_Tx_Power_Pos => "osd_link_tx_power_pos",
        when Osd_Rssi_Dbm_Pos => "osd_rssi_dbm_pos",
        when Osd_Rsnr_Pos => "osd_rsnr_pos",
        when Osd_Tim_1_Pos => "osd_tim_1_pos",
        when Osd_Tim_2_Pos => "osd_tim_2_pos",
        when Osd_Remaining_Time_Estimate_Pos => "osd_remaining_time_estimate_pos",
        when Osd_Flymode_Pos => "osd_flymode_pos",
        when Osd_Anti_Gravity_Pos => "osd_anti_gravity_pos",
        when Osd_G_Force_Pos => "osd_g_force_pos",
        when Osd_Throttle_Pos => "osd_throttle_pos",
        when Osd_Vtx_Channel_Pos => "osd_vtx_channel_pos",
        when Osd_Crosshairs_Pos => "osd_crosshairs_pos",
        when Osd_Ah_Sbar_Pos => "osd_ah_sbar_pos",
        when Osd_Ah_Pos => "osd_ah_pos",
        when Osd_Current_Pos => "osd_current_pos",
        when Osd_Mah_Drawn_Pos => "osd_mah_drawn_pos",
        when Osd_Wh_Drawn_Pos => "osd_wh_drawn_pos",
        when Osd_Motor_Diag_Pos => "osd_motor_diag_pos",
        when Osd_Craft_Name_Pos => "osd_craft_name_pos",
        when Osd_Pilot_Name_Pos => "osd_pilot_name_pos",
        when Osd_Gps_Speed_Pos => "osd_gps_speed_pos",
        when Osd_Gps_Lon_Pos => "osd_gps_lon_pos",
        when Osd_Gps_Lat_Pos => "osd_gps_lat_pos",
        when Osd_Gps_Lap_Curr_Pos => "osd_gps_lap_curr_pos",
        when Osd_Gps_Lap_Prev_Pos => "osd_gps_lap_prev_pos",
        when Osd_Gps_Lap_Best3_Pos => "osd_gps_lap_best3_pos",
        when Osd_Gps_Sats_Pos => "osd_gps_sats_pos",
        when Osd_Home_Dir_Pos => "osd_home_dir_pos",
        when Osd_Home_Dist_Pos => "osd_home_dist_pos",
        when Osd_Flight_Dist_Pos => "osd_flight_dist_pos",
        when Osd_Compass_Bar_Pos => "osd_compass_bar_pos",
        when Osd_Altitude_Pos => "osd_altitude_pos",
        when Osd_Pid_Roll_Pos => "osd_pid_roll_pos",
        when Osd_Pid_Pitch_Pos => "osd_pid_pitch_pos",
        when Osd_Pid_Yaw_Pos => "osd_pid_yaw_pos",
        when Osd_Debug_Pos => "osd_debug_pos",
        when Osd_Debug2_Pos => "osd_debug2_pos",
        when Osd_Power_Pos => "osd_power_pos",
        when Osd_Pidrate_Profile_Pos => "osd_pidrate_profile_pos",
        when Osd_Warnings_Pos => "osd_warnings_pos",
        when Osd_Avg_Cell_Voltage_Pos => "osd_avg_cell_voltage_pos",
        when Osd_Pit_Ang_Pos => "osd_pit_ang_pos",
        when Osd_Rol_Ang_Pos => "osd_rol_ang_pos",
        when Osd_Battery_Usage_Pos => "osd_battery_usage_pos",
        when Osd_Disarmed_Pos => "osd_disarmed_pos",
        when Osd_Nheading_Pos => "osd_nheading_pos",
        when Osd_Up_Down_Reference_Pos => "osd_up_down_reference_pos",
        when Osd_Ready_Mode_Pos => "osd_ready_mode_pos",
        when Osd_Pos_Hold_Ready_Pos => "osd_pos_hold_ready_pos",
        when Osd_Nvario_Pos => "osd_nvario_pos",
        when Osd_Esc_Tmp_Pos => "osd_esc_tmp_pos",
        when Osd_Esc_Rpm_Pos => "osd_esc_rpm_pos",
        when Osd_Esc_Rpm_Freq_Pos => "osd_esc_rpm_freq_pos",
        when Osd_Rtc_Date_Time_Pos => "osd_rtc_date_time_pos",
        when Osd_Adjustment_Range_Pos => "osd_adjustment_range_pos",
        when Osd_Flip_Arrow_Pos => "osd_flip_arrow_pos",
        when Osd_Core_Temp_Pos => "osd_core_temp_pos",
        when Osd_Log_Status_Pos => "osd_log_status_pos",
        when Osd_Stick_Overlay_Left_Pos => "osd_stick_overlay_left_pos",
        when Osd_Stick_Overlay_Right_Pos => "osd_stick_overlay_right_pos",
        when Osd_Stick_Overlay_Radio_Mode => "osd_stick_overlay_radio_mode",
        when Osd_Rate_Profile_Name_Pos => "osd_rate_profile_name_pos",
        when Osd_Pid_Profile_Name_Pos => "osd_pid_profile_name_pos",
        when Osd_Battery_Profile_Name_Pos => "osd_battery_profile_name_pos",
        when Osd_Profile_Name_Pos => "osd_profile_name_pos",
        when Osd_Rcchannels_Pos => "osd_rcchannels_pos",
        when Osd_Camera_Frame_Pos => "osd_camera_frame_pos",
        when Osd_Efficiency_Pos => "osd_efficiency_pos",
        when Osd_Total_Flights_Pos => "osd_total_flights_pos",
        when Osd_Aux_Pos => "osd_aux_pos",
        when Osd_Sys_Goggle_Voltage_Pos => "osd_sys_goggle_voltage_pos",
        when Osd_Sys_Vtx_Voltage_Pos => "osd_sys_vtx_voltage_pos",
        when Osd_Sys_Bitrate_Pos => "osd_sys_bitrate_pos",
        when Osd_Sys_Delay_Pos => "osd_sys_delay_pos",
        when Osd_Sys_Distance_Pos => "osd_sys_distance_pos",
        when Osd_Sys_Lq_Pos => "osd_sys_lq_pos",
        when Osd_Sys_Goggle_Dvr_Pos => "osd_sys_goggle_dvr_pos",
        when Osd_Sys_Vtx_Dvr_Pos => "osd_sys_vtx_dvr_pos",
        when Osd_Sys_Warnings_Pos => "osd_sys_warnings_pos",
        when Osd_Sys_Vtx_Temp_Pos => "osd_sys_vtx_temp_pos",
        when Osd_Sys_Fan_Speed_Pos => "osd_sys_fan_speed_pos",
        when Osd_Stat_Bitmask => "osd_stat_bitmask",
        when Osd_Profile => "osd_profile",
        when Osd_Profile_1_Name => "osd_profile_1_name",
        when Osd_Profile_2_Name => "osd_profile_2_name",
        when Osd_Profile_3_Name => "osd_profile_3_name",
        when Osd_Gps_Sats_Show_Pdop => "osd_gps_sats_show_pdop",
        when Osd_Displayport_Device => "osd_displayport_device",
        when Osd_Uart => "osd_uart",
        when Osd_Rcchannels => "osd_rcchannels",
        when Osd_Camera_Frame_Width => "osd_camera_frame_width",
        when Osd_Camera_Frame_Height => "osd_camera_frame_height",
        when Osd_Stat_Avg_Cell_Value => "osd_stat_avg_cell_value",
        when Osd_Framerate_Hz => "osd_framerate_hz",
        when Osd_Menu_Background => "osd_menu_background",
        when Osd_Aux_Channel => "osd_aux_channel",
        when Osd_Aux_Scale => "osd_aux_scale",
        when Osd_Aux_Symbol => "osd_aux_symbol",
        when Osd_Craftname_Msgs => "osd_craftname_msgs",
        when Osd_Lidar_Dist_Pos => "osd_lidar_dist_pos",
        when Osd_Custom_Serial_Text_Pos => "osd_custom_serial_text_pos",
        when Osd_Custom_Serial_Text_Terminator => "osd_custom_serial_text_terminator",
        when Osd_Custom_Text_Uart => "osd_custom_text_uart",
        when Osd_Custom_Text_Baud => "osd_custom_text_baud",
        when Osd_Wp_Number_Pos => "osd_wp_number_pos",
        when Osd_Wp_Current_Lat_Pos => "osd_wp_current_lat_pos",
        when Osd_Wp_Current_Lon_Pos => "osd_wp_current_lon_pos",
        when Osd_Wp_Current_Alt_Pos => "osd_wp_current_alt_pos",
        when Osd_Wp_Distance_Pos => "osd_wp_distance_pos",
        when Osd_Wp_Direction_Pos => "osd_wp_direction_pos",
        when Osd_Wp_Next_Number_Pos => "osd_wp_next_number_pos",
        when Osd_Wp_Eta_Pos => "osd_wp_eta_pos",
        when Osd_Nav_Map_Pos => "osd_nav_map_pos",
        when Osd_Nav_Map_Mode => "osd_nav_map_mode",
        when Osd_Nav_Map_Centre => "osd_nav_map_centre",
        when Osd_Nav_Map_Min_Scale_M => "osd_nav_map_min_scale_m",
        when Osd_Airspeed => "osd_airspeed",
        when System_Hse_Mhz => "system_hse_mhz",
        when Task_Statistics => "task_statistics",
        when Debug_Mode => "debug_mode",
        when Rate_6pos_Switch => "rate_6pos_switch",
        when Cpu_Overclock => "cpu_overclock",
        when Pwr_On_Arm_Grace => "pwr_on_arm_grace",
        when Enable_Stick_Arming => "enable_stick_arming",
        when Vtx_Band => "vtx_band",
        when Vtx_Channel => "vtx_channel",
        when Vtx_Power => "vtx_power",
        when Vtx_Low_Power_Disarm => "vtx_low_power_disarm",
        when Vtx_Softserial_Alt => "vtx_softserial_alt",
        when Vtx_Type => "vtx_type",
        when Vtx_Uart => "vtx_uart",
        when Vtx_Freq => "vtx_freq",
        when Vtx_Pit_Mode_Freq => "vtx_pit_mode_freq",
        when Vtx_Halfduplex => "vtx_halfduplex",
        when Vtx_Spi_Bus => "vtx_spi_bus",
        when Vcd_Video_System => "vcd_video_system",
        when Vcd_H_Offset => "vcd_h_offset",
        when Vcd_V_Offset => "vcd_v_offset",
        when Max7456_Clock => "max7456_clock",
        when Max7456_Spi_Bus => "max7456_spi_bus",
        when Max7456_Preinit_Opu => "max7456_preinit_opu",
        when Displayport_Msp_Col_Adjust => "displayport_msp_col_adjust",
        when Displayport_Msp_Row_Adjust => "displayport_msp_row_adjust",
        when Displayport_Msp_Fonts => "displayport_msp_fonts",
        when Displayport_Msp_Use_Device_Blink => "displayport_msp_use_device_blink",
        when Displayport_Max7456_Col_Adjust => "displayport_max7456_col_adjust",
        when Displayport_Max7456_Row_Adjust => "displayport_max7456_row_adjust",
        when Displayport_Max7456_Inv => "displayport_max7456_inv",
        when Displayport_Max7456_Blk => "displayport_max7456_blk",
        when Displayport_Max7456_Wht => "displayport_max7456_wht",
        when Esc_Sensor_Halfduplex => "esc_sensor_halfduplex",
        when Esc_Sensor_Current_Offset => "esc_sensor_current_offset",
        when Esc_Sensor_Uart => "esc_sensor_uart",
        when Frsky_Spi_Autobind => "frsky_spi_autobind",
        when Frsky_Spi_Tx_Id => "frsky_spi_tx_id",
        when Frsky_Spi_Offset => "frsky_spi_offset",
        when Frsky_Spi_Bind_Hop_Data => "frsky_spi_bind_hop_data",
        when Frsky_X_Rx_Num => "frsky_x_rx_num",
        when Frsky_Spi_A1_Source => "frsky_spi_a1_source",
        when Cc2500_Spi_Chip_Detect => "cc2500_spi_chip_detect",
        when Led_Inversion => "led_inversion",
        when Dashboard_I2c_Bus => "dashboard_i2c_bus",
        when Dashboard_I2c_Addr => "dashboard_i2c_addr",
        when Rangefinder_Hardware => "rangefinder_hardware",
        when Rangefinder_Uart => "rangefinder_uart",
        when Opticalflow_Hardware => "opticalflow_hardware",
        when Opticalflow_Uart => "opticalflow_uart",
        when Opticalflow_Rotation => "opticalflow_rotation",
        when Opticalflow_Flip_X => "opticalflow_flip_x",
        when Pinio_Config => "pinio_config",
        when Pinio_Box => "pinio_box",
        when Usb_Hid_Cdc => "usb_hid_cdc",
        when Usb_Msc_Pin_Pullup => "usb_msc_pin_pullup",
        when Flash_Spi_Bus => "flash_spi_bus",
        when Rcdevice_Init_Dev_Attempts => "rcdevice_init_dev_attempts",
        when Rcdevice_Init_Dev_Attempt_Interval => "rcdevice_init_dev_attempt_interval",
        when Rcdevice_Protocol_Version => "rcdevice_protocol_version",
        when Rcdevice_Feature => "rcdevice_feature",
        when Rcdevice_Uart => "rcdevice_uart",
        when Gyro_1_Bustype => "gyro_1_bustype",
        when Gyro_1_Spibus => "gyro_1_spibus",
        when Gyro_1_I2c_Bus => "gyro_1_i2cBus",
        when Gyro_1_I2c_Address => "gyro_1_i2c_address",
        when I2c1_Pullup => "i2c1_pullup",
        when I2c1_Clockspeed_Khz => "i2c1_clockspeed_khz",
        when I2c2_Pullup => "i2c2_pullup",
        when I2c2_Clockspeed_Khz => "i2c2_clockspeed_khz",
        when I2c3_Pullup => "i2c3_pullup",
        when I2c3_Clockspeed_Khz => "i2c3_clockspeed_khz",
        when Mco2_On_Pc9 => "mco2_on_pc9",
        when Spektrum_Spi_Protocol => "spektrum_spi_protocol",
        when Spektrum_Spi_Mfg_Id => "spektrum_spi_mfg_id",
        when Spektrum_Spi_Num_Channels => "spektrum_spi_num_channels",
        when Expresslrs_Uid => "expresslrs_uid",
        when Expresslrs_Domain => "expresslrs_domain",
        when Expresslrs_Model_Id => "expresslrs_model_id",
        when Scheduler_Relax_Rx => "scheduler_relax_rx",
        when Scheduler_Relax_Osd => "scheduler_relax_osd",
        when Scheduler_Debug_Task => "scheduler_debug_task",
        when Cpu_Late_Limit_Permille => "cpu_late_limit_permille",
        when Serialmsp_Halfduplex => "serialmsp_halfduplex",
        when Msp_1_Uart => "msp_1_uart",
        when Msp_1_Baud => "msp_1_baud",
        when Msp_2_Uart => "msp_2_uart",
        when Msp_2_Baud => "msp_2_baud",
        when Msp_3_Uart => "msp_3_uart",
        when Msp_3_Baud => "msp_3_baud",
        when Timezone_Offset_Minutes => "timezone_offset_minutes",
        when Rpm_Filter_Harmonics => "rpm_filter_harmonics",
        when Rpm_Filter_Weights => "rpm_filter_weights",
        when Rpm_Filter_Q => "rpm_filter_q",
        when Rpm_Filter_Min_Hz => "rpm_filter_min_hz",
        when Rpm_Filter_Fade_Range_Hz => "rpm_filter_fade_range_hz",
        when Rpm_Filter_Lpf_Hz => "rpm_filter_lpf_hz",
        when Flysky_Spi_Tx_Id => "flysky_spi_tx_id",
        when Flysky_Spi_Rf_Channels => "flysky_spi_rf_channels",
        when Stats_Min_Armed_Time_S => "stats_min_armed_time_s",
        when Stats_Total_Flights => "stats_total_flights",
        when Stats_Total_Time_S => "stats_total_time_s",
        when Stats_Total_Dist_M => "stats_total_dist_m",
        when Stats_Save_Move_Limit => "stats_save_move_limit",
        when Stats_Mah_Used => "stats_mah_used",
        when Craft_Name => "craft_name",
        when Pilot_Name => "pilot_name",
        when Altitude_Source => "altitude_source",
        when Altitude_Prefer_Baro => "altitude_prefer_baro",
        when Altitude_Lpf => "altitude_lpf",
        when Rangefinder_Max_Range_Cm => "rangefinder_max_range_cm",
        when Altitude_D_Lpf => "altitude_d_lpf",
        when Ap_Landing_Altitude_M => "ap_landing_altitude_m",
        when Ap_Hover_Throttle => "ap_hover_throttle",
        when Ap_Throttle_Min => "ap_throttle_min",
        when Ap_Throttle_Max => "ap_throttle_max",
        when Ap_Altitude_P => "ap_altitude_p",
        when Ap_Altitude_I => "ap_altitude_i",
        when Ap_Altitude_D => "ap_altitude_d",
        when Ap_Altitude_A => "ap_altitude_a",
        when Ap_Altitude_F => "ap_altitude_f",
        when Ap_Position_P => "ap_position_p",
        when Ap_Position_I => "ap_position_i",
        when Ap_Position_D => "ap_position_d",
        when Ap_Position_A => "ap_position_a",
        when Ap_Position_F => "ap_position_f",
        when Ap_Position_Cutoff => "ap_position_cutoff",
        when Ap_Stop_Threshold => "ap_stop_threshold",
        when Ap_Max_Angle => "ap_max_angle",
        when Ap_Max_Yaw_Rate => "ap_max_yaw_rate",
        when Ap_Yaw_P => "ap_yaw_p",
        when Ap_Velocity_Drag_Coeff => "ap_velocity_drag_coeff",
        when Ap_Max_Velocity => "ap_max_velocity",
        when Ap_Waypoint_Arrival_Radius => "ap_waypoint_arrival_radius",
        when Ap_Waypoint_Hold_Radius => "ap_waypoint_hold_radius",
        when Ap_Stick_Deadband => "ap_stick_deadband",
        when Ap_Throttle_Deadband => "ap_throttle_deadband",
        when Ap_Yaw_Mode => "ap_yaw_mode",
        when Ap_Min_Forward_Velocity => "ap_min_forward_velocity",
        when Ap_Nav_Corner_Speed => "ap_nav_corner_speed",
        when Ap_Nav_Corner_Delta_V => "ap_nav_corner_delta_v",
        when Ap_Nav_Decel => "ap_nav_decel",
        when Ap_Nav_Accel => "ap_nav_accel",
        when Ap_Nav_Carrot_Lead_Time => "ap_nav_carrot_lead_time",
        when Ap_Nav_Carrot_Lead_Max => "ap_nav_carrot_lead_max",
        when Ap_Nav_Preturn_Dist => "ap_nav_preturn_dist",
        when Ap_Velocity_Buildup_Max_Pitch => "ap_velocity_buildup_max_pitch",
        when Ap_Max_Turn_Rate => "ap_max_turn_rate",
        when Ap_Hold_Orbit_Radius => "ap_hold_orbit_radius",
        when Ap_Hold_Figure8_Width => "ap_hold_figure8_width",
        when Ap_Landing_Descent_Rate => "ap_landing_descent_rate",
        when Ap_Landing_Detection_Time => "ap_landing_detection_time",
        when Ap_Landing_Spiral_Enable => "ap_landing_spiral_enable",
        when Ap_Landing_Spiral_Radius => "ap_landing_spiral_radius",
        when Ap_Landing_Spiral_Rate => "ap_landing_spiral_rate",
        when Ap_Landing_Velocity_Threshold => "ap_landing_velocity_threshold",
        when Ap_Landing_Throttle_Threshold => "ap_landing_throttle_threshold",
        when Ap_L1_Enable => "ap_l1_enable",
        when Ap_L1_Period => "ap_l1_period",
        when Ap_L1_Min_Lookahead => "ap_l1_min_lookahead",
        when Ap_L1_Max_Lookahead => "ap_l1_max_lookahead",
        when Ap_L1_Max_Cross_Track_Error => "ap_l1_max_cross_track_error",
        when Ap_L1_Turn_Rate => "ap_l1_turn_rate",
        when Ap_Min_Nav_Altitude_M => "ap_min_nav_altitude_m",
        when Ap_Rx_Loss_Policy => "ap_rx_loss_policy",
        when Ap_Max_Distance_From_Home => "ap_max_distance_from_home",
        when Ap_Geofence_Action => "ap_geofence_action",
        when Box_User_1_Name => "box_user_1_name",
        when Box_User_2_Name => "box_user_2_name",
        when Box_User_3_Name => "box_user_3_name",
        when Box_User_4_Name => "box_user_4_name",
        when Gimbal_Roll_Rc_Gain => "gimbal_roll_rc_gain",
        when Gimbal_Pitch_Rc_Thr_Gain => "gimbal_pitch_rc_thr_gain",
        when Gimbal_Pitch_Rc_Low_Gain => "gimbal_pitch_rc_low_gain",
        when Gimbal_Pitch_Rc_High_Gain => "gimbal_pitch_rc_high_gain",
        when Gimbal_Yaw_Rc_Gain => "gimbal_yaw_rc_gain",
        when Gimbal_Roll_Gain => "gimbal_roll_gain",
        when Gimbal_Roll_Offset => "gimbal_roll_offset",
        when Gimbal_Roll_Limit => "gimbal_roll_limit",
        when Gimbal_Pitch_Gain => "gimbal_pitch_gain",
        when Gimbal_Pitch_Offset => "gimbal_pitch_offset",
        when Gimbal_Pitch_Low_Limit => "gimbal_pitch_low_limit",
        when Gimbal_Pitch_High_Limit => "gimbal_pitch_high_limit",
        when Gimbal_Yaw_Gain => "gimbal_yaw_gain",
        when Gimbal_Yaw_Offset => "gimbal_yaw_offset",
        when Gimbal_Yaw_Limit => "gimbal_yaw_limit",
        when Gimbal_Stabilisation => "gimbal_stabilisation",
        when Gimbal_Sensitivity => "gimbal_sensitivity",
        when Gimbal_Uart => "gimbal_uart");

   function Value_Count (T : Lookup_Table) return Natural is
     (case T is
        when Table_Off_On => 2,
        when Table_Unit => 3,
        when Table_Alignment => 10,
        when Table_Gps_Provider => 4,
        when Table_Gps_Sbas_Mode => 6,
        when Table_Gps_Ublox_Models => 8,
        when Table_Gps_Ublox_Utc_Standard => 5,
        when Table_Ap_Yaw_Mode => 5,
        when Table_Ap_Rx_Loss_Policy => 3,
        when Table_Ap_Geofence_Action => 2,
        when Table_Gps_Rescue_Sanity_Check => 3,
        when Table_Gps_Rescue_Alt_Mode => 3,
        when Table_Blackbox_Device => 4,
        when Table_Blackbox_Mode => 3,
        when Table_Blackbox_Sample_Rate => 5,
        when Table_Current_Meter => 5,
        when Table_Voltage_Meter => 3,
        when Table_Gimbal_Mode => 2,
        when Table_Serial_Rx => 17,
        when Table_Rx_Spi => 20,
        when Table_Gyro_Hardware_Lpf => 4,
        when Table_Acc_Hardware => 29,
        when Table_Baro_Hardware => 15,
        when Table_Mag_Hardware => 15,
        when Table_Debug => 111,
        when Table_Motor_Pwm_Protocol => 11,
        when Table_Dshot_Edt => 3,
        when Table_Gyro_Lpf_Type => 4,
        when Table_Dterm_Lpf_Type => 4,
        when Table_Failsafe => 3,
        when Table_Failsafe_Switch_Mode => 3,
        when Table_Crash_Recovery => 4,
        when Table_Bus_Type => 4,
        when Table_Max7456_Clock => 3,
        when Table_Rx_Frsky_Spi_A1_Source => 3,
        when Table_Rangefinder_Hardware => 16,
        when Table_Opticalflow_Hardware => 3,
        when Table_Pitot_Hardware => 4,
        when Table_Poshold_Source => 3,
        when Table_Gyro_Overflow_Check => 3,
        when Table_Rates_Type => 5,
        when Table_Overclock => 4,
        when Table_Rgb_Grb => 3,
        when Table_Throttle_Limit_Type => 3,
        when Table_Video_System => 4,
        when Table_Iterm_Relax => 5,
        when Table_Iterm_Relax_Type => 2,
        when Table_Acro_Trainer_Debug => 2,
        when Table_Rc_Smoothing_Debug => 4,
        when Table_Vtx_Low_Power_Disarm => 3,
        when Table_Sdcard_Mode => 3,
        when Table_Launch_Control_Mode => 3,
        when Table_Tpa_Mode => 2,
        when Table_Spa_Mode => 5,
        when Table_Led_Profile => 3,
        when Table_Ledstrip_Color => 14,
        when Table_Gyro_Filter_Debug => 3,
        when Table_Position_Alt_Source => 5,
        when Table_Off_On_Auto => 3,
        when Table_Feedforward_Averaging => 4,
        when Table_Dshot_Bitbanged_Timer => 3,
        when Table_Osd_Displayport_Device => 6,
        when Table_Vtx_Type => 6,
        when Table_Osd_Logo_On_Arming => 3,
        when Table_Osd_Custom_Text_Terminator => 2,
        when Table_Mixer_Type => 4,
        when Table_Simplified_Tuning_Pids_Mode => 3,
        when Table_Cms_Background => 4,
        when Table_Freq_Domain => 8,
        when Table_Transponder_Provider => 4,
        when Table_Baud_Rate => 16,
        when Table_Telemetry_Protocol => 7);

   function Value_Name (T : Lookup_Table; Index : Natural) return String is
     (case T is
        when Table_Off_On =>
          (case Index is
             when 0 => "OFF", when 1 => "ON", when others => ""),
        when Table_Unit =>
          (case Index is
             when 0 => "IMPERIAL", when 1 => "METRIC", when 2 => "BRITISH", when others => ""),
        when Table_Alignment =>
          (case Index is
             when 0 => "DEFAULT", when 1 => "CW0", when 2 => "CW90", when 3 => "CW180", when 4 => "CW270", when 5
             => "CW0FLIP", when 6 => "CW90FLIP", when 7 => "CW180FLIP", when 8 => "CW270FLIP", when 9 =>
             "CUSTOM", when others => ""),
        when Table_Gps_Provider =>
          (case Index is
             when 0 => "NMEA", when 1 => "UBLOX", when 2 => "MSP", when 3 => "VIRTUAL", when others => ""),
        when Table_Gps_Sbas_Mode =>
          (case Index is
             when 0 => "AUTO", when 1 => "EGNOS", when 2 => "WAAS", when 3 => "MSAS", when 4 => "GAGAN", when 5
             => "NONE", when others => ""),
        when Table_Gps_Ublox_Models =>
          (case Index is
             when 0 => "PORTABLE", when 1 => "STATIONARY", when 2 => "PEDESTRIAN", when 3 => "AUTOMOTIVE", when 4
             => "AT_SEA", when 5 => "AIRBORNE_1G", when 6 => "AIRBORNE_2G", when 7 => "AIRBORNE_4G", when others
             => ""),
        when Table_Gps_Ublox_Utc_Standard =>
          (case Index is
             when 0 => "AUTO", when 1 => "USNO", when 2 => "EU", when 3 => "SU", when 4 => "NTSC", when others =>
             ""),
        when Table_Ap_Yaw_Mode =>
          (case Index is
             when 0 => "VELOCITY", when 1 => "BEARING", when 2 => "HYBRID", when 3 => "FIXED", when 4 =>
             "DAMPENER", when others => ""),
        when Table_Ap_Rx_Loss_Policy =>
          (case Index is
             when 0 => "DISABLE", when 1 => "CONTINUE", when 2 => "LAND", when others => ""),
        when Table_Ap_Geofence_Action =>
          (case Index is
             when 0 => "LAND", when 1 => "RTH", when others => ""),
        when Table_Gps_Rescue_Sanity_Check =>
          (case Index is
             when 0 => "RESCUE_SANITY_OFF", when 1 => "RESCUE_SANITY_ON", when 2 => "RESCUE_SANITY_FS_ONLY", when
             others => ""),
        when Table_Gps_Rescue_Alt_Mode =>
          (case Index is
             when 0 => "MAX_ALT", when 1 => "FIXED_ALT", when 2 => "CURRENT_ALT", when others => ""),
        when Table_Blackbox_Device =>
          (case Index is
             when 0 => "NONE", when 1 => "SPIFLASH", when 2 => "SDCARD", when 3 => "SERIAL", when others => ""),
        when Table_Blackbox_Mode =>
          (case Index is
             when 0 => "NORMAL", when 1 => "MOTOR_TEST", when 2 => "ALWAYS", when others => ""),
        when Table_Blackbox_Sample_Rate =>
          (case Index is
             when 0 => "1/1", when 1 => "1/2", when 2 => "1/4", when 3 => "1/8", when 4 => "1/16", when others =>
             ""),
        when Table_Current_Meter =>
          (case Index is
             when 0 => "NONE", when 1 => "ADC", when 2 => "VIRTUAL", when 3 => "ESC", when 4 => "MSP", when
             others => ""),
        when Table_Voltage_Meter =>
          (case Index is
             when 0 => "NONE", when 1 => "ADC", when 2 => "ESC", when others => ""),
        when Table_Gimbal_Mode =>
          (case Index is
             when 0 => "NORMAL", when 1 => "MIXTILT", when others => ""),
        when Table_Serial_Rx =>
          (case Index is
             when 0 => "NONE", when 1 => "SPEK2048", when 2 => "SBUS", when 3 => "SUMD", when 4 => "SUMH", when 5
             => "XB-B", when 6 => "XB-B-RJ01", when 7 => "IBUS", when 8 => "JETIEXBUS", when 9 => "CRSF", when 10
             => "SRXL", when 11 => "CUSTOM", when 12 => "FPORT", when 13 => "SRXL2", when 14 => "GHST", when 15
             => "SPEK1024", when 16 => "MAVLINK", when others => ""),
        when Table_Rx_Spi =>
          (case Index is
             when 0 => "V202_250K", when 1 => "V202_1M", when 2 => "SYMA_X", when 3 => "SYMA_X5C", when 4 =>
             "CX10", when 5 => "CX10A", when 6 => "H8_3D", when 7 => "INAV", when 8 => "FRSKY_D", when 9 =>
             "FRSKY_X", when 10 => "FLYSKY", when 11 => "FLYSKY_2A", when 12 => "KN", when 13 => "SFHSS", when 14
             => "SPEKTRUM", when 15 => "FRSKY_X_LBT", when 16 => "REDPINE", when 17 => "FRSKY_X_V2", when 18 =>
             "FRSKY_X_LBT_V2", when 19 => "EXPRESSLRS", when others => ""),
        when Table_Gyro_Hardware_Lpf =>
          (case Index is
             when 0 => "NORMAL", when 1 => "OPTION_1", when 2 => "OPTION_2", when 3 => "EXPERIMENTAL", when
             others => ""),
        when Table_Acc_Hardware =>
          (case Index is
             when 0 => "AUTO", when 1 => "NONE", when 2 => "MPU6050", when 3 => "MPU6000", when 4 => "MPU6500",
             when 5 => "MPU9250", when 6 => "ICM20601", when 7 => "ICM20602", when 8 => "ICM20608G", when 9 =>
             "ICM20649", when 10 => "ICM20689", when 11 => "ICM42605", when 12 => "ICM42688P", when 13 =>
             "BMI160", when 14 => "BMI270", when 15 => "LSM6DSO", when 16 => "LSM6DSV16X", when 17 => "IIM42653",
             when 18 => "ICM45605", when 19 => "ICM45686", when 20 => "ICM40609D", when 21 => "IIM42652", when 22
             => "LSM6DSK320X", when 23 => "ICM42622P", when 24 => "ICM42686P", when 25 => "ICM56686", when 26 =>
             "BMI423", when 27 => "VIRTUAL", when 28 => "LSM6DSV32X", when others => ""),
        when Table_Baro_Hardware =>
          (case Index is
             when 0 => "AUTO", when 1 => "NONE", when 2 => "BMP085", when 3 => "MS5611", when 4 => "BMP280", when
             5 => "LPS", when 6 => "QMP6988", when 7 => "BMP388", when 8 => "DPS310", when 9 => "2SMPB_02B", when
             10 => "LPS22DF", when 11 => "BMP580", when 12 => "BMP581", when 13 => "VIRTUAL", when 14 =>
             "SPA06_003", when others => ""),
        when Table_Mag_Hardware =>
          (case Index is
             when 0 => "AUTO", when 1 => "NONE", when 2 => "HMC5883", when 3 => "AK8975", when 4 => "AK8963",
             when 5 => "QMC5883L", when 6 => "LIS2MDL", when 7 => "LIS3MDL", when 8 => "MPU925X_AK8963", when 9
             => "IST8310", when 10 => "MMC560X", when 11 => "QMC5883P", when 12 => "", when 13 => "BMM350", when
             14 => "AK9916", when others => ""),
        when Table_Debug =>
          (case Index is
             when 0 => "NONE", when 1 => "CYCLETIME", when 2 => "BATTERY", when 3 => "GYRO_FILTERED", when 4 =>
             "ACCELEROMETER", when 5 => "PIDLOOP", when 6 => "RC_INTERPOLATION", when 7 => "ANGLERATE", when 8 =>
             "ESC_SENSOR", when 9 => "SCHEDULER", when 10 => "STACK", when 11 => "ESC_SENSOR_RPM", when 12 =>
             "ESC_SENSOR_TMP", when 13 => "ALTITUDE", when 14 => "FFT", when 15 => "FFT_TIME", when 16 =>
             "FFT_FREQ", when 17 => "RX_FRSKY_SPI", when 18 => "RX_SFHSS_SPI", when 19 => "GYRO_RAW", when 20 =>
             "MULTI_GYRO_RAW", when 21 => "MULTI_GYRO_DIFF", when 22 => "MAX7456_SIGNAL", when 23 =>
             "MAX7456_SPICLOCK", when 24 => "SBUS", when 25 => "FPORT", when 26 => "RANGEFINDER", when 27 =>
             "RANGEFINDER_QUALITY", when 28 => "OPTICALFLOW", when 29 => "LIDAR_TF", when 30 => "ADC_INTERNAL",
             when 31 => "RUNAWAY_TAKEOFF", when 32 => "SDIO", when 33 => "CURRENT_SENSOR", when 34 => "USB", when
             35 => "SMARTAUDIO", when 36 => "RTH", when 37 => "ITERM_RELAX", when 38 => "ACRO_TRAINER", when 39
             => "RC_SMOOTHING", when 40 => "RX_SIGNAL_LOSS", when 41 => "RC_SMOOTHING_RATE", when 42 =>
             "ANTI_GRAVITY", when 43 => "DYN_LPF", when 44 => "RX_SPEKTRUM_SPI", when 45 =>
             "DSHOT_RPM_TELEMETRY", when 46 => "RPM_FILTER", when 47 => "D_MAX", when 48 => "AC_CORRECTION", when
             49 => "AC_ERROR", when 50 => "MULTI_GYRO_SCALED", when 51 => "DSHOT_RPM_ERRORS", when 52 =>
             "CRSF_LINK_STATISTICS_UPLINK", when 53 => "CRSF_LINK_STATISTICS_PWR", when 54 =>
             "CRSF_LINK_STATISTICS_DOWN", when 55 => "BARO", when 56 => "AUTOPILOT_ALTITUDE", when 57 =>
             "DYN_IDLE", when 58 => "FEEDFORWARD_LIMIT", when 59 => "FEEDFORWARD", when 60 => "BLACKBOX_OUTPUT",
             when 61 => "GYRO_SAMPLE", when 62 => "RX_TIMING", when 63 => "D_LPF", when 64 => "VTX_TRAMP", when
             65 => "GHST", when 66 => "GHST_MSP", when 67 => "SCHEDULER_DETERMINISM", when 68 =>
             "TIMING_ACCURACY", when 69 => "RX_EXPRESSLRS_SPI", when 70 => "RX_EXPRESSLRS_PHASELOCK", when 71 =>
             "RX_STATE_TIME", when 72 => "GPS_RESCUE_VELOCITY", when 73 => "GPS_RESCUE_HEADING", when 74 =>
             "GPS_RESCUE_TRACKING", when 75 => "GPS_CONNECTION", when 76 => "ATTITUDE", when 77 => "VTX_MSP",
             when 78 => "GPS_DOP", when 79 => "FAILSAFE", when 80 => "GYRO_CALIBRATION", when 81 => "ANGLE_MODE",
             when 82 => "ANGLE_TARGET", when 83 => "CURRENT_ANGLE", when 84 => "DSHOT_TELEMETRY_COUNTS", when 85
             => "RPM_LIMIT", when 86 => "RC_STATS", when 87 => "MAG_CALIB", when 88 => "MAG_TASK_RATE", when 89
             => "EZLANDING", when 90 => "TPA", when 91 => "S_TERM", when 92 => "SPA", when 93 => "TASK", when 94
             => "GIMBAL", when 95 => "WING_SETPOINT", when 96 => "CHIRP", when 97 => "FLASH_TEST_PRBS", when 98
             => "MAVLINK_TELEMETRY", when 99 => "AUTOPILOT_PID", when 100 => "POSITION_NAV", when 101 =>
             "AUTOPILOT_STOP", when 102 => "PITOT", when 103 => "POSITION_EST", when 104 => "AUTOPILOT_HEADING",
             when 105 => "RX_REDPINE_SPI", when 106 => "LAUNCH", when 107 => "VELOCITY_EST", when 108 =>
             "SAG_COMPENSATION", when 109 => "UPT1", when 110 => "FLIGHT_PLAN", when others => ""),
        when Table_Motor_Pwm_Protocol =>
          (case Index is
             when 0 => "PWM", when 1 => "ONESHOT125", when 2 => "ONESHOT42", when 3 => "MULTISHOT", when 4 =>
             "BRUSHED", when 5 => "DSHOT150", when 6 => "DSHOT300", when 7 => "DSHOT600", when 8 =>
             "PROSHOT1000", when 9 => "DISABLED", when 10 => "DRONECAN", when others => ""),
        when Table_Dshot_Edt =>
          (case Index is
             when 0 => "OFF", when 1 => "ON", when 2 => "FORCE", when others => ""),
        when Table_Gyro_Lpf_Type =>
          (case Index is
             when 0 => "PT1", when 1 => "BIQUAD", when 2 => "PT2", when 3 => "PT3", when others => ""),
        when Table_Dterm_Lpf_Type =>
          (case Index is
             when 0 => "PT1", when 1 => "BIQUAD", when 2 => "PT2", when 3 => "PT3", when others => ""),
        when Table_Failsafe =>
          (case Index is
             when 0 => "AUTO-LAND", when 1 => "DROP", when 2 => "GPS-RESCUE", when others => ""),
        when Table_Failsafe_Switch_Mode =>
          (case Index is
             when 0 => "STAGE1", when 1 => "KILL", when 2 => "STAGE2", when others => ""),
        when Table_Crash_Recovery =>
          (case Index is
             when 0 => "OFF", when 1 => "ON", when 2 => "BEEP", when 3 => "DISARM", when others => ""),
        when Table_Bus_Type =>
          (case Index is
             when 0 => "NONE", when 1 => "I2C", when 2 => "SPI", when 3 => "SLAVE", when others => ""),
        when Table_Max7456_Clock =>
          (case Index is
             when 0 => "HALF", when 1 => "NOMINAL", when 2 => "DOUBLE", when others => ""),
        when Table_Rx_Frsky_Spi_A1_Source =>
          (case Index is
             when 0 => "VBAT", when 1 => "EXTADC", when 2 => "CONST", when others => ""),
        when Table_Rangefinder_Hardware =>
          (case Index is
             when 0 => "NONE", when 1 => "HCSR04", when 2 => "TFMINI", when 3 => "TF02", when 4 => "MTF01", when
             5 => "MTF02", when 6 => "MTF01P", when 7 => "MTF02P", when 8 => "TFNOVA", when 9 => "NOOPLOOP_F2",
             when 10 => "NOOPLOOP_F2P", when 11 => "NOOPLOOP_F2PH", when 12 => "NOOPLOOP_F", when 13 =>
             "NOOPLOOP_FP", when 14 => "NOOPLOOP_F2MINI", when 15 => "UPT1", when others => ""),
        when Table_Opticalflow_Hardware =>
          (case Index is
             when 0 => "NONE", when 1 => "MT", when 2 => "UPT1", when others => ""),
        when Table_Pitot_Hardware =>
          (case Index is
             when 0 => "AUTO", when 1 => "NONE", when 2 => "MS4525", when 3 => "", when others => ""),
        when Table_Poshold_Source =>
          (case Index is
             when 0 => "AUTO", when 1 => "GPS_ONLY", when 2 => "OPTICALFLOW_ONLY", when others => ""),
        when Table_Gyro_Overflow_Check =>
          (case Index is
             when 0 => "OFF", when 1 => "YAW", when 2 => "ALL", when others => ""),
        when Table_Rates_Type =>
          (case Index is
             when 0 => "BETAFLIGHT", when 1 => "RACEFLIGHT", when 2 => "KISS", when 3 => "ACTUAL", when 4 =>
             "QUICK", when others => ""),
        when Table_Overclock =>
          (case Index is
             when 0 => "OFF", when 1 => "192MHZ", when 2 => "216MHZ", when 3 => "240MHZ", when others => ""),
        when Table_Rgb_Grb =>
          (case Index is
             when 0 => "GRB", when 1 => "RGB", when 2 => "GRBW", when others => ""),
        when Table_Throttle_Limit_Type =>
          (case Index is
             when 0 => "OFF", when 1 => "SCALE", when 2 => "CLIP", when others => ""),
        when Table_Video_System =>
          (case Index is
             when 0 => "AUTO", when 1 => "PAL", when 2 => "NTSC", when 3 => "HD", when others => ""),
        when Table_Iterm_Relax =>
          (case Index is
             when 0 => "OFF", when 1 => "RP", when 2 => "RPY", when 3 => "RP_INC", when 4 => "RPY_INC", when
             others => ""),
        when Table_Iterm_Relax_Type =>
          (case Index is
             when 0 => "GYRO", when 1 => "SETPOINT", when others => ""),
        when Table_Acro_Trainer_Debug =>
          (case Index is
             when 0 => "ROLL", when 1 => "PITCH", when others => ""),
        when Table_Rc_Smoothing_Debug =>
          (case Index is
             when 0 => "ROLL", when 1 => "PITCH", when 2 => "YAW", when 3 => "THROTTLE", when others => ""),
        when Table_Vtx_Low_Power_Disarm =>
          (case Index is
             when 0 => "OFF", when 1 => "ON", when 2 => "UNTIL_FIRST_ARM", when others => ""),
        when Table_Sdcard_Mode =>
          (case Index is
             when 0 => "OFF", when 1 => "SPI", when 2 => "SDIO", when others => ""),
        when Table_Launch_Control_Mode =>
          (case Index is
             when 0 => "NORMAL", when 1 => "PITCHONLY", when 2 => "FULL", when others => ""),
        when Table_Tpa_Mode =>
          (case Index is
             when 0 => "PD", when 1 => "D", when others => ""),
        when Table_Spa_Mode =>
          (case Index is
             when 0 => "OFF", when 1 => "I_FREEZE", when 2 => "I", when 3 => "PID", when 4 => "PD_I_FREEZE", when
             others => ""),
        when Table_Led_Profile =>
          (case Index is
             when 0 => "RACE", when 1 => "BEACON", when 2 => "STATUS", when others => ""),
        when Table_Ledstrip_Color =>
          (case Index is
             when 0 => "BLACK", when 1 => "WHITE", when 2 => "RED", when 3 => "ORANGE", when 4 => "YELLOW", when
             5 => "LIME_GREEN", when 6 => "GREEN", when 7 => "MINT_GREEN", when 8 => "CYAN", when 9 =>
             "LIGHT_BLUE", when 10 => "BLUE", when 11 => "DARK_VIOLET", when 12 => "MAGENTA", when 13 =>
             "DEEP_PINK", when others => ""),
        when Table_Gyro_Filter_Debug =>
          (case Index is
             when 0 => "ROLL", when 1 => "PITCH", when 2 => "YAW", when others => ""),
        when Table_Position_Alt_Source =>
          (case Index is
             when 0 => "DEFAULT", when 1 => "BARO_ONLY", when 2 => "GPS_ONLY", when 3 => "RANGEFINDER_PREFER",
             when 4 => "RANGEFINDER_ONLY", when others => ""),
        when Table_Off_On_Auto =>
          (case Index is
             when 0 => "OFF", when 1 => "ON", when 2 => "AUTO", when others => ""),
        when Table_Feedforward_Averaging =>
          (case Index is
             when 0 => "OFF", when 1 => "2_POINT", when 2 => "3_POINT", when 3 => "4_POINT", when others => ""),
        when Table_Dshot_Bitbanged_Timer =>
          (case Index is
             when 0 => "AUTO", when 1 => "TIM1", when 2 => "TIM8", when others => ""),
        when Table_Osd_Displayport_Device =>
          (case Index is
             when 0 => "NONE", when 1 => "AUTO", when 2 => "MAX7456", when 3 => "MSP", when 4 => "FRSKYOSD", when
             5 => "FBOSD", when others => ""),
        when Table_Vtx_Type =>
          (case Index is
             when 0 => "NONE", when 1 => "RTC6705", when 2 => "", when 3 => "SMARTAUDIO", when 4 => "TRAMP", when
             5 => "MSP", when others => ""),
        when Table_Osd_Logo_On_Arming =>
          (case Index is
             when 0 => "OFF", when 1 => "ON", when 2 => "FIRST_ARMING", when others => ""),
        when Table_Osd_Custom_Text_Terminator =>
          (case Index is
             when 0 => "NULL", when 1 => "LF", when others => ""),
        when Table_Mixer_Type =>
          (case Index is
             when 0 => "LEGACY", when 1 => "LINEAR", when 2 => "DYNAMIC", when 3 => "EZLANDING", when others =>
             ""),
        when Table_Simplified_Tuning_Pids_Mode =>
          (case Index is
             when 0 => "OFF", when 1 => "RP", when 2 => "RPY", when others => ""),
        when Table_Cms_Background =>
          (case Index is
             when 0 => "TRANSPARENT", when 1 => "BLACK", when 2 => "GRAY", when 3 => "LIGHT_GRAY", when others =>
             ""),
        when Table_Freq_Domain =>
          (case Index is
             when 0 => "AU433", when 1 => "AU915", when 2 => "EU433", when 3 => "EU868", when 4 => "IN866", when
             5 => "FCC915", when 6 => "ISM2400", when 7 => "CE2400", when others => ""),
        when Table_Transponder_Provider =>
          (case Index is
             when 0 => "NONE", when 1 => "ILAP", when 2 => "ARCITIMER", when 3 => "ERLT", when others => ""),
        when Table_Baud_Rate =>
          (case Index is
             when 0 => "AUTO", when 1 => "9600", when 2 => "19200", when 3 => "38400", when 4 => "57600", when 5
             => "115200", when 6 => "230400", when 7 => "250000", when 8 => "400000", when 9 => "460800", when 10
             => "500000", when 11 => "921600", when 12 => "1000000", when 13 => "1500000", when 14 => "2000000",
             when 15 => "2470000", when others => ""),
        when Table_Telemetry_Protocol =>
          (case Index is
             when 0 => "NONE", when 1 => "FRSKY_HUB", when 2 => "HOTT", when 3 => "LTM", when 4 => "SMARTPORT",
             when 5 => "MAVLINK", when 6 => "IBUS", when others => ""));

end Adaflight.Settings_Table;
