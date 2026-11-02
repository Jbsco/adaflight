package body Adaflight.Settings_Table with SPARK_Mode is

   --  Each setting's limits and group as indexes into the tables of the distinct ones, so the info
   --  of every setting packs into a few bytes of flash.
   type Limit_Pair is record
      Min : Limit;
      Max : Limit;
   end record with Pack;

   type Limit_Index is range 0 .. 162;
   type Group_Index is range 0 .. 82;

   Limit_Pairs : constant array (Limit_Index) of Limit_Pair :=
     ((Min => -1800000000, Max => 1800000000), (Min => -900000000, Max => 900000000), (Min => -32768, Max => 32767),
      (Min => -32000, Max => 32000), (Min => -18000, Max => 18000), (Min => -16000, Max => 16000),
      (Min => -9000, Max => 9000), (Min => -3600, Max => 3600), (Min => -1000, Max => 1000),
      (Min => -780, Max => 780), (Min => -500, Max => 500), (Min => -450, Max => 450), (Min => -300, Max => 300),
      (Min => -180, Max => 360), (Min => -130, Max => 0), (Min => -128, Max => 100), (Min => -127, Max => 127),
      (Min => -100, Max => 100), (Min => -32, Max => 31), (Min => -30, Max => 20), (Min => -16, Max => 15),
      (Min => -15, Max => 16), (Min => -6, Max => 0), (Min => -3, Max => 0), (Min => -1, Max => 8),
      (Min => -1, Max => 127), (Min => -1, Max => 32767), (Min => 0, Max => 0), (Min => 0, Max => 1),
      (Min => 0, Max => 3), (Min => 0, Max => 5), (Min => 0, Max => 7), (Min => 0, Max => 8), (Min => 0, Max => 10),
      (Min => 0, Max => 12), (Min => 0, Max => 14), (Min => 0, Max => 15), (Min => 0, Max => 18),
      (Min => 0, Max => 20), (Min => 0, Max => 24), (Min => 0, Max => 30), (Min => 0, Max => 32),
      (Min => 0, Max => 41), (Min => 0, Max => 45), (Min => 0, Max => 50), (Min => 0, Max => 60),
      (Min => 0, Max => 70), (Min => 0, Max => 75), (Min => 0, Max => 80), (Min => 0, Max => 90),
      (Min => 0, Max => 95), (Min => 0, Max => 100), (Min => 0, Max => 119), (Min => 0, Max => 120),
      (Min => 0, Max => 150), (Min => 0, Max => 180), (Min => 0, Max => 200), (Min => 0, Max => 250),
      (Min => 0, Max => 255), (Min => 0, Max => 300), (Min => 0, Max => 359), (Min => 0, Max => 400),
      (Min => 0, Max => 500), (Min => 0, Max => 1000), (Min => 0, Max => 1700), (Min => 0, Max => 2000),
      (Min => 0, Max => 3000), (Min => 0, Max => 5000), (Min => 0, Max => 5999), (Min => 0, Max => 10000),
      (Min => 0, Max => 16000), (Min => 0, Max => 20000), (Min => 0, Max => 30000), (Min => 0, Max => 32000),
      (Min => 0, Max => 32767), (Min => 0, Max => 60000), (Min => 0, Max => 65535), (Min => 0, Max => 262143),
      (Min => 0, Max => 4294967295), (Min => 1, Max => 3), (Min => 1, Max => 4), (Min => 1, Max => 5),
      (Min => 1, Max => 9), (Min => 1, Max => 16), (Min => 1, Max => 18), (Min => 1, Max => 20),
      (Min => 1, Max => 45), (Min => 1, Max => 50), (Min => 1, Max => 60), (Min => 1, Max => 90),
      (Min => 1, Max => 100), (Min => 1, Max => 200), (Min => 1, Max => 250), (Min => 1, Max => 255),
      (Min => 1, Max => 900), (Min => 1, Max => 1000), (Min => 1, Max => 2000), (Min => 1, Max => 10000),
      (Min => 1, Max => 40000), (Min => 1, Max => 65535), (Min => 2, Max => 16), (Min => 2, Max => 30),
      (Min => 2, Max => 40), (Min => 2, Max => 50), (Min => 4, Max => 18), (Min => 4, Max => 255),
      (Min => 5, Max => 30), (Min => 5, Max => 50), (Min => 5, Max => 80), (Min => 5, Max => 100),
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
      557, 559, 560, 561, 568, 569, 570, 2044, 2045);

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
      In_Multirotor : Boolean;
      In_Wing    : Boolean;
   end record with Pack;

   Infos : constant array (Setting) of Packed_Info :=
     (Gyro_Hardware_Lpf =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gyro_Hardware_Lpf, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf1_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gyro_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf1_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf2_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gyro_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf2_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch1_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch1_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch2_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch2_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Calib_Duration =>
        (Kind => U16, Where => Master, How => Direct, Limits => 137, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Calib_Noise_Limit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Offset_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Limits => 8, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Overflow_Detect =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gyro_Overflow_Check, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Yaw_Spin_Recovery =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On_Auto, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => False),
      Yaw_Spin_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Limits => 151, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => False),
      Dyn_Notch_Count =>
        (Kind => U8, Where => Master, How => Direct, Limits => 31, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Dyn_Notch_Q =>
        (Kind => U16, Where => Master, How => Direct, Limits => 95, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Dyn_Notch_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 124, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Dyn_Notch_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 146, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => Master, How => Direct, Limits => 33, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Filter_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gyro_Filter_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Acc_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Acc_Hardware, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 21, In_Multirotor => True, In_Wing => True),
      Acc_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 21, In_Multirotor => True, In_Wing => True),
      Acc_Trim_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Limits => 12, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 21, In_Multirotor => True, In_Wing => True),
      Acc_Trim_Roll =>
        (Kind => I16, Where => Master, How => Direct, Limits => 12, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 21, In_Multirotor => True, In_Wing => True),
      Acc_Calibration =>
        (Kind => I16, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 21, In_Multirotor => True, In_Wing => True),
      Align_Mag =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Alignment, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_Align_Roll =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 7, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_Align_Pitch =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 7, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_Align_Yaw =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 7, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Mag_Hardware, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Mag_Calibration =>
        (Kind => I16, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 24, In_Multirotor => True, In_Wing => True),
      Baro_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 22, In_Multirotor => True, In_Wing => True),
      Baro_Spi_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 22, In_Multirotor => True, In_Wing => True),
      Baro_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 22, In_Multirotor => True, In_Wing => True),
      Baro_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 22, In_Multirotor => True, In_Wing => True),
      Baro_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baro_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 22, In_Multirotor => True, In_Wing => True),
      Baro_Drift =>
        (Kind => I16, Where => Master, How => Direct, Limits => 10, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 22, In_Multirotor => True, In_Wing => True),
      Pitot_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 79, In_Multirotor => True, In_Wing => True),
      Pitot_I2c_Device =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 30, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 79, In_Multirotor => True, In_Wing => True),
      Pitot_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 79, In_Multirotor => True, In_Wing => True),
      Pitot_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Pitot_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 79, In_Multirotor => True, In_Wing => True),
      Mid_Rc =>
        (Kind => U16, Where => Master, How => Direct, Limits => 160, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Min_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Max_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Channel =>
        (Kind => I8, Where => Master, How => Direct, Limits => 37, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Src_Frame_Errors =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Scale =>
        (Kind => U8, Where => Master, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Invert =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Src_Frame_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Smoothing =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Auto_Factor =>
        (Kind => U8, Where => Master, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Auto_Factor_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Setpoint_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Throttle_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Rc_Smoothing_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Fpv_Mix_Degrees =>
        (Kind => U8, Where => Master, How => Direct, Limits => 49, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Max_Aux_Channels =>
        (Kind => U8, Where => Master, How => Direct, Limits => 35, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Serialrx_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Serial_Rx, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Serialrx_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Spektrum_Sat_Bind =>
        (Kind => U8, Where => Master, How => Direct, Limits => 33, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Spektrum_Sat_Bind_Autoreset =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Srxl2_Unit_Id =>
        (Kind => U8, Where => Master, How => Direct, Limits => 36, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Srxl2_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Sbus_Baud_Fast =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Crsf_Use_Negotiated_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Airmode_Start_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rx_Min_Usec =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rx_Max_Usec =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Serialrx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rx_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Msp_Override_Channels_Mask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 77, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Msp_Override_Failsafe =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rx_Spi_Protocol =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Rx_Spi, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 63, In_Multirotor => True, In_Wing => True),
      Rx_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 63, In_Multirotor => True, In_Wing => True),
      Rx_Spi_Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 63, In_Multirotor => True, In_Wing => True),
      Adc_Device =>
        (Kind => I8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45, In_Multirotor => True, In_Wing => True),
      Adc_Vrefint_Calibration =>
        (Kind => U16, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45, In_Multirotor => True, In_Wing => True),
      Adc_Tempsensor_Calibration30 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45, In_Multirotor => True, In_Wing => True),
      Adc_Tempsensor_Calibration110 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45, In_Multirotor => True, In_Wing => True),
      Input_Filtering_Mode =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 44, In_Multirotor => True, In_Wing => True),
      Blackbox_Sample_Rate =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Blackbox_Sample_Rate, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Device =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Blackbox_Device, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Pids =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Rc =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 1, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Setpoint =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 2, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Bat =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 3, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Mag =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Alt =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 5, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Rssi =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 6, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Gyro =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 7, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Gyrounfilt =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 14, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Acc =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 9, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Attitude =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Debug =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 10, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Motors =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 11, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Servos =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 15, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Rpm =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 13, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Gps =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 12, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Disable_Pitot =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Blackbox_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_High_Resolution =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Blackbox_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 3, In_Multirotor => True, In_Wing => True),
      Max_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Min_Command =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Kv =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 98, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Idle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Dshot_Burst =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On_Auto, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Dshot_Bidir =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Dshot_Edt =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Dshot_Edt, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Dshot_Bitbang =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On_Auto, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Dshot_Bitbang_Timer =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Dshot_Bitbanged_Timer, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Use_Unsynced_Pwm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Pwm_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Motor_Pwm_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Pwm_Inversion =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Poles =>
        (Kind => U8, Where => Master, How => Direct, Limits => 105, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Output_Reordering =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length => 0,
         Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Thr_Corr_Value =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 23, In_Multirotor => True, In_Wing => True),
      Thr_Corr_Angle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 94, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 23, In_Multirotor => True, In_Wing => True),
      Failsafe_Delay =>
        (Kind => U8, Where => Master, How => Direct, Limits => 91, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Landing_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Switch_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Failsafe_Switch_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Throttle_Low_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Procedure =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Failsafe, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Recovery_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 91, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Stick_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Align_Board_Roll =>
        (Kind => I16, Where => Master, How => Direct, Limits => 13, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 1, In_Multirotor => True, In_Wing => True),
      Align_Board_Pitch =>
        (Kind => I16, Where => Master, How => Direct, Limits => 13, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 1, In_Multirotor => True, In_Wing => True),
      Align_Board_Yaw =>
        (Kind => I16, Where => Master, How => Direct, Limits => 13, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 1, In_Multirotor => True, In_Wing => True),
      Gimbal_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gimbal_Mode, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 2, In_Multirotor => True, In_Wing => True),
      Battery_Profile_Name =>
        (Kind => U8, Where => Battery_Profile, How => Text, Limits => 27, Table => Table_Off_On, Count => 8,
         Min_Length => 1, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Bat_Capacity =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Max_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Full_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Min_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Warning_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Cbat_Alert_Percent =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Force_Battery_Cell_Count =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 39, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Hysteresis =>
        (Kind => U8, Where => Master, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Current_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Current_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Battery_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Voltage_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Detect_Cell_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Use_Vbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Use_Cbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Cutoff_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Display_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Sag_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Ibat_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Duration_For_Warning =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Duration_For_Critical =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Scale =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 36, In_Multirotor => True, In_Wing => True),
      Vbat_Divider =>
        (Kind => U8, Where => Master, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 36, In_Multirotor => True, In_Wing => True),
      Vbat_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 36, In_Multirotor => True, In_Wing => True),
      Ibata_Scale =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 5, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 34, In_Multirotor => True, In_Wing => True),
      Ibata_Offset =>
        (Kind => I16, Where => Master, How => Direct, Limits => 3, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 34, In_Multirotor => True, In_Wing => True),
      Ibatv_Scale =>
        (Kind => I16, Where => Master, How => Direct, Limits => 5, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 35, In_Multirotor => True, In_Wing => True),
      Ibatv_Offset =>
        (Kind => U16, Where => Master, How => Direct, Limits => 70, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 35, In_Multirotor => True, In_Wing => True),
      Battery_Continue =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Beeper_Inversion =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 40, In_Multirotor => True, In_Wing => True),
      Beeper_Od =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 40, In_Multirotor => True, In_Wing => True),
      Beeper_Frequency =>
        (Kind => I16, Where => Hardware, How => Direct, Limits => 70, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 40, In_Multirotor => True, In_Wing => True),
      Beeper_Dshot_Beacon_Tone =>
        (Kind => U8, Where => Master, How => Direct, Limits => 81, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 39, In_Multirotor => True, In_Wing => True),
      Yaw_Motors_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Mixer_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Mixer_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Crashflip_Motor_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Crashflip_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Crashflip_Auto_Rearm =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_P =>
        (Kind => U16, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_I =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_D =>
        (Kind => U16, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_Value =>
        (Kind => U16, Where => Master, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Three_D_Deadband_Low =>
        (Kind => U16, Where => Master, How => Direct, Limits => 155, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Deadband_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 162, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Neutral =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Deadband_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Limit_Low =>
        (Kind => U16, Where => Master, How => Direct, Limits => 155, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Limit_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 162, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Switched_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Servo_Center_Pulse =>
        (Kind => U16, Where => Master, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Servo_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Servo_Lowpass_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Tri_Unarmed_Servo =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Channel_Forwarding_Start =>
        (Kind => U8, Where => Master, How => Direct, Limits => 104, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Rateprofile_Name =>
        (Kind => U8, Where => Rate_Profile, How => Text, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length
         => 1, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Thr_Mid =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Thr_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Thr_Hover =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Rates_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 27, Table => Table_Rates_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Quickrates_Rc_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Throttle_Limit_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 27, Table => Table_Throttle_Limit_Type, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Throttle_Limit_Percent =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 127, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 147, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 147, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 147, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Reboot_Character =>
        (Kind => U8, Where => Master, How => Direct, Limits => 131, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 8, In_Multirotor => True, In_Wing => True),
      Serial_Update_Rate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 142, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 8, In_Multirotor => True, In_Wing => True),
      Imu_Dcm_Kp =>
        (Kind => U16, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Imu_Dcm_Ki =>
        (Kind => U16, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Small_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 55, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Imu_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Limits => 80, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Mag_Declination =>
        (Kind => I16, Where => Master, How => Direct, Limits => 12, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Auto_Disarm_Delay =>
        (Kind => U8, Where => Master, How => Direct, Limits => 45, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 10, In_Multirotor => True, In_Wing => True),
      Gyro_Cal_On_First_Arm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 10, In_Multirotor => True, In_Wing => True),
      Prearm_Allow_Rearm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 10, In_Multirotor => True, In_Wing => True),
      Gps_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Provider, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Sbas_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Sbas_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Auto_Config =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Auto_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Ublox_Acquire_Model =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Ublox_Models, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Ublox_Flight_Model =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Ublox_Models, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Update_Rate_Hz =>
        (Kind => U8, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Ublox_Utc_Standard =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Ublox_Utc_Standard, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Ublox_Use_Galileo =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Ublox_Enable_Ana =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Set_Home_Point_Once =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Use_3d_Speed =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Sbas_Integrity =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Nmea_Custom_Commands =>
        (Kind => U8, Where => Master, How => Text, Limits => 27, Table => Table_Off_On, Count => 64, Min_Length => 1,
         Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 19, In_Multirotor => True, In_Wing => True),
      Gps_Rescue_Min_Start_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 106, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Alt_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Rescue_Alt_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Initial_Climb =>
        (Kind => U16, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Ascend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 136, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Return_Alt =>
        (Kind => U16, Where => Master, How => Direct, Limits => 111, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Ground_Speed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Descent_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Descend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 129, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Sanity_Checks =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Rescue_Sanity_Check, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Min_Sats =>
        (Kind => U8, Where => Master, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Allow_Arming_Without_Fix =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Lap_Timer_Gate_Lat =>
        (Kind => I32, Where => Master, How => Direct, Limits => 1, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Gps_Lap_Timer_Gate_Lon =>
        (Kind => I32, Where => Master, How => Direct, Limits => 0, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Gps_Lap_Timer_Min_Lap_Time_S =>
        (Kind => U16, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Gps_Lap_Timer_Gate_Tolerance_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 41, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16, In_Multirotor => True, In_Wing => True),
      Yaw_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16, In_Multirotor => True, In_Wing => True),
      Yaw_Control_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16, In_Multirotor => True, In_Wing => True),
      Alt_Hold_Climb_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 31, In_Multirotor => True, In_Wing => False),
      Alt_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 46, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 31, In_Multirotor => True, In_Wing => False),
      Pos_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Poshold_Position_Source =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Poshold_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Poshold_Opticalflow_Quality_Min =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Poshold_Opticalflow_Max_Range =>
        (Kind => U16, Where => Master, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Launch_Climb_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 43, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Max_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Detect_Accel =>
        (Kind => U8, Where => Master, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Detect_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 140, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Detect_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 120, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Idle_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Idle_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Motor_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Spinup_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Min_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Timeout =>
        (Kind => U16, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Max_Altitude =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_End_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Abort_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Abort_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 49, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Pid_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Limits => 83, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => True),
      Runaway_Takeoff_Prevention =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => False),
      Runaway_Takeoff_Deactivate_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 140, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => False),
      Runaway_Takeoff_Deactivate_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => False),
      Profile_Name =>
        (Kind => U8, Where => PID_Profile, How => Text, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length =>
         1, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 33, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Dterm_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf2_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Dterm_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf2_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Notch_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Notch_Cutoff =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Vbat_Sag_Compensation =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Pid_At_Min_Throttle =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Anti_Gravity_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Anti_Gravity_Cutoff_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 103, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Anti_Gravity_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acc_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acc_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Dthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 121, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Gthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 142, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Setpoint_Threshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Time =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Recovery_Angle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 106, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Recovery_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Recovery =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Crash_Recovery, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Iterm_Rotation =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Iterm_Relax =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Iterm_Relax, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Iterm_Relax_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Iterm_Relax_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Iterm_Relax_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Iterm_Windup =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 123, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Pidsum_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 140, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Pidsum_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 140, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Yaw_Lowpass_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Throttle_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Throttle_Boost_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Lookahead_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Debug_Axis =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Acro_Trainer_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      P_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      I_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      F_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      P_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      I_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      F_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      P_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      I_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      F_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      S_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      S_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      S_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Angle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Feedforward =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Feedforward_Smoothing_Ms =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 117, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Earth_Ref =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Level_Strength =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Limit_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Limit_Degrees =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 117, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Ignore_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Delay_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 122, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Lag_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Lead_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Amplitude_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Amplitude_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Amplitude_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Frequency_Start_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 95, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Frequency_End_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 97, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Time_Seconds =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Repeat =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 82, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Advance =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Motor_Output_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Auto_Profile_Cell_Count =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 24, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Launch_Control_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Launch_Control_Mode, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Launch_Trigger_Allow_Reset =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Launch_Trigger_Throttle_Percent =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 49, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Launch_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 48, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Launch_Control_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Thrust_Linear =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Transition =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Averaging =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Feedforward_Averaging, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Smooth_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 50, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Jitter_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 38, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Max_Rate_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Yaw_Hold_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Yaw_Hold_Time =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 117, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_Min_Rpm =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 92, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 92, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_Max_Increase =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 118, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Level_Race_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pids_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Simplified_Tuning_Pids_Mode,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Master_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Feedforward_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pitch_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pitch_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Dterm_Filter =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Dterm_Filter_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Gyro_Filter =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Simplified_Gyro_Filter_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Tpa_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Tpa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 157, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Low_Rate =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Low_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 157, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Low_Always =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Speed_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Tpa_Speed_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Basic_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Basic_Gravity =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Prop_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Mass =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Drag_K =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Thrust =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Max_Voltage =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Pitch_Offset =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 2, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Tpa_Curve_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Stall_Throttle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Pid_Thr0 =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Pid_Thr100 =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Expo =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Ez_Landing_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Ez_Landing_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 47, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Ez_Landing_Speed =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Landing_Disarm_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Spa_Roll_Center =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Roll_Width =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Roll_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Spa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Pitch_Center =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Pitch_Width =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Pitch_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Spa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Yaw_Center =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Yaw_Width =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Yaw_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Spa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Yaw_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Yaw_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Angle_Pitch_Offset =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 11, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tlm_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Tlm_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_1_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Telemetry_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_1_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_2_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Telemetry_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_2_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_3_Protocol =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Telemetry_Protocol, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_3_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Crsf_Tlm_Accgyro =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Frsky_Default_Lat =>
        (Kind => I16, Where => Master, How => Direct, Limits => 6, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Frsky_Default_Long =>
        (Kind => I16, Where => Master, How => Direct, Limits => 4, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Frsky_Gps_Format =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Frsky_Unit =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Unit, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Frsky_Vfas_Precision =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Hott_Alarm_Int =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Pid_In_Tlm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Report_Cell_Voltage =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Ibus_Sensor =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 15, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Mah_As_Heading_Divisor =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Min_Txbuff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Ext_Status_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Rc_Chan_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Pos_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Extra1_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Extra2_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Extra3_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Current =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 1, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Fuel =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 2, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Mode =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 3, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Acc_X =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Acc_Y =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 5, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Acc_Z =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 6, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Pitch =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 7, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Roll =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Heading =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 9, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Altitude =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 10, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Vario =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 11, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Lat_Long =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 12, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Ground_Speed =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 13, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Distance =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 14, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Esc_Current =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 15, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Esc_Voltage =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Esc_Rpm =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 17, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Esc_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 18, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Temperature =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 19, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Telemetry_Disabled_Cap_Used =>
        (Kind => U32, Where => Master, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 20, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Ledstrip_Visual_Beeper =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Visual_Beeper_Color =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Grb_Rgb =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Rgb_Grb, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Profile =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Led_Profile, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Race_Color =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Beacon_Color =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ledstrip_Color, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Beacon_Period_Ms =>
        (Kind => U16, Where => Master, How => Direct, Limits => 138, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Beacon_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Beacon_Armed_Only =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Brightness =>
        (Kind => U8, Where => Master, How => Direct, Limits => 109, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Rainbow_Delta =>
        (Kind => U16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Rainbow_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 96, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Transponder_Provider =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Transponder_Provider, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 11, In_Multirotor => True, In_Wing => True),
      Transponder_Data =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 9, Min_Length => 0,
         Write_Once => False, Group => 11, In_Multirotor => True, In_Wing => True),
      Sdcard_Detect_Inverted =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 46, In_Multirotor => True, In_Wing => True),
      Sdcard_Mode =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Sdcard_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 46, In_Multirotor => True, In_Wing => True),
      Sdcard_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 46, In_Multirotor => True, In_Wing => True),
      Osd_Units =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Unit, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Warn_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Link_Quality_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Dbm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rsnr_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 19, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Cap_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Alt_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 69, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Distance_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Rpm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Current_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Core_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Max_Pit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 49, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Max_Rol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 49, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Invert =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Logo_On_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Osd_Logo_On_Arming, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Logo_On_Arming_Duration =>
        (Kind => U8, Where => Master, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Arming_Logo =>
        (Kind => U8, Where => Master, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Use_Quick_Menu =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Show_Spec_Prearm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Tim1 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Tim2 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Vbat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Link_Quality_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Link_Tx_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Dbm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rsnr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Tim_1_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Tim_2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Remaining_Time_Estimate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Flymode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Anti_Gravity_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_G_Force_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Throttle_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Vtx_Channel_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Crosshairs_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Sbar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Current_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Mah_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wh_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Motor_Diag_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Craft_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pilot_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lap_Curr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lap_Prev_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lap_Best3_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Sats_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Home_Dir_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Home_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Flight_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Compass_Bar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Altitude_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Roll_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Pitch_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Yaw_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Debug_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Debug2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pidrate_Profile_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Avg_Cell_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pit_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rol_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Battery_Usage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Disarmed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Nheading_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Up_Down_Reference_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Ready_Mode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pos_Hold_Ready_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Nvario_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Tmp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Rpm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Rpm_Freq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rtc_Date_Time_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Adjustment_Range_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Flip_Arrow_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Core_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Log_Status_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stick_Overlay_Left_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stick_Overlay_Right_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stick_Overlay_Radio_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 80, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rate_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Battery_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rcchannels_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Camera_Frame_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Efficiency_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Total_Flights_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Goggle_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Vtx_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Bitrate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Delay_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Lq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Goggle_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Vtx_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Vtx_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Fan_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stat_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Profile =>
        (Kind => U8, Where => Master, How => Direct, Limits => 79, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Profile_1_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Profile_2_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Profile_3_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Sats_Show_Pdop =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Displayport_Device =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Osd_Displayport_Device, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rcchannels =>
        (Kind => I8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Camera_Frame_Width =>
        (Kind => U8, Where => Master, How => Direct, Limits => 101, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Camera_Frame_Height =>
        (Kind => U8, Where => Master, How => Direct, Limits => 100, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Stat_Avg_Cell_Value =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Framerate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Menu_Background =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Cms_Background, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Channel =>
        (Kind => U8, Where => Master, How => Direct, Limits => 84, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Scale =>
        (Kind => U16, Where => Master, How => Direct, Limits => 95, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Symbol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Craftname_Msgs =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Lidar_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Custom_Serial_Text_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Custom_Serial_Text_Terminator =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Osd_Custom_Text_Terminator, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 81, In_Multirotor => True, In_Wing => True),
      Osd_Custom_Text_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Custom_Text_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Current_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Current_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Current_Alt_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Direction_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Next_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Eta_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Nav_Map_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => False),
      Osd_Nav_Map_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 78, In_Multirotor => True, In_Wing => False),
      Osd_Nav_Map_Centre =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 78, In_Multirotor => True, In_Wing => False),
      Osd_Nav_Map_Min_Scale_M =>
        (Kind => U16, Where => Master, How => Direct, Limits => 126, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 78, In_Multirotor => True, In_Wing => False),
      Osd_Airspeed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      System_Hse_Mhz =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 12, In_Multirotor => True, In_Wing => True),
      Task_Statistics =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12, In_Multirotor => True, In_Wing => True),
      Debug_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Debug, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12, In_Multirotor => True, In_Wing => True),
      Rate_6pos_Switch =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12, In_Multirotor => True, In_Wing => True),
      Cpu_Overclock =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Overclock, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 12, In_Multirotor => True, In_Wing => True),
      Pwr_On_Arm_Grace =>
        (Kind => U8, Where => Master, How => Direct, Limits => 40, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12, In_Multirotor => True, In_Wing => True),
      Enable_Stick_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 12, In_Multirotor => True, In_Wing => True),
      Vtx_Band =>
        (Kind => U8, Where => Master, How => Direct, Limits => 32, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Channel =>
        (Kind => U8, Where => Master, How => Direct, Limits => 32, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Power =>
        (Kind => U8, Where => Master, How => Direct, Limits => 31, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Low_Power_Disarm =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Vtx_Low_Power_Disarm, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Softserial_Alt =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Vtx_Type, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 68, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Pit_Mode_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 68, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 50, In_Multirotor => True, In_Wing => True),
      Vtx_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 29, In_Multirotor => True, In_Wing => True),
      Vcd_Video_System =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Video_System, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 49, In_Multirotor => True, In_Wing => True),
      Vcd_H_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 18, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 49, In_Multirotor => True, In_Wing => True),
      Vcd_V_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 21, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 49, In_Multirotor => True, In_Wing => True),
      Max7456_Clock =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Max7456_Clock, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 56, In_Multirotor => True, In_Wing => True),
      Max7456_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 56, In_Multirotor => True, In_Wing => True),
      Max7456_Preinit_Opu =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 56, In_Multirotor => True, In_Wing => True),
      Displayport_Msp_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 22, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 47, In_Multirotor => True, In_Wing => True),
      Displayport_Msp_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 23, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 47, In_Multirotor => True, In_Wing => True),
      Displayport_Msp_Fonts =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 47, In_Multirotor => True, In_Wing => True),
      Displayport_Msp_Use_Device_Blink =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 47, In_Multirotor => True, In_Wing => True),
      Displayport_Max7456_Col_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 22, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48, In_Multirotor => True, In_Wing => True),
      Displayport_Max7456_Row_Adjust =>
        (Kind => I8, Where => Master, How => Direct, Limits => 23, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48, In_Multirotor => True, In_Wing => True),
      Displayport_Max7456_Inv =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48, In_Multirotor => True, In_Wing => True),
      Displayport_Max7456_Blk =>
        (Kind => U8, Where => Master, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48, In_Multirotor => True, In_Wing => True),
      Displayport_Max7456_Wht =>
        (Kind => U8, Where => Master, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 48, In_Multirotor => True, In_Wing => True),
      Esc_Sensor_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 51, In_Multirotor => True, In_Wing => True),
      Esc_Sensor_Current_Offset =>
        (Kind => U16, Where => Master, How => Direct, Limits => 70, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 51, In_Multirotor => True, In_Wing => True),
      Esc_Sensor_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 51, In_Multirotor => True, In_Wing => True),
      Frsky_Spi_Autobind =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 55, In_Multirotor => True, In_Wing => True),
      Frsky_Spi_Tx_Id =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 55, In_Multirotor => True, In_Wing => True),
      Frsky_Spi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 16, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 55, In_Multirotor => True, In_Wing => True),
      Frsky_Spi_Bind_Hop_Data =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 50, Min_Length => 0,
         Write_Once => False, Group => 55, In_Multirotor => True, In_Wing => True),
      Frsky_X_Rx_Num =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 55, In_Multirotor => True, In_Wing => True),
      Frsky_Spi_A1_Source =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Rx_Frsky_Spi_A1_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 55, In_Multirotor => True, In_Wing => True),
      Cc2500_Spi_Chip_Detect =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 55, In_Multirotor => True, In_Wing => True),
      Led_Inversion =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 31, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 42, In_Multirotor => True, In_Wing => True),
      Dashboard_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 53, In_Multirotor => True, In_Wing => True),
      Dashboard_I2c_Addr =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 112, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 53, In_Multirotor => True, In_Wing => True),
      Camera_Control_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Camera_Control_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Ref_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Limits => 145, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Key_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Internal_Resistance =>
        (Kind => U16, Where => Master, How => Direct, Limits => 120, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Button_Resistance =>
        (Kind => U16, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 5, Min_Length => 0,
         Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Inverted =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Rangefinder_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Rangefinder_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 59, In_Multirotor => True, In_Wing => True),
      Rangefinder_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 59, In_Multirotor => True, In_Wing => True),
      Opticalflow_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Opticalflow_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 76, In_Multirotor => True, In_Wing => True),
      Opticalflow_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 76, In_Multirotor => True, In_Wing => True),
      Opticalflow_Rotation =>
        (Kind => I16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 76, In_Multirotor => True, In_Wing => True),
      Opticalflow_Flip_X =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 76, In_Multirotor => True, In_Wing => True),
      Pinio_Config =>
        (Kind => U8, Where => Hardware, How => List, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 60, In_Multirotor => True, In_Wing => True),
      Pinio_Box =>
        (Kind => U8, Where => Hardware, How => List, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 61, In_Multirotor => True, In_Wing => True),
      Usb_Hid_Cdc =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 62, In_Multirotor => True, In_Wing => True),
      Usb_Msc_Pin_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 62, In_Multirotor => True, In_Wing => True),
      Flash_Spi_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 43, In_Multirotor => True, In_Wing => True),
      Rcdevice_Init_Dev_Attempts =>
        (Kind => U8, Where => Master, How => Direct, Limits => 33, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 64, In_Multirotor => True, In_Wing => True),
      Rcdevice_Init_Dev_Attempt_Interval =>
        (Kind => U32, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64, In_Multirotor => True, In_Wing => True),
      Rcdevice_Protocol_Version =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 64, In_Multirotor => True, In_Wing => True),
      Rcdevice_Feature =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64, In_Multirotor => True, In_Wing => True),
      Rcdevice_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 64, In_Multirotor => True, In_Wing => True),
      Gyro_1_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      Gyro_1_Spibus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      Gyro_1_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      Gyro_1_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      I2c1_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c1_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c2_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c2_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c3_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c3_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      Mco2_On_Pc9 =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 66, In_Multirotor => True, In_Wing => True),
      Spektrum_Spi_Protocol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 67, In_Multirotor => True, In_Wing => True),
      Spektrum_Spi_Mfg_Id =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 4, Min_Length => 0,
         Write_Once => False, Group => 67, In_Multirotor => True, In_Wing => True),
      Spektrum_Spi_Num_Channels =>
        (Kind => U8, Where => Master, How => Direct, Limits => 34, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 67, In_Multirotor => True, In_Wing => True),
      Expresslrs_Uid =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 6, Min_Length => 0,
         Write_Once => False, Group => 72, In_Multirotor => True, In_Wing => True),
      Expresslrs_Domain =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Freq_Domain, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 72, In_Multirotor => True, In_Wing => True),
      Expresslrs_Model_Id =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 72, In_Multirotor => True, In_Wing => True),
      Scheduler_Relax_Rx =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73, In_Multirotor => True, In_Wing => True),
      Scheduler_Relax_Osd =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73, In_Multirotor => True, In_Wing => True),
      Scheduler_Debug_Task =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 42, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73, In_Multirotor => True, In_Wing => True),
      Cpu_Late_Limit_Permille =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 73, In_Multirotor => True, In_Wing => True),
      Serialmsp_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 74, In_Multirotor => True, In_Wing => True),
      Msp_1_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 74, In_Multirotor => True, In_Wing => True),
      Msp_1_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 74, In_Multirotor => True, In_Wing => True),
      Msp_2_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 74, In_Multirotor => True, In_Wing => True),
      Msp_2_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 74, In_Multirotor => True, In_Wing => True),
      Msp_3_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 74, In_Multirotor => True, In_Wing => True),
      Msp_3_Baud =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Baud_Rate, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 74, In_Multirotor => True, In_Wing => True),
      Timezone_Offset_Minutes =>
        (Kind => I16, Where => Master, How => Direct, Limits => 9, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 58, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Harmonics =>
        (Kind => U8, Where => Master, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Weights =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 3, Min_Length => 0,
         Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Q =>
        (Kind => U16, Where => Master, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Min_Hz =>
        (Kind => U8, Where => Master, How => Direct, Limits => 130, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Fade_Range_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Flysky_Spi_Tx_Id =>
        (Kind => U32, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 57, In_Multirotor => True, In_Wing => True),
      Flysky_Spi_Rf_Channels =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length => 0,
         Write_Once => False, Group => 57, In_Multirotor => True, In_Wing => True),
      Stats_Min_Armed_Time_S =>
        (Kind => I8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Total_Flights =>
        (Kind => U32, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Total_Time_S =>
        (Kind => U32, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Total_Dist_M =>
        (Kind => U32, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Save_Move_Limit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Mah_Used =>
        (Kind => U32, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Craft_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 25, In_Multirotor => True, In_Wing => True),
      Pilot_Name =>
        (Kind => U8, Where => Master, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length => 1,
         Write_Once => False, Group => 25, In_Multirotor => True, In_Wing => True),
      Altitude_Source =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Position_Alt_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Altitude_Prefer_Baro =>
        (Kind => I8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Altitude_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Limits => 122, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Rangefinder_Max_Range_Cm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Altitude_D_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Limits => 122, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Ap_Landing_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Hover_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 64, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Throttle_Min =>
        (Kind => U16, Where => Master, How => Direct, Limits => 159, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Throttle_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 161, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_I =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_D =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_A =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_F =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_I =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_D =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_A =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_F =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 113, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Stop_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 114, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Yaw_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 117, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Velocity_Drag_Coeff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Waypoint_Arrival_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Waypoint_Hold_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Stick_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Throttle_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Yaw_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ap_Yaw_Mode, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Min_Forward_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 119, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Corner_Speed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Corner_Delta_V =>
        (Kind => U16, Where => Master, How => Direct, Limits => 143, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Decel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Accel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Carrot_Lead_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Carrot_Lead_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 154, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Preturn_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 152, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Velocity_Buildup_Max_Pitch =>
        (Kind => U8, Where => Master, How => Direct, Limits => 38, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 89, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Hold_Orbit_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Hold_Figure8_Width =>
        (Kind => U16, Where => Master, How => Direct, Limits => 153, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Descent_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Detection_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Spiral_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Spiral_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Spiral_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 86, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Velocity_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Throttle_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Limits => 119, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Period =>
        (Kind => U16, Where => Master, How => Direct, Limits => 109, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Min_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Max_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Limits => 158, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Max_Cross_Track_Error =>
        (Kind => U16, Where => Master, How => Direct, Limits => 158, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 49, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Min_Nav_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 44, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Rx_Loss_Policy =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ap_Rx_Loss_Policy, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Distance_From_Home =>
        (Kind => U16, Where => Master, How => Direct, Limits => 69, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Geofence_Action =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ap_Geofence_Action, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Box_User_1_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 70, In_Multirotor => True, In_Wing => True),
      Box_User_2_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 70, In_Multirotor => True, In_Wing => True),
      Box_User_3_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 70, In_Multirotor => True, In_Wing => True),
      Box_User_4_Name =>
        (Kind => U8, Where => Hardware, How => Text, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length =>
         1, Write_Once => False, Group => 70, In_Multirotor => True, In_Wing => True),
      Gimbal_Roll_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Pitch_Rc_Thr_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Pitch_Rc_Low_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Pitch_Rc_High_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Yaw_Rc_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Roll_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Roll_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Roll_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Pitch_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Pitch_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Pitch_Low_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Pitch_High_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Yaw_Gain =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Yaw_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Yaw_Limit =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Stabilisation =>
        (Kind => I8, Where => Master, How => Direct, Limits => 31, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Sensitivity =>
        (Kind => I8, Where => Master, How => Direct, Limits => 20, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True),
      Gimbal_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 75, In_Multirotor => True, In_Wing => True));

   --  The limits of a setting in a build, where the wing build has others.
   function Limits_Of (S : Setting; Wing : Boolean) return Limit_Index is
     (if Wing then (case S is when Tpa_Low_Rate => 15, when others => Infos (S).Limits)
      else Infos (S).Limits);

   function In_Build (S : Setting; Wing : Boolean) return Boolean is
     (if Wing then Infos (S).In_Wing else Infos (S).In_Multirotor);

   function Table_In_Build (T : Lookup_Table; Wing : Boolean) return Boolean is
     (case T is
         when Table_Ap_Yaw_Mode | Table_Ap_Rx_Loss_Policy | Table_Ap_Geofence_Action
           | Table_Launch_Control_Mode => not Wing,
         when Table_Tpa_Curve_Type | Table_Tpa_Speed_Type | Table_Yaw_Type => Wing,
         when others => True);

   function Describe (S : Setting; Wing : Boolean := False) return Info is
     (Kind => Infos (S).Kind, Where => Infos (S).Where, How => Infos (S).How,
      Min => Limit_Pairs (Limits_Of (S, Wing)).Min, Max => Limit_Pairs (Limits_Of (S, Wing)).Max,
      Table => Infos (S).Table, Count => Infos (S).Count, Min_Length => Infos (S).Min_Length,
      Write_Once => Infos (S).Write_Once, Group => Group_Numbers (Infos (S).Group));

   --  The setting names in codes: a code below 128 is a character, a higher one the token of its
   --  pair merge. Each name starts at its start and decodes to its length, and the codes and the
   --  tokens end with room for a longest name and token, so every read stays within them by the
   --  types alone.
   Name_Codes_Length : constant := 8077;
   subtype Name_Code_Index is Natural range 0 .. Name_Codes_Length + Max_Name_Length - 1;

   --  The code at an index, outside the proof: the decoder needs no fact about the codes.
   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8;

   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8 with SPARK_Mode => Off is
      Codes : constant array (Name_Code_Index) of Interfaces.Unsigned_8 :=
        (220, 161, 141, 100, 228, 130, 108, 234, 220, 157, 234, 49, 153, 121, 171, 220, 157, 234, 49, 142, 116,
         137, 207, 235, 220, 157, 234, 50, 153, 121, 171, 220, 157, 234, 50, 142, 116, 137, 207, 235, 220, 229,
         162, 147, 49, 235, 220, 229, 162, 147, 49, 150, 208, 221, 220, 229, 162, 147, 50, 235, 220, 229, 162,
         147, 50, 150, 208, 221, 220, 150, 139, 105, 98, 138, 222, 137, 197, 220, 150, 139, 105, 98, 229, 111,
         149, 130, 108, 199, 220, 95, 221, 115, 158, 95, 182, 220, 95, 111, 216, 102, 204, 119, 138, 158, 101,
         99, 116, 182, 142, 112, 132, 95, 145, 99, 111, 216, 121, 182, 142, 112, 132, 153, 104, 192, 104, 164,
         100, 100, 121, 110, 229, 162, 147, 150, 111, 188, 116, 100, 121, 110, 229, 162, 147, 95, 113, 100, 121,
         110, 229, 162, 147, 148, 132, 235, 100, 121, 110, 229, 162, 147, 232, 120, 235, 220, 157, 234, 49, 138,
         121, 110, 148, 132, 235, 220, 157, 234, 49, 138, 121, 110, 232, 120, 235, 220, 157, 234, 49, 138, 121,
         110, 95, 253, 112, 111, 220, 95, 169, 108, 187, 183, 98, 117, 103, 95, 97, 120, 149, 193, 99, 161, 141,
         100, 228, 101, 193, 99, 157, 234, 235, 193, 99, 153, 114, 144, 133, 189, 193, 99, 153, 114, 144, 95,
         236, 193, 99, 150, 139, 105, 98, 114, 137, 197, 139, 105, 103, 110, 232, 103, 167, 103, 244, 105, 103,
         110, 95, 236, 167, 103, 244, 105, 103, 110, 133, 189, 167, 103, 244, 105, 103, 110, 95, 182, 167, 103,
         168, 117, 159, 121, 171, 167, 103, 95, 105, 50, 99, 183, 118, 207, 101, 167, 103, 95, 105, 50, 99, 95,
         175, 100, 192, 115, 167, 103, 237, 183, 118, 207, 101, 167, 103, 161, 141, 100, 228, 101, 167, 103,
         150, 139, 105, 98, 114, 137, 197, 98, 97, 136, 168, 117, 159, 121, 171, 98, 97, 136, 237, 183, 118,
         207, 101, 98, 97, 136, 95, 105, 50, 99, 183, 118, 207, 101, 98, 97, 136, 95, 105, 50, 99, 95, 175, 100,
         192, 115, 98, 97, 136, 161, 141, 100, 228, 101, 98, 97, 136, 138, 114, 105, 102, 116, 112, 135, 162,
         168, 117, 159, 121, 171, 112, 135, 162, 95, 105, 50, 99, 183, 118, 207, 101, 112, 135, 162, 95, 105,
         50, 99, 95, 175, 100, 192, 115, 112, 135, 162, 161, 141, 100, 228, 101, 109, 105, 128, 114, 99, 109,
         132, 95, 147, 101, 174, 167, 181, 147, 101, 174, 198, 115, 105, 95, 147, 155, 110, 101, 108, 198, 115,
         105, 142, 114, 99, 230, 180, 109, 130, 131, 136, 198, 198, 115, 105, 142, 99, 139, 101, 198, 115, 105,
         95, 221, 115, 158, 198, 115, 105, 95, 132, 216, 116, 198, 115, 105, 142, 114, 99, 230, 180, 109, 130,
         108, 234, 133, 131, 105, 111, 100, 198, 115, 105, 142, 109, 111, 162, 104, 185, 114, 99, 142, 109, 111,
         162, 104, 185, 114, 99, 142, 109, 111, 162, 104, 185, 95, 97, 208, 111, 230, 193, 116, 154, 114, 99,
         142, 109, 111, 162, 104, 185, 95, 97, 208, 111, 230, 193, 116, 154, 153, 104, 238, 143, 114, 99, 142,
         109, 111, 162, 104, 185, 142, 158, 112, 111, 132, 116, 150, 208, 221, 114, 99, 142, 109, 111, 162, 104,
         185, 153, 104, 238, 156, 99, 208, 221, 114, 99, 142, 109, 111, 162, 104, 185, 183, 98, 117, 103, 95,
         97, 120, 149, 102, 112, 118, 148, 105, 120, 183, 103, 145, 101, 115, 167, 181, 97, 117, 181, 147, 155,
         110, 101, 108, 115, 115, 131, 105, 139, 114, 120, 133, 136, 118, 217, 131, 115, 131, 105, 139, 114,
         181, 132, 216, 179, 100, 115, 171, 107, 116, 114, 117, 109, 142, 137, 168, 132, 100, 115, 171, 107,
         116, 114, 117, 109, 142, 137, 168, 132, 128, 97, 208, 111, 192, 158, 115, 114, 120, 108, 50, 95, 188,
         135, 95, 217, 115, 114, 120, 108, 50, 168, 97, 117, 128, 102, 97, 159, 115, 98, 190, 168, 97, 117, 128,
         102, 97, 159, 99, 198, 102, 95, 190, 130, 110, 101, 103, 162, 105, 137, 195, 98, 97, 223, 97, 105, 114,
         109, 111, 100, 130, 159, 248, 153, 104, 238, 156, 112, 131, 99, 176, 116, 114, 120, 148, 132, 95, 190,
         101, 99, 114, 120, 232, 181, 190, 101, 99, 115, 131, 105, 139, 114, 120, 161, 139, 102, 100, 117, 112,
         143, 120, 114, 181, 117, 248, 109, 115, 140, 111, 216, 114, 217, 130, 147, 155, 110, 101, 108, 115,
         232, 115, 107, 109, 115, 140, 111, 216, 114, 217, 130, 102, 97, 105, 108, 115, 97, 102, 101, 114, 120,
         237, 133, 194, 111, 99, 164, 114, 120, 237, 168, 190, 114, 120, 237, 95, 239, 132, 216, 115, 197, 175,
         99, 183, 118, 207, 101, 175, 99, 254, 145, 102, 132, 116, 150, 139, 105, 98, 114, 137, 197, 175, 99,
         153, 101, 109, 172, 176, 115, 154, 150, 139, 105, 98, 114, 137, 197, 51, 48, 175, 99, 153, 101, 109,
         172, 176, 115, 154, 150, 139, 105, 98, 114, 137, 197, 49, 49, 48, 132, 112, 208, 95, 169, 108, 187,
         185, 148, 233, 245, 142, 200, 112, 156, 114, 209, 245, 183, 118, 207, 101, 245, 186, 156, 178, 100,
         115, 245, 186, 156, 114, 99, 245, 186, 156, 115, 158, 112, 111, 132, 116, 245, 186, 156, 201, 245, 186,
         156, 167, 103, 245, 186, 156, 139, 116, 245, 186, 156, 198, 115, 105, 245, 186, 156, 220, 245, 186,
         156, 220, 188, 169, 108, 116, 245, 186, 156, 193, 99, 245, 186, 156, 137, 116, 135, 117, 165, 245, 186,
         156, 165, 98, 117, 103, 245, 186, 156, 109, 162, 154, 115, 245, 186, 156, 115, 131, 118, 129, 245, 186,
         156, 114, 112, 109, 245, 186, 156, 177, 245, 186, 156, 112, 135, 162, 245, 148, 233, 245, 161, 105,
         103, 104, 95, 192, 164, 208, 197, 242, 181, 117, 248, 245, 168, 97, 223, 167, 120, 153, 104, 238, 143,
         109, 132, 150, 111, 109, 109, 155, 100, 109, 162, 154, 95, 107, 118, 109, 162, 154, 95, 217, 143, 100,
         243, 162, 168, 222, 159, 100, 243, 162, 168, 217, 105, 114, 100, 243, 162, 95, 224, 116, 100, 243, 162,
         168, 135, 98, 225, 100, 243, 162, 168, 135, 98, 225, 153, 144, 131, 190, 130, 188, 115, 121, 110, 99,
         195, 112, 119, 109, 109, 162, 154, 133, 119, 109, 133, 194, 111, 99, 164, 109, 162, 154, 133, 119, 109,
         255, 109, 162, 154, 133, 119, 109, 95, 132, 216, 115, 197, 109, 162, 154, 133, 111, 143, 115, 109, 162,
         154, 95, 111, 208, 112, 208, 95, 145, 154, 100, 131, 185, 202, 114, 150, 154, 114, 254, 139, 117, 101,
         202, 114, 150, 154, 114, 95, 225, 143, 102, 97, 105, 108, 115, 97, 102, 130, 165, 226, 102, 97, 105,
         108, 115, 97, 102, 130, 146, 110, 100, 185, 153, 144, 101, 102, 97, 105, 108, 115, 97, 102, 130, 202,
         238, 143, 102, 97, 105, 108, 115, 97, 102, 130, 115, 119, 189, 148, 233, 102, 97, 105, 108, 115, 97,
         102, 130, 202, 238, 156, 204, 119, 183, 226, 102, 97, 105, 108, 115, 97, 102, 130, 112, 136, 99, 224,
         117, 145, 102, 97, 105, 108, 115, 97, 102, 130, 145, 99, 111, 216, 121, 183, 226, 102, 97, 105, 108,
         115, 97, 102, 130, 159, 105, 174, 153, 104, 192, 104, 164, 100, 139, 105, 103, 110, 168, 111, 141, 128,
         236, 139, 105, 103, 110, 168, 111, 141, 128, 112, 189, 139, 105, 103, 110, 168, 111, 141, 128, 182,
         103, 246, 139, 148, 233, 201, 187, 121, 133, 136, 169, 156, 110, 200, 101, 201, 150, 97, 112, 193, 135,
         121, 118, 201, 232, 120, 150, 101, 184, 254, 164, 116, 97, 103, 101, 118, 201, 230, 117, 184, 150, 101,
         184, 254, 164, 116, 97, 103, 101, 118, 201, 148, 132, 150, 101, 184, 254, 164, 116, 97, 103, 101, 118,
         201, 95, 228, 110, 185, 150, 101, 184, 254, 164, 116, 97, 103, 101, 99, 201, 244, 131, 116, 133, 131,
         99, 176, 116, 102, 154, 99, 130, 201, 187, 121, 150, 101, 184, 150, 111, 188, 116, 118, 201, 161, 121,
         159, 131, 101, 115, 149, 99, 222, 145, 110, 116, 148, 158, 131, 201, 187, 121, 148, 158, 131, 118, 201,
         138, 158, 101, 99, 116, 150, 101, 184, 254, 164, 116, 97, 103, 101, 190, 130, 118, 201, 244, 131, 116,
         115, 190, 130, 99, 201, 244, 131, 116, 115, 118, 201, 150, 208, 221, 133, 131, 99, 176, 116, 118, 201,
         166, 112, 226, 157, 234, 133, 131, 105, 111, 100, 118, 201, 142, 97, 103, 157, 234, 133, 131, 105, 111,
         100, 105, 201, 157, 234, 133, 131, 105, 111, 100, 118, 201, 138, 222, 137, 197, 230, 154, 95, 228, 110,
         185, 118, 201, 138, 222, 137, 197, 230, 154, 150, 114, 135, 207, 139, 118, 201, 142, 99, 139, 101, 118,
         201, 138, 105, 118, 217, 131, 118, 201, 148, 117, 108, 116, 105, 112, 227, 131, 105, 201, 97, 142, 99,
         139, 101, 105, 201, 97, 95, 221, 115, 158, 105, 201, 118, 142, 99, 139, 101, 105, 201, 118, 95, 221,
         115, 158, 201, 187, 121, 150, 151, 116, 132, 117, 101, 98, 101, 101, 112, 131, 95, 132, 216, 115, 197,
         98, 101, 101, 112, 131, 95, 111, 100, 98, 101, 101, 112, 131, 230, 145, 113, 117, 176, 99, 121, 98,
         101, 101, 112, 131, 138, 243, 162, 168, 101, 193, 151, 153, 151, 101, 182, 148, 162, 154, 115, 95, 145,
         216, 115, 224, 109, 105, 120, 131, 153, 121, 171, 99, 180, 243, 102, 227, 140, 109, 162, 154, 133, 131,
         99, 176, 116, 99, 180, 243, 102, 227, 140, 114, 209, 99, 180, 243, 102, 227, 140, 97, 208, 111, 95,
         145, 205, 114, 112, 109, 157, 199, 114, 112, 109, 157, 199, 133, 114, 112, 109, 157, 199, 95, 105, 114,
         112, 109, 157, 199, 138, 114, 112, 109, 157, 199, 254, 139, 117, 101, 51, 128, 165, 175, 98, 155, 128,
         204, 119, 51, 128, 165, 175, 98, 155, 128, 104, 105, 103, 104, 51, 128, 110, 101, 208, 114, 139, 51,
         128, 165, 175, 98, 155, 128, 202, 238, 143, 51, 128, 108, 199, 157, 111, 119, 51, 128, 108, 199, 161,
         105, 103, 104, 51, 128, 115, 119, 189, 195, 109, 233, 115, 131, 118, 111, 150, 176, 187, 133, 117, 108,
         115, 101, 115, 131, 118, 111, 133, 119, 109, 255, 115, 131, 118, 111, 157, 111, 119, 203, 115, 115,
         235, 116, 114, 105, 95, 188, 205, 195, 115, 131, 118, 111, 147, 155, 110, 101, 108, 230, 154, 228, 100,
         185, 142, 116, 248, 114, 209, 112, 136, 169, 156, 110, 200, 101, 202, 114, 148, 217, 202, 114, 95, 253,
         112, 111, 202, 114, 161, 111, 216, 114, 209, 115, 153, 121, 171, 113, 117, 105, 174, 114, 209, 115,
         163, 99, 95, 253, 112, 111, 236, 163, 99, 255, 112, 189, 163, 99, 255, 182, 163, 99, 255, 236, 95, 253,
         112, 111, 112, 189, 95, 253, 112, 111, 182, 95, 253, 112, 111, 236, 142, 114, 209, 112, 189, 142, 114,
         209, 182, 142, 114, 209, 202, 238, 156, 108, 199, 153, 121, 171, 202, 238, 156, 108, 199, 133, 131, 99,
         176, 116, 236, 163, 137, 130, 108, 199, 112, 189, 163, 137, 130, 108, 199, 182, 163, 137, 130, 108,
         199, 145, 191, 162, 95, 147, 141, 193, 187, 115, 131, 105, 139, 95, 117, 112, 100, 137, 130, 114, 137,
         130, 104, 122, 144, 117, 138, 99, 109, 95, 107, 112, 144, 117, 138, 99, 109, 95, 107, 105, 115, 109,
         139, 108, 95, 225, 143, 144, 117, 133, 136, 99, 101, 115, 115, 138, 176, 111, 109, 167, 103, 183, 99,
         108, 132, 137, 197, 97, 208, 111, 166, 205, 183, 226, 220, 150, 139, 95, 151, 95, 169, 114, 159, 95,
         205, 112, 145, 205, 244, 204, 119, 95, 145, 205, 177, 133, 136, 118, 217, 131, 177, 142, 98, 97, 115,
         148, 233, 206, 97, 208, 111, 150, 151, 169, 103, 206, 97, 208, 111, 168, 97, 223, 206, 117, 98, 204,
         181, 193, 113, 117, 105, 114, 130, 109, 233, 108, 206, 117, 98, 204, 181, 102, 227, 103, 104, 116, 148,
         233, 108, 206, 117, 112, 100, 137, 130, 114, 137, 130, 104, 122, 206, 117, 98, 204, 181, 208, 99, 142,
         116, 155, 100, 141, 100, 206, 117, 98, 204, 181, 190, 130, 103, 139, 105, 143, 111, 206, 117, 98, 204,
         181, 176, 170, 156, 155, 97, 177, 142, 158, 161, 111, 109, 130, 112, 111, 132, 116, 95, 151, 99, 101,
         206, 190, 130, 51, 128, 115, 171, 224, 177, 142, 98, 97, 115, 95, 132, 179, 103, 114, 135, 121, 206,
         110, 109, 101, 97, 150, 117, 159, 111, 109, 150, 111, 109, 109, 155, 100, 115, 206, 117, 248, 177, 168,
         97, 223, 206, 192, 99, 117, 130, 109, 132, 142, 116, 248, 166, 116, 206, 192, 99, 117, 130, 139, 116,
         148, 233, 206, 192, 99, 117, 130, 132, 135, 105, 139, 150, 108, 246, 206, 192, 99, 117, 130, 97, 115,
         99, 176, 128, 114, 209, 206, 192, 99, 117, 130, 145, 116, 222, 110, 244, 116, 206, 192, 99, 117, 130,
         103, 136, 188, 128, 115, 171, 224, 206, 192, 99, 117, 130, 165, 115, 99, 176, 116, 166, 116, 206, 192,
         99, 117, 130, 165, 115, 99, 176, 128, 114, 209, 206, 192, 99, 117, 130, 115, 155, 135, 121, 95, 147,
         101, 174, 115, 206, 192, 99, 117, 130, 109, 132, 142, 137, 115, 206, 192, 99, 117, 130, 139, 204, 119,
         95, 205, 185, 95, 119, 135, 104, 111, 208, 95, 169, 120, 206, 192, 99, 117, 130, 182, 133, 206, 146,
         140, 116, 144, 131, 218, 137, 130, 108, 137, 206, 146, 140, 116, 144, 131, 218, 137, 130, 108, 151,
         206, 146, 140, 116, 144, 131, 148, 132, 95, 146, 140, 116, 144, 130, 115, 206, 146, 140, 116, 144, 131,
         218, 137, 130, 116, 164, 131, 155, 99, 130, 109, 165, 175, 98, 155, 100, 182, 183, 175, 98, 155, 100,
         182, 150, 151, 116, 136, 108, 95, 145, 216, 115, 224, 139, 116, 161, 164, 128, 99, 108, 246, 255, 139,
         116, 161, 164, 128, 165, 175, 98, 155, 100, 196, 161, 164, 128, 165, 175, 98, 155, 100, 196, 104, 164,
         128, 196, 135, 197, 142, 111, 222, 99, 101, 196, 104, 164, 128, 111, 112, 116, 207, 139, 102, 204, 119,
         95, 113, 117, 139, 135, 121, 148, 132, 196, 104, 164, 128, 111, 112, 116, 207, 139, 102, 204, 119, 232,
         120, 163, 225, 101, 250, 150, 108, 246, 95, 225, 143, 250, 232, 181, 225, 143, 250, 138, 158, 101, 99,
         116, 95, 193, 99, 101, 108, 250, 138, 158, 101, 99, 116, 254, 101, 204, 99, 135, 121, 250, 138, 158,
         101, 99, 116, 153, 144, 101, 250, 95, 217, 156, 202, 238, 143, 250, 95, 217, 156, 165, 226, 250, 153,
         104, 238, 143, 250, 148, 162, 154, 183, 226, 250, 142, 112, 132, 117, 140, 116, 144, 101, 250, 148,
         132, 153, 144, 101, 250, 153, 144, 101, 111, 208, 250, 232, 181, 139, 116, 135, 117, 165, 250, 95, 176,
         128, 116, 144, 101, 250, 95, 170, 154, 116, 183, 175, 98, 155, 100, 250, 95, 170, 154, 116, 95, 225,
         143, 178, 128, 112, 136, 99, 101, 115, 115, 138, 176, 111, 109, 114, 188, 173, 97, 121, 153, 97, 107,
         101, 221, 133, 145, 118, 176, 116, 197, 114, 188, 173, 97, 121, 153, 97, 107, 101, 221, 183, 193, 116,
         105, 118, 137, 130, 165, 226, 114, 188, 173, 97, 121, 153, 97, 107, 101, 221, 183, 193, 116, 105, 118,
         137, 130, 202, 238, 156, 112, 131, 99, 176, 116, 112, 136, 169, 156, 110, 200, 101, 100, 187, 109, 157,
         234, 49, 138, 121, 110, 148, 132, 235, 100, 187, 109, 157, 234, 49, 138, 121, 110, 232, 120, 235, 100,
         187, 109, 157, 234, 49, 138, 121, 110, 95, 253, 112, 111, 100, 187, 109, 157, 234, 49, 153, 121, 171,
         100, 187, 109, 157, 234, 49, 142, 116, 137, 207, 235, 100, 187, 109, 157, 234, 50, 153, 121, 171, 100,
         187, 109, 157, 234, 50, 142, 116, 137, 207, 235, 100, 187, 109, 229, 162, 147, 235, 100, 187, 109, 229,
         162, 147, 150, 208, 221, 118, 201, 142, 97, 103, 150, 111, 109, 171, 110, 115, 137, 197, 178, 128, 137,
         148, 132, 153, 104, 238, 143, 155, 116, 105, 218, 180, 118, 135, 121, 218, 231, 155, 116, 105, 218,
         180, 118, 135, 121, 150, 208, 221, 235, 155, 116, 105, 218, 180, 118, 135, 121, 133, 218, 231, 193, 99,
         157, 199, 95, 182, 193, 99, 157, 199, 99, 180, 243, 138, 202, 192, 104, 164, 100, 99, 180, 243, 218,
         202, 192, 104, 164, 100, 99, 180, 243, 142, 158, 112, 111, 132, 116, 153, 104, 192, 104, 164, 100, 99,
         180, 243, 153, 144, 101, 99, 180, 243, 183, 226, 99, 180, 243, 95, 145, 99, 111, 216, 121, 95, 225,
         143, 99, 180, 243, 95, 145, 99, 111, 216, 121, 255, 99, 180, 243, 157, 199, 95, 182, 99, 180, 243, 95,
         145, 99, 111, 216, 121, 135, 131, 109, 95, 194, 137, 197, 135, 131, 109, 95, 145, 146, 120, 135, 131,
         109, 95, 145, 146, 120, 153, 121, 171, 135, 131, 109, 95, 145, 146, 120, 150, 208, 221, 135, 131, 109,
         95, 119, 132, 100, 117, 112, 178, 100, 115, 117, 109, 157, 199, 178, 100, 115, 117, 109, 157, 199, 95,
         182, 182, 157, 111, 119, 203, 115, 115, 235, 202, 238, 156, 191, 129, 116, 202, 238, 156, 191, 129,
         116, 150, 208, 221, 193, 136, 153, 180, 132, 131, 95, 225, 156, 108, 199, 193, 136, 153, 180, 132, 131,
         157, 111, 111, 107, 97, 104, 101, 97, 128, 109, 115, 193, 136, 153, 180, 132, 131, 183, 98, 117, 103,
         95, 97, 120, 149, 193, 136, 153, 180, 132, 131, 218, 231, 112, 133, 189, 105, 133, 189, 128, 112, 189,
         102, 133, 189, 140, 236, 105, 95, 236, 128, 236, 102, 95, 236, 140, 182, 105, 95, 182, 128, 182, 102,
         95, 182, 115, 133, 189, 115, 95, 236, 115, 95, 182, 225, 156, 140, 103, 231, 225, 156, 102, 101, 224,
         102, 154, 228, 100, 225, 156, 102, 101, 224, 102, 154, 228, 128, 115, 109, 111, 162, 104, 185, 148,
         115, 225, 156, 108, 199, 225, 156, 101, 141, 202, 95, 145, 102, 104, 154, 105, 122, 151, 95, 143, 118,
         101, 108, 142, 116, 145, 110, 103, 202, 104, 154, 105, 122, 151, 157, 199, 142, 116, 105, 174, 115,
         104, 154, 105, 122, 151, 157, 199, 183, 103, 145, 101, 115, 104, 154, 105, 122, 151, 95, 105, 103, 110,
         154, 130, 159, 105, 174, 115, 104, 154, 105, 122, 151, 183, 226, 148, 115, 147, 105, 114, 140, 146,
         103, 230, 145, 113, 235, 147, 105, 114, 140, 143, 97, 128, 102, 145, 113, 235, 147, 105, 114, 140, 200,
         112, 108, 135, 223, 130, 236, 147, 105, 114, 140, 200, 112, 108, 135, 223, 130, 112, 189, 147, 105,
         114, 140, 200, 112, 108, 135, 223, 130, 182, 147, 105, 114, 140, 102, 145, 113, 117, 176, 99, 121, 142,
         116, 248, 183, 99, 105, 235, 147, 105, 114, 140, 102, 145, 113, 117, 176, 99, 121, 95, 176, 128, 165,
         99, 105, 235, 147, 105, 114, 140, 116, 144, 130, 115, 101, 99, 151, 100, 115, 147, 105, 114, 140, 145,
         171, 137, 128, 167, 181, 236, 128, 167, 120, 133, 189, 128, 167, 181, 182, 128, 167, 181, 103, 231,
         128, 167, 181, 175, 118, 155, 99, 101, 109, 162, 154, 95, 111, 208, 112, 208, 157, 199, 97, 208, 111,
         133, 136, 169, 156, 99, 101, 184, 150, 111, 188, 116, 250, 150, 151, 116, 136, 108, 148, 233, 250, 153,
         114, 105, 103, 103, 131, 244, 204, 119, 95, 192, 158, 250, 153, 114, 105, 103, 103, 131, 153, 104, 238,
         156, 112, 131, 99, 176, 116, 250, 95, 225, 156, 108, 199, 250, 150, 151, 116, 136, 108, 218, 231, 202,
         114, 117, 159, 157, 132, 101, 141, 102, 101, 224, 102, 154, 228, 128, 116, 114, 155, 115, 135, 197,
         102, 101, 224, 102, 154, 228, 128, 97, 216, 97, 103, 185, 102, 101, 224, 102, 154, 228, 128, 115, 109,
         111, 162, 104, 230, 193, 116, 154, 102, 101, 224, 102, 154, 228, 128, 106, 135, 187, 230, 193, 116,
         154, 102, 101, 224, 102, 154, 228, 128, 191, 129, 116, 102, 101, 224, 102, 154, 228, 128, 167, 120,
         163, 137, 130, 108, 199, 102, 101, 224, 102, 154, 228, 128, 182, 161, 164, 128, 103, 231, 102, 101,
         224, 102, 154, 228, 128, 182, 161, 164, 128, 116, 144, 101, 100, 121, 110, 95, 217, 156, 109, 132, 163,
         112, 109, 100, 121, 110, 95, 217, 156, 140, 103, 231, 100, 121, 110, 95, 217, 156, 105, 218, 231, 100,
         121, 110, 95, 217, 156, 128, 103, 231, 100, 121, 110, 95, 217, 156, 167, 181, 132, 99, 145, 97, 115,
         101, 143, 118, 101, 108, 163, 193, 130, 109, 233, 115, 144, 112, 227, 169, 195, 178, 100, 115, 148,
         233, 115, 144, 112, 227, 169, 195, 167, 159, 131, 148, 117, 108, 116, 105, 112, 227, 131, 115, 144,
         112, 227, 169, 195, 105, 218, 231, 115, 144, 112, 227, 169, 195, 128, 103, 231, 115, 144, 112, 227,
         169, 195, 178, 218, 231, 115, 144, 112, 227, 169, 195, 128, 167, 181, 103, 231, 115, 144, 112, 227,
         169, 195, 102, 101, 224, 102, 154, 228, 128, 103, 231, 115, 144, 112, 227, 169, 195, 112, 189, 95, 128,
         103, 231, 115, 144, 112, 227, 169, 195, 112, 189, 133, 105, 218, 231, 115, 144, 112, 227, 169, 195,
         100, 187, 109, 95, 169, 108, 187, 115, 144, 112, 227, 169, 195, 100, 187, 109, 95, 169, 108, 187, 148,
         117, 108, 116, 105, 112, 227, 131, 115, 144, 112, 227, 169, 195, 220, 95, 169, 108, 187, 115, 144, 112,
         227, 169, 195, 220, 95, 169, 108, 187, 148, 117, 108, 116, 105, 112, 227, 131, 116, 203, 148, 233, 116,
         203, 255, 116, 203, 168, 145, 97, 107, 112, 111, 132, 116, 116, 203, 157, 111, 119, 255, 116, 203, 157,
         111, 119, 168, 145, 97, 107, 112, 111, 132, 116, 116, 203, 157, 111, 119, 244, 119, 97, 121, 115, 116,
         203, 142, 171, 195, 116, 121, 171, 116, 203, 142, 171, 195, 98, 97, 115, 207, 183, 226, 116, 203, 142,
         171, 195, 98, 97, 115, 207, 218, 180, 118, 135, 121, 116, 203, 142, 171, 195, 175, 118, 133, 136, 112,
         133, 189, 116, 203, 142, 171, 195, 175, 118, 232, 115, 115, 116, 203, 142, 171, 195, 175, 118, 138,
         180, 103, 95, 107, 116, 203, 142, 171, 195, 175, 118, 153, 104, 114, 117, 159, 116, 203, 142, 171, 195,
         167, 181, 118, 164, 116, 97, 103, 101, 116, 203, 142, 171, 195, 112, 189, 95, 221, 115, 158, 116, 203,
         150, 222, 118, 130, 116, 121, 171, 116, 203, 150, 222, 118, 130, 159, 139, 108, 153, 104, 238, 143,
         116, 203, 150, 222, 118, 130, 178, 128, 202, 114, 48, 116, 203, 150, 222, 118, 130, 178, 128, 202, 114,
         49, 48, 48, 116, 203, 150, 222, 118, 130, 253, 112, 111, 101, 122, 95, 146, 110, 100, 185, 153, 104,
         192, 104, 164, 100, 101, 122, 95, 146, 110, 100, 185, 157, 199, 101, 122, 95, 146, 110, 100, 185, 142,
         171, 224, 146, 110, 100, 185, 166, 205, 153, 104, 192, 104, 164, 100, 115, 203, 95, 236, 150, 176, 187,
         115, 203, 95, 236, 95, 119, 217, 202, 115, 203, 95, 236, 148, 233, 115, 203, 133, 189, 150, 176, 187,
         115, 203, 133, 189, 95, 119, 217, 202, 115, 203, 133, 189, 148, 233, 115, 203, 95, 182, 150, 176, 187,
         115, 203, 95, 182, 95, 119, 217, 202, 115, 203, 95, 182, 148, 233, 182, 153, 121, 171, 225, 156, 112,
         189, 95, 221, 115, 158, 116, 108, 109, 95, 132, 216, 179, 100, 116, 108, 109, 161, 139, 102, 100, 117,
         112, 143, 120, 214, 95, 49, 133, 194, 111, 99, 164, 214, 95, 49, 95, 117, 248, 214, 95, 49, 168, 97,
         223, 214, 95, 50, 133, 194, 111, 99, 164, 214, 95, 50, 95, 117, 248, 214, 95, 50, 168, 97, 223, 214,
         95, 51, 133, 194, 111, 99, 164, 214, 95, 51, 95, 117, 248, 214, 95, 51, 168, 97, 223, 99, 198, 102,
         153, 108, 109, 95, 193, 99, 220, 102, 198, 107, 121, 183, 102, 97, 117, 108, 116, 157, 137, 102, 198,
         107, 121, 183, 102, 97, 117, 108, 116, 157, 151, 103, 102, 198, 107, 121, 95, 206, 102, 154, 109, 137,
         102, 198, 107, 121, 95, 188, 135, 102, 198, 107, 121, 254, 102, 97, 115, 133, 145, 99, 149, 197, 104,
         162, 116, 244, 205, 95, 132, 116, 178, 128, 132, 153, 108, 109, 145, 112, 154, 116, 150, 101, 184, 254,
         164, 116, 97, 103, 101, 105, 98, 190, 142, 176, 115, 154, 167, 118, 108, 132, 107, 232, 104, 95, 97,
         115, 161, 101, 175, 185, 138, 105, 118, 149, 154, 167, 118, 108, 132, 107, 148, 132, 153, 120, 98, 117,
         102, 102, 167, 118, 108, 132, 107, 95, 253, 116, 142, 116, 137, 190, 255, 167, 118, 108, 132, 107, 163,
         99, 95, 147, 155, 255, 167, 118, 108, 132, 107, 152, 255, 167, 118, 108, 132, 107, 95, 253, 116, 180,
         49, 255, 167, 118, 108, 132, 107, 95, 253, 116, 180, 50, 255, 167, 118, 108, 132, 107, 95, 253, 116,
         180, 51, 255, 252, 118, 164, 116, 97, 103, 101, 252, 99, 222, 145, 110, 116, 252, 102, 117, 101, 108,
         252, 109, 233, 252, 193, 99, 95, 120, 252, 193, 99, 95, 121, 252, 193, 99, 95, 122, 252, 112, 189, 252,
         236, 252, 104, 101, 175, 185, 252, 139, 116, 135, 117, 165, 252, 118, 141, 105, 111, 252, 108, 137,
         157, 151, 103, 252, 103, 136, 188, 128, 115, 171, 224, 252, 100, 149, 116, 155, 99, 101, 252, 101, 115,
         99, 150, 222, 145, 110, 116, 252, 101, 115, 99, 254, 164, 116, 97, 103, 101, 252, 101, 115, 99, 163,
         112, 109, 252, 101, 115, 99, 153, 101, 109, 112, 131, 137, 117, 145, 252, 179, 109, 112, 131, 137, 117,
         145, 252, 99, 160, 190, 224, 143, 100, 159, 114, 105, 140, 118, 149, 117, 139, 168, 101, 101, 112, 131,
         143, 100, 159, 114, 105, 140, 118, 149, 117, 139, 168, 101, 101, 112, 131, 150, 164, 154, 143, 100,
         159, 114, 105, 140, 103, 114, 98, 163, 103, 98, 143, 100, 159, 114, 105, 112, 133, 136, 169, 143, 143,
         100, 159, 114, 105, 140, 180, 99, 130, 99, 164, 154, 143, 100, 159, 114, 105, 140, 98, 101, 193, 151,
         150, 164, 154, 143, 100, 159, 114, 105, 140, 98, 101, 193, 151, 133, 131, 105, 111, 128, 109, 115, 143,
         100, 159, 114, 105, 140, 98, 101, 193, 151, 133, 131, 99, 176, 116, 143, 100, 159, 114, 105, 140, 98,
         101, 193, 151, 95, 205, 195, 151, 108, 121, 143, 100, 159, 114, 105, 140, 98, 114, 105, 103, 104, 116,
         110, 101, 115, 115, 143, 100, 159, 114, 105, 140, 180, 132, 191, 119, 183, 108, 116, 97, 143, 100, 159,
         114, 105, 140, 180, 132, 191, 119, 230, 145, 113, 116, 114, 155, 115, 112, 151, 100, 131, 133, 136,
         118, 217, 131, 116, 114, 155, 115, 112, 151, 100, 131, 138, 137, 97, 115, 100, 99, 141, 128, 100, 158,
         101, 99, 116, 95, 132, 216, 179, 100, 115, 100, 99, 141, 128, 109, 233, 115, 100, 99, 141, 128, 115,
         178, 168, 190, 134, 188, 135, 115, 134, 228, 110, 168, 135, 167, 115, 107, 134, 198, 115, 105, 244,
         205, 134, 108, 132, 107, 95, 113, 117, 139, 135, 121, 244, 205, 134, 198, 115, 105, 138, 98, 109, 244,
         205, 134, 198, 110, 114, 244, 205, 134, 99, 160, 139, 205, 134, 139, 116, 244, 205, 134, 100, 149, 116,
         155, 99, 130, 139, 205, 134, 101, 115, 99, 153, 101, 109, 140, 139, 205, 134, 101, 115, 99, 163, 112,
         109, 244, 205, 134, 101, 115, 99, 150, 222, 145, 110, 116, 244, 205, 134, 99, 154, 130, 179, 109, 140,
         139, 205, 134, 97, 104, 232, 120, 133, 135, 134, 97, 104, 232, 181, 136, 108, 134, 97, 104, 95, 132,
         216, 116, 134, 204, 103, 111, 95, 151, 95, 205, 185, 134, 204, 103, 111, 95, 151, 95, 205, 185, 138,
         222, 137, 197, 134, 205, 185, 157, 111, 103, 111, 134, 190, 130, 113, 117, 105, 174, 148, 176, 117,
         134, 243, 111, 119, 142, 171, 99, 133, 145, 205, 134, 116, 144, 49, 134, 116, 144, 50, 134, 118, 201,
         152, 134, 198, 115, 105, 152, 134, 108, 132, 107, 95, 113, 117, 139, 135, 121, 152, 134, 108, 132, 107,
         153, 120, 133, 111, 119, 131, 152, 134, 198, 115, 105, 138, 98, 109, 152, 134, 198, 110, 114, 152, 134,
         116, 144, 95, 49, 152, 134, 116, 144, 95, 50, 152, 134, 145, 167, 132, 185, 153, 144, 130, 101, 159,
         144, 137, 247, 134, 102, 108, 121, 109, 111, 100, 247, 134, 155, 116, 105, 218, 180, 118, 135, 121,
         152, 134, 103, 230, 154, 99, 247, 134, 202, 238, 156, 196, 134, 118, 116, 181, 147, 155, 110, 101, 108,
         152, 134, 99, 114, 129, 243, 97, 105, 198, 152, 134, 97, 104, 142, 98, 141, 152, 134, 97, 104, 152,
         134, 99, 222, 145, 110, 116, 152, 134, 167, 104, 138, 114, 173, 110, 152, 134, 119, 104, 138, 114, 173,
         110, 152, 134, 109, 162, 154, 138, 105, 97, 103, 152, 134, 99, 180, 102, 116, 229, 200, 247, 134, 178,
         108, 162, 229, 200, 247, 134, 177, 142, 171, 195, 196, 134, 177, 157, 151, 152, 134, 177, 157, 137,
         152, 134, 206, 146, 140, 99, 222, 114, 152, 134, 206, 146, 112, 133, 145, 118, 152, 134, 206, 146, 140,
         98, 101, 159, 51, 152, 134, 177, 142, 137, 115, 152, 134, 104, 111, 109, 130, 100, 105, 114, 152, 134,
         104, 111, 109, 130, 100, 149, 116, 152, 134, 102, 227, 103, 104, 116, 166, 116, 152, 134, 99, 111, 109,
         203, 115, 115, 168, 141, 152, 134, 139, 116, 135, 223, 247, 134, 178, 128, 236, 152, 134, 178, 128,
         112, 189, 152, 134, 178, 128, 182, 152, 134, 165, 98, 117, 103, 152, 134, 165, 98, 117, 103, 50, 152,
         134, 112, 111, 119, 131, 152, 134, 178, 100, 114, 137, 130, 112, 136, 169, 156, 196, 134, 228, 110,
         185, 115, 152, 134, 97, 118, 103, 150, 101, 184, 254, 164, 116, 97, 103, 247, 134, 112, 135, 95, 225,
         152, 134, 136, 108, 95, 225, 152, 134, 201, 187, 121, 95, 190, 97, 103, 247, 134, 100, 149, 205, 195,
         196, 134, 110, 104, 101, 175, 185, 152, 134, 117, 112, 138, 111, 119, 110, 95, 145, 102, 131, 176, 99,
         247, 134, 145, 175, 121, 148, 111, 100, 247, 134, 196, 161, 164, 128, 145, 175, 121, 152, 134, 110,
         118, 141, 105, 111, 152, 134, 101, 115, 99, 153, 109, 112, 152, 134, 101, 115, 99, 163, 112, 109, 152,
         134, 101, 115, 99, 163, 112, 109, 230, 145, 113, 152, 134, 114, 116, 99, 138, 137, 130, 116, 144, 247,
         134, 175, 106, 117, 159, 109, 176, 116, 163, 225, 247, 134, 102, 227, 140, 141, 136, 119, 152, 134, 99,
         154, 130, 179, 109, 112, 152, 134, 204, 103, 142, 116, 137, 190, 152, 134, 159, 105, 174, 95, 111, 216,
         226, 95, 143, 102, 116, 152, 134, 159, 105, 174, 95, 111, 216, 226, 163, 105, 103, 104, 116, 152, 134,
         159, 105, 174, 95, 111, 216, 226, 163, 175, 105, 111, 148, 233, 134, 114, 137, 130, 112, 136, 169, 156,
         110, 200, 247, 134, 178, 128, 112, 136, 169, 156, 110, 200, 247, 134, 201, 187, 121, 133, 136, 169,
         156, 110, 200, 247, 134, 112, 136, 169, 156, 110, 200, 247, 134, 114, 99, 147, 155, 110, 101, 108, 115,
         152, 134, 99, 200, 131, 97, 230, 180, 109, 247, 134, 101, 102, 169, 99, 105, 176, 99, 121, 152, 134,
         116, 162, 139, 230, 227, 103, 104, 116, 115, 152, 134, 97, 117, 120, 152, 134, 115, 121, 115, 218, 111,
         103, 103, 156, 118, 164, 116, 97, 103, 247, 134, 115, 121, 115, 254, 116, 181, 118, 164, 116, 97, 103,
         247, 134, 115, 121, 115, 168, 135, 114, 137, 247, 134, 115, 121, 115, 183, 226, 152, 134, 115, 121,
         115, 166, 116, 155, 99, 247, 134, 115, 121, 115, 157, 113, 152, 134, 115, 121, 115, 218, 111, 103, 103,
         156, 100, 118, 114, 152, 134, 115, 121, 115, 254, 116, 120, 138, 118, 114, 152, 134, 115, 121, 115, 95,
         228, 110, 185, 115, 152, 134, 115, 121, 115, 254, 116, 120, 153, 101, 109, 112, 152, 134, 115, 121,
         115, 230, 155, 142, 171, 195, 196, 134, 159, 137, 168, 135, 167, 115, 107, 134, 112, 136, 169, 143,
         134, 112, 136, 169, 156, 49, 229, 200, 101, 134, 112, 136, 169, 156, 50, 229, 200, 101, 134, 112, 136,
         169, 156, 51, 229, 200, 101, 134, 177, 142, 137, 115, 142, 104, 111, 119, 133, 100, 111, 112, 134, 100,
         149, 112, 226, 112, 154, 116, 183, 118, 207, 101, 134, 117, 248, 134, 114, 99, 147, 155, 110, 101, 108,
         115, 134, 99, 200, 131, 97, 230, 180, 109, 130, 119, 217, 202, 134, 99, 200, 131, 97, 230, 180, 109,
         130, 104, 101, 105, 103, 104, 116, 134, 159, 137, 95, 97, 118, 103, 150, 101, 184, 254, 139, 117, 101,
         134, 102, 180, 109, 131, 137, 130, 104, 122, 134, 109, 176, 117, 168, 97, 174, 103, 136, 188, 100, 134,
         97, 117, 181, 147, 155, 110, 101, 108, 134, 97, 117, 120, 142, 99, 139, 101, 134, 97, 117, 120, 142,
         121, 109, 98, 164, 134, 99, 180, 102, 116, 110, 200, 130, 109, 115, 103, 115, 134, 108, 217, 141, 166,
         116, 152, 134, 99, 117, 159, 111, 109, 142, 131, 105, 139, 153, 253, 116, 152, 134, 99, 117, 159, 111,
         109, 142, 131, 105, 139, 153, 253, 116, 153, 131, 109, 132, 137, 154, 134, 99, 117, 159, 111, 109, 153,
         253, 116, 95, 117, 248, 134, 99, 117, 159, 111, 109, 153, 253, 116, 168, 97, 223, 134, 119, 140, 110,
         117, 109, 98, 131, 152, 134, 119, 140, 99, 222, 145, 110, 116, 157, 137, 152, 134, 119, 140, 99, 222,
         145, 110, 116, 157, 151, 152, 134, 119, 140, 99, 222, 145, 110, 116, 244, 116, 152, 134, 119, 112, 166,
         116, 155, 99, 247, 134, 119, 112, 138, 105, 145, 99, 116, 197, 152, 134, 119, 140, 110, 253, 116, 229,
         117, 109, 98, 131, 152, 134, 119, 140, 158, 97, 152, 134, 110, 97, 118, 232, 112, 152, 134, 110, 97,
         118, 148, 160, 109, 233, 134, 110, 97, 118, 148, 160, 99, 176, 116, 145, 134, 110, 97, 118, 148, 160,
         109, 132, 142, 99, 139, 130, 109, 134, 97, 105, 198, 171, 224, 115, 121, 159, 101, 109, 161, 115, 130,
         109, 104, 122, 116, 97, 115, 107, 142, 116, 137, 149, 116, 207, 115, 165, 98, 117, 103, 148, 233, 114,
         137, 130, 54, 196, 142, 119, 189, 99, 112, 117, 95, 111, 216, 99, 204, 174, 112, 119, 114, 95, 151, 95,
         205, 218, 180, 99, 101, 176, 170, 156, 159, 105, 174, 95, 205, 185, 118, 116, 120, 168, 155, 100, 118,
         116, 181, 147, 155, 110, 101, 108, 118, 116, 120, 133, 111, 119, 131, 118, 116, 120, 157, 111, 119,
         133, 111, 119, 131, 166, 205, 118, 116, 120, 142, 215, 116, 115, 131, 105, 139, 244, 116, 118, 116,
         120, 153, 121, 171, 118, 116, 181, 117, 248, 118, 116, 181, 102, 145, 113, 118, 116, 120, 133, 135,
         148, 111, 100, 130, 102, 145, 113, 118, 116, 120, 161, 139, 102, 100, 117, 112, 143, 120, 118, 116,
         120, 237, 168, 190, 118, 99, 128, 118, 105, 165, 111, 142, 121, 159, 101, 109, 118, 99, 128, 104, 95,
         221, 115, 158, 118, 99, 128, 118, 95, 221, 115, 158, 167, 120, 55, 52, 53, 54, 150, 204, 174, 167, 120,
         55, 52, 53, 54, 237, 168, 190, 167, 120, 55, 52, 53, 54, 133, 145, 132, 135, 95, 111, 112, 117, 100,
         149, 112, 226, 112, 154, 116, 148, 115, 140, 99, 164, 95, 175, 106, 117, 159, 100, 149, 112, 226, 112,
         154, 116, 148, 115, 140, 136, 119, 95, 175, 106, 117, 159, 100, 149, 112, 226, 112, 154, 116, 148, 115,
         140, 102, 151, 116, 115, 100, 149, 112, 226, 112, 154, 116, 148, 115, 140, 190, 130, 165, 118, 207,
         130, 98, 108, 132, 107, 100, 149, 112, 226, 112, 154, 116, 232, 120, 55, 52, 53, 54, 150, 164, 95, 175,
         106, 117, 159, 100, 149, 112, 226, 112, 154, 116, 232, 120, 55, 52, 53, 54, 95, 136, 119, 95, 175, 106,
         117, 159, 100, 149, 112, 226, 112, 154, 116, 232, 120, 55, 52, 53, 54, 95, 132, 118, 100, 149, 112,
         226, 112, 154, 116, 232, 120, 55, 52, 53, 54, 168, 108, 107, 100, 149, 112, 226, 112, 154, 116, 232,
         120, 55, 52, 53, 54, 95, 119, 104, 116, 101, 115, 99, 142, 176, 115, 154, 161, 139, 102, 100, 117, 112,
         143, 120, 101, 115, 99, 142, 176, 115, 154, 150, 222, 145, 110, 116, 95, 221, 115, 158, 101, 115, 99,
         142, 176, 115, 154, 95, 117, 248, 102, 198, 107, 121, 237, 95, 97, 208, 111, 98, 132, 100, 102, 198,
         107, 121, 237, 153, 181, 217, 102, 198, 107, 121, 237, 95, 221, 115, 158, 102, 198, 107, 121, 237, 168,
         132, 128, 104, 111, 112, 138, 137, 97, 102, 198, 107, 121, 95, 120, 163, 181, 110, 117, 109, 102, 198,
         107, 121, 237, 95, 97, 49, 142, 111, 222, 99, 101, 99, 99, 50, 53, 48, 48, 237, 95, 147, 105, 112, 138,
         158, 101, 99, 116, 239, 132, 216, 115, 197, 100, 97, 243, 191, 141, 128, 105, 50, 99, 168, 190, 100,
         97, 243, 191, 141, 128, 105, 50, 99, 95, 175, 100, 114, 99, 200, 131, 97, 150, 151, 116, 136, 108, 148,
         233, 99, 200, 131, 97, 150, 151, 116, 136, 108, 95, 145, 102, 254, 164, 116, 97, 103, 101, 99, 200,
         131, 97, 150, 151, 116, 136, 108, 95, 107, 101, 121, 183, 226, 99, 200, 131, 97, 150, 151, 116, 136,
         108, 95, 132, 187, 110, 139, 95, 192, 149, 116, 155, 99, 101, 99, 200, 131, 97, 150, 151, 116, 136,
         108, 168, 208, 116, 151, 95, 192, 149, 116, 155, 99, 101, 99, 200, 131, 97, 150, 151, 116, 136, 108,
         95, 132, 216, 179, 100, 114, 225, 101, 102, 132, 100, 131, 161, 141, 100, 228, 101, 114, 225, 101, 102,
         132, 100, 131, 95, 117, 248, 111, 112, 116, 207, 139, 102, 204, 119, 161, 141, 100, 228, 101, 111, 112,
         116, 207, 139, 102, 204, 119, 95, 117, 248, 111, 112, 116, 207, 139, 102, 204, 119, 95, 194, 137, 197,
         111, 112, 116, 207, 139, 102, 204, 119, 230, 227, 140, 120, 112, 132, 105, 111, 150, 151, 169, 103,
         112, 132, 105, 111, 168, 111, 120, 190, 98, 161, 105, 128, 99, 100, 99, 190, 98, 148, 115, 99, 133,
         132, 133, 117, 184, 117, 112, 102, 146, 243, 237, 168, 190, 114, 99, 165, 118, 207, 130, 132, 135, 183,
         118, 95, 137, 179, 109, 112, 116, 115, 114, 99, 165, 118, 207, 130, 132, 135, 183, 118, 95, 137, 179,
         109, 112, 116, 95, 132, 187, 118, 139, 114, 99, 165, 118, 207, 130, 112, 194, 111, 99, 164, 95, 216,
         115, 197, 114, 99, 165, 118, 207, 130, 102, 101, 137, 117, 145, 114, 99, 165, 118, 207, 130, 117, 248,
         220, 95, 49, 168, 117, 159, 121, 171, 220, 95, 49, 237, 98, 190, 220, 95, 49, 95, 105, 50, 99, 66, 190,
         220, 95, 49, 95, 105, 50, 99, 95, 175, 100, 192, 115, 105, 50, 99, 49, 133, 117, 184, 117, 112, 105,
         50, 99, 49, 150, 204, 174, 115, 171, 195, 107, 104, 122, 105, 50, 99, 50, 133, 117, 184, 117, 112, 105,
         50, 99, 50, 150, 204, 174, 115, 171, 195, 107, 104, 122, 105, 50, 99, 51, 133, 117, 184, 117, 112, 105,
         50, 99, 51, 150, 204, 174, 115, 171, 195, 107, 104, 122, 109, 99, 111, 50, 95, 151, 133, 99, 57, 115,
         171, 107, 116, 114, 117, 109, 237, 133, 194, 111, 99, 164, 115, 171, 107, 116, 114, 117, 109, 237, 148,
         102, 103, 95, 217, 115, 171, 107, 116, 114, 117, 109, 237, 229, 117, 109, 95, 147, 155, 110, 101, 108,
         115, 253, 112, 192, 115, 108, 198, 95, 117, 217, 253, 112, 192, 115, 108, 198, 138, 111, 167, 132, 253,
         112, 192, 115, 108, 198, 148, 233, 108, 95, 217, 115, 147, 224, 117, 108, 131, 95, 145, 146, 120, 163,
         120, 115, 147, 224, 117, 108, 131, 95, 145, 146, 181, 129, 100, 115, 147, 224, 117, 108, 131, 183, 98,
         117, 103, 153, 97, 115, 107, 99, 112, 117, 157, 137, 130, 108, 199, 133, 131, 109, 105, 108, 143, 115,
         131, 105, 139, 109, 115, 140, 104, 139, 102, 100, 117, 112, 143, 120, 109, 115, 140, 49, 95, 117, 248,
         109, 115, 140, 49, 168, 97, 223, 109, 115, 140, 50, 95, 117, 248, 109, 115, 140, 50, 168, 97, 223, 109,
         115, 140, 51, 95, 117, 248, 109, 115, 140, 51, 168, 97, 223, 116, 144, 101, 122, 151, 130, 221, 115,
         158, 148, 132, 117, 179, 115, 114, 112, 109, 95, 169, 108, 187, 161, 205, 151, 207, 115, 114, 112, 109,
         95, 169, 108, 187, 95, 119, 101, 105, 103, 104, 116, 115, 114, 112, 109, 95, 169, 108, 187, 95, 113,
         114, 112, 109, 95, 169, 108, 187, 148, 132, 235, 114, 112, 109, 95, 169, 108, 187, 230, 175, 130, 114,
         225, 130, 104, 122, 114, 112, 109, 95, 169, 108, 187, 157, 234, 235, 102, 108, 121, 115, 107, 121, 237,
         153, 181, 217, 102, 108, 121, 115, 107, 121, 237, 163, 102, 95, 147, 155, 110, 101, 108, 115, 159, 137,
         115, 148, 132, 95, 205, 195, 116, 144, 130, 115, 159, 137, 115, 153, 162, 139, 230, 227, 103, 104, 116,
         115, 159, 137, 115, 153, 162, 139, 153, 144, 130, 115, 159, 137, 115, 153, 162, 139, 166, 116, 148,
         159, 137, 115, 142, 97, 118, 130, 109, 111, 118, 130, 108, 199, 159, 137, 115, 232, 104, 95, 190, 224,
         99, 180, 102, 116, 229, 200, 101, 178, 108, 162, 229, 200, 101, 139, 116, 135, 223, 130, 115, 111, 222,
         99, 101, 139, 116, 135, 223, 130, 112, 145, 102, 131, 168, 97, 136, 139, 116, 135, 223, 130, 108, 234,
         114, 225, 101, 102, 132, 100, 131, 232, 120, 163, 225, 130, 99, 109, 139, 116, 135, 223, 130, 128, 108,
         234, 160, 146, 110, 100, 185, 244, 116, 135, 223, 130, 109, 160, 104, 111, 216, 153, 104, 238, 143,
         160, 202, 238, 156, 109, 132, 160, 202, 238, 156, 167, 120, 160, 139, 116, 135, 223, 130, 112, 160,
         139, 116, 135, 223, 130, 105, 160, 139, 116, 135, 223, 130, 100, 160, 139, 116, 135, 223, 130, 97, 160,
         139, 116, 135, 223, 130, 102, 97, 112, 152, 135, 197, 133, 97, 112, 152, 135, 197, 95, 105, 97, 112,
         152, 135, 197, 138, 97, 112, 152, 135, 197, 95, 97, 97, 112, 152, 135, 197, 230, 97, 112, 152, 135,
         197, 150, 208, 221, 160, 159, 111, 140, 202, 192, 104, 164, 100, 160, 167, 181, 225, 143, 160, 167,
         181, 182, 255, 160, 182, 133, 160, 118, 101, 204, 99, 135, 121, 138, 180, 103, 150, 111, 101, 102, 102,
         160, 167, 181, 118, 101, 204, 99, 135, 121, 160, 119, 97, 121, 112, 111, 132, 116, 95, 141, 114, 105,
         118, 139, 163, 175, 105, 190, 160, 119, 97, 121, 112, 111, 132, 116, 161, 164, 128, 114, 175, 105, 190,
         160, 159, 105, 174, 183, 175, 98, 155, 100, 160, 202, 238, 156, 165, 175, 98, 155, 100, 160, 182, 148,
         233, 160, 109, 132, 230, 154, 228, 128, 118, 101, 204, 99, 135, 121, 160, 110, 97, 118, 150, 154, 110,
         131, 142, 171, 224, 160, 110, 97, 118, 150, 154, 110, 131, 183, 108, 116, 97, 254, 160, 110, 97, 118,
         183, 99, 101, 108, 160, 110, 97, 118, 95, 193, 99, 101, 108, 160, 110, 97, 118, 150, 141, 194, 95, 143,
         97, 128, 116, 144, 101, 160, 110, 97, 118, 150, 141, 194, 95, 143, 97, 128, 167, 120, 160, 110, 97,
         118, 133, 145, 116, 222, 110, 166, 116, 160, 118, 101, 204, 99, 135, 121, 168, 117, 105, 108, 100, 117,
         140, 167, 120, 133, 189, 160, 167, 120, 153, 222, 110, 255, 160, 104, 164, 128, 154, 98, 135, 163, 175,
         105, 190, 160, 104, 164, 128, 169, 103, 117, 145, 56, 95, 119, 217, 202, 160, 146, 110, 100, 185, 183,
         115, 99, 176, 116, 255, 160, 146, 110, 100, 185, 138, 158, 101, 99, 116, 197, 153, 144, 101, 160, 146,
         110, 100, 185, 237, 114, 139, 95, 176, 170, 143, 160, 146, 110, 100, 185, 237, 114, 139, 163, 175, 105,
         190, 160, 146, 110, 100, 185, 237, 114, 139, 255, 160, 146, 110, 100, 185, 254, 101, 204, 99, 135, 121,
         153, 104, 192, 104, 164, 100, 160, 146, 110, 100, 185, 153, 104, 238, 156, 202, 192, 104, 164, 100,
         160, 108, 49, 95, 176, 170, 143, 160, 108, 49, 133, 131, 105, 111, 100, 160, 108, 49, 148, 132, 157,
         111, 111, 107, 97, 104, 101, 175, 160, 108, 49, 232, 120, 157, 111, 111, 107, 97, 104, 101, 175, 160,
         108, 49, 232, 120, 150, 114, 129, 115, 153, 180, 174, 95, 131, 136, 114, 160, 108, 49, 153, 222, 110,
         255, 160, 109, 132, 229, 97, 118, 244, 116, 135, 223, 130, 109, 160, 114, 120, 157, 129, 115, 133, 164,
         207, 121, 160, 167, 120, 166, 116, 155, 99, 130, 102, 136, 109, 161, 111, 109, 101, 160, 103, 101, 215,
         176, 99, 130, 193, 116, 197, 191, 181, 190, 131, 95, 49, 229, 200, 101, 191, 181, 190, 131, 95, 50,
         229, 200, 101, 191, 181, 190, 131, 95, 51, 229, 200, 101, 191, 181, 190, 131, 95, 52, 229, 200, 101,
         103, 246, 139, 95, 236, 163, 99, 218, 231, 103, 246, 139, 133, 189, 163, 99, 153, 104, 114, 218, 231,
         103, 246, 139, 133, 189, 163, 99, 157, 111, 119, 218, 231, 103, 246, 139, 133, 189, 163, 99, 161, 105,
         103, 104, 218, 231, 103, 246, 139, 95, 182, 163, 99, 218, 231, 103, 246, 139, 95, 236, 218, 231, 103,
         246, 139, 95, 236, 95, 221, 115, 158, 103, 246, 139, 95, 236, 157, 199, 103, 246, 139, 133, 189, 218,
         231, 103, 246, 139, 133, 189, 95, 221, 115, 158, 103, 246, 139, 133, 189, 157, 111, 119, 157, 199, 103,
         246, 139, 133, 189, 161, 105, 103, 104, 157, 199, 103, 246, 139, 95, 182, 218, 231, 103, 246, 139, 95,
         182, 95, 221, 115, 158, 103, 246, 139, 95, 182, 157, 199, 103, 246, 139, 142, 116, 170, 105, 108, 149,
         137, 197, 103, 246, 139, 142, 176, 115, 135, 105, 118, 135, 121, 103, 246, 139, 95, 117, 248, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0);
   begin
      return Codes (I);
   end Name_Code;

   Token_Text_Length : constant := 372;
   Max_Token_Length  : constant := 19;
   Token_Text : constant String (1 .. Token_Text_Length + Max_Token_Length) :=
     "d_ose_erin_posd_itroat_dalp_ar_sleimrelach_mis_con_toranle__letstap__hot_rolde_disma_bfiabpepsawckadengpspi"
     & "tex_yaw_delling_disabterunitchusboresroted_ionrsimitambatthpaloarmgps_icutateteletelemtelemettelemetrteleme"
     & "tryofverid_ggygyrooffurudanglaywar_n_fain_maodepf_hzroll_spirottled_blablackblackbosh_alblackboximbe_posart"
     & "launlaunchtelemetry_disabtelemetry_disabled__v_rate                   ";

   subtype Token_Code is Interfaces.Unsigned_8 range 128 .. 255;
   type Token_Start is range 0 .. Token_Text_Length;
   type Token_Length is range 2 .. Max_Token_Length;

   Token_Starts : constant array (Token_Code) of Token_Start :=
     (0, 2, 4, 6, 8, 10, 12, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 10, 50, 52, 54,
      56, 59, 61, 63, 65, 68, 70, 72, 74, 76, 78, 82, 84, 86, 88, 90, 92, 94, 96, 98, 100, 102, 105, 107, 53,
      109, 111, 114, 117, 119, 122, 128, 131, 133, 137, 139, 141, 39, 144, 147, 11, 150, 153, 155, 159, 161,
      164, 166, 168, 170, 173, 177, 179, 181, 184, 188, 193, 200, 208, 217, 219, 222, 224, 226, 228, 232, 235,
      237, 147, 239, 242, 118, 245, 248, 250, 252, 255, 258, 261, 263, 266, 270, 274, 278, 282, 285, 290, 297,
      299, 302, 310, 313, 318, 321, 325, 331, 346, 108, 365, 367);

   Token_Lengths : constant array (Token_Code) of Token_Length :=
     (2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 3, 2, 2, 2, 3, 2, 2,
      2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 3, 3, 2, 3, 6, 3, 2, 4, 2, 2, 3, 2, 3, 3, 3, 3,
      2, 4, 2, 3, 2, 2, 2, 3, 4, 2, 2, 3, 4, 5, 7, 8, 9, 2, 3, 2, 2, 2, 4, 3, 2, 2, 2, 3, 3, 2, 3, 2, 2, 3, 3,
      3, 2, 3, 4, 4, 4, 4, 3, 5, 7, 2, 3, 8, 3, 5, 3, 4, 6, 15, 19, 2, 2, 5);

   type Name_Start is range 0 .. Name_Codes_Length;
   type Name_Length is range 1 .. Max_Name_Length;

   Name_Starts : constant array (Setting) of Name_Start :=
     (0, 8, 15, 24, 31, 40, 46, 54, 60, 68, 77, 88, 95, 107, 117, 127, 137, 145, 154, 163, 173, 183, 194, 207,
      214, 219, 226, 233, 242, 248, 256, 264, 272, 279, 289, 300, 307, 314, 323, 331, 339, 350, 362, 370, 378,
      386, 397, 409, 417, 422, 428, 433, 442, 455, 462, 469, 476, 493, 502, 510, 526, 546, 563, 578, 594, 605,
      616, 627, 637, 649, 666, 676, 688, 698, 714, 732, 740, 747, 761, 765, 782, 798, 806, 811, 820, 826, 840,
      858, 877, 887, 894, 899, 905, 910, 919, 923, 928, 933, 939, 943, 951, 956, 964, 971, 978, 985, 991, 995,
      1001, 1004, 1014, 1018, 1022, 1028, 1036, 1042, 1048, 1054, 1061, 1067, 1074, 1084, 1095, 1106, 1113,
      1124, 1131, 1145, 1154, 1162, 1172, 1187, 1198, 1211, 1226, 1240, 1255, 1272, 1281, 1291, 1300, 1305,
      1315, 1322, 1335, 1349, 1362, 1377, 1387, 1401, 1410, 1418, 1424, 1440, 1448, 1456, 1466, 1478, 1490,
      1499, 1511, 1524, 1530, 1537, 1547, 1554, 1561, 1568, 1575, 1584, 1594, 1602, 1614, 1629, 1639, 1646,
      1660, 1668, 1680, 1685, 1691, 1698, 1704, 1713, 1722, 1733, 1740, 1750, 1757, 1765, 1773, 1785, 1793,
      1804, 1815, 1828, 1837, 1841, 1847, 1852, 1858, 1871, 1875, 1880, 1884, 1889, 1895, 1900, 1904, 1909,
      1913, 1921, 1931, 1937, 1944, 1950, 1958, 1973, 1981, 1989, 1996, 2008, 2016, 2023, 2034, 2043, 2049,
      2056, 2064, 2071, 2085, 2098, 2109, 2122, 2134, 2144, 2159, 2167, 2179, 2196, 2199, 2203, 2215, 2224,
      2236, 2248, 2259, 2271, 2283, 2295, 2309, 2319, 2339, 2346, 2357, 2368, 2383, 2399, 2404, 2410, 2421,
      2430, 2440, 2449, 2461, 2481, 2498, 2505, 2510, 2521, 2533, 2542, 2549, 2555, 2560, 2566, 2575, 2581,
      2587, 2595, 2602, 2612, 2620, 2632, 2648, 2667, 2692, 2699, 2711, 2723, 2736, 2745, 2756, 2765, 2776,
      2783, 2792, 2805, 2814, 2824, 2836, 2847, 2853, 2857, 2866, 2875, 2890, 2896, 2901, 2913, 2923, 2930,
      2939, 2946, 2953, 2963, 2973, 2982, 2989, 2998, 3006, 3012, 3021, 3032, 3049, 3063, 3071, 3074, 3077,
      3080, 3083, 3085, 3088, 3090, 3093, 3095, 3098, 3100, 3103, 3106, 3109, 3112, 3117, 3126, 3143, 3147,
      3155, 3171, 3183, 3195, 3210, 3219, 3229, 3240, 3251, 3263, 3274, 3292, 3310, 3323, 3330, 3334, 3339,
      3343, 3348, 3356, 3366, 3380, 3388, 3401, 3417, 3423, 3431, 3439, 3452, 3464, 3480, 3494, 3504, 3518,
      3531, 3545, 3556, 3565, 3574, 3583, 3597, 3606, 3617, 3634, 3643, 3652, 3661, 3672, 3687, 3699, 3711,
      3724, 3745, 3756, 3775, 3779, 3782, 3792, 3798, 3811, 3821, 3829, 3840, 3854, 3866, 3876, 3888, 3900,
      3913, 3924, 3933, 3946, 3957, 3970, 3979, 3992, 4001, 4011, 4023, 4030, 4038, 4044, 4051, 4059, 4065,
      4072, 4080, 4086, 4090, 4098, 4106, 4117, 4125, 4131, 4137, 4145, 4151, 4157, 4165, 4171, 4177, 4187,
      4199, 4212, 4222, 4229, 4242, 4250, 4256, 4269, 4276, 4295, 4308, 4321, 4332, 4339, 4350, 4361, 4372,
      4379, 4385, 4390, 4393, 4398, 4403, 4408, 4411, 4413, 4418, 4424, 4429, 4435, 4443, 4450, 4459, 4469,
      4476, 4488, 4496, 4501, 4516, 4534, 4546, 4556, 4568, 4581, 4598, 4613, 4629, 4645, 4659, 4672, 4685,
      4696, 4711, 4718, 4727, 4731, 4739, 4745, 4757, 4766, 4772, 4777, 4782, 4791, 4801, 4810, 4821, 4830,
      4837, 4844, 4851, 4860, 4873, 4880, 4890, 4900, 4904, 4908, 4912, 4917, 4928, 4939, 4947, 4952, 4958,
      4964, 4977, 4985, 4995, 5001, 5006, 5016, 5025, 5032, 5036, 5043, 5051, 5059, 5068, 5076, 5083, 5089,
      5094, 5099, 5107, 5115, 5124, 5130, 5139, 5148, 5157, 5167, 5173, 5178, 5184, 5189, 5195, 5202, 5208,
      5219, 5225, 5238, 5244, 5250, 5259, 5265, 5272, 5286, 5294, 5303, 5310, 5318, 5326, 5337, 5347, 5358,
      5366, 5374, 5382, 5395, 5409, 5423, 5434, 5444, 5455, 5463, 5473, 5482, 5492, 5503, 5508, 5523, 5536,
      5545, 5552, 5561, 5568, 5581, 5592, 5602, 5614, 5624, 5632, 5637, 5646, 5655, 5664, 5677, 5689, 5692,
      5701, 5713, 5728, 5742, 5751, 5762, 5771, 5779, 5788, 5800, 5807, 5821, 5840, 5852, 5864, 5873, 5884,
      5895, 5906, 5914, 5924, 5936, 5942, 5949, 5957, 5967, 5980, 5986, 5997, 6008, 6014, 6022, 6031, 6042,
      6051, 6057, 6065, 6072, 6084, 6096, 6102, 6107, 6113, 6125, 6136, 6142, 6154, 6162, 6170, 6179, 6188,
      6202, 6219, 6236, 6250, 6270, 6290, 6311, 6327, 6343, 6360, 6375, 6391, 6401, 6413, 6421, 6430, 6444,
      6455, 6468, 6484, 6489, 6500, 6513, 6524, 6542, 6557, 6578, 6598, 6612, 6624, 6634, 6647, 6658, 6670,
      6682, 6690, 6697, 6705, 6717, 6723, 6740, 6761, 6776, 6787, 6795, 6803, 6809, 6818, 6830, 6839, 6852,
      6861, 6874, 6883, 6896, 6905, 6918, 6931, 6949, 6958, 6968, 6979, 6991, 7003, 7017, 7031, 7046, 7053,
      7060, 7067, 7074, 7081, 7088, 7102, 7114, 7129, 7138, 7148, 7163, 7173, 7183, 7199, 7211, 7223, 7233,
      7242, 7255, 7263, 7270, 7276, 7286, 7298, 7305, 7319, 7327, 7338, 7346, 7352, 7358, 7365, 7372, 7379,
      7386, 7393, 7399, 7406, 7412, 7419, 7425, 7433, 7442, 7447, 7452, 7455, 7470, 7479, 7497, 7512, 7521,
      7530, 7534, 7547, 7558, 7571, 7579, 7588, 7602, 7615, 7626, 7644, 7651, 7662, 7675, 7686, 7700, 7712,
      7724, 7733, 7750, 7764, 7771, 7779, 7792, 7805, 7821, 7828, 7840, 7850, 7865, 7875, 7884, 7893, 7902,
      7911, 7920, 7932, 7944, 7957, 7966, 7973, 7982, 7989, 7996, 8005, 8015, 8026, 8033, 8042, 8049, 8060, 8071);

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
      25, 19, 24, 22, 21, 23, 23, 23, 24, 19, 35, 16, 22, 22, 28, 30, 8, 12, 20, 19, 17, 17, 23, 31, 29, 18, 16,
      19, 22, 18, 20, 17, 15, 18, 18, 15, 14, 19, 15, 21, 18, 17, 26, 32, 43, 12, 21, 21, 19, 15, 20, 15, 20,
      14, 18, 21, 19, 17, 22, 19, 13, 9, 16, 16, 24, 10, 11, 20, 19, 15, 14, 14, 11, 16, 18, 12, 12, 16, 14, 14,
      21, 24, 25, 23, 17, 7, 7, 7, 7, 6, 6, 6, 6, 5, 5, 5, 5, 7, 6, 5, 12, 17, 30, 11, 15, 22, 20, 21, 21, 16,
      17, 18, 20, 21, 19, 29, 27, 18, 12, 10, 11, 9, 10, 13, 18, 23, 19, 26, 31, 18, 19, 13, 22, 21, 25, 25, 17,
      26, 25, 25, 16, 15, 15, 15, 21, 15, 20, 28, 17, 17, 18, 21, 27, 23, 24, 23, 34, 22, 33, 8, 8, 14, 12, 18,
      14, 14, 21, 23, 24, 18, 20, 20, 21, 22, 14, 24, 18, 20, 14, 20, 16, 16, 24, 15, 14, 13, 16, 15, 14, 14,
      13, 12, 8, 18, 12, 14, 20, 16, 16, 20, 16, 16, 20, 16, 16, 16, 17, 18, 16, 10, 20, 14, 10, 19, 11, 30, 18,
      23, 20, 16, 19, 19, 19, 26, 26, 23, 23, 24, 24, 24, 24, 23, 26, 27, 24, 27, 31, 27, 30, 30, 26, 34, 30,
      27, 22, 28, 16, 16, 19, 21, 25, 23, 26, 19, 22, 21, 20, 16, 22, 11, 14, 9, 16, 14, 22, 18, 14, 13, 13, 18,
      18, 17, 21, 19, 14, 14, 13, 18, 27, 15, 18, 20, 8, 8, 12, 12, 20, 21, 16, 12, 13, 13, 31, 15, 20, 15, 16,
      19, 18, 15, 10, 15, 17, 16, 18, 18, 18, 17, 15, 15, 20, 20, 21, 16, 16, 17, 19, 19, 16, 16, 17, 15, 13,
      14, 13, 23, 16, 24, 15, 15, 21, 16, 16, 25, 18, 22, 14, 15, 15, 20, 21, 24, 18, 17, 18, 26, 27, 28, 25,
      24, 28, 20, 18, 20, 18, 21, 11, 26, 23, 19, 17, 20, 14, 22, 19, 20, 20, 21, 16, 11, 18, 18, 18, 22, 22, 8,
      14, 22, 23, 23, 16, 19, 15, 13, 14, 18, 18, 26, 33, 20, 20, 17, 22, 22, 22, 19, 20, 22, 14, 15, 16, 18,
      23, 12, 14, 15, 10, 16, 13, 16, 19, 8, 11, 9, 20, 18, 8, 8, 8, 17, 14, 11, 16, 12, 12, 13, 15, 19, 26, 26,
      21, 32, 30, 30, 23, 23, 23, 21, 25, 15, 18, 15, 16, 23, 14, 19, 22, 13, 17, 18, 19, 26, 24, 34, 32, 23,
      20, 16, 20, 16, 20, 18, 12, 9, 11, 18, 13, 26, 34, 25, 16, 13, 14, 13, 13, 18, 11, 19, 11, 19, 11, 19, 11,
      21, 19, 25, 14, 17, 19, 18, 19, 20, 23, 20, 10, 10, 10, 10, 10, 10, 23, 20, 18, 12, 17, 24, 17, 16, 22,
      22, 19, 18, 18, 21, 14, 10, 10, 15, 20, 12, 24, 14, 21, 17, 15, 15, 13, 13, 13, 13, 13, 13, 13, 13, 13,
      13, 18, 17, 12, 15, 8, 22, 15, 26, 23, 17, 20, 11, 23, 19, 21, 12, 12, 23, 22, 19, 29, 16, 20, 21, 23, 25,
      24, 24, 22, 29, 29, 12, 12, 19, 19, 27, 15, 21, 17, 25, 18, 15, 15, 15, 15, 19, 24, 24, 25, 18, 16, 18,
      17, 17, 19, 22, 23, 15, 17, 16, 20, 18, 11);

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

   function Value_Count (T : Lookup_Table; Wing : Boolean := False) return Natural is
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
        when Table_Tpa_Mode => (if Wing then 3 else 2),
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
        when Table_Tpa_Curve_Type => 2,
        when Table_Tpa_Speed_Type => 2,
        when Table_Yaw_Type => 2,
        when Table_Transponder_Provider => 4,
        when Table_Baud_Rate => 16,
        when Table_Telemetry_Protocol => 7);

   --  The value names in one text, with each table's first value index;
   --  the index tables run past the last value by a longest table, so a
   --  table's first index plus an index under its count stays within them.
   Values_Length : constant := 3721;
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
     & "ITCHROLLPITCHYAWTHROTTLEOFFONUNTIL_FIRST_ARMOFFSPISDIONORMALPITCHONLYFULLPDDPDSOFFI_FREEZEIPIDPD_I_FREEZERA"
     & "CEBEACONSTATUSBLACKWHITEREDORANGEYELLOWLIME_GREENGREENMINT_GREENCYANLIGHT_BLUEBLUEDARK_VIOLETMAGENTADEEP_PI"
     & "NKROLLPITCHYAWDEFAULTBARO_ONLYGPS_ONLYRANGEFINDER_PREFERRANGEFINDER_ONLYOFFONAUTOOFF2_POINT3_POINT4_POINTAU"
     & "TOTIM1TIM8NONEAUTOMAX7456MSPFRSKYOSDFBOSDNONERTC6705SMARTAUDIOTRAMPMSPOFFONFIRST_ARMINGNULLLFLEGACYLINEARDY"
     & "NAMICEZLANDINGOFFRPRPYTRANSPARENTBLACKGRAYLIGHT_GRAYAU433AU915EU433EU868IN866FCC915ISM2400CE2400CLASSICHYPE"
     & "RBOLICBASICADVANCEDRUDDERDIFF_THRUSTNONEILAPARCITIMERERLTAUTO9600192003840057600115200230400250000400000460"
     & "8005000009216001000000150000020000002470000NONEFRSKY_HUBHOTTLTMSMARTPORTMAVLINKIBUS                        "
     & "   ";

   type Value_Index is range 0 .. 624;
   type Value_Start is range 0 .. Values_Length;
   type Value_Length is range 0 .. Max_Value_Length;
   subtype Table_First_Index is Value_Index range 0 .. 513;

   Table_Firsts : constant array (Lookup_Table) of Table_First_Index :=
     (0, 2, 5, 15, 19, 25, 33, 38, 43, 46, 48, 51, 54, 58, 61, 66, 71, 74, 76, 93, 113, 117, 146, 161, 176, 287,
      298, 301, 305, 309, 312, 315, 319, 322, 326, 329, 332, 348, 351, 355, 358, 361, 366, 370, 373, 376, 380,
      385, 387, 389, 393, 396, 399, 402, 405, 410, 413, 427, 430, 435, 438, 442, 445, 451, 457, 460, 462, 466,
      469, 473, 481, 483, 485, 487, 491, 507);

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
      3004, 3009, 3012, 3020, 3023, 3025, 3040, 3043, 3046, 3050, 3056, 3065, 3069, 3071, 3072, 3075, 3078,
      3086, 3087, 3090, 3101, 3105, 3111, 3117, 3122, 3127, 3130, 3136, 3142, 3152, 3157, 3167, 3171, 3181,
      3185, 3196, 3203, 3212, 3216, 3221, 3224, 3231, 3240, 3248, 3266, 3282, 3285, 3287, 3291, 3294, 3301,
      3308, 3315, 3319, 3323, 3327, 3331, 3335, 3342, 3345, 3353, 3358, 3362, 3369, 3369, 3379, 3384, 3387,
      3390, 3392, 3404, 3408, 3410, 3416, 3422, 3429, 3438, 3441, 3443, 3446, 3457, 3462, 3466, 3476, 3481,
      3486, 3491, 3496, 3501, 3507, 3514, 3520, 3527, 3537, 3542, 3550, 3556, 3567, 3571, 3575, 3584, 3588,
      3592, 3596, 3601, 3606, 3611, 3617, 3623, 3629, 3635, 3641, 3647, 3653, 3660, 3667, 3674, 3681, 3685,
      3694, 3698, 3701, 3710, 3717, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

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
      4, 5, 3, 8, 3, 2, 15, 3, 3, 4, 6, 9, 4, 2, 1, 3, 3, 8, 1, 3, 11, 4, 6, 6, 5, 5, 3, 6, 6, 10, 5, 10, 4, 10,
      4, 11, 7, 9, 4, 5, 3, 7, 9, 8, 18, 16, 3, 2, 4, 3, 7, 7, 7, 4, 4, 4, 4, 4, 7, 3, 8, 5, 4, 7, 0, 10, 5, 3,
      3, 2, 12, 4, 2, 6, 6, 7, 9, 3, 2, 3, 11, 5, 4, 10, 5, 5, 5, 5, 5, 6, 7, 6, 7, 10, 5, 8, 6, 11, 4, 4, 9, 4,
      4, 4, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 4, 9, 4, 3, 9, 7, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

   function Value_Name (T : Lookup_Table; Index : Natural) return String is
     (Value_Names
        (Natural (Value_Starts (Table_Firsts (T) + Value_Index (Index))) + 1
         .. Natural (Value_Starts (Table_Firsts (T) + Value_Index (Index)))
            + Natural (Value_Lengths (Table_Firsts (T) + Value_Index (Index)))));

end Adaflight.Settings_Table;
