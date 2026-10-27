package body Adaflight.Settings_Table with SPARK_Mode is

   Infos : constant array (Setting) of Info :=
     (Gyro_Hardware_Lpf =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gyro_Hardware_Lpf, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Lpf1_Type =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gyro_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Lpf1_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Lpf2_Type =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gyro_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Lpf2_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Notch1_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Notch1_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Notch2_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Notch2_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Calib_Duration =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 3000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Calib_Noise_Limit =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Offset_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Min => -1000, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Overflow_Detect =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gyro_Overflow_Check, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 10),
      Yaw_Spin_Recovery =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On_Auto, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Yaw_Spin_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Min => 500, Max => 1950, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Dyn_Notch_Count =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 7, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 554),
      Dyn_Notch_Q =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 554),
      Dyn_Notch_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 554),
      Dyn_Notch_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 200, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 554),
      Gyro_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 10, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Gyro_Filter_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gyro_Filter_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Acc_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Acc_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 35),
      Acc_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 35),
      Acc_Trim_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Min => -300, Max => 300, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 35),
      Acc_Trim_Roll =>
        (Kind => I16, Where => Master, How => Direct, Min => -300, Max => 300, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 35),
      Acc_Calibration =>
        (Kind => I16, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 4, Min_Length
         => 0, Write_Once => False, Group => 35),
      Align_Mag =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Alignment, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_Align_Roll =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -3600, Max => 3600, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_Align_Pitch =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -3600, Max => 3600, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_Align_Yaw =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -3600, Max => 3600, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Bus_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Mag_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 40),
      Mag_Calibration =>
        (Kind => I16, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 3, Min_Length
         => 0, Write_Once => False, Group => 40),
      Baro_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Bus_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Baro_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 5, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Baro_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 5, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Baro_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Baro_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baro_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Baro_Drift =>
        (Kind => I16, Where => Master, How => Direct, Min => -500, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Pitot_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Bus_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 569),
      Pitot_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 5, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 569),
      Pitot_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 569),
      Pitot_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Pitot_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 569),
      Mid_Rc =>
        (Kind => U16, Where => Master, How => Direct, Min => 1200, Max => 1700, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Min_Check =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Max_Check =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rssi_Channel =>
        (Kind => I8, Where => Master, How => Direct, Min => 0, Max => 18, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rssi_Src_Frame_Errors =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Rssi_Scale =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rssi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rssi_Invert =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Rssi_Src_Frame_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rssi_Smoothing =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rc_Smoothing =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Rc_Smoothing_Auto_Factor =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rc_Smoothing_Auto_Factor_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rc_Smoothing_Setpoint_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rc_Smoothing_Throttle_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rc_Smoothing_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Rc_Smoothing_Debug, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 24),
      Fpv_Mix_Degrees =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Max_Aux_Channels =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 14, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Serialrx_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Serial_Rx, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Serialrx_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Spektrum_Sat_Bind =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 10, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Spektrum_Sat_Bind_Autoreset =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Srxl2_Unit_Id =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 15, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Srxl2_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Sbus_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Crsf_Use_Negotiated_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Airmode_Start_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rx_Min_Usec =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rx_Max_Usec =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Serialrx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Rx_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Msp_Override_Channels_Mask =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 262143, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Msp_Override_Failsafe =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 24),
      Rx_Spi_Protocol =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Rx_Spi, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 537),
      Rx_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 537),
      Rx_Spi_Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 537),
      Adc_Device =>
        (Kind => I8, Where => Hardware, How => Direct, Min => 0, Max => 1, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 510),
      Adc_Vrefint_Calibration =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 510),
      Adc_Tempsensor_Calibration30 =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 510),
      Adc_Tempsensor_Calibration110 =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 510),
      Input_Filtering_Mode =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 508),
      Blackbox_Sample_Rate =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Blackbox_Sample_Rate, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Device =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Blackbox_Device, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Pids =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Rc =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 1,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Setpoint =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 2,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Bat =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 3,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Mag =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 4,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Alt =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 5,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Rssi =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 6,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Gyro =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 7,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Gyrounfilt =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 14,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Acc =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 9,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Attitude =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 8,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Debug =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 10,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Motors =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 11,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Servos =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 15,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Rpm =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 13,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Gps =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 12,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Disable_Pitot =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 16,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Blackbox_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_High_Resolution =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 5),
      Blackbox_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Blackbox_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Max_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Min_Command =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Motor_Kv =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 1, Max => 40000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Motor_Idle =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Dshot_Burst =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On_Auto, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Dshot_Bidir =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 6),
      Dshot_Edt =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Dshot_Edt, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Dshot_Bitbang =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On_Auto, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Dshot_Bitbang_Timer =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Dshot_Bitbanged_Timer, Count
         => 0, Min_Length => 0, Write_Once => False, Group => 6),
      Use_Unsynced_Pwm =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 6),
      Motor_Pwm_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Motor_Pwm_Protocol, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 6),
      Motor_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 200, Max => 32000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Motor_Pwm_Inversion =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 6),
      Motor_Poles =>
        (Kind => U8, Where => Master, How => Direct, Min => 4, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Motor_Output_Reordering =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 8, Min_Length
         => 0, Write_Once => False, Group => 6),
      Thr_Corr_Value =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 150, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 39),
      Thr_Corr_Angle =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 900, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 39),
      Failsafe_Delay =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 1),
      Failsafe_Landing_Time =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 1),
      Failsafe_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 1),
      Failsafe_Switch_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Failsafe_Switch_Mode, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 1),
      Failsafe_Throttle_Low_Delay =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 300, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 1),
      Failsafe_Procedure =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Failsafe, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 1),
      Failsafe_Recovery_Delay =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 1),
      Failsafe_Stick_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 1),
      Align_Board_Roll =>
        (Kind => I16, Where => Master, How => Direct, Min => -180, Max => 360, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2),
      Align_Board_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Min => -180, Max => 360, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2),
      Align_Board_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Min => -180, Max => 360, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2),
      Gimbal_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gimbal_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 3),
      Battery_Profile_Name =>
        (Kind => U8, Where => Battery_Profile, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 8,
         Min_Length => 1, Write_Once => False, Group => 561),
      Bat_Capacity =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 0, Max => 20000, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 561),
      Vbat_Max_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 561),
      Vbat_Full_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 561),
      Vbat_Min_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 561),
      Vbat_Warning_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Min => 100, Max => 500, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 561),
      Cbat_Alert_Percent =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 561),
      Force_Battery_Cell_Count =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Min => 0, Max => 24, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 561),
      Vbat_Hysteresis =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Current_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Current_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Battery_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Voltage_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Vbat_Detect_Cell_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Use_Vbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 11),
      Use_Cbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 11),
      Vbat_Cutoff_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Vbat_Display_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Vbat_Sag_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Ibat_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Vbat_Duration_For_Warning =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 150, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Vbat_Duration_For_Critical =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 150, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Vbat_Scale =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 258),
      Vbat_Divider =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 258),
      Vbat_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 258),
      Ibata_Scale =>
        (Kind => I16, Where => Hardware, How => Direct, Min => -16000, Max => 16000, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 256),
      Ibata_Offset =>
        (Kind => I16, Where => Master, How => Direct, Min => -32000, Max => 32000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 256),
      Ibatv_Scale =>
        (Kind => I16, Where => Master, How => Direct, Min => -16000, Max => 16000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 257),
      Ibatv_Offset =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 16000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 257),
      Battery_Continue =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 11),
      Beeper_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 503),
      Beeper_Od =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 503),
      Beeper_Frequency =>
        (Kind => I16, Where => Hardware, How => Direct, Min => 0, Max => 16000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 503),
      Beeper_Dshot_Beacon_Tone =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 5, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 502),
      Yaw_Motors_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20),
      Mixer_Type =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Mixer_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Crashflip_Motor_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Crashflip_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Crashflip_Auto_Rearm =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20),
      Rpm_Limit =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20),
      Rpm_Limit_P =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Rpm_Limit_I =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Rpm_Limit_D =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Rpm_Limit_Value =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Three_D_Deadband_Low =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 1500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 26),
      Three_D_Deadband_High =>
        (Kind => U16, Where => Master, How => Direct, Min => 1500, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 26),
      Three_D_Neutral =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 26),
      Three_D_Deadband_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 26),
      Three_D_Limit_Low =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 1500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 26),
      Three_D_Limit_High =>
        (Kind => U16, Where => Master, How => Direct, Min => 1500, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 26),
      Three_D_Switched_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 26),
      Servo_Center_Pulse =>
        (Kind => U16, Where => Master, How => Direct, Min => 750, Max => 2250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 52),
      Servo_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 498, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 52),
      Servo_Lowpass_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 400, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 52),
      Tri_Unarmed_Servo =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52),
      Channel_Forwarding_Start =>
        (Kind => U8, Where => Master, How => Direct, Min => 4, Max => 18, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 52),
      Rateprofile_Name =>
        (Kind => U8, Where => Rate_Profile, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 8,
         Min_Length => 1, Write_Once => False, Group => 12),
      Thr_Mid =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Thr_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Thr_Hover =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Rates_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Rates_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Quickrates_Rc_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Roll_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Pitch_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Yaw_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Roll_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Pitch_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Yaw_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Roll_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Pitch_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Yaw_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Throttle_Limit_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Throttle_Limit_Type,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 12),
      Throttle_Limit_Percent =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Min => 25, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 12),
      Roll_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Min => 200, Max => 1998, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 12),
      Pitch_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Min => 200, Max => 1998, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 12),
      Yaw_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Min => 200, Max => 1998, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 12),
      Reboot_Character =>
        (Kind => U8, Where => Master, How => Direct, Min => 48, Max => 126, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 13),
      Serial_Update_Rate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 13),
      Imu_Dcm_Kp =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 22),
      Imu_Dcm_Ki =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 22),
      Small_Angle =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 180, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 22),
      Imu_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 4, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 22),
      Mag_Declination =>
        (Kind => I16, Where => Master, How => Direct, Min => -300, Max => 300, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 22),
      Auto_Disarm_Delay =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 60, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 16),
      Gyro_Cal_On_First_Arm =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 16),
      Prearm_Allow_Rearm =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 16),
      Gps_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gps_Provider, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Sbas_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gps_Sbas_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Auto_Config =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 30),
      Gps_Auto_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 30),
      Gps_Ublox_Acquire_Model =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gps_Ublox_Models, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Ublox_Flight_Model =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gps_Ublox_Models, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Update_Rate_Hz =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 20, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Ublox_Utc_Standard =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gps_Ublox_Utc_Standard, Count
         => 0, Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Ublox_Use_Galileo =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 30),
      Gps_Ublox_Enable_Ana =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 30),
      Gps_Set_Home_Point_Once =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 30),
      Gps_Use_3d_Speed =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 30),
      Gps_Sbas_Integrity =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 30),
      Gps_Nmea_Custom_Commands =>
        (Kind => U8, Where => Master, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 64, Min_Length
         => 1, Write_Once => False, Group => 30),
      Gps_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 30),
      Gps_Rescue_Min_Start_Dist =>
        (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 30, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Alt_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gps_Rescue_Alt_Mode, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Initial_Climb =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Ascend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 2500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Return_Alt =>
        (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Ground_Speed =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 3000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Descent_Dist =>
        (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Descend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Min => 25, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Sanity_Checks =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Gps_Rescue_Sanity_Check, Count
         => 0, Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Min_Sats =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Allow_Arming_Without_Fix =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 55),
      Gps_Rescue_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Gps_Lap_Timer_Gate_Lat =>
        (Kind => I32, Where => Master, How => Direct, Min => -900000000, Max => 900000000, Table => Table_Off_On,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 58),
      Gps_Lap_Timer_Gate_Lon =>
        (Kind => I32, Where => Master, How => Direct, Min => -1800000000, Max => 1800000000, Table => Table_Off_On,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 58),
      Gps_Lap_Timer_Min_Lap_Time_S =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 3000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 58),
      Gps_Lap_Timer_Gate_Tolerance_M =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 58),
      Deadband =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 32, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 25),
      Yaw_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 25),
      Yaw_Control_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 25),
      Alt_Hold_Climb_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 59),
      Alt_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 70, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 59),
      Pos_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 61),
      Poshold_Position_Source =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Poshold_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 61),
      Poshold_Opticalflow_Quality_Min =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 61),
      Poshold_Opticalflow_Max_Range =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 61),
      Pid_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 16, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 504),
      Runaway_Takeoff_Prevention =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 504),
      Runaway_Takeoff_Deactivate_Delay =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 504),
      Runaway_Takeoff_Deactivate_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 504),
      Profile_Name =>
        (Kind => U8, Where => PID_Profile, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 8,
         Min_Length => 1, Write_Once => False, Group => 14),
      Dterm_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 10, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Lpf1_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Dterm_Lpf_Type, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Lpf1_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Lpf2_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Dterm_Lpf_Type, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Lpf2_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Notch_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dterm_Notch_Cutoff =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Vbat_Sag_Compensation =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 150, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Pid_At_Min_Throttle =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Anti_Gravity_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Anti_Gravity_Cutoff_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 2, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Anti_Gravity_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Acc_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Acc_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Dthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 10, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Gthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Setpoint_Threshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 50, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Time =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Recovery_Angle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 5, Max => 30, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Recovery_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 50, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Crash_Recovery =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Crash_Recovery, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 14),
      Iterm_Rotation =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Iterm_Relax =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Iterm_Relax, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Iterm_Relax_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Iterm_Relax_Type, Count
         => 0, Min_Length => 0, Write_Once => False, Group => 14),
      Iterm_Relax_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Iterm_Windup =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 20, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Pidsum_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Pidsum_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 100, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Yaw_Lowpass_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Throttle_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Throttle_Boost_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 5, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Acro_Trainer_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 80, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Acro_Trainer_Lookahead_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 10, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Acro_Trainer_Debug_Axis =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Acro_Trainer_Debug, Count
         => 0, Min_Length => 0, Write_Once => False, Group => 14),
      Acro_Trainer_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 25, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      P_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      I_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      F_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      P_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      I_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      F_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      P_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      I_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      F_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Angle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Angle_Feedforward =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Angle_Feedforward_Smoothing_Ms =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 80, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Angle_Earth_Ref =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Horizon_Level_Strength =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Horizon_Limit_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Horizon_Limit_Degrees =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Horizon_Ignore_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Horizon_Delay_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 10, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Lag_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Lead_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Amplitude_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Amplitude_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Amplitude_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Frequency_Start_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Frequency_End_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1, Max => 10000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Time_Seconds =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Chirp_Repeat =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 9, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Max_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Max_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Max_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      D_Max_Advance =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Motor_Output_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Auto_Profile_Cell_Count =>
        (Kind => I8, Where => PID_Profile, How => Direct, Min => -1, Max => 8, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Launch_Control_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Launch_Control_Mode,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 14),
      Launch_Trigger_Allow_Reset =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Launch_Trigger_Throttle_Percent =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 90, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Launch_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 80, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Launch_Control_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Thrust_Linear =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 150, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Transition =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Averaging =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Feedforward_Averaging,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Smooth_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 95, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Jitter_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 20, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Max_Rate_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Yaw_Hold_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Feedforward_Yaw_Hold_Time =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dyn_Idle_Min_Rpm =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dyn_Idle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dyn_Idle_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 1, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dyn_Idle_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Dyn_Idle_Max_Increase =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Level_Race_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Pids_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table =>
         Table_Simplified_Tuning_Pids_Mode, Count => 0, Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Master_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Feedforward_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Pitch_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Pitch_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Dterm_Filter =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Dterm_Filter_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 10, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Simplified_Gyro_Filter =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 10),
      Simplified_Gyro_Filter_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 10),
      Tpa_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Tpa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Tpa_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Tpa_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1000, Max => 2000, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 14),
      Tpa_Low_Rate =>
        (Kind => I8, Where => PID_Profile, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Tpa_Low_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Min => 1000, Max => 2000, Table => Table_Off_On, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 14),
      Tpa_Low_Always =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Ez_Landing_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Ez_Landing_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 75, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Ez_Landing_Speed =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Landing_Disarm_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Min => 0, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 14),
      Tlm_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Tlm_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Telemetry_1_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Telemetry_Protocol, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_1_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_2_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Telemetry_Protocol, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_2_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_3_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Telemetry_Protocol, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_3_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Crsf_Tlm_Accgyro =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Frsky_Default_Lat =>
        (Kind => I16, Where => Master, How => Direct, Min => -9000, Max => 9000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Frsky_Default_Long =>
        (Kind => I16, Where => Master, How => Direct, Min => -18000, Max => 18000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Frsky_Gps_Format =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Frsky_Unit =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Unit, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Frsky_Vfas_Precision =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Hott_Alarm_Int =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 120, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Pid_In_Tlm =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Report_Cell_Voltage =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 31),
      Ibus_Sensor =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 15, Min_Length
         => 0, Write_Once => False, Group => 31),
      Mavlink_Mah_As_Heading_Divisor =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 30000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Mavlink_Min_Txbuff =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Mavlink_Ext_Status_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Mavlink_Rc_Chan_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Mavlink_Pos_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Mavlink_Extra1_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Mavlink_Extra2_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Mavlink_Extra3_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Current =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 1,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Fuel =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 2,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Mode =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 3,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Acc_X =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 4,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Acc_Y =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 5,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Acc_Z =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 6,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Pitch =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 7,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Roll =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 8,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Heading =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 9,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Altitude =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 10,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Vario =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 11,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Lat_Long =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 12,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Ground_Speed =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 13,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Distance =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 14,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Esc_Current =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 15,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Esc_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 16,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Esc_Rpm =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 17,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Esc_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 18,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 19,
         Min_Length => 0, Write_Once => False, Group => 31),
      Telemetry_Disabled_Cap_Used =>
        (Kind => U32, Where => Master, How => Bitset, Min => 0, Max => 0, Table => Table_Off_On, Count => 20,
         Min_Length => 0, Write_Once => False, Group => 31),
      Ledstrip_Visual_Beeper =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 27),
      Ledstrip_Visual_Beeper_Color =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Grb_Rgb =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Rgb_Grb, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Profile =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Led_Profile, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Race_Color =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Beacon_Color =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Beacon_Period_Ms =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 10000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Beacon_Percent =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Beacon_Armed_Only =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 27),
      Ledstrip_Brightness =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Rainbow_Delta =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 359, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Ledstrip_Rainbow_Freq =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Transponder_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Transponder_Provider, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 17),
      Transponder_Data =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 9, Min_Length
         => 0, Write_Once => False, Group => 17),
      Sdcard_Detect_Inverted =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 511),
      Sdcard_Mode =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Sdcard_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 511),
      Osd_Units =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Unit, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Warn_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Rssi_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Link_Quality_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Rssi_Dbm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -130, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Rsnr_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -30, Max => 20, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Cap_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 20000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Alt_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 10000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Distance_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Esc_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Esc_Rpm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -1, Max => 32767, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Esc_Current_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Min => -1, Max => 32767, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Core_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Ah_Max_Pit =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Ah_Max_Rol =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Ah_Invert =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Logo_On_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Osd_Logo_On_Arming, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Logo_On_Arming_Duration =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Arming_Logo =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Use_Quick_Menu =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Show_Spec_Prearm =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Tim1 =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32767, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Tim2 =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 32767, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Vbat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Rssi_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Link_Quality_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Link_Tx_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Rssi_Dbm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Rsnr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Tim_1_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Tim_2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Remaining_Time_Estimate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Flymode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Anti_Gravity_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_G_Force_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Throttle_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Vtx_Channel_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Crosshairs_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Ah_Sbar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Ah_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Current_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Mah_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wh_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Motor_Diag_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Craft_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pilot_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Gps_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Gps_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Gps_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Gps_Lap_Curr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Gps_Lap_Prev_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Gps_Lap_Best3_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Gps_Sats_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Home_Dir_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Home_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Flight_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Compass_Bar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Altitude_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pid_Roll_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pid_Pitch_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pid_Yaw_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Debug_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Debug2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pidrate_Profile_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Avg_Cell_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pit_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Rol_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Battery_Usage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Disarmed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Nheading_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Up_Down_Reference_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Ready_Mode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pos_Hold_Ready_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Nvario_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Esc_Tmp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Esc_Rpm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Esc_Rpm_Freq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Rtc_Date_Time_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Adjustment_Range_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Flip_Arrow_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Core_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Log_Status_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Stick_Overlay_Left_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Stick_Overlay_Right_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Stick_Overlay_Radio_Mode =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 4, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Rate_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Pid_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Battery_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Rcchannels_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Camera_Frame_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Efficiency_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Total_Flights_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Aux_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Goggle_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Vtx_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Bitrate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Delay_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Lq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Goggle_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Vtx_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Vtx_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Sys_Fan_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Stat_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Profile =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 3, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Profile_1_Name =>
        (Kind => U8, Where => Master, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16, Min_Length
         => 1, Write_Once => False, Group => 501),
      Osd_Profile_2_Name =>
        (Kind => U8, Where => Master, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16, Min_Length
         => 1, Write_Once => False, Group => 501),
      Osd_Profile_3_Name =>
        (Kind => U8, Where => Master, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16, Min_Length
         => 1, Write_Once => False, Group => 501),
      Osd_Gps_Sats_Show_Pdop =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Displayport_Device =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Osd_Displayport_Device, Count
         => 0, Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Rcchannels =>
        (Kind => I8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 4, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Camera_Frame_Width =>
        (Kind => U8, Where => Master, How => Direct, Min => 2, Max => 30, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Camera_Frame_Height =>
        (Kind => U8, Where => Master, How => Direct, Min => 2, Max => 16, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Stat_Avg_Cell_Value =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Framerate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 60, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Menu_Background =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Cms_Background, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Aux_Channel =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 18, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Aux_Scale =>
        (Kind => U16, Where => Master, How => Direct, Min => 1, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Aux_Symbol =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Craftname_Msgs =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 501),
      Osd_Lidar_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Custom_Serial_Text_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Custom_Serial_Text_Terminator =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Osd_Custom_Text_Terminator,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 2044),
      Osd_Custom_Text_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Custom_Text_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 501),
      Osd_Wp_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wp_Current_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wp_Current_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wp_Current_Alt_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wp_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wp_Direction_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wp_Next_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Wp_Eta_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Nav_Map_Pos =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      Osd_Nav_Map_Mode =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 568),
      Osd_Nav_Map_Centre =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 568),
      Osd_Nav_Map_Min_Scale_M =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 568),
      Osd_Airspeed =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 2045),
      System_Hse_Mhz =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 30, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18),
      Task_Statistics =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 18),
      Debug_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Debug, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 18),
      Rate_6pos_Switch =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 18),
      Cpu_Overclock =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Overclock, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18),
      Pwr_On_Arm_Grace =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 30, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18),
      Enable_Stick_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 18),
      Vtx_Band =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 8, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 259),
      Vtx_Channel =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 8, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 259),
      Vtx_Power =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 7, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 259),
      Vtx_Low_Power_Disarm =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Vtx_Low_Power_Disarm, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 259),
      Vtx_Softserial_Alt =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 259),
      Vtx_Type =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Vtx_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 259),
      Vtx_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 259),
      Vtx_Freq =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 5999, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 259),
      Vtx_Pit_Mode_Freq =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 5999, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 259),
      Vtx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 515),
      Vtx_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 57),
      Vcd_Video_System =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Video_System, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 514),
      Vcd_H_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -32, Max => 31, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 514),
      Vcd_V_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -15, Max => 16, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 514),
      Max7456_Clock =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Max7456_Clock, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 524),
      Max7456_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 524),
      Max7456_Preinit_Opu =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 524),
      Displayport_Msp_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -6, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 512),
      Displayport_Msp_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -3, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 512),
      Displayport_Msp_Fonts =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 4, Min_Length
         => 0, Write_Once => False, Group => 512),
      Displayport_Msp_Use_Device_Blink =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 512),
      Displayport_Max7456_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -6, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 513),
      Displayport_Max7456_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Min => -3, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 513),
      Displayport_Max7456_Inv =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 513),
      Displayport_Max7456_Blk =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 513),
      Displayport_Max7456_Wht =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 513),
      Esc_Sensor_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 517),
      Esc_Sensor_Current_Offset =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 16000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 517),
      Esc_Sensor_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 517),
      Frsky_Spi_Autobind =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 523),
      Frsky_Spi_Tx_Id =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 3, Min_Length
         => 0, Write_Once => False, Group => 523),
      Frsky_Spi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -127, Max => 127, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 523),
      Frsky_Spi_Bind_Hop_Data =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 50, Min_Length
         => 0, Write_Once => False, Group => 523),
      Frsky_X_Rx_Num =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 523),
      Frsky_Spi_A1_Source =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Rx_Frsky_Spi_A1_Source, Count
         => 0, Min_Length => 0, Write_Once => False, Group => 523),
      Cc2500_Spi_Chip_Detect =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 523),
      Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 7, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 505),
      Dashboard_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 519),
      Dashboard_I2c_Addr =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 8, Max => 119, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 519),
      Rangefinder_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Rangefinder_Hardware, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 527),
      Rangefinder_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 527),
      Opticalflow_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Opticalflow_Hardware, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 560),
      Opticalflow_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 560),
      Opticalflow_Rotation =>
        (Kind => I16, Where => Master, How => Direct, Min => 0, Max => 359, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 560),
      Opticalflow_Flip_X =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 560),
      Pinio_Config =>
        (Kind => U8, Where => Hardware, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 4, Min_Length
         => 0, Write_Once => False, Group => 529),
      Pinio_Box =>
        (Kind => U8, Where => Hardware, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 4, Min_Length
         => 0, Write_Once => False, Group => 530),
      Usb_Hid_Cdc =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 531),
      Usb_Msc_Pin_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 531),
      Flash_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 506),
      Rcdevice_Init_Dev_Attempts =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 10, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 539),
      Rcdevice_Init_Dev_Attempt_Interval =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 539),
      Rcdevice_Protocol_Version =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 1, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 539),
      Rcdevice_Feature =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 65535, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 539),
      Rcdevice_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 539),
      Gyro_1_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Bus_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 540),
      Gyro_1_Spibus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 540),
      Gyro_1_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 540),
      Gyro_1_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Min => 0, Max => 119, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 540),
      I2c1_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 518),
      I2c1_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 100, Max => 1300, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 518),
      I2c2_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 518),
      I2c2_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 100, Max => 1300, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 518),
      I2c3_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 518),
      I2c3_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 100, Max => 1300, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 518),
      Mco2_On_Pc9 =>
        (Kind => U8, Where => Hardware, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 541),
      Spektrum_Spi_Protocol =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 542),
      Spektrum_Spi_Mfg_Id =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 4, Min_Length
         => 0, Write_Once => False, Group => 542),
      Spektrum_Spi_Num_Channels =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 12, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 542),
      Expresslrs_Uid =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 6, Min_Length
         => 0, Write_Once => False, Group => 555),
      Expresslrs_Domain =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Freq_Domain, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 555),
      Expresslrs_Model_Id =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 555),
      Scheduler_Relax_Rx =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 556),
      Scheduler_Relax_Osd =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 556),
      Scheduler_Debug_Task =>
        (Kind => U16, Where => Hardware, How => Direct, Min => 0, Max => 40, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 556),
      Cpu_Late_Limit_Permille =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 556),
      Serialmsp_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 557),
      Msp_1_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 557),
      Msp_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 557),
      Msp_2_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 557),
      Msp_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 557),
      Msp_3_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 557),
      Msp_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Baud_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 557),
      Timezone_Offset_Minutes =>
        (Kind => I16, Where => Master, How => Direct, Min => -780, Max => 780, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 526),
      Rpm_Filter_Harmonics =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 3, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 544),
      Rpm_Filter_Weights =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 3, Min_Length
         => 0, Write_Once => False, Group => 544),
      Rpm_Filter_Q =>
        (Kind => U16, Where => Master, How => Direct, Min => 250, Max => 3000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 544),
      Rpm_Filter_Min_Hz =>
        (Kind => U8, Where => Master, How => Direct, Min => 30, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 544),
      Rpm_Filter_Fade_Range_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 544),
      Rpm_Filter_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 544),
      Flysky_Spi_Tx_Id =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 525),
      Flysky_Spi_Rf_Channels =>
        (Kind => U8, Where => Master, How => List, Min => 0, Max => 0, Table => Table_Off_On, Count => 16, Min_Length
         => 0, Write_Once => False, Group => 525),
      Stats_Min_Armed_Time_S =>
        (Kind => I8, Where => Master, How => Direct, Min => -1, Max => 127, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 547),
      Stats_Total_Flights =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 547),
      Stats_Total_Time_S =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 547),
      Stats_Total_Dist_M =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 547),
      Stats_Save_Move_Limit =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 255, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 547),
      Stats_Mah_Used =>
        (Kind => U32, Where => Master, How => Direct, Min => 0, Max => 4294967295, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 547),
      Craft_Name =>
        (Kind => U8, Where => Master, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16, Min_Length
         => 1, Write_Once => False, Group => 47),
      Pilot_Name =>
        (Kind => U8, Where => Master, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16, Min_Length
         => 1, Write_Once => False, Group => 47),
      Altitude_Source =>
        (Kind => I8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Position_Alt_Source, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 56),
      Altitude_Prefer_Baro =>
        (Kind => I8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 56),
      Altitude_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 56),
      Rangefinder_Max_Range_Cm =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 56),
      Altitude_D_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 56),
      Ap_Landing_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Hover_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 1700, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Throttle_Min =>
        (Kind => U16, Where => Master, How => Direct, Min => 1050, Max => 1400, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Throttle_Max =>
        (Kind => U16, Where => Master, How => Direct, Min => 1400, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Altitude_P =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Altitude_I =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Altitude_D =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Altitude_A =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Altitude_F =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Position_P =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Position_I =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Position_D =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Position_A =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Position_F =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Position_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Stop_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Max_Angle =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 70, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Max_Yaw_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 250, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Velocity_Drag_Coeff =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Max_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Waypoint_Arrival_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Waypoint_Hold_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Stick_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Throttle_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Yaw_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Ap_Yaw_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Min_Forward_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Nav_Corner_Speed =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Nav_Corner_Delta_V =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 4000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Nav_Decel =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Nav_Accel =>
        (Kind => U16, Where => Master, How => Direct, Min => 20, Max => 1000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Nav_Carrot_Lead_Time =>
        (Kind => U8, Where => Master, How => Direct, Min => 2, Max => 40, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Nav_Carrot_Lead_Max =>
        (Kind => U16, Where => Master, How => Direct, Min => 600, Max => 6000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Nav_Preturn_Dist =>
        (Kind => U16, Where => Master, How => Direct, Min => 500, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Velocity_Buildup_Max_Pitch =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 20, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Max_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 90, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Hold_Orbit_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 300, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Hold_Figure8_Width =>
        (Kind => U16, Where => Master, How => Direct, Min => 500, Max => 10000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Landing_Descent_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Landing_Detection_Time =>
        (Kind => U8, Where => Master, How => Direct, Min => 5, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Landing_Spiral_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 60),
      Ap_Landing_Spiral_Radius =>
        (Kind => U16, Where => Master, How => Direct, Min => 50, Max => 2000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Landing_Spiral_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 1, Max => 45, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Landing_Velocity_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Min => 10, Max => 200, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Landing_Throttle_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Min => 10, Max => 500, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_L1_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 60),
      Ap_L1_Period =>
        (Kind => U16, Where => Master, How => Direct, Min => 5, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_L1_Min_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Min => 100, Max => 5000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_L1_Max_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Min => 1000, Max => 50000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_L1_Max_Cross_Track_Error =>
        (Kind => U16, Where => Master, How => Direct, Min => 1000, Max => 50000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_L1_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 90, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Min_Nav_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Min => 0, Max => 50, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Rx_Loss_Policy =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Ap_Rx_Loss_Policy, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Max_Distance_From_Home =>
        (Kind => U16, Where => Master, How => Direct, Min => 0, Max => 10000, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 60),
      Ap_Geofence_Action =>
        (Kind => U8, Where => Master, How => Lookup, Min => 0, Max => 0, Table => Table_Ap_Geofence_Action, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 60),
      Box_User_1_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16,
         Min_Length => 1, Write_Once => False, Group => 553),
      Box_User_2_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16,
         Min_Length => 1, Write_Once => False, Group => 553),
      Box_User_3_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16,
         Min_Length => 1, Write_Once => False, Group => 553),
      Box_User_4_Name =>
        (Kind => U8, Where => Hardware, How => Text, Min => 0, Max => 0, Table => Table_Off_On, Count => 16,
         Min_Length => 1, Write_Once => False, Group => 553),
      Gimbal_Roll_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Pitch_Rc_Thr_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Pitch_Rc_Low_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Pitch_Rc_High_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Yaw_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Roll_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Roll_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Roll_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Pitch_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Pitch_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Pitch_Low_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Pitch_High_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Yaw_Gain =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Yaw_Offset =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Yaw_Limit =>
        (Kind => I8, Where => Master, How => Direct, Min => -100, Max => 100, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Stabilisation =>
        (Kind => I8, Where => Master, How => Direct, Min => 0, Max => 7, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 559),
      Gimbal_Sensitivity =>
        (Kind => I8, Where => Master, How => Direct, Min => -16, Max => 15, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559),
      Gimbal_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Min => 0, Max => 0, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 559));

   function Describe (S : Setting) return Info is (Infos (S));

   --  The setting names in one text, each at its start for its length; the
   --  text ends with room for a longest name, so every slice stays within
   --  it by the types alone.
   Names_Length : constant := 13947;
   Names : constant String (1 .. Names_Length + Max_Name_Length) :=
     "gyro_hardware_lpfgyro_lpf1_typegyro_lpf1_static_hzgyro_lpf2_typegyro_lpf2_static_hzgyro_notch1_hzgyro_notch"
     & "1_cutoffgyro_notch2_hzgyro_notch2_cutoffgyro_calib_durationgyro_calib_noise_limitgyro_offset_yawgyro_overfl"
     & "ow_detectyaw_spin_recoveryyaw_spin_thresholddyn_notch_countdyn_notch_qdyn_notch_min_hzdyn_notch_max_hzgyro_"
     & "lpf1_dyn_min_hzgyro_lpf1_dyn_max_hzgyro_lpf1_dyn_expogyro_filter_debug_axisacc_hardwareacc_lpf_hzacc_trim_p"
     & "itchacc_trim_rollacc_calibrationalign_magmag_align_rollmag_align_pitchmag_align_yawmag_bustypemag_i2c_devic"
     & "emag_i2c_addressmag_spi_devicemag_hardwaremag_calibrationbaro_bustypebaro_spi_devicebaro_i2c_devicebaro_i2c"
     & "_addressbaro_hardwarebaro_driftpitot_bustypepitot_i2c_devicepitot_i2c_addresspitot_hardwaremid_rcmin_checkm"
     & "ax_checkrssi_channelrssi_src_frame_errorsrssi_scalerssi_offsetrssi_invertrssi_src_frame_lpf_periodrssi_smoo"
     & "thingrc_smoothingrc_smoothing_auto_factorrc_smoothing_auto_factor_throttlerc_smoothing_setpoint_cutoffrc_sm"
     & "oothing_throttle_cutoffrc_smoothing_debug_axisfpv_mix_degreesmax_aux_channelsserialrx_providerserialrx_inve"
     & "rtedspektrum_sat_bindspektrum_sat_bind_autoresetsrxl2_unit_idsrxl2_baud_fastsbus_baud_fastcrsf_use_negotiat"
     & "ed_baudairmode_start_throttle_percentrx_min_usecrx_max_usecserialrx_halfduplexrx_uartmsp_override_channels_"
     & "maskmsp_override_failsaferx_spi_protocolrx_spi_busrx_spi_led_inversionadc_deviceadc_vrefint_calibrationadc_"
     & "tempsensor_calibration30adc_tempsensor_calibration110input_filtering_modeblackbox_sample_rateblackbox_devic"
     & "eblackbox_disable_pidsblackbox_disable_rcblackbox_disable_setpointblackbox_disable_batblackbox_disable_magb"
     & "lackbox_disable_altblackbox_disable_rssiblackbox_disable_gyroblackbox_disable_gyrounfiltblackbox_disable_ac"
     & "cblackbox_disable_attitudeblackbox_disable_debugblackbox_disable_motorsblackbox_disable_servosblackbox_disa"
     & "ble_rpmblackbox_disable_gpsblackbox_disable_pitotblackbox_modeblackbox_high_resolutionblackbox_uartblackbox"
     & "_baudmax_throttlemin_commandmotor_kvmotor_idledshot_burstdshot_bidirdshot_edtdshot_bitbangdshot_bitbang_tim"
     & "eruse_unsynced_pwmmotor_pwm_protocolmotor_pwm_ratemotor_pwm_inversionmotor_polesmotor_output_reorderingthr_"
     & "corr_valuethr_corr_anglefailsafe_delayfailsafe_landing_timefailsafe_throttlefailsafe_switch_modefailsafe_th"
     & "rottle_low_delayfailsafe_procedurefailsafe_recovery_delayfailsafe_stick_thresholdalign_board_rollalign_boar"
     & "d_pitchalign_board_yawgimbal_modebattery_profile_namebat_capacityvbat_max_cell_voltagevbat_full_cell_voltag"
     & "evbat_min_cell_voltagevbat_warning_cell_voltagecbat_alert_percentforce_battery_cell_countvbat_hysteresiscur"
     & "rent_meterbattery_metervbat_detect_cell_voltageuse_vbat_alertsuse_cbat_alertsvbat_cutoff_percentvbat_displa"
     & "y_lpf_periodvbat_sag_lpf_periodibat_lpf_periodvbat_duration_for_warningvbat_duration_for_criticalvbat_scale"
     & "vbat_dividervbat_multiplieribata_scaleibata_offsetibatv_scaleibatv_offsetbattery_continuebeeper_inversionbe"
     & "eper_odbeeper_frequencybeeper_dshot_beacon_toneyaw_motors_reversedmixer_typecrashflip_motor_percentcrashfli"
     & "p_ratecrashflip_auto_rearmrpm_limitrpm_limit_prpm_limit_irpm_limit_drpm_limit_value3d_deadband_low3d_deadba"
     & "nd_high3d_neutral3d_deadband_throttle3d_limit_low3d_limit_high3d_switched_modeservo_center_pulseservo_pwm_r"
     & "ateservo_lowpass_hztri_unarmed_servochannel_forwarding_startrateprofile_namethr_midthr_expothr_hoverrates_t"
     & "ypequickrates_rc_exporoll_rc_ratepitch_rc_rateyaw_rc_rateroll_expopitch_expoyaw_exporoll_sratepitch_srateya"
     & "w_sratethrottle_limit_typethrottle_limit_percentroll_rate_limitpitch_rate_limityaw_rate_limitreboot_charact"
     & "erserial_update_rate_hzimu_dcm_kpimu_dcm_kismall_angleimu_process_denommag_declinationauto_disarm_delaygyro"
     & "_cal_on_first_armprearm_allow_rearmgps_providergps_sbas_modegps_auto_configgps_auto_baudgps_ublox_acquire_m"
     & "odelgps_ublox_flight_modelgps_update_rate_hzgps_ublox_utc_standardgps_ublox_use_galileogps_ublox_enable_ana"
     & "gps_set_home_point_oncegps_use_3d_speedgps_sbas_integritygps_nmea_custom_commandsgps_uartgps_baudgps_rescue"
     & "_min_start_distgps_rescue_alt_modegps_rescue_initial_climbgps_rescue_ascend_rategps_rescue_return_altgps_re"
     & "scue_ground_speedgps_rescue_descent_distgps_rescue_descend_rategps_rescue_sanity_checksgps_rescue_min_satsg"
     & "ps_rescue_allow_arming_without_fixgps_rescue_yaw_pgps_lap_timer_gate_latgps_lap_timer_gate_longps_lap_timer"
     & "_min_lap_time_sgps_lap_timer_gate_tolerance_mdeadbandyaw_deadbandyaw_control_reversedalt_hold_climb_ratealt"
     & "_hold_deadbandpos_hold_deadbandposhold_position_sourceposhold_opticalflow_quality_minposhold_opticalflow_ma"
     & "x_rangepid_process_denomrunaway_takeoff_preventionrunaway_takeoff_deactivate_delayrunaway_takeoff_deactivat"
     & "e_throttle_percentprofile_namedterm_lpf1_dyn_min_hzdterm_lpf1_dyn_max_hzdterm_lpf1_dyn_expodterm_lpf1_typed"
     & "term_lpf1_static_hzdterm_lpf2_typedterm_lpf2_static_hzdterm_notch_hzdterm_notch_cutoffvbat_sag_compensation"
     & "pid_at_min_throttleanti_gravity_gainanti_gravity_cutoff_hzanti_gravity_p_gainacc_limit_yawacc_limitcrash_dt"
     & "hresholdcrash_gthresholdcrash_setpoint_thresholdcrash_timecrash_delaycrash_recovery_anglecrash_recovery_rat"
     & "ecrash_limit_yawcrash_recoveryiterm_rotationiterm_relaxiterm_relax_typeiterm_relax_cutoffiterm_winduppidsum"
     & "_limitpidsum_limit_yawyaw_lowpass_hzthrottle_boostthrottle_boost_cutoffacro_trainer_angle_limitacro_trainer"
     & "_lookahead_msacro_trainer_debug_axisacro_trainer_gainp_pitchi_pitchd_pitchf_pitchp_rolli_rolld_rollf_rollp_"
     & "yawi_yawd_yawf_yawangle_p_gainangle_feedforwardangle_feedforward_smoothing_msangle_limitangle_earth_refhori"
     & "zon_level_strengthhorizon_limit_stickshorizon_limit_degreeshorizon_ignore_stickshorizon_delay_mschirp_lag_f"
     & "req_hzchirp_lead_freq_hzchirp_amplitude_rollchirp_amplitude_pitchchirp_amplitude_yawchirp_frequency_start_d"
     & "eci_hzchirp_frequency_end_deci_hzchirp_time_secondschirp_repeatd_max_rolld_max_pitchd_max_yawd_max_gaind_ma"
     & "x_advancemotor_output_limitauto_profile_cell_countlaunch_control_modelaunch_trigger_allow_resetlaunch_trigg"
     & "er_throttle_percentlaunch_angle_limitlaunch_control_gainthrust_linearfeedforward_transitionfeedforward_aver"
     & "agingfeedforward_smooth_factorfeedforward_jitter_factorfeedforward_boostfeedforward_max_rate_limitfeedforwa"
     & "rd_yaw_hold_gainfeedforward_yaw_hold_timedyn_idle_min_rpmdyn_idle_p_gaindyn_idle_i_gaindyn_idle_d_gaindyn_i"
     & "dle_max_increaselevel_race_modesimplified_pids_modesimplified_master_multipliersimplified_i_gainsimplified_"
     & "d_gainsimplified_pi_gainsimplified_d_max_gainsimplified_feedforward_gainsimplified_pitch_d_gainsimplified_p"
     & "itch_pi_gainsimplified_dterm_filtersimplified_dterm_filter_multipliersimplified_gyro_filtersimplified_gyro_"
     & "filter_multipliertpa_modetpa_ratetpa_breakpointtpa_low_ratetpa_low_breakpointtpa_low_alwaysez_landing_thres"
     & "holdez_landing_limitez_landing_speedlanding_disarm_thresholdtlm_invertedtlm_halfduplextelemetry_1_protocolt"
     & "elemetry_1_uarttelemetry_1_baudtelemetry_2_protocoltelemetry_2_uarttelemetry_2_baudtelemetry_3_protocoltele"
     & "metry_3_uarttelemetry_3_baudcrsf_tlm_accgyrofrsky_default_latfrsky_default_longfrsky_gps_formatfrsky_unitfr"
     & "sky_vfas_precisionhott_alarm_intpid_in_tlmreport_cell_voltageibus_sensormavlink_mah_as_heading_divisormavli"
     & "nk_min_txbuffmavlink_ext_status_ratemavlink_rc_chan_ratemavlink_pos_ratemavlink_extra1_ratemavlink_extra2_r"
     & "atemavlink_extra3_ratetelemetry_disabled_voltagetelemetry_disabled_currenttelemetry_disabled_fueltelemetry_"
     & "disabled_modetelemetry_disabled_acc_xtelemetry_disabled_acc_ytelemetry_disabled_acc_ztelemetry_disabled_pit"
     & "chtelemetry_disabled_rolltelemetry_disabled_headingtelemetry_disabled_altitudetelemetry_disabled_variotelem"
     & "etry_disabled_lat_longtelemetry_disabled_ground_speedtelemetry_disabled_distancetelemetry_disabled_esc_curr"
     & "enttelemetry_disabled_esc_voltagetelemetry_disabled_esc_rpmtelemetry_disabled_esc_temperaturetelemetry_disa"
     & "bled_temperaturetelemetry_disabled_cap_usedledstrip_visual_beeperledstrip_visual_beeper_colorledstrip_grb_r"
     & "gbledstrip_profileledstrip_race_colorledstrip_beacon_colorledstrip_beacon_period_msledstrip_beacon_percentl"
     & "edstrip_beacon_armed_onlyledstrip_brightnessledstrip_rainbow_deltaledstrip_rainbow_freqtransponder_provider"
     & "transponder_datasdcard_detect_invertedsdcard_modeosd_unitsosd_warn_bitmaskosd_rssi_alarmosd_link_quality_al"
     & "armosd_rssi_dbm_alarmosd_rsnr_alarmosd_cap_alarmosd_alt_alarmosd_distance_alarmosd_esc_temp_alarmosd_esc_rp"
     & "m_alarmosd_esc_current_alarmosd_core_temp_alarmosd_ah_max_pitosd_ah_max_rolosd_ah_invertosd_logo_on_armingo"
     & "sd_logo_on_arming_durationosd_arming_logoosd_use_quick_menuosd_show_spec_prearmosd_tim1osd_tim2osd_vbat_pos"
     & "osd_rssi_pososd_link_quality_pososd_link_tx_power_pososd_rssi_dbm_pososd_rsnr_pososd_tim_1_pososd_tim_2_pos"
     & "osd_remaining_time_estimate_pososd_flymode_pososd_anti_gravity_pososd_g_force_pososd_throttle_pososd_vtx_ch"
     & "annel_pososd_crosshairs_pososd_ah_sbar_pososd_ah_pososd_current_pososd_mah_drawn_pososd_wh_drawn_pososd_mot"
     & "or_diag_pososd_craft_name_pososd_pilot_name_pososd_gps_speed_pososd_gps_lon_pososd_gps_lat_pososd_gps_lap_c"
     & "urr_pososd_gps_lap_prev_pososd_gps_lap_best3_pososd_gps_sats_pososd_home_dir_pososd_home_dist_pososd_flight"
     & "_dist_pososd_compass_bar_pososd_altitude_pososd_pid_roll_pososd_pid_pitch_pososd_pid_yaw_pososd_debug_posos"
     & "d_debug2_pososd_power_pososd_pidrate_profile_pososd_warnings_pososd_avg_cell_voltage_pososd_pit_ang_pososd_"
     & "rol_ang_pososd_battery_usage_pososd_disarmed_pososd_nheading_pososd_up_down_reference_pososd_ready_mode_pos"
     & "osd_pos_hold_ready_pososd_nvario_pososd_esc_tmp_pososd_esc_rpm_pososd_esc_rpm_freq_pososd_rtc_date_time_pos"
     & "osd_adjustment_range_pososd_flip_arrow_pososd_core_temp_pososd_log_status_pososd_stick_overlay_left_pososd_"
     & "stick_overlay_right_pososd_stick_overlay_radio_modeosd_rate_profile_name_pososd_pid_profile_name_pososd_bat"
     & "tery_profile_name_pososd_profile_name_pososd_rcchannels_pososd_camera_frame_pososd_efficiency_pososd_total_"
     & "flights_pososd_aux_pososd_sys_goggle_voltage_pososd_sys_vtx_voltage_pososd_sys_bitrate_pososd_sys_delay_pos"
     & "osd_sys_distance_pososd_sys_lq_pososd_sys_goggle_dvr_pososd_sys_vtx_dvr_pososd_sys_warnings_pososd_sys_vtx_"
     & "temp_pososd_sys_fan_speed_pososd_stat_bitmaskosd_profileosd_profile_1_nameosd_profile_2_nameosd_profile_3_n"
     & "ameosd_gps_sats_show_pdoposd_displayport_deviceosd_uartosd_rcchannelsosd_camera_frame_widthosd_camera_frame"
     & "_heightosd_stat_avg_cell_valueosd_framerate_hzosd_menu_backgroundosd_aux_channelosd_aux_scaleosd_aux_symbol"
     & "osd_craftname_msgsosd_lidar_dist_pososd_custom_serial_text_pososd_custom_serial_text_terminatorosd_custom_t"
     & "ext_uartosd_custom_text_baudosd_wp_number_pososd_wp_current_lat_pososd_wp_current_lon_pososd_wp_current_alt"
     & "_pososd_wp_distance_pososd_wp_direction_pososd_wp_next_number_pososd_wp_eta_pososd_nav_map_pososd_nav_map_m"
     & "odeosd_nav_map_centreosd_nav_map_min_scale_mosd_airspeedsystem_hse_mhztask_statisticsdebug_moderate_6pos_sw"
     & "itchcpu_overclockpwr_on_arm_graceenable_stick_armingvtx_bandvtx_channelvtx_powervtx_low_power_disarmvtx_sof"
     & "tserial_altvtx_typevtx_uartvtx_freqvtx_pit_mode_freqvtx_halfduplexvtx_spi_busvcd_video_systemvcd_h_offsetvc"
     & "d_v_offsetmax7456_clockmax7456_spi_busmax7456_preinit_opudisplayport_msp_col_adjustdisplayport_msp_row_adju"
     & "stdisplayport_msp_fontsdisplayport_msp_use_device_blinkdisplayport_max7456_col_adjustdisplayport_max7456_ro"
     & "w_adjustdisplayport_max7456_invdisplayport_max7456_blkdisplayport_max7456_whtesc_sensor_halfduplexesc_senso"
     & "r_current_offsetesc_sensor_uartfrsky_spi_autobindfrsky_spi_tx_idfrsky_spi_offsetfrsky_spi_bind_hop_datafrsk"
     & "y_x_rx_numfrsky_spi_a1_sourcecc2500_spi_chip_detectled_inversiondashboard_i2c_busdashboard_i2c_addrrangefin"
     & "der_hardwarerangefinder_uartopticalflow_hardwareopticalflow_uartopticalflow_rotationopticalflow_flip_xpinio"
     & "_configpinio_boxusb_hid_cdcusb_msc_pin_pullupflash_spi_busrcdevice_init_dev_attemptsrcdevice_init_dev_attem"
     & "pt_intervalrcdevice_protocol_versionrcdevice_featurercdevice_uartgyro_1_bustypegyro_1_spibusgyro_1_i2cBusgy"
     & "ro_1_i2c_addressi2c1_pullupi2c1_clockspeed_khzi2c2_pullupi2c2_clockspeed_khzi2c3_pullupi2c3_clockspeed_khzm"
     & "co2_on_pc9spektrum_spi_protocolspektrum_spi_mfg_idspektrum_spi_num_channelsexpresslrs_uidexpresslrs_domaine"
     & "xpresslrs_model_idscheduler_relax_rxscheduler_relax_osdscheduler_debug_taskcpu_late_limit_permilleserialmsp"
     & "_halfduplexmsp_1_uartmsp_1_baudmsp_2_uartmsp_2_baudmsp_3_uartmsp_3_baudtimezone_offset_minutesrpm_filter_ha"
     & "rmonicsrpm_filter_weightsrpm_filter_qrpm_filter_min_hzrpm_filter_fade_range_hzrpm_filter_lpf_hzflysky_spi_t"
     & "x_idflysky_spi_rf_channelsstats_min_armed_time_sstats_total_flightsstats_total_time_sstats_total_dist_mstat"
     & "s_save_move_limitstats_mah_usedcraft_namepilot_namealtitude_sourcealtitude_prefer_baroaltitude_lpfrangefind"
     & "er_max_range_cmaltitude_d_lpfap_landing_altitude_map_hover_throttleap_throttle_minap_throttle_maxap_altitud"
     & "e_pap_altitude_iap_altitude_dap_altitude_aap_altitude_fap_position_pap_position_iap_position_dap_position_a"
     & "ap_position_fap_position_cutoffap_stop_thresholdap_max_angleap_max_yaw_rateap_yaw_pap_velocity_drag_coeffap"
     & "_max_velocityap_waypoint_arrival_radiusap_waypoint_hold_radiusap_stick_deadbandap_throttle_deadbandap_yaw_m"
     & "odeap_min_forward_velocityap_nav_corner_speedap_nav_corner_delta_vap_nav_decelap_nav_accelap_nav_carrot_lea"
     & "d_timeap_nav_carrot_lead_maxap_nav_preturn_distap_velocity_buildup_max_pitchap_max_turn_rateap_hold_orbit_r"
     & "adiusap_hold_figure8_widthap_landing_descent_rateap_landing_detection_timeap_landing_spiral_enableap_landin"
     & "g_spiral_radiusap_landing_spiral_rateap_landing_velocity_thresholdap_landing_throttle_thresholdap_l1_enable"
     & "ap_l1_periodap_l1_min_lookaheadap_l1_max_lookaheadap_l1_max_cross_track_errorap_l1_turn_rateap_min_nav_alti"
     & "tude_map_rx_loss_policyap_max_distance_from_homeap_geofence_actionbox_user_1_namebox_user_2_namebox_user_3_"
     & "namebox_user_4_namegimbal_roll_rc_gaingimbal_pitch_rc_thr_gaingimbal_pitch_rc_low_gaingimbal_pitch_rc_high_"
     & "gaingimbal_yaw_rc_gaingimbal_roll_gaingimbal_roll_offsetgimbal_roll_limitgimbal_pitch_gaingimbal_pitch_offs"
     & "etgimbal_pitch_low_limitgimbal_pitch_high_limitgimbal_yaw_gaingimbal_yaw_offsetgimbal_yaw_limitgimbal_stabi"
     & "lisationgimbal_sensitivitygimbal_uart                                           ";

   type Name_Start is range 0 .. Names_Length;
   type Name_Length is range 1 .. Max_Name_Length;

   Name_Starts : constant array (Setting) of Name_Start :=
     (0, 17, 31, 50, 64, 83, 97, 115, 129, 147, 166, 188, 203, 223, 240, 258, 273, 284, 300, 316, 336, 356, 374,
      396, 408, 418, 432, 445, 460, 469, 483, 498, 511, 522, 536, 551, 565, 577, 592, 604, 619, 634, 650, 663,
      673, 686, 702, 719, 733, 739, 748, 757, 769, 790, 800, 811, 822, 847, 861, 873, 897, 930, 958, 986, 1009,
      1024, 1040, 1057, 1074, 1091, 1118, 1131, 1146, 1160, 1184, 1214, 1225, 1236, 1255, 1262, 1288, 1309,
      1324, 1334, 1354, 1364, 1387, 1415, 1444, 1464, 1484, 1499, 1520, 1539, 1564, 1584, 1604, 1624, 1645,
      1666, 1693, 1713, 1738, 1760, 1783, 1806, 1826, 1846, 1868, 1881, 1905, 1918, 1931, 1943, 1954, 1962,
      1972, 1983, 1994, 2003, 2016, 2035, 2051, 2069, 2083, 2102, 2113, 2136, 2150, 2164, 2178, 2199, 2216,
      2236, 2263, 2281, 2304, 2328, 2344, 2361, 2376, 2387, 2407, 2419, 2440, 2462, 2483, 2508, 2526, 2550,
      2565, 2578, 2591, 2615, 2630, 2645, 2664, 2687, 2706, 2721, 2746, 2772, 2782, 2794, 2809, 2820, 2832,
      2843, 2855, 2871, 2887, 2896, 2912, 2936, 2955, 2965, 2988, 3002, 3022, 3031, 3042, 3053, 3064, 3079,
      3094, 3110, 3120, 3140, 3152, 3165, 3181, 3199, 3213, 3229, 3246, 3270, 3286, 3293, 3301, 3310, 3320,
      3338, 3350, 3363, 3374, 3383, 3393, 3401, 3411, 3422, 3431, 3450, 3472, 3487, 3503, 3517, 3533, 3554,
      3564, 3574, 3585, 3602, 3617, 3634, 3655, 3673, 3685, 3698, 3713, 3726, 3749, 3771, 3789, 3811, 3832,
      3852, 3875, 3891, 3909, 3933, 3941, 3949, 3974, 3993, 4017, 4039, 4060, 4083, 4106, 4129, 4153, 4172,
      4207, 4223, 4245, 4267, 4295, 4325, 4333, 4345, 4365, 4384, 4401, 4418, 4441, 4472, 4501, 4518, 4544,
      4576, 4619, 4631, 4652, 4673, 4692, 4707, 4727, 4742, 4762, 4776, 4794, 4815, 4834, 4851, 4873, 4892,
      4905, 4914, 4930, 4946, 4970, 4980, 4991, 5011, 5030, 5045, 5059, 5073, 5084, 5100, 5118, 5130, 5142,
      5158, 5172, 5186, 5207, 5231, 5256, 5279, 5296, 5303, 5310, 5317, 5324, 5330, 5336, 5342, 5348, 5353,
      5358, 5363, 5368, 5380, 5397, 5427, 5438, 5453, 5475, 5495, 5516, 5537, 5553, 5570, 5588, 5608, 5629,
      5648, 5677, 5704, 5722, 5734, 5744, 5755, 5764, 5774, 5787, 5805, 5828, 5847, 5873, 5904, 5922, 5941,
      5954, 5976, 5997, 6022, 6047, 6064, 6090, 6115, 6140, 6156, 6171, 6186, 6201, 6222, 6237, 6257, 6285,
      6302, 6319, 6337, 6358, 6385, 6408, 6432, 6455, 6489, 6511, 6544, 6552, 6560, 6574, 6586, 6604, 6618,
      6638, 6654, 6670, 6694, 6706, 6720, 6740, 6756, 6772, 6792, 6808, 6824, 6844, 6860, 6876, 6892, 6909,
      6927, 6943, 6953, 6973, 6987, 6997, 7016, 7027, 7057, 7075, 7098, 7118, 7134, 7153, 7172, 7191, 7217,
      7243, 7266, 7289, 7313, 7337, 7361, 7385, 7408, 7434, 7461, 7485, 7512, 7543, 7570, 7600, 7630, 7656,
      7690, 7720, 7747, 7769, 7797, 7813, 7829, 7848, 7869, 7894, 7917, 7943, 7962, 7984, 8005, 8025, 8041,
      8063, 8074, 8083, 8099, 8113, 8135, 8153, 8167, 8180, 8193, 8211, 8229, 8246, 8267, 8286, 8300, 8314,
      8327, 8345, 8372, 8387, 8405, 8425, 8433, 8441, 8453, 8465, 8485, 8506, 8522, 8534, 8547, 8560, 8591,
      8606, 8626, 8641, 8657, 8676, 8694, 8709, 8719, 8734, 8751, 8767, 8785, 8803, 8821, 8838, 8853, 8868,
      8888, 8908, 8929, 8945, 8961, 8978, 8997, 9016, 9032, 9048, 9065, 9080, 9093, 9107, 9120, 9143, 9159,
      9183, 9198, 9213, 9234, 9250, 9266, 9291, 9309, 9331, 9345, 9360, 9375, 9395, 9416, 9440, 9458, 9475,
      9493, 9519, 9546, 9574, 9599, 9623, 9651, 9671, 9689, 9709, 9727, 9748, 9759, 9785, 9808, 9827, 9844,
      9864, 9878, 9900, 9919, 9939, 9959, 9980, 9996, 10007, 10025, 10043, 10061, 10083, 10105, 10113, 10127,
      10149, 10172, 10195, 10211, 10230, 10245, 10258, 10272, 10290, 10308, 10334, 10367, 10387, 10407, 10424,
      10446, 10468, 10490, 10509, 10529, 10551, 10565, 10580, 10596, 10614, 10637, 10649, 10663, 10678, 10688,
      10704, 10717, 10733, 10752, 10760, 10771, 10780, 10800, 10818, 10826, 10834, 10842, 10859, 10873, 10884,
      10900, 10912, 10924, 10937, 10952, 10971, 10997, 11023, 11044, 11076, 11106, 11136, 11159, 11182, 11205,
      11226, 11251, 11266, 11284, 11299, 11315, 11338, 11352, 11371, 11393, 11406, 11423, 11441, 11461, 11477,
      11497, 11513, 11533, 11551, 11563, 11572, 11583, 11601, 11614, 11640, 11674, 11699, 11715, 11728, 11742,
      11755, 11768, 11786, 11797, 11816, 11827, 11846, 11857, 11876, 11887, 11908, 11927, 11952, 11966, 11983,
      12002, 12020, 12039, 12059, 12082, 12102, 12112, 12122, 12132, 12142, 12152, 12162, 12185, 12205, 12223,
      12235, 12252, 12276, 12293, 12309, 12331, 12353, 12372, 12390, 12408, 12429, 12443, 12453, 12463, 12478,
      12498, 12510, 12534, 12548, 12569, 12586, 12601, 12616, 12629, 12642, 12655, 12668, 12681, 12694, 12707,
      12720, 12733, 12746, 12764, 12781, 12793, 12808, 12816, 12838, 12853, 12879, 12902, 12919, 12939, 12950,
      12973, 12992, 13013, 13025, 13037, 13060, 13082, 13101, 13130, 13146, 13166, 13187, 13210, 13235, 13259,
      13283, 13305, 13334, 13363, 13375, 13387, 13406, 13425, 13452, 13467, 13488, 13505, 13530, 13548, 13563,
      13578, 13593, 13608, 13627, 13651, 13675, 13700, 13718, 13734, 13752, 13769, 13786, 13805, 13827, 13850,
      13865, 13882, 13898, 13918, 13936);

   Name_Lengths : constant array (Setting) of Name_Length :=
     (17, 14, 19, 14, 19, 14, 18, 14, 18, 19, 22, 15, 20, 17, 18, 15, 11, 16, 16, 20, 20, 18, 22, 12, 10, 14,
      13, 15, 9, 14, 15, 13, 11, 14, 15, 14, 12, 15, 12, 15, 15, 16, 13, 10, 13, 16, 17, 14, 6, 9, 9, 12, 21,
      10, 11, 11, 25, 14, 12, 24, 33, 28, 28, 23, 15, 16, 17, 17, 17, 27, 13, 15, 14, 24, 30, 11, 11, 19, 7, 26,
      21, 15, 10, 20, 10, 23, 28, 29, 20, 20, 15, 21, 19, 25, 20, 20, 20, 21, 21, 27, 20, 25, 22, 23, 23, 20,
      20, 22, 13, 24, 13, 13, 12, 11, 8, 10, 11, 11, 9, 13, 19, 16, 18, 14, 19, 11, 23, 14, 14, 14, 21, 17, 20,
      27, 18, 23, 24, 16, 17, 15, 11, 20, 12, 21, 22, 21, 25, 18, 24, 15, 13, 13, 24, 15, 15, 19, 23, 19, 15,
      25, 26, 10, 12, 15, 11, 12, 11, 12, 16, 16, 9, 16, 24, 19, 10, 23, 14, 20, 9, 11, 11, 11, 15, 15, 16, 10,
      20, 12, 13, 16, 18, 14, 16, 17, 24, 16, 7, 8, 9, 10, 18, 12, 13, 11, 9, 10, 8, 10, 11, 9, 19, 22, 15, 16,
      14, 16, 21, 10, 10, 11, 17, 15, 17, 21, 18, 12, 13, 15, 13, 23, 22, 18, 22, 21, 20, 23, 16, 18, 24, 8, 8,
      25, 19, 24, 22, 21, 23, 23, 23, 24, 19, 35, 16, 22, 22, 28, 30, 8, 12, 20, 19, 17, 17, 23, 31, 29, 17, 26,
      32, 43, 12, 21, 21, 19, 15, 20, 15, 20, 14, 18, 21, 19, 17, 22, 19, 13, 9, 16, 16, 24, 10, 11, 20, 19, 15,
      14, 14, 11, 16, 18, 12, 12, 16, 14, 14, 21, 24, 25, 23, 17, 7, 7, 7, 7, 6, 6, 6, 6, 5, 5, 5, 5, 12, 17,
      30, 11, 15, 22, 20, 21, 21, 16, 17, 18, 20, 21, 19, 29, 27, 18, 12, 10, 11, 9, 10, 13, 18, 23, 19, 26, 31,
      18, 19, 13, 22, 21, 25, 25, 17, 26, 25, 25, 16, 15, 15, 15, 21, 15, 20, 28, 17, 17, 18, 21, 27, 23, 24,
      23, 34, 22, 33, 8, 8, 14, 12, 18, 14, 20, 16, 16, 24, 12, 14, 20, 16, 16, 20, 16, 16, 20, 16, 16, 16, 17,
      18, 16, 10, 20, 14, 10, 19, 11, 30, 18, 23, 20, 16, 19, 19, 19, 26, 26, 23, 23, 24, 24, 24, 24, 23, 26,
      27, 24, 27, 31, 27, 30, 30, 26, 34, 30, 27, 22, 28, 16, 16, 19, 21, 25, 23, 26, 19, 22, 21, 20, 16, 22,
      11, 9, 16, 14, 22, 18, 14, 13, 13, 18, 18, 17, 21, 19, 14, 14, 13, 18, 27, 15, 18, 20, 8, 8, 12, 12, 20,
      21, 16, 12, 13, 13, 31, 15, 20, 15, 16, 19, 18, 15, 10, 15, 17, 16, 18, 18, 18, 17, 15, 15, 20, 20, 21,
      16, 16, 17, 19, 19, 16, 16, 17, 15, 13, 14, 13, 23, 16, 24, 15, 15, 21, 16, 16, 25, 18, 22, 14, 15, 15,
      20, 21, 24, 18, 17, 18, 26, 27, 28, 25, 24, 28, 20, 18, 20, 18, 21, 11, 26, 23, 19, 17, 20, 14, 22, 19,
      20, 20, 21, 16, 11, 18, 18, 18, 22, 22, 8, 14, 22, 23, 23, 16, 19, 15, 13, 14, 18, 18, 26, 33, 20, 20, 17,
      22, 22, 22, 19, 20, 22, 14, 15, 16, 18, 23, 12, 14, 15, 10, 16, 13, 16, 19, 8, 11, 9, 20, 18, 8, 8, 8, 17,
      14, 11, 16, 12, 12, 13, 15, 19, 26, 26, 21, 32, 30, 30, 23, 23, 23, 21, 25, 15, 18, 15, 16, 23, 14, 19,
      22, 13, 17, 18, 20, 16, 20, 16, 20, 18, 12, 9, 11, 18, 13, 26, 34, 25, 16, 13, 14, 13, 13, 18, 11, 19, 11,
      19, 11, 19, 11, 21, 19, 25, 14, 17, 19, 18, 19, 20, 23, 20, 10, 10, 10, 10, 10, 10, 23, 20, 18, 12, 17,
      24, 17, 16, 22, 22, 19, 18, 18, 21, 14, 10, 10, 15, 20, 12, 24, 14, 21, 17, 15, 15, 13, 13, 13, 13, 13,
      13, 13, 13, 13, 13, 18, 17, 12, 15, 8, 22, 15, 26, 23, 17, 20, 11, 23, 19, 21, 12, 12, 23, 22, 19, 29, 16,
      20, 21, 23, 25, 24, 24, 22, 29, 29, 12, 12, 19, 19, 27, 15, 21, 17, 25, 18, 15, 15, 15, 15, 19, 24, 24,
      25, 18, 16, 18, 17, 17, 19, 22, 23, 15, 17, 16, 20, 18, 11);

   function Name (S : Setting) return String is
     (Names (Natural (Name_Starts (S)) + 1 .. Natural (Name_Starts (S)) + Natural (Name_Lengths (S))));

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

   --  The value names in one text, with each table's first value index;
   --  the index tables run past the last value by a longest table, so a
   --  table's first index plus an index under its count stays within them.
   Values_Length : constant := 3644;
   Value_Names : constant String (1 .. Values_Length + Max_Value_Length) :=
     "OFFONIMPERIALMETRICBRITISHDEFAULTCW0CW90CW180CW270CW0FLIPCW90FLIPCW180FLIPCW270FLIPCUSTOMNMEAUBLOXMSPVIRTUA"
     & "LAUTOEGNOSWAASMSASGAGANNONEPORTABLESTATIONARYPEDESTRIANAUTOMOTIVEAT_SEAAIRBORNE_1GAIRBORNE_2GAIRBORNE_4GAUT"
     & "OUSNOEUSUNTSCVELOCITYBEARINGHYBRIDFIXEDDAMPENERDISABLECONTINUELANDLANDRTHRESCUE_SANITY_OFFRESCUE_SANITY_ONR"
     & "ESCUE_SANITY_FS_ONLYMAX_ALTFIXED_ALTCURRENT_ALTNONESPIFLASHSDCARDSERIALNORMALMOTOR_TESTALWAYS1/11/21/41/81/"
     & "16NONEADCVIRTUALESCMSPNONEADCESCNORMALMIXTILTNONESPEK2048SBUSSUMDSUMHXB-BXB-B-RJ01IBUSJETIEXBUSCRSFSRXLCUST"
     & "OMFPORTSRXL2GHSTSPEK1024MAVLINKV202_250KV202_1MSYMA_XSYMA_X5CCX10CX10AH8_3DINAVFRSKY_DFRSKY_XFLYSKYFLYSKY_2"
     & "AKNSFHSSSPEKTRUMFRSKY_X_LBTREDPINEFRSKY_X_V2FRSKY_X_LBT_V2EXPRESSLRSNORMALOPTION_1OPTION_2EXPERIMENTALAUTON"
     & "ONEMPU6050MPU6000MPU6500MPU9250ICM20601ICM20602ICM20608GICM20649ICM20689ICM42605ICM42688PBMI160BMI270LSM6DS"
     & "OLSM6DSV16XIIM42653ICM45605ICM45686ICM40609DIIM42652LSM6DSK320XICM42622PICM42686PICM56686BMI423VIRTUALLSM6D"
     & "SV32XAUTONONEBMP085MS5611BMP280LPSQMP6988BMP388DPS3102SMPB_02BLPS22DFBMP580BMP581VIRTUALSPA06_003AUTONONEHM"
     & "C5883AK8975AK8963QMC5883LLIS2MDLLIS3MDLMPU925X_AK8963IST8310MMC560XQMC5883PBMM350AK9916NONECYCLETIMEBATTERY"
     & "GYRO_FILTEREDACCELEROMETERPIDLOOPRC_INTERPOLATIONANGLERATEESC_SENSORSCHEDULERSTACKESC_SENSOR_RPMESC_SENSOR_"
     & "TMPALTITUDEFFTFFT_TIMEFFT_FREQRX_FRSKY_SPIRX_SFHSS_SPIGYRO_RAWMULTI_GYRO_RAWMULTI_GYRO_DIFFMAX7456_SIGNALMA"
     & "X7456_SPICLOCKSBUSFPORTRANGEFINDERRANGEFINDER_QUALITYOPTICALFLOWLIDAR_TFADC_INTERNALRUNAWAY_TAKEOFFSDIOCURR"
     & "ENT_SENSORUSBSMARTAUDIORTHITERM_RELAXACRO_TRAINERRC_SMOOTHINGRX_SIGNAL_LOSSRC_SMOOTHING_RATEANTI_GRAVITYDYN"
     & "_LPFRX_SPEKTRUM_SPIDSHOT_RPM_TELEMETRYRPM_FILTERD_MAXAC_CORRECTIONAC_ERRORMULTI_GYRO_SCALEDDSHOT_RPM_ERRORS"
     & "CRSF_LINK_STATISTICS_UPLINKCRSF_LINK_STATISTICS_PWRCRSF_LINK_STATISTICS_DOWNBAROAUTOPILOT_ALTITUDEDYN_IDLEF"
     & "EEDFORWARD_LIMITFEEDFORWARDBLACKBOX_OUTPUTGYRO_SAMPLERX_TIMINGD_LPFVTX_TRAMPGHSTGHST_MSPSCHEDULER_DETERMINI"
     & "SMTIMING_ACCURACYRX_EXPRESSLRS_SPIRX_EXPRESSLRS_PHASELOCKRX_STATE_TIMEGPS_RESCUE_VELOCITYGPS_RESCUE_HEADING"
     & "GPS_RESCUE_TRACKINGGPS_CONNECTIONATTITUDEVTX_MSPGPS_DOPFAILSAFEGYRO_CALIBRATIONANGLE_MODEANGLE_TARGETCURREN"
     & "T_ANGLEDSHOT_TELEMETRY_COUNTSRPM_LIMITRC_STATSMAG_CALIBMAG_TASK_RATEEZLANDINGTPAS_TERMSPATASKGIMBALWING_SET"
     & "POINTCHIRPFLASH_TEST_PRBSMAVLINK_TELEMETRYAUTOPILOT_PIDPOSITION_NAVAUTOPILOT_STOPPITOTPOSITION_ESTAUTOPILOT"
     & "_HEADINGRX_REDPINE_SPILAUNCHVELOCITY_ESTSAG_COMPENSATIONUPT1FLIGHT_PLANPWMONESHOT125ONESHOT42MULTISHOTBRUSH"
     & "EDDSHOT150DSHOT300DSHOT600PROSHOT1000DISABLEDDRONECANOFFONFORCEPT1BIQUADPT2PT3PT1BIQUADPT2PT3AUTO-LANDDROPG"
     & "PS-RESCUESTAGE1KILLSTAGE2OFFONBEEPDISARMNONEI2CSPISLAVEHALFNOMINALDOUBLEVBATEXTADCCONSTNONEHCSR04TFMINITF02"
     & "MTF01MTF02MTF01PMTF02PTFNOVANOOPLOOP_F2NOOPLOOP_F2PNOOPLOOP_F2PHNOOPLOOP_FNOOPLOOP_FPNOOPLOOP_F2MINIUPT1NON"
     & "EMTUPT1AUTONONEMS4525AUTOGPS_ONLYOPTICALFLOW_ONLYOFFYAWALLBETAFLIGHTRACEFLIGHTKISSACTUALQUICKOFF192MHZ216MH"
     & "Z240MHZGRBRGBGRBWOFFSCALECLIPAUTOPALNTSCHDOFFRPRPYRP_INCRPY_INCGYROSETPOINTROLLPITCHROLLPITCHYAWTHROTTLEOFF"
     & "ONUNTIL_FIRST_ARMOFFSPISDIONORMALPITCHONLYFULLPDDOFFI_FREEZEIPIDPD_I_FREEZERACEBEACONSTATUSBLACKWHITEREDORA"
     & "NGEYELLOWLIME_GREENGREENMINT_GREENCYANLIGHT_BLUEBLUEDARK_VIOLETMAGENTADEEP_PINKROLLPITCHYAWDEFAULTBARO_ONLY"
     & "GPS_ONLYRANGEFINDER_PREFERRANGEFINDER_ONLYOFFONAUTOOFF2_POINT3_POINT4_POINTAUTOTIM1TIM8NONEAUTOMAX7456MSPFR"
     & "SKYOSDFBOSDNONERTC6705SMARTAUDIOTRAMPMSPOFFONFIRST_ARMINGNULLLFLEGACYLINEARDYNAMICEZLANDINGOFFRPRPYTRANSPAR"
     & "ENTBLACKGRAYLIGHT_GRAYAU433AU915EU433EU868IN866FCC915ISM2400CE2400NONEILAPARCITIMERERLTAUTO9600192003840057"
     & "6001152002304002500004000004608005000009216001000000150000020000002470000NONEFRSKY_HUBHOTTLTMSMARTPORTMAVLI"
     & "NKIBUS                           ";

   type Value_Index is range 0 .. 614;
   type Value_Start is range 0 .. Values_Length;
   type Value_Length is range 0 .. Max_Value_Length;
   subtype Table_First_Index is Value_Index range 0 .. 503;

   Table_Firsts : constant array (Lookup_Table) of Table_First_Index :=
     (0, 2, 5, 15, 19, 25, 33, 38, 43, 46, 48, 51, 54, 58, 61, 66, 71, 74, 76, 93, 113, 117, 146, 161, 176, 287,
      298, 301, 305, 309, 312, 315, 319, 323, 326, 329, 345, 348, 352, 355, 358, 363, 367, 370, 373, 377, 382,
      384, 386, 390, 393, 396, 399, 401, 406, 409, 423, 426, 431, 434, 438, 441, 447, 453, 456, 458, 462, 465,
      469, 477, 481, 497);

   Value_Starts : constant array (Value_Index) of Value_Start :=
     (0, 3, 5, 13, 19, 26, 33, 36, 40, 45, 50, 57, 65, 74, 83, 89, 93, 98, 101, 108, 112, 117, 121, 125, 130,
      134, 142, 152, 162, 172, 178, 189, 200, 211, 215, 219, 221, 223, 227, 235, 242, 248, 253, 261, 268, 276,
      280, 284, 287, 304, 320, 341, 348, 357, 368, 372, 380, 386, 392, 398, 408, 414, 417, 420, 423, 426, 430,
      434, 437, 444, 447, 450, 454, 457, 460, 466, 473, 477, 485, 489, 493, 497, 501, 510, 514, 523, 527, 531,
      537, 542, 547, 551, 559, 566, 575, 582, 588, 596, 600, 605, 610, 614, 621, 628, 634, 643, 645, 650, 658,
      669, 676, 686, 700, 710, 716, 724, 732, 744, 748, 752, 759, 766, 773, 780, 788, 796, 805, 813, 821, 829,
      838, 844, 850, 857, 867, 875, 883, 891, 900, 908, 919, 928, 937, 945, 951, 958, 968, 972, 976, 982, 988,
      994, 997, 1004, 1010, 1016, 1025, 1032, 1038, 1044, 1051, 1060, 1064, 1068, 1075, 1081, 1087, 1095, 1102,
      1109, 1123, 1130, 1137, 1145, 1145, 1151, 1157, 1161, 1170, 1177, 1190, 1203, 1210, 1226, 1235, 1245,
      1254, 1259, 1273, 1287, 1295, 1298, 1306, 1314, 1326, 1338, 1346, 1360, 1375, 1389, 1405, 1409, 1414,
      1425, 1444, 1455, 1463, 1475, 1490, 1494, 1508, 1511, 1521, 1524, 1535, 1547, 1559, 1573, 1590, 1602,
      1609, 1624, 1643, 1653, 1658, 1671, 1679, 1696, 1712, 1739, 1763, 1788, 1792, 1810, 1818, 1835, 1846,
      1861, 1872, 1881, 1886, 1895, 1899, 1907, 1928, 1943, 1960, 1983, 1996, 2015, 2033, 2052, 2066, 2074,
      2081, 2088, 2096, 2112, 2122, 2134, 2147, 2169, 2178, 2186, 2195, 2208, 2217, 2220, 2226, 2229, 2233,
      2239, 2252, 2257, 2272, 2289, 2302, 2314, 2328, 2333, 2345, 2362, 2376, 2382, 2394, 2410, 2414, 2425,
      2428, 2438, 2447, 2456, 2463, 2471, 2479, 2487, 2498, 2506, 2514, 2517, 2519, 2524, 2527, 2533, 2536,
      2539, 2542, 2548, 2551, 2554, 2563, 2567, 2577, 2583, 2587, 2593, 2596, 2598, 2602, 2608, 2612, 2615,
      2618, 2623, 2627, 2634, 2640, 2644, 2650, 2655, 2659, 2665, 2671, 2675, 2680, 2685, 2691, 2697, 2703,
      2714, 2726, 2739, 2749, 2760, 2775, 2779, 2783, 2785, 2789, 2793, 2797, 2803, 2803, 2807, 2815, 2831,
      2834, 2837, 2840, 2850, 2860, 2864, 2870, 2875, 2878, 2884, 2890, 2896, 2899, 2902, 2906, 2909, 2914,
      2918, 2922, 2925, 2929, 2931, 2934, 2936, 2939, 2945, 2952, 2956, 2964, 2968, 2973, 2977, 2982, 2985,
      2993, 2996, 2998, 3013, 3016, 3019, 3023, 3029, 3038, 3042, 3044, 3045, 3048, 3056, 3057, 3060, 3071,
      3075, 3081, 3087, 3092, 3097, 3100, 3106, 3112, 3122, 3127, 3137, 3141, 3151, 3155, 3166, 3173, 3182,
      3186, 3191, 3194, 3201, 3210, 3218, 3236, 3252, 3255, 3257, 3261, 3264, 3271, 3278, 3285, 3289, 3293,
      3297, 3301, 3305, 3312, 3315, 3323, 3328, 3332, 3339, 3339, 3349, 3354, 3357, 3360, 3362, 3374, 3378,
      3380, 3386, 3392, 3399, 3408, 3411, 3413, 3416, 3427, 3432, 3436, 3446, 3451, 3456, 3461, 3466, 3471,
      3477, 3484, 3490, 3494, 3498, 3507, 3511, 3515, 3519, 3524, 3529, 3534, 3540, 3546, 3552, 3558, 3564,
      3570, 3576, 3583, 3590, 3597, 3604, 3608, 3617, 3621, 3624, 3633, 3640, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

   Value_Lengths : constant array (Value_Index) of Value_Length :=
     (3, 2, 8, 6, 7, 7, 3, 4, 5, 5, 7, 8, 9, 9, 6, 4, 5, 3, 7, 4, 5, 4, 4, 5, 4, 8, 10, 10, 10, 6, 11, 11, 11,
      4, 4, 2, 2, 4, 8, 7, 6, 5, 8, 7, 8, 4, 4, 3, 17, 16, 21, 7, 9, 11, 4, 8, 6, 6, 6, 10, 6, 3, 3, 3, 3, 4, 4,
      3, 7, 3, 3, 4, 3, 3, 6, 7, 4, 8, 4, 4, 4, 4, 9, 4, 9, 4, 4, 6, 5, 5, 4, 8, 7, 9, 7, 6, 8, 4, 5, 5, 4, 7,
      7, 6, 9, 2, 5, 8, 11, 7, 10, 14, 10, 6, 8, 8, 12, 4, 4, 7, 7, 7, 7, 8, 8, 9, 8, 8, 8, 9, 6, 6, 7, 10, 8,
      8, 8, 9, 8, 11, 9, 9, 8, 6, 7, 10, 4, 4, 6, 6, 6, 3, 7, 6, 6, 9, 7, 6, 6, 7, 9, 4, 4, 7, 6, 6, 8, 7, 7,
      14, 7, 7, 8, 0, 6, 6, 4, 9, 7, 13, 13, 7, 16, 9, 10, 9, 5, 14, 14, 8, 3, 8, 8, 12, 12, 8, 14, 15, 14, 16,
      4, 5, 11, 19, 11, 8, 12, 15, 4, 14, 3, 10, 3, 11, 12, 12, 14, 17, 12, 7, 15, 19, 10, 5, 13, 8, 17, 16, 27,
      24, 25, 4, 18, 8, 17, 11, 15, 11, 9, 5, 9, 4, 8, 21, 15, 17, 23, 13, 19, 18, 19, 14, 8, 7, 7, 8, 16, 10,
      12, 13, 22, 9, 8, 9, 13, 9, 3, 6, 3, 4, 6, 13, 5, 15, 17, 13, 12, 14, 5, 12, 17, 14, 6, 12, 16, 4, 11, 3,
      10, 9, 9, 7, 8, 8, 8, 11, 8, 8, 3, 2, 5, 3, 6, 3, 3, 3, 6, 3, 3, 9, 4, 10, 6, 4, 6, 3, 2, 4, 6, 4, 3, 3,
      5, 4, 7, 6, 4, 6, 5, 4, 6, 6, 4, 5, 5, 6, 6, 6, 11, 12, 13, 10, 11, 15, 4, 4, 2, 4, 4, 4, 6, 0, 4, 8, 16,
      3, 3, 3, 10, 10, 4, 6, 5, 3, 6, 6, 6, 3, 3, 4, 3, 5, 4, 4, 3, 4, 2, 3, 2, 3, 6, 7, 4, 8, 4, 5, 4, 5, 3, 8,
      3, 2, 15, 3, 3, 4, 6, 9, 4, 2, 1, 3, 8, 1, 3, 11, 4, 6, 6, 5, 5, 3, 6, 6, 10, 5, 10, 4, 10, 4, 11, 7, 9,
      4, 5, 3, 7, 9, 8, 18, 16, 3, 2, 4, 3, 7, 7, 7, 4, 4, 4, 4, 4, 7, 3, 8, 5, 4, 7, 0, 10, 5, 3, 3, 2, 12, 4,
      2, 6, 6, 7, 9, 3, 2, 3, 11, 5, 4, 10, 5, 5, 5, 5, 5, 6, 7, 6, 4, 4, 9, 4, 4, 4, 5, 5, 5, 6, 6, 6, 6, 6, 6,
      6, 7, 7, 7, 7, 4, 9, 4, 3, 9, 7, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

   function Value_Name (T : Lookup_Table; Index : Natural) return String is
     (Value_Names
        (Natural (Value_Starts (Table_Firsts (T) + Value_Index (Index))) + 1
         .. Natural (Value_Starts (Table_Firsts (T) + Value_Index (Index)))
            + Natural (Value_Lengths (Table_Firsts (T) + Value_Index (Index)))));

end Adaflight.Settings_Table;
