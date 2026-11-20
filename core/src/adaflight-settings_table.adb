package body Adaflight.Settings_Table with SPARK_Mode is

   --  Each setting's limits and group as indexes into the tables of the distinct ones, so the info
   --  of every setting packs into a few bytes of flash.
   type Limit_Pair is record
      Min : Limit;
      Max : Limit;
   end record with Pack;

   type Limit_Index is range 0 .. 171;
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
      (Min => 0, Max => 20), (Min => 0, Max => 24), (Min => 0, Max => 30), (Min => 0, Max => 31),
      (Min => 0, Max => 32), (Min => 0, Max => 33), (Min => 0, Max => 34), (Min => 0, Max => 35),
      (Min => 0, Max => 36), (Min => 0, Max => 37), (Min => 0, Max => 38), (Min => 0, Max => 39),
      (Min => 0, Max => 40), (Min => 0, Max => 41), (Min => 0, Max => 45), (Min => 0, Max => 50),
      (Min => 0, Max => 60), (Min => 0, Max => 70), (Min => 0, Max => 75), (Min => 0, Max => 80),
      (Min => 0, Max => 90), (Min => 0, Max => 95), (Min => 0, Max => 100), (Min => 0, Max => 119),
      (Min => 0, Max => 120), (Min => 0, Max => 150), (Min => 0, Max => 180), (Min => 0, Max => 200),
      (Min => 0, Max => 250), (Min => 0, Max => 255), (Min => 0, Max => 300), (Min => 0, Max => 359),
      (Min => 0, Max => 400), (Min => 0, Max => 500), (Min => 0, Max => 1000), (Min => 0, Max => 1700),
      (Min => 0, Max => 2000), (Min => 0, Max => 3000), (Min => 0, Max => 5000), (Min => 0, Max => 5999),
      (Min => 0, Max => 10000), (Min => 0, Max => 16000), (Min => 0, Max => 20000), (Min => 0, Max => 30000),
      (Min => 0, Max => 32000), (Min => 0, Max => 32767), (Min => 0, Max => 60000), (Min => 0, Max => 65535),
      (Min => 0, Max => 262143), (Min => 0, Max => 4294967295), (Min => 1, Max => 3), (Min => 1, Max => 4),
      (Min => 1, Max => 5), (Min => 1, Max => 9), (Min => 1, Max => 16), (Min => 1, Max => 18), (Min => 1, Max => 20),
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
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf2_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gyro_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf2_Static_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch1_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch1_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch2_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Notch2_Cutoff =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Calib_Duration =>
        (Kind => U16, Where => Master, How => Direct, Limits => 146, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Calib_Noise_Limit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U16, Where => Master, How => Direct, Limits => 160, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => False),
      Gyro_Enabled_Bitmask =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_1_Enabled =>
        (Kind => U8, Where => Hardware, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_2_Enabled =>
        (Kind => U8, Where => Hardware, How => Bitset, Limits => 27, Table => Table_Off_On, Count => 1, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Dyn_Notch_Count =>
        (Kind => U8, Where => Master, How => Direct, Limits => 31, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Dyn_Notch_Q =>
        (Kind => U16, Where => Master, How => Direct, Limits => 104, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Dyn_Notch_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 133, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Dyn_Notch_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 155, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 71, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Gyro_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U8, Where => Hardware, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U8, Where => Hardware, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U8, Where => Hardware, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 79, In_Multirotor => True, In_Wing => True),
      Pitot_Hardware =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Pitot_Hardware, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 79, In_Multirotor => True, In_Wing => True),
      Mid_Rc =>
        (Kind => U16, Where => Master, How => Direct, Limits => 169, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Min_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Max_Check =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Channel =>
        (Kind => I8, Where => Master, How => Direct, Limits => 37, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Src_Frame_Errors =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Scale =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Offset =>
        (Kind => I8, Where => Master, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Invert =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Src_Frame_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rssi_Smoothing =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Auto_Factor =>
        (Kind => U8, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Auto_Factor_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Setpoint_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Throttle_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rc_Smoothing_Debug_Axis =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Rc_Smoothing_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Fpv_Mix_Degrees =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rx_Min_Usec =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rx_Max_Usec =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Serialrx_Halfduplex =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Rx_Uart =>
        (Kind => I8, Where => Master, How => Identifier, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 15, In_Multirotor => True, In_Wing => True),
      Msp_Override_Channels_Mask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 86, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45, In_Multirotor => True, In_Wing => True),
      Adc_Tempsensor_Calibration30 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 45, In_Multirotor => True, In_Wing => True),
      Adc_Tempsensor_Calibration110 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Min_Command =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Kv =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 107, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Idle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 157, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Pwm_Inversion =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Poles =>
        (Kind => U8, Where => Master, How => Direct, Limits => 114, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Motor_Output_Reordering =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length => 0,
         Write_Once => False, Group => 4, In_Multirotor => True, In_Wing => True),
      Thr_Corr_Value =>
        (Kind => U8, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 23, In_Multirotor => True, In_Wing => True),
      Thr_Corr_Angle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 103, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 23, In_Multirotor => True, In_Wing => True),
      Failsafe_Delay =>
        (Kind => U8, Where => Master, How => Direct, Limits => 100, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Landing_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Switch_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Failsafe_Switch_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Throttle_Low_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 68, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Procedure =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Failsafe, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Recovery_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 100, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 0, In_Multirotor => True, In_Wing => True),
      Failsafe_Stick_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 80, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Max_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Full_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Min_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Warning_Cell_Voltage =>
        (Kind => U16, Where => Battery_Profile, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Cbat_Alert_Percent =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Force_Battery_Cell_Count =>
        (Kind => U8, Where => Battery_Profile, How => Direct, Limits => 39, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 77, In_Multirotor => True, In_Wing => True),
      Vbat_Hysteresis =>
        (Kind => U8, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Current_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Current_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Battery_Meter =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Voltage_Meter, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Detect_Cell_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Limits => 74, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Use_Vbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Use_Cbat_Alerts =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Cutoff_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Display_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Sag_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Ibat_Lpf_Period =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Duration_For_Warning =>
        (Kind => U8, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Duration_For_Critical =>
        (Kind => U8, Where => Master, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 6, In_Multirotor => True, In_Wing => True),
      Vbat_Scale =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 36, In_Multirotor => True, In_Wing => True),
      Vbat_Divider =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 36, In_Multirotor => True, In_Wing => True),
      Vbat_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 36, In_Multirotor => True, In_Wing => True),
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
        (Kind => U16, Where => Master, How => Direct, Limits => 79, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => I16, Where => Hardware, How => Direct, Limits => 79, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 40, In_Multirotor => True, In_Wing => True),
      Beeper_Dshot_Beacon_Tone =>
        (Kind => U8, Where => Master, How => Direct, Limits => 90, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 39, In_Multirotor => True, In_Wing => True),
      Yaw_Motors_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Mixer_Type =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Mixer_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Crashflip_Motor_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Crashflip_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Crashflip_Auto_Rearm =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_P =>
        (Kind => U16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_I =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_D =>
        (Kind => U16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Rpm_Limit_Value =>
        (Kind => U16, Where => Master, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 13, In_Multirotor => True, In_Wing => True),
      Three_D_Deadband_Low =>
        (Kind => U16, Where => Master, How => Direct, Limits => 164, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Deadband_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 171, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Neutral =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Deadband_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Limit_Low =>
        (Kind => U16, Where => Master, How => Direct, Limits => 164, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Limit_High =>
        (Kind => U16, Where => Master, How => Direct, Limits => 171, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Three_D_Switched_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 17, In_Multirotor => True, In_Wing => True),
      Servo_Center_Pulse =>
        (Kind => U16, Where => Master, How => Direct, Limits => 165, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Servo_Pwm_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 142, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Servo_Lowpass_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 70, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Tri_Unarmed_Servo =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Channel_Forwarding_Start =>
        (Kind => U8, Where => Master, How => Direct, Limits => 113, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 26, In_Multirotor => True, In_Wing => True),
      Rateprofile_Name =>
        (Kind => U8, Where => Rate_Profile, How => Text, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length
         => 1, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Thr_Mid =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Thr_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Thr_Hover =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Rates_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 27, Table => Table_Rates_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Quickrates_Rc_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Rc_Rate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Expo =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Srate =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Throttle_Limit_Type =>
        (Kind => U8, Where => Rate_Profile, How => Lookup, Limits => 27, Table => Table_Throttle_Limit_Type, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Throttle_Limit_Percent =>
        (Kind => U8, Where => Rate_Profile, How => Direct, Limits => 136, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Roll_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Pitch_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Yaw_Rate_Limit =>
        (Kind => U16, Where => Rate_Profile, How => Direct, Limits => 156, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 7, In_Multirotor => True, In_Wing => True),
      Reboot_Character =>
        (Kind => U8, Where => Master, How => Direct, Limits => 140, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 8, In_Multirotor => True, In_Wing => True),
      Serial_Update_Rate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 151, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 8, In_Multirotor => True, In_Wing => True),
      Imu_Dcm_Kp =>
        (Kind => U16, Where => Master, How => Direct, Limits => 82, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Imu_Dcm_Ki =>
        (Kind => U16, Where => Master, How => Direct, Limits => 82, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Small_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 64, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Imu_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Limits => 89, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Mag_Declination =>
        (Kind => I16, Where => Master, How => Direct, Limits => 12, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 14, In_Multirotor => True, In_Wing => True),
      Auto_Disarm_Delay =>
        (Kind => U8, Where => Master, How => Direct, Limits => 54, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U8, Where => Master, How => Direct, Limits => 94, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U16, Where => Master, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Alt_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Rescue_Alt_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Initial_Climb =>
        (Kind => U16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Ascend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 145, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Return_Alt =>
        (Kind => U16, Where => Master, How => Direct, Limits => 120, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Ground_Speed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Descent_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 119, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Descend_Rate =>
        (Kind => U16, Where => Master, How => Direct, Limits => 138, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Sanity_Checks =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Gps_Rescue_Sanity_Check, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Min_Sats =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Allow_Arming_Without_Fix =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Rescue_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 27, In_Multirotor => True, In_Wing => False),
      Gps_Lap_Timer_Gate_Lat =>
        (Kind => I32, Where => Master, How => Direct, Limits => 1, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Gps_Lap_Timer_Gate_Lon =>
        (Kind => I32, Where => Master, How => Direct, Limits => 0, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Gps_Lap_Timer_Min_Lap_Time_S =>
        (Kind => U16, Where => Master, How => Direct, Limits => 75, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Gps_Lap_Timer_Gate_Tolerance_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 30, In_Multirotor => True, In_Wing => True),
      Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 42, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16, In_Multirotor => True, In_Wing => True),
      Yaw_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16, In_Multirotor => True, In_Wing => True),
      Yaw_Control_Reversed =>
        (Kind => I8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 16, In_Multirotor => True, In_Wing => True),
      Alt_Hold_Climb_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 31, In_Multirotor => True, In_Wing => False),
      Alt_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 55, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 31, In_Multirotor => True, In_Wing => False),
      Pos_Hold_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Poshold_Position_Source =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Poshold_Source, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Poshold_Opticalflow_Quality_Min =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Poshold_Opticalflow_Max_Range =>
        (Kind => U16, Where => Master, How => Direct, Limits => 143, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 33, In_Multirotor => True, In_Wing => False),
      Launch_Climb_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 52, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Max_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 117, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Detect_Accel =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Detect_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Detect_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 129, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Idle_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Idle_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 84, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Throttle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Motor_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Spinup_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Min_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 84, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Timeout =>
        (Kind => U16, Where => Master, How => Direct, Limits => 84, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Max_Altitude =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_End_Time =>
        (Kind => U16, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Abort_Deadband =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Launch_Abort_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 80, In_Multirotor => False, In_Wing => True),
      Pid_Process_Denom =>
        (Kind => U8, Where => Master, How => Direct, Limits => 92, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => True),
      Runaway_Takeoff_Prevention =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => False),
      Runaway_Takeoff_Deactivate_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => False),
      Runaway_Takeoff_Deactivate_Throttle_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 41, In_Multirotor => True, In_Wing => False),
      Profile_Name =>
        (Kind => U8, Where => PID_Profile, How => Text, Limits => 27, Table => Table_Off_On, Count => 8, Min_Length =>
         1, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Dyn_Min_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Dyn_Max_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Dyn_Expo =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 33, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Dterm_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf1_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf2_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Dterm_Lpf_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Lpf2_Static_Hz =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Notch_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dterm_Notch_Cutoff =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Vbat_Sag_Compensation =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Pid_At_Min_Throttle =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Anti_Gravity_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Anti_Gravity_Cutoff_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 112, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Anti_Gravity_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acc_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acc_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Dthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 130, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Gthreshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 151, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Setpoint_Threshold =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Time =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 153, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Recovery_Angle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 115, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Recovery_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 141, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Crash_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
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
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 96, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Iterm_Windup =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 132, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Pidsum_Limit =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Pidsum_Limit_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 149, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Yaw_Lowpass_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Throttle_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Throttle_Boost_Cutoff =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 124, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Lookahead_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Debug_Axis =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Acro_Trainer_Debug, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Acro_Trainer_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 137, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      P_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      I_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      F_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      P_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      I_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      F_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      P_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      I_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      F_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      S_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      S_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      S_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Angle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Feedforward =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Feedforward_Smoothing_Ms =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 126, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 124, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Angle_Earth_Ref =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Level_Strength =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Limit_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Limit_Degrees =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 126, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Ignore_Sticks =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Horizon_Delay_Ms =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 131, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Lag_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Lead_Freq_Hz =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Amplitude_Roll =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Amplitude_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Amplitude_Yaw =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Frequency_Start_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 104, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Frequency_End_Deci_Hz =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 106, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Time_Seconds =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 102, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Chirp_Repeat =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 91, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Roll =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Pitch =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Yaw =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      D_Max_Advance =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Motor_Output_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length
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
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Launch_Angle_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 57, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Launch_Control_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => False),
      Thrust_Linear =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 63, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Transition =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Averaging =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Feedforward_Averaging, Count =>
         0, Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Smooth_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 59, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Jitter_Factor =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 38, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Boost =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Max_Rate_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Yaw_Hold_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Feedforward_Yaw_Hold_Time =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 126, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_Min_Rpm =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_P_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 101, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 101, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Dyn_Idle_Max_Increase =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 127, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Level_Race_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pids_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Simplified_Tuning_Pids_Mode,
         Count => 0, Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Master_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_I_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_D_Max_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Feedforward_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pitch_D_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Pitch_Pi_Gain =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Dterm_Filter =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Dterm_Filter_Multiplier =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Simplified_Gyro_Filter =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Simplified_Gyro_Filter_Multiplier =>
        (Kind => U8, Where => Master, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 5, In_Multirotor => True, In_Wing => True),
      Tpa_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Tpa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Rate =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 166, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Low_Rate =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Low_Breakpoint =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 166, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Low_Always =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Tpa_Speed_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Tpa_Speed_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Basic_Delay =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Basic_Gravity =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Prop_Pitch =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Mass =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Drag_K =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Adv_Thrust =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 108, Table => Table_Off_On, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Max_Voltage =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Speed_Pitch_Offset =>
        (Kind => I16, Where => PID_Profile, How => Direct, Limits => 2, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Type =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Tpa_Curve_Type, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Stall_Throttle =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Pid_Thr0 =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Pid_Thr100 =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Tpa_Curve_Expo =>
        (Kind => I8, Where => PID_Profile, How => Direct, Limits => 17, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Ez_Landing_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Ez_Landing_Limit =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 56, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Ez_Landing_Speed =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Landing_Disarm_Threshold =>
        (Kind => U8, Where => PID_Profile, How => Direct, Limits => 66, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => True, In_Wing => True),
      Spa_Roll_Center =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Roll_Width =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Roll_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Spa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Pitch_Center =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Pitch_Width =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Pitch_Mode =>
        (Kind => U8, Where => PID_Profile, How => Lookup, Limits => 27, Table => Table_Spa_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Yaw_Center =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 9, In_Multirotor => False, In_Wing => True),
      Spa_Yaw_Width =>
        (Kind => U16, Where => PID_Profile, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length
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
        (Kind => U8, Where => Master, How => Direct, Limits => 62, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U16, Where => Master, How => Direct, Limits => 81, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Min_Txbuff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 99, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Ext_Status_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Rc_Chan_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Pos_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Extra1_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Extra2_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 20, In_Multirotor => True, In_Wing => True),
      Mavlink_Extra3_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U16, Where => Master, How => Direct, Limits => 147, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Beacon_Percent =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Beacon_Armed_Only =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Brightness =>
        (Kind => U8, Where => Master, How => Direct, Limits => 118, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Rainbow_Delta =>
        (Kind => U16, Where => Master, How => Direct, Limits => 69, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 18, In_Multirotor => True, In_Wing => True),
      Ledstrip_Rainbow_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 105, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U32, Where => Master, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Link_Quality_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Dbm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 14, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rsnr_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 19, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Cap_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 80, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Alt_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Distance_Alarm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Rpm_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Current_Alarm =>
        (Kind => I16, Where => Master, How => Direct, Limits => 26, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Core_Temp_Alarm =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Max_Pit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Max_Rol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Invert =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Logo_On_Arming =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Osd_Logo_On_Arming, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Logo_On_Arming_Duration =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 83, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Tim2 =>
        (Kind => U16, Where => Master, How => Direct, Limits => 83, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Vbat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Link_Quality_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Link_Tx_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rssi_Dbm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rsnr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Tim_1_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Tim_2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Remaining_Time_Estimate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Flymode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Anti_Gravity_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_G_Force_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Throttle_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Vtx_Channel_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Crosshairs_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Sbar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Ah_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Current_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Mah_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wh_Drawn_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Motor_Diag_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Craft_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pilot_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lap_Curr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lap_Prev_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Lap_Best3_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Gps_Sats_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Home_Dir_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Home_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Flight_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Compass_Bar_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Altitude_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Roll_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Pitch_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Yaw_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Debug_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Debug2_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Power_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pidrate_Profile_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Avg_Cell_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pit_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rol_Ang_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Battery_Usage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Disarmed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Nheading_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Up_Down_Reference_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Ready_Mode_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pos_Hold_Ready_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Nvario_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Tmp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Rpm_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Esc_Rpm_Freq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rtc_Date_Time_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Adjustment_Range_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Flip_Arrow_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Core_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Log_Status_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stick_Overlay_Left_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stick_Overlay_Right_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stick_Overlay_Radio_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 89, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Rate_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Pid_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Battery_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Profile_Name_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Rcchannels_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Camera_Frame_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Efficiency_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Total_Flights_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Goggle_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Vtx_Voltage_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Bitrate_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Delay_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Lq_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Goggle_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Vtx_Dvr_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Warnings_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Vtx_Temp_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Sys_Fan_Speed_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Stat_Bitmask =>
        (Kind => U32, Where => Master, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Profile =>
        (Kind => U8, Where => Master, How => Direct, Limits => 88, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U8, Where => Master, How => Direct, Limits => 110, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Camera_Frame_Height =>
        (Kind => U8, Where => Master, How => Direct, Limits => 109, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Stat_Avg_Cell_Value =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Framerate_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 97, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Menu_Background =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Cms_Background, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Channel =>
        (Kind => U8, Where => Master, How => Direct, Limits => 93, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Scale =>
        (Kind => U16, Where => Master, How => Direct, Limits => 104, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Aux_Symbol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Craftname_Msgs =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 38, In_Multirotor => True, In_Wing => True),
      Osd_Lidar_Dist_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Custom_Serial_Text_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Current_Lat_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Current_Lon_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Current_Alt_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Distance_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Direction_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Next_Number_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Wp_Eta_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => True),
      Osd_Nav_Map_Pos =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 82, In_Multirotor => True, In_Wing => False),
      Osd_Nav_Map_Mode =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 78, In_Multirotor => True, In_Wing => False),
      Osd_Nav_Map_Centre =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 78, In_Multirotor => True, In_Wing => False),
      Osd_Nav_Map_Min_Scale_M =>
        (Kind => U16, Where => Master, How => Direct, Limits => 135, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 78, In_Multirotor => True, In_Wing => False),
      Osd_Airspeed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 77, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 37, In_Multirotor => True, In_Wing => True),
      Vtx_Pit_Mode_Freq =>
        (Kind => U16, Where => Master, How => Direct, Limits => 77, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U16, Where => Master, How => Direct, Limits => 79, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U8, Where => Hardware, How => Direct, Limits => 121, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 53, In_Multirotor => True, In_Wing => True),
      Camera_Control_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Camera_Control_Mode, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Ref_Voltage =>
        (Kind => U16, Where => Master, How => Direct, Limits => 154, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Key_Delay =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 54, In_Multirotor => True, In_Wing => True),
      Camera_Control_Internal_Resistance =>
        (Kind => U16, Where => Master, How => Direct, Limits => 129, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => I16, Where => Master, How => Direct, Limits => 69, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U32, Where => Master, How => Direct, Limits => 76, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 64, In_Multirotor => True, In_Wing => True),
      Rcdevice_Protocol_Version =>
        (Kind => U8, Where => Master, How => Direct, Limits => 28, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 64, In_Multirotor => True, In_Wing => True),
      Rcdevice_Feature =>
        (Kind => U16, Where => Master, How => Direct, Limits => 85, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => U8, Where => Hardware, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      Gyro_2_Bustype =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Bus_Type, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      Gyro_2_Spibus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      Gyro_2_I2c_Bus =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 29, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      Gyro_2_I2c_Address =>
        (Kind => U8, Where => Hardware, How => Direct, Limits => 61, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 65, In_Multirotor => True, In_Wing => True),
      I2c1_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c1_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c2_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c2_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c3_Pullup =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      I2c3_Clockspeed_Khz =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 150, Table => Table_Off_On, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 52, In_Multirotor => True, In_Wing => True),
      Mco2_On_Pc9 =>
        (Kind => U8, Where => Hardware, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 66, In_Multirotor => True, In_Wing => True),
      Spektrum_Spi_Protocol =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 72, In_Multirotor => True, In_Wing => True),
      Scheduler_Relax_Rx =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73, In_Multirotor => True, In_Wing => True),
      Scheduler_Relax_Osd =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73, In_Multirotor => True, In_Wing => True),
      Scheduler_Debug_Task =>
        (Kind => U16, Where => Hardware, How => Direct, Limits => 51, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 73, In_Multirotor => True, In_Wing => True),
      Cpu_Late_Limit_Permille =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
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
        (Kind => U16, Where => Master, How => Direct, Limits => 158, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Min_Hz =>
        (Kind => U8, Where => Master, How => Direct, Limits => 139, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Fade_Range_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 72, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Rpm_Filter_Lpf_Hz =>
        (Kind => U16, Where => Master, How => Direct, Limits => 148, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 68, In_Multirotor => True, In_Wing => True),
      Flysky_Spi_Tx_Id =>
        (Kind => U32, Where => Master, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 57, In_Multirotor => True, In_Wing => True),
      Flysky_Spi_Rf_Channels =>
        (Kind => U8, Where => Master, How => List, Limits => 27, Table => Table_Off_On, Count => 16, Min_Length => 0,
         Write_Once => False, Group => 57, In_Multirotor => True, In_Wing => True),
      Stats_Min_Armed_Time_S =>
        (Kind => I8, Where => Master, How => Direct, Limits => 25, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Total_Flights =>
        (Kind => U32, Where => Master, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Total_Time_S =>
        (Kind => U32, Where => Master, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Total_Dist_M =>
        (Kind => U32, Where => Master, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Save_Move_Limit =>
        (Kind => U8, Where => Master, How => Direct, Limits => 67, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 69, In_Multirotor => True, In_Wing => True),
      Stats_Mah_Used =>
        (Kind => U32, Where => Master, How => Direct, Limits => 87, Table => Table_Off_On, Count => 0, Min_Length =>
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
        (Kind => I8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Altitude_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Limits => 131, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Rangefinder_Max_Range_Cm =>
        (Kind => U16, Where => Master, How => Direct, Limits => 143, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Altitude_D_Lpf =>
        (Kind => U16, Where => Master, How => Direct, Limits => 131, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 28, In_Multirotor => True, In_Wing => True),
      Ap_Landing_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Hover_Throttle =>
        (Kind => U16, Where => Master, How => Direct, Limits => 73, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Throttle_Min =>
        (Kind => U16, Where => Master, How => Direct, Limits => 168, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Throttle_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 170, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_I =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_D =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_A =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Altitude_F =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_I =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_D =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_A =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_F =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Position_Cutoff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 122, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Stop_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Angle =>
        (Kind => U8, Where => Master, How => Direct, Limits => 123, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Yaw_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 126, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Yaw_P =>
        (Kind => U8, Where => Master, How => Direct, Limits => 65, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Velocity_Drag_Coeff =>
        (Kind => U8, Where => Master, How => Direct, Limits => 60, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 153, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Waypoint_Arrival_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 153, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Waypoint_Hold_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 143, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Stick_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Throttle_Deadband =>
        (Kind => U16, Where => Master, How => Direct, Limits => 71, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Yaw_Mode =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ap_Yaw_Mode, Count => 0, Min_Length
         => 0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Min_Forward_Velocity =>
        (Kind => U16, Where => Master, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Corner_Speed =>
        (Kind => U16, Where => Master, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Corner_Delta_V =>
        (Kind => U16, Where => Master, How => Direct, Limits => 152, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Decel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Accel =>
        (Kind => U16, Where => Master, How => Direct, Limits => 134, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Carrot_Lead_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 111, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Carrot_Lead_Max =>
        (Kind => U16, Where => Master, How => Direct, Limits => 163, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Nav_Preturn_Dist =>
        (Kind => U16, Where => Master, How => Direct, Limits => 161, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Velocity_Buildup_Max_Pitch =>
        (Kind => U8, Where => Master, How => Direct, Limits => 38, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 98, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Hold_Orbit_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 159, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Hold_Figure8_Width =>
        (Kind => U16, Where => Master, How => Direct, Limits => 162, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Descent_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Detection_Time =>
        (Kind => U8, Where => Master, How => Direct, Limits => 116, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Spiral_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Spiral_Radius =>
        (Kind => U16, Where => Master, How => Direct, Limits => 144, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Spiral_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 95, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Velocity_Threshold =>
        (Kind => U8, Where => Master, How => Direct, Limits => 125, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Landing_Throttle_Threshold =>
        (Kind => U16, Where => Master, How => Direct, Limits => 128, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Enable =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Period =>
        (Kind => U16, Where => Master, How => Direct, Limits => 118, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Min_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Limits => 153, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Max_Lookahead =>
        (Kind => U16, Where => Master, How => Direct, Limits => 167, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Max_Cross_Track_Error =>
        (Kind => U16, Where => Master, How => Direct, Limits => 167, Table => Table_Off_On, Count => 0, Min_Length =>
         0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_L1_Turn_Rate =>
        (Kind => U8, Where => Master, How => Direct, Limits => 58, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Min_Nav_Altitude_M =>
        (Kind => U8, Where => Master, How => Direct, Limits => 53, Table => Table_Off_On, Count => 0, Min_Length => 0,
         Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Rx_Loss_Policy =>
        (Kind => U8, Where => Master, How => Lookup, Limits => 27, Table => Table_Ap_Rx_Loss_Policy, Count => 0,
         Min_Length => 0, Write_Once => False, Group => 32, In_Multirotor => True, In_Wing => False),
      Ap_Max_Distance_From_Home =>
        (Kind => U16, Where => Master, How => Direct, Limits => 78, Table => Table_Off_On, Count => 0, Min_Length =>
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

   --  The limits of a setting in a build, where the wing build and a build without the LED strip or the GPS or the
   --  compass or the barometer or the rangefinders have others.
   function Limits_Of
     (S : Setting; Wing : Boolean; LED_Strip : Boolean; GPS : Boolean; Compass : Boolean; Barometer : Boolean;
      Rangefinder : Boolean)
      return Limit_Index is
     (if S = Scheduler_Debug_Task then
        (if LED_Strip then
          (if GPS then
            (if Compass then
              (if Barometer then (if Rangefinder then 51 else 49) else (if Rangefinder then 50 else 48))
             else (if Barometer then (if Rangefinder then 49 else 47) else (if Rangefinder then 48 else 46)))
           else (if Compass then
                  (if Barometer then (if Rangefinder then 47 else 45) else (if Rangefinder then 46 else 44))
                 else (if Barometer then (if Rangefinder then 45 else 43) else (if Rangefinder then 44 else 42))))
         else (if GPS then
                (if Compass then
                  (if Barometer then (if Rangefinder then 50 else 48) else (if Rangefinder then 49 else 47))
                 else (if Barometer then (if Rangefinder then 48 else 46) else (if Rangefinder then 47 else 45)))
               else (if Compass then
                      (if Barometer then (if Rangefinder then 46 else 44) else (if Rangefinder then 45 else 43))
                     else (if Barometer then (if Rangefinder then 44 else 42) else (if Rangefinder then 43 else 41)))))
      elsif Wing then (case S is when Tpa_Low_Rate => 15, when others => Infos (S).Limits)
      else Infos (S).Limits);

   --  Whether a setting exists only in a build with the flight plan.
   function Needs_Flight_Plan (S : Setting) return Boolean is
     (S in Osd_Wp_Number_Pos .. Osd_Nav_Map_Min_Scale_M | Ap_Waypoint_Arrival_Radius .. Ap_Geofence_Action);

   --  Whether a setting exists only on a board with a second gyro.
   function Needs_Second_Gyro (S : Setting) return Boolean is
     (S in Gyro_Enabled_Bitmask .. Gyro_2_Enabled | Gyro_2_Bustype .. Gyro_2_I2c_Address);

   --  Whether a setting exists only in a build with servos.
   function Needs_Servos (S : Setting) return Boolean is
     (S in Blackbox_Disable_Servos | Gimbal_Mode | Servo_Center_Pulse .. Channel_Forwarding_Start);

   --  Whether a setting exists only in a build with the LED strip.
   function Needs_LED_Strip (S : Setting) return Boolean is
     (S in Ledstrip_Visual_Beeper .. Ledstrip_Rainbow_Freq);

   --  Whether a setting exists only in a build with the GPS.
   function Needs_GPS (S : Setting) return Boolean is
     (S in Blackbox_Disable_Gps | Gps_Provider .. Gps_Lap_Timer_Gate_Tolerance_M | Alt_Hold_Climb_Rate ..
        Poshold_Opticalflow_Max_Range | Frsky_Default_Lat .. Frsky_Unit | Osd_Gps_Lap_Curr_Pos ..
        Osd_Gps_Lap_Best3_Pos | Osd_Pos_Hold_Ready_Pos | Osd_Wp_Number_Pos .. Osd_Nav_Map_Min_Scale_M |
        Ap_Waypoint_Arrival_Radius .. Ap_Geofence_Action);

   --  Whether a setting exists only in a build with the SD card.
   function Needs_SD_Card (S : Setting) return Boolean is
     (S in Sdcard_Detect_Inverted .. Sdcard_Spi_Bus);

   --  Whether a setting exists only in a build with the flight log.
   function Needs_Blackbox (S : Setting) return Boolean is
     (S in Blackbox_Sample_Rate .. Blackbox_Baud | Sdcard_Detect_Inverted .. Sdcard_Spi_Bus | Osd_Log_Status_Pos
        | Usb_Msc_Pin_Pullup .. Flash_Spi_Bus);

   --  Whether a setting exists only in a build with the flash chip.
   function Needs_Flash_Chip (S : Setting) return Boolean is
     (S in Flash_Spi_Bus);

   --  Whether a setting exists only in a build with the compass.
   function Needs_Compass (S : Setting) return Boolean is
     (S in Align_Mag .. Mag_Calibration | Blackbox_Disable_Mag | Mag_Declination);

   --  Whether a setting exists only in a build with the barometer.
   function Needs_Barometer (S : Setting) return Boolean is
     (S in Baro_Bustype .. Baro_Drift);

   --  Whether a setting exists only in a build with the rangefinders.
   function Needs_Rangefinder (S : Setting) return Boolean is
     (S in Osd_Lidar_Dist_Pos | Rangefinder_Hardware .. Opticalflow_Flip_X);

   function In_Build
     (S : Setting; Wing : Boolean; Gyros : Positive;
      Flight_Plan : Boolean := Adaflight.Plan_Build.Enabled;
      Servos : Boolean := Adaflight.Servo_Build.Enabled;
      LED_Strip : Boolean := Adaflight.LED_Build.Enabled;
      GPS : Boolean := Adaflight.GPS_Build.Enabled;
      SD_Card : Boolean := Adaflight.SD_Build.Enabled;
      Blackbox : Boolean := Adaflight.Blackbox_Build.Enabled;
      Flash_Chip : Boolean := Adaflight.Flash_Build.Enabled;
      Compass : Boolean := Adaflight.Compass_Build.Enabled;
      Barometer : Boolean := Adaflight.Baro_Build.Enabled;
      Rangefinder : Boolean := Adaflight.Rangefinder_Build.Enabled) return Boolean is
     ((if Wing then Infos (S).In_Wing else Infos (S).In_Multirotor)
      and then (Flight_Plan or else not Needs_Flight_Plan (S))
      and then (Gyros > 1 or else not Needs_Second_Gyro (S))
      and then (Servos or else not Needs_Servos (S))
      and then (LED_Strip or else not Needs_LED_Strip (S))
      and then (GPS or else not Needs_GPS (S))
      and then (SD_Card or else not Needs_SD_Card (S))
      and then (Blackbox or else not Needs_Blackbox (S))
      and then (Flash_Chip or else not Needs_Flash_Chip (S))
      and then (Compass or else not Needs_Compass (S))
      and then (Barometer or else not Needs_Barometer (S))
      and then (Rangefinder or else not Needs_Rangefinder (S)));

   function Table_In_Build
     (T : Lookup_Table; Wing : Boolean;
      Servos : Boolean := Adaflight.Servo_Build.Enabled;
      LED_Strip : Boolean := Adaflight.LED_Build.Enabled;
      GPS : Boolean := Adaflight.GPS_Build.Enabled;
      SD_Card : Boolean := Adaflight.SD_Build.Enabled;
      Blackbox : Boolean := Adaflight.Blackbox_Build.Enabled;
      Compass : Boolean := Adaflight.Compass_Build.Enabled;
      Barometer : Boolean := Adaflight.Baro_Build.Enabled;
      Rangefinder : Boolean := Adaflight.Rangefinder_Build.Enabled) return Boolean is
     (case T is
         when Table_Ap_Yaw_Mode | Table_Ap_Rx_Loss_Policy | Table_Ap_Geofence_Action
           | Table_Launch_Control_Mode => not Wing,
         when Table_Tpa_Curve_Type | Table_Tpa_Speed_Type | Table_Yaw_Type => Wing,
         when Table_Gimbal_Mode => Servos,
         when Table_Rgb_Grb | Table_Led_Profile | Table_Ledstrip_Color => LED_Strip,
         when Table_Gps_Provider | Table_Gps_Sbas_Mode | Table_Gps_Ublox_Models
           | Table_Gps_Ublox_Utc_Standard | Table_Gps_Rescue_Sanity_Check
           | Table_Gps_Rescue_Alt_Mode | Table_Poshold_Source => GPS,
         when Table_Sdcard_Mode => SD_Card and then Blackbox,
         when Table_Blackbox_Device | Table_Blackbox_Mode | Table_Blackbox_Sample_Rate => Blackbox,
         when Table_Mag_Hardware => Compass,
         when Table_Baro_Hardware => Barometer,
         when Table_Rangefinder_Hardware | Table_Opticalflow_Hardware => Rangefinder,
         when others => True);

   function Describe
     (S : Setting; Wing : Boolean := False;
      LED_Strip : Boolean := Adaflight.LED_Build.Enabled;
      GPS : Boolean := Adaflight.GPS_Build.Enabled;
      Compass : Boolean := Adaflight.Compass_Build.Enabled;
      Barometer : Boolean := Adaflight.Baro_Build.Enabled;
      Rangefinder : Boolean := Adaflight.Rangefinder_Build.Enabled) return Info is
     (Kind => Infos (S).Kind, Where => Infos (S).Where, How => Infos (S).How,
      Min => Limit_Pairs (Limits_Of (S, Wing, LED_Strip, GPS, Compass, Barometer, Rangefinder)).Min,
      Max => Limit_Pairs (Limits_Of (S, Wing, LED_Strip, GPS, Compass, Barometer, Rangefinder)).Max,
      Table => Infos (S).Table, Count => Infos (S).Count, Min_Length => Infos (S).Min_Length,
      Write_Once => Infos (S).Write_Once, Group => Group_Numbers (Infos (S).Group));

   --  The setting names in codes: a code below 128 is a character, a higher one the token of its
   --  pair merge. Each name starts at its start and decodes to its length, and the codes and the
   --  tokens end with room for a longest name and token, so every read stays within them by the
   --  types alone.
   Name_Codes_Length : constant := 8143;
   subtype Name_Code_Index is Natural range 0 .. Name_Codes_Length + Max_Name_Length - 1;

   --  The code at an index, outside the proof: the decoder needs no fact about the codes.
   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8;

   function Name_Code (I : Name_Code_Index) return Interfaces.Unsigned_8 with SPARK_Mode => Off is
      Codes : constant array (Name_Code_Index) of Interfaces.Unsigned_8 :=
        (194, 161, 144, 100, 119, 144, 130, 108, 235, 194, 157, 235, 49, 153, 121, 172, 194, 157, 235, 49, 143,
         116, 137, 209, 236, 194, 157, 235, 50, 153, 121, 172, 194, 157, 235, 50, 143, 116, 137, 209, 236, 194,
         228, 162, 147, 49, 236, 194, 228, 162, 147, 49, 150, 210, 221, 194, 228, 162, 147, 50, 236, 194, 228,
         162, 147, 50, 150, 210, 221, 194, 150, 139, 105, 98, 138, 222, 137, 199, 194, 150, 139, 105, 98, 228,
         111, 149, 130, 108, 201, 194, 95, 221, 115, 158, 95, 182, 194, 95, 111, 218, 102, 206, 119, 138, 158,
         101, 99, 116, 182, 143, 112, 132, 95, 141, 99, 111, 218, 121, 182, 143, 112, 132, 153, 104, 190, 104,
         164, 100, 194, 95, 170, 169, 231, 98, 136, 167, 115, 107, 194, 95, 49, 95, 170, 169, 142, 100, 194, 95,
         50, 95, 170, 169, 142, 100, 100, 121, 110, 228, 162, 147, 150, 111, 189, 116, 100, 121, 110, 228, 162,
         147, 95, 113, 100, 121, 110, 228, 162, 147, 148, 132, 236, 100, 121, 110, 228, 162, 147, 232, 120, 236,
         194, 157, 235, 49, 138, 121, 110, 148, 132, 236, 194, 157, 235, 49, 138, 121, 110, 232, 120, 236, 194,
         157, 235, 49, 138, 121, 110, 95, 252, 112, 111, 194, 95, 171, 108, 187, 183, 98, 117, 103, 95, 97, 120,
         149, 195, 99, 161, 144, 100, 119, 97, 141, 195, 99, 157, 235, 236, 195, 99, 153, 114, 145, 133, 191,
         195, 99, 153, 114, 145, 95, 237, 195, 99, 150, 139, 105, 98, 114, 137, 199, 139, 105, 103, 110, 232,
         103, 167, 103, 243, 105, 103, 110, 95, 237, 167, 103, 243, 105, 103, 110, 133, 191, 167, 103, 243, 105,
         103, 110, 95, 182, 167, 103, 168, 117, 159, 121, 172, 167, 103, 95, 105, 50, 99, 183, 118, 209, 101,
         167, 103, 95, 105, 50, 99, 95, 175, 100, 190, 115, 167, 103, 233, 183, 118, 209, 101, 167, 103, 161,
         144, 100, 119, 97, 141, 167, 103, 150, 139, 105, 98, 114, 137, 199, 98, 97, 134, 168, 117, 159, 121,
         172, 98, 97, 134, 233, 183, 118, 209, 101, 98, 97, 134, 95, 105, 50, 99, 183, 118, 209, 101, 98, 97,
         134, 95, 105, 50, 99, 95, 175, 100, 190, 115, 98, 97, 134, 161, 144, 100, 119, 97, 141, 98, 97, 134,
         138, 114, 105, 102, 116, 112, 136, 162, 168, 117, 159, 121, 172, 112, 136, 162, 95, 105, 50, 99, 183,
         118, 209, 101, 112, 136, 162, 95, 105, 50, 99, 95, 175, 100, 190, 115, 112, 136, 162, 161, 144, 100,
         119, 97, 141, 109, 105, 128, 114, 99, 109, 132, 95, 147, 101, 176, 167, 181, 147, 101, 176, 200, 115,
         105, 95, 147, 155, 110, 101, 108, 200, 115, 105, 143, 114, 99, 229, 180, 109, 130, 131, 134, 200, 200,
         115, 105, 143, 99, 139, 101, 200, 115, 105, 95, 221, 115, 158, 200, 115, 105, 95, 132, 218, 116, 200,
         115, 105, 143, 114, 99, 229, 180, 109, 130, 108, 235, 133, 131, 105, 111, 100, 200, 115, 105, 143, 109,
         111, 162, 104, 185, 114, 99, 143, 109, 111, 162, 104, 185, 114, 99, 143, 109, 111, 162, 104, 185, 95,
         97, 210, 111, 229, 195, 116, 154, 114, 99, 143, 109, 111, 162, 104, 185, 95, 97, 210, 111, 229, 195,
         116, 154, 153, 104, 238, 142, 114, 99, 143, 109, 111, 162, 104, 185, 143, 158, 112, 111, 132, 116, 150,
         210, 221, 114, 99, 143, 109, 111, 162, 104, 185, 153, 104, 238, 156, 99, 210, 221, 114, 99, 143, 109,
         111, 162, 104, 185, 183, 98, 117, 103, 95, 97, 120, 149, 102, 112, 118, 148, 105, 120, 183, 103, 141,
         101, 115, 167, 181, 97, 117, 181, 147, 155, 110, 101, 108, 115, 115, 131, 105, 139, 114, 120, 133, 134,
         118, 219, 131, 115, 131, 105, 139, 114, 181, 132, 218, 179, 100, 115, 172, 107, 116, 114, 117, 109,
         143, 137, 168, 132, 100, 115, 172, 107, 116, 114, 117, 109, 143, 137, 168, 132, 128, 97, 210, 111, 190,
         158, 115, 114, 120, 108, 50, 95, 189, 136, 95, 219, 115, 114, 120, 108, 50, 168, 97, 117, 128, 102, 97,
         159, 115, 98, 188, 168, 97, 117, 128, 102, 97, 159, 99, 200, 102, 95, 188, 130, 110, 101, 103, 162,
         105, 137, 197, 98, 97, 223, 97, 105, 114, 109, 111, 100, 130, 159, 247, 153, 104, 238, 156, 112, 131,
         99, 170, 116, 114, 120, 148, 132, 95, 188, 101, 99, 114, 120, 232, 181, 188, 101, 99, 115, 131, 105,
         139, 114, 120, 161, 139, 102, 100, 117, 112, 142, 120, 114, 181, 117, 247, 109, 115, 140, 111, 218,
         114, 219, 130, 147, 155, 110, 101, 108, 115, 232, 115, 107, 109, 115, 140, 111, 218, 114, 219, 130,
         102, 97, 105, 108, 115, 97, 102, 101, 114, 120, 233, 133, 196, 111, 99, 164, 114, 120, 233, 168, 188,
         114, 120, 233, 95, 231, 132, 218, 115, 199, 175, 99, 183, 118, 209, 101, 175, 99, 253, 141, 102, 132,
         116, 150, 139, 105, 98, 114, 137, 199, 175, 99, 153, 101, 109, 173, 170, 115, 154, 150, 139, 105, 98,
         114, 137, 199, 51, 48, 175, 99, 153, 101, 109, 173, 170, 115, 154, 150, 139, 105, 98, 114, 137, 199,
         49, 49, 48, 132, 112, 210, 95, 171, 108, 187, 185, 148, 234, 244, 143, 202, 112, 156, 114, 211, 244,
         183, 118, 209, 101, 244, 186, 156, 177, 100, 115, 244, 186, 156, 114, 99, 244, 186, 156, 115, 158, 112,
         111, 132, 116, 244, 186, 156, 203, 244, 186, 156, 167, 103, 244, 186, 156, 139, 116, 244, 186, 156,
         200, 115, 105, 244, 186, 156, 194, 244, 186, 156, 194, 189, 171, 108, 116, 244, 186, 156, 195, 99, 244,
         186, 156, 137, 116, 136, 117, 165, 244, 186, 156, 165, 98, 117, 103, 244, 186, 156, 109, 162, 154, 115,
         244, 186, 156, 115, 131, 118, 129, 244, 186, 156, 114, 112, 109, 244, 186, 156, 178, 244, 186, 156,
         112, 136, 162, 244, 148, 234, 244, 161, 105, 103, 104, 95, 190, 164, 210, 199, 241, 181, 117, 247, 244,
         168, 97, 223, 167, 120, 153, 104, 238, 142, 109, 132, 150, 111, 109, 109, 155, 100, 109, 162, 154, 95,
         107, 118, 109, 162, 154, 95, 219, 142, 100, 242, 162, 168, 222, 159, 100, 242, 162, 168, 219, 105, 114,
         100, 242, 162, 95, 224, 116, 100, 242, 162, 168, 136, 98, 225, 100, 242, 162, 168, 136, 98, 225, 153,
         145, 131, 188, 130, 189, 115, 121, 110, 99, 197, 112, 119, 109, 109, 162, 154, 133, 119, 109, 133, 196,
         111, 99, 164, 109, 162, 154, 133, 119, 109, 254, 109, 162, 154, 133, 119, 109, 95, 132, 218, 115, 199,
         109, 162, 154, 133, 111, 142, 115, 109, 162, 154, 95, 111, 210, 112, 210, 95, 141, 154, 100, 131, 185,
         204, 114, 150, 154, 114, 253, 139, 117, 101, 204, 114, 150, 154, 114, 95, 225, 142, 102, 97, 105, 108,
         115, 97, 102, 130, 165, 226, 102, 97, 105, 108, 115, 97, 102, 130, 146, 110, 100, 185, 153, 145, 101,
         102, 97, 105, 108, 115, 97, 102, 130, 204, 238, 142, 102, 97, 105, 108, 115, 97, 102, 130, 115, 119,
         191, 148, 234, 102, 97, 105, 108, 115, 97, 102, 130, 204, 238, 156, 206, 119, 183, 226, 102, 97, 105,
         108, 115, 97, 102, 130, 112, 134, 99, 224, 117, 141, 102, 97, 105, 108, 115, 97, 102, 130, 141, 99,
         111, 218, 121, 183, 226, 102, 97, 105, 108, 115, 97, 102, 130, 159, 105, 176, 153, 104, 190, 104, 164,
         100, 139, 105, 103, 110, 168, 111, 144, 128, 237, 139, 105, 103, 110, 168, 111, 144, 128, 112, 191,
         139, 105, 103, 110, 168, 111, 144, 128, 182, 103, 245, 139, 148, 234, 203, 187, 121, 133, 134, 171,
         156, 110, 202, 101, 203, 150, 97, 112, 195, 136, 121, 118, 203, 232, 120, 150, 101, 184, 253, 164, 116,
         97, 103, 101, 118, 203, 229, 117, 184, 150, 101, 184, 253, 164, 116, 97, 103, 101, 118, 203, 148, 132,
         150, 101, 184, 253, 164, 116, 97, 103, 101, 118, 203, 95, 119, 144, 110, 185, 150, 101, 184, 253, 164,
         116, 97, 103, 101, 99, 203, 243, 131, 116, 133, 131, 99, 170, 116, 102, 154, 99, 130, 203, 187, 121,
         150, 101, 184, 150, 111, 189, 116, 118, 203, 161, 121, 159, 131, 101, 115, 149, 99, 222, 141, 110, 116,
         148, 158, 131, 203, 187, 121, 148, 158, 131, 118, 203, 138, 158, 101, 99, 116, 150, 101, 184, 253, 164,
         116, 97, 103, 101, 188, 130, 118, 203, 243, 131, 116, 115, 188, 130, 99, 203, 243, 131, 116, 115, 118,
         203, 150, 210, 221, 133, 131, 99, 170, 116, 118, 203, 166, 112, 226, 157, 235, 133, 131, 105, 111, 100,
         118, 203, 143, 97, 103, 157, 235, 133, 131, 105, 111, 100, 105, 203, 157, 235, 133, 131, 105, 111, 100,
         118, 203, 138, 222, 137, 199, 229, 154, 95, 119, 144, 110, 185, 118, 203, 138, 222, 137, 199, 229, 154,
         150, 114, 136, 209, 139, 118, 203, 143, 99, 139, 101, 118, 203, 138, 105, 118, 219, 131, 118, 203, 148,
         117, 108, 116, 105, 112, 227, 131, 105, 203, 97, 143, 99, 139, 101, 105, 203, 97, 95, 221, 115, 158,
         105, 203, 118, 143, 99, 139, 101, 105, 203, 118, 95, 221, 115, 158, 203, 187, 121, 150, 151, 116, 132,
         117, 101, 98, 101, 101, 112, 131, 95, 132, 218, 115, 199, 98, 101, 101, 112, 131, 95, 111, 100, 98,
         101, 101, 112, 131, 229, 141, 113, 117, 170, 99, 121, 98, 101, 101, 112, 131, 138, 242, 162, 168, 101,
         195, 151, 153, 151, 101, 182, 148, 162, 154, 115, 95, 141, 218, 115, 224, 109, 105, 120, 131, 153, 121,
         172, 99, 180, 242, 102, 227, 140, 109, 162, 154, 133, 131, 99, 170, 116, 99, 180, 242, 102, 227, 140,
         114, 211, 99, 180, 242, 102, 227, 140, 97, 210, 111, 95, 141, 207, 114, 112, 109, 157, 201, 114, 112,
         109, 157, 201, 133, 114, 112, 109, 157, 201, 95, 105, 114, 112, 109, 157, 201, 138, 114, 112, 109, 157,
         201, 253, 139, 117, 101, 51, 128, 165, 175, 98, 155, 128, 206, 119, 51, 128, 165, 175, 98, 155, 128,
         104, 105, 103, 104, 51, 128, 110, 101, 210, 114, 139, 51, 128, 165, 175, 98, 155, 128, 204, 238, 142,
         51, 128, 108, 201, 157, 111, 119, 51, 128, 108, 201, 161, 105, 103, 104, 51, 128, 115, 119, 191, 197,
         109, 234, 115, 131, 118, 111, 150, 170, 187, 133, 117, 108, 115, 101, 115, 131, 118, 111, 133, 119,
         109, 254, 115, 131, 118, 111, 157, 111, 119, 205, 115, 115, 236, 116, 114, 105, 95, 189, 207, 197, 115,
         131, 118, 111, 147, 155, 110, 101, 108, 229, 154, 119, 144, 100, 185, 143, 116, 247, 114, 211, 112,
         134, 171, 156, 110, 202, 101, 204, 114, 148, 219, 204, 114, 95, 252, 112, 111, 204, 114, 161, 111, 218,
         114, 211, 115, 153, 121, 172, 113, 117, 105, 176, 114, 211, 115, 163, 99, 95, 252, 112, 111, 237, 163,
         99, 254, 112, 191, 163, 99, 254, 182, 163, 99, 254, 237, 95, 252, 112, 111, 112, 191, 95, 252, 112,
         111, 182, 95, 252, 112, 111, 237, 143, 114, 211, 112, 191, 143, 114, 211, 182, 143, 114, 211, 204, 238,
         156, 108, 201, 153, 121, 172, 204, 238, 156, 108, 201, 133, 131, 99, 170, 116, 237, 163, 137, 130, 108,
         201, 112, 191, 163, 137, 130, 108, 201, 182, 163, 137, 130, 108, 201, 141, 192, 162, 95, 147, 144, 195,
         187, 115, 131, 105, 139, 95, 117, 112, 100, 137, 130, 114, 137, 130, 104, 122, 145, 117, 138, 99, 109,
         95, 107, 112, 145, 117, 138, 99, 109, 95, 107, 105, 115, 109, 139, 108, 95, 225, 142, 145, 117, 133,
         134, 99, 101, 115, 115, 138, 170, 111, 109, 167, 103, 183, 99, 108, 132, 137, 199, 97, 210, 111, 166,
         207, 183, 226, 194, 150, 139, 95, 151, 95, 171, 114, 159, 95, 207, 112, 141, 207, 243, 206, 119, 95,
         141, 207, 178, 133, 134, 118, 219, 131, 178, 143, 98, 97, 115, 148, 234, 208, 97, 210, 111, 150, 151,
         171, 103, 208, 97, 210, 111, 168, 97, 223, 208, 117, 98, 206, 181, 195, 113, 117, 105, 114, 130, 109,
         234, 108, 208, 117, 98, 206, 181, 102, 227, 103, 104, 116, 148, 234, 108, 208, 117, 112, 100, 137, 130,
         114, 137, 130, 104, 122, 208, 117, 98, 206, 181, 210, 99, 143, 116, 155, 100, 144, 100, 208, 117, 98,
         206, 181, 188, 130, 103, 139, 105, 142, 111, 208, 117, 98, 206, 181, 170, 169, 156, 155, 97, 178, 143,
         158, 161, 111, 109, 130, 112, 111, 132, 116, 95, 151, 99, 101, 208, 188, 130, 51, 128, 115, 172, 224,
         178, 143, 98, 97, 115, 95, 132, 179, 103, 114, 136, 121, 208, 110, 109, 101, 97, 150, 117, 159, 111,
         109, 150, 111, 109, 109, 155, 100, 115, 208, 117, 247, 178, 168, 97, 223, 208, 190, 99, 117, 130, 109,
         132, 143, 116, 247, 166, 116, 208, 190, 99, 117, 130, 139, 116, 148, 234, 208, 190, 99, 117, 130, 132,
         136, 105, 139, 150, 108, 245, 208, 190, 99, 117, 130, 97, 115, 99, 170, 128, 114, 211, 208, 190, 99,
         117, 130, 141, 116, 222, 110, 243, 116, 208, 190, 99, 117, 130, 103, 134, 189, 128, 115, 172, 224, 208,
         190, 99, 117, 130, 165, 115, 99, 170, 116, 166, 116, 208, 190, 99, 117, 130, 165, 115, 99, 170, 128,
         114, 211, 208, 190, 99, 117, 130, 115, 155, 136, 121, 95, 147, 101, 176, 115, 208, 190, 99, 117, 130,
         109, 132, 143, 137, 115, 208, 190, 99, 117, 130, 139, 206, 119, 95, 207, 185, 95, 119, 136, 104, 111,
         210, 95, 171, 120, 208, 190, 99, 117, 130, 182, 133, 208, 146, 140, 116, 145, 131, 220, 137, 130, 108,
         137, 208, 146, 140, 116, 145, 131, 220, 137, 130, 108, 151, 208, 146, 140, 116, 145, 131, 148, 132, 95,
         146, 140, 116, 145, 130, 115, 208, 146, 140, 116, 145, 131, 220, 137, 130, 116, 164, 131, 155, 99, 130,
         109, 165, 175, 98, 155, 100, 182, 183, 175, 98, 155, 100, 182, 150, 151, 116, 134, 108, 95, 141, 218,
         115, 224, 139, 116, 161, 164, 128, 99, 108, 245, 254, 139, 116, 161, 164, 128, 165, 175, 98, 155, 100,
         198, 161, 164, 128, 165, 175, 98, 155, 100, 198, 104, 164, 128, 198, 136, 199, 143, 111, 222, 99, 101,
         198, 104, 164, 128, 111, 112, 116, 209, 139, 102, 206, 119, 95, 113, 117, 139, 136, 121, 148, 132, 198,
         104, 164, 128, 111, 112, 116, 209, 139, 102, 206, 119, 232, 120, 163, 225, 101, 249, 150, 108, 245, 95,
         225, 142, 249, 232, 181, 225, 142, 249, 138, 158, 101, 99, 116, 95, 195, 99, 101, 108, 249, 138, 158,
         101, 99, 116, 253, 101, 206, 99, 136, 121, 249, 138, 158, 101, 99, 116, 153, 145, 101, 249, 95, 219,
         156, 204, 238, 142, 249, 95, 219, 156, 165, 226, 249, 153, 104, 238, 142, 249, 148, 162, 154, 183, 226,
         249, 143, 112, 132, 117, 140, 116, 145, 101, 249, 148, 132, 153, 145, 101, 249, 153, 145, 101, 111,
         210, 249, 232, 181, 139, 116, 136, 117, 165, 249, 95, 170, 128, 116, 145, 101, 249, 95, 169, 154, 116,
         183, 175, 98, 155, 100, 249, 95, 169, 154, 116, 95, 225, 142, 177, 128, 112, 134, 99, 101, 115, 115,
         138, 170, 111, 109, 114, 189, 174, 97, 121, 153, 97, 107, 101, 221, 133, 141, 118, 170, 116, 199, 114,
         189, 174, 97, 121, 153, 97, 107, 101, 221, 183, 195, 116, 105, 118, 137, 130, 165, 226, 114, 189, 174,
         97, 121, 153, 97, 107, 101, 221, 183, 195, 116, 105, 118, 137, 130, 204, 238, 156, 112, 131, 99, 170,
         116, 112, 134, 171, 156, 110, 202, 101, 100, 187, 109, 157, 235, 49, 138, 121, 110, 148, 132, 236, 100,
         187, 109, 157, 235, 49, 138, 121, 110, 232, 120, 236, 100, 187, 109, 157, 235, 49, 138, 121, 110, 95,
         252, 112, 111, 100, 187, 109, 157, 235, 49, 153, 121, 172, 100, 187, 109, 157, 235, 49, 143, 116, 137,
         209, 236, 100, 187, 109, 157, 235, 50, 153, 121, 172, 100, 187, 109, 157, 235, 50, 143, 116, 137, 209,
         236, 100, 187, 109, 228, 162, 147, 236, 100, 187, 109, 228, 162, 147, 150, 210, 221, 118, 203, 143, 97,
         103, 150, 111, 109, 112, 170, 115, 137, 199, 177, 128, 137, 148, 132, 153, 104, 238, 142, 155, 116,
         105, 220, 180, 118, 136, 121, 220, 230, 155, 116, 105, 220, 180, 118, 136, 121, 150, 210, 221, 236,
         155, 116, 105, 220, 180, 118, 136, 121, 133, 220, 230, 195, 99, 157, 201, 95, 182, 195, 99, 157, 201,
         99, 180, 242, 138, 204, 190, 104, 164, 100, 99, 180, 242, 220, 204, 190, 104, 164, 100, 99, 180, 242,
         143, 158, 112, 111, 132, 116, 153, 104, 190, 104, 164, 100, 99, 180, 242, 153, 145, 101, 99, 180, 242,
         183, 226, 99, 180, 242, 95, 141, 99, 111, 218, 121, 95, 225, 142, 99, 180, 242, 95, 141, 99, 111, 218,
         121, 254, 99, 180, 242, 157, 201, 95, 182, 99, 180, 242, 95, 141, 99, 111, 218, 121, 136, 131, 109, 95,
         196, 137, 199, 136, 131, 109, 95, 141, 146, 120, 136, 131, 109, 95, 141, 146, 120, 153, 121, 172, 136,
         131, 109, 95, 141, 146, 120, 150, 210, 221, 136, 131, 109, 95, 119, 132, 100, 117, 112, 177, 100, 115,
         117, 109, 157, 201, 177, 100, 115, 117, 109, 157, 201, 95, 182, 182, 157, 111, 119, 205, 115, 115, 236,
         204, 238, 156, 192, 129, 116, 204, 238, 156, 192, 129, 116, 150, 210, 221, 195, 134, 153, 180, 132,
         131, 95, 225, 156, 108, 201, 195, 134, 153, 180, 132, 131, 157, 111, 111, 107, 97, 104, 101, 97, 128,
         109, 115, 195, 134, 153, 180, 132, 131, 183, 98, 117, 103, 95, 97, 120, 149, 195, 134, 153, 180, 132,
         131, 220, 230, 112, 133, 191, 105, 133, 191, 128, 112, 191, 102, 133, 191, 140, 237, 105, 95, 237, 128,
         237, 102, 95, 237, 140, 182, 105, 95, 182, 128, 182, 102, 95, 182, 115, 133, 191, 115, 95, 237, 115,
         95, 182, 225, 156, 140, 103, 230, 225, 156, 102, 101, 224, 102, 154, 119, 144, 100, 225, 156, 102, 101,
         224, 102, 154, 119, 144, 128, 115, 109, 111, 162, 104, 185, 148, 115, 225, 156, 108, 201, 225, 156,
         101, 144, 204, 95, 141, 102, 104, 154, 105, 122, 151, 95, 142, 118, 101, 108, 143, 116, 141, 110, 103,
         204, 104, 154, 105, 122, 151, 157, 201, 143, 116, 105, 176, 115, 104, 154, 105, 122, 151, 157, 201,
         183, 103, 141, 101, 115, 104, 154, 105, 122, 151, 95, 105, 103, 110, 154, 130, 159, 105, 176, 115, 104,
         154, 105, 122, 151, 183, 226, 148, 115, 147, 105, 114, 140, 146, 103, 229, 141, 113, 236, 147, 105,
         114, 140, 142, 97, 128, 102, 141, 113, 236, 147, 105, 114, 140, 202, 112, 108, 136, 223, 130, 237, 147,
         105, 114, 140, 202, 112, 108, 136, 223, 130, 112, 191, 147, 105, 114, 140, 202, 112, 108, 136, 223,
         130, 182, 147, 105, 114, 140, 102, 141, 113, 117, 170, 99, 121, 143, 116, 247, 183, 99, 105, 236, 147,
         105, 114, 140, 102, 141, 113, 117, 170, 99, 121, 95, 170, 128, 165, 99, 105, 236, 147, 105, 114, 140,
         116, 145, 130, 115, 101, 99, 151, 100, 115, 147, 105, 114, 140, 141, 172, 137, 128, 167, 181, 237, 128,
         167, 120, 133, 191, 128, 167, 181, 182, 128, 167, 181, 103, 230, 128, 167, 181, 175, 118, 155, 99, 101,
         109, 162, 154, 95, 111, 210, 112, 210, 157, 201, 97, 210, 111, 133, 134, 171, 156, 99, 101, 184, 150,
         111, 189, 116, 249, 150, 151, 116, 134, 108, 148, 234, 249, 153, 114, 105, 103, 103, 131, 243, 206,
         119, 95, 190, 158, 249, 153, 114, 105, 103, 103, 131, 153, 104, 238, 156, 112, 131, 99, 170, 116, 249,
         95, 225, 156, 108, 201, 249, 150, 151, 116, 134, 108, 220, 230, 204, 114, 117, 159, 157, 132, 101, 144,
         102, 101, 224, 102, 154, 119, 144, 128, 116, 114, 155, 115, 136, 199, 102, 101, 224, 102, 154, 119,
         144, 128, 97, 218, 97, 103, 185, 102, 101, 224, 102, 154, 119, 144, 128, 115, 109, 111, 162, 104, 229,
         195, 116, 154, 102, 101, 224, 102, 154, 119, 144, 128, 106, 136, 187, 229, 195, 116, 154, 102, 101,
         224, 102, 154, 119, 144, 128, 192, 129, 116, 102, 101, 224, 102, 154, 119, 144, 128, 167, 120, 163,
         137, 130, 108, 201, 102, 101, 224, 102, 154, 119, 144, 128, 182, 161, 164, 128, 103, 230, 102, 101,
         224, 102, 154, 119, 144, 128, 182, 161, 164, 128, 116, 145, 101, 100, 121, 110, 95, 219, 156, 109, 132,
         163, 112, 109, 100, 121, 110, 95, 219, 156, 140, 103, 230, 100, 121, 110, 95, 219, 156, 105, 220, 230,
         100, 121, 110, 95, 219, 156, 128, 103, 230, 100, 121, 110, 95, 219, 156, 167, 181, 132, 99, 141, 97,
         115, 101, 142, 118, 101, 108, 163, 195, 130, 109, 234, 115, 145, 112, 227, 171, 197, 177, 100, 115,
         148, 234, 115, 145, 112, 227, 171, 197, 167, 159, 131, 148, 117, 108, 116, 105, 112, 227, 131, 115,
         145, 112, 227, 171, 197, 105, 220, 230, 115, 145, 112, 227, 171, 197, 128, 103, 230, 115, 145, 112,
         227, 171, 197, 177, 220, 230, 115, 145, 112, 227, 171, 197, 128, 167, 181, 103, 230, 115, 145, 112,
         227, 171, 197, 102, 101, 224, 102, 154, 119, 144, 128, 103, 230, 115, 145, 112, 227, 171, 197, 112,
         191, 95, 128, 103, 230, 115, 145, 112, 227, 171, 197, 112, 191, 133, 105, 220, 230, 115, 145, 112, 227,
         171, 197, 100, 187, 109, 95, 171, 108, 187, 115, 145, 112, 227, 171, 197, 100, 187, 109, 95, 171, 108,
         187, 148, 117, 108, 116, 105, 112, 227, 131, 115, 145, 112, 227, 171, 197, 194, 95, 171, 108, 187, 115,
         145, 112, 227, 171, 197, 194, 95, 171, 108, 187, 148, 117, 108, 116, 105, 112, 227, 131, 255, 148, 234,
         255, 254, 255, 168, 141, 97, 107, 112, 111, 132, 116, 255, 157, 111, 119, 254, 255, 157, 111, 119, 168,
         141, 97, 107, 112, 111, 132, 116, 255, 157, 111, 119, 243, 119, 97, 121, 115, 255, 143, 172, 197, 116,
         121, 172, 255, 143, 172, 197, 98, 97, 115, 209, 183, 226, 255, 143, 172, 197, 98, 97, 115, 209, 220,
         180, 118, 136, 121, 255, 143, 172, 197, 175, 118, 133, 134, 112, 133, 191, 255, 143, 172, 197, 175,
         118, 232, 115, 115, 255, 143, 172, 197, 175, 118, 138, 180, 103, 95, 107, 255, 143, 172, 197, 175, 118,
         153, 104, 114, 117, 159, 255, 143, 172, 197, 167, 181, 118, 164, 116, 97, 103, 101, 255, 143, 172, 197,
         112, 191, 95, 221, 115, 158, 255, 150, 222, 118, 130, 116, 121, 172, 255, 150, 222, 118, 130, 159, 139,
         108, 153, 104, 238, 142, 255, 150, 222, 118, 130, 177, 128, 204, 114, 48, 255, 150, 222, 118, 130, 177,
         128, 204, 114, 49, 48, 48, 255, 150, 222, 118, 130, 252, 112, 111, 101, 122, 95, 146, 110, 100, 185,
         153, 104, 190, 104, 164, 100, 101, 122, 95, 146, 110, 100, 185, 157, 201, 101, 122, 95, 146, 110, 100,
         185, 143, 172, 224, 146, 110, 100, 185, 166, 207, 153, 104, 190, 104, 164, 100, 115, 205, 95, 237, 150,
         170, 187, 115, 205, 95, 237, 95, 119, 219, 204, 115, 205, 95, 237, 148, 234, 115, 205, 133, 191, 150,
         170, 187, 115, 205, 133, 191, 95, 119, 219, 204, 115, 205, 133, 191, 148, 234, 115, 205, 95, 182, 150,
         170, 187, 115, 205, 95, 182, 95, 119, 219, 204, 115, 205, 95, 182, 148, 234, 182, 153, 121, 172, 225,
         156, 112, 191, 95, 221, 115, 158, 116, 108, 109, 95, 132, 218, 179, 100, 116, 108, 109, 161, 139, 102,
         100, 117, 112, 142, 120, 216, 95, 49, 133, 196, 111, 99, 164, 216, 95, 49, 95, 117, 247, 216, 95, 49,
         168, 97, 223, 216, 95, 50, 133, 196, 111, 99, 164, 216, 95, 50, 95, 117, 247, 216, 95, 50, 168, 97,
         223, 216, 95, 51, 133, 196, 111, 99, 164, 216, 95, 51, 95, 117, 247, 216, 95, 51, 168, 97, 223, 99,
         200, 102, 153, 108, 109, 95, 195, 99, 194, 102, 200, 107, 121, 183, 102, 97, 117, 108, 116, 157, 137,
         102, 200, 107, 121, 183, 102, 97, 117, 108, 116, 157, 151, 103, 102, 200, 107, 121, 95, 208, 102, 154,
         109, 137, 102, 200, 107, 121, 95, 189, 136, 102, 200, 107, 121, 253, 102, 97, 115, 133, 141, 99, 149,
         199, 104, 162, 116, 243, 207, 95, 132, 116, 177, 128, 132, 153, 108, 109, 141, 112, 154, 116, 150, 101,
         184, 253, 164, 116, 97, 103, 101, 105, 98, 188, 143, 170, 115, 154, 167, 118, 108, 132, 107, 232, 104,
         95, 97, 115, 161, 101, 175, 185, 138, 105, 118, 149, 154, 167, 118, 108, 132, 107, 148, 132, 153, 120,
         98, 117, 102, 102, 167, 118, 108, 132, 107, 95, 252, 116, 143, 116, 137, 188, 254, 167, 118, 108, 132,
         107, 163, 99, 95, 147, 155, 254, 167, 118, 108, 132, 107, 152, 254, 167, 118, 108, 132, 107, 95, 252,
         116, 180, 49, 254, 167, 118, 108, 132, 107, 95, 252, 116, 180, 50, 254, 167, 118, 108, 132, 107, 95,
         252, 116, 180, 51, 254, 251, 118, 164, 116, 97, 103, 101, 251, 99, 222, 141, 110, 116, 251, 102, 117,
         101, 108, 251, 109, 234, 251, 195, 99, 95, 120, 251, 195, 99, 95, 121, 251, 195, 99, 95, 122, 251, 112,
         191, 251, 237, 251, 104, 101, 175, 185, 251, 139, 116, 136, 117, 165, 251, 118, 144, 105, 111, 251,
         108, 137, 157, 151, 103, 251, 103, 134, 189, 128, 115, 172, 224, 251, 100, 149, 116, 155, 99, 101, 251,
         101, 115, 99, 150, 222, 141, 110, 116, 251, 101, 115, 99, 253, 164, 116, 97, 103, 101, 251, 101, 115,
         99, 163, 112, 109, 251, 101, 115, 99, 153, 101, 109, 112, 131, 137, 117, 141, 251, 179, 109, 112, 131,
         137, 117, 141, 251, 99, 160, 188, 224, 142, 100, 159, 114, 105, 140, 118, 149, 117, 139, 168, 101, 101,
         112, 131, 142, 100, 159, 114, 105, 140, 118, 149, 117, 139, 168, 101, 101, 112, 131, 150, 164, 154,
         142, 100, 159, 114, 105, 140, 103, 114, 98, 163, 103, 98, 142, 100, 159, 114, 105, 112, 133, 134, 171,
         142, 142, 100, 159, 114, 105, 140, 180, 99, 130, 99, 164, 154, 142, 100, 159, 114, 105, 140, 98, 101,
         195, 151, 150, 164, 154, 142, 100, 159, 114, 105, 140, 98, 101, 195, 151, 133, 131, 105, 111, 128, 109,
         115, 142, 100, 159, 114, 105, 140, 98, 101, 195, 151, 133, 131, 99, 170, 116, 142, 100, 159, 114, 105,
         140, 98, 101, 195, 151, 95, 207, 197, 151, 108, 121, 142, 100, 159, 114, 105, 140, 98, 114, 105, 103,
         104, 116, 110, 101, 115, 115, 142, 100, 159, 114, 105, 140, 180, 132, 192, 119, 183, 108, 116, 97, 142,
         100, 159, 114, 105, 140, 180, 132, 192, 119, 229, 141, 113, 116, 114, 155, 115, 112, 151, 100, 131,
         133, 134, 118, 219, 131, 116, 114, 155, 115, 112, 151, 100, 131, 138, 137, 97, 115, 100, 99, 144, 128,
         100, 158, 101, 99, 116, 95, 132, 218, 179, 100, 115, 100, 99, 144, 128, 109, 234, 115, 100, 99, 144,
         128, 115, 177, 168, 188, 135, 189, 136, 115, 135, 119, 144, 110, 168, 136, 167, 115, 107, 135, 200,
         115, 105, 243, 207, 135, 108, 132, 107, 95, 113, 117, 139, 136, 121, 243, 207, 135, 200, 115, 105, 138,
         98, 109, 243, 207, 135, 200, 110, 114, 243, 207, 135, 99, 160, 139, 207, 135, 139, 116, 243, 207, 135,
         100, 149, 116, 155, 99, 130, 139, 207, 135, 101, 115, 99, 153, 101, 109, 140, 139, 207, 135, 101, 115,
         99, 163, 112, 109, 243, 207, 135, 101, 115, 99, 150, 222, 141, 110, 116, 243, 207, 135, 99, 154, 130,
         179, 109, 140, 139, 207, 135, 97, 104, 232, 120, 133, 136, 135, 97, 104, 232, 181, 134, 108, 135, 97,
         104, 95, 132, 218, 116, 135, 206, 103, 111, 95, 151, 95, 207, 185, 135, 206, 103, 111, 95, 151, 95,
         207, 185, 138, 222, 137, 199, 135, 207, 185, 157, 111, 103, 111, 135, 188, 130, 113, 117, 105, 176,
         148, 170, 117, 135, 242, 111, 119, 143, 172, 99, 133, 141, 207, 135, 116, 145, 49, 135, 116, 145, 50,
         135, 118, 203, 152, 135, 200, 115, 105, 152, 135, 108, 132, 107, 95, 113, 117, 139, 136, 121, 152, 135,
         108, 132, 107, 153, 120, 133, 111, 119, 131, 152, 135, 200, 115, 105, 138, 98, 109, 152, 135, 200, 110,
         114, 152, 135, 116, 145, 95, 49, 152, 135, 116, 145, 95, 50, 152, 135, 141, 167, 132, 185, 153, 145,
         130, 101, 159, 145, 137, 246, 135, 102, 108, 121, 109, 111, 100, 246, 135, 155, 116, 105, 220, 180,
         118, 136, 121, 152, 135, 103, 229, 154, 99, 246, 135, 204, 238, 156, 198, 135, 118, 116, 181, 147, 155,
         110, 101, 108, 152, 135, 99, 114, 129, 242, 97, 105, 200, 152, 135, 97, 104, 143, 98, 144, 152, 135,
         97, 104, 152, 135, 99, 222, 141, 110, 116, 152, 135, 167, 104, 138, 114, 174, 110, 152, 135, 119, 104,
         138, 114, 174, 110, 152, 135, 109, 162, 154, 138, 105, 97, 103, 152, 135, 99, 180, 102, 116, 228, 202,
         246, 135, 177, 108, 162, 228, 202, 246, 135, 178, 143, 172, 197, 198, 135, 178, 157, 151, 152, 135,
         178, 157, 137, 152, 135, 208, 146, 140, 99, 222, 114, 152, 135, 208, 146, 112, 133, 141, 118, 152, 135,
         208, 146, 140, 98, 101, 159, 51, 152, 135, 178, 143, 137, 115, 152, 135, 104, 111, 109, 130, 100, 105,
         114, 152, 135, 104, 111, 109, 130, 100, 149, 116, 152, 135, 102, 227, 103, 104, 116, 166, 116, 152,
         135, 99, 111, 109, 205, 115, 115, 168, 144, 152, 135, 139, 116, 136, 223, 246, 135, 177, 128, 237, 152,
         135, 177, 128, 112, 191, 152, 135, 177, 128, 182, 152, 135, 165, 98, 117, 103, 152, 135, 165, 98, 117,
         103, 50, 152, 135, 112, 111, 119, 131, 152, 135, 177, 100, 114, 137, 130, 112, 134, 171, 156, 198, 135,
         119, 144, 110, 185, 115, 152, 135, 97, 118, 103, 150, 101, 184, 253, 164, 116, 97, 103, 246, 135, 112,
         136, 95, 225, 152, 135, 134, 108, 95, 225, 152, 135, 203, 187, 121, 95, 188, 97, 103, 246, 135, 100,
         149, 207, 197, 198, 135, 110, 104, 101, 175, 185, 152, 135, 117, 112, 138, 111, 119, 110, 95, 141, 102,
         131, 170, 99, 246, 135, 141, 175, 121, 148, 111, 100, 246, 135, 198, 161, 164, 128, 141, 175, 121, 152,
         135, 110, 118, 144, 105, 111, 152, 135, 101, 115, 99, 153, 109, 112, 152, 135, 101, 115, 99, 163, 112,
         109, 152, 135, 101, 115, 99, 163, 112, 109, 229, 141, 113, 152, 135, 114, 116, 99, 138, 137, 130, 116,
         145, 246, 135, 175, 106, 117, 159, 109, 170, 116, 163, 225, 246, 135, 102, 227, 140, 144, 134, 119,
         152, 135, 99, 154, 130, 179, 109, 112, 152, 135, 206, 103, 143, 116, 137, 188, 152, 135, 159, 105, 176,
         95, 111, 218, 226, 95, 142, 102, 116, 152, 135, 159, 105, 176, 95, 111, 218, 226, 163, 105, 103, 104,
         116, 152, 135, 159, 105, 176, 95, 111, 218, 226, 163, 175, 105, 111, 148, 234, 135, 114, 137, 130, 112,
         134, 171, 156, 110, 202, 246, 135, 177, 128, 112, 134, 171, 156, 110, 202, 246, 135, 203, 187, 121,
         133, 134, 171, 156, 110, 202, 246, 135, 112, 134, 171, 156, 110, 202, 246, 135, 114, 99, 147, 155, 110,
         101, 108, 115, 152, 135, 99, 202, 131, 97, 229, 180, 109, 246, 135, 101, 102, 171, 99, 105, 170, 99,
         121, 152, 135, 116, 162, 139, 229, 227, 103, 104, 116, 115, 152, 135, 97, 117, 120, 152, 135, 115, 121,
         115, 220, 111, 103, 103, 156, 118, 164, 116, 97, 103, 246, 135, 115, 121, 115, 253, 116, 181, 118, 164,
         116, 97, 103, 246, 135, 115, 121, 115, 168, 136, 114, 137, 246, 135, 115, 121, 115, 183, 226, 152, 135,
         115, 121, 115, 166, 116, 155, 99, 246, 135, 115, 121, 115, 157, 113, 152, 135, 115, 121, 115, 220, 111,
         103, 103, 156, 100, 118, 114, 152, 135, 115, 121, 115, 253, 116, 120, 138, 118, 114, 152, 135, 115,
         121, 115, 95, 119, 144, 110, 185, 115, 152, 135, 115, 121, 115, 253, 116, 120, 153, 101, 109, 112, 152,
         135, 115, 121, 115, 229, 155, 143, 172, 197, 198, 135, 159, 137, 168, 136, 167, 115, 107, 135, 112,
         134, 171, 142, 135, 112, 134, 171, 156, 49, 228, 202, 101, 135, 112, 134, 171, 156, 50, 228, 202, 101,
         135, 112, 134, 171, 156, 51, 228, 202, 101, 135, 178, 143, 137, 115, 143, 104, 111, 119, 133, 100, 111,
         112, 135, 100, 149, 112, 226, 112, 154, 116, 183, 118, 209, 101, 135, 117, 247, 135, 114, 99, 147, 155,
         110, 101, 108, 115, 135, 99, 202, 131, 97, 229, 180, 109, 130, 119, 219, 204, 135, 99, 202, 131, 97,
         229, 180, 109, 130, 104, 101, 105, 103, 104, 116, 135, 159, 137, 95, 97, 118, 103, 150, 101, 184, 253,
         139, 117, 101, 135, 102, 180, 109, 131, 137, 130, 104, 122, 135, 109, 170, 117, 168, 97, 176, 103, 134,
         189, 100, 135, 97, 117, 181, 147, 155, 110, 101, 108, 135, 97, 117, 120, 143, 99, 139, 101, 135, 97,
         117, 120, 143, 121, 109, 98, 164, 135, 99, 180, 102, 116, 110, 202, 130, 109, 115, 103, 115, 135, 108,
         219, 144, 166, 116, 152, 135, 99, 117, 159, 111, 109, 143, 131, 105, 139, 153, 252, 116, 152, 135, 99,
         117, 159, 111, 109, 143, 131, 105, 139, 153, 252, 116, 153, 131, 109, 132, 137, 154, 135, 99, 117, 159,
         111, 109, 153, 252, 116, 95, 117, 247, 135, 99, 117, 159, 111, 109, 153, 252, 116, 168, 97, 223, 135,
         119, 140, 110, 117, 109, 98, 131, 152, 135, 119, 140, 99, 222, 141, 110, 116, 157, 137, 152, 135, 119,
         140, 99, 222, 141, 110, 116, 157, 151, 152, 135, 119, 140, 99, 222, 141, 110, 116, 243, 116, 152, 135,
         119, 112, 166, 116, 155, 99, 246, 135, 119, 112, 138, 105, 141, 99, 116, 199, 152, 135, 119, 140, 110,
         252, 116, 228, 117, 109, 98, 131, 152, 135, 119, 140, 158, 97, 152, 135, 110, 97, 118, 232, 112, 152,
         135, 110, 97, 118, 148, 160, 109, 234, 135, 110, 97, 118, 148, 160, 99, 170, 116, 141, 135, 110, 97,
         118, 148, 160, 109, 132, 143, 99, 139, 130, 109, 135, 97, 105, 200, 172, 224, 115, 121, 159, 101, 109,
         161, 115, 130, 109, 104, 122, 116, 97, 115, 107, 143, 116, 137, 149, 116, 209, 115, 165, 98, 117, 103,
         148, 234, 114, 137, 130, 54, 198, 143, 119, 191, 99, 112, 117, 95, 111, 218, 99, 206, 176, 112, 119,
         114, 95, 151, 95, 207, 220, 180, 99, 101, 170, 169, 156, 159, 105, 176, 95, 207, 185, 118, 116, 120,
         168, 155, 100, 118, 116, 181, 147, 155, 110, 101, 108, 118, 116, 120, 133, 111, 119, 131, 118, 116,
         120, 157, 111, 119, 133, 111, 119, 131, 166, 207, 118, 116, 120, 143, 217, 116, 115, 131, 105, 139,
         243, 116, 118, 116, 120, 153, 121, 172, 118, 116, 181, 117, 247, 118, 116, 181, 102, 141, 113, 118,
         116, 120, 133, 136, 148, 111, 100, 130, 102, 141, 113, 118, 116, 120, 161, 139, 102, 100, 117, 112,
         142, 120, 118, 116, 120, 233, 168, 188, 118, 99, 128, 118, 105, 165, 111, 143, 121, 159, 101, 109, 118,
         99, 128, 104, 95, 221, 115, 158, 118, 99, 128, 118, 95, 221, 115, 158, 167, 120, 55, 52, 53, 54, 150,
         206, 176, 167, 120, 55, 52, 53, 54, 233, 168, 188, 167, 120, 55, 52, 53, 54, 133, 141, 132, 136, 95,
         111, 112, 117, 100, 149, 112, 226, 112, 154, 116, 148, 115, 140, 99, 164, 95, 175, 106, 117, 159, 100,
         149, 112, 226, 112, 154, 116, 148, 115, 140, 134, 119, 95, 175, 106, 117, 159, 100, 149, 112, 226, 112,
         154, 116, 148, 115, 140, 102, 151, 116, 115, 100, 149, 112, 226, 112, 154, 116, 148, 115, 140, 188,
         130, 165, 118, 209, 130, 98, 108, 132, 107, 100, 149, 112, 226, 112, 154, 116, 232, 120, 55, 52, 53,
         54, 150, 164, 95, 175, 106, 117, 159, 100, 149, 112, 226, 112, 154, 116, 232, 120, 55, 52, 53, 54, 95,
         134, 119, 95, 175, 106, 117, 159, 100, 149, 112, 226, 112, 154, 116, 232, 120, 55, 52, 53, 54, 95, 132,
         118, 100, 149, 112, 226, 112, 154, 116, 232, 120, 55, 52, 53, 54, 168, 108, 107, 100, 149, 112, 226,
         112, 154, 116, 232, 120, 55, 52, 53, 54, 95, 119, 104, 116, 101, 115, 99, 143, 170, 115, 154, 161, 139,
         102, 100, 117, 112, 142, 120, 101, 115, 99, 143, 170, 115, 154, 150, 222, 141, 110, 116, 95, 221, 115,
         158, 101, 115, 99, 143, 170, 115, 154, 95, 117, 247, 102, 200, 107, 121, 233, 95, 97, 210, 111, 98,
         132, 100, 102, 200, 107, 121, 233, 153, 181, 219, 102, 200, 107, 121, 233, 95, 221, 115, 158, 102, 200,
         107, 121, 233, 168, 132, 128, 104, 111, 112, 138, 137, 97, 102, 200, 107, 121, 95, 120, 163, 181, 110,
         117, 109, 102, 200, 107, 121, 233, 95, 97, 49, 143, 111, 222, 99, 101, 99, 99, 50, 53, 48, 48, 233, 95,
         147, 105, 112, 138, 158, 101, 99, 116, 231, 132, 218, 115, 199, 100, 97, 242, 192, 144, 128, 105, 50,
         99, 168, 188, 100, 97, 242, 192, 144, 128, 105, 50, 99, 95, 175, 100, 114, 99, 202, 131, 97, 150, 151,
         116, 134, 108, 148, 234, 99, 202, 131, 97, 150, 151, 116, 134, 108, 95, 141, 102, 253, 164, 116, 97,
         103, 101, 99, 202, 131, 97, 150, 151, 116, 134, 108, 95, 107, 101, 121, 183, 226, 99, 202, 131, 97,
         150, 151, 116, 134, 108, 95, 132, 187, 110, 139, 95, 190, 149, 116, 155, 99, 101, 99, 202, 131, 97,
         150, 151, 116, 134, 108, 168, 210, 116, 151, 95, 190, 149, 116, 155, 99, 101, 99, 202, 131, 97, 150,
         151, 116, 134, 108, 95, 132, 218, 179, 100, 114, 225, 101, 102, 132, 100, 131, 161, 144, 100, 119, 97,
         141, 114, 225, 101, 102, 132, 100, 131, 95, 117, 247, 111, 112, 116, 209, 139, 102, 206, 119, 161, 144,
         100, 119, 97, 141, 111, 112, 116, 209, 139, 102, 206, 119, 95, 117, 247, 111, 112, 116, 209, 139, 102,
         206, 119, 95, 196, 137, 199, 111, 112, 116, 209, 139, 102, 206, 119, 229, 227, 140, 120, 112, 132, 105,
         111, 150, 151, 171, 103, 112, 132, 105, 111, 168, 111, 120, 188, 98, 161, 105, 128, 99, 100, 99, 188,
         98, 148, 115, 99, 133, 132, 133, 117, 184, 117, 112, 102, 146, 242, 233, 168, 188, 114, 99, 165, 118,
         209, 130, 132, 136, 183, 118, 95, 137, 179, 109, 112, 116, 115, 114, 99, 165, 118, 209, 130, 132, 136,
         183, 118, 95, 137, 179, 109, 112, 116, 95, 132, 187, 118, 139, 114, 99, 165, 118, 209, 130, 112, 196,
         111, 99, 164, 95, 218, 115, 199, 114, 99, 165, 118, 209, 130, 102, 101, 137, 117, 141, 114, 99, 165,
         118, 209, 130, 117, 247, 194, 95, 49, 168, 117, 159, 121, 172, 194, 95, 49, 233, 98, 188, 194, 95, 49,
         95, 105, 50, 99, 66, 188, 194, 95, 49, 95, 105, 50, 99, 95, 175, 100, 190, 115, 194, 95, 50, 168, 117,
         159, 121, 172, 194, 95, 50, 233, 98, 188, 194, 95, 50, 95, 105, 50, 99, 66, 188, 194, 95, 50, 95, 105,
         50, 99, 95, 175, 100, 190, 115, 105, 50, 99, 49, 133, 117, 184, 117, 112, 105, 50, 99, 49, 150, 206,
         176, 115, 172, 197, 107, 104, 122, 105, 50, 99, 50, 133, 117, 184, 117, 112, 105, 50, 99, 50, 150, 206,
         176, 115, 172, 197, 107, 104, 122, 105, 50, 99, 51, 133, 117, 184, 117, 112, 105, 50, 99, 51, 150, 206,
         176, 115, 172, 197, 107, 104, 122, 109, 99, 111, 50, 95, 151, 133, 99, 57, 115, 172, 107, 116, 114,
         117, 109, 233, 133, 196, 111, 99, 164, 115, 172, 107, 116, 114, 117, 109, 233, 148, 102, 103, 95, 219,
         115, 172, 107, 116, 114, 117, 109, 233, 228, 117, 109, 95, 147, 155, 110, 101, 108, 115, 252, 112, 190,
         115, 108, 200, 95, 117, 219, 252, 112, 190, 115, 108, 200, 138, 111, 167, 132, 252, 112, 190, 115, 108,
         200, 148, 234, 108, 95, 219, 115, 147, 224, 117, 108, 131, 95, 141, 146, 120, 163, 120, 115, 147, 224,
         117, 108, 131, 95, 141, 146, 181, 129, 100, 115, 147, 224, 117, 108, 131, 183, 98, 117, 103, 153, 97,
         115, 107, 99, 112, 117, 157, 137, 130, 108, 201, 133, 131, 109, 105, 108, 142, 115, 131, 105, 139, 109,
         115, 140, 104, 139, 102, 100, 117, 112, 142, 120, 109, 115, 140, 49, 95, 117, 247, 109, 115, 140, 49,
         168, 97, 223, 109, 115, 140, 50, 95, 117, 247, 109, 115, 140, 50, 168, 97, 223, 109, 115, 140, 51, 95,
         117, 247, 109, 115, 140, 51, 168, 97, 223, 116, 145, 101, 122, 151, 130, 221, 115, 158, 148, 132, 117,
         179, 115, 114, 112, 109, 95, 171, 108, 187, 161, 207, 151, 209, 115, 114, 112, 109, 95, 171, 108, 187,
         95, 119, 101, 105, 103, 104, 116, 115, 114, 112, 109, 95, 171, 108, 187, 95, 113, 114, 112, 109, 95,
         171, 108, 187, 148, 132, 236, 114, 112, 109, 95, 171, 108, 187, 229, 175, 130, 114, 225, 130, 104, 122,
         114, 112, 109, 95, 171, 108, 187, 157, 235, 236, 102, 108, 121, 115, 107, 121, 233, 153, 181, 219, 102,
         108, 121, 115, 107, 121, 233, 163, 102, 95, 147, 155, 110, 101, 108, 115, 159, 137, 115, 148, 132, 95,
         207, 197, 116, 145, 130, 115, 159, 137, 115, 153, 162, 139, 229, 227, 103, 104, 116, 115, 159, 137,
         115, 153, 162, 139, 153, 145, 130, 115, 159, 137, 115, 153, 162, 139, 166, 116, 148, 159, 137, 115,
         143, 97, 118, 130, 109, 111, 118, 130, 108, 201, 159, 137, 115, 232, 104, 95, 188, 224, 99, 180, 102,
         116, 228, 202, 101, 177, 108, 162, 228, 202, 101, 139, 116, 136, 223, 130, 115, 111, 222, 99, 101, 139,
         116, 136, 223, 130, 112, 141, 102, 131, 168, 97, 134, 139, 116, 136, 223, 130, 108, 235, 114, 225, 101,
         102, 132, 100, 131, 232, 120, 163, 225, 130, 99, 109, 139, 116, 136, 223, 130, 128, 108, 235, 160, 146,
         110, 100, 185, 243, 116, 136, 223, 130, 109, 160, 104, 111, 218, 153, 104, 238, 142, 160, 204, 238,
         156, 109, 132, 160, 204, 238, 156, 167, 120, 160, 139, 116, 136, 223, 130, 112, 160, 139, 116, 136,
         223, 130, 105, 160, 139, 116, 136, 223, 130, 100, 160, 139, 116, 136, 223, 130, 97, 160, 139, 116, 136,
         223, 130, 102, 97, 112, 152, 136, 199, 133, 97, 112, 152, 136, 199, 95, 105, 97, 112, 152, 136, 199,
         138, 97, 112, 152, 136, 199, 95, 97, 97, 112, 152, 136, 199, 229, 97, 112, 152, 136, 199, 150, 210,
         221, 160, 159, 111, 140, 204, 190, 104, 164, 100, 160, 167, 181, 225, 142, 160, 167, 181, 182, 254,
         160, 182, 133, 160, 118, 101, 206, 99, 136, 121, 138, 180, 103, 150, 111, 101, 102, 102, 160, 167, 181,
         118, 101, 206, 99, 136, 121, 160, 119, 97, 121, 112, 111, 132, 116, 95, 144, 114, 105, 118, 139, 163,
         175, 105, 188, 160, 119, 97, 121, 112, 111, 132, 116, 161, 164, 128, 114, 175, 105, 188, 160, 159, 105,
         176, 183, 175, 98, 155, 100, 160, 204, 238, 156, 165, 175, 98, 155, 100, 160, 182, 148, 234, 160, 109,
         132, 229, 154, 119, 144, 128, 118, 101, 206, 99, 136, 121, 160, 110, 97, 118, 150, 154, 110, 131, 143,
         172, 224, 160, 110, 97, 118, 150, 154, 110, 131, 183, 108, 116, 97, 253, 160, 110, 97, 118, 183, 99,
         101, 108, 160, 110, 97, 118, 95, 195, 99, 101, 108, 160, 110, 97, 118, 150, 144, 196, 95, 142, 97, 128,
         116, 145, 101, 160, 110, 97, 118, 150, 144, 196, 95, 142, 97, 128, 167, 120, 160, 110, 97, 118, 133,
         141, 116, 222, 110, 166, 116, 160, 118, 101, 206, 99, 136, 121, 168, 117, 105, 108, 100, 117, 140, 167,
         120, 133, 191, 160, 167, 120, 153, 222, 110, 254, 160, 104, 164, 128, 154, 98, 136, 163, 175, 105, 188,
         160, 104, 164, 128, 171, 103, 117, 141, 56, 95, 119, 219, 204, 160, 146, 110, 100, 185, 183, 115, 99,
         170, 116, 254, 160, 146, 110, 100, 185, 138, 158, 101, 99, 116, 199, 153, 145, 101, 160, 146, 110, 100,
         185, 233, 114, 139, 95, 170, 169, 142, 160, 146, 110, 100, 185, 233, 114, 139, 163, 175, 105, 188, 160,
         146, 110, 100, 185, 233, 114, 139, 254, 160, 146, 110, 100, 185, 253, 101, 206, 99, 136, 121, 153, 104,
         190, 104, 164, 100, 160, 146, 110, 100, 185, 153, 104, 238, 156, 204, 190, 104, 164, 100, 160, 108, 49,
         95, 170, 169, 142, 160, 108, 49, 133, 131, 105, 111, 100, 160, 108, 49, 148, 132, 157, 111, 111, 107,
         97, 104, 101, 175, 160, 108, 49, 232, 120, 157, 111, 111, 107, 97, 104, 101, 175, 160, 108, 49, 232,
         120, 150, 114, 129, 115, 153, 180, 176, 95, 131, 134, 114, 160, 108, 49, 153, 222, 110, 254, 160, 109,
         132, 228, 97, 118, 243, 116, 136, 223, 130, 109, 160, 114, 120, 157, 129, 115, 133, 164, 209, 121, 160,
         167, 120, 166, 116, 155, 99, 130, 102, 134, 109, 161, 111, 109, 101, 160, 103, 101, 217, 170, 99, 130,
         195, 116, 199, 192, 181, 188, 131, 95, 49, 228, 202, 101, 192, 181, 188, 131, 95, 50, 228, 202, 101,
         192, 181, 188, 131, 95, 51, 228, 202, 101, 192, 181, 188, 131, 95, 52, 228, 202, 101, 103, 245, 139,
         95, 237, 163, 99, 220, 230, 103, 245, 139, 133, 191, 163, 99, 153, 104, 114, 220, 230, 103, 245, 139,
         133, 191, 163, 99, 157, 111, 119, 220, 230, 103, 245, 139, 133, 191, 163, 99, 161, 105, 103, 104, 220,
         230, 103, 245, 139, 95, 182, 163, 99, 220, 230, 103, 245, 139, 95, 237, 220, 230, 103, 245, 139, 95,
         237, 95, 221, 115, 158, 103, 245, 139, 95, 237, 157, 201, 103, 245, 139, 133, 191, 220, 230, 103, 245,
         139, 133, 191, 95, 221, 115, 158, 103, 245, 139, 133, 191, 157, 111, 119, 157, 201, 103, 245, 139, 133,
         191, 161, 105, 103, 104, 157, 201, 103, 245, 139, 95, 182, 220, 230, 103, 245, 139, 95, 182, 95, 221,
         115, 158, 103, 245, 139, 95, 182, 157, 201, 103, 245, 139, 143, 116, 169, 105, 108, 149, 137, 199, 103,
         245, 139, 143, 170, 115, 136, 105, 118, 136, 121, 103, 245, 139, 95, 117, 247, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
   begin
      return Codes (I);
   end Name_Code;

   Token_Text_Length : constant := 371;
   Max_Token_Length  : constant := 19;
   Token_Text : constant String (1 .. Token_Text_Length + Max_Token_Length) :=
     "d_ose_erin_proosd_itat_dalp_rele_sarimlach_mis_con_pos_toran_letstap__hotolde_disma_babenfipepsawadckpigpst"
     & "ex_yaw_delling_disabterusunresitchbogygyroroted_ionrsimitambatthpaloarmgps_icutateteletelemtelemettelemetrt"
     & "elemetryofverid_goffurudanglay_n_fainled__ma_spiodepf_hzrollrottblablackblackbosh_alblackboximbe_posartlaun"
     & "launchtelemetry_disabtelemetry_disabled__v_ratetpa                   ";

   subtype Token_Code is Interfaces.Unsigned_8 range 128 .. 255;
   type Token_Start is range 0 .. Token_Text_Length;
   type Token_Length is range 2 .. Max_Token_Length;

   Token_Starts : constant array (Token_Code) of Token_Start :=
     (0, 2, 4, 6, 8, 10, 12, 14, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 54, 56, 58,
      30, 60, 62, 64, 66, 69, 71, 27, 73, 75, 77, 81, 83, 85, 87, 89, 91, 93, 95, 97, 99, 101, 103, 106, 57,
      108, 110, 113, 116, 118, 121, 127, 130, 132, 134, 137, 141, 143, 145, 39, 149, 152, 51, 155, 158, 160,
      164, 166, 169, 171, 173, 175, 178, 182, 184, 186, 189, 193, 198, 205, 213, 222, 224, 227, 229, 231, 234,
      236, 152, 238, 241, 117, 244, 246, 248, 251, 255, 258, 262, 265, 267, 270, 274, 278, 281, 286, 293, 295,
      298, 306, 309, 314, 317, 321, 327, 342, 107, 361, 363, 368);

   Token_Lengths : constant array (Token_Code) of Token_Length :=
     (2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 3, 2, 2, 2, 3, 2, 2,
      2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 3, 3, 2, 3, 6, 3, 2, 2, 3, 4, 2, 2, 4, 2, 3, 3,
      3, 3, 2, 4, 2, 3, 2, 2, 2, 3, 4, 2, 2, 3, 4, 5, 7, 8, 9, 2, 3, 2, 2, 3, 2, 2, 2, 3, 3, 2, 2, 2, 3, 4, 3,
      4, 3, 2, 3, 4, 4, 3, 5, 7, 2, 3, 8, 3, 5, 3, 4, 6, 15, 19, 2, 2, 5, 3);

   type Name_Start is range 0 .. Name_Codes_Length;
   type Name_Length is range 1 .. Max_Name_Length;

   Name_Starts : constant array (Setting) of Name_Start :=
     (0, 9, 16, 25, 32, 41, 47, 55, 61, 69, 78, 89, 96, 108, 118, 128, 138, 146, 154, 164, 172, 181, 190, 200,
      210, 221, 234, 242, 247, 254, 261, 270, 276, 284, 292, 300, 307, 317, 328, 335, 343, 352, 360, 368, 379,
      391, 400, 408, 416, 427, 439, 448, 453, 459, 464, 473, 486, 493, 500, 507, 524, 533, 541, 557, 577, 594,
      609, 625, 636, 647, 658, 668, 680, 697, 707, 719, 729, 745, 763, 771, 778, 792, 796, 813, 829, 837, 842,
      851, 857, 871, 889, 908, 918, 925, 930, 936, 941, 950, 954, 959, 964, 970, 974, 982, 987, 995, 1002, 1009,
      1016, 1022, 1026, 1032, 1035, 1045, 1049, 1053, 1059, 1067, 1073, 1079, 1085, 1092, 1098, 1105, 1115,
      1126, 1137, 1144, 1155, 1162, 1176, 1185, 1193, 1203, 1218, 1229, 1242, 1257, 1271, 1286, 1303, 1312,
      1322, 1331, 1336, 1346, 1353, 1366, 1380, 1393, 1409, 1419, 1433, 1442, 1450, 1456, 1472, 1480, 1488,
      1498, 1510, 1522, 1531, 1544, 1557, 1563, 1570, 1580, 1587, 1594, 1601, 1608, 1617, 1627, 1635, 1647,
      1662, 1672, 1679, 1693, 1701, 1713, 1718, 1724, 1731, 1737, 1746, 1755, 1766, 1773, 1783, 1790, 1798,
      1806, 1818, 1826, 1837, 1848, 1862, 1871, 1875, 1881, 1886, 1892, 1905, 1909, 1914, 1918, 1923, 1929,
      1934, 1938, 1943, 1947, 1955, 1965, 1971, 1978, 1984, 1992, 2007, 2015, 2023, 2030, 2042, 2050, 2057,
      2068, 2077, 2083, 2090, 2098, 2105, 2119, 2132, 2143, 2156, 2168, 2178, 2193, 2201, 2213, 2230, 2233,
      2237, 2249, 2258, 2270, 2282, 2293, 2305, 2317, 2329, 2343, 2353, 2373, 2380, 2391, 2402, 2417, 2433,
      2438, 2444, 2455, 2464, 2474, 2483, 2495, 2515, 2532, 2539, 2544, 2555, 2567, 2576, 2583, 2589, 2594,
      2600, 2609, 2615, 2621, 2629, 2636, 2646, 2654, 2666, 2682, 2701, 2726, 2733, 2745, 2757, 2770, 2779,
      2790, 2799, 2810, 2817, 2826, 2839, 2848, 2858, 2870, 2881, 2887, 2891, 2900, 2909, 2924, 2930, 2935,
      2947, 2957, 2964, 2973, 2980, 2987, 2997, 3007, 3016, 3023, 3032, 3040, 3046, 3055, 3066, 3083, 3097,
      3105, 3108, 3111, 3114, 3117, 3119, 3122, 3124, 3127, 3129, 3132, 3134, 3137, 3140, 3143, 3146, 3151,
      3161, 3179, 3183, 3191, 3207, 3219, 3231, 3246, 3255, 3265, 3276, 3287, 3299, 3310, 3328, 3346, 3359,
      3366, 3370, 3375, 3379, 3384, 3392, 3402, 3416, 3424, 3437, 3453, 3459, 3467, 3475, 3489, 3502, 3519,
      3534, 3545, 3560, 3574, 3589, 3600, 3609, 3618, 3627, 3641, 3650, 3661, 3678, 3687, 3696, 3705, 3716,
      3732, 3744, 3756, 3769, 3790, 3801, 3820, 3823, 3825, 3834, 3839, 3851, 3860, 3867, 3877, 3890, 3901,
      3910, 3921, 3932, 3944, 3954, 3962, 3974, 3984, 3996, 4004, 4017, 4026, 4036, 4048, 4055, 4063, 4069,
      4076, 4084, 4090, 4097, 4105, 4111, 4115, 4123, 4131, 4142, 4150, 4156, 4162, 4170, 4176, 4182, 4190,
      4196, 4202, 4212, 4224, 4237, 4247, 4254, 4267, 4275, 4281, 4294, 4301, 4320, 4333, 4346, 4357, 4364,
      4375, 4386, 4397, 4404, 4410, 4415, 4418, 4423, 4428, 4433, 4436, 4438, 4443, 4449, 4454, 4460, 4468,
      4475, 4484, 4494, 4501, 4513, 4521, 4526, 4541, 4559, 4571, 4581, 4593, 4606, 4623, 4638, 4654, 4670,
      4684, 4697, 4710, 4721, 4736, 4743, 4752, 4756, 4765, 4771, 4783, 4792, 4798, 4803, 4808, 4817, 4827,
      4836, 4847, 4856, 4863, 4870, 4877, 4886, 4899, 4906, 4916, 4926, 4930, 4934, 4938, 4943, 4954, 4965,
      4973, 4978, 4984, 4990, 5003, 5011, 5021, 5027, 5032, 5042, 5051, 5058, 5062, 5069, 5077, 5085, 5094,
      5102, 5109, 5115, 5120, 5125, 5133, 5141, 5150, 5156, 5165, 5174, 5183, 5193, 5199, 5204, 5210, 5215,
      5221, 5228, 5234, 5245, 5252, 5265, 5271, 5277, 5286, 5292, 5299, 5313, 5321, 5330, 5337, 5345, 5353,
      5364, 5374, 5385, 5393, 5401, 5409, 5422, 5436, 5450, 5461, 5471, 5482, 5490, 5500, 5509, 5519, 5530,
      5535, 5550, 5563, 5572, 5579, 5588, 5595, 5608, 5619, 5630, 5642, 5652, 5660, 5665, 5674, 5683, 5692,
      5705, 5717, 5720, 5729, 5741, 5756, 5770, 5779, 5790, 5799, 5807, 5816, 5828, 5835, 5849, 5868, 5880,
      5892, 5901, 5912, 5923, 5934, 5942, 5952, 5964, 5970, 5977, 5985, 5995, 6008, 6014, 6025, 6036, 6042,
      6050, 6059, 6070, 6079, 6085, 6093, 6100, 6112, 6124, 6130, 6135, 6141, 6153, 6164, 6170, 6182, 6190,
      6198, 6207, 6216, 6230, 6247, 6264, 6278, 6298, 6318, 6339, 6355, 6371, 6388, 6403, 6419, 6429, 6441,
      6449, 6458, 6472, 6483, 6496, 6512, 6517, 6528, 6541, 6552, 6570, 6585, 6606, 6626, 6640, 6653, 6663,
      6677, 6688, 6700, 6712, 6720, 6727, 6735, 6747, 6753, 6770, 6791, 6806, 6817, 6825, 6833, 6839, 6848,
      6860, 6868, 6874, 6883, 6895, 6904, 6917, 6926, 6939, 6948, 6961, 6970, 6983, 6996, 7014, 7023, 7033,
      7044, 7056, 7068, 7082, 7096, 7111, 7118, 7125, 7132, 7139, 7146, 7153, 7167, 7179, 7194, 7203, 7213,
      7228, 7238, 7248, 7264, 7276, 7288, 7298, 7307, 7320, 7328, 7335, 7341, 7351, 7363, 7370, 7384, 7392,
      7403, 7411, 7417, 7423, 7430, 7437, 7444, 7451, 7458, 7464, 7471, 7477, 7484, 7490, 7498, 7507, 7512,
      7517, 7520, 7535, 7544, 7562, 7577, 7586, 7595, 7599, 7613, 7624, 7637, 7645, 7654, 7668, 7681, 7692,
      7710, 7717, 7728, 7741, 7752, 7766, 7778, 7790, 7799, 7816, 7830, 7837, 7845, 7858, 7871, 7887, 7894,
      7906, 7916, 7931, 7941, 7950, 7959, 7968, 7977, 7986, 7998, 8010, 8023, 8032, 8039, 8048, 8055, 8062,
      8071, 8081, 8092, 8099, 8108, 8115, 8126, 8137);

   Name_Lengths : constant array (Setting) of Name_Length :=
     (17, 14, 19, 14, 19, 14, 18, 14, 18, 19, 22, 15, 20, 17, 18, 20, 14, 14, 15, 11, 16, 16, 20, 20, 18, 22,
      12, 10, 14, 13, 15, 9, 14, 15, 13, 11, 14, 15, 14, 12, 15, 12, 15, 15, 16, 13, 10, 13, 16, 17, 14, 6, 9,
      9, 12, 21, 10, 11, 11, 25, 14, 12, 24, 33, 28, 28, 23, 15, 16, 17, 17, 17, 27, 13, 15, 14, 24, 30, 11, 11,
      19, 7, 26, 21, 15, 10, 20, 10, 23, 28, 29, 20, 20, 15, 21, 19, 25, 20, 20, 20, 21, 21, 27, 20, 25, 22, 23,
      23, 20, 20, 22, 13, 24, 13, 13, 12, 11, 8, 10, 11, 11, 9, 13, 19, 16, 18, 14, 19, 11, 23, 14, 14, 14, 21,
      17, 20, 27, 18, 23, 24, 16, 17, 15, 11, 20, 12, 21, 22, 21, 25, 18, 24, 15, 13, 13, 24, 15, 15, 19, 23,
      19, 15, 25, 26, 10, 12, 15, 11, 12, 11, 12, 16, 16, 9, 16, 24, 19, 10, 23, 14, 20, 9, 11, 11, 11, 15, 15,
      16, 10, 20, 12, 13, 16, 18, 14, 16, 17, 24, 16, 7, 8, 9, 10, 18, 12, 13, 11, 9, 10, 8, 10, 11, 9, 19, 22,
      15, 16, 14, 16, 21, 10, 10, 11, 17, 15, 17, 21, 18, 12, 13, 15, 13, 23, 22, 18, 22, 21, 20, 23, 16, 18,
      24, 8, 8, 25, 19, 24, 22, 21, 23, 23, 23, 24, 19, 35, 16, 22, 22, 28, 30, 8, 12, 20, 19, 17, 17, 23, 31,
      29, 18, 16, 19, 22, 18, 20, 17, 15, 18, 18, 15, 14, 19, 15, 21, 18, 17, 26, 32, 43, 12, 21, 21, 19, 15,
      20, 15, 20, 14, 18, 21, 19, 17, 22, 19, 13, 9, 16, 16, 24, 10, 11, 20, 19, 15, 14, 14, 11, 16, 18, 12, 12,
      16, 14, 14, 21, 24, 25, 23, 17, 7, 7, 7, 7, 6, 6, 6, 6, 5, 5, 5, 5, 7, 6, 5, 12, 17, 30, 11, 15, 22, 20,
      21, 21, 16, 17, 18, 20, 21, 19, 29, 27, 18, 12, 10, 11, 9, 10, 13, 18, 23, 19, 26, 31, 18, 19, 13, 22, 21,
      25, 25, 17, 26, 25, 25, 16, 15, 15, 15, 21, 15, 20, 28, 17, 17, 18, 21, 27, 23, 24, 23, 34, 22, 33, 8, 8,
      14, 12, 18, 14, 14, 21, 23, 24, 18, 20, 20, 21, 22, 14, 24, 18, 20, 14, 20, 16, 16, 24, 15, 14, 13, 16,
      15, 14, 14, 13, 12, 8, 18, 12, 14, 20, 16, 16, 20, 16, 16, 20, 16, 16, 16, 17, 18, 16, 10, 20, 14, 10, 19,
      11, 30, 18, 23, 20, 16, 19, 19, 19, 26, 26, 23, 23, 24, 24, 24, 24, 23, 26, 27, 24, 27, 31, 27, 30, 30,
      26, 34, 30, 27, 22, 28, 16, 16, 19, 21, 25, 23, 26, 19, 22, 21, 20, 16, 22, 11, 14, 9, 16, 14, 22, 18, 14,
      13, 13, 18, 18, 17, 21, 19, 14, 14, 13, 18, 27, 15, 18, 20, 8, 8, 12, 12, 20, 21, 16, 12, 13, 13, 31, 15,
      20, 15, 16, 19, 18, 15, 10, 15, 17, 16, 18, 18, 18, 17, 15, 15, 20, 20, 21, 16, 16, 17, 19, 19, 16, 16,
      17, 15, 13, 14, 13, 23, 16, 24, 15, 15, 21, 16, 16, 25, 18, 22, 14, 15, 15, 20, 21, 24, 18, 17, 18, 26,
      27, 28, 25, 24, 28, 20, 18, 20, 18, 21, 11, 26, 23, 19, 17, 20, 14, 22, 19, 20, 20, 21, 16, 11, 18, 18,
      18, 22, 22, 8, 14, 22, 23, 23, 16, 19, 15, 13, 14, 18, 18, 26, 33, 20, 20, 17, 22, 22, 22, 19, 20, 22, 14,
      15, 16, 18, 23, 12, 14, 15, 10, 16, 13, 16, 19, 8, 11, 9, 20, 18, 8, 8, 8, 17, 14, 11, 16, 12, 12, 13, 15,
      19, 26, 26, 21, 32, 30, 30, 23, 23, 23, 21, 25, 15, 18, 15, 16, 23, 14, 19, 22, 13, 17, 18, 19, 26, 24,
      34, 32, 23, 20, 16, 20, 16, 20, 18, 12, 9, 11, 18, 13, 26, 34, 25, 16, 13, 14, 13, 13, 18, 14, 13, 13, 18,
      11, 19, 11, 19, 11, 19, 11, 21, 19, 25, 14, 17, 19, 18, 19, 20, 23, 20, 10, 10, 10, 10, 10, 10, 23, 20,
      18, 12, 17, 24, 17, 16, 22, 22, 19, 18, 18, 21, 14, 10, 10, 15, 20, 12, 24, 14, 21, 17, 15, 15, 13, 13,
      13, 13, 13, 13, 13, 13, 13, 13, 18, 17, 12, 15, 8, 22, 15, 26, 23, 17, 20, 11, 23, 19, 21, 12, 12, 23, 22,
      19, 29, 16, 20, 21, 23, 25, 24, 24, 22, 29, 29, 12, 12, 19, 19, 27, 15, 21, 17, 25, 18, 15, 15, 15, 15,
      19, 24, 24, 25, 18, 16, 18, 17, 17, 19, 22, 23, 15, 17, 16, 20, 18, 11);

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
