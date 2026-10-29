package body Adaflight.Settings_Table with SPARK_Mode is

   --  Each setting's limits and group as indexes into the tables of the distinct ones, so the info
   --  of every setting packs into a few bytes of flash.
   type Limit_Pair is record
      Min : Limit;
      Max : Limit;
   end record with Pack;

   type Limit_Index is range 0 .. 156;
   type Group_Index is range 0 .. 81;

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
      (Min => 0, Max => 41), (Min => 0, Max => 50), (Min => 0, Max => 60), (Min => 0, Max => 70),
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
      (Min => 10, Max => 255), (Min => 10, Max => 500), (Min => 10, Max => 1000), (Min => 10, Max => 2000),
      (Min => 10, Max => 5000), (Min => 20, Max => 100), (Min => 20, Max => 250), (Min => 20, Max => 1000),
      (Min => 20, Max => 5000), (Min => 25, Max => 100), (Min => 25, Max => 255), (Min => 25, Max => 500),
      (Min => 30, Max => 200), (Min => 48, Max => 126), (Min => 50, Max => 255), (Min => 50, Max => 498),
      (Min => 50, Max => 1000), (Min => 50, Max => 2000), (Min => 50, Max => 2500), (Min => 50, Max => 3000),
      (Min => 50, Max => 10000), (Min => 100, Max => 500), (Min => 100, Max => 1000), (Min => 100, Max => 1300),
      (Min => 100, Max => 2000), (Min => 100, Max => 4000), (Min => 100, Max => 5000), (Min => 200, Max => 400),
      (Min => 200, Max => 1000), (Min => 200, Max => 1998), (Min => 200, Max => 32000), (Min => 250, Max => 3000),
      (Min => 300, Max => 5000), (Min => 500, Max => 1950), (Min => 500, Max => 5000), (Min => 500, Max => 10000),
      (Min => 600, Max => 6000), (Min => 750, Max => 1500), (Min => 750, Max => 2250), (Min => 1000, Max => 2000),
      (Min => 1000, Max => 50000), (Min => 1050, Max => 1400), (Min => 1200, Max => 1700), (Min => 1400, Max => 2000),
      (Min => 1500, Max => 2250));

   Group_Numbers : constant array (Group_Index) of Group_Number :=
     (1, 2, 3, 5, 6, 10, 11, 12, 13, 14, 16, 17, 18, 20, 22, 24, 25, 26, 27, 30, 31, 35, 38, 39, 40, 47, 52, 55, 56,
      57, 58, 59, 60, 61, 256, 257, 258, 259, 501, 502, 503, 504, 505, 506, 508, 510, 511, 512, 513, 514, 515, 517,
      518, 519, 522, 523, 524, 525, 526, 527, 529, 530, 531, 537, 539, 540, 541, 542, 544, 547, 553, 554, 555, 556,
      557, 559, 560, 561, 568, 569, 2044, 2045);

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
        (Kind => U16, Where => Master, How => Direct, Limits => 131, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 145, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5),
      Dyn_Notch_Count =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 71),
      Dyn_Notch_Q =>
        (Kind => U16, Where => Master, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71),
      Dyn_Notch_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 118, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71),
      Dyn_Notch_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 140, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71),
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
         => 0, Write_Once => False, Group => 79),
      Pitot_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 79),
      Pitot_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 48, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 79),
      Pitot_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Pitot_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 79),
      Mid_Rc =>
        (Kind => U16, Where => Master, How => Direct, Limits => 154, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Min_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Max_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15),
      Rx_Max_Usec =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
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
         0, Write_Once => False, Group => 63),
      Rx_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 63),
      Rx_Spi_Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 63),
      Adc_Device =>
        (Kind => I8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4),
      Min_Command =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 142, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
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
         Min_Length => 1, Write_Once => False, Group => 77),
      Bat_Capacity =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77),
      Vbat_Max_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77),
      Vbat_Full_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77),
      Vbat_Min_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77),
      Vbat_Warning_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77),
      Cbat_Alert_Percent =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77),
      Force_Battery_Cell_Count =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 36, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77),
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
        (Kind => U16, Where => Master, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Deadband_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Neutral =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Deadband_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Limit_Low =>
        (Kind => U16, Where => Master, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Limit_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17),
      Three_D_Switched_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 17),
      Servo_Center_Pulse =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26),
      Servo_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 127, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 121, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Roll_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Pitch_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Yaw_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7),
      Reboot_Character =>
        (Kind => U8, Where => Master, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 8),
      Serial_Update_Rate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 136, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 130, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 123, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 33),
      Pid_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41),
      Runaway_Takeoff_Prevention =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41),
      Runaway_Takeoff_Deactivate_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Gthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 136, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Setpoint_Threshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 129, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Time =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 138, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Crash_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Crash_Recovery_Angle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 101, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Crash_Recovery_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 126, Table => Table_Off_On, Count => 0, Min_Length
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
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 117, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Pidsum_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Pidsum_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0,
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
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 122, Table => Table_Off_On, Count => 0, Min_Length
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
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0,
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
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 151, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9),
      Tpa_Low_Rate =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9),
      Tpa_Low_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 151, Table => Table_Off_On, Count => 0,
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
        (Kind => U16, Where => Master, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0, Min_Length =>
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
      Sdcard_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 46),
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
         0, Write_Once => False, Group => 81),
      Osd_Rssi_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Link_Quality_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Link_Tx_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Rssi_Dbm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Rsnr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Tim_1_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Tim_2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Remaining_Time_Estimate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Flymode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Anti_Gravity_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_G_Force_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Throttle_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Vtx_Channel_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Crosshairs_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Ah_Sbar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Ah_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Current_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Mah_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wh_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Motor_Diag_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Craft_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pilot_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Gps_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Gps_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Gps_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Gps_Lap_Curr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Gps_Lap_Prev_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Gps_Lap_Best3_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Gps_Sats_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Home_Dir_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Home_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Flight_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Compass_Bar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Altitude_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pid_Roll_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pid_Pitch_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pid_Yaw_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Debug_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Debug2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pidrate_Profile_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Avg_Cell_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pit_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Rol_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Battery_Usage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Disarmed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Nheading_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Up_Down_Reference_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Ready_Mode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pos_Hold_Ready_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Nvario_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Esc_Tmp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Esc_Rpm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Esc_Rpm_Freq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Rtc_Date_Time_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Adjustment_Range_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Flip_Arrow_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Core_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Log_Status_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Stick_Overlay_Left_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Stick_Overlay_Right_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Stick_Overlay_Radio_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38),
      Osd_Rate_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Pid_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Battery_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Rcchannels_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Camera_Frame_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Efficiency_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Total_Flights_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Aux_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Goggle_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Vtx_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Bitrate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Delay_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Lq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Goggle_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Vtx_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Vtx_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Sys_Fan_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
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
         0, Write_Once => False, Group => 81),
      Osd_Custom_Serial_Text_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Custom_Serial_Text_Terminator =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Osd_Custom_Text_Terminator, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 80),
      Osd_Custom_Text_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 38),
      Osd_Custom_Text_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38),
      Osd_Wp_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wp_Current_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wp_Current_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wp_Current_Alt_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wp_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wp_Direction_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wp_Next_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Wp_Eta_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Nav_Map_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
      Osd_Nav_Map_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 78),
      Osd_Nav_Map_Centre =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 78),
      Osd_Nav_Map_Min_Scale_M =>
        (Kind => U16, Where => Master, How => Direct, Limits => 120, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 78),
      Osd_Airspeed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 81),
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
         Min_Length => 0, Write_Once => False, Group => 56),
      Max7456_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 56),
      Max7456_Preinit_Opu =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 56),
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
         Write_Once => False, Group => 55),
      Frsky_Spi_Tx_Id =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 55),
      Frsky_Spi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 13, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 55),
      Frsky_Spi_Bind_Hop_Data =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 50, Min_Length => 0,
         Write_Once => False, Group => 55),
      Frsky_X_Rx_Num =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 55),
      Frsky_Spi_A1_Source =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Rx_Frsky_Spi_A1_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55),
      Cc2500_Spi_Chip_Detect =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 55),
      Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 42),
      Dashboard_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 53),
      Dashboard_I2c_Addr =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 106, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 53),
      Camera_Control_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Camera_Control_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 54),
      Camera_Control_Ref_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54),
      Camera_Control_Key_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54),
      Camera_Control_Internal_Resistance =>
        (Kind => U16, Where => Master, How => Direct, Limits => 114, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54),
      Camera_Control_Button_Resistance =>
        (Kind => U16, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 5, Min_Length => 0,
         Write_Once => False, Group => 54),
      Camera_Control_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 54),
      Rangefinder_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Rangefinder_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 59),
      Rangefinder_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 59),
      Opticalflow_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Opticalflow_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76),
      Opticalflow_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 76),
      Opticalflow_Rotation =>
        (Kind => I16, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 76),
      Opticalflow_Flip_X =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 76),
      Pinio_Config =>
        (Kind => U8, Where => Hardware, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 60),
      Pinio_Box =>
        (Kind => U8, Where => Hardware, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 61),
      Usb_Hid_Cdc =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 62),
      Usb_Msc_Pin_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 62),
      Flash_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 43),
      Rcdevice_Init_Dev_Attempts =>
        (Kind => U8, Where => Master, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 64),
      Rcdevice_Init_Dev_Attempt_Interval =>
        (Kind => U32, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64),
      Rcdevice_Protocol_Version =>
        (Kind => U8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 64),
      Rcdevice_Feature =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64),
      Rcdevice_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 64),
      Gyro_1_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 65),
      Gyro_1_Spibus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65),
      Gyro_1_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65),
      Gyro_1_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 48, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65),
      I2c1_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52),
      I2c1_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52),
      I2c2_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52),
      I2c2_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52),
      I2c3_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52),
      I2c3_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52),
      Mco2_On_Pc9 =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 66),
      Spektrum_Spi_Protocol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 67),
      Spektrum_Spi_Mfg_Id =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 67),
      Spektrum_Spi_Num_Channels =>
        (Kind => U8, Where => Master, How => Direct, Limits => 31, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 67),
      Expresslrs_Uid =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 6, Min_Length => 0,
         Write_Once => False, Group => 72),
      Expresslrs_Domain =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Freq_Domain, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 72),
      Expresslrs_Model_Id =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 72),
      Scheduler_Relax_Rx =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73),
      Scheduler_Relax_Osd =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73),
      Scheduler_Debug_Task =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 39, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73),
      Cpu_Late_Limit_Permille =>
        (Kind => U8, Where => Master, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 73),
      Serialmsp_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74),
      Msp_1_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 74),
      Msp_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 74),
      Msp_2_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 74),
      Msp_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 74),
      Msp_3_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 74),
      Msp_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 24, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 74),
      Timezone_Offset_Minutes =>
        (Kind => I16, Where => Master, How => Direct, Limits => 8, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 58),
      Rpm_Filter_Harmonics =>
        (Kind => U8, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 68),
      Rpm_Filter_Weights =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 68),
      Rpm_Filter_Q =>
        (Kind => U16, Where => Master, How => Direct, Limits => 143, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Rpm_Filter_Min_Hz =>
        (Kind => U8, Where => Master, How => Direct, Limits => 124, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Rpm_Filter_Fade_Range_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Rpm_Filter_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68),
      Flysky_Spi_Tx_Id =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 57),
      Flysky_Spi_Rf_Channels =>
        (Kind => U8, Where => Master, How => List, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length => 0,
         Write_Once => False, Group => 57),
      Stats_Min_Armed_Time_S =>
        (Kind => I8, Where => Master, How => Direct, Limits => 22, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 69),
      Stats_Total_Flights =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69),
      Stats_Total_Time_S =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69),
      Stats_Total_Dist_M =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69),
      Stats_Save_Move_Limit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 69),
      Stats_Mah_Used =>
        (Kind => U32, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69),
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
        (Kind => U16, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28),
      Rangefinder_Max_Range_Cm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28),
      Altitude_D_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28),
      Ap_Landing_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Hover_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Throttle_Min =>
        (Kind => U16, Where => Master, How => Direct, Limits => 153, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Throttle_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 155, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 138, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Waypoint_Arrival_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 138, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Waypoint_Hold_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 129, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Corner_Delta_V =>
        (Kind => U16, Where => Master, How => Direct, Limits => 137, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Decel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 119, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Accel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 119, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Carrot_Lead_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 97, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Nav_Carrot_Lead_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Nav_Preturn_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 146, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Velocity_Buildup_Max_Pitch =>
        (Kind => U8, Where => Master, How => Direct, Limits => 35, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Max_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 84, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32),
      Ap_Hold_Orbit_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_Hold_Figure8_Width =>
        (Kind => U16, Where => Master, How => Direct, Limits => 147, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 129, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 138, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_L1_Max_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Limits => 152, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32),
      Ap_L1_Max_Cross_Track_Error =>
        (Kind => U16, Where => Master, How => Direct, Limits => 152, Table => Table_Off_On, Count => 0, Min_Length =>
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
         1, Write_Once => False, Group => 70),
      Box_User_2_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 70),
      Box_User_3_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 70),
      Box_User_4_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 24, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 70),
      Gimbal_Roll_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Pitch_Rc_Thr_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Pitch_Rc_Low_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Pitch_Rc_High_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Yaw_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Roll_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Roll_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Roll_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Pitch_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Pitch_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Pitch_Low_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Pitch_High_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Yaw_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Yaw_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Yaw_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Stabilisation =>
        (Kind => I8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Sensitivity =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75),
      Gimbal_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 75));

   function Describe (S : Setting) return Info is
     (Kind => Infos (S).Kind, Where => Infos (S).Where, How => Infos (S).How,
      Min => Limit_Pairs (Infos (S).Limits).Min, Max => Limit_Pairs (Infos (S).Limits).Max,
      Table => Infos (S).Table, Count => Infos (S).Count, Min_Length => Infos (S).Min_Length,
      Write_Once => Infos (S).Write_Once, Group => Group_Numbers (Infos (S).Group));

   --  The setting names in codes: a code below 128 is a character, a higher one the token of its
   --  pair merge. Each name starts at its start and decodes to its length, and the codes and the
   --  tokens end with room for a longest name and token, so every read stays within them by the
   --  types alone.
   Name_Codes_Length : constant := 7657;
   subtype Name_Code_Index is Natural range 0 .. Name_Codes_Length + Max_Name_Length - 1;

   --  The code at an index, outside the proof: the decoder needs no fact about the codes.
   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8;

   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8 with SPARK_Mode => Off is
      Codes : constant array (Name_Code_Index) of Interfaces.Unsigned_8 :=
        (214, 161, 141, 100, 222, 130, 108, 229, 214, 252, 49, 154, 121, 194, 214, 252, 49, 145, 116, 135, 177,
         230, 214, 252, 50, 154, 121, 194, 214, 252, 50, 145, 116, 135, 177, 230, 214, 215, 163, 158, 49, 230,
         214, 215, 163, 158, 49, 146, 117, 116, 223, 214, 215, 163, 158, 50, 230, 214, 215, 163, 158, 50, 146,
         117, 116, 223, 214, 146, 139, 105, 98, 138, 117, 114, 135, 189, 214, 146, 139, 105, 98, 215, 111, 148,
         130, 108, 192, 214, 95, 223, 115, 159, 95, 190, 214, 95, 111, 209, 102, 108, 210, 138, 159, 101, 99,
         116, 190, 145, 112, 132, 95, 142, 99, 111, 209, 121, 190, 145, 112, 132, 154, 104, 185, 104, 165, 100,
         100, 121, 110, 215, 163, 158, 146, 111, 117, 110, 116, 100, 121, 110, 215, 163, 158, 95, 113, 100, 121,
         110, 215, 163, 158, 151, 132, 230, 100, 121, 110, 215, 163, 158, 151, 225, 230, 214, 252, 49, 138, 121,
         110, 151, 132, 230, 214, 252, 49, 138, 121, 110, 151, 225, 230, 214, 252, 49, 138, 121, 110, 95, 253,
         112, 111, 214, 95, 168, 108, 186, 219, 98, 117, 103, 95, 225, 148, 156, 99, 161, 141, 100, 222, 101,
         156, 99, 252, 230, 156, 99, 154, 114, 144, 133, 211, 156, 99, 154, 114, 144, 95, 254, 156, 99, 146,
         139, 105, 98, 114, 135, 189, 139, 231, 110, 151, 248, 167, 103, 238, 231, 110, 95, 254, 167, 103, 238,
         231, 110, 133, 211, 167, 103, 238, 231, 110, 95, 190, 167, 103, 166, 117, 160, 121, 194, 167, 103, 95,
         105, 50, 99, 219, 118, 177, 101, 167, 103, 95, 105, 50, 99, 95, 183, 100, 185, 115, 167, 103, 232, 219,
         118, 177, 101, 167, 103, 161, 141, 100, 222, 101, 167, 103, 146, 139, 105, 98, 114, 135, 189, 98, 97,
         137, 166, 117, 160, 121, 194, 98, 97, 137, 232, 219, 118, 177, 101, 98, 97, 137, 95, 105, 50, 99, 219,
         118, 177, 101, 98, 97, 137, 95, 105, 50, 99, 95, 183, 100, 185, 115, 98, 97, 137, 161, 141, 100, 222,
         101, 98, 97, 137, 138, 114, 105, 102, 116, 112, 136, 163, 166, 117, 160, 121, 194, 112, 136, 163, 95,
         105, 50, 99, 219, 118, 177, 101, 112, 136, 163, 95, 105, 50, 99, 95, 183, 100, 185, 115, 112, 136, 163,
         161, 141, 100, 222, 101, 109, 105, 128, 249, 109, 132, 146, 104, 101, 99, 107, 239, 146, 104, 101, 99,
         107, 191, 115, 105, 146, 104, 147, 110, 174, 191, 115, 105, 145, 249, 212, 114, 179, 130, 131, 137,
         191, 191, 115, 105, 145, 99, 139, 101, 191, 115, 105, 95, 223, 115, 159, 191, 115, 105, 95, 132, 209,
         116, 191, 115, 105, 145, 249, 212, 114, 179, 130, 108, 229, 133, 131, 105, 111, 100, 191, 115, 105,
         145, 109, 111, 163, 104, 180, 249, 145, 109, 111, 163, 104, 180, 249, 145, 109, 111, 163, 104, 180, 95,
         187, 116, 111, 212, 156, 116, 153, 249, 145, 109, 111, 163, 104, 180, 95, 187, 116, 111, 212, 156, 116,
         153, 154, 104, 250, 143, 249, 145, 109, 111, 163, 104, 180, 145, 159, 112, 111, 132, 116, 146, 117,
         116, 223, 249, 145, 109, 111, 163, 104, 180, 154, 104, 250, 157, 226, 116, 223, 249, 145, 109, 111,
         163, 104, 180, 219, 98, 117, 103, 95, 225, 148, 102, 112, 118, 151, 105, 120, 219, 103, 142, 255, 239,
         95, 187, 120, 146, 104, 147, 110, 174, 115, 115, 131, 105, 139, 114, 120, 133, 137, 118, 233, 131, 115,
         131, 105, 139, 114, 120, 95, 132, 209, 173, 100, 115, 194, 107, 116, 114, 117, 109, 145, 135, 166, 132,
         100, 115, 194, 107, 116, 114, 117, 109, 145, 135, 166, 132, 128, 187, 116, 111, 185, 159, 115, 114,
         120, 108, 50, 181, 110, 136, 95, 233, 115, 114, 120, 108, 50, 166, 187, 128, 102, 97, 160, 115, 98,
         227, 166, 187, 128, 102, 97, 160, 99, 191, 102, 181, 115, 130, 110, 101, 103, 163, 105, 196, 128, 98,
         187, 100, 97, 105, 114, 109, 111, 100, 130, 160, 242, 154, 104, 250, 157, 112, 131, 99, 176, 116, 114,
         120, 151, 132, 181, 115, 101, 99, 114, 120, 151, 225, 181, 115, 101, 99, 115, 131, 105, 139, 114, 120,
         161, 139, 102, 100, 117, 112, 143, 120, 114, 120, 181, 242, 109, 115, 140, 111, 209, 114, 233, 130,
         158, 147, 110, 174, 115, 151, 217, 107, 109, 115, 140, 111, 209, 114, 233, 130, 102, 97, 105, 108, 115,
         97, 102, 101, 114, 120, 232, 133, 195, 111, 99, 165, 114, 120, 232, 166, 227, 114, 120, 232, 95, 234,
         132, 209, 115, 189, 183, 99, 219, 118, 177, 101, 183, 99, 243, 142, 102, 132, 116, 146, 139, 105, 98,
         114, 135, 189, 183, 99, 154, 101, 109, 170, 176, 115, 153, 146, 139, 105, 98, 114, 135, 189, 51, 48,
         183, 99, 154, 101, 109, 170, 176, 115, 153, 146, 139, 105, 98, 114, 135, 189, 49, 49, 48, 132, 112,
         117, 116, 95, 168, 108, 186, 180, 151, 244, 236, 145, 179, 112, 157, 114, 196, 236, 219, 118, 177, 101,
         236, 182, 157, 175, 100, 115, 236, 182, 157, 249, 236, 182, 157, 115, 159, 112, 111, 132, 116, 236,
         182, 157, 193, 236, 182, 157, 167, 103, 236, 182, 157, 139, 116, 236, 182, 157, 191, 115, 105, 236,
         182, 157, 214, 236, 182, 157, 214, 117, 110, 168, 108, 116, 236, 182, 157, 156, 99, 236, 182, 157, 135,
         116, 136, 117, 169, 236, 182, 157, 169, 98, 117, 103, 236, 182, 157, 109, 163, 153, 115, 236, 182, 157,
         115, 131, 118, 129, 236, 182, 157, 114, 112, 109, 236, 182, 157, 172, 236, 182, 157, 112, 136, 163,
         236, 151, 244, 236, 161, 231, 104, 95, 185, 165, 117, 116, 189, 236, 181, 242, 236, 166, 187, 100, 239,
         154, 104, 250, 143, 109, 132, 146, 111, 109, 109, 237, 109, 163, 153, 95, 107, 118, 109, 163, 153, 95,
         233, 143, 100, 115, 104, 163, 166, 117, 114, 160, 100, 115, 104, 163, 166, 233, 105, 114, 100, 115,
         104, 163, 95, 220, 116, 100, 115, 104, 163, 166, 136, 98, 240, 100, 115, 104, 163, 166, 136, 98, 240,
         154, 144, 131, 227, 130, 117, 110, 115, 121, 110, 99, 228, 112, 119, 109, 109, 163, 153, 133, 119, 109,
         133, 195, 111, 99, 165, 109, 163, 153, 133, 119, 109, 251, 109, 163, 153, 133, 119, 109, 95, 132, 209,
         115, 189, 109, 163, 153, 133, 111, 143, 115, 109, 163, 153, 95, 111, 117, 116, 112, 117, 116, 95, 142,
         153, 100, 131, 180, 221, 114, 146, 153, 114, 243, 139, 117, 101, 221, 114, 146, 153, 114, 95, 240, 143,
         102, 97, 105, 108, 115, 97, 102, 130, 169, 108, 207, 102, 97, 105, 108, 115, 97, 102, 130, 108, 237,
         180, 154, 144, 101, 102, 97, 105, 108, 115, 97, 102, 130, 221, 250, 143, 102, 97, 105, 108, 115, 97,
         102, 130, 115, 119, 211, 151, 244, 102, 97, 105, 108, 115, 97, 102, 130, 221, 250, 157, 108, 210, 138,
         174, 207, 102, 97, 105, 108, 115, 97, 102, 130, 112, 137, 99, 220, 117, 142, 102, 97, 105, 108, 115,
         97, 102, 130, 142, 99, 111, 209, 121, 138, 174, 207, 102, 97, 105, 108, 115, 97, 102, 130, 160, 177,
         107, 154, 104, 185, 104, 165, 100, 139, 231, 110, 166, 111, 141, 128, 254, 139, 231, 110, 166, 111,
         141, 128, 112, 211, 139, 231, 110, 166, 111, 141, 128, 190, 103, 245, 139, 151, 244, 193, 186, 121,
         133, 137, 168, 157, 110, 179, 101, 193, 146, 97, 112, 156, 136, 121, 118, 193, 151, 225, 146, 174, 108,
         243, 165, 116, 248, 101, 118, 193, 212, 117, 108, 108, 146, 174, 108, 243, 165, 116, 248, 101, 118,
         193, 151, 132, 146, 174, 108, 243, 165, 116, 248, 101, 118, 193, 95, 222, 110, 180, 146, 174, 108, 243,
         165, 116, 248, 101, 99, 193, 238, 131, 116, 133, 131, 99, 176, 116, 102, 153, 99, 130, 193, 186, 121,
         146, 174, 108, 146, 111, 117, 110, 116, 118, 193, 161, 121, 160, 131, 255, 148, 226, 114, 142, 110,
         116, 151, 159, 131, 193, 186, 121, 151, 159, 131, 118, 193, 138, 159, 101, 99, 116, 146, 174, 108, 243,
         165, 116, 248, 101, 227, 130, 118, 193, 238, 131, 116, 115, 227, 130, 99, 193, 238, 131, 116, 115, 118,
         193, 146, 117, 116, 223, 133, 131, 99, 176, 116, 118, 193, 164, 197, 207, 252, 133, 131, 105, 111, 100,
         118, 193, 145, 248, 252, 133, 131, 105, 111, 100, 105, 193, 252, 133, 131, 105, 111, 100, 118, 193,
         138, 117, 114, 135, 189, 212, 153, 95, 222, 110, 180, 118, 193, 138, 117, 114, 135, 189, 212, 153, 146,
         114, 136, 177, 139, 118, 193, 145, 99, 139, 101, 118, 193, 138, 105, 118, 233, 131, 118, 193, 151, 117,
         108, 116, 105, 197, 105, 131, 105, 193, 97, 145, 99, 139, 101, 105, 193, 97, 95, 223, 115, 159, 105,
         193, 118, 145, 99, 139, 101, 105, 193, 118, 95, 223, 115, 159, 193, 186, 121, 146, 149, 116, 132, 117,
         101, 98, 101, 101, 112, 131, 95, 132, 209, 115, 189, 98, 101, 101, 112, 131, 95, 111, 100, 98, 101,
         101, 112, 131, 212, 142, 113, 117, 176, 99, 121, 98, 101, 101, 112, 131, 138, 115, 104, 163, 166, 101,
         156, 149, 154, 149, 101, 190, 151, 163, 153, 115, 95, 142, 209, 115, 220, 109, 105, 120, 131, 154, 121,
         194, 99, 114, 217, 104, 102, 108, 105, 140, 109, 163, 153, 133, 131, 99, 176, 116, 99, 114, 217, 104,
         102, 108, 105, 140, 114, 196, 99, 114, 217, 104, 102, 108, 105, 140, 187, 116, 111, 95, 142, 198, 114,
         112, 109, 152, 192, 114, 112, 109, 152, 192, 133, 114, 112, 109, 152, 192, 95, 105, 114, 112, 109, 152,
         192, 138, 114, 112, 109, 152, 192, 243, 139, 117, 101, 51, 128, 169, 183, 98, 147, 128, 108, 210, 51,
         128, 169, 183, 98, 147, 128, 104, 231, 104, 51, 128, 110, 101, 117, 116, 114, 139, 51, 128, 169, 183,
         98, 147, 128, 221, 250, 143, 51, 128, 108, 192, 152, 210, 51, 128, 108, 192, 161, 231, 104, 51, 128,
         115, 119, 211, 228, 109, 244, 115, 131, 118, 111, 146, 176, 186, 133, 117, 108, 115, 101, 115, 131,
         118, 111, 133, 119, 109, 251, 115, 131, 118, 111, 152, 210, 112, 217, 115, 230, 116, 114, 105, 181,
         110, 198, 228, 115, 131, 118, 111, 158, 147, 110, 174, 212, 153, 222, 100, 180, 145, 116, 242, 114,
         196, 112, 137, 168, 157, 110, 179, 101, 221, 114, 151, 233, 221, 114, 95, 253, 112, 111, 221, 114, 161,
         111, 209, 114, 196, 115, 154, 121, 194, 113, 117, 177, 107, 114, 196, 115, 162, 99, 95, 253, 112, 111,
         254, 162, 99, 251, 112, 211, 162, 99, 251, 190, 162, 99, 251, 254, 95, 253, 112, 111, 112, 211, 95,
         253, 112, 111, 190, 95, 253, 112, 111, 254, 145, 114, 196, 112, 211, 145, 114, 196, 190, 145, 114, 196,
         221, 250, 157, 108, 192, 154, 121, 194, 221, 250, 157, 108, 192, 133, 131, 99, 176, 116, 254, 162, 135,
         130, 108, 192, 112, 211, 162, 135, 130, 108, 192, 190, 162, 135, 130, 108, 192, 142, 184, 163, 146,
         104, 141, 156, 186, 115, 131, 105, 139, 181, 112, 100, 135, 130, 114, 135, 130, 104, 122, 144, 117,
         138, 99, 109, 95, 107, 112, 144, 117, 138, 99, 109, 95, 107, 105, 115, 109, 139, 108, 95, 240, 143,
         144, 117, 133, 137, 99, 255, 115, 138, 176, 111, 109, 167, 103, 219, 99, 108, 132, 135, 189, 187, 116,
         111, 164, 198, 138, 174, 207, 214, 146, 139, 95, 149, 95, 168, 114, 160, 95, 198, 112, 142, 198, 238,
         108, 210, 95, 142, 198, 172, 133, 137, 118, 233, 131, 172, 145, 98, 217, 151, 244, 172, 95, 187, 116,
         111, 146, 149, 168, 103, 172, 95, 187, 116, 111, 166, 187, 100, 172, 181, 206, 111, 120, 95, 156, 113,
         117, 105, 114, 130, 109, 244, 108, 172, 181, 206, 111, 120, 212, 108, 231, 104, 116, 151, 244, 108,
         172, 181, 112, 100, 135, 130, 114, 135, 130, 104, 122, 172, 181, 206, 111, 120, 181, 116, 99, 145, 116,
         237, 141, 100, 172, 181, 206, 111, 120, 181, 115, 130, 103, 139, 105, 143, 111, 172, 181, 206, 111,
         120, 95, 176, 171, 157, 147, 97, 172, 145, 159, 161, 111, 109, 130, 112, 111, 132, 116, 95, 149, 99,
         101, 172, 181, 115, 130, 51, 128, 115, 194, 220, 172, 145, 98, 217, 95, 132, 173, 103, 114, 136, 121,
         172, 215, 109, 101, 97, 146, 117, 160, 111, 109, 146, 111, 109, 109, 237, 115, 172, 181, 242, 172, 166,
         187, 100, 172, 95, 185, 226, 130, 109, 132, 145, 116, 242, 164, 116, 172, 95, 185, 226, 130, 139, 116,
         151, 244, 172, 95, 185, 226, 130, 132, 136, 105, 139, 146, 108, 245, 172, 95, 185, 226, 130, 217, 99,
         176, 128, 114, 196, 172, 95, 185, 226, 130, 142, 116, 117, 114, 110, 238, 116, 172, 95, 185, 226, 130,
         103, 137, 117, 110, 128, 115, 194, 220, 172, 95, 185, 226, 130, 169, 115, 99, 176, 116, 164, 116, 172,
         95, 185, 226, 130, 169, 115, 99, 176, 128, 114, 196, 172, 95, 185, 226, 130, 115, 147, 136, 121, 146,
         104, 101, 99, 107, 115, 172, 95, 185, 226, 130, 109, 132, 145, 135, 115, 172, 95, 185, 226, 130, 139,
         108, 210, 95, 198, 180, 95, 119, 136, 104, 111, 117, 116, 95, 168, 120, 172, 95, 185, 226, 130, 190,
         133, 172, 152, 155, 116, 144, 131, 208, 135, 130, 108, 135, 172, 152, 155, 116, 144, 131, 208, 135,
         130, 108, 149, 172, 152, 155, 116, 144, 131, 151, 132, 152, 155, 116, 144, 130, 115, 172, 152, 155,
         116, 144, 131, 208, 135, 130, 116, 165, 131, 147, 99, 130, 109, 169, 183, 98, 237, 190, 219, 183, 98,
         237, 190, 146, 149, 116, 200, 95, 142, 209, 115, 220, 139, 116, 161, 165, 128, 99, 108, 245, 251, 139,
         116, 161, 165, 128, 169, 183, 98, 237, 188, 161, 165, 128, 169, 183, 98, 237, 188, 104, 165, 128, 188,
         136, 189, 145, 111, 117, 249, 101, 188, 104, 165, 128, 111, 112, 116, 177, 139, 102, 108, 210, 95, 113,
         117, 139, 136, 121, 151, 132, 188, 104, 165, 128, 111, 112, 116, 177, 139, 102, 108, 210, 151, 225,
         162, 240, 101, 175, 128, 112, 137, 99, 255, 115, 138, 176, 111, 109, 114, 117, 110, 178, 207, 154, 97,
         107, 101, 223, 133, 142, 118, 176, 116, 189, 114, 117, 110, 178, 207, 154, 97, 107, 101, 223, 219, 156,
         116, 105, 118, 135, 130, 169, 108, 207, 114, 117, 110, 178, 207, 154, 97, 107, 101, 223, 219, 156, 116,
         105, 118, 135, 130, 221, 250, 157, 112, 131, 99, 176, 116, 112, 137, 168, 157, 110, 179, 101, 100, 186,
         109, 252, 49, 138, 121, 110, 151, 132, 230, 100, 186, 109, 252, 49, 138, 121, 110, 151, 225, 230, 100,
         186, 109, 252, 49, 138, 121, 110, 95, 253, 112, 111, 100, 186, 109, 252, 49, 154, 121, 194, 100, 186,
         109, 252, 49, 145, 116, 135, 177, 230, 100, 186, 109, 252, 50, 154, 121, 194, 100, 186, 109, 252, 50,
         145, 116, 135, 177, 230, 100, 186, 109, 215, 163, 158, 230, 100, 186, 109, 215, 163, 158, 146, 117,
         116, 223, 118, 193, 145, 248, 146, 111, 109, 112, 176, 115, 135, 189, 175, 128, 135, 151, 132, 154,
         104, 250, 143, 147, 116, 105, 208, 114, 97, 118, 136, 121, 208, 199, 147, 116, 105, 208, 114, 97, 118,
         136, 121, 146, 117, 116, 223, 230, 147, 116, 105, 208, 114, 97, 118, 136, 121, 133, 208, 199, 156, 99,
         152, 192, 95, 190, 156, 99, 152, 192, 99, 114, 217, 104, 138, 221, 185, 104, 165, 100, 99, 114, 217,
         104, 208, 221, 185, 104, 165, 100, 99, 114, 217, 104, 145, 159, 112, 111, 132, 116, 154, 104, 185, 104,
         165, 100, 99, 114, 217, 104, 154, 144, 101, 99, 114, 217, 104, 138, 174, 207, 99, 114, 217, 104, 95,
         142, 99, 111, 209, 121, 95, 240, 143, 99, 114, 217, 104, 95, 142, 99, 111, 209, 121, 251, 99, 114, 217,
         104, 152, 192, 95, 190, 99, 114, 217, 104, 95, 142, 99, 111, 209, 121, 136, 131, 109, 95, 195, 135,
         189, 136, 131, 109, 95, 142, 108, 225, 136, 131, 109, 95, 142, 108, 225, 154, 121, 194, 136, 131, 109,
         95, 142, 108, 225, 146, 117, 116, 223, 136, 131, 109, 95, 119, 132, 100, 117, 112, 175, 100, 115, 117,
         109, 152, 192, 175, 100, 115, 117, 109, 152, 192, 95, 190, 190, 152, 210, 112, 217, 115, 230, 221, 250,
         157, 184, 129, 116, 221, 250, 157, 184, 129, 116, 146, 117, 116, 223, 156, 137, 154, 114, 199, 131, 95,
         240, 157, 108, 192, 156, 137, 154, 114, 199, 131, 152, 111, 111, 107, 97, 104, 101, 97, 128, 109, 115,
         156, 137, 154, 114, 199, 131, 219, 98, 117, 103, 95, 225, 148, 156, 137, 154, 114, 199, 131, 208, 199,
         112, 133, 211, 105, 133, 211, 128, 112, 211, 102, 133, 211, 140, 254, 105, 95, 254, 128, 254, 102, 95,
         254, 140, 190, 105, 95, 190, 128, 190, 102, 95, 190, 240, 157, 140, 103, 199, 240, 157, 102, 101, 220,
         102, 153, 222, 100, 240, 157, 102, 101, 220, 102, 153, 222, 128, 115, 109, 111, 163, 104, 180, 151,
         115, 240, 157, 108, 192, 240, 157, 101, 141, 221, 95, 142, 102, 104, 153, 105, 122, 149, 95, 143, 118,
         174, 145, 116, 142, 110, 103, 221, 104, 153, 105, 122, 149, 152, 192, 145, 116, 177, 107, 115, 104,
         153, 105, 122, 149, 152, 192, 219, 103, 142, 255, 104, 153, 105, 122, 149, 95, 231, 110, 153, 130, 160,
         177, 107, 115, 104, 153, 105, 122, 149, 138, 174, 207, 151, 115, 158, 105, 114, 140, 108, 248, 212,
         142, 113, 230, 158, 105, 114, 140, 143, 97, 128, 102, 142, 113, 230, 158, 105, 114, 140, 179, 197, 136,
         117, 100, 130, 254, 158, 105, 114, 140, 179, 197, 136, 117, 100, 130, 112, 211, 158, 105, 114, 140,
         179, 197, 136, 117, 100, 130, 190, 158, 105, 114, 140, 102, 142, 113, 117, 176, 99, 121, 145, 116, 242,
         219, 99, 105, 230, 158, 105, 114, 140, 102, 142, 113, 117, 176, 99, 121, 95, 176, 128, 169, 99, 105,
         230, 158, 105, 114, 140, 116, 144, 130, 115, 101, 99, 149, 100, 115, 158, 105, 114, 140, 142, 194, 135,
         128, 239, 95, 254, 128, 239, 133, 211, 128, 239, 95, 190, 128, 239, 208, 199, 128, 239, 95, 183, 118,
         147, 99, 101, 109, 163, 153, 95, 111, 117, 116, 112, 117, 116, 152, 192, 187, 116, 111, 133, 137, 168,
         157, 99, 174, 108, 146, 111, 117, 110, 116, 108, 187, 110, 158, 146, 149, 116, 200, 151, 244, 108, 187,
         110, 158, 154, 114, 231, 103, 131, 238, 108, 210, 95, 185, 159, 108, 187, 110, 158, 154, 114, 231, 103,
         131, 154, 104, 250, 157, 112, 131, 99, 176, 116, 108, 187, 110, 158, 95, 240, 157, 108, 192, 108, 187,
         110, 158, 146, 149, 116, 200, 208, 199, 221, 114, 117, 160, 152, 132, 101, 141, 102, 101, 220, 102,
         153, 222, 128, 116, 114, 147, 115, 136, 189, 102, 101, 220, 102, 153, 222, 128, 97, 209, 248, 180, 102,
         101, 220, 102, 153, 222, 128, 115, 109, 111, 163, 104, 212, 156, 116, 153, 102, 101, 220, 102, 153,
         222, 128, 106, 136, 186, 212, 156, 116, 153, 102, 101, 220, 102, 153, 222, 128, 184, 129, 116, 102,
         101, 220, 102, 153, 222, 128, 239, 162, 135, 130, 108, 192, 102, 101, 220, 102, 153, 222, 128, 190,
         161, 165, 128, 103, 199, 102, 101, 220, 102, 153, 222, 128, 190, 161, 165, 128, 116, 144, 101, 100,
         121, 110, 95, 233, 157, 109, 132, 162, 112, 109, 100, 121, 110, 95, 233, 157, 140, 103, 199, 100, 121,
         110, 95, 233, 157, 105, 208, 199, 100, 121, 110, 95, 233, 157, 128, 103, 199, 100, 121, 110, 95, 233,
         157, 239, 95, 132, 99, 142, 217, 101, 143, 118, 174, 162, 156, 130, 109, 244, 115, 144, 197, 105, 168,
         228, 175, 100, 115, 151, 244, 115, 144, 197, 105, 168, 228, 167, 160, 131, 151, 117, 108, 116, 105,
         197, 105, 131, 115, 144, 197, 105, 168, 228, 105, 208, 199, 115, 144, 197, 105, 168, 228, 128, 103,
         199, 115, 144, 197, 105, 168, 228, 175, 208, 199, 115, 144, 197, 105, 168, 228, 128, 239, 208, 199,
         115, 144, 197, 105, 168, 228, 102, 101, 220, 102, 153, 222, 128, 103, 199, 115, 144, 197, 105, 168,
         228, 112, 211, 95, 128, 103, 199, 115, 144, 197, 105, 168, 228, 112, 211, 133, 105, 208, 199, 115, 144,
         197, 105, 168, 228, 100, 186, 109, 95, 168, 108, 186, 115, 144, 197, 105, 168, 228, 100, 186, 109, 95,
         168, 108, 186, 151, 117, 108, 116, 105, 197, 105, 131, 115, 144, 197, 105, 168, 228, 214, 95, 168, 108,
         186, 115, 144, 197, 105, 168, 228, 214, 95, 168, 108, 186, 151, 117, 108, 116, 105, 197, 105, 131, 116,
         112, 97, 151, 244, 116, 112, 97, 251, 116, 112, 97, 166, 142, 97, 107, 112, 111, 132, 116, 116, 112,
         97, 152, 210, 251, 116, 112, 97, 152, 210, 166, 142, 97, 107, 112, 111, 132, 116, 116, 112, 97, 152,
         210, 238, 119, 207, 115, 101, 122, 152, 237, 180, 154, 104, 185, 104, 165, 100, 101, 122, 152, 237,
         180, 152, 192, 101, 122, 152, 237, 180, 145, 194, 220, 108, 237, 180, 164, 198, 154, 104, 185, 104,
         165, 100, 116, 108, 109, 95, 132, 209, 173, 100, 116, 108, 109, 161, 139, 102, 100, 117, 112, 143, 120,
         205, 95, 49, 133, 195, 111, 99, 165, 205, 95, 49, 181, 242, 205, 95, 49, 166, 187, 100, 205, 95, 50,
         133, 195, 111, 99, 165, 205, 95, 50, 181, 242, 205, 95, 50, 166, 187, 100, 205, 95, 51, 133, 195, 111,
         99, 165, 205, 95, 51, 181, 242, 205, 95, 51, 166, 187, 100, 99, 191, 102, 154, 108, 109, 95, 156, 99,
         214, 102, 191, 107, 121, 219, 102, 187, 108, 116, 152, 135, 102, 191, 107, 121, 219, 102, 187, 108,
         116, 152, 149, 103, 102, 191, 107, 121, 95, 172, 212, 153, 109, 135, 102, 191, 107, 121, 181, 110, 136,
         102, 191, 107, 121, 243, 102, 217, 133, 142, 99, 148, 189, 104, 163, 116, 238, 198, 95, 132, 116, 175,
         128, 132, 154, 108, 109, 142, 112, 153, 116, 146, 174, 108, 243, 165, 116, 248, 101, 105, 98, 227, 145,
         176, 115, 153, 167, 118, 108, 132, 107, 151, 97, 104, 95, 217, 161, 101, 183, 180, 138, 105, 118, 148,
         153, 167, 118, 108, 132, 107, 151, 132, 154, 120, 98, 117, 102, 102, 167, 118, 108, 132, 107, 95, 253,
         116, 145, 116, 135, 227, 251, 167, 118, 108, 132, 107, 162, 99, 146, 104, 147, 251, 167, 118, 108, 132,
         107, 150, 251, 167, 118, 108, 132, 107, 95, 253, 116, 114, 97, 49, 251, 167, 118, 108, 132, 107, 95,
         253, 116, 114, 97, 50, 251, 167, 118, 108, 132, 107, 95, 253, 116, 114, 97, 51, 251, 247, 118, 165,
         116, 248, 101, 247, 226, 114, 142, 110, 116, 247, 102, 117, 174, 247, 109, 244, 247, 156, 99, 95, 120,
         247, 156, 99, 95, 121, 247, 156, 99, 95, 122, 247, 112, 211, 247, 254, 247, 104, 101, 183, 180, 247,
         139, 116, 136, 117, 169, 247, 118, 141, 105, 111, 247, 108, 135, 152, 149, 103, 247, 103, 137, 117,
         110, 128, 115, 194, 220, 247, 100, 148, 116, 147, 99, 101, 247, 255, 99, 146, 117, 114, 142, 110, 116,
         247, 255, 99, 243, 165, 116, 248, 101, 247, 255, 99, 162, 112, 109, 247, 255, 99, 154, 101, 109, 112,
         131, 135, 117, 142, 247, 173, 109, 112, 131, 135, 117, 142, 247, 99, 155, 227, 220, 143, 100, 160, 114,
         105, 140, 118, 148, 117, 139, 166, 101, 101, 112, 131, 143, 100, 160, 114, 105, 140, 118, 148, 117,
         139, 166, 101, 101, 112, 131, 146, 165, 153, 143, 100, 160, 114, 105, 140, 103, 114, 98, 162, 103, 98,
         143, 100, 160, 114, 105, 112, 133, 137, 168, 143, 143, 100, 160, 114, 105, 140, 114, 156, 130, 99, 165,
         153, 143, 100, 160, 114, 105, 140, 98, 101, 156, 149, 146, 165, 153, 143, 100, 160, 114, 105, 140, 98,
         101, 156, 149, 133, 131, 105, 111, 128, 109, 115, 143, 100, 160, 114, 105, 140, 98, 101, 156, 149, 133,
         131, 99, 176, 116, 143, 100, 160, 114, 105, 140, 98, 101, 156, 149, 95, 198, 228, 149, 108, 121, 143,
         100, 160, 114, 105, 140, 98, 114, 231, 104, 116, 110, 255, 115, 143, 100, 160, 114, 105, 140, 114, 199,
         184, 119, 138, 174, 116, 97, 143, 100, 160, 114, 105, 140, 114, 199, 184, 119, 212, 142, 113, 116, 114,
         147, 115, 112, 149, 100, 131, 133, 137, 118, 233, 131, 116, 114, 147, 115, 112, 149, 100, 131, 138,
         135, 97, 115, 100, 99, 141, 128, 100, 159, 101, 99, 116, 95, 132, 209, 173, 100, 115, 100, 99, 141,
         128, 109, 244, 115, 100, 99, 141, 128, 115, 175, 166, 227, 134, 117, 110, 136, 115, 134, 222, 110, 166,
         136, 167, 115, 107, 134, 191, 115, 105, 238, 198, 134, 108, 132, 107, 95, 113, 117, 139, 136, 121, 238,
         198, 134, 191, 115, 105, 138, 98, 109, 238, 198, 134, 191, 110, 114, 238, 198, 134, 99, 155, 139, 198,
         134, 139, 116, 238, 198, 134, 100, 148, 116, 147, 99, 130, 139, 198, 134, 255, 99, 154, 101, 109, 140,
         139, 198, 134, 255, 99, 162, 112, 109, 238, 198, 134, 255, 99, 146, 117, 114, 142, 110, 116, 238, 198,
         134, 99, 153, 130, 173, 109, 140, 139, 198, 134, 97, 104, 151, 225, 133, 136, 134, 97, 104, 151, 225,
         95, 200, 134, 97, 104, 95, 132, 209, 116, 134, 108, 111, 103, 111, 95, 149, 95, 198, 180, 134, 108,
         111, 103, 111, 95, 149, 95, 198, 180, 138, 117, 114, 135, 189, 134, 198, 180, 152, 111, 103, 111, 134,
         227, 130, 113, 117, 177, 107, 151, 176, 117, 134, 115, 104, 210, 145, 194, 99, 133, 142, 198, 134, 116,
         144, 49, 134, 116, 144, 50, 134, 118, 193, 150, 134, 191, 115, 105, 150, 134, 108, 132, 107, 95, 113,
         117, 139, 136, 121, 150, 134, 108, 132, 107, 154, 120, 133, 210, 131, 150, 134, 191, 115, 105, 138, 98,
         109, 150, 134, 191, 110, 114, 150, 134, 116, 144, 95, 49, 150, 134, 116, 144, 95, 50, 150, 134, 142,
         167, 132, 180, 154, 144, 130, 101, 160, 144, 135, 241, 134, 102, 108, 121, 109, 111, 100, 241, 134,
         147, 116, 105, 208, 114, 97, 118, 136, 121, 150, 134, 103, 212, 153, 99, 241, 134, 221, 250, 157, 188,
         134, 118, 116, 120, 146, 104, 147, 110, 174, 150, 134, 99, 114, 129, 115, 104, 97, 105, 191, 150, 134,
         97, 104, 145, 98, 141, 150, 134, 97, 104, 150, 134, 226, 114, 142, 110, 116, 150, 134, 167, 104, 138,
         114, 178, 110, 150, 134, 119, 104, 138, 114, 178, 110, 150, 134, 109, 163, 153, 138, 105, 248, 150,
         134, 99, 114, 97, 102, 116, 215, 179, 241, 134, 175, 108, 163, 215, 179, 241, 134, 172, 145, 194, 228,
         188, 134, 172, 152, 149, 150, 134, 172, 152, 135, 150, 134, 172, 152, 155, 226, 114, 114, 150, 134,
         172, 152, 97, 112, 133, 142, 118, 150, 134, 172, 152, 155, 98, 101, 160, 51, 150, 134, 172, 145, 135,
         115, 150, 134, 104, 111, 109, 130, 100, 105, 114, 150, 134, 104, 111, 109, 130, 100, 148, 116, 150,
         134, 102, 108, 231, 104, 116, 164, 116, 150, 134, 99, 111, 109, 112, 217, 115, 166, 141, 150, 134, 139,
         116, 136, 117, 100, 241, 134, 175, 128, 254, 150, 134, 175, 128, 112, 211, 150, 134, 175, 128, 190,
         150, 134, 169, 98, 117, 103, 150, 134, 169, 98, 117, 103, 50, 150, 134, 112, 210, 131, 150, 134, 175,
         100, 114, 135, 130, 112, 137, 168, 157, 188, 134, 222, 110, 180, 115, 150, 134, 97, 118, 103, 146, 174,
         108, 243, 165, 116, 248, 241, 134, 112, 136, 95, 240, 150, 134, 200, 95, 240, 150, 134, 193, 186, 121,
         181, 115, 248, 241, 134, 100, 148, 198, 228, 188, 134, 110, 104, 101, 183, 180, 150, 134, 117, 112,
         138, 210, 110, 95, 142, 102, 131, 176, 99, 241, 134, 142, 183, 121, 151, 111, 100, 241, 134, 188, 161,
         165, 128, 142, 183, 121, 150, 134, 110, 118, 141, 105, 111, 150, 134, 255, 99, 154, 109, 112, 150, 134,
         255, 99, 162, 112, 109, 150, 134, 255, 99, 162, 112, 109, 212, 142, 113, 150, 134, 114, 116, 99, 138,
         135, 130, 116, 144, 241, 134, 183, 106, 117, 160, 109, 176, 116, 162, 240, 241, 134, 102, 108, 105,
         140, 141, 137, 119, 150, 134, 99, 153, 130, 173, 109, 112, 150, 134, 108, 111, 103, 145, 116, 135, 227,
         150, 134, 160, 177, 107, 95, 111, 209, 108, 207, 95, 143, 102, 116, 150, 134, 160, 177, 107, 95, 111,
         209, 108, 207, 162, 231, 104, 116, 150, 134, 160, 177, 107, 95, 111, 209, 108, 207, 162, 183, 105, 111,
         151, 244, 134, 114, 135, 130, 112, 137, 168, 157, 110, 179, 241, 134, 175, 128, 112, 137, 168, 157,
         110, 179, 241, 134, 193, 186, 121, 133, 137, 168, 157, 110, 179, 241, 134, 112, 137, 168, 157, 110,
         179, 241, 134, 249, 158, 147, 110, 174, 115, 150, 134, 99, 179, 131, 97, 212, 114, 179, 241, 134, 101,
         102, 168, 99, 105, 176, 99, 121, 150, 134, 116, 163, 139, 212, 108, 231, 104, 116, 115, 150, 134, 187,
         120, 150, 134, 115, 121, 115, 208, 111, 103, 103, 157, 118, 165, 116, 248, 241, 134, 115, 121, 115,
         243, 116, 120, 243, 165, 116, 248, 241, 134, 115, 121, 115, 166, 136, 114, 135, 241, 134, 115, 121,
         115, 138, 174, 207, 150, 134, 115, 121, 115, 164, 116, 147, 99, 241, 134, 115, 121, 115, 152, 113, 150,
         134, 115, 121, 115, 208, 111, 103, 103, 157, 100, 118, 114, 150, 134, 115, 121, 115, 243, 116, 120,
         138, 118, 114, 150, 134, 115, 121, 115, 95, 222, 110, 180, 115, 150, 134, 115, 121, 115, 243, 116, 120,
         154, 101, 109, 112, 150, 134, 115, 121, 115, 212, 147, 145, 194, 228, 188, 134, 160, 135, 166, 136,
         167, 115, 107, 134, 112, 137, 168, 143, 134, 112, 137, 168, 157, 49, 215, 179, 101, 134, 112, 137, 168,
         157, 50, 215, 179, 101, 134, 112, 137, 168, 157, 51, 215, 179, 101, 134, 172, 145, 135, 115, 145, 104,
         210, 133, 100, 111, 112, 134, 100, 148, 197, 207, 112, 153, 116, 219, 118, 177, 101, 134, 117, 242,
         134, 249, 158, 147, 110, 174, 115, 134, 99, 179, 131, 97, 212, 114, 179, 130, 119, 233, 221, 134, 99,
         179, 131, 97, 212, 114, 179, 130, 104, 101, 231, 104, 116, 134, 160, 135, 95, 97, 118, 103, 146, 174,
         108, 243, 139, 117, 101, 134, 102, 114, 179, 131, 135, 130, 104, 122, 134, 109, 176, 117, 166, 224,
         103, 137, 117, 110, 100, 134, 187, 120, 146, 104, 147, 110, 174, 134, 187, 120, 145, 99, 139, 101, 134,
         187, 120, 145, 121, 109, 98, 165, 134, 99, 114, 97, 102, 116, 110, 179, 130, 109, 115, 103, 115, 134,
         108, 233, 141, 164, 116, 150, 134, 226, 160, 111, 109, 145, 131, 105, 139, 154, 253, 116, 150, 134,
         226, 160, 111, 109, 145, 131, 105, 139, 154, 253, 116, 154, 131, 109, 132, 135, 153, 134, 226, 160,
         111, 109, 154, 253, 116, 181, 242, 134, 226, 160, 111, 109, 154, 253, 116, 166, 187, 100, 134, 119,
         140, 110, 117, 109, 98, 131, 150, 134, 119, 140, 226, 114, 142, 110, 116, 152, 135, 150, 134, 119, 140,
         226, 114, 142, 110, 116, 152, 149, 150, 134, 119, 140, 226, 114, 142, 110, 116, 238, 116, 150, 134,
         119, 112, 164, 116, 147, 99, 241, 134, 119, 112, 138, 105, 142, 99, 116, 189, 150, 134, 119, 140, 110,
         253, 116, 215, 117, 109, 98, 131, 150, 134, 119, 140, 159, 97, 150, 134, 110, 97, 118, 151, 97, 112,
         150, 134, 110, 97, 118, 151, 155, 109, 244, 134, 110, 97, 118, 151, 155, 99, 176, 116, 142, 134, 110,
         97, 118, 151, 155, 109, 132, 145, 99, 139, 130, 109, 134, 97, 105, 191, 194, 220, 115, 121, 160, 101,
         109, 161, 115, 130, 109, 104, 122, 116, 217, 107, 145, 116, 135, 148, 116, 177, 115, 169, 98, 117, 103,
         151, 244, 114, 135, 130, 54, 188, 145, 119, 211, 99, 112, 117, 95, 111, 209, 99, 108, 111, 99, 107,
         112, 119, 114, 95, 149, 95, 198, 208, 114, 156, 101, 176, 171, 157, 160, 177, 107, 95, 198, 180, 118,
         116, 120, 166, 237, 118, 116, 120, 146, 104, 147, 110, 174, 118, 116, 120, 133, 210, 131, 118, 116,
         120, 152, 210, 133, 210, 131, 164, 198, 118, 116, 120, 145, 216, 116, 115, 131, 105, 139, 238, 116,
         118, 116, 120, 154, 121, 194, 118, 116, 120, 181, 242, 118, 116, 120, 212, 142, 113, 118, 116, 120,
         133, 136, 151, 111, 100, 130, 102, 142, 113, 118, 116, 120, 161, 139, 102, 100, 117, 112, 143, 120,
         118, 116, 120, 232, 166, 227, 118, 99, 128, 118, 105, 169, 111, 145, 121, 160, 101, 109, 118, 99, 128,
         104, 95, 223, 115, 159, 118, 99, 128, 118, 95, 223, 115, 159, 239, 55, 52, 53, 54, 146, 108, 111, 99,
         107, 239, 55, 52, 53, 54, 232, 166, 227, 239, 55, 52, 53, 54, 133, 142, 132, 136, 95, 111, 112, 117,
         100, 148, 197, 207, 112, 153, 116, 151, 115, 140, 99, 165, 95, 183, 106, 117, 160, 100, 148, 197, 207,
         112, 153, 116, 151, 115, 140, 137, 119, 95, 183, 106, 117, 160, 100, 148, 197, 207, 112, 153, 116, 151,
         115, 140, 102, 149, 116, 115, 100, 148, 197, 207, 112, 153, 116, 151, 115, 140, 227, 130, 169, 118,
         177, 130, 206, 132, 107, 100, 148, 197, 207, 112, 153, 116, 151, 225, 55, 52, 53, 54, 146, 165, 95,
         183, 106, 117, 160, 100, 148, 197, 207, 112, 153, 116, 151, 225, 55, 52, 53, 54, 95, 137, 119, 95, 183,
         106, 117, 160, 100, 148, 197, 207, 112, 153, 116, 151, 225, 55, 52, 53, 54, 95, 132, 118, 100, 148,
         197, 207, 112, 153, 116, 151, 225, 55, 52, 53, 54, 166, 108, 107, 100, 148, 197, 207, 112, 153, 116,
         151, 225, 55, 52, 53, 54, 95, 119, 104, 116, 255, 99, 145, 176, 115, 153, 161, 139, 102, 100, 117, 112,
         143, 120, 255, 99, 145, 176, 115, 153, 146, 117, 114, 142, 110, 116, 95, 223, 115, 159, 255, 99, 145,
         176, 115, 153, 181, 242, 102, 191, 107, 121, 232, 95, 187, 116, 111, 98, 132, 100, 102, 191, 107, 121,
         232, 154, 120, 95, 233, 102, 191, 107, 121, 232, 95, 223, 115, 159, 102, 191, 107, 121, 232, 166, 132,
         128, 104, 111, 112, 138, 135, 97, 102, 191, 107, 121, 95, 120, 162, 120, 215, 117, 109, 102, 191, 107,
         121, 232, 95, 97, 49, 145, 111, 117, 249, 101, 99, 99, 50, 53, 48, 48, 232, 146, 104, 105, 112, 138,
         159, 101, 99, 116, 234, 132, 209, 115, 189, 100, 217, 104, 184, 141, 128, 105, 50, 99, 166, 227, 100,
         217, 104, 184, 141, 128, 105, 50, 99, 95, 183, 100, 114, 99, 179, 131, 97, 146, 149, 116, 200, 151,
         244, 99, 179, 131, 97, 146, 149, 116, 200, 95, 142, 102, 243, 165, 116, 248, 101, 99, 179, 131, 97,
         146, 149, 116, 200, 95, 107, 101, 121, 138, 174, 207, 99, 179, 131, 97, 146, 149, 116, 200, 95, 132,
         186, 110, 139, 95, 185, 148, 116, 147, 99, 101, 99, 179, 131, 97, 146, 149, 116, 200, 166, 117, 116,
         116, 149, 95, 185, 148, 116, 147, 99, 101, 99, 179, 131, 97, 146, 149, 116, 200, 95, 132, 209, 173,
         100, 114, 240, 101, 102, 132, 100, 131, 161, 141, 100, 222, 101, 114, 240, 101, 102, 132, 100, 131,
         181, 242, 111, 112, 116, 177, 139, 102, 108, 210, 161, 141, 100, 222, 101, 111, 112, 116, 177, 139,
         102, 108, 210, 181, 242, 111, 112, 116, 177, 139, 102, 108, 210, 95, 195, 135, 189, 111, 112, 116, 177,
         139, 102, 108, 210, 212, 108, 105, 140, 120, 112, 132, 105, 111, 146, 149, 168, 103, 112, 132, 105,
         111, 166, 111, 120, 227, 98, 161, 105, 128, 99, 100, 99, 227, 98, 151, 115, 99, 133, 132, 133, 117,
         108, 108, 117, 112, 102, 108, 217, 104, 232, 166, 227, 249, 169, 118, 177, 130, 132, 136, 219, 118, 95,
         135, 173, 109, 112, 116, 115, 249, 169, 118, 177, 130, 132, 136, 219, 118, 95, 135, 173, 109, 112, 116,
         95, 132, 186, 118, 139, 249, 169, 118, 177, 130, 112, 195, 111, 99, 165, 95, 209, 115, 189, 249, 169,
         118, 177, 130, 102, 101, 135, 117, 142, 249, 169, 118, 177, 130, 117, 242, 214, 95, 49, 166, 117, 160,
         121, 194, 214, 95, 49, 232, 98, 227, 214, 95, 49, 95, 105, 50, 99, 66, 227, 214, 95, 49, 95, 105, 50,
         99, 95, 183, 100, 185, 115, 105, 50, 99, 49, 133, 117, 108, 108, 117, 112, 105, 50, 99, 49, 146, 108,
         111, 99, 107, 115, 194, 228, 107, 104, 122, 105, 50, 99, 50, 133, 117, 108, 108, 117, 112, 105, 50, 99,
         50, 146, 108, 111, 99, 107, 115, 194, 228, 107, 104, 122, 105, 50, 99, 51, 133, 117, 108, 108, 117,
         112, 105, 50, 99, 51, 146, 108, 111, 99, 107, 115, 194, 228, 107, 104, 122, 109, 99, 111, 50, 95, 149,
         133, 99, 57, 115, 194, 107, 116, 114, 117, 109, 232, 133, 195, 111, 99, 165, 115, 194, 107, 116, 114,
         117, 109, 232, 151, 102, 103, 95, 233, 115, 194, 107, 116, 114, 117, 109, 232, 215, 117, 109, 146, 104,
         147, 110, 174, 115, 253, 112, 185, 115, 108, 191, 181, 233, 253, 112, 185, 115, 108, 191, 138, 111,
         167, 132, 253, 112, 185, 115, 108, 191, 151, 244, 108, 95, 233, 115, 158, 220, 117, 108, 131, 95, 142,
         108, 225, 162, 120, 115, 158, 220, 117, 108, 131, 95, 142, 108, 225, 95, 129, 100, 115, 158, 220, 117,
         108, 131, 219, 98, 117, 103, 154, 217, 107, 99, 112, 117, 152, 135, 130, 108, 192, 133, 131, 109, 105,
         108, 143, 115, 131, 105, 139, 109, 115, 140, 104, 139, 102, 100, 117, 112, 143, 120, 109, 115, 140, 49,
         181, 242, 109, 115, 140, 49, 166, 187, 100, 109, 115, 140, 50, 181, 242, 109, 115, 140, 50, 166, 187,
         100, 109, 115, 140, 51, 181, 242, 109, 115, 140, 51, 166, 187, 100, 116, 144, 101, 122, 149, 130, 223,
         115, 159, 151, 132, 117, 173, 115, 114, 112, 109, 95, 168, 108, 186, 161, 198, 149, 177, 115, 114, 112,
         109, 95, 168, 108, 186, 95, 119, 101, 231, 104, 116, 115, 114, 112, 109, 95, 168, 108, 186, 95, 113,
         114, 112, 109, 95, 168, 108, 186, 151, 132, 230, 114, 112, 109, 95, 168, 108, 186, 212, 183, 130, 114,
         240, 130, 104, 122, 114, 112, 109, 95, 168, 108, 186, 252, 230, 102, 108, 121, 115, 107, 121, 232, 154,
         120, 95, 233, 102, 108, 121, 115, 107, 121, 232, 162, 102, 146, 104, 147, 110, 174, 115, 160, 135, 115,
         151, 132, 95, 198, 228, 116, 144, 130, 115, 160, 135, 115, 154, 163, 139, 212, 108, 231, 104, 116, 115,
         160, 135, 115, 154, 163, 139, 154, 144, 130, 115, 160, 135, 115, 154, 163, 139, 164, 116, 151, 160,
         135, 115, 145, 97, 118, 130, 109, 111, 118, 130, 108, 192, 160, 135, 115, 151, 97, 104, 181, 115, 220,
         99, 114, 97, 102, 116, 215, 179, 101, 175, 108, 163, 215, 179, 101, 139, 116, 136, 117, 100, 130, 115,
         111, 117, 249, 101, 139, 116, 136, 117, 100, 130, 112, 142, 102, 131, 166, 97, 137, 139, 116, 136, 117,
         100, 130, 108, 229, 114, 240, 101, 102, 132, 100, 131, 151, 225, 162, 240, 130, 99, 109, 139, 116, 136,
         117, 100, 130, 128, 108, 229, 155, 108, 237, 180, 238, 116, 136, 117, 100, 130, 109, 155, 104, 111,
         209, 154, 104, 250, 143, 155, 221, 250, 157, 109, 132, 155, 221, 250, 157, 239, 155, 139, 116, 136,
         117, 100, 130, 112, 155, 139, 116, 136, 117, 100, 130, 105, 155, 139, 116, 136, 117, 100, 130, 100,
         155, 139, 116, 136, 117, 100, 130, 97, 155, 139, 116, 136, 117, 100, 130, 102, 97, 112, 150, 136, 189,
         133, 97, 112, 150, 136, 189, 95, 105, 97, 112, 150, 136, 189, 138, 97, 112, 150, 136, 189, 95, 97, 97,
         112, 150, 136, 189, 212, 97, 112, 150, 136, 189, 146, 117, 116, 223, 155, 160, 111, 140, 221, 185, 104,
         165, 100, 155, 239, 95, 240, 143, 155, 239, 95, 190, 251, 155, 190, 133, 155, 118, 174, 111, 99, 136,
         121, 138, 114, 248, 146, 111, 101, 102, 102, 155, 239, 243, 174, 111, 99, 136, 121, 155, 119, 207, 112,
         111, 132, 116, 95, 141, 114, 105, 118, 139, 162, 183, 105, 227, 155, 119, 207, 112, 111, 132, 116, 161,
         165, 128, 114, 183, 105, 227, 155, 160, 177, 107, 219, 183, 98, 237, 155, 221, 250, 157, 169, 183, 98,
         237, 155, 190, 151, 244, 155, 109, 132, 212, 153, 222, 128, 118, 174, 111, 99, 136, 121, 155, 110, 97,
         118, 146, 153, 110, 131, 145, 194, 220, 155, 110, 97, 118, 146, 153, 110, 131, 138, 174, 116, 97, 243,
         155, 110, 97, 118, 219, 99, 174, 155, 110, 97, 118, 95, 156, 99, 174, 155, 110, 97, 118, 146, 141, 195,
         95, 143, 97, 128, 116, 144, 101, 155, 110, 97, 118, 146, 141, 195, 95, 143, 97, 128, 239, 155, 110, 97,
         118, 133, 142, 116, 117, 114, 110, 164, 116, 155, 118, 174, 111, 99, 136, 121, 166, 117, 105, 108, 100,
         117, 140, 239, 133, 211, 155, 239, 154, 117, 114, 110, 251, 155, 104, 165, 128, 153, 98, 136, 162, 183,
         105, 227, 155, 104, 165, 128, 168, 103, 117, 142, 56, 95, 119, 233, 221, 155, 108, 237, 180, 219, 115,
         99, 176, 116, 251, 155, 108, 237, 180, 138, 159, 101, 99, 116, 189, 154, 144, 101, 155, 108, 237, 180,
         232, 114, 139, 95, 176, 171, 143, 155, 108, 237, 180, 232, 114, 139, 162, 183, 105, 227, 155, 108, 237,
         180, 232, 114, 139, 251, 155, 108, 237, 180, 243, 174, 111, 99, 136, 121, 154, 104, 185, 104, 165, 100,
         155, 108, 237, 180, 154, 104, 250, 157, 221, 185, 104, 165, 100, 155, 108, 49, 95, 176, 171, 143, 155,
         108, 49, 133, 131, 105, 111, 100, 155, 108, 49, 151, 132, 152, 111, 111, 107, 97, 104, 101, 183, 155,
         108, 49, 151, 225, 152, 111, 111, 107, 97, 104, 101, 183, 155, 108, 49, 151, 225, 146, 114, 129, 115,
         154, 114, 224, 95, 131, 137, 114, 155, 108, 49, 154, 117, 114, 110, 251, 155, 109, 132, 215, 97, 118,
         238, 116, 136, 117, 100, 130, 109, 155, 114, 120, 152, 129, 115, 133, 165, 177, 121, 155, 239, 164,
         116, 147, 99, 130, 102, 137, 109, 161, 111, 109, 101, 155, 103, 101, 216, 176, 99, 130, 156, 116, 189,
         218, 181, 115, 131, 95, 49, 215, 179, 101, 218, 181, 115, 131, 95, 50, 215, 179, 101, 218, 181, 115,
         131, 95, 51, 215, 179, 101, 218, 181, 115, 131, 95, 52, 215, 179, 101, 103, 245, 139, 95, 254, 162, 99,
         208, 199, 103, 245, 139, 133, 211, 162, 99, 154, 104, 114, 208, 199, 103, 245, 139, 133, 211, 162, 99,
         152, 210, 208, 199, 103, 245, 139, 133, 211, 162, 99, 161, 231, 104, 208, 199, 103, 245, 139, 95, 190,
         162, 99, 208, 199, 103, 245, 139, 95, 254, 208, 199, 103, 245, 139, 95, 254, 95, 223, 115, 159, 103,
         245, 139, 95, 254, 152, 192, 103, 245, 139, 133, 211, 208, 199, 103, 245, 139, 133, 211, 95, 223, 115,
         159, 103, 245, 139, 133, 211, 152, 210, 152, 192, 103, 245, 139, 133, 211, 161, 231, 104, 152, 192,
         103, 245, 139, 95, 190, 208, 199, 103, 245, 139, 95, 190, 95, 223, 115, 159, 103, 245, 139, 95, 190,
         152, 192, 103, 245, 139, 145, 116, 171, 105, 108, 148, 135, 189, 103, 245, 139, 145, 176, 115, 136,
         105, 118, 136, 121, 103, 245, 139, 181, 242, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
   begin
      return Codes (I);
   end Name_Code;

   Token_Text_Length : constant := 364;
   Max_Token_Length  : constant := 19;
   Token_Text : constant String (1 .. Token_Text_Length + Max_Token_Length) :=
     "d_ose_erin_posd_atitro_dalp_arreleim_s_canison_m_lor_tap_acle_chetst_h_rot_disol_bmafidepsabgpstepienicawam"
     & "ing_u_disabadboresterauionyawrsimitbatpeateplarmainrolteletelemtelemettelemetrtelemetryblay_gverowitch_fgyg"
     & "yro_nofasbox_deedthwaroffackaxcuused_pf_hzig_spiled_blackblackboxand_almaxange_posart_vodeimbtelemetry_disa"
     & "btelemetry_disabled_agrcrott_rate_lpfexroll                   ";

   subtype Token_Code is Interfaces.Unsigned_8 range 128 .. 255;
   type Token_Start is range 0 .. Token_Text_Length;
   type Token_Length is range 2 .. Max_Token_Length;

   Token_Starts : constant array (Token_Code) of Token_Start :=
     (0, 2, 4, 6, 8, 10, 12, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 10, 46, 48, 50, 52, 54,
      57, 59, 62, 64, 66, 68, 70, 72, 74, 78, 80, 82, 84, 86, 88, 90, 92, 95, 31, 97, 99, 101, 103, 105, 107,
      110, 112, 118, 120, 122, 125, 128, 11, 130, 133, 136, 138, 142, 145, 71, 147, 150, 152, 155, 158, 161,
      165, 170, 177, 185, 194, 196, 198, 200, 203, 205, 209, 211, 213, 217, 219, 221, 223, 226, 229, 231, 233,
      236, 239, 242, 244, 246, 248, 251, 253, 256, 258, 85, 262, 266, 271, 279, 282, 285, 288, 291, 296, 299,
      301, 304, 307, 322, 341, 343, 345, 349, 354, 358, 360, 123);

   Token_Lengths : constant array (Token_Code) of Token_Length :=
     (2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 3, 2, 3, 2, 2, 2, 2, 2,
      2, 4, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2, 6, 2, 2, 3, 3, 2, 3, 3, 3, 2, 4, 3, 2, 3, 3, 2,
      3, 3, 3, 4, 5, 7, 8, 9, 2, 2, 2, 3, 2, 4, 2, 2, 4, 2, 2, 2, 3, 3, 2, 2, 3, 3, 3, 2, 2, 2, 3, 2, 3, 2, 4,
      2, 4, 5, 8, 3, 3, 3, 3, 5, 3, 2, 3, 3, 15, 19, 2, 2, 4, 5, 4, 2, 4, 2);

   type Name_Start is range 0 .. Name_Codes_Length;
   type Name_Length is range 1 .. Max_Name_Length;

   Name_Starts : constant array (Setting) of Name_Start :=
     (0, 8, 14, 22, 28, 36, 42, 51, 57, 66, 76, 87, 94, 106, 116, 126, 137, 145, 154, 163, 172, 181, 191, 203,
      210, 214, 221, 228, 237, 242, 249, 256, 263, 270, 280, 291, 298, 305, 314, 322, 330, 341, 353, 361, 369,
      377, 388, 400, 408, 412, 419, 425, 433, 445, 452, 459, 466, 482, 491, 498, 513, 532, 549, 563, 577, 587,
      597, 608, 619, 631, 648, 658, 669, 678, 694, 712, 720, 728, 742, 746, 762, 778, 786, 791, 800, 806, 820,
      838, 857, 868, 875, 880, 886, 890, 899, 903, 908, 913, 919, 923, 932, 937, 945, 952, 959, 966, 972, 976,
      982, 985, 995, 998, 1002, 1007, 1014, 1020, 1026, 1034, 1042, 1049, 1057, 1068, 1080, 1091, 1098, 1109,
      1116, 1132, 1141, 1149, 1160, 1174, 1185, 1198, 1214, 1228, 1244, 1261, 1269, 1278, 1286, 1291, 1301,
      1308, 1320, 1334, 1346, 1360, 1370, 1385, 1393, 1401, 1407, 1422, 1430, 1438, 1449, 1460, 1470, 1478,
      1491, 1505, 1511, 1518, 1528, 1535, 1542, 1549, 1556, 1565, 1575, 1583, 1595, 1611, 1621, 1628, 1644,
      1654, 1668, 1673, 1679, 1686, 1692, 1701, 1710, 1720, 1728, 1738, 1744, 1751, 1759, 1771, 1779, 1789,
      1800, 1812, 1821, 1825, 1831, 1836, 1842, 1855, 1859, 1864, 1868, 1873, 1879, 1884, 1888, 1893, 1897,
      1905, 1915, 1921, 1928, 1934, 1942, 1956, 1964, 1972, 1979, 1990, 1998, 2006, 2017, 2026, 2032, 2038,
      2047, 2055, 2070, 2083, 2094, 2107, 2120, 2131, 2146, 2155, 2166, 2182, 2185, 2189, 2201, 2210, 2222,
      2233, 2245, 2258, 2270, 2282, 2297, 2307, 2328, 2335, 2346, 2357, 2371, 2387, 2391, 2396, 2406, 2415,
      2424, 2432, 2444, 2464, 2481, 2492, 2508, 2528, 2553, 2560, 2571, 2582, 2594, 2602, 2612, 2620, 2630,
      2637, 2647, 2659, 2668, 2679, 2693, 2705, 2711, 2715, 2725, 2735, 2751, 2758, 2765, 2778, 2789, 2797,
      2807, 2814, 2821, 2831, 2842, 2851, 2858, 2867, 2874, 2880, 2890, 2901, 2918, 2931, 2939, 2942, 2945,
      2948, 2951, 2953, 2956, 2958, 2961, 2963, 2966, 2968, 2971, 2976, 2985, 3002, 3006, 3014, 3029, 3041,
      3052, 3066, 3076, 3086, 3097, 3108, 3120, 3131, 3149, 3167, 3180, 3187, 3191, 3195, 3199, 3203, 3211,
      3223, 3238, 3248, 3263, 3281, 3290, 3300, 3308, 3321, 3332, 3348, 3362, 3372, 3385, 3398, 3412, 3423,
      3432, 3441, 3450, 3463, 3471, 3482, 3499, 3508, 3517, 3526, 3536, 3551, 3563, 3575, 3588, 3609, 3620,
      3639, 3644, 3648, 3659, 3665, 3678, 3687, 3698, 3705, 3713, 3724, 3732, 3743, 3751, 3756, 3762, 3770,
      3775, 3781, 3789, 3794, 3800, 3810, 3821, 3833, 3843, 3850, 3862, 3870, 3876, 3888, 3895, 3914, 3927,
      3940, 3951, 3958, 3970, 3982, 3994, 4000, 4006, 4010, 4013, 4018, 4023, 4028, 4031, 4033, 4038, 4044,
      4049, 4055, 4064, 4071, 4080, 4088, 4094, 4105, 4113, 4118, 4133, 4151, 4163, 4173, 4185, 4198, 4215,
      4230, 4246, 4260, 4274, 4287, 4300, 4311, 4326, 4333, 4342, 4347, 4355, 4361, 4373, 4382, 4388, 4393,
      4398, 4407, 4416, 4424, 4435, 4444, 4451, 4458, 4465, 4475, 4490, 4497, 4507, 4517, 4521, 4525, 4529,
      4534, 4545, 4555, 4563, 4568, 4574, 4580, 4593, 4601, 4612, 4618, 4623, 4633, 4643, 4650, 4654, 4661,
      4669, 4677, 4685, 4694, 4701, 4707, 4712, 4717, 4725, 4734, 4743, 4749, 4758, 4767, 4776, 4786, 4793,
      4798, 4804, 4809, 4815, 4822, 4827, 4838, 4844, 4856, 4862, 4867, 4875, 4881, 4888, 4901, 4909, 4918,
      4925, 4932, 4939, 4949, 4959, 4970, 4979, 4987, 4996, 5010, 5024, 5039, 5050, 5060, 5071, 5079, 5087,
      5096, 5106, 5117, 5121, 5135, 5147, 5156, 5164, 5173, 5180, 5193, 5204, 5214, 5226, 5236, 5244, 5249,
      5258, 5267, 5276, 5288, 5300, 5303, 5310, 5322, 5336, 5350, 5359, 5370, 5378, 5385, 5393, 5406, 5413,
      5426, 5444, 5454, 5465, 5474, 5485, 5496, 5507, 5515, 5525, 5537, 5543, 5551, 5559, 5569, 5582, 5588,
      5599, 5609, 5615, 5623, 5634, 5645, 5654, 5659, 5667, 5673, 5683, 5695, 5701, 5706, 5712, 5724, 5735,
      5741, 5753, 5761, 5769, 5779, 5787, 5800, 5817, 5834, 5848, 5867, 5887, 5908, 5924, 5940, 5957, 5971,
      5987, 5995, 6007, 6016, 6025, 6039, 6050, 6063, 6079, 6084, 6095, 6108, 6118, 6134, 6149, 6169, 6189,
      6202, 6214, 6223, 6236, 6246, 6258, 6271, 6279, 6286, 6294, 6307, 6314, 6330, 6350, 6364, 6374, 6381,
      6389, 6395, 6404, 6416, 6426, 6441, 6451, 6466, 6476, 6491, 6500, 6513, 6526, 6543, 6551, 6561, 6572,
      6584, 6597, 6610, 6624, 6639, 6645, 6652, 6658, 6665, 6671, 6678, 6692, 6704, 6718, 6727, 6737, 6752,
      6761, 6772, 6787, 6799, 6811, 6821, 6830, 6843, 6852, 6860, 6866, 6877, 6890, 6898, 6912, 6921, 6932,
      6940, 6946, 6951, 6959, 6967, 6975, 6983, 6991, 6997, 7004, 7010, 7017, 7023, 7032, 7041, 7046, 7051,
      7054, 7069, 7077, 7094, 7108, 7116, 7124, 7128, 7141, 7152, 7165, 7172, 7180, 7194, 7206, 7218, 7235,
      7242, 7253, 7266, 7276, 7289, 7300, 7311, 7319, 7335, 7348, 7355, 7363, 7376, 7389, 7405, 7413, 7426,
      7436, 7450, 7460, 7469, 7478, 7487, 7496, 7505, 7517, 7528, 7540, 7549, 7556, 7565, 7572, 7579, 7588,
      7597, 7607, 7614, 7623, 7630, 7641, 7652);

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
      11, 14, 9, 16, 14, 22, 18, 14, 13, 13, 18, 18, 17, 21, 19, 14, 14, 13, 18, 27, 15, 18, 20, 8, 8, 12, 12,
      20, 21, 16, 12, 13, 13, 31, 15, 20, 15, 16, 19, 18, 15, 10, 15, 17, 16, 18, 18, 18, 17, 15, 15, 20, 20,
      21, 16, 16, 17, 19, 19, 16, 16, 17, 15, 13, 14, 13, 23, 16, 24, 15, 15, 21, 16, 16, 25, 18, 22, 14, 15,
      15, 20, 21, 24, 18, 17, 18, 26, 27, 28, 25, 24, 28, 20, 18, 20, 18, 21, 11, 26, 23, 19, 17, 20, 14, 22,
      19, 20, 20, 21, 16, 11, 18, 18, 18, 22, 22, 8, 14, 22, 23, 23, 16, 19, 15, 13, 14, 18, 18, 26, 33, 20, 20,
      17, 22, 22, 22, 19, 20, 22, 14, 15, 16, 18, 23, 12, 14, 15, 10, 16, 13, 16, 19, 8, 11, 9, 20, 18, 8, 8, 8,
      17, 14, 11, 16, 12, 12, 13, 15, 19, 26, 26, 21, 32, 30, 30, 23, 23, 23, 21, 25, 15, 18, 15, 16, 23, 14,
      19, 22, 13, 17, 18, 19, 26, 24, 34, 32, 23, 20, 16, 20, 16, 20, 18, 12, 9, 11, 18, 13, 26, 34, 25, 16, 13,
      14, 13, 13, 18, 11, 19, 11, 19, 11, 19, 11, 21, 19, 25, 14, 17, 19, 18, 19, 20, 23, 20, 10, 10, 10, 10,
      10, 10, 23, 20, 18, 12, 17, 24, 17, 16, 22, 22, 19, 18, 18, 21, 14, 10, 10, 15, 20, 12, 24, 14, 21, 17,
      15, 15, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 18, 17, 12, 15, 8, 22, 15, 26, 23, 17, 20, 11, 23, 19, 21,
      12, 12, 23, 22, 19, 29, 16, 20, 21, 23, 25, 24, 24, 22, 29, 29, 12, 12, 19, 19, 27, 15, 21, 17, 25, 18,
      15, 15, 15, 15, 19, 24, 24, 25, 18, 16, 18, 17, 17, 19, 22, 23, 15, 17, 16, 20, 18, 11);

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
        when Table_Camera_Control_Mode => 3,
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
   Values_Length : constant := 3671;
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
     & "PS-RESCUESTAGE1KILLSTAGE2OFFONBEEPDISARMHARDWARE_PWMSOFTWARE_PWMDACNONEI2CSPISLAVEHALFNOMINALDOUBLEVBATEXTA"
     & "DCCONSTNONEHCSR04TFMINITF02MTF01MTF02MTF01PMTF02PTFNOVANOOPLOOP_F2NOOPLOOP_F2PNOOPLOOP_F2PHNOOPLOOP_FNOOPLO"
     & "OP_FPNOOPLOOP_F2MINIUPT1NONEMTUPT1AUTONONEMS4525AUTOGPS_ONLYOPTICALFLOW_ONLYOFFYAWALLBETAFLIGHTRACEFLIGHTKI"
     & "SSACTUALQUICKOFF192MHZ216MHZ240MHZGRBRGBGRBWOFFSCALECLIPAUTOPALNTSCHDOFFRPRPYRP_INCRPY_INCGYROSETPOINTROLLP"
     & "ITCHROLLPITCHYAWTHROTTLEOFFONUNTIL_FIRST_ARMOFFSPISDIONORMALPITCHONLYFULLPDDOFFI_FREEZEIPIDPD_I_FREEZERACEB"
     & "EACONSTATUSBLACKWHITEREDORANGEYELLOWLIME_GREENGREENMINT_GREENCYANLIGHT_BLUEBLUEDARK_VIOLETMAGENTADEEP_PINKR"
     & "OLLPITCHYAWDEFAULTBARO_ONLYGPS_ONLYRANGEFINDER_PREFERRANGEFINDER_ONLYOFFONAUTOOFF2_POINT3_POINT4_POINTAUTOT"
     & "IM1TIM8NONEAUTOMAX7456MSPFRSKYOSDFBOSDNONERTC6705SMARTAUDIOTRAMPMSPOFFONFIRST_ARMINGNULLLFLEGACYLINEARDYNAM"
     & "ICEZLANDINGOFFRPRPYTRANSPARENTBLACKGRAYLIGHT_GRAYAU433AU915EU433EU868IN866FCC915ISM2400CE2400NONEILAPARCITI"
     & "MERERLTAUTO96001920038400576001152002304002500004000004608005000009216001000000150000020000002470000NONEFRS"
     & "KY_HUBHOTTLTMSMARTPORTMAVLINKIBUS                           ";

   type Value_Index is range 0 .. 617;
   type Value_Start is range 0 .. Values_Length;
   type Value_Length is range 0 .. Max_Value_Length;
   subtype Table_First_Index is Value_Index range 0 .. 506;

   Table_Firsts : constant array (Lookup_Table) of Table_First_Index :=
     (0, 2, 5, 15, 19, 25, 33, 38, 43, 46, 48, 51, 54, 58, 61, 66, 71, 74, 76, 93, 113, 117, 146, 161, 176, 287,
      298, 301, 305, 309, 312, 315, 319, 322, 326, 329, 332, 348, 351, 355, 358, 361, 366, 370, 373, 376, 380,
      385, 387, 389, 393, 396, 399, 402, 404, 409, 412, 426, 429, 434, 437, 441, 444, 450, 456, 459, 461, 465,
      468, 472, 480, 484, 500);

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
      2539, 2542, 2548, 2551, 2554, 2563, 2567, 2577, 2583, 2587, 2593, 2596, 2598, 2602, 2608, 2620, 2632,
      2635, 2639, 2642, 2645, 2650, 2654, 2661, 2667, 2671, 2677, 2682, 2686, 2692, 2698, 2702, 2707, 2712,
      2718, 2724, 2730, 2741, 2753, 2766, 2776, 2787, 2802, 2806, 2810, 2812, 2816, 2820, 2824, 2830, 2830,
      2834, 2842, 2858, 2861, 2864, 2867, 2877, 2887, 2891, 2897, 2902, 2905, 2911, 2917, 2923, 2926, 2929,
      2933, 2936, 2941, 2945, 2949, 2952, 2956, 2958, 2961, 2963, 2966, 2972, 2979, 2983, 2991, 2995, 3000,
      3004, 3009, 3012, 3020, 3023, 3025, 3040, 3043, 3046, 3050, 3056, 3065, 3069, 3071, 3072, 3075, 3083,
      3084, 3087, 3098, 3102, 3108, 3114, 3119, 3124, 3127, 3133, 3139, 3149, 3154, 3164, 3168, 3178, 3182,
      3193, 3200, 3209, 3213, 3218, 3221, 3228, 3237, 3245, 3263, 3279, 3282, 3284, 3288, 3291, 3298, 3305,
      3312, 3316, 3320, 3324, 3328, 3332, 3339, 3342, 3350, 3355, 3359, 3366, 3366, 3376, 3381, 3384, 3387,
      3389, 3401, 3405, 3407, 3413, 3419, 3426, 3435, 3438, 3440, 3443, 3454, 3459, 3463, 3473, 3478, 3483,
      3488, 3493, 3498, 3504, 3511, 3517, 3521, 3525, 3534, 3538, 3542, 3546, 3551, 3556, 3561, 3567, 3573,
      3579, 3585, 3591, 3597, 3603, 3610, 3617, 3624, 3631, 3635, 3644, 3648, 3651, 3660, 3667, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

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
      10, 9, 9, 7, 8, 8, 8, 11, 8, 8, 3, 2, 5, 3, 6, 3, 3, 3, 6, 3, 3, 9, 4, 10, 6, 4, 6, 3, 2, 4, 6, 12, 12, 3,
      4, 3, 3, 5, 4, 7, 6, 4, 6, 5, 4, 6, 6, 4, 5, 5, 6, 6, 6, 11, 12, 13, 10, 11, 15, 4, 4, 2, 4, 4, 4, 6, 0,
      4, 8, 16, 3, 3, 3, 10, 10, 4, 6, 5, 3, 6, 6, 6, 3, 3, 4, 3, 5, 4, 4, 3, 4, 2, 3, 2, 3, 6, 7, 4, 8, 4, 5,
      4, 5, 3, 8, 3, 2, 15, 3, 3, 4, 6, 9, 4, 2, 1, 3, 8, 1, 3, 11, 4, 6, 6, 5, 5, 3, 6, 6, 10, 5, 10, 4, 10, 4,
      11, 7, 9, 4, 5, 3, 7, 9, 8, 18, 16, 3, 2, 4, 3, 7, 7, 7, 4, 4, 4, 4, 4, 7, 3, 8, 5, 4, 7, 0, 10, 5, 3, 3,
      2, 12, 4, 2, 6, 6, 7, 9, 3, 2, 3, 11, 5, 4, 10, 5, 5, 5, 5, 5, 6, 7, 6, 4, 4, 9, 4, 4, 4, 5, 5, 5, 6, 6,
      6, 6, 6, 6, 6, 7, 7, 7, 7, 4, 9, 4, 3, 9, 7, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

   function Value_Name (T : Lookup_Table; Index : Natural) return String is
     (Value_Names
        (Natural (Value_Starts (Table_Firsts (T) + Value_Index (Index))) + 1
         .. Natural (Value_Starts (Table_Firsts (T) + Value_Index (Index)))
            + Natural (Value_Lengths (Table_Firsts (T) + Value_Index (Index)))));

end Adaflight.Settings_Table;
