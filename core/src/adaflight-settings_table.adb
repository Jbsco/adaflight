package body Adaflight.Settings_Table with SPARK_Mode is

   --  Each setting's limits and group as indexes into the tables of the distinct ones, so the info
   --  of every setting packs into a few bytes of flash.
   type Limit_Pair is record
      Min : Limit;
      Max : Limit;
   end record with Pack;

   type Limit_Index is range 0 .. 154;
   type Group_Index is range 0 .. 80;

   Limit_Pairs : constant array (Limit_Index) of Limit_Pair :=
     ((Min => -1800000000, Max => 1800000000), (Min => -900000000, Max => 900000000), (Min => -32000, Max => 32000),
      (Min => -18000, Max => 18000), (Min => -16000, Max => 16000), (Min => -9000, Max => 9000),
      (Min => -3600, Max => 3600), (Min => -1000, Max => 1000), (Min => -780, Max => 780), (Min => -500, Max => 500),
      (Min => -300, Max => 300), (Min => -180, Max => 360), (Min => -130, Max => 0), (Min => -127, Max => 127),
      (Min => -100, Max => 100), (Min => -32, Max => 31), (Min => -30, Max => 20), (Min => -16, Max => 15),
      (Min => -15, Max => 16), (Min => -6, Max => 0), (Min => -3, Max => 0), (Min => -1, Max => 8),
      (Min => -1, Max => 127), (Min => -1, Max => 32767), (Min => 0, Max => 0), (Min => 0, Max => 1),
      (Min => 0, Max => 3), (Min => 0, Max => 5), (Min => 0, Max => 7), (Min => 0, Max => 8), (Min => 0, Max => 10),
      (Min => 0, Max => 12), (Min => 0, Max => 14), (Min => 0, Max => 15), (Min => 0, Max => 18),
      (Min => 0, Max => 20), (Min => 0, Max => 24), (Min => 0, Max => 30), (Min => 0, Max => 32),
      (Min => 0, Max => 40), (Min => 0, Max => 50), (Min => 0, Max => 60), (Min => 0, Max => 70),
      (Min => 0, Max => 75), (Min => 0, Max => 80), (Min => 0, Max => 90), (Min => 0, Max => 95),
      (Min => 0, Max => 100), (Min => 0, Max => 119), (Min => 0, Max => 120), (Min => 0, Max => 150),
      (Min => 0, Max => 180), (Min => 0, Max => 200), (Min => 0, Max => 250), (Min => 0, Max => 255),
      (Min => 0, Max => 300), (Min => 0, Max => 359), (Min => 0, Max => 400), (Min => 0, Max => 500),
      (Min => 0, Max => 1000), (Min => 0, Max => 1700), (Min => 0, Max => 2000), (Min => 0, Max => 3000),
      (Min => 0, Max => 5000), (Min => 0, Max => 5999), (Min => 0, Max => 10000), (Min => 0, Max => 16000),
      (Min => 0, Max => 20000), (Min => 0, Max => 30000), (Min => 0, Max => 32000), (Min => 0, Max => 32767),
      (Min => 0, Max => 65535), (Min => 0, Max => 262143), (Min => 0, Max => 4294967295), (Min => 1, Max => 3),
      (Min => 1, Max => 4), (Min => 1, Max => 5), (Min => 1, Max => 9), (Min => 1, Max => 16), (Min => 1, Max => 18),
      (Min => 1, Max => 20), (Min => 1, Max => 45), (Min => 1, Max => 50), (Min => 1, Max => 60),
      (Min => 1, Max => 90), (Min => 1, Max => 100), (Min => 1, Max => 200), (Min => 1, Max => 250),
      (Min => 1, Max => 255), (Min => 1, Max => 900), (Min => 1, Max => 1000), (Min => 1, Max => 2000),
      (Min => 1, Max => 10000), (Min => 1, Max => 40000), (Min => 1, Max => 65535), (Min => 2, Max => 16),
      (Min => 2, Max => 30), (Min => 2, Max => 40), (Min => 2, Max => 50), (Min => 4, Max => 18),
      (Min => 4, Max => 255), (Min => 5, Max => 30), (Min => 5, Max => 50), (Min => 5, Max => 100),
      (Min => 5, Max => 500), (Min => 5, Max => 1000), (Min => 8, Max => 119), (Min => 10, Max => 50),
      (Min => 10, Max => 70), (Min => 10, Max => 80), (Min => 10, Max => 200), (Min => 10, Max => 250),
      (Min => 10, Max => 255), (Min => 10, Max => 500), (Min => 10, Max => 2000), (Min => 10, Max => 5000),
      (Min => 20, Max => 100), (Min => 20, Max => 250), (Min => 20, Max => 1000), (Min => 20, Max => 5000),
      (Min => 25, Max => 100), (Min => 25, Max => 255), (Min => 25, Max => 500), (Min => 30, Max => 200),
      (Min => 48, Max => 126), (Min => 50, Max => 255), (Min => 50, Max => 498), (Min => 50, Max => 1000),
      (Min => 50, Max => 2000), (Min => 50, Max => 2500), (Min => 50, Max => 3000), (Min => 50, Max => 10000),
      (Min => 100, Max => 500), (Min => 100, Max => 1000), (Min => 100, Max => 1300), (Min => 100, Max => 2000),
      (Min => 100, Max => 4000), (Min => 100, Max => 5000), (Min => 200, Max => 1000), (Min => 200, Max => 1998),
      (Min => 200, Max => 32000), (Min => 250, Max => 3000), (Min => 300, Max => 5000), (Min => 500, Max => 1950),
      (Min => 500, Max => 5000), (Min => 500, Max => 10000), (Min => 600, Max => 6000), (Min => 750, Max => 1500),
      (Min => 750, Max => 2250), (Min => 1000, Max => 2000), (Min => 1000, Max => 50000), (Min => 1050, Max => 1400),
      (Min => 1200, Max => 1700), (Min => 1400, Max => 2000), (Min => 1500, Max => 2250));

   Group_Numbers : constant array (Group_Index) of Group_Number :=
     (1, 2, 3, 5, 6, 10, 11, 12, 13, 14, 16, 17, 18, 20, 22, 24, 25, 26, 27, 30, 31, 35, 38, 39, 40, 47, 52, 55, 56,
      57, 58, 59, 60, 61, 256, 257, 258, 259, 501, 502, 503, 504, 505, 506, 508, 510, 511, 512, 513, 514, 515, 517,
      518, 519, 523, 524, 525, 526, 527, 529, 530, 531, 537, 539, 540, 541, 542, 544, 547, 553, 554, 555, 556, 557,
      559, 560, 561, 568, 569, 2044, 2045);

   type Packed_Info is record
      Kind       : Value_Type;
      Where      : Value_Scope;
      How        : Value_Mode;
      Limits     : Limit_Index;
      Table      : Lookup_Table;
      Count      : Count_Value;
      Min_Length : Count_Value;
      Write_Once : Boolean;
      Group      : Group_Index;
   end record with Pack;

   Infos : constant array (Setting) of Packed_Info :=
     (Gyro_Hardware_Lpf =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gyro_Hardware_Lpf, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Gyro_Lpf1_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gyro_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Gyro_Lpf1_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Lpf2_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gyro_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Gyro_Lpf2_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Notch1_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Notch1_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Notch2_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Notch2_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Calib_Duration =>
        (Kind => U16, Where => Master, How => Direct, Limits => 130, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Calib_Noise_Limit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5),
      Gyro_Offset_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Limits => 7, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5),
      Gyro_Overflow_Detect =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gyro_Overflow_Check, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Yaw_Spin_Recovery =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On_Auto, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 5),
      Yaw_Spin_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Limits => 143, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Dyn_Notch_Count =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 70),
      Dyn_Notch_Q =>
        (Kind => U16, Where => Master, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 70),
      Dyn_Notch_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 117, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 70),
      Dyn_Notch_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 138, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 70),
      Gyro_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Gyro_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => Master, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5),
      Gyro_Filter_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gyro_Filter_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5),
      Acc_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Acc_Hardware, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 21),
      Acc_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 21),
      Acc_Trim_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Limits => 10, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 21),
      Acc_Trim_Roll =>
        (Kind => I16, Where => Master, How => Direct, Limits => 10, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 21),
      Acc_Calibration =>
        (Kind => I16, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 21),
      Align_Mag =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Alignment, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Mag_Align_Roll =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 6, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24),
      Mag_Align_Pitch =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 6, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24),
      Mag_Align_Yaw =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 6, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24),
      Mag_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Mag_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24),
      Mag_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 48, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24),
      Mag_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24),
      Mag_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Mag_Hardware, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24),
      Mag_Calibration =>
        (Kind => I16, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 24),
      Baro_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 22),
      Baro_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 22),
      Baro_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 22),
      Baro_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 48, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 22),
      Baro_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baro_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 22),
      Baro_Drift =>
        (Kind => I16, Where => Master, How => Direct, Limits => 9, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 22),
      Pitot_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 78),
      Pitot_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 78),
      Pitot_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 48, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 78),
      Pitot_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Pitot_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 78),
      Mid_Rc =>
        (Kind => U16, Where => Master, How => Direct, Limits => 152, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Min_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Max_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Rssi_Channel =>
        (Kind => I8, Where => Master, How => Direct, Limits => 34, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rssi_Src_Frame_Errors =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rssi_Scale =>
        (Kind => U8, Where => Master, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rssi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rssi_Invert =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rssi_Src_Frame_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rssi_Smoothing =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rc_Smoothing =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rc_Smoothing_Auto_Factor =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rc_Smoothing_Auto_Factor_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rc_Smoothing_Setpoint_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rc_Smoothing_Throttle_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rc_Smoothing_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Rc_Smoothing_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 15),
      Fpv_Mix_Degrees =>
        (Kind => U8, Where => Master, How => Direct, Limits => 45, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Max_Aux_Channels =>
        (Kind => U8, Where => Master, How => Direct, Limits => 32, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Serialrx_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Serial_Rx, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Serialrx_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Spektrum_Sat_Bind =>
        (Kind => U8, Where => Master, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Spektrum_Sat_Bind_Autoreset =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Srxl2_Unit_Id =>
        (Kind => U8, Where => Master, How => Direct, Limits => 33, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Srxl2_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Sbus_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Crsf_Use_Negotiated_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Airmode_Start_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rx_Min_Usec =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Rx_Max_Usec =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Serialrx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15),
      Rx_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 15),
      Msp_Override_Channels_Mask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Msp_Override_Failsafe =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Rx_Spi_Protocol =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Rx_Spi, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 62),
      Rx_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 62),
      Rx_Spi_Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 62),
      Adc_Device =>
        (Kind => I8, Where => Hardware, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45),
      Adc_Vrefint_Calibration =>
        (Kind => U16, Where => Master, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45),
      Adc_Tempsensor_Calibration30 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45),
      Adc_Tempsensor_Calibration110 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45),
      Input_Filtering_Mode =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 44),
      Blackbox_Sample_Rate =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Blackbox_Sample_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 3),
      Blackbox_Device =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Blackbox_Device, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 3),
      Blackbox_Disable_Pids =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Rc =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 1, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Setpoint =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 2, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Bat =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 3, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Mag =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Alt =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 5, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Rssi =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 6, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Gyro =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 7, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Gyrounfilt =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 14, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Acc =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 9, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Attitude =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 8, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Debug =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 10, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Motors =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 11, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Servos =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 15, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Rpm =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 13, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Gps =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 12, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Disable_Pitot =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         0, Write_Once => False, Group => 3),
      Blackbox_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Blackbox_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 3),
      Blackbox_High_Resolution =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 3),
      Blackbox_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 3),
      Blackbox_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 3),
      Max_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Min_Command =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Motor_Kv =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Motor_Idle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Dshot_Burst =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On_Auto, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4),
      Dshot_Bidir =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 4),
      Dshot_Edt =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Dshot_Edt, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Dshot_Bitbang =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On_Auto, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4),
      Dshot_Bitbang_Timer =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Dshot_Bitbanged_Timer, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4),
      Use_Unsynced_Pwm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 4),
      Motor_Pwm_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Motor_Pwm_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4),
      Motor_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 140, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Motor_Pwm_Inversion =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 4),
      Motor_Poles =>
        (Kind => U8, Where => Master, How => Direct, Limits => 100, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Motor_Output_Reordering =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 8, Min_Length => 0,
         Write_Once => False, Group => 4),
      Thr_Corr_Value =>
        (Kind => U8, Where => Master, How => Direct, Limits => 50, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 23),
      Thr_Corr_Angle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 89, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 23),
      Failsafe_Delay =>
        (Kind => U8, Where => Master, How => Direct, Limits => 86, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 0),
      Failsafe_Landing_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 0),
      Failsafe_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0),
      Failsafe_Switch_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Failsafe_Switch_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 0),
      Failsafe_Throttle_Low_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 55, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0),
      Failsafe_Procedure =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Failsafe, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0),
      Failsafe_Recovery_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 86, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0),
      Failsafe_Stick_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 0),
      Align_Board_Roll =>
        (Kind => I16, Where => Master, How => Direct, Limits => 11, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 1),
      Align_Board_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Limits => 11, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 1),
      Align_Board_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Limits => 11, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 1),
      Gimbal_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gimbal_Mode, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 2),
      Battery_Profile_Name =>
        (Kind => U8, Where => Battery_Profile, How => Text, Limits => 24, Table => Table_Off_On, Count => 8,
         Min_Length => 1, Write_Once => False, Group => 76),
      Bat_Capacity =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Vbat_Max_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Vbat_Full_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Vbat_Min_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Vbat_Warning_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Cbat_Alert_Percent =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Force_Battery_Cell_Count =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 36, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Vbat_Hysteresis =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Current_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Current_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Battery_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Voltage_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6),
      Vbat_Detect_Cell_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 6),
      Use_Vbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Use_Cbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Vbat_Cutoff_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Vbat_Display_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Vbat_Sag_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Ibat_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Vbat_Duration_For_Warning =>
        (Kind => U8, Where => Master, How => Direct, Limits => 50, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Vbat_Duration_For_Critical =>
        (Kind => U8, Where => Master, How => Direct, Limits => 50, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Vbat_Scale =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 36),
      Vbat_Divider =>
        (Kind => U8, Where => Master, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 36),
      Vbat_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 36),
      Ibata_Scale =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 4, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 34),
      Ibata_Offset =>
        (Kind => I16, Where => Master, How => Direct, Limits => 2, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 34),
      Ibatv_Scale =>
        (Kind => I16, Where => Master, How => Direct, Limits => 4, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 35),
      Ibatv_Offset =>
        (Kind => U16, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 35),
      Battery_Continue =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6),
      Beeper_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 40),
      Beeper_Od =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 40),
      Beeper_Frequency =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 40),
      Beeper_Dshot_Beacon_Tone =>
        (Kind => U8, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 39),
      Yaw_Motors_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13),
      Mixer_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Mixer_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 13),
      Crashflip_Motor_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13),
      Crashflip_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13),
      Crashflip_Auto_Rearm =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13),
      Rpm_Limit =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13),
      Rpm_Limit_P =>
        (Kind => U16, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13),
      Rpm_Limit_I =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13),
      Rpm_Limit_D =>
        (Kind => U16, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13),
      Rpm_Limit_Value =>
        (Kind => U16, Where => Master, How => Direct, Limits => 94, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13),
      Three_D_Deadband_Low =>
        (Kind => U16, Where => Master, How => Direct, Limits => 147, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Deadband_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 154, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Neutral =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Deadband_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Limit_Low =>
        (Kind => U16, Where => Master, How => Direct, Limits => 147, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Limit_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 154, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Switched_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 17),
      Servo_Center_Pulse =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26),
      Servo_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 126, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26),
      Servo_Lowpass_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26),
      Tri_Unarmed_Servo =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 26),
      Channel_Forwarding_Start =>
        (Kind => U8, Where => Master, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 26),
      Rateprofile_Name =>
        (Kind => U8, Where => Rate_Profile, How => Text, Limits => 24, Table => Table_Off_On, Count => 8, Min_Length
         => 1, Write_Once => False, Group => 7),
      Thr_Mid =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Thr_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Thr_Hover =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Rates_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 24, Table => Table_Rates_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Quickrates_Rc_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Roll_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Pitch_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Yaw_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Roll_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Pitch_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Yaw_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Roll_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Pitch_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Yaw_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7),
      Throttle_Limit_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 24, Table => Table_Throttle_Limit_Type, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 7),
      Throttle_Limit_Percent =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 120, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Roll_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Pitch_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Yaw_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Reboot_Character =>
        (Kind => U8, Where => Master, How => Direct, Limits => 124, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 8),
      Serial_Update_Rate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 8),
      Imu_Dcm_Kp =>
        (Kind => U16, Where => Master, How => Direct, Limits => 69, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14),
      Imu_Dcm_Ki =>
        (Kind => U16, Where => Master, How => Direct, Limits => 69, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14),
      Small_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 14),
      Imu_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 14),
      Mag_Declination =>
        (Kind => I16, Where => Master, How => Direct, Limits => 10, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14),
      Auto_Disarm_Delay =>
        (Kind => U8, Where => Master, How => Direct, Limits => 41, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 10),
      Gyro_Cal_On_First_Arm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 10),
      Prearm_Allow_Rearm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 10),
      Gps_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gps_Provider, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 19),
      Gps_Sbas_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gps_Sbas_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19),
      Gps_Auto_Config =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Auto_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Ublox_Acquire_Model =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gps_Ublox_Models, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19),
      Gps_Ublox_Flight_Model =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gps_Ublox_Models, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19),
      Gps_Update_Rate_Hz =>
        (Kind => U8, Where => Master, How => Direct, Limits => 80, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Ublox_Utc_Standard =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gps_Ublox_Utc_Standard, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19),
      Gps_Ublox_Use_Galileo =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Ublox_Enable_Ana =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Set_Home_Point_Once =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Use_3d_Speed =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Sbas_Integrity =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19),
      Gps_Nmea_Custom_Commands =>
        (Kind => U8, Where => Master, How => Text, Limits => 24, Table => Table_Off_On, Count => 64, Min_Length => 1,
         Write_Once => False, Group => 19),
      Gps_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 19),
      Gps_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 19),
      Gps_Rescue_Min_Start_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 101, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Alt_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gps_Rescue_Alt_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Gps_Rescue_Initial_Climb =>
        (Kind => U16, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Ascend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 129, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Return_Alt =>
        (Kind => U16, Where => Master, How => Direct, Limits => 105, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Ground_Speed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Descent_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 104, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Descend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 122, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Sanity_Checks =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Gps_Rescue_Sanity_Check, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27),
      Gps_Rescue_Min_Sats =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27),
      Gps_Rescue_Allow_Arming_Without_Fix =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 27),
      Gps_Rescue_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 27),
      Gps_Lap_Timer_Gate_Lat =>
        (Kind => I32, Where => Master, How => Direct, Limits => 1, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30),
      Gps_Lap_Timer_Gate_Lon =>
        (Kind => I32, Where => Master, How => Direct, Limits => 0, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30),
      Gps_Lap_Timer_Min_Lap_Time_S =>
        (Kind => U16, Where => Master, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 30),
      Gps_Lap_Timer_Gate_Tolerance_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30),
      Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 38, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16),
      Yaw_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16),
      Yaw_Control_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16),
      Alt_Hold_Climb_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 31),
      Alt_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 42, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 31),
      Pos_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 33),
      Poshold_Position_Source =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Poshold_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 33),
      Poshold_Opticalflow_Quality_Min =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 33),
      Poshold_Opticalflow_Max_Range =>
        (Kind => U16, Where => Master, How => Direct, Limits => 127, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 33),
      Pid_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41),
      Runaway_Takeoff_Prevention =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41),
      Runaway_Takeoff_Deactivate_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 41),
      Runaway_Takeoff_Deactivate_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41),
      Profile_Name =>
        (Kind => U8, Where => PID_Profile, How => Text, Limits => 24, Table => Table_Off_On, Count => 8, Min_Length =>
         1, Write_Once => False, Group => 9),
      Dterm_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dterm_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dterm_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dterm_Lpf1_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Dterm_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Dterm_Lpf1_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dterm_Lpf2_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Dterm_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Dterm_Lpf2_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dterm_Notch_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dterm_Notch_Cutoff =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Vbat_Sag_Compensation =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 50, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Pid_At_Min_Throttle =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Anti_Gravity_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Anti_Gravity_Cutoff_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 98, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Anti_Gravity_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Acc_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Acc_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Crash_Dthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 114, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Gthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Setpoint_Threshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Time =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 137, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Crash_Recovery_Angle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 101, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Crash_Recovery_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Crash_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Crash_Recovery =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Crash_Recovery, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Iterm_Rotation =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Iterm_Relax =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Iterm_Relax, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Iterm_Relax_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Iterm_Relax_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Iterm_Relax_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 82, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Iterm_Windup =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Pidsum_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Pidsum_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Yaw_Lowpass_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Throttle_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Throttle_Boost_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Acro_Trainer_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 109, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Acro_Trainer_Lookahead_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Acro_Trainer_Debug_Axis =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Acro_Trainer_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Acro_Trainer_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 121, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      P_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      I_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      F_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      P_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      I_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      F_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      P_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      I_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      F_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Angle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Angle_Feedforward =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Angle_Feedforward_Smoothing_Ms =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 111, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 109, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Angle_Earth_Ref =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Horizon_Level_Strength =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Horizon_Limit_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Horizon_Limit_Degrees =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 111, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Horizon_Ignore_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Horizon_Delay_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Chirp_Lag_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Lead_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Amplitude_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Amplitude_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Amplitude_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Frequency_Start_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Frequency_End_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 92, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Time_Seconds =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Chirp_Repeat =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 77, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Max_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Max_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Max_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      D_Max_Advance =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Motor_Output_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Auto_Profile_Cell_Count =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 21, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Launch_Control_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Launch_Control_Mode, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 9),
      Launch_Trigger_Allow_Reset =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Launch_Trigger_Throttle_Percent =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 45, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Launch_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Launch_Control_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Thrust_Linear =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 50, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Feedforward_Transition =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Feedforward_Averaging =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Feedforward_Averaging, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 9),
      Feedforward_Smooth_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 46, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Feedforward_Jitter_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 35, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Feedforward_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Feedforward_Max_Rate_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Feedforward_Yaw_Hold_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Feedforward_Yaw_Hold_Time =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 111, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dyn_Idle_Min_Rpm =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dyn_Idle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dyn_Idle_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dyn_Idle_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Dyn_Idle_Max_Increase =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 112, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Level_Race_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Pids_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Simplified_Tuning_Pids_Mode,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 9),
      Simplified_Master_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Feedforward_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Pitch_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Pitch_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Dterm_Filter =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Dterm_Filter_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Simplified_Gyro_Filter =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5),
      Simplified_Gyro_Filter_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Tpa_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Tpa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Tpa_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Tpa_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Tpa_Low_Rate =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Tpa_Low_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Tpa_Low_Always =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Ez_Landing_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Ez_Landing_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 43, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Ez_Landing_Speed =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Landing_Disarm_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Tlm_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Tlm_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Telemetry_1_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Telemetry_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Telemetry_1_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20),
      Telemetry_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_2_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Telemetry_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Telemetry_2_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20),
      Telemetry_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_3_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Telemetry_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20),
      Telemetry_3_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20),
      Telemetry_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20),
      Crsf_Tlm_Accgyro =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Frsky_Default_Lat =>
        (Kind => I16, Where => Master, How => Direct, Limits => 5, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Frsky_Default_Long =>
        (Kind => I16, Where => Master, How => Direct, Limits => 3, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Frsky_Gps_Format =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Frsky_Unit =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Unit, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Frsky_Vfas_Precision =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Hott_Alarm_Int =>
        (Kind => U8, Where => Master, How => Direct, Limits => 49, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Pid_In_Tlm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Report_Cell_Voltage =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Ibus_Sensor =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 15, Min_Length => 0,
         Write_Once => False, Group => 20),
      Mavlink_Mah_As_Heading_Divisor =>
        (Kind => U16, Where => Master, How => Direct, Limits => 68, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20),
      Mavlink_Min_Txbuff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Mavlink_Ext_Status_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Mavlink_Rc_Chan_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Mavlink_Pos_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Mavlink_Extra1_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Mavlink_Extra2_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Mavlink_Extra3_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20),
      Telemetry_Disabled_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Current =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 1, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Fuel =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 2, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Mode =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 3, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Acc_X =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Acc_Y =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 5, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Acc_Z =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 6, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Pitch =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 7, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Roll =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 8, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Heading =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 9, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Altitude =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 10, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Vario =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 11, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Lat_Long =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 12, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Ground_Speed =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 13, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Distance =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 14, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Esc_Current =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 15, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Esc_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Esc_Rpm =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 17, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Esc_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 18, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 19, Min_Length =>
         0, Write_Once => False, Group => 20),
      Telemetry_Disabled_Cap_Used =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 24, Table => Table_Off_On, Count => 20, Min_Length =>
         0, Write_Once => False, Group => 20),
      Ledstrip_Visual_Beeper =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18),
      Ledstrip_Visual_Beeper_Color =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18),
      Ledstrip_Grb_Rgb =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Rgb_Grb, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18),
      Ledstrip_Profile =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Led_Profile, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 18),
      Ledstrip_Race_Color =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18),
      Ledstrip_Beacon_Color =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18),
      Ledstrip_Beacon_Period_Ms =>
        (Kind => U16, Where => Master, How => Direct, Limits => 131, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18),
      Ledstrip_Beacon_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18),
      Ledstrip_Beacon_Armed_Only =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18),
      Ledstrip_Brightness =>
        (Kind => U8, Where => Master, How => Direct, Limits => 103, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18),
      Ledstrip_Rainbow_Delta =>
        (Kind => U16, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18),
      Ledstrip_Rainbow_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 91, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18),
      Transponder_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Transponder_Provider, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11),
      Transponder_Data =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 9, Min_Length => 0,
         Write_Once => False, Group => 11),
      Sdcard_Detect_Inverted =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 46),
      Sdcard_Mode =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Sdcard_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 46),
      Osd_Units =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Unit, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Warn_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Rssi_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Link_Quality_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Rssi_Dbm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 12, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Rsnr_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 16, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Cap_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Alt_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Distance_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Esc_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Esc_Rpm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 23, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Esc_Current_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 23, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Core_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Ah_Max_Pit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 45, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Ah_Max_Rol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 45, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Ah_Invert =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Logo_On_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Osd_Logo_On_Arming, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Osd_Logo_On_Arming_Duration =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Arming_Logo =>
        (Kind => U8, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Use_Quick_Menu =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Show_Spec_Prearm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Tim1 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 70, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Tim2 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 70, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Vbat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Rssi_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Link_Quality_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Link_Tx_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Rssi_Dbm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Rsnr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Tim_1_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Tim_2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Remaining_Time_Estimate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Flymode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Anti_Gravity_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_G_Force_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Throttle_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Vtx_Channel_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Crosshairs_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Ah_Sbar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Ah_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Current_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Mah_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wh_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Motor_Diag_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Craft_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pilot_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Gps_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Gps_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Gps_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Gps_Lap_Curr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Gps_Lap_Prev_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Gps_Lap_Best3_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Gps_Sats_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Home_Dir_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Home_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Flight_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Compass_Bar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Altitude_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pid_Roll_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pid_Pitch_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pid_Yaw_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Debug_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Debug2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pidrate_Profile_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Avg_Cell_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pit_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Rol_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Battery_Usage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Disarmed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Nheading_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Up_Down_Reference_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Ready_Mode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pos_Hold_Ready_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Nvario_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Esc_Tmp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Esc_Rpm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Esc_Rpm_Freq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Rtc_Date_Time_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Adjustment_Range_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Flip_Arrow_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Core_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Log_Status_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Stick_Overlay_Left_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Stick_Overlay_Right_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Stick_Overlay_Radio_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Rate_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Pid_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Battery_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Rcchannels_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Camera_Frame_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Efficiency_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Total_Flights_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Aux_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Goggle_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Vtx_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Bitrate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Delay_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Lq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Goggle_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Vtx_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Vtx_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Sys_Fan_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Stat_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Profile =>
        (Kind => U8, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Profile_1_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 38),
      Osd_Profile_2_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 38),
      Osd_Profile_3_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 38),
      Osd_Gps_Sats_Show_Pdop =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Displayport_Device =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Osd_Displayport_Device, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Osd_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 38),
      Osd_Rcchannels =>
        (Kind => I8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Camera_Frame_Width =>
        (Kind => U8, Where => Master, How => Direct, Limits => 96, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Camera_Frame_Height =>
        (Kind => U8, Where => Master, How => Direct, Limits => 95, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Stat_Avg_Cell_Value =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Framerate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 83, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Menu_Background =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Cms_Background, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38),
      Osd_Aux_Channel =>
        (Kind => U8, Where => Master, How => Direct, Limits => 79, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Aux_Scale =>
        (Kind => U16, Where => Master, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Aux_Symbol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Craftname_Msgs =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Lidar_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Custom_Serial_Text_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Custom_Serial_Text_Terminator =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Osd_Custom_Text_Terminator, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 79),
      Osd_Custom_Text_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 38),
      Osd_Custom_Text_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Wp_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wp_Current_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wp_Current_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wp_Current_Alt_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wp_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wp_Direction_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wp_Next_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Wp_Eta_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Nav_Map_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      Osd_Nav_Map_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 77),
      Osd_Nav_Map_Centre =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 77),
      Osd_Nav_Map_Min_Scale_M =>
        (Kind => U16, Where => Master, How => Direct, Limits => 119, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 77),
      Osd_Airspeed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80),
      System_Hse_Mhz =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 37, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 12),
      Task_Statistics =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12),
      Debug_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Debug, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12),
      Rate_6pos_Switch =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12),
      Cpu_Overclock =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Overclock, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 12),
      Pwr_On_Arm_Grace =>
        (Kind => U8, Where => Master, How => Direct, Limits => 37, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12),
      Enable_Stick_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12),
      Vtx_Band =>
        (Kind => U8, Where => Master, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37),
      Vtx_Channel =>
        (Kind => U8, Where => Master, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37),
      Vtx_Power =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37),
      Vtx_Low_Power_Disarm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Vtx_Low_Power_Disarm, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 37),
      Vtx_Softserial_Alt =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37),
      Vtx_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Vtx_Type, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 37),
      Vtx_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 37),
      Vtx_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 64, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 37),
      Vtx_Pit_Mode_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 64, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 37),
      Vtx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 50),
      Vtx_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 29),
      Vcd_Video_System =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Video_System, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 49),
      Vcd_H_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 15, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 49),
      Vcd_V_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 18, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 49),
      Max7456_Clock =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Max7456_Clock, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Max7456_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 55),
      Max7456_Preinit_Opu =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 55),
      Displayport_Msp_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 19, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 47),
      Displayport_Msp_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 20, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 47),
      Displayport_Msp_Fonts =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 47),
      Displayport_Msp_Use_Device_Blink =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 47),
      Displayport_Max7456_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 19, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48),
      Displayport_Max7456_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 20, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48),
      Displayport_Max7456_Inv =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48),
      Displayport_Max7456_Blk =>
        (Kind => U8, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48),
      Displayport_Max7456_Wht =>
        (Kind => U8, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48),
      Esc_Sensor_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 51),
      Esc_Sensor_Current_Offset =>
        (Kind => U16, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 51),
      Esc_Sensor_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 51),
      Frsky_Spi_Autobind =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 54),
      Frsky_Spi_Tx_Id =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 54),
      Frsky_Spi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 13, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 54),
      Frsky_Spi_Bind_Hop_Data =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 50, Min_Length => 0,
         Write_Once => False, Group => 54),
      Frsky_X_Rx_Num =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 54),
      Frsky_Spi_A1_Source =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Rx_Frsky_Spi_A1_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 54),
      Cc2500_Spi_Chip_Detect =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54),
      Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 42),
      Dashboard_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 53),
      Dashboard_I2c_Addr =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 106, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 53),
      Rangefinder_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Rangefinder_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 58),
      Rangefinder_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 58),
      Opticalflow_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Opticalflow_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 75),
      Opticalflow_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 75),
      Opticalflow_Rotation =>
        (Kind => I16, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 75),
      Opticalflow_Flip_X =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Pinio_Config =>
        (Kind => U8, Where => Hardware, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 59),
      Pinio_Box =>
        (Kind => U8, Where => Hardware, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 60),
      Usb_Hid_Cdc =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 61),
      Usb_Msc_Pin_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 61),
      Flash_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 43),
      Rcdevice_Init_Dev_Attempts =>
        (Kind => U8, Where => Master, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 63),
      Rcdevice_Init_Dev_Attempt_Interval =>
        (Kind => U32, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 63),
      Rcdevice_Protocol_Version =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 63),
      Rcdevice_Feature =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 63),
      Rcdevice_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 63),
      Gyro_1_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 64),
      Gyro_1_Spibus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64),
      Gyro_1_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64),
      Gyro_1_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 48, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64),
      I2c1_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52),
      I2c1_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52),
      I2c2_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52),
      I2c2_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52),
      I2c3_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52),
      I2c3_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52),
      Mco2_On_Pc9 =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65),
      Spektrum_Spi_Protocol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 66),
      Spektrum_Spi_Mfg_Id =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 66),
      Spektrum_Spi_Num_Channels =>
        (Kind => U8, Where => Master, How => Direct, Limits => 31, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 66),
      Expresslrs_Uid =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 6, Min_Length => 0,
         Write_Once => False, Group => 71),
      Expresslrs_Domain =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Freq_Domain, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 71),
      Expresslrs_Model_Id =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 71),
      Scheduler_Relax_Rx =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 72),
      Scheduler_Relax_Osd =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 72),
      Scheduler_Debug_Task =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 39, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 72),
      Cpu_Late_Limit_Permille =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 72),
      Serialmsp_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 73),
      Msp_1_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 73),
      Msp_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73),
      Msp_2_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 73),
      Msp_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73),
      Msp_3_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 73),
      Msp_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73),
      Timezone_Offset_Minutes =>
        (Kind => I16, Where => Master, How => Direct, Limits => 8, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 57),
      Rpm_Filter_Harmonics =>
        (Kind => U8, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 67),
      Rpm_Filter_Weights =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 67),
      Rpm_Filter_Q =>
        (Kind => U16, Where => Master, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 67),
      Rpm_Filter_Min_Hz =>
        (Kind => U8, Where => Master, How => Direct, Limits => 123, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 67),
      Rpm_Filter_Fade_Range_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 67),
      Rpm_Filter_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 67),
      Flysky_Spi_Tx_Id =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 56),
      Flysky_Spi_Rf_Channels =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length => 0,
         Write_Once => False, Group => 56),
      Stats_Min_Armed_Time_S =>
        (Kind => I8, Where => Master, How => Direct, Limits => 22, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 68),
      Stats_Total_Flights =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Stats_Total_Time_S =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Stats_Total_Dist_M =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Stats_Save_Move_Limit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 68),
      Stats_Mah_Used =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Craft_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 25),
      Pilot_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 25),
      Altitude_Source =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 24, Table => Table_Position_Alt_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 28),
      Altitude_Prefer_Baro =>
        (Kind => I8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 28),
      Altitude_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28),
      Rangefinder_Max_Range_Cm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 127, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28),
      Altitude_D_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28),
      Ap_Landing_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Hover_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Throttle_Min =>
        (Kind => U16, Where => Master, How => Direct, Limits => 151, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Throttle_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 153, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Altitude_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Altitude_I =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Altitude_D =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Altitude_A =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Altitude_F =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Position_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Position_I =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Position_D =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Position_A =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Position_F =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Position_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Stop_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Max_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Max_Yaw_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 111, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Velocity_Drag_Coeff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Max_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 137, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Waypoint_Arrival_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 137, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Waypoint_Hold_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 127, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Stick_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Throttle_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Yaw_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Ap_Yaw_Mode, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 32),
      Ap_Min_Forward_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 113, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Corner_Speed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Corner_Delta_V =>
        (Kind => U16, Where => Master, How => Direct, Limits => 136, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Decel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 118, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Accel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 118, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Carrot_Lead_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 97, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Nav_Carrot_Lead_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 146, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Preturn_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Velocity_Buildup_Max_Pitch =>
        (Kind => U8, Where => Master, How => Direct, Limits => 35, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Max_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 84, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Hold_Orbit_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 142, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Hold_Figure8_Width =>
        (Kind => U16, Where => Master, How => Direct, Limits => 145, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Landing_Descent_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Landing_Detection_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Landing_Spiral_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Landing_Spiral_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Landing_Spiral_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 81, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Landing_Velocity_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Landing_Throttle_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Limits => 113, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_L1_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_L1_Period =>
        (Kind => U16, Where => Master, How => Direct, Limits => 103, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_L1_Min_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Limits => 137, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_L1_Max_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_L1_Max_Cross_Track_Error =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_L1_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 45, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Min_Nav_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Rx_Loss_Policy =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Ap_Rx_Loss_Policy, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 32),
      Ap_Max_Distance_From_Home =>
        (Kind => U16, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Geofence_Action =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Ap_Geofence_Action, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 32),
      Box_User_1_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 69),
      Box_User_2_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 69),
      Box_User_3_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 69),
      Box_User_4_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 69),
      Gimbal_Roll_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Pitch_Rc_Thr_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Pitch_Rc_Low_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Pitch_Rc_High_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Yaw_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Roll_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Roll_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Roll_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Pitch_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Pitch_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Pitch_Low_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Pitch_High_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Yaw_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Yaw_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Yaw_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Stabilisation =>
        (Kind => I8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Sensitivity =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Gimbal_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 74));

   function Describe (S : Setting) return Info is
     (Kind => Infos (S).Kind, Where => Infos (S).Where, How => Infos (S).How,
      Min => Limit_Pairs (Infos (S).Limits).Min, Max => Limit_Pairs (Infos (S).Limits).Max,
      Table => Infos (S).Table, Count => Infos (S).Count, Min_Length => Infos (S).Min_Length,
      Write_Once => Infos (S).Write_Once, Group => Group_Numbers (Infos (S).Group));

   --  The setting names in codes: a code below 128 is a character, a higher one the token of its
   --  pair merge. Each name starts at its start and decodes to its length, and the codes and the
   --  tokens end with room for a longest name and token, so every read stays within them by the
   --  types alone.
   Name_Codes_Length : constant := 7566;
   subtype Name_Code_Index is Natural range 0 .. Name_Codes_Length + Max_Name_Length - 1;

   --  The code at an index, outside the proof: the decoder needs no fact about the codes.
   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8;

   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8 with SPARK_Mode => Off is
      Codes : constant array (Name_Code_Index) of Interfaces.Unsigned_8 :=
        (213, 164, 141, 100, 222, 130, 108, 226, 213, 248, 49, 153, 121, 196, 213, 248, 49, 145, 116, 135, 210,
         238, 213, 248, 50, 153, 121, 196, 213, 248, 50, 145, 116, 135, 210, 238, 213, 95, 110, 161, 157, 49,
         238, 213, 95, 110, 161, 157, 49, 148, 249, 223, 213, 95, 110, 161, 157, 50, 238, 213, 95, 110, 161,
         157, 50, 148, 249, 223, 213, 148, 139, 105, 98, 137, 232, 135, 187, 213, 148, 139, 105, 98, 95, 110,
         111, 147, 130, 108, 192, 213, 95, 223, 115, 158, 95, 188, 213, 95, 111, 215, 102, 202, 119, 137, 158,
         101, 99, 116, 188, 145, 112, 132, 95, 142, 99, 111, 215, 121, 188, 145, 112, 132, 153, 104, 142, 189,
         166, 100, 100, 121, 110, 95, 110, 161, 157, 148, 111, 244, 116, 100, 121, 110, 95, 110, 161, 157, 95,
         113, 100, 121, 110, 95, 110, 161, 157, 169, 132, 238, 100, 121, 110, 95, 110, 161, 157, 95, 177, 238,
         213, 248, 49, 137, 121, 110, 169, 132, 238, 213, 248, 49, 137, 121, 110, 95, 177, 238, 213, 248, 49,
         137, 121, 110, 95, 250, 112, 111, 213, 95, 167, 108, 190, 184, 98, 117, 103, 95, 97, 120, 147, 191, 99,
         164, 141, 100, 222, 101, 191, 99, 248, 238, 191, 99, 153, 114, 144, 133, 211, 191, 99, 153, 114, 144,
         95, 251, 191, 99, 148, 139, 105, 98, 114, 135, 187, 139, 105, 103, 110, 95, 150, 103, 150, 103, 233,
         105, 103, 110, 95, 251, 150, 103, 233, 105, 103, 110, 133, 211, 150, 103, 233, 105, 103, 110, 95, 188,
         150, 103, 172, 117, 160, 121, 196, 150, 103, 234, 50, 99, 184, 118, 210, 101, 150, 103, 234, 50, 99,
         95, 182, 100, 142, 115, 115, 150, 103, 227, 184, 118, 210, 101, 150, 103, 164, 141, 100, 222, 101, 150,
         103, 148, 139, 105, 98, 114, 135, 187, 98, 97, 138, 172, 117, 160, 121, 196, 98, 97, 138, 227, 184,
         118, 210, 101, 98, 97, 138, 234, 50, 99, 184, 118, 210, 101, 98, 97, 138, 234, 50, 99, 95, 182, 100,
         142, 115, 115, 98, 97, 138, 164, 141, 100, 222, 101, 98, 97, 138, 137, 245, 102, 116, 112, 136, 161,
         172, 117, 160, 121, 196, 112, 136, 161, 234, 50, 99, 184, 118, 210, 101, 112, 136, 161, 234, 50, 99,
         95, 182, 100, 142, 115, 115, 112, 136, 161, 164, 141, 100, 222, 101, 109, 105, 128, 114, 99, 109, 132,
         148, 104, 101, 170, 177, 148, 104, 101, 170, 197, 115, 105, 148, 104, 154, 110, 101, 108, 197, 115,
         105, 145, 114, 99, 219, 174, 109, 130, 131, 138, 197, 197, 115, 105, 145, 99, 139, 101, 197, 115, 105,
         95, 223, 115, 158, 197, 115, 105, 95, 132, 215, 116, 197, 115, 105, 145, 114, 99, 219, 174, 109, 130,
         108, 226, 133, 131, 105, 111, 100, 197, 115, 105, 145, 239, 161, 104, 179, 114, 99, 145, 239, 161, 104,
         179, 114, 99, 145, 239, 161, 104, 179, 95, 209, 116, 111, 219, 191, 116, 151, 114, 99, 145, 239, 161,
         104, 179, 95, 209, 116, 111, 219, 191, 116, 151, 153, 104, 246, 143, 114, 99, 145, 239, 161, 104, 179,
         145, 158, 112, 111, 132, 116, 148, 249, 223, 114, 99, 145, 239, 161, 104, 179, 153, 104, 246, 156, 99,
         249, 223, 114, 99, 145, 239, 161, 104, 179, 184, 98, 117, 103, 95, 97, 120, 147, 102, 112, 118, 169,
         105, 120, 184, 103, 142, 101, 115, 177, 95, 209, 120, 148, 104, 154, 110, 101, 108, 115, 115, 131, 105,
         139, 114, 120, 133, 138, 118, 105, 100, 131, 115, 131, 105, 139, 114, 120, 95, 132, 215, 175, 100, 115,
         196, 107, 116, 114, 117, 109, 145, 135, 172, 132, 100, 115, 196, 107, 116, 114, 117, 109, 145, 135,
         172, 132, 128, 209, 116, 111, 142, 115, 158, 115, 114, 120, 108, 50, 95, 244, 136, 234, 100, 115, 114,
         120, 108, 50, 172, 209, 128, 102, 97, 160, 115, 98, 117, 159, 98, 209, 128, 102, 97, 160, 99, 197, 102,
         95, 193, 130, 110, 101, 103, 161, 105, 199, 128, 98, 209, 100, 97, 105, 114, 239, 100, 130, 160, 240,
         153, 104, 246, 156, 112, 131, 99, 176, 116, 114, 120, 169, 132, 95, 193, 101, 99, 114, 120, 95, 177,
         95, 193, 101, 99, 115, 131, 105, 139, 114, 120, 164, 139, 102, 100, 117, 112, 143, 120, 114, 120, 95,
         117, 240, 109, 115, 140, 111, 215, 245, 100, 130, 157, 154, 110, 101, 108, 159, 150, 115, 107, 109,
         115, 140, 111, 215, 245, 100, 130, 102, 97, 105, 108, 115, 97, 102, 101, 114, 120, 227, 133, 198, 111,
         99, 166, 114, 120, 227, 172, 193, 114, 120, 227, 95, 228, 132, 215, 115, 187, 182, 99, 184, 118, 210,
         101, 182, 99, 95, 118, 142, 102, 132, 116, 148, 139, 105, 98, 114, 135, 187, 182, 99, 153, 101, 109,
         112, 115, 176, 115, 151, 148, 139, 105, 98, 114, 135, 187, 51, 48, 182, 99, 153, 101, 109, 112, 115,
         176, 115, 151, 148, 139, 105, 98, 114, 135, 187, 49, 49, 48, 132, 112, 249, 95, 167, 108, 190, 179,
         169, 111, 168, 231, 145, 97, 109, 112, 156, 114, 199, 231, 184, 118, 210, 101, 231, 180, 156, 178, 100,
         115, 231, 180, 156, 114, 99, 231, 180, 156, 115, 158, 112, 111, 132, 116, 231, 180, 156, 194, 231, 180,
         156, 150, 103, 231, 180, 156, 139, 116, 231, 180, 156, 197, 115, 105, 231, 180, 156, 213, 231, 180,
         156, 213, 244, 167, 108, 116, 231, 180, 156, 191, 99, 231, 180, 156, 135, 116, 136, 117, 168, 231, 180,
         156, 168, 98, 117, 103, 231, 180, 156, 109, 161, 151, 115, 231, 180, 156, 115, 131, 118, 129, 231, 180,
         156, 114, 112, 109, 231, 180, 156, 173, 115, 231, 180, 156, 112, 136, 161, 231, 169, 111, 168, 231,
         164, 105, 103, 104, 95, 142, 115, 166, 249, 187, 231, 95, 117, 240, 231, 172, 209, 100, 177, 153, 104,
         246, 143, 109, 132, 148, 111, 109, 150, 110, 100, 109, 161, 151, 95, 107, 118, 109, 161, 151, 234, 100,
         143, 100, 189, 161, 172, 232, 160, 100, 189, 161, 172, 105, 100, 105, 114, 100, 189, 161, 95, 220, 116,
         100, 189, 161, 172, 136, 98, 235, 100, 189, 161, 172, 136, 98, 235, 153, 144, 131, 193, 130, 244, 115,
         121, 110, 99, 225, 112, 119, 109, 109, 161, 151, 133, 119, 109, 133, 198, 111, 99, 166, 109, 161, 151,
         133, 119, 109, 252, 109, 161, 151, 133, 119, 247, 132, 215, 115, 187, 109, 161, 151, 133, 111, 143,
         115, 109, 161, 151, 95, 111, 249, 112, 249, 95, 142, 151, 100, 131, 179, 221, 114, 148, 151, 114, 95,
         118, 139, 117, 101, 221, 114, 148, 151, 114, 95, 235, 143, 102, 97, 105, 108, 115, 97, 102, 130, 168,
         236, 102, 97, 105, 108, 115, 97, 102, 130, 146, 110, 100, 179, 153, 144, 101, 102, 97, 105, 108, 115,
         97, 102, 130, 221, 246, 143, 102, 97, 105, 108, 115, 97, 102, 130, 115, 119, 211, 169, 111, 168, 102,
         97, 105, 108, 115, 97, 102, 130, 221, 246, 156, 202, 119, 184, 236, 102, 97, 105, 108, 115, 97, 102,
         130, 112, 138, 99, 220, 117, 142, 102, 97, 105, 108, 115, 97, 102, 130, 142, 99, 111, 215, 121, 184,
         236, 102, 97, 105, 108, 115, 97, 102, 130, 160, 105, 170, 153, 104, 142, 189, 166, 100, 139, 105, 103,
         110, 172, 111, 141, 128, 251, 139, 105, 103, 110, 172, 111, 141, 128, 112, 211, 139, 105, 103, 110,
         172, 111, 141, 128, 188, 254, 169, 111, 168, 194, 190, 121, 133, 138, 167, 156, 255, 101, 194, 148, 97,
         112, 191, 136, 121, 118, 194, 95, 177, 148, 101, 185, 95, 118, 166, 116, 97, 103, 101, 118, 194, 219,
         117, 185, 148, 101, 185, 95, 118, 166, 116, 97, 103, 101, 118, 194, 169, 132, 148, 101, 185, 95, 118,
         166, 116, 97, 103, 101, 118, 194, 95, 222, 110, 179, 148, 101, 185, 95, 118, 166, 116, 97, 103, 101,
         99, 194, 233, 131, 116, 133, 131, 99, 176, 116, 102, 151, 99, 130, 194, 190, 121, 148, 101, 185, 148,
         111, 244, 116, 118, 194, 164, 121, 160, 131, 101, 115, 147, 99, 232, 142, 110, 116, 169, 158, 131, 194,
         190, 121, 169, 158, 131, 118, 194, 137, 158, 101, 99, 116, 148, 101, 185, 95, 118, 166, 116, 97, 103,
         101, 193, 130, 118, 194, 233, 131, 116, 115, 193, 130, 99, 194, 233, 131, 116, 115, 118, 194, 148, 249,
         223, 133, 131, 99, 176, 116, 118, 194, 162, 112, 236, 248, 133, 131, 105, 111, 100, 118, 194, 145, 97,
         103, 248, 133, 131, 105, 111, 100, 105, 194, 248, 133, 131, 105, 111, 100, 118, 194, 137, 232, 135,
         187, 219, 151, 95, 222, 110, 179, 118, 194, 137, 232, 135, 187, 219, 151, 148, 114, 136, 210, 139, 118,
         194, 145, 99, 139, 101, 118, 194, 137, 105, 118, 105, 100, 131, 118, 194, 169, 117, 108, 116, 105, 112,
         217, 131, 105, 194, 97, 145, 99, 139, 101, 105, 194, 97, 95, 223, 115, 158, 105, 194, 118, 145, 99,
         139, 101, 105, 194, 118, 95, 223, 115, 158, 194, 190, 121, 148, 152, 116, 132, 117, 101, 98, 101, 101,
         112, 131, 95, 132, 215, 115, 187, 98, 101, 101, 112, 131, 95, 111, 100, 98, 101, 101, 112, 131, 219,
         142, 113, 117, 176, 99, 121, 98, 101, 101, 112, 131, 137, 189, 161, 172, 101, 191, 152, 153, 152, 101,
         188, 169, 161, 151, 159, 142, 215, 115, 220, 109, 105, 120, 131, 153, 121, 196, 99, 174, 189, 102, 217,
         140, 109, 161, 151, 133, 131, 99, 176, 116, 99, 174, 189, 102, 217, 140, 114, 199, 99, 174, 189, 102,
         217, 140, 209, 116, 111, 95, 142, 201, 114, 112, 109, 155, 192, 114, 112, 109, 155, 192, 133, 114, 112,
         109, 155, 192, 234, 114, 112, 109, 155, 192, 137, 114, 112, 109, 155, 192, 95, 118, 139, 117, 101, 51,
         128, 168, 182, 98, 154, 128, 202, 119, 51, 128, 168, 182, 98, 154, 128, 104, 105, 103, 104, 51, 128,
         110, 101, 249, 114, 139, 51, 128, 168, 182, 98, 154, 128, 221, 246, 143, 51, 128, 108, 192, 155, 111,
         119, 51, 128, 108, 192, 164, 105, 103, 104, 51, 128, 115, 119, 211, 225, 239, 168, 115, 131, 118, 111,
         148, 176, 190, 133, 117, 108, 115, 101, 115, 131, 118, 111, 133, 119, 109, 252, 115, 131, 118, 111,
         155, 111, 119, 112, 97, 115, 159, 104, 122, 116, 245, 95, 244, 201, 225, 115, 131, 118, 111, 157, 154,
         110, 101, 108, 219, 151, 222, 100, 179, 145, 116, 240, 114, 199, 112, 138, 167, 156, 255, 101, 221,
         114, 169, 105, 100, 221, 114, 95, 250, 112, 111, 221, 114, 164, 111, 215, 114, 199, 115, 153, 121, 196,
         113, 117, 105, 170, 114, 199, 159, 114, 99, 95, 250, 112, 111, 251, 165, 99, 252, 112, 211, 165, 99,
         252, 188, 165, 99, 252, 251, 95, 250, 112, 111, 112, 211, 95, 250, 112, 111, 188, 95, 250, 112, 111,
         251, 145, 114, 199, 112, 211, 145, 114, 199, 188, 145, 114, 199, 221, 246, 156, 108, 192, 153, 121,
         196, 221, 246, 156, 108, 192, 133, 131, 99, 176, 116, 251, 165, 135, 130, 108, 192, 112, 211, 165, 135,
         130, 108, 192, 188, 165, 135, 130, 108, 192, 142, 183, 161, 148, 104, 141, 191, 190, 115, 131, 105,
         139, 95, 117, 112, 100, 135, 130, 114, 135, 130, 104, 122, 144, 117, 137, 99, 247, 107, 112, 144, 117,
         137, 99, 247, 107, 105, 115, 109, 139, 108, 95, 235, 143, 144, 117, 133, 138, 99, 101, 115, 115, 137,
         176, 111, 109, 150, 103, 184, 99, 108, 132, 135, 187, 209, 116, 111, 162, 201, 184, 236, 213, 148, 139,
         95, 152, 95, 167, 114, 160, 95, 201, 112, 142, 201, 233, 202, 119, 95, 142, 201, 173, 115, 133, 138,
         118, 105, 100, 131, 173, 115, 145, 98, 97, 159, 239, 168, 195, 209, 116, 111, 148, 152, 167, 103, 195,
         209, 116, 111, 172, 209, 100, 195, 117, 98, 202, 120, 95, 191, 113, 117, 105, 114, 130, 239, 168, 108,
         195, 117, 98, 202, 120, 219, 217, 103, 104, 116, 169, 111, 168, 108, 195, 117, 112, 100, 135, 130, 114,
         135, 130, 104, 122, 195, 117, 98, 202, 120, 95, 249, 99, 145, 116, 154, 100, 141, 100, 195, 117, 98,
         202, 120, 95, 193, 130, 103, 139, 105, 143, 111, 195, 117, 98, 202, 120, 95, 176, 171, 156, 154, 97,
         173, 115, 145, 158, 164, 111, 109, 130, 112, 111, 132, 116, 95, 152, 99, 101, 195, 193, 130, 51, 128,
         115, 196, 220, 173, 115, 145, 98, 97, 159, 132, 175, 103, 114, 136, 121, 195, 110, 109, 101, 97, 148,
         117, 160, 111, 109, 148, 111, 109, 150, 110, 100, 115, 195, 117, 240, 195, 98, 209, 100, 195, 142, 203,
         117, 130, 109, 132, 145, 116, 240, 162, 116, 195, 142, 203, 117, 130, 139, 116, 169, 111, 168, 195,
         142, 203, 117, 130, 132, 136, 105, 139, 148, 108, 241, 195, 142, 203, 117, 130, 97, 203, 176, 128, 114,
         199, 195, 142, 203, 117, 130, 142, 116, 232, 110, 233, 116, 195, 142, 203, 117, 130, 103, 138, 244,
         128, 115, 196, 220, 195, 142, 203, 117, 130, 168, 203, 176, 116, 162, 116, 195, 142, 203, 117, 130,
         168, 203, 176, 128, 114, 199, 195, 142, 203, 117, 130, 115, 154, 136, 121, 148, 104, 101, 170, 115,
         195, 142, 203, 117, 130, 109, 132, 145, 135, 115, 195, 142, 203, 117, 130, 139, 202, 119, 95, 201, 179,
         95, 119, 136, 104, 111, 249, 95, 167, 120, 195, 142, 203, 117, 130, 188, 133, 195, 146, 140, 116, 144,
         131, 218, 135, 130, 108, 135, 195, 146, 140, 116, 144, 131, 218, 135, 130, 108, 152, 195, 146, 140,
         116, 144, 131, 169, 132, 95, 146, 140, 116, 144, 130, 115, 195, 146, 140, 116, 144, 131, 218, 135, 130,
         116, 166, 131, 154, 99, 130, 109, 168, 182, 98, 154, 100, 188, 184, 182, 98, 154, 100, 188, 148, 152,
         116, 138, 108, 95, 142, 215, 115, 220, 139, 116, 164, 166, 128, 99, 108, 241, 252, 139, 116, 164, 166,
         128, 168, 182, 98, 154, 100, 186, 164, 166, 128, 168, 182, 98, 154, 100, 186, 104, 166, 128, 186, 136,
         187, 145, 111, 232, 99, 101, 186, 104, 166, 128, 111, 112, 116, 210, 139, 102, 202, 119, 95, 113, 117,
         139, 136, 121, 169, 132, 186, 104, 166, 128, 111, 112, 116, 210, 139, 102, 202, 119, 95, 177, 165, 235,
         101, 178, 128, 112, 138, 99, 101, 115, 115, 137, 176, 111, 109, 114, 244, 181, 97, 121, 153, 97, 107,
         101, 223, 133, 142, 118, 176, 116, 187, 114, 244, 181, 97, 121, 153, 97, 107, 101, 223, 184, 191, 116,
         105, 118, 135, 130, 168, 236, 114, 244, 181, 97, 121, 153, 97, 107, 101, 223, 184, 191, 116, 105, 118,
         135, 130, 221, 246, 156, 112, 131, 99, 176, 116, 112, 138, 167, 156, 255, 101, 100, 190, 109, 248, 49,
         137, 121, 110, 169, 132, 238, 100, 190, 109, 248, 49, 137, 121, 110, 95, 177, 238, 100, 190, 109, 248,
         49, 137, 121, 110, 95, 250, 112, 111, 100, 190, 109, 248, 49, 153, 121, 196, 100, 190, 109, 248, 49,
         145, 116, 135, 210, 238, 100, 190, 109, 248, 50, 153, 121, 196, 100, 190, 109, 248, 50, 145, 116, 135,
         210, 238, 100, 190, 247, 110, 161, 157, 238, 100, 190, 247, 110, 161, 157, 148, 249, 223, 118, 194,
         145, 97, 103, 148, 111, 109, 112, 176, 115, 135, 187, 178, 128, 135, 169, 132, 153, 104, 246, 143, 154,
         116, 105, 218, 174, 118, 136, 121, 218, 224, 154, 116, 105, 218, 174, 118, 136, 121, 148, 249, 223,
         238, 154, 116, 105, 218, 174, 118, 136, 121, 133, 218, 224, 191, 99, 155, 192, 95, 188, 191, 99, 155,
         192, 99, 174, 189, 137, 221, 142, 189, 166, 100, 99, 174, 189, 218, 221, 142, 189, 166, 100, 99, 174,
         189, 145, 158, 112, 111, 132, 116, 153, 104, 142, 189, 166, 100, 99, 174, 189, 153, 144, 101, 99, 174,
         189, 184, 236, 99, 174, 189, 95, 142, 99, 111, 215, 121, 95, 235, 143, 99, 174, 189, 95, 142, 99, 111,
         215, 121, 252, 99, 174, 189, 155, 192, 95, 188, 99, 174, 189, 95, 142, 99, 111, 215, 121, 136, 131,
         247, 198, 135, 187, 136, 131, 247, 142, 146, 120, 136, 131, 247, 142, 146, 120, 153, 121, 196, 136,
         131, 247, 142, 146, 120, 148, 249, 223, 136, 131, 247, 119, 132, 100, 117, 112, 178, 100, 115, 117,
         109, 155, 192, 178, 100, 115, 117, 109, 155, 192, 95, 188, 188, 155, 111, 119, 112, 97, 115, 159, 104,
         122, 221, 246, 156, 183, 129, 116, 221, 246, 156, 183, 129, 116, 148, 249, 223, 191, 138, 153, 174,
         132, 131, 95, 235, 156, 108, 192, 191, 138, 153, 174, 132, 131, 155, 111, 111, 107, 97, 104, 101, 97,
         128, 109, 115, 191, 138, 153, 174, 132, 131, 184, 98, 117, 103, 95, 97, 120, 147, 191, 138, 153, 174,
         132, 131, 218, 224, 112, 133, 211, 105, 133, 211, 128, 112, 211, 102, 133, 211, 140, 251, 105, 95, 251,
         128, 251, 102, 95, 251, 140, 188, 105, 95, 188, 128, 188, 102, 95, 188, 235, 156, 140, 103, 224, 235,
         156, 102, 101, 220, 102, 151, 222, 100, 235, 156, 102, 101, 220, 102, 151, 222, 128, 115, 239, 161,
         104, 179, 169, 115, 235, 156, 108, 192, 235, 156, 101, 141, 221, 95, 142, 102, 104, 151, 105, 122, 152,
         95, 143, 118, 101, 108, 145, 116, 142, 110, 103, 221, 104, 151, 105, 122, 152, 155, 192, 145, 116, 105,
         170, 115, 104, 151, 105, 122, 152, 155, 192, 184, 103, 142, 101, 115, 104, 151, 105, 122, 152, 234,
         103, 110, 151, 130, 160, 105, 170, 115, 104, 151, 105, 122, 152, 184, 236, 169, 115, 157, 105, 114,
         140, 146, 103, 219, 142, 113, 238, 157, 105, 114, 140, 143, 97, 128, 102, 142, 113, 238, 157, 105, 114,
         140, 97, 109, 112, 108, 136, 117, 100, 130, 251, 157, 105, 114, 140, 97, 109, 112, 108, 136, 117, 100,
         130, 112, 211, 157, 105, 114, 140, 97, 109, 112, 108, 136, 117, 100, 130, 188, 157, 105, 114, 140, 102,
         142, 113, 117, 176, 99, 121, 145, 116, 240, 184, 99, 105, 238, 157, 105, 114, 140, 102, 142, 113, 117,
         176, 99, 121, 95, 176, 128, 168, 99, 105, 238, 157, 105, 114, 140, 116, 144, 130, 115, 101, 99, 152,
         100, 115, 157, 105, 114, 140, 142, 196, 135, 128, 177, 95, 251, 128, 177, 133, 211, 128, 177, 95, 188,
         128, 177, 218, 224, 128, 177, 95, 182, 118, 154, 99, 101, 109, 161, 151, 95, 111, 249, 112, 249, 155,
         192, 209, 116, 111, 133, 138, 167, 156, 99, 101, 185, 148, 111, 244, 116, 146, 244, 157, 148, 152, 116,
         138, 108, 169, 111, 168, 146, 244, 157, 153, 245, 103, 103, 131, 233, 202, 119, 95, 142, 115, 158, 146,
         244, 157, 153, 245, 103, 103, 131, 153, 104, 246, 156, 112, 131, 99, 176, 116, 146, 244, 157, 95, 235,
         156, 108, 192, 146, 244, 157, 148, 152, 116, 138, 108, 218, 224, 221, 114, 117, 160, 155, 132, 101,
         141, 102, 101, 220, 102, 151, 222, 128, 116, 114, 154, 115, 136, 187, 102, 101, 220, 102, 151, 222,
         128, 97, 215, 97, 103, 179, 102, 101, 220, 102, 151, 222, 128, 115, 239, 161, 104, 219, 191, 116, 151,
         102, 101, 220, 102, 151, 222, 128, 106, 136, 190, 219, 191, 116, 151, 102, 101, 220, 102, 151, 222,
         128, 183, 129, 116, 102, 101, 220, 102, 151, 222, 128, 177, 165, 135, 130, 108, 192, 102, 101, 220,
         102, 151, 222, 128, 188, 164, 166, 128, 103, 224, 102, 101, 220, 102, 151, 222, 128, 188, 164, 166,
         128, 116, 144, 101, 100, 121, 110, 234, 100, 156, 109, 132, 165, 112, 109, 100, 121, 110, 234, 100,
         156, 140, 103, 224, 100, 121, 110, 234, 100, 156, 105, 218, 224, 100, 121, 110, 234, 100, 156, 128,
         103, 224, 100, 121, 110, 234, 100, 156, 177, 95, 132, 99, 142, 97, 115, 101, 143, 118, 101, 108, 165,
         191, 130, 239, 168, 115, 144, 112, 217, 167, 225, 178, 100, 159, 239, 168, 115, 144, 112, 217, 167,
         225, 150, 160, 131, 169, 117, 108, 116, 105, 112, 217, 131, 115, 144, 112, 217, 167, 225, 105, 218,
         224, 115, 144, 112, 217, 167, 225, 128, 103, 224, 115, 144, 112, 217, 167, 225, 178, 218, 224, 115,
         144, 112, 217, 167, 225, 128, 177, 218, 224, 115, 144, 112, 217, 167, 225, 102, 101, 220, 102, 151,
         222, 128, 103, 224, 115, 144, 112, 217, 167, 225, 112, 211, 95, 128, 103, 224, 115, 144, 112, 217, 167,
         225, 112, 211, 133, 105, 218, 224, 115, 144, 112, 217, 167, 225, 100, 190, 247, 167, 108, 190, 115,
         144, 112, 217, 167, 225, 100, 190, 247, 167, 108, 190, 169, 117, 108, 116, 105, 112, 217, 131, 115,
         144, 112, 217, 167, 225, 213, 95, 167, 108, 190, 115, 144, 112, 217, 167, 225, 213, 95, 167, 108, 190,
         169, 117, 108, 116, 105, 112, 217, 131, 116, 112, 97, 169, 111, 168, 116, 112, 97, 252, 116, 112, 97,
         172, 142, 97, 107, 112, 111, 132, 116, 116, 112, 97, 155, 111, 119, 252, 116, 112, 97, 155, 111, 119,
         172, 142, 97, 107, 112, 111, 132, 116, 116, 112, 97, 155, 111, 119, 233, 119, 97, 121, 115, 101, 122,
         95, 146, 110, 100, 179, 153, 104, 142, 189, 166, 100, 101, 122, 95, 146, 110, 100, 179, 155, 192, 101,
         122, 95, 146, 110, 100, 179, 145, 196, 220, 146, 110, 100, 179, 162, 201, 153, 104, 142, 189, 166, 100,
         116, 108, 247, 132, 215, 175, 100, 116, 108, 109, 164, 139, 102, 100, 117, 112, 143, 120, 208, 95, 49,
         133, 198, 111, 99, 166, 208, 95, 49, 95, 117, 240, 208, 95, 49, 172, 209, 100, 208, 95, 50, 133, 198,
         111, 99, 166, 208, 95, 50, 95, 117, 240, 208, 95, 50, 172, 209, 100, 208, 95, 51, 133, 198, 111, 99,
         166, 208, 95, 51, 95, 117, 240, 208, 95, 51, 172, 209, 100, 99, 197, 102, 153, 108, 247, 191, 99, 213,
         102, 197, 107, 121, 184, 102, 209, 108, 116, 155, 135, 102, 197, 107, 121, 184, 102, 209, 108, 116,
         155, 152, 103, 102, 197, 107, 121, 95, 195, 102, 151, 109, 135, 102, 197, 107, 121, 95, 244, 136, 102,
         197, 107, 121, 95, 118, 102, 97, 115, 133, 142, 99, 147, 187, 104, 161, 116, 233, 201, 95, 132, 116,
         178, 128, 132, 153, 108, 109, 142, 112, 151, 116, 148, 101, 185, 95, 118, 166, 116, 97, 103, 101, 105,
         98, 193, 145, 176, 115, 151, 150, 118, 108, 132, 107, 95, 150, 104, 95, 97, 159, 104, 101, 182, 179,
         137, 105, 118, 147, 151, 150, 118, 108, 132, 107, 169, 132, 153, 120, 98, 117, 102, 102, 150, 118, 108,
         132, 107, 95, 250, 116, 145, 116, 135, 117, 159, 114, 199, 150, 118, 108, 132, 107, 165, 99, 148, 104,
         154, 252, 150, 118, 108, 132, 107, 149, 252, 150, 118, 108, 132, 107, 95, 250, 116, 174, 49, 252, 150,
         118, 108, 132, 107, 95, 250, 116, 174, 50, 252, 150, 118, 108, 132, 107, 95, 250, 116, 174, 51, 252,
         243, 118, 166, 116, 97, 103, 101, 243, 99, 232, 142, 110, 116, 243, 102, 117, 101, 108, 243, 239, 168,
         243, 191, 99, 95, 120, 243, 191, 99, 95, 121, 243, 191, 99, 95, 122, 243, 112, 211, 243, 251, 243, 104,
         101, 182, 179, 243, 139, 116, 136, 117, 168, 243, 118, 141, 105, 111, 243, 108, 135, 155, 152, 103,
         243, 103, 138, 244, 128, 115, 196, 220, 243, 100, 147, 116, 154, 99, 101, 243, 101, 203, 148, 232, 142,
         110, 116, 243, 101, 203, 95, 118, 166, 116, 97, 103, 101, 243, 101, 203, 165, 112, 109, 243, 101, 203,
         153, 101, 109, 112, 131, 135, 117, 142, 243, 175, 109, 112, 131, 135, 117, 142, 243, 99, 163, 193, 220,
         143, 100, 160, 245, 140, 118, 147, 117, 139, 172, 101, 101, 112, 131, 143, 100, 160, 245, 140, 118,
         147, 117, 139, 172, 101, 101, 112, 131, 148, 166, 151, 143, 100, 160, 245, 140, 103, 114, 98, 165, 103,
         98, 143, 100, 160, 245, 112, 133, 138, 167, 143, 143, 100, 160, 245, 140, 174, 99, 130, 99, 166, 151,
         143, 100, 160, 245, 140, 98, 101, 191, 152, 148, 166, 151, 143, 100, 160, 245, 140, 98, 101, 191, 152,
         133, 131, 105, 111, 128, 109, 115, 143, 100, 160, 245, 140, 98, 101, 191, 152, 133, 131, 99, 176, 116,
         143, 100, 160, 245, 140, 98, 101, 191, 152, 95, 201, 225, 152, 108, 121, 143, 100, 160, 245, 140, 98,
         245, 103, 104, 116, 110, 101, 115, 115, 143, 100, 160, 245, 140, 174, 132, 183, 119, 184, 108, 116, 97,
         143, 100, 160, 245, 140, 174, 132, 183, 119, 219, 142, 113, 116, 114, 154, 115, 112, 152, 100, 131,
         133, 138, 118, 105, 100, 131, 116, 114, 154, 115, 112, 152, 100, 131, 137, 135, 97, 115, 100, 99, 141,
         128, 100, 158, 101, 99, 116, 95, 132, 215, 175, 100, 115, 100, 99, 141, 128, 239, 168, 134, 244, 136,
         115, 134, 222, 110, 172, 136, 150, 115, 107, 134, 197, 115, 105, 233, 201, 134, 108, 132, 107, 95, 113,
         117, 139, 136, 121, 233, 201, 134, 197, 115, 105, 137, 98, 109, 233, 201, 134, 197, 110, 114, 233, 201,
         134, 99, 163, 139, 201, 134, 139, 116, 233, 201, 134, 100, 147, 116, 154, 99, 130, 139, 201, 134, 101,
         203, 153, 101, 109, 140, 139, 201, 134, 101, 203, 165, 112, 109, 233, 201, 134, 101, 203, 148, 232,
         142, 110, 116, 233, 201, 134, 99, 151, 130, 175, 109, 140, 139, 201, 134, 97, 104, 95, 177, 133, 136,
         134, 97, 104, 95, 177, 95, 138, 108, 134, 97, 104, 95, 132, 215, 116, 134, 202, 103, 111, 95, 152, 95,
         201, 179, 134, 202, 103, 111, 95, 152, 95, 201, 179, 137, 232, 135, 187, 134, 201, 179, 155, 111, 103,
         111, 134, 193, 130, 113, 117, 105, 170, 169, 176, 117, 134, 189, 111, 119, 145, 196, 99, 133, 142, 201,
         134, 116, 144, 49, 134, 116, 144, 50, 134, 118, 194, 149, 134, 197, 115, 105, 149, 134, 108, 132, 107,
         95, 113, 117, 139, 136, 121, 149, 134, 108, 132, 107, 153, 120, 133, 111, 119, 131, 149, 134, 197, 115,
         105, 137, 98, 109, 149, 134, 197, 110, 114, 149, 134, 116, 144, 95, 49, 149, 134, 116, 144, 95, 50,
         149, 134, 142, 150, 132, 179, 153, 144, 130, 101, 160, 144, 135, 237, 134, 102, 108, 121, 239, 100,
         237, 134, 154, 116, 105, 218, 174, 118, 136, 121, 149, 134, 103, 219, 151, 99, 237, 134, 221, 246, 156,
         186, 134, 118, 116, 120, 148, 104, 154, 110, 101, 108, 149, 134, 99, 114, 129, 189, 97, 105, 197, 149,
         134, 97, 104, 145, 98, 141, 149, 134, 97, 104, 149, 134, 99, 232, 142, 110, 116, 149, 134, 150, 104,
         137, 174, 119, 110, 149, 134, 119, 104, 137, 174, 119, 110, 149, 134, 109, 161, 151, 137, 105, 97, 103,
         149, 134, 99, 174, 102, 116, 95, 255, 237, 134, 178, 108, 161, 95, 255, 237, 134, 173, 115, 145, 196,
         225, 186, 134, 173, 115, 155, 152, 149, 134, 173, 115, 155, 135, 149, 134, 195, 146, 140, 99, 232, 114,
         149, 134, 195, 146, 112, 133, 142, 118, 149, 134, 195, 146, 140, 98, 101, 160, 51, 149, 134, 173, 115,
         145, 135, 115, 149, 134, 104, 111, 109, 130, 100, 105, 114, 149, 134, 104, 111, 109, 130, 100, 147,
         116, 149, 134, 102, 217, 103, 104, 116, 162, 116, 149, 134, 99, 111, 109, 112, 97, 115, 159, 98, 141,
         149, 134, 139, 116, 136, 117, 100, 237, 134, 178, 128, 251, 149, 134, 178, 128, 112, 211, 149, 134,
         178, 128, 188, 149, 134, 168, 98, 117, 103, 149, 134, 168, 98, 117, 103, 50, 149, 134, 112, 111, 119,
         131, 149, 134, 178, 100, 114, 135, 130, 112, 138, 167, 156, 186, 134, 222, 110, 179, 115, 149, 134, 97,
         118, 103, 148, 101, 185, 95, 118, 166, 116, 97, 103, 237, 134, 112, 136, 95, 235, 149, 134, 138, 108,
         95, 235, 149, 134, 194, 190, 121, 95, 193, 97, 103, 237, 134, 100, 147, 201, 225, 186, 134, 110, 104,
         101, 182, 179, 149, 134, 117, 112, 137, 111, 119, 110, 95, 142, 102, 131, 176, 99, 237, 134, 142, 182,
         121, 169, 111, 100, 237, 134, 186, 164, 166, 128, 142, 182, 121, 149, 134, 110, 118, 141, 105, 111,
         149, 134, 101, 203, 153, 109, 112, 149, 134, 101, 203, 165, 112, 109, 149, 134, 101, 203, 165, 112,
         109, 219, 142, 113, 149, 134, 114, 116, 99, 137, 135, 130, 116, 144, 237, 134, 182, 106, 117, 160, 109,
         176, 116, 165, 235, 237, 134, 102, 217, 140, 141, 138, 119, 149, 134, 99, 151, 130, 175, 109, 112, 149,
         134, 202, 103, 145, 116, 135, 193, 149, 134, 160, 105, 170, 95, 111, 215, 236, 95, 143, 102, 116, 149,
         134, 160, 105, 170, 95, 111, 215, 236, 165, 105, 103, 104, 116, 149, 134, 160, 105, 170, 95, 111, 215,
         236, 165, 182, 105, 111, 169, 111, 168, 134, 114, 135, 130, 112, 138, 167, 156, 255, 237, 134, 178,
         128, 112, 138, 167, 156, 255, 237, 134, 194, 190, 121, 133, 138, 167, 156, 255, 237, 134, 112, 138,
         167, 156, 255, 237, 134, 114, 99, 157, 154, 110, 101, 108, 115, 149, 134, 99, 97, 109, 131, 97, 219,
         174, 109, 237, 134, 101, 102, 167, 99, 105, 176, 99, 121, 149, 134, 116, 161, 139, 219, 217, 103, 104,
         116, 115, 149, 134, 209, 120, 149, 134, 115, 121, 159, 103, 111, 103, 103, 156, 118, 166, 116, 97, 103,
         237, 134, 115, 121, 159, 118, 116, 120, 95, 118, 166, 116, 97, 103, 237, 134, 115, 121, 159, 98, 136,
         114, 135, 237, 134, 115, 121, 115, 184, 236, 149, 134, 115, 121, 115, 162, 116, 154, 99, 237, 134, 115,
         121, 115, 155, 113, 149, 134, 115, 121, 159, 103, 111, 103, 103, 156, 100, 118, 114, 149, 134, 115,
         121, 159, 118, 116, 120, 137, 118, 114, 149, 134, 115, 121, 159, 222, 110, 179, 115, 149, 134, 115,
         121, 159, 118, 116, 120, 153, 101, 109, 112, 149, 134, 115, 121, 159, 102, 154, 145, 196, 225, 186,
         134, 160, 135, 172, 136, 150, 115, 107, 134, 112, 138, 167, 143, 134, 112, 138, 167, 156, 49, 95, 255,
         101, 134, 112, 138, 167, 156, 50, 95, 255, 101, 134, 112, 138, 167, 156, 51, 95, 255, 101, 134, 173,
         115, 145, 135, 115, 145, 104, 111, 119, 133, 100, 111, 112, 134, 100, 147, 112, 236, 112, 151, 116,
         184, 118, 210, 101, 134, 117, 240, 134, 114, 99, 157, 154, 110, 101, 108, 115, 134, 99, 97, 109, 131,
         97, 219, 174, 109, 130, 119, 105, 100, 221, 134, 99, 97, 109, 131, 97, 219, 174, 109, 130, 104, 101,
         105, 103, 104, 116, 134, 160, 135, 95, 97, 118, 103, 148, 101, 185, 95, 118, 139, 117, 101, 134, 102,
         174, 109, 131, 135, 130, 104, 122, 134, 109, 176, 117, 172, 97, 170, 103, 138, 244, 100, 134, 209, 120,
         148, 104, 154, 110, 101, 108, 134, 209, 120, 145, 99, 139, 101, 134, 209, 120, 145, 121, 109, 98, 166,
         134, 99, 174, 102, 116, 255, 130, 109, 115, 103, 115, 134, 217, 100, 141, 162, 116, 149, 134, 99, 117,
         160, 111, 109, 145, 131, 105, 139, 153, 250, 116, 149, 134, 99, 117, 160, 111, 109, 145, 131, 105, 139,
         153, 250, 116, 153, 131, 109, 132, 135, 151, 134, 99, 117, 160, 111, 109, 153, 250, 116, 95, 117, 240,
         134, 99, 117, 160, 111, 109, 153, 250, 116, 172, 209, 100, 134, 119, 140, 110, 117, 109, 98, 131, 149,
         134, 119, 140, 99, 232, 142, 110, 116, 155, 135, 149, 134, 119, 140, 99, 232, 142, 110, 116, 155, 152,
         149, 134, 119, 140, 99, 232, 142, 110, 116, 233, 116, 149, 134, 119, 112, 162, 116, 154, 99, 237, 134,
         119, 112, 137, 105, 142, 99, 116, 187, 149, 134, 119, 140, 110, 250, 116, 95, 110, 117, 109, 98, 131,
         149, 134, 119, 140, 158, 97, 149, 134, 200, 118, 95, 150, 112, 149, 134, 200, 118, 95, 150, 140, 239,
         168, 134, 200, 118, 95, 150, 140, 99, 176, 116, 142, 134, 200, 118, 95, 150, 140, 109, 132, 145, 99,
         139, 130, 109, 134, 97, 105, 197, 196, 220, 115, 121, 160, 101, 109, 164, 115, 130, 109, 104, 122, 116,
         97, 115, 107, 145, 116, 135, 147, 116, 210, 115, 168, 98, 117, 103, 169, 111, 168, 114, 135, 130, 54,
         186, 145, 119, 211, 99, 112, 117, 95, 111, 215, 99, 202, 170, 112, 119, 114, 95, 152, 95, 201, 218,
         174, 99, 101, 176, 171, 156, 160, 105, 170, 95, 201, 179, 118, 116, 120, 172, 154, 100, 118, 116, 120,
         148, 104, 154, 110, 101, 108, 118, 116, 120, 133, 111, 119, 131, 118, 116, 120, 155, 111, 119, 133,
         111, 119, 131, 162, 201, 118, 116, 120, 145, 214, 116, 115, 131, 105, 139, 233, 116, 118, 116, 120,
         153, 121, 196, 118, 116, 120, 95, 117, 240, 118, 116, 120, 219, 142, 113, 118, 116, 120, 133, 136, 169,
         111, 100, 130, 102, 142, 113, 118, 116, 120, 164, 139, 102, 100, 117, 112, 143, 120, 118, 116, 120,
         227, 172, 193, 118, 99, 128, 118, 105, 168, 111, 145, 121, 160, 101, 109, 118, 99, 128, 104, 95, 223,
         115, 158, 118, 99, 128, 118, 95, 223, 115, 158, 177, 55, 52, 53, 54, 148, 202, 170, 177, 55, 52, 53,
         54, 227, 172, 193, 177, 55, 52, 53, 54, 133, 142, 132, 136, 95, 111, 112, 117, 100, 147, 112, 236, 112,
         151, 116, 169, 115, 140, 99, 166, 95, 182, 106, 117, 160, 100, 147, 112, 236, 112, 151, 116, 169, 115,
         140, 138, 119, 95, 182, 106, 117, 160, 100, 147, 112, 236, 112, 151, 116, 169, 115, 140, 102, 152, 116,
         115, 100, 147, 112, 236, 112, 151, 116, 169, 115, 140, 193, 130, 168, 118, 210, 130, 98, 108, 132, 107,
         100, 147, 112, 236, 112, 151, 116, 95, 177, 55, 52, 53, 54, 148, 166, 95, 182, 106, 117, 160, 100, 147,
         112, 236, 112, 151, 116, 95, 177, 55, 52, 53, 54, 95, 138, 119, 95, 182, 106, 117, 160, 100, 147, 112,
         236, 112, 151, 116, 95, 177, 55, 52, 53, 54, 95, 132, 118, 100, 147, 112, 236, 112, 151, 116, 95, 177,
         55, 52, 53, 54, 172, 108, 107, 100, 147, 112, 236, 112, 151, 116, 95, 177, 55, 52, 53, 54, 95, 119,
         104, 116, 101, 203, 145, 176, 115, 151, 164, 139, 102, 100, 117, 112, 143, 120, 101, 203, 145, 176,
         115, 151, 148, 232, 142, 110, 116, 95, 223, 115, 158, 101, 203, 145, 176, 115, 151, 95, 117, 240, 102,
         197, 107, 121, 227, 95, 209, 116, 111, 98, 132, 100, 102, 197, 107, 121, 227, 153, 120, 234, 100, 102,
         197, 107, 121, 227, 95, 223, 115, 158, 102, 197, 107, 121, 227, 172, 132, 128, 104, 111, 112, 137, 135,
         97, 102, 197, 107, 121, 95, 120, 165, 120, 95, 110, 117, 109, 102, 197, 107, 121, 227, 95, 97, 49, 145,
         111, 232, 99, 101, 99, 99, 50, 53, 48, 48, 227, 148, 104, 105, 112, 137, 158, 101, 99, 116, 228, 132,
         215, 115, 187, 100, 97, 189, 183, 141, 128, 105, 50, 99, 172, 193, 100, 97, 189, 183, 141, 128, 105,
         50, 99, 95, 182, 100, 114, 114, 235, 101, 102, 132, 100, 131, 164, 141, 100, 222, 101, 114, 235, 101,
         102, 132, 100, 131, 95, 117, 240, 111, 112, 116, 210, 139, 102, 202, 119, 164, 141, 100, 222, 101, 111,
         112, 116, 210, 139, 102, 202, 119, 95, 117, 240, 111, 112, 116, 210, 139, 102, 202, 119, 95, 198, 135,
         187, 111, 112, 116, 210, 139, 102, 202, 119, 219, 217, 140, 120, 112, 132, 105, 111, 148, 152, 167,
         103, 112, 132, 105, 111, 172, 111, 120, 193, 98, 164, 105, 128, 99, 100, 99, 193, 98, 169, 203, 133,
         132, 133, 117, 185, 117, 112, 102, 146, 189, 227, 172, 193, 114, 99, 168, 118, 210, 130, 132, 136, 184,
         118, 95, 135, 175, 109, 112, 116, 115, 114, 99, 168, 118, 210, 130, 132, 136, 184, 118, 95, 135, 175,
         109, 112, 116, 95, 132, 190, 118, 139, 114, 99, 168, 118, 210, 130, 112, 198, 111, 99, 166, 95, 215,
         115, 187, 114, 99, 168, 118, 210, 130, 102, 101, 135, 117, 142, 114, 99, 168, 118, 210, 130, 117, 240,
         213, 95, 49, 172, 117, 160, 121, 196, 213, 95, 49, 227, 98, 193, 213, 95, 49, 234, 50, 99, 66, 193,
         213, 95, 49, 234, 50, 99, 95, 182, 100, 142, 115, 115, 105, 50, 99, 49, 133, 117, 185, 117, 112, 105,
         50, 99, 49, 148, 202, 170, 115, 196, 225, 107, 104, 122, 105, 50, 99, 50, 133, 117, 185, 117, 112, 105,
         50, 99, 50, 148, 202, 170, 115, 196, 225, 107, 104, 122, 105, 50, 99, 51, 133, 117, 185, 117, 112, 105,
         50, 99, 51, 148, 202, 170, 115, 196, 225, 107, 104, 122, 109, 99, 111, 50, 95, 152, 133, 99, 57, 115,
         196, 107, 116, 114, 117, 109, 227, 133, 198, 111, 99, 166, 115, 196, 107, 116, 114, 117, 109, 227, 169,
         102, 103, 234, 100, 115, 196, 107, 116, 114, 117, 109, 227, 95, 110, 117, 109, 148, 104, 154, 110, 101,
         108, 115, 250, 112, 142, 115, 115, 108, 114, 159, 117, 105, 100, 250, 112, 142, 115, 115, 108, 197,
         137, 111, 150, 132, 250, 112, 142, 115, 115, 108, 114, 159, 239, 168, 108, 234, 100, 115, 157, 220,
         117, 108, 131, 95, 142, 146, 120, 165, 120, 115, 157, 220, 117, 108, 131, 95, 142, 146, 120, 95, 129,
         100, 115, 157, 220, 117, 108, 131, 184, 98, 117, 103, 153, 97, 115, 107, 99, 112, 117, 155, 135, 130,
         108, 192, 133, 131, 109, 105, 108, 143, 115, 131, 105, 139, 109, 115, 140, 104, 139, 102, 100, 117,
         112, 143, 120, 109, 115, 140, 49, 95, 117, 240, 109, 115, 140, 49, 172, 209, 100, 109, 115, 140, 50,
         95, 117, 240, 109, 115, 140, 50, 172, 209, 100, 109, 115, 140, 51, 95, 117, 240, 109, 115, 140, 51,
         172, 209, 100, 116, 144, 101, 122, 152, 130, 223, 115, 158, 169, 132, 117, 175, 115, 114, 112, 247,
         167, 108, 190, 164, 201, 152, 210, 115, 114, 112, 247, 167, 108, 190, 95, 119, 101, 105, 103, 104, 116,
         115, 114, 112, 247, 167, 108, 190, 95, 113, 114, 112, 247, 167, 108, 190, 169, 132, 238, 114, 112, 247,
         167, 108, 190, 219, 182, 130, 114, 235, 130, 104, 122, 114, 112, 247, 167, 108, 190, 248, 238, 102,
         108, 121, 115, 107, 121, 227, 153, 120, 234, 100, 102, 108, 121, 115, 107, 121, 227, 165, 102, 148,
         104, 154, 110, 101, 108, 115, 160, 135, 159, 109, 132, 95, 201, 225, 116, 144, 130, 115, 160, 135, 115,
         153, 161, 139, 219, 217, 103, 104, 116, 115, 160, 135, 115, 153, 161, 139, 153, 144, 130, 115, 160,
         135, 115, 153, 161, 139, 162, 116, 169, 160, 135, 115, 145, 97, 118, 130, 239, 118, 130, 108, 192, 160,
         135, 159, 150, 104, 95, 193, 220, 99, 174, 102, 116, 95, 255, 101, 178, 108, 161, 95, 255, 101, 139,
         116, 136, 117, 100, 130, 115, 111, 232, 99, 101, 139, 116, 136, 117, 100, 130, 112, 142, 102, 131, 172,
         97, 138, 139, 116, 136, 117, 100, 130, 108, 226, 114, 235, 101, 102, 132, 100, 131, 95, 177, 165, 235,
         130, 99, 109, 139, 116, 136, 117, 100, 130, 128, 108, 226, 163, 146, 110, 100, 179, 233, 116, 136, 117,
         100, 130, 109, 163, 104, 111, 215, 153, 104, 246, 143, 163, 221, 246, 156, 109, 132, 163, 221, 246,
         156, 177, 163, 139, 116, 136, 117, 100, 130, 112, 163, 139, 116, 136, 117, 100, 130, 105, 163, 139,
         116, 136, 117, 100, 130, 100, 163, 139, 116, 136, 117, 100, 130, 97, 163, 139, 116, 136, 117, 100, 130,
         102, 97, 112, 149, 136, 187, 133, 97, 112, 149, 136, 187, 234, 97, 112, 149, 136, 187, 137, 97, 112,
         149, 136, 187, 95, 97, 97, 112, 149, 136, 187, 219, 97, 112, 149, 136, 187, 148, 249, 223, 163, 160,
         111, 140, 221, 142, 189, 166, 100, 163, 177, 95, 235, 143, 163, 177, 95, 188, 252, 163, 188, 133, 163,
         118, 101, 202, 99, 136, 121, 137, 174, 103, 148, 111, 101, 102, 102, 163, 177, 95, 118, 101, 202, 99,
         136, 121, 163, 119, 97, 121, 112, 111, 132, 116, 95, 141, 245, 118, 139, 165, 182, 105, 193, 163, 119,
         97, 121, 112, 111, 132, 116, 164, 166, 128, 174, 100, 105, 193, 163, 160, 105, 170, 184, 182, 98, 154,
         100, 163, 221, 246, 156, 168, 182, 98, 154, 100, 163, 188, 169, 111, 168, 163, 109, 132, 219, 151, 222,
         128, 118, 101, 202, 99, 136, 121, 163, 200, 118, 148, 151, 110, 131, 145, 196, 220, 163, 200, 118, 148,
         151, 110, 131, 184, 108, 116, 97, 95, 118, 163, 200, 118, 184, 99, 101, 108, 163, 200, 118, 95, 191,
         99, 101, 108, 163, 200, 118, 148, 141, 198, 95, 143, 97, 128, 116, 144, 101, 163, 200, 118, 148, 141,
         198, 95, 143, 97, 128, 177, 163, 200, 118, 133, 142, 116, 232, 110, 162, 116, 163, 118, 101, 202, 99,
         136, 121, 172, 117, 105, 108, 100, 117, 140, 177, 133, 211, 163, 177, 153, 232, 110, 252, 163, 104,
         166, 128, 151, 98, 136, 165, 182, 105, 193, 163, 104, 166, 128, 167, 103, 117, 142, 56, 95, 119, 105,
         100, 221, 163, 146, 110, 100, 179, 184, 203, 176, 116, 252, 163, 146, 110, 100, 179, 137, 158, 101, 99,
         116, 187, 153, 144, 101, 163, 146, 110, 100, 179, 227, 114, 139, 95, 176, 171, 143, 163, 146, 110, 100,
         179, 227, 114, 139, 165, 182, 105, 193, 163, 146, 110, 100, 179, 227, 114, 139, 252, 163, 146, 110,
         100, 179, 95, 118, 101, 202, 99, 136, 121, 153, 104, 142, 189, 166, 100, 163, 146, 110, 100, 179, 153,
         104, 246, 156, 221, 142, 189, 166, 100, 163, 108, 49, 95, 176, 171, 143, 163, 108, 49, 133, 131, 105,
         111, 100, 163, 108, 49, 169, 132, 155, 111, 111, 107, 97, 104, 101, 182, 163, 108, 49, 95, 177, 155,
         111, 111, 107, 97, 104, 101, 182, 163, 108, 49, 95, 177, 148, 114, 129, 115, 153, 174, 170, 95, 131,
         138, 114, 163, 108, 49, 153, 232, 110, 252, 163, 109, 132, 95, 200, 118, 233, 116, 136, 117, 100, 130,
         109, 163, 114, 120, 155, 129, 115, 133, 166, 210, 121, 163, 177, 162, 116, 154, 99, 130, 102, 138, 109,
         164, 111, 109, 101, 163, 103, 101, 214, 176, 99, 130, 191, 116, 187, 216, 95, 193, 131, 95, 49, 95,
         255, 101, 216, 95, 193, 131, 95, 50, 95, 255, 101, 216, 95, 193, 131, 95, 51, 95, 255, 101, 216, 95,
         193, 131, 95, 52, 95, 255, 101, 254, 95, 251, 165, 99, 218, 224, 254, 133, 211, 165, 99, 153, 104, 114,
         218, 224, 254, 133, 211, 165, 99, 155, 111, 119, 218, 224, 254, 133, 211, 165, 99, 164, 105, 103, 104,
         218, 224, 254, 95, 188, 165, 99, 218, 224, 254, 95, 251, 218, 224, 254, 95, 251, 95, 223, 115, 158,
         254, 95, 251, 155, 192, 254, 133, 211, 218, 224, 254, 133, 211, 95, 223, 115, 158, 254, 133, 211, 155,
         111, 119, 155, 192, 254, 133, 211, 164, 105, 103, 104, 155, 192, 254, 95, 188, 218, 224, 254, 95, 188,
         95, 223, 115, 158, 254, 95, 188, 155, 192, 254, 145, 116, 171, 105, 108, 147, 135, 187, 254, 145, 176,
         115, 136, 105, 118, 136, 121, 254, 95, 117, 240, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
   begin
      return Codes (I);
   end Name_Code;

   Token_Text_Length : constant := 367;
   Max_Token_Length  : constant := 19;
   Token_Text : constant String (1 .. Token_Text_Length + Max_Token_Length) :=
     "d_ose_erin_posd_atit_droalp_arreleim_slais_cmaoron_tan_lle_chetstot_disap__h_rolfide_mckab_bgprateenmaxpiin"
     & "g_disabawadbo_deionyawshteracimitusbatgps_persrotnaarmloscteletelemtelemettelemetrtelemetryauicitchgygyroof"
     & "verboxli_g_fedthwaroffained_pf_spiled_blablackblackboxur_al_ianglaye_pos_hzmoartimbtelemetry_disabtelemetry"
     & "_disabled_unrott_lpfutexroll_rategimbgimbalnam                   ";

   subtype Token_Code is Interfaces.Unsigned_8 range 128 .. 255;
   type Token_Start is range 0 .. Token_Text_Length;
   type Token_Length is range 2 .. Max_Token_Length;

   Token_Starts : constant array (Token_Code) of Token_Start :=
     (0, 2, 4, 6, 8, 10, 12, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 10, 44, 46, 48, 50, 52, 54,
      56, 59, 61, 41, 63, 65, 67, 71, 74, 76, 78, 80, 82, 84, 86, 88, 90, 92, 94, 96, 98, 100, 103, 105, 108,
      114, 116, 118, 120, 55, 11, 123, 126, 129, 131, 134, 136, 140, 142, 145, 149, 151, 153, 95, 156, 158, 161,
      163, 165, 169, 174, 181, 189, 198, 200, 202, 206, 208, 212, 214, 217, 220, 222, 224, 226, 228, 230, 233,
      236, 239, 242, 244, 248, 252, 255, 260, 268, 270, 273, 275, 278, 281, 286, 289, 291, 294, 297, 312, 331,
      7, 333, 35, 337, 341, 343, 345, 349, 354, 358, 364);

   Token_Lengths : constant array (Token_Code) of Token_Length :=
     (2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 4,
      3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 3, 6, 2, 2, 2, 3, 2, 3, 3, 3, 2, 3, 2, 4, 2, 3, 4, 2, 2,
      3, 3, 2, 3, 2, 2, 4, 5, 7, 8, 9, 2, 2, 4, 2, 4, 2, 3, 3, 2, 2, 2, 2, 2, 3, 3, 3, 3, 2, 4, 4, 3, 5, 8, 2,
      3, 2, 3, 3, 5, 3, 2, 3, 3, 15, 19, 2, 2, 4, 2, 4, 2, 2, 4, 5, 4, 6, 3);

   type Name_Start is range 0 .. Name_Codes_Length;
   type Name_Length is range 1 .. Max_Name_Length;

   Name_Starts : constant array (Setting) of Name_Start :=
     (0, 8, 14, 22, 28, 36, 43, 52, 59, 68, 77, 89, 96, 108, 118, 128, 139, 148, 158, 168, 177, 186, 196, 209,
      216, 220, 227, 234, 243, 250, 258, 266, 274, 281, 290, 301, 308, 315, 324, 332, 340, 350, 362, 370, 377,
      385, 395, 407, 415, 420, 426, 431, 440, 453, 460, 467, 474, 491, 499, 506, 521, 540, 556, 570, 585, 596,
      607, 619, 630, 642, 660, 670, 681, 691, 707, 724, 732, 740, 754, 759, 776, 792, 800, 805, 814, 820, 835,
      854, 874, 885, 893, 898, 904, 909, 918, 922, 927, 932, 938, 942, 950, 955, 963, 970, 977, 984, 990, 995,
      1001, 1005, 1016, 1020, 1024, 1029, 1037, 1043, 1049, 1055, 1063, 1069, 1076, 1086, 1097, 1108, 1115,
      1125, 1132, 1146, 1156, 1164, 1174, 1189, 1200, 1214, 1229, 1243, 1258, 1275, 1284, 1294, 1303, 1307,
      1316, 1323, 1337, 1352, 1366, 1382, 1392, 1406, 1415, 1423, 1429, 1446, 1454, 1462, 1472, 1483, 1494,
      1502, 1514, 1527, 1533, 1541, 1551, 1558, 1565, 1572, 1579, 1588, 1598, 1606, 1618, 1633, 1642, 1649,
      1663, 1671, 1683, 1688, 1694, 1700, 1706, 1716, 1725, 1736, 1743, 1753, 1760, 1768, 1776, 1788, 1796,
      1809, 1819, 1832, 1840, 1845, 1851, 1856, 1862, 1875, 1879, 1884, 1888, 1893, 1899, 1904, 1908, 1913,
      1917, 1925, 1935, 1941, 1948, 1954, 1962, 1977, 1984, 1991, 1998, 2010, 2018, 2025, 2036, 2045, 2053,
      2061, 2069, 2076, 2091, 2105, 2116, 2130, 2143, 2154, 2170, 2178, 2190, 2207, 2210, 2214, 2226, 2236,
      2248, 2259, 2270, 2282, 2293, 2304, 2318, 2328, 2348, 2355, 2366, 2377, 2392, 2408, 2413, 2419, 2430,
      2439, 2449, 2458, 2470, 2490, 2507, 2519, 2535, 2554, 2579, 2585, 2596, 2607, 2619, 2627, 2637, 2645,
      2655, 2662, 2671, 2684, 2693, 2703, 2715, 2726, 2732, 2736, 2745, 2754, 2769, 2775, 2780, 2792, 2802,
      2809, 2818, 2824, 2830, 2839, 2848, 2856, 2863, 2872, 2882, 2888, 2897, 2908, 2925, 2939, 2947, 2950,
      2953, 2956, 2959, 2961, 2964, 2966, 2969, 2971, 2974, 2976, 2979, 2984, 2993, 3009, 3013, 3021, 3037,
      3049, 3061, 3075, 3084, 3094, 3105, 3118, 3132, 3145, 3163, 3181, 3194, 3201, 3205, 3209, 3213, 3217,
      3225, 3235, 3249, 3260, 3275, 3292, 3300, 3310, 3318, 3331, 3343, 3358, 3372, 3382, 3395, 3408, 3422,
      3433, 3442, 3451, 3460, 3474, 3483, 3494, 3511, 3520, 3529, 3538, 3548, 3563, 3575, 3587, 3599, 3619,
      3630, 3649, 3655, 3659, 3670, 3677, 3691, 3702, 3715, 3724, 3734, 3746, 3753, 3764, 3772, 3778, 3784,
      3792, 3798, 3804, 3812, 3818, 3824, 3833, 3844, 3856, 3866, 3873, 3887, 3895, 3901, 3915, 3922, 3942,
      3955, 3970, 3981, 3988, 3999, 4010, 4021, 4028, 4034, 4039, 4042, 4047, 4052, 4057, 4060, 4062, 4067,
      4073, 4078, 4084, 4092, 4099, 4107, 4117, 4123, 4134, 4142, 4147, 4161, 4178, 4189, 4198, 4209, 4221,
      4237, 4251, 4266, 4280, 4293, 4305, 4319, 4330, 4345, 4352, 4356, 4364, 4370, 4382, 4391, 4397, 4402,
      4407, 4416, 4425, 4433, 4443, 4452, 4459, 4467, 4474, 4483, 4496, 4503, 4513, 4523, 4527, 4531, 4535,
      4540, 4551, 4562, 4570, 4575, 4581, 4587, 4600, 4607, 4617, 4623, 4628, 4639, 4648, 4655, 4659, 4666,
      4674, 4682, 4691, 4699, 4706, 4713, 4719, 4725, 4733, 4741, 4750, 4757, 4766, 4775, 4784, 4795, 4802,
      4807, 4813, 4818, 4824, 4831, 4837, 4848, 4854, 4868, 4874, 4880, 4889, 4895, 4902, 4916, 4924, 4933,
      4940, 4947, 4954, 4964, 4974, 4985, 4993, 5001, 5009, 5022, 5036, 5051, 5061, 5070, 5080, 5087, 5097,
      5107, 5117, 5128, 5132, 5147, 5161, 5170, 5177, 5186, 5193, 5206, 5217, 5226, 5238, 5248, 5256, 5261,
      5270, 5279, 5288, 5302, 5314, 5317, 5326, 5340, 5356, 5371, 5380, 5391, 5400, 5407, 5415, 5426, 5433,
      5447, 5466, 5478, 5490, 5499, 5510, 5521, 5532, 5540, 5550, 5563, 5569, 5576, 5584, 5594, 5607, 5613,
      5624, 5635, 5642, 5650, 5659, 5670, 5679, 5685, 5694, 5701, 5713, 5725, 5731, 5737, 5743, 5755, 5766,
      5772, 5784, 5792, 5800, 5808, 5816, 5829, 5846, 5863, 5877, 5897, 5917, 5938, 5954, 5970, 5987, 6001,
      6016, 6025, 6037, 6046, 6055, 6069, 6081, 6094, 6110, 6115, 6126, 6139, 6151, 6161, 6174, 6185, 6197,
      6209, 6217, 6224, 6232, 6243, 6249, 6266, 6287, 6302, 6313, 6321, 6329, 6335, 6343, 6355, 6364, 6377,
      6386, 6399, 6408, 6421, 6430, 6443, 6456, 6475, 6486, 6497, 6510, 6522, 6535, 6549, 6563, 6578, 6585,
      6592, 6599, 6606, 6613, 6620, 6634, 6645, 6659, 6667, 6676, 6690, 6698, 6709, 6725, 6737, 6749, 6759,
      6768, 6780, 6788, 6795, 6801, 6812, 6825, 6833, 6847, 6856, 6868, 6876, 6882, 6887, 6895, 6903, 6911,
      6919, 6927, 6933, 6939, 6945, 6952, 6958, 6966, 6975, 6980, 6985, 6988, 7003, 7012, 7029, 7044, 7053,
      7062, 7067, 7080, 7090, 7103, 7110, 7118, 7131, 7142, 7152, 7169, 7175, 7186, 7200, 7210, 7224, 7236,
      7248, 7257, 7275, 7289, 7296, 7304, 7317, 7330, 7346, 7353, 7366, 7376, 7390, 7400, 7409, 7418, 7427,
      7436, 7443, 7453, 7463, 7474, 7481, 7486, 7493, 7498, 7503, 7510, 7518, 7527, 7532, 7539, 7544, 7553, 7562);

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
      Length : constant Natural := Natural (Name_Lengths (S));
      First  : constant Natural := Natural (Name_Starts (S));
      Result : String (1 .. Length) := (others => ' ');
      Done   : Natural := 0;
      Next   : Natural := First;
   begin
      while Done < Length loop
         pragma Loop_Invariant (Next <= First + Done);
         pragma Loop_Variant (Increases => Done);
         declare
            Code   : constant Interfaces.Unsigned_8 := Name_Code (Next);
            Before : constant Natural := Done;
         begin
            Next := Next + 1;
            if Code in Token_Code then
               for K in 0 .. Natural (Token_Lengths (Code)) - 1 loop
                  pragma Loop_Invariant (Done = Before + K and then Done < Length);
                  Result (Done + 1) := Token_Text (Natural (Token_Starts (Code)) + K + 1);
                  Done := Done + 1;
                  exit when Done = Length;
               end loop;
            else
               Result (Done + 1) := Character'Val (Code);
               Done := Done + 1;
            end if;
            pragma Assert (Done > Before);
         end;
      end loop;
      return Result;
   end Name;

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
