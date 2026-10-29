--  The parameter groups of the configuration: a record per group, the
--  configuration over all of them with the reference's defaults for the
--  settings oracle's build, and every setting's value. Generated from the
--  settings oracle.
with Interfaces; use Interfaces;
with Adaflight.Settings_Table; use Adaflight.Settings_Table;

package Adaflight.Config_Groups with SPARK_Mode is

   type Bytes is array (Natural range <>) of Unsigned_8;
   type Integer_8_List is array (Natural range <>) of Integer_8;
   type Unsigned_16_List is array (Natural range <>) of Unsigned_16;
   type Integer_16_List is array (Natural range <>) of Integer_16;
   type Unsigned_32_List is array (Natural range <>) of Unsigned_32;
   type Boolean_List is array (Natural range <>) of Boolean;

   type Blackbox_Config_Record is record
      Fields_Disabled_Mask : Unsigned_32;
      Sample_Rate          : Unsigned_8;
      Device               : Unsigned_8;
      Mode                 : Unsigned_8;
      High_Resolution      : Unsigned_8;
      Blackbox_Uart        : Integer_8;
      Blackbox_Baud        : Unsigned_8;
   end record;
   type Time_Config_Record is record
      Tz_Offset_Minutes : Integer_16;
   end record;
   subtype Bytes_6 is Bytes (0 .. 5);
   type System_Config_Record is record
      Pid_Profile_Index          : Unsigned_8;
      Active_Rate_Profile        : Unsigned_8;
      Debug_Mode                 : Unsigned_8;
      Task_Statistics            : Unsigned_8;
      Rate_Profile6_Pos_Switch   : Unsigned_8;
      Cpu_Overclock              : Unsigned_8;
      Power_On_Arming_Grace_Time : Unsigned_8;
      Board_Identifier           : Bytes_6;
      Hse_Mhz                    : Unsigned_8;
      Configuration_State        : Unsigned_8;
      Enable_Stick_Arming        : Unsigned_8;
      Active_Battery_Profile     : Unsigned_8;
   end record;
   type Feature_Config_Record is record
      Enabled_Features : Unsigned_32;
   end record;
   subtype Unsigned_16_List_5 is Unsigned_16_List (0 .. 4);
   type Camera_Control_Config_Record is record
      Mode                     : Unsigned_8;
      Ref_Voltage              : Unsigned_16;
      Key_Delay_Ms             : Unsigned_16;
      Internal_Resistance      : Unsigned_16;
      Io_Tag                   : Unsigned_8;
      Inverted                 : Unsigned_8;
      Button_Resistance_Values : Unsigned_16_List_5;
   end record;
   subtype Bytes_3 is Bytes (0 .. 2);
   type Status_Led_Config_Record is record
      Io_Tags   : Bytes_3;
      Inversion : Unsigned_8;
   end record;
   subtype Bytes_8 is Bytes (0 .. 7);
   type Serial_Pin_Config_Record is record
      Io_Tag_Tx       : Bytes_8;
      Io_Tag_Rx       : Bytes_8;
      Io_Tag_Inverter : Bytes_6;
   end record;
   type Esc_Serial_Config_Record is record
      Io_Tag : Unsigned_8;
   end record;
   subtype Unsigned_16_List_3 is Unsigned_16_List (0 .. 2);
   subtype Bytes_9 is Bytes (0 .. 8);
   type Control_Rate_Config_Record is record
      Thr_Mid8               : Unsigned_8;
      Thr_Expo8              : Unsigned_8;
      Rates_Type             : Unsigned_8;
      Rc_Rates               : Bytes_3;
      Rc_Expo                : Bytes_3;
      Rates                  : Bytes_3;
      Throttle_Limit_Type    : Unsigned_8;
      Throttle_Limit_Percent : Unsigned_8;
      Rate_Limit             : Unsigned_16_List_3;
      Profile_Name           : Bytes_9;
      Quick_Rates_Rc_Expo    : Unsigned_8;
      Thr_Hover8             : Unsigned_8;
   end record;
   type Control_Rate_Config_Record_List_4 is array (0 .. 3) of Control_Rate_Config_Record;
   type Throttle_Correction_Config_Record is record
      Throttle_Correction_Angle : Unsigned_16;
      Throttle_Correction_Value : Unsigned_8;
   end record;
   type Channel_Range_Record is record
      Start_Step : Unsigned_8;
      End_Step   : Unsigned_8;
   end record;
   type Adjustment_Range_Record is record
      Aux_Channel_Index        : Unsigned_8;
      Range_Value              : Channel_Range_Record;
      Adjustment_Config        : Unsigned_8;
      Aux_Switch_Channel_Index : Unsigned_8;
      Adjustment_Center        : Unsigned_16;
      Adjustment_Scale         : Unsigned_16;
   end record;
   type Adjustment_Range_Record_List_30 is array (0 .. 29) of Adjustment_Range_Record;
   type Rc_Controls_Config_Record is record
      Deadband             : Unsigned_8;
      Yaw_Deadband         : Unsigned_8;
      Yaw_Control_Reversed : Boolean;
   end record;
   type Arming_Config_Record is record
      Gyro_Cal_On_First_Arm : Unsigned_8;
      Auto_Disarm_Delay     : Unsigned_8;
      Prearm_Allow_Rearm    : Unsigned_8;
   end record;
   type Flight3_D_Config_Record is record
      Deadband3d_Low      : Unsigned_16;
      Deadband3d_High     : Unsigned_16;
      Neutral3d           : Unsigned_16;
      Deadband3d_Throttle : Unsigned_16;
      Limit3d_Low         : Unsigned_16;
      Limit3d_High        : Unsigned_16;
      Switched_Mode3d     : Unsigned_8;
   end record;
   type Mode_Activation_Condition_Record is record
      Mode_Id           : Unsigned_8;
      Aux_Channel_Index : Unsigned_8;
      Range_Value       : Channel_Range_Record;
      Mode_Logic        : Unsigned_8;
      Linked_To         : Unsigned_8;
   end record;
   type Mode_Activation_Condition_Record_List_20 is array (0 .. 19) of Mode_Activation_Condition_Record;
   subtype Bytes_16 is Bytes (0 .. 15);
   type Bytes_16_List_4 is array (0 .. 3) of Bytes_16;
   type Mode_Activation_Config_Record is record
      Box_User_Names : Bytes_16_List_4;
   end record;
   type Failsafe_Config_Record is record
      Failsafe_Throttle           : Unsigned_16;
      Failsafe_Throttle_Low_Delay : Unsigned_16;
      Failsafe_Delay              : Unsigned_8;
      Failsafe_Landing_Time       : Unsigned_8;
      Failsafe_Switch_Mode        : Unsigned_8;
      Failsafe_Procedure          : Unsigned_8;
      Failsafe_Recovery_Delay     : Unsigned_16;
      Failsafe_Stick_Threshold    : Unsigned_8;
   end record;
   type Imu_Config_Record is record
      Imu_Dcm_Kp        : Unsigned_16;
      Imu_Dcm_Ki        : Unsigned_16;
      Small_Angle       : Unsigned_8;
      Imu_Process_Denom : Unsigned_8;
      Mag_Declination   : Integer_16;
   end record;
   type Mixer_Config_Record is record
      Mixer_Mode              : Unsigned_8;
      Yaw_Motors_Reversed     : Boolean;
      Crashflip_Motor_Percent : Unsigned_8;
      Crashflip_Rate          : Unsigned_8;
      Crashflip_Auto_Rearm    : Boolean;
      Mixer_Type              : Unsigned_8;
      Rpm_Limit               : Boolean;
      Rpm_Limit_P             : Unsigned_16;
      Rpm_Limit_I             : Unsigned_16;
      Rpm_Limit_D             : Unsigned_16;
      Rpm_Limit_Value         : Unsigned_16;
   end record;
   type Motor_Mixer_Record is record
      Throttle : Float;
      Roll     : Float;
      Pitch    : Float;
      Yaw      : Float;
   end record;
   type Motor_Mixer_Record_List_8 is array (0 .. 7) of Motor_Mixer_Record;
   type Tricopter_Mixer_Config_Record is record
      Dummy : Unsigned_8;
   end record;
   type Pid_Config_Record is record
      Pid_Process_Denom                   : Unsigned_8;
      Runaway_Takeoff_Prevention          : Unsigned_8;
      Runaway_Takeoff_Deactivate_Delay    : Unsigned_16;
      Runaway_Takeoff_Deactivate_Throttle : Unsigned_8;
   end record;
   type Pidf_Record is record
      P : Unsigned_8;
      I : Unsigned_8;
      D : Unsigned_8;
      F : Unsigned_16;
      S : Unsigned_8;
   end record;
   type Pidf_Record_List_5 is array (0 .. 4) of Pidf_Record;
   type Pid_Profile_Record is record
      Yaw_Lowpass_Hz                     : Unsigned_16;
      Dterm_Lpf1_Static_Hz               : Unsigned_16;
      Dterm_Notch_Hz                     : Unsigned_16;
      Dterm_Notch_Cutoff                 : Unsigned_16;
      Pid                                : Pidf_Record_List_5;
      Dterm_Lpf1_Type                    : Unsigned_8;
      Iterm_Windup                       : Unsigned_8;
      Pid_Sum_Limit                      : Unsigned_16;
      Pid_Sum_Limit_Yaw                  : Unsigned_16;
      Pid_At_Min_Throttle                : Unsigned_8;
      Angle_Limit                        : Unsigned_8;
      Horizon_Limit_Degrees              : Unsigned_8;
      Horizon_Ignore_Sticks              : Unsigned_8;
      Anti_Gravity_Gain                  : Unsigned_8;
      Yaw_Rate_Accel_Limit               : Unsigned_16;
      Rate_Accel_Limit                   : Unsigned_16;
      Crash_Dthreshold                   : Unsigned_16;
      Crash_Gthreshold                   : Unsigned_16;
      Crash_Setpoint_Threshold           : Unsigned_16;
      Crash_Time                         : Unsigned_16;
      Crash_Delay                        : Unsigned_16;
      Crash_Recovery_Angle               : Unsigned_8;
      Crash_Recovery_Rate                : Unsigned_8;
      Crash_Limit_Yaw                    : Unsigned_16;
      Iterm_Limit                        : Unsigned_16;
      Dterm_Lpf2_Static_Hz               : Unsigned_16;
      Crash_Recovery                     : Unsigned_8;
      Throttle_Boost                     : Unsigned_8;
      Throttle_Boost_Cutoff              : Unsigned_8;
      Iterm_Rotation                     : Unsigned_8;
      Iterm_Relax_Type                   : Unsigned_8;
      Iterm_Relax_Cutoff                 : Unsigned_8;
      Iterm_Relax                        : Unsigned_8;
      Acro_Trainer_Angle_Limit           : Unsigned_8;
      Acro_Trainer_Debug_Axis            : Unsigned_8;
      Acro_Trainer_Gain                  : Unsigned_8;
      Acro_Trainer_Lookahead_Ms          : Unsigned_16;
      Dterm_Lpf2_Type                    : Unsigned_8;
      Dterm_Lpf1_Dyn_Min_Hz              : Unsigned_16;
      Dterm_Lpf1_Dyn_Max_Hz              : Unsigned_16;
      Launch_Control_Mode                : Unsigned_8;
      Launch_Control_Throttle_Percent    : Unsigned_8;
      Launch_Control_Angle_Limit         : Unsigned_8;
      Launch_Control_Gain                : Unsigned_8;
      Launch_Control_Allow_Trigger_Reset : Unsigned_8;
      Thrust_Linearization               : Unsigned_8;
      D_Max                              : Bytes_3;
      D_Max_Gain                         : Unsigned_8;
      D_Max_Advance                      : Unsigned_8;
      Motor_Output_Limit                 : Unsigned_8;
      Auto_Profile_Cell_Count            : Integer_8;
      Profile_Name                       : Bytes_9;
      Dyn_Idle_Min_Rpm                   : Unsigned_8;
      Dyn_Idle_P_Gain                    : Unsigned_8;
      Dyn_Idle_I_Gain                    : Unsigned_8;
      Dyn_Idle_D_Gain                    : Unsigned_8;
      Dyn_Idle_Max_Increase              : Unsigned_8;
      Feedforward_Transition             : Unsigned_8;
      Feedforward_Averaging              : Unsigned_8;
      Feedforward_Smooth_Factor          : Unsigned_8;
      Feedforward_Jitter_Factor          : Unsigned_8;
      Feedforward_Boost                  : Unsigned_8;
      Feedforward_Max_Rate_Limit         : Unsigned_8;
      Feedforward_Yaw_Hold_Gain          : Unsigned_8;
      Feedforward_Yaw_Hold_Time          : Unsigned_8;
      Dterm_Lpf1_Dyn_Expo                : Unsigned_8;
      Level_Race_Mode                    : Unsigned_8;
      Vbat_Sag_Compensation              : Unsigned_8;
      Simplified_Pids_Mode               : Unsigned_8;
      Simplified_Master_Multiplier       : Unsigned_8;
      Simplified_Roll_Pitch_Ratio        : Unsigned_8;
      Simplified_I_Gain                  : Unsigned_8;
      Simplified_D_Gain                  : Unsigned_8;
      Simplified_Pi_Gain                 : Unsigned_8;
      Simplified_D_Max_Gain              : Unsigned_8;
      Simplified_Feedforward_Gain        : Unsigned_8;
      Simplified_Dterm_Filter            : Unsigned_8;
      Simplified_Dterm_Filter_Multiplier : Unsigned_8;
      Simplified_Pitch_Pi_Gain           : Unsigned_8;
      Anti_Gravity_Cutoff_Hz             : Unsigned_8;
      Anti_Gravity_P_Gain                : Unsigned_8;
      Tpa_Mode                           : Unsigned_8;
      Tpa_Rate                           : Unsigned_8;
      Tpa_Breakpoint                     : Unsigned_16;
      Angle_Feedforward_Smoothing_Ms     : Unsigned_8;
      Angle_Earth_Ref                    : Unsigned_8;
      Horizon_Delay_Ms                   : Unsigned_16;
      Tpa_Low_Rate                       : Integer_8;
      Tpa_Low_Breakpoint                 : Unsigned_16;
      Tpa_Low_Always                     : Unsigned_8;
      Ez_Landing_Threshold               : Unsigned_8;
      Ez_Landing_Limit                   : Unsigned_8;
      Ez_Landing_Speed                   : Unsigned_8;
      Landing_Disarm_Threshold           : Unsigned_8;
      Spa_Center                         : Unsigned_16_List_3;
      Spa_Width                          : Unsigned_16_List_3;
      Spa_Mode                           : Bytes_3;
      Tpa_Curve_Type                     : Unsigned_8;
      Tpa_Curve_Stall_Throttle           : Unsigned_8;
      Tpa_Curve_Pid_Thr0                 : Unsigned_16;
      Tpa_Curve_Pid_Thr100               : Unsigned_16;
      Tpa_Curve_Expo                     : Integer_8;
      Tpa_Speed_Type                     : Unsigned_8;
      Tpa_Speed_Basic_Delay              : Unsigned_16;
      Tpa_Speed_Basic_Gravity            : Unsigned_16;
      Tpa_Speed_Adv_Prop_Pitch           : Unsigned_16;
      Tpa_Speed_Adv_Mass                 : Unsigned_16;
      Tpa_Speed_Adv_Drag_K               : Unsigned_16;
      Tpa_Speed_Adv_Thrust               : Unsigned_16;
      Tpa_Speed_Max_Voltage              : Unsigned_16;
      Tpa_Speed_Pitch_Offset             : Integer_16;
      Yaw_Type                           : Unsigned_8;
      Angle_Pitch_Offset                 : Integer_16;
      Chirp_Lag_Freq_Hz                  : Unsigned_8;
      Chirp_Lead_Freq_Hz                 : Unsigned_8;
      Chirp_Amplitude_Roll               : Unsigned_16;
      Chirp_Amplitude_Pitch              : Unsigned_16;
      Chirp_Amplitude_Yaw                : Unsigned_16;
      Chirp_Frequency_Start_Deci_Hz      : Unsigned_16;
      Chirp_Frequency_End_Deci_Hz        : Unsigned_16;
      Chirp_Time_Seconds                 : Unsigned_8;
      Chirp_Repeat                       : Unsigned_8;
   end record;
   type Pid_Profile_Record_List_4 is array (0 .. 3) of Pid_Profile_Record;
   type Position_Config_Record is record
      Altitude_Source          : Unsigned_8;
      Altitude_Prefer_Baro     : Unsigned_8;
      Altitude_Lpf             : Unsigned_16;
      Altitude_D_Lpf           : Unsigned_16;
      Rangefinder_Max_Range_Cm : Unsigned_16;
   end record;
   type Servo_Dev_Config_Record is record
      Servo_Center_Pulse : Unsigned_16;
      Servo_Pwm_Rate     : Unsigned_16;
      Io_Tags            : Bytes_8;
   end record;
   type Servo_Config_Record is record
      Dev                              : Servo_Dev_Config_Record;
      Servo_Lowpass_Freq               : Unsigned_16;
      Tri_Unarmed_Servo                : Unsigned_8;
      Channel_Forwarding_Start_Channel : Unsigned_8;
   end record;
   type Servo_Mixer_Record is record
      Target_Channel : Unsigned_8;
      Input_Source   : Unsigned_8;
      Rate           : Integer_8;
      Speed          : Unsigned_8;
      Min            : Integer_8;
      Max            : Integer_8;
      Box            : Unsigned_8;
   end record;
   type Servo_Mixer_Record_List_16 is array (0 .. 15) of Servo_Mixer_Record;
   type Servo_Param_Record is record
      Reversed_Sources     : Unsigned_32;
      Min                  : Integer_16;
      Max                  : Integer_16;
      Middle               : Integer_16;
      Rate                 : Integer_8;
      Forward_From_Channel : Integer_8;
   end record;
   type Servo_Param_Record_List_8 is array (0 .. 7) of Servo_Param_Record;
   type Gimbal_Config_Record is record
      Mode : Unsigned_8;
   end record;
   type Led_Strip_Config_Record is record
      Ledstrip_Visual_Beeper       : Unsigned_8;
      Io_Tag                       : Unsigned_8;
      Ledstrip_Grb_Rgb             : Unsigned_8;
      Ledstrip_Profile             : Unsigned_8;
      Ledstrip_Race_Color          : Unsigned_8;
      Ledstrip_Beacon_Color        : Unsigned_8;
      Ledstrip_Beacon_Period_Ms    : Unsigned_16;
      Ledstrip_Beacon_Percent      : Unsigned_8;
      Ledstrip_Beacon_Armed_Only   : Unsigned_8;
      Ledstrip_Visual_Beeper_Color : Unsigned_8;
      Ledstrip_Brightness          : Unsigned_8;
      Ledstrip_Rainbow_Delta       : Unsigned_16;
      Ledstrip_Rainbow_Freq        : Unsigned_16;
   end record;
   subtype Unsigned_32_List_32 is Unsigned_32_List (0 .. 31);
   type Hsv_Color_Record is record
      H : Unsigned_16;
      S : Unsigned_8;
      V : Unsigned_8;
   end record;
   type Hsv_Color_Record_List_16 is array (0 .. 15) of Hsv_Color_Record;
   type Mode_Color_Indexes_Record is record
      Color : Bytes_6;
   end record;
   type Mode_Color_Indexes_Record_List_6 is array (0 .. 5) of Mode_Color_Indexes_Record;
   subtype Bytes_11 is Bytes (0 .. 10);
   type Special_Color_Indexes_Record is record
      Color : Bytes_11;
   end record;
   type Led_Strip_Status_Mode_Config_Record is record
      Led_Configs          : Unsigned_32_List_32;
      Colors               : Hsv_Color_Record_List_16;
      Mode_Colors          : Mode_Color_Indexes_Record_List_6;
      Special_Colors       : Special_Color_Indexes_Record;
      Ledstrip_Aux_Channel : Unsigned_8;
   end record;
   type Serial_Config_Record is record
      Serial_Update_Rate_Hz : Unsigned_16;
      Reboot_Character      : Unsigned_8;
   end record;
   type Transponder_Config_Record is record
      Provider : Unsigned_8;
      Reserved : Unsigned_8;
      Data     : Bytes_9;
      Io_Tag   : Unsigned_8;
   end record;
   type Vtx_Channel_Activation_Condition_Record is record
      Aux_Channel_Index : Unsigned_8;
      Band              : Unsigned_8;
      Channel           : Unsigned_8;
      Power             : Unsigned_8;
      Range_Value       : Channel_Range_Record;
   end record;
   type Vtx_Channel_Activation_Condition_Record_List_10 is array (0 .. 9) of Vtx_Channel_Activation_Condition_Record;
   type Vtx_Config_Record is record
      Vtx_Channel_Activation_Conditions : Vtx_Channel_Activation_Condition_Record_List_10;
      Half_Duplex                       : Unsigned_8;
   end record;
   type Vtx_Settings_Config_Record is record
      Band             : Unsigned_8;
      Channel          : Unsigned_8;
      Power            : Unsigned_8;
      Freq             : Unsigned_16;
      Pit_Mode_Freq    : Unsigned_16;
      Low_Power_Disarm : Unsigned_8;
      Softserial_Alt   : Unsigned_8;
      Vtx_Type         : Unsigned_8;
      Vtx_Uart         : Integer_8;
   end record;
   type Osd_Custom_Text_Config_Record is record
      Terminator : Unsigned_8;
   end record;
   subtype Unsigned_16_List_2 is Unsigned_16_List (0 .. 1);
   subtype Bytes_17 is Bytes (0 .. 16);
   type Bytes_17_List_3 is array (0 .. 2) of Bytes_17;
   subtype Integer_8_List_4 is Integer_8_List (0 .. 3);
   type Osd_Config_Record is record
      Cap_Alarm               : Unsigned_16;
      Alt_Alarm               : Unsigned_16;
      Rssi_Alarm              : Unsigned_8;
      Units                   : Unsigned_8;
      Timers                  : Unsigned_16_List_2;
      Enabled_Warnings        : Unsigned_32;
      Ah_Max_Pitch            : Unsigned_8;
      Ah_Max_Roll             : Unsigned_8;
      Enabled_Stats           : Unsigned_32;
      Esc_Temp_Alarm          : Unsigned_8;
      Esc_Rpm_Alarm           : Integer_16;
      Esc_Current_Alarm       : Integer_16;
      Core_Temp_Alarm         : Unsigned_8;
      Ah_Invert               : Unsigned_8;
      Osd_Profile_Index       : Unsigned_8;
      Overlay_Radio_Mode      : Unsigned_8;
      Profile                 : Bytes_17_List_3;
      Link_Quality_Alarm      : Unsigned_16;
      Rssi_Dbm_Alarm          : Integer_16;
      Rsnr_Alarm              : Integer_16;
      Gps_Sats_Show_Pdop      : Unsigned_8;
      Rc_Channels             : Integer_8_List_4;
      Display_Port_Device     : Unsigned_8;
      Distance_Alarm          : Unsigned_16;
      Logo_On_Arming          : Unsigned_8;
      Logo_On_Arming_Duration : Unsigned_8;
      Camera_Frame_Width      : Unsigned_8;
      Camera_Frame_Height     : Unsigned_8;
      Framerate_Hz            : Unsigned_16;
      Cms_Background_Type     : Unsigned_8;
      Stat_Show_Cell_Value    : Unsigned_8;
      Osd_Craftname_Msgs      : Unsigned_8;
      Aux_Channel             : Unsigned_8;
      Aux_Scale               : Unsigned_16;
      Aux_Symbol              : Unsigned_8;
      Canvas_Cols             : Unsigned_8;
      Canvas_Rows             : Unsigned_8;
      Osd_Use_Quick_Menu      : Unsigned_8;
      Osd_Show_Spec_Prearm    : Unsigned_8;
      Arming_Logo             : Unsigned_8;
      Osd_Uart                : Integer_8;
      Osd_Custom_Text_Uart    : Integer_8;
      Osd_Custom_Text_Baud    : Unsigned_8;
   end record;
   subtype Unsigned_16_List_99 is Unsigned_16_List (0 .. 98);
   type Osd_Element_Config_Record is record
      Item_Pos : Unsigned_16_List_99;
   end record;
   type Adc_Channel_Config_T_Record is record
      Enabled : Boolean;
      Io_Tag  : Unsigned_8;
      Device  : Integer_8;
   end record;
   subtype Integer_8_List_3 is Integer_8_List (0 .. 2);
   type Adc_Config_Record is record
      Vbat                     : Adc_Channel_Config_T_Record;
      Rssi                     : Adc_Channel_Config_T_Record;
      Current                  : Adc_Channel_Config_T_Record;
      External1                : Adc_Channel_Config_T_Record;
      Device                   : Integer_8;
      Vref_Int_Calibration     : Unsigned_16;
      Temp_Sensor_Calibration1 : Unsigned_16;
      Temp_Sensor_Calibration2 : Unsigned_16;
      Dmaopt                   : Integer_8_List_3;
   end record;
   type Alt_Hold_Config_Record is record
      Climb_Rate : Unsigned_8;
      Deadband   : Unsigned_8;
   end record;
   type Autopilot_Config_Record is record
      Landing_Altitude_M         : Unsigned_8;
      Hover_Throttle             : Unsigned_16;
      Throttle_Min               : Unsigned_16;
      Throttle_Max               : Unsigned_16;
      Altitude_P                 : Unsigned_8;
      Altitude_I                 : Unsigned_8;
      Altitude_D                 : Unsigned_8;
      Altitude_A                 : Unsigned_8;
      Altitude_F                 : Unsigned_8;
      Position_P                 : Unsigned_8;
      Position_I                 : Unsigned_8;
      Position_D                 : Unsigned_8;
      Position_A                 : Unsigned_8;
      Position_F                 : Unsigned_8;
      Position_Cutoff            : Unsigned_8;
      Stop_Threshold             : Unsigned_8;
      Max_Angle                  : Unsigned_8;
      Velocity_Drag_Coeff        : Unsigned_8;
      Max_Velocity               : Unsigned_16;
      Waypoint_Arrival_Radius    : Unsigned_16;
      Waypoint_Hold_Radius       : Unsigned_16;
      Stick_Deadband             : Unsigned_16;
      Throttle_Deadband          : Unsigned_16;
      Nav_Corner_Speed           : Unsigned_16;
      Nav_Corner_Delta_V         : Unsigned_16;
      Nav_Decel                  : Unsigned_16;
      Nav_Accel                  : Unsigned_16;
      Nav_Carrot_Lead_Time       : Unsigned_8;
      Nav_Carrot_Lead_Max        : Unsigned_16;
      Nav_Preturn_Dist           : Unsigned_16;
      Yaw_Mode                   : Unsigned_8;
      Yaw_P                      : Unsigned_8;
      Max_Yaw_Rate               : Unsigned_8;
      Min_Forward_Velocity       : Unsigned_16;
      Velocity_Buildup_Max_Pitch : Unsigned_8;
      Max_Turn_Rate              : Unsigned_8;
      Hold_Orbit_Radius          : Unsigned_16;
      Hold_Figure8_Width         : Unsigned_16;
      Landing_Descent_Rate       : Unsigned_8;
      Landing_Detection_Time     : Unsigned_8;
      Landing_Spiral_Enable      : Unsigned_8;
      Landing_Spiral_Radius      : Unsigned_16;
      Landing_Spiral_Rate        : Unsigned_8;
      Landing_Velocity_Threshold : Unsigned_8;
      Landing_Throttle_Threshold : Unsigned_16;
      L1_Enable                  : Unsigned_8;
      L1_Period                  : Unsigned_16;
      L1_Min_Lookahead           : Unsigned_16;
      L1_Max_Lookahead           : Unsigned_16;
      L1_Max_Cross_Track_Error   : Unsigned_16;
      L1_Turn_Rate               : Unsigned_8;
      Min_Nav_Altitude_M         : Unsigned_8;
      Rx_Loss_Policy             : Unsigned_8;
      Max_Distance_From_Home_M   : Unsigned_16;
      Geofence_Action            : Unsigned_8;
   end record;
   type Beeper_Dev_Config_Record is record
      Io_Tag        : Unsigned_8;
      Is_Inverted   : Unsigned_8;
      Is_Open_Drain : Unsigned_8;
      Frequency     : Unsigned_16;
   end record;
   type Beeper_Config_Record is record
      Beeper_Off_Flags       : Unsigned_32;
      Dshot_Beacon_Tone      : Unsigned_8;
      Dshot_Beacon_Off_Flags : Unsigned_32;
   end record;
   subtype Bytes_32 is Bytes (0 .. 31);
   subtype Bytes_5 is Bytes (0 .. 4);
   subtype Bytes_21 is Bytes (0 .. 20);
   type Board_Config_Record is record
      Signature             : Bytes_32;
      Manufacturer_Id       : Bytes_5;
      Board_Name            : Bytes_21;
      Board_Information_Set : Unsigned_8;
      Signature_Set         : Unsigned_8;
   end record;
   type I2c_Config_Record is record
      Io_Tag_Scl  : Unsigned_8;
      Io_Tag_Sda  : Unsigned_8;
      Pull_Up     : Boolean;
      Clock_Speed : Unsigned_16;
   end record;
   type I2c_Config_Record_List_3 is array (0 .. 2) of I2c_Config_Record;
   type Spi_Pin_Config_Record is record
      Io_Tag_Sck  : Unsigned_8;
      Io_Tag_Miso : Unsigned_8;
      Io_Tag_Mosi : Unsigned_8;
      Tx_Dmaopt   : Integer_8;
      Rx_Dmaopt   : Integer_8;
   end record;
   type Spi_Pin_Config_Record_List_3 is array (0 .. 2) of Spi_Pin_Config_Record;
   type Dashboard_Config_Record is record
      Device  : Integer_8;
      Address : Unsigned_8;
   end record;
   subtype Bytes_4 is Bytes (0 .. 3);
   type Display_Port_Profile_Record is record
      Col_Adjust       : Integer_8;
      Row_Adjust       : Integer_8;
      Invert           : Boolean;
      Black_Brightness : Unsigned_8;
      White_Brightness : Unsigned_8;
      Font_Selection   : Bytes_4;
      Use_Device_Blink : Unsigned_8;
   end record;
   type Dyn_Notch_Config_Record is record
      Dyn_Notch_Min_Hz : Unsigned_16;
      Dyn_Notch_Max_Hz : Unsigned_16;
      Dyn_Notch_Q      : Unsigned_16;
      Dyn_Notch_Count  : Unsigned_8;
   end record;
   type Flash_Config_Record is record
      Cs_Tag          : Unsigned_8;
      Spi_Device      : Unsigned_8;
      Quad_Spi_Device : Unsigned_8;
      Octo_Spi_Device : Unsigned_8;
   end record;
   type Flight_Plan_Config_Record_Waypoints_Record is record
      Latitude      : Integer_32;
      Longitude     : Integer_32;
      Altitude      : Integer_32;
      Speed         : Unsigned_16;
      Duration      : Unsigned_16;
      Vert_Rate     : Unsigned_16;
      Type_Value    : Unsigned_8;
      Pattern       : Unsigned_8;
      Yaw_Behaviour : Unsigned_8;
   end record;
   type Flight_Plan_Config_Record_Waypoints_Record_List_30 is array (0 .. 29) of
      Flight_Plan_Config_Record_Waypoints_Record;
   type Flight_Plan_Config_Record is record
      Waypoint_Count : Unsigned_8;
      Waypoints      : Flight_Plan_Config_Record_Waypoints_Record_List_30;
   end record;
   type Gimbal_Track_Config_Record is record
      Gimbal_Roll_Rc_Gain       : Integer_8;
      Gimbal_Pitch_Rc_Thr_Gain  : Integer_8;
      Gimbal_Pitch_Rc_Low_Gain  : Integer_8;
      Gimbal_Pitch_Rc_High_Gain : Integer_8;
      Gimbal_Yaw_Rc_Gain        : Integer_8;
      Gimbal_Roll_Gain          : Integer_8;
      Gimbal_Roll_Offset        : Integer_8;
      Gimbal_Roll_Limit         : Integer_8;
      Gimbal_Pitch_Gain         : Integer_8;
      Gimbal_Pitch_Offset       : Integer_8;
      Gimbal_Pitch_Low_Limit    : Integer_8;
      Gimbal_Pitch_High_Limit   : Integer_8;
      Gimbal_Yaw_Gain           : Integer_8;
      Gimbal_Yaw_Offset         : Integer_8;
      Gimbal_Yaw_Limit          : Integer_8;
      Gimbal_Stabilisation      : Integer_8;
      Gimbal_Sensitivity        : Integer_8;
      Gimbal_Uart               : Integer_8;
   end record;
   type Gps_Lap_Timer_Config_Record is record
      Gate_Lat                 : Integer_32;
      Gate_Lon                 : Integer_32;
      Minimum_Lap_Time_Seconds : Unsigned_16;
      Gate_Tolerance_M         : Unsigned_8;
   end record;
   subtype Bytes_65 is Bytes (0 .. 64);
   type Gps_Config_Record is record
      Provider                : Unsigned_8;
      Sbas_Mode               : Unsigned_8;
      Auto_Config             : Unsigned_8;
      Auto_Baud               : Unsigned_8;
      Gps_Ublox_Acquire_Model : Unsigned_8;
      Gps_Ublox_Flight_Model  : Unsigned_8;
      Gps_Update_Rate_Hz      : Unsigned_8;
      Gps_Ublox_Use_Galileo   : Boolean;
      Gps_Set_Home_Point_Once : Boolean;
      Gps_Use_3d_Speed        : Boolean;
      Sbas_Integrity          : Boolean;
      Gps_Ublox_Utc_Standard  : Unsigned_8;
      Gps_Ublox_Enable_Ana    : Boolean;
      Nmea_Custom_Commands    : Bytes_65;
      Gps_Uart                : Integer_8;
      Gps_Baud                : Unsigned_8;
   end record;
   type Gps_Rescue_Record is record
      Min_Start_Dist_M         : Unsigned_16;
      Altitude_Mode            : Unsigned_8;
      Initial_Climb_M          : Unsigned_16;
      Ascend_Rate              : Unsigned_16;
      Return_Altitude_M        : Unsigned_16;
      Ground_Speed_Cm_S        : Unsigned_16;
      Descent_Distance_M       : Unsigned_16;
      Descend_Rate             : Unsigned_16;
      Sanity_Checks            : Unsigned_8;
      Min_Sats                 : Unsigned_8;
      Allow_Arming_Without_Fix : Unsigned_8;
      Yaw_P                    : Unsigned_8;
   end record;
   subtype Integer_16_List_3 is Integer_16_List (0 .. 2);
   type Gyro_Device_Config_Record is record
      Index            : Integer_8;
      Bus_Type         : Unsigned_8;
      Spi_Bus          : Unsigned_8;
      Csn_Tag          : Unsigned_8;
      I2c_Bus          : Unsigned_8;
      I2c_Address      : Unsigned_8;
      Exti_Tag         : Unsigned_8;
      Alignment        : Unsigned_8;
      Custom_Alignment : Integer_16_List_3;
      Clk_In           : Unsigned_8;
   end record;
   type Gyro_Device_Config_Record_List_1 is array (0 .. 0) of Gyro_Device_Config_Record;
   type Max7456_Config_Record is record
      Clock_Config : Unsigned_8;
      Cs_Tag       : Unsigned_8;
      Spi_Device   : Unsigned_8;
      Pre_Init_Opu : Boolean;
   end record;
   type Mco_Config_Record is record
      Enabled : Unsigned_8;
      Source  : Unsigned_8;
      Divider : Unsigned_8;
   end record;
   type Mco_Config_Record_List_2 is array (0 .. 1) of Mco_Config_Record;
   type Motor_Dev_Config_Record is record
      Motor_Pwm_Rate            : Unsigned_16;
      Motor_Protocol            : Unsigned_8;
      Motor_Inversion           : Unsigned_8;
      Use_Continuous_Update     : Unsigned_8;
      Use_Burst_Dshot           : Unsigned_8;
      Use_Dshot_Telemetry       : Unsigned_8;
      Use_Dshot_Edt             : Unsigned_8;
      Io_Tags                   : Bytes_8;
      Motor_Transport_Protocol  : Unsigned_8;
      Use_Dshot_Bitbang         : Unsigned_8;
      Use_Dshot_Bitbanged_Timer : Unsigned_8;
      Motor_Output_Reordering   : Bytes_8;
   end record;
   type Motor_Config_Record is record
      Dev              : Motor_Dev_Config_Record;
      Motor_Idle       : Unsigned_16;
      Maxthrottle      : Unsigned_16;
      Mincommand       : Unsigned_16;
      Kv               : Unsigned_16;
      Motor_Pole_Count : Unsigned_8;
   end record;
   type Msp_Config_Record is record
      Half_Duplex : Unsigned_8;
      Msp_Uart    : Integer_8_List_3;
      Msp_Baud    : Bytes_3;
   end record;
   type Osd_Nav_Map_Config_Record is record
      Mode        : Unsigned_8;
      Centre      : Unsigned_8;
      Min_Scale_M : Unsigned_16;
   end record;
   type Bytes_17_List_4 is array (0 .. 3) of Bytes_17;
   type Pilot_Config_Record is record
      Craft_Name : Bytes_17;
      Pilot_Name : Bytes_17;
      Message    : Bytes_17_List_4;
   end record;
   type Pinio_Box_Config_Record is record
      Permanent_Id : Bytes_4;
   end record;
   type Pinio_Config_Record is record
      Io_Tag : Bytes_4;
      Config : Bytes_4;
   end record;
   type Pin_Pull_Up_Down_Config_Record is record
      Io_Tag : Unsigned_8;
   end record;
   type Pin_Pull_Up_Down_Config_Record_List_4 is array (0 .. 3) of Pin_Pull_Up_Down_Config_Record;
   type Pos_Hold_Config_Record is record
      Deadband                : Unsigned_8;
      Position_Source         : Unsigned_8;
      Opticalflow_Quality_Min : Unsigned_8;
      Opticalflow_Max_Range   : Unsigned_16;
   end record;
   type Rcdevice_Config_Record is record
      Init_Device_Attempts         : Unsigned_8;
      Init_Device_Attempt_Interval : Unsigned_32;
      Feature                      : Unsigned_32;
      Protocol_Version             : Unsigned_8;
      Rcdevice_Uart                : Integer_8;
   end record;
   type Rpm_Filter_Config_Record is record
      Rpm_Filter_Harmonics     : Unsigned_8;
      Rpm_Filter_Weights       : Bytes_3;
      Rpm_Filter_Min_Hz        : Unsigned_8;
      Rpm_Filter_Fade_Range_Hz : Unsigned_16;
      Rpm_Filter_Q             : Unsigned_16;
      Rpm_Filter_Lpf_Hz        : Unsigned_16;
   end record;
   type Rx_Config_Record is record
      Rcmap                             : Bytes_8;
      Serialrx_Provider                 : Unsigned_8;
      Serialrx_Inverted                 : Unsigned_8;
      Half_Duplex                       : Unsigned_8;
      Spektrum_Bind_Pin_Override_Io_Tag : Unsigned_8;
      Spektrum_Bind_Plug_Io_Tag         : Unsigned_8;
      Spektrum_Sat_Bind                 : Unsigned_8;
      Spektrum_Sat_Bind_Autoreset       : Unsigned_8;
      Rssi_Channel                      : Unsigned_8;
      Rssi_Scale                        : Unsigned_8;
      Rssi_Invert                       : Unsigned_8;
      Midrc                             : Unsigned_16;
      Mincheck                          : Unsigned_16;
      Maxcheck                          : Unsigned_16;
      Fpv_Cam_Angle_Degrees             : Unsigned_8;
      Air_Mode_Activate_Threshold       : Unsigned_8;
      Rx_Min_Usec                       : Unsigned_16;
      Rx_Max_Usec                       : Unsigned_16;
      Max_Aux_Channel                   : Unsigned_8;
      Rssi_Src_Frame_Errors             : Unsigned_8;
      Rssi_Offset                       : Integer_8;
      Rc_Smoothing                      : Unsigned_8;
      Rc_Smoothing_Setpoint_Cutoff      : Unsigned_8;
      Rc_Smoothing_Throttle_Cutoff      : Unsigned_8;
      Rc_Smoothing_Debug_Axis           : Unsigned_8;
      Rc_Smoothing_Auto_Factor_Rpy      : Unsigned_8;
      Rc_Smoothing_Auto_Factor_Throttle : Unsigned_8;
      Rssi_Src_Frame_Lpf_Period         : Unsigned_8;
      Rssi_Smoothing                    : Unsigned_8;
      Srxl2_Unit_Id                     : Unsigned_8;
      Srxl2_Baud_Fast                   : Unsigned_8;
      Sbus_Baud_Fast                    : Unsigned_8;
      Msp_Override_Channels_Mask        : Unsigned_32;
      Msp_Override_Failsafe             : Unsigned_8;
      Crsf_Use_Negotiated_Baud          : Unsigned_8;
      Rx_Uart                           : Integer_8;
   end record;
   type Pwm_Config_Record is record
      Io_Tags              : Bytes_8;
      Input_Filtering_Mode : Unsigned_8;
   end record;
   type Ppm_Config_Record is record
      Io_Tag : Unsigned_8;
   end record;
   subtype Bytes_50 is Bytes (0 .. 49);
   type Rx_Cc2500_Spi_Config_Record is record
      Auto_Bind           : Unsigned_8;
      Bind_Tx_Id          : Bytes_3;
      Bind_Offset         : Integer_8;
      Bind_Hop_Data       : Bytes_50;
      Rx_Num              : Unsigned_8;
      A1_Source           : Unsigned_8;
      Chip_Detect_Enabled : Unsigned_8;
      Tx_En_Io_Tag        : Unsigned_8;
      Lna_En_Io_Tag       : Unsigned_8;
      Ant_Sel_Io_Tag      : Unsigned_8;
   end record;
   type Rx_Express_Lrs_Spi_Config_Record is record
      Reset_Io_Tag : Unsigned_8;
      Busy_Io_Tag  : Unsigned_8;
      Uid          : Bytes_6;
      Domain       : Unsigned_8;
      Rate_Index   : Unsigned_8;
      Model_Id     : Unsigned_8;
   end record;
   type Rx_Spi_Config_Record is record
      Rx_Spi_Protocol         : Unsigned_8;
      Rx_Spi_Id               : Unsigned_32;
      Rx_Spi_Rf_Channel_Count : Unsigned_8;
      Csn_Tag                 : Unsigned_8;
      Spibus                  : Unsigned_8;
      Bind_Io_Tag             : Unsigned_8;
      Led_Io_Tag              : Unsigned_8;
      Led_Inversion           : Unsigned_8;
      Exti_Io_Tag             : Unsigned_8;
   end record;
   type Scheduler_Config_Record is record
      Rx_Relax_Determinism      : Unsigned_16;
      Osd_Relax_Determinism     : Unsigned_16;
      Cpu_Late_Percentage_Limit : Unsigned_16;
      Debug_Task                : Unsigned_8;
   end record;
   type Sdcard_Config_Record is record
      Device               : Integer_8;
      Card_Detect_Tag      : Unsigned_8;
      Chip_Select_Tag      : Unsigned_8;
      Card_Detect_Inverted : Unsigned_8;
      Mode                 : Unsigned_8;
   end record;
   type Serial_Uart_Config_Record is record
      Tx_Dmaopt : Integer_8;
      Rx_Dmaopt : Integer_8;
   end record;
   type Serial_Uart_Config_Record_List_6 is array (0 .. 5) of Serial_Uart_Config_Record;
   type Stats_Config_Record is record
      Stats_Total_Flights    : Unsigned_32;
      Stats_Total_Time_S     : Unsigned_32;
      Stats_Total_Dist_M     : Unsigned_32;
      Stats_Min_Armed_Time_S : Integer_8;
      Stats_Mah_Used         : Unsigned_32;
      Stats_Save_Move_Limit  : Unsigned_8;
   end record;
   type Timer_Io_Config_Record is record
      Io_Tag : Unsigned_8;
      Index  : Unsigned_8;
      Dmaopt : Integer_8;
   end record;
   type Timer_Io_Config_Record_List_21 is array (0 .. 20) of Timer_Io_Config_Record;
   type Usb_Dev_Record is record
      Type_Value            : Unsigned_8;
      Msc_Button_Pin        : Unsigned_8;
      Msc_Button_Use_Pullup : Unsigned_8;
      Detect_Pin            : Unsigned_8;
   end record;
   type Vcd_Profile_Record is record
      Video_System : Unsigned_8;
      H_Offset     : Integer_8;
      V_Offset     : Integer_8;
   end record;
   type Vtx_Io_Config_Record is record
      Cs_Tag     : Unsigned_8;
      Power_Tag  : Unsigned_8;
      Data_Tag   : Unsigned_8;
      Clock_Tag  : Unsigned_8;
      Spi_Device : Unsigned_8;
   end record;
   subtype Unsigned_16_List_8 is Unsigned_16_List (0 .. 7);
   type Unsigned_16_List_8_List_8 is array (0 .. 7) of Unsigned_16_List_8;
   type Bytes_9_List_8 is array (0 .. 7) of Bytes_9;
   subtype Bytes_2 is Bytes (0 .. 1);
   type Bytes_2_List_8 is array (0 .. 7) of Bytes_2;
   subtype Boolean_List_8 is Boolean_List (0 .. 7);
   type Bytes_4_List_8 is array (0 .. 7) of Bytes_4;
   type Vtx_Table_Config_Record is record
      Bands           : Unsigned_8;
      Channels        : Unsigned_8;
      Frequency       : Unsigned_16_List_8_List_8;
      Band_Names      : Bytes_9_List_8;
      Band_Letters    : Bytes_8;
      Channel_Names   : Bytes_2_List_8;
      Is_Factory_Band : Boolean_List_8;
      Power_Levels    : Unsigned_8;
      Power_Values    : Unsigned_16_List_8;
      Power_Labels    : Bytes_4_List_8;
   end record;
   type Fly_Sky_Config_Record is record
      Tx_Id          : Unsigned_32;
      Rf_Channel_Map : Bytes_16;
   end record;
   type Spektrum_Config_Record is record
      Protocol     : Unsigned_8;
      Mfg_Id       : Bytes_4;
      Num_Channels : Unsigned_8;
   end record;
   type Rx_Channel_Range_Config_Record is record
      Min : Unsigned_16;
      Max : Unsigned_16;
   end record;
   type Rx_Channel_Range_Config_Record_List_4 is array (0 .. 3) of Rx_Channel_Range_Config_Record;
   type Rx_Failsafe_Channel_Config_Record is record
      Mode : Unsigned_8;
      Step : Unsigned_8;
   end record;
   type Rx_Failsafe_Channel_Config_Record_List_18 is array (0 .. 17) of Rx_Failsafe_Channel_Config_Record;
   subtype Integer_16_List_4 is Integer_16_List (0 .. 3);
   subtype Integer_16_List_2 is Integer_16_List (0 .. 1);
   type Accelerometer_Config_Record is record
      Acc_Lpf_Hz          : Unsigned_16;
      Acc_Hardware        : Unsigned_8;
      Acc_High_Fsr        : Boolean;
      Acc_Zero            : Integer_16_List_4;
      Accelerometer_Trims : Integer_16_List_2;
   end record;
   type Barometer_Config_Record is record
      Baro_Bus_Type              : Unsigned_8;
      Baro_Spi_Device            : Unsigned_8;
      Baro_Spi_Csn               : Unsigned_8;
      Baro_I2c_Device            : Unsigned_8;
      Baro_I2c_Address           : Unsigned_8;
      Baro_Hardware              : Unsigned_8;
      Baro_Eoc_Tag               : Unsigned_8;
      Baro_Xclr_Tag              : Unsigned_8;
      Baro_Temp_Drift_Cm_Per10_C : Integer_16;
   end record;
   type Battery_Profile_Record is record
      Vbatmaxcellvoltage             : Unsigned_16;
      Vbatmincellvoltage             : Unsigned_16;
      Vbatwarningcellvoltage         : Unsigned_16;
      Vbatfullcellvoltage            : Unsigned_16;
      Battery_Capacity               : Unsigned_16;
      Force_Battery_Cell_Count       : Unsigned_8;
      Consumption_Warning_Percentage : Unsigned_8;
      Profile_Name                   : Bytes_9;
   end record;
   type Battery_Profile_Record_List_3 is array (0 .. 2) of Battery_Profile_Record;
   type Battery_Config_Record is record
      Vbatnotpresentcellvoltage   : Unsigned_16;
      Lvc_Percentage              : Unsigned_8;
      Voltage_Meter_Source        : Unsigned_8;
      Current_Meter_Source        : Unsigned_8;
      Use_V_Bat_Alerts            : Boolean;
      Use_Consumption_Alerts      : Boolean;
      Vbathysteresis              : Unsigned_8;
      Vbat_Display_Lpf_Period     : Unsigned_8;
      Ibat_Lpf_Period             : Unsigned_8;
      Vbat_Duration_For_Warning   : Unsigned_8;
      Vbat_Duration_For_Critical  : Unsigned_8;
      Vbat_Sag_Lpf_Period         : Unsigned_8;
      Is_Battery_Continue_Enabled : Boolean;
   end record;
   type Board_Alignment_Record is record
      Roll_Degrees  : Integer_32;
      Pitch_Degrees : Integer_32;
      Yaw_Degrees   : Integer_32;
   end record;
   type Compass_Config_Record is record
      Mag_Alignment        : Unsigned_8;
      Mag_Hardware         : Unsigned_8;
      Mag_Bus_Type         : Unsigned_8;
      Mag_I2c_Device       : Unsigned_8;
      Mag_I2c_Address      : Unsigned_8;
      Mag_Spi_Device       : Unsigned_8;
      Mag_Spi_Csn          : Unsigned_8;
      Interrupt_Tag        : Unsigned_8;
      Mag_Zero             : Integer_16_List_4;
      Mag_Custom_Alignment : Integer_16_List_3;
   end record;
   type Current_Sensor_Adc_Config_Record is record
      Scale  : Integer_16;
      Offset : Integer_16;
   end record;
   type Current_Sensor_Virtual_Config_Record is record
      Scale  : Integer_16;
      Offset : Unsigned_16;
   end record;
   type Esc_Sensor_Config_Record is record
      Half_Duplex     : Unsigned_8;
      Offset          : Unsigned_16;
      Esc_Sensor_Uart : Integer_8;
   end record;
   type Gyro_Config_Record is record
      Gyro_Movement_Calibration_Threshold : Unsigned_8;
      Gyro_Hardware_Lpf                   : Unsigned_8;
      Gyro_High_Fsr                       : Unsigned_8;
      Gyro_Lpf1_Static_Hz                 : Unsigned_16;
      Gyro_Lpf2_Static_Hz                 : Unsigned_16;
      Gyro_Soft_Notch_Hz_1                : Unsigned_16;
      Gyro_Soft_Notch_Cutoff_1            : Unsigned_16;
      Gyro_Soft_Notch_Hz_2                : Unsigned_16;
      Gyro_Soft_Notch_Cutoff_2            : Unsigned_16;
      Gyro_Offset_Yaw                     : Integer_16;
      Check_Overflow                      : Unsigned_8;
      Gyro_Lpf1_Type                      : Unsigned_8;
      Gyro_Lpf2_Type                      : Unsigned_8;
      Yaw_Spin_Recovery                   : Unsigned_8;
      Yaw_Spin_Threshold                  : Integer_16;
      Gyro_Calibration_Duration           : Unsigned_16;
      Gyro_Lpf1_Dyn_Min_Hz                : Unsigned_16;
      Gyro_Lpf1_Dyn_Max_Hz                : Unsigned_16;
      Gyro_Filter_Debug_Axis              : Unsigned_8;
      Gyros_Detected                      : Unsigned_8;
      Gyro_Lpf1_Dyn_Expo                  : Unsigned_8;
      Simplified_Gyro_Filter              : Unsigned_8;
      Simplified_Gyro_Filter_Multiplier   : Unsigned_8;
      Gyro_Enabled_Bitmask                : Unsigned_8;
   end record;
   type Opticalflow_Config_Record is record
      Opticalflow_Hardware : Unsigned_8;
      Rotation             : Unsigned_16;
      Flip_X               : Unsigned_8;
      Opticalflow_Uart     : Integer_8;
   end record;
   type Pitot_Config_Record is record
      Pitot_Bus_Type    : Unsigned_8;
      Pitot_I2c_Device  : Unsigned_8;
      Pitot_I2c_Address : Unsigned_8;
      Pitot_Hardware    : Unsigned_8;
   end record;
   type Rangefinder_Config_Record is record
      Rangefinder_Hardware : Unsigned_8;
      Rangefinder_Uart     : Integer_8;
   end record;
   type Sonar_Config_Record is record
      Trigger_Tag : Unsigned_8;
      Echo_Tag    : Unsigned_8;
   end record;
   type Voltage_Sensor_Adc_Config_Record is record
      Vbatscale            : Unsigned_8;
      Vbatresdivval        : Unsigned_8;
      Vbatresdivmultiplier : Unsigned_8;
   end record;
   type Voltage_Sensor_Adc_Config_Record_List_1 is array (0 .. 0) of Voltage_Sensor_Adc_Config_Record;
   subtype Bytes_15 is Bytes (0 .. 14);
   type Telemetry_Provider_Record is record
      Protocol : Unsigned_8;
      Uart     : Integer_8;
      Baud     : Unsigned_8;
   end record;
   type Telemetry_Provider_Record_List_3 is array (0 .. 2) of Telemetry_Provider_Record;
   type Telemetry_Config_Record is record
      Gps_No_Fix_Latitude            : Integer_16;
      Gps_No_Fix_Longitude           : Integer_16;
      Telemetry_Inverted             : Unsigned_8;
      Half_Duplex                    : Unsigned_8;
      Frsky_Coordinate_Format        : Unsigned_8;
      Frsky_Unit                     : Unsigned_8;
      Frsky_Vfas_Precision           : Unsigned_8;
      Hott_Alarm_Sound_Interval      : Unsigned_8;
      Pid_Values_As_Telemetry        : Unsigned_8;
      Report_Cell_Voltage            : Unsigned_8;
      Flysky_Sensors                 : Bytes_15;
      Mavlink_Mah_As_Heading_Divisor : Unsigned_16;
      Disabled_Sensors               : Unsigned_32;
      Mavlink_Min_Txbuff             : Unsigned_8;
      Mavlink_Extended_Status_Rate   : Unsigned_8;
      Mavlink_Rc_Channels_Rate       : Unsigned_8;
      Mavlink_Position_Rate          : Unsigned_8;
      Mavlink_Extra1_Rate            : Unsigned_8;
      Mavlink_Extra2_Rate            : Unsigned_8;
      Mavlink_Extra3_Rate            : Unsigned_8;
      Crsf_Tlm_Accgyro               : Unsigned_8;
      Providers                      : Telemetry_Provider_Record_List_3;
   end record;

   type Configuration is record
      Blackbox_Config               : Blackbox_Config_Record;
      Time_Config                   : Time_Config_Record;
      System_Config                 : System_Config_Record;
      Feature_Config                : Feature_Config_Record;
      Camera_Control_Config         : Camera_Control_Config_Record;
      Status_Led_Config             : Status_Led_Config_Record;
      Serial_Pin_Config             : Serial_Pin_Config_Record;
      Esc_Serial_Config             : Esc_Serial_Config_Record;
      Control_Rate_Profiles         : Control_Rate_Config_Record_List_4;
      Throttle_Correction_Config    : Throttle_Correction_Config_Record;
      Adjustment_Ranges             : Adjustment_Range_Record_List_30;
      Rc_Controls_Config            : Rc_Controls_Config_Record;
      Arming_Config                 : Arming_Config_Record;
      Flight3_D_Config              : Flight3_D_Config_Record;
      Mode_Activation_Conditions    : Mode_Activation_Condition_Record_List_20;
      Mode_Activation_Config        : Mode_Activation_Config_Record;
      Failsafe_Config               : Failsafe_Config_Record;
      Imu_Config                    : Imu_Config_Record;
      Mixer_Config                  : Mixer_Config_Record;
      Custom_Motor_Mixer            : Motor_Mixer_Record_List_8;
      Tricopter_Mixer_Config        : Tricopter_Mixer_Config_Record;
      Pid_Config                    : Pid_Config_Record;
      Pid_Profiles                  : Pid_Profile_Record_List_4;
      Position_Config               : Position_Config_Record;
      Servo_Config                  : Servo_Config_Record;
      Custom_Servo_Mixers           : Servo_Mixer_Record_List_16;
      Servo_Params                  : Servo_Param_Record_List_8;
      Gimbal_Config                 : Gimbal_Config_Record;
      Led_Strip_Config              : Led_Strip_Config_Record;
      Led_Strip_Status_Mode_Config  : Led_Strip_Status_Mode_Config_Record;
      Serial_Config                 : Serial_Config_Record;
      Transponder_Config            : Transponder_Config_Record;
      Vtx_Config                    : Vtx_Config_Record;
      Vtx_Settings_Config           : Vtx_Settings_Config_Record;
      Osd_Custom_Text_Config        : Osd_Custom_Text_Config_Record;
      Osd_Config                    : Osd_Config_Record;
      Osd_Element_Config            : Osd_Element_Config_Record;
      Adc_Config                    : Adc_Config_Record;
      Alt_Hold_Config               : Alt_Hold_Config_Record;
      Autopilot_Config              : Autopilot_Config_Record;
      Beeper_Dev_Config             : Beeper_Dev_Config_Record;
      Beeper_Config                 : Beeper_Config_Record;
      Board_Config                  : Board_Config_Record;
      I2c_Config                    : I2c_Config_Record_List_3;
      Spi_Pin_Config                : Spi_Pin_Config_Record_List_3;
      Dashboard_Config              : Dashboard_Config_Record;
      Display_Port_Profile_Msp      : Display_Port_Profile_Record;
      Display_Port_Profile_Max7456  : Display_Port_Profile_Record;
      Dyn_Notch_Config              : Dyn_Notch_Config_Record;
      Flash_Config                  : Flash_Config_Record;
      Flight_Plan_Config            : Flight_Plan_Config_Record;
      Gimbal_Track_Config           : Gimbal_Track_Config_Record;
      Gps_Lap_Timer_Config          : Gps_Lap_Timer_Config_Record;
      Gps_Config                    : Gps_Config_Record;
      Gps_Rescue_Config             : Gps_Rescue_Record;
      Gyro_Device_Config            : Gyro_Device_Config_Record_List_1;
      Max7456_Config                : Max7456_Config_Record;
      Mco_Config                    : Mco_Config_Record_List_2;
      Motor_Config                  : Motor_Config_Record;
      Msp_Config                    : Msp_Config_Record;
      Osd_Nav_Map_Config            : Osd_Nav_Map_Config_Record;
      Pilot_Config                  : Pilot_Config_Record;
      Pinio_Box_Config              : Pinio_Box_Config_Record;
      Pinio_Config                  : Pinio_Config_Record;
      Pin_Pullup_Config             : Pin_Pull_Up_Down_Config_Record_List_4;
      Pin_Pulldown_Config           : Pin_Pull_Up_Down_Config_Record_List_4;
      Pos_Hold_Config               : Pos_Hold_Config_Record;
      Rcdevice_Config               : Rcdevice_Config_Record;
      Rpm_Filter_Config             : Rpm_Filter_Config_Record;
      Rx_Config                     : Rx_Config_Record;
      Pwm_Config                    : Pwm_Config_Record;
      Ppm_Config                    : Ppm_Config_Record;
      Rx_Cc2500_Spi_Config          : Rx_Cc2500_Spi_Config_Record;
      Rx_Express_Lrs_Spi_Config     : Rx_Express_Lrs_Spi_Config_Record;
      Rx_Spi_Config                 : Rx_Spi_Config_Record;
      Scheduler_Config              : Scheduler_Config_Record;
      Sdcard_Config                 : Sdcard_Config_Record;
      Serial_Uart_Config            : Serial_Uart_Config_Record_List_6;
      Stats_Config                  : Stats_Config_Record;
      Timer_Io_Config               : Timer_Io_Config_Record_List_21;
      Usb_Dev_Config                : Usb_Dev_Record;
      Vcd_Profile                   : Vcd_Profile_Record;
      Vtx_Io_Config                 : Vtx_Io_Config_Record;
      Vtx_Table_Config              : Vtx_Table_Config_Record;
      Fly_Sky_Config                : Fly_Sky_Config_Record;
      Spektrum_Config               : Spektrum_Config_Record;
      Rx_Channel_Range_Configs      : Rx_Channel_Range_Config_Record_List_4;
      Rx_Failsafe_Channel_Configs   : Rx_Failsafe_Channel_Config_Record_List_18;
      Accelerometer_Config          : Accelerometer_Config_Record;
      Barometer_Config              : Barometer_Config_Record;
      Battery_Profiles              : Battery_Profile_Record_List_3;
      Battery_Config                : Battery_Config_Record;
      Board_Alignment               : Board_Alignment_Record;
      Compass_Config                : Compass_Config_Record;
      Current_Sensor_Adc_Config     : Current_Sensor_Adc_Config_Record;
      Current_Sensor_Virtual_Config : Current_Sensor_Virtual_Config_Record;
      Esc_Sensor_Config             : Esc_Sensor_Config_Record;
      Gyro_Config                   : Gyro_Config_Record;
      Opticalflow_Config            : Opticalflow_Config_Record;
      Pitot_Config                  : Pitot_Config_Record;
      Rangefinder_Config            : Rangefinder_Config_Record;
      Sonar_Config                  : Sonar_Config_Record;
      Voltage_Sensor_Adc_Config     : Voltage_Sensor_Adc_Config_Record_List_1;
      Telemetry_Config              : Telemetry_Config_Record;
   end record;

   Defaults : constant Configuration;

   --  The profiles a setting has: one for a setting outside the profiles.
   function Profile_Count (S : Setting) return Positive is
     (case S is
        when Battery_Profile_Name | Bat_Capacity | Vbat_Max_Cell_Voltage | Vbat_Full_Cell_Voltage |
          Vbat_Min_Cell_Voltage | Vbat_Warning_Cell_Voltage | Cbat_Alert_Percent | Force_Battery_Cell_Count => 3,
        when Rateprofile_Name | Thr_Mid | Thr_Expo | Thr_Hover | Rates_Type | Quickrates_Rc_Expo | Roll_Rc_Rate |
          Pitch_Rc_Rate | Yaw_Rc_Rate | Roll_Expo | Pitch_Expo | Yaw_Expo | Roll_Srate | Pitch_Srate | Yaw_Srate |
          Throttle_Limit_Type | Throttle_Limit_Percent | Roll_Rate_Limit | Pitch_Rate_Limit | Yaw_Rate_Limit |
          Profile_Name | Dterm_Lpf1_Dyn_Min_Hz | Dterm_Lpf1_Dyn_Max_Hz | Dterm_Lpf1_Dyn_Expo | Dterm_Lpf1_Type |
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
          Ez_Landing_Speed | Landing_Disarm_Threshold => 4,
        when others => 1);

   --  The values an array setting holds: one for the others.
   subtype Element_Count_Value is Positive range 1 .. 50;
   function Element_Count (S : Setting) return Element_Count_Value is
     (case S is
        when Acc_Calibration => 4,
        when Mag_Calibration => 3,
        when Motor_Output_Reordering => 8,
        when Ibus_Sensor => 15,
        when Transponder_Data => 9,
        when Osd_Rcchannels => 4,
        when Displayport_Msp_Fonts => 4,
        when Frsky_Spi_Tx_Id => 3,
        when Frsky_Spi_Bind_Hop_Data => 50,
        when Camera_Control_Button_Resistance => 5,
        when Pinio_Config => 4,
        when Pinio_Box => 4,
        when Spektrum_Spi_Mfg_Id => 4,
        when Expresslrs_Uid => 6,
        when Rpm_Filter_Weights => 3,
        when Flysky_Spi_Rf_Channels => 16,
        when others => 1);

   --  A setting's value: a bit setting's bit, an array setting's element,
   --  zero for a text setting.
   function Get (C : Configuration; S : Setting; Profile : Natural := 0; Index : Natural := 0)
     return Integer_64
     with Pre => Profile < Profile_Count (S) and then Index < Element_Count (S);

   --  The values a setting's type holds: its bit or flag for a bit or flag setting.
   function Lowest (S : Setting) return Integer_64;
   function Highest (S : Setting) return Integer_64;

   --  Writes a setting's value as the reference's command line writes it: the
   --  value truncated to the field's width, a bit setting's bit, an array
   --  setting's element, a profile setting's profile; text settings keep
   --  their characters. A value between Lowest and Highest reads back.
   procedure Set (C : in out Configuration; S : Setting; Value : Integer_64; Profile : Natural := 0;
                  Index : Natural := 0)
     with Pre => Profile < Profile_Count (S) and then Index < Element_Count (S);

   --  A text setting's characters before the first zero, empty for the others.
   function Get_Text (C : Configuration; S : Setting; Profile : Natural := 0) return String
     with Pre => Profile < Profile_Count (S);

   --  Writes a text setting as the command line writes it: the setting's
   --  longest length of bytes cleared, then the text, cut at that length.
   procedure Set_Text (C : in out Configuration; S : Setting; Text : String; Profile : Natural := 0)
     with Pre => Profile < Profile_Count (S);

private

   Defaults : constant Configuration :=
     (Blackbox_Config => (Fields_Disabled_Mask => 0, Sample_Rate => 2, Device => 0, Mode => 0, High_Resolution => 0,
     Blackbox_Uart => -1, Blackbox_Baud => 5),  Time_Config => (Tz_Offset_Minutes => 0),  System_Config =>
     (Pid_Profile_Index => 0, Active_Rate_Profile => 0, Debug_Mode => 0, Task_Statistics => 1,
     Rate_Profile6_Pos_Switch => 0, Cpu_Overclock => 0, Power_On_Arming_Grace_Time => 5, Board_Identifier => (70, 52,
     48, 53, 0, 0), Hse_Mhz => 0, Configuration_State => 0, Enable_Stick_Arming => 0, Active_Battery_Profile => 0),
     Feature_Config => (Enabled_Features => 272629768),  Camera_Control_Config => (Mode => 0, Ref_Voltage => 330,
     Key_Delay_Ms => 180, Internal_Resistance => 470, Io_Tag => 41, Inverted => 0, Button_Resistance_Values => (450,
     270, 150, 68, 0)),  Status_Led_Config => (Io_Tags => (others => 0), Inversion => 0),  Serial_Pin_Config =>
     (Io_Tag_Tx => (others => 0), Io_Tag_Rx => (others => 0), Io_Tag_Inverter => (others => 0)),  Esc_Serial_Config
     => (Io_Tag => 0),  Control_Rate_Profiles => (others => (Thr_Mid8 => 50, Thr_Expo8 => 0, Rates_Type => 3,
     Rc_Rates => (others => 7), Rc_Expo => (others => 0), Rates => (others => 67), Throttle_Limit_Type => 0,
     Throttle_Limit_Percent => 100, Rate_Limit => (others => 1998), Profile_Name => (others => 0),
     Quick_Rates_Rc_Expo => 0, Thr_Hover8 => 50)),  Throttle_Correction_Config => (Throttle_Correction_Angle => 800,
     Throttle_Correction_Value => 0),  Adjustment_Ranges => (others => (Aux_Channel_Index => 0, Range_Value =>
     (Start_Step => 0, End_Step => 0), Adjustment_Config => 0, Aux_Switch_Channel_Index => 0, Adjustment_Center => 0,
     Adjustment_Scale => 0)),  Rc_Controls_Config => (Deadband => 0, Yaw_Deadband => 0, Yaw_Control_Reversed =>
     False),  Arming_Config => (Gyro_Cal_On_First_Arm => 0, Auto_Disarm_Delay => 5, Prearm_Allow_Rearm => 0),
     Flight3_D_Config => (Deadband3d_Low => 1406, Deadband3d_High => 1514, Neutral3d => 1460, Deadband3d_Throttle =>
     50, Limit3d_Low => 1000, Limit3d_High => 2000, Switched_Mode3d => 0),  Mode_Activation_Conditions => (others =>
     (Mode_Id => 0, Aux_Channel_Index => 0, Range_Value => (Start_Step => 0, End_Step => 0), Mode_Logic => 0,
     Linked_To => 0)),  Mode_Activation_Config => (Box_User_Names => (others => (others => 0))),  Failsafe_Config =>
     (Failsafe_Throttle => 1000, Failsafe_Throttle_Low_Delay => 100, Failsafe_Delay => 15, Failsafe_Landing_Time =>
     60, Failsafe_Switch_Mode => 0, Failsafe_Procedure => 1, Failsafe_Recovery_Delay => 5, Failsafe_Stick_Threshold
     => 30),  Imu_Config => (Imu_Dcm_Kp => 2500, Imu_Dcm_Ki => 0, Small_Angle => 25, Imu_Process_Denom => 2,
     Mag_Declination => 0),  Mixer_Config => (Mixer_Mode => 3, Yaw_Motors_Reversed => False, Crashflip_Motor_Percent
     => 0, Crashflip_Rate => 0, Crashflip_Auto_Rearm => False, Mixer_Type => 0, Rpm_Limit => False, Rpm_Limit_P =>
     25, Rpm_Limit_I => 10, Rpm_Limit_D => 8, Rpm_Limit_Value => 18000),  Custom_Motor_Mixer => (others => (Throttle
     => 0.0, Roll => 0.0, Pitch => 0.0, Yaw => 0.0)),  Tricopter_Mixer_Config => (Dummy => 0),  Pid_Config =>
     (Pid_Process_Denom => 1, Runaway_Takeoff_Prevention => 1, Runaway_Takeoff_Deactivate_Delay => 500,
     Runaway_Takeoff_Deactivate_Throttle => 20),  Pid_Profiles => (others => (Yaw_Lowpass_Hz => 100,
     Dterm_Lpf1_Static_Hz => 75, Dterm_Notch_Hz => 0, Dterm_Notch_Cutoff => 0, Pid => ((P => 45, I => 80, D => 30, F
     => 120, S => 0), (P => 47, I => 84, D => 34, F => 125, S => 0), (P => 45, I => 80, D => 0, F => 120, S => 0), (P
     => 50, I => 75, D => 75, F => 50, S => 0), (P => 40, I => 0, D => 0, F => 0, S => 0)), Dterm_Lpf1_Type => 0,
     Iterm_Windup => 80, Pid_Sum_Limit => 500, Pid_Sum_Limit_Yaw => 400, Pid_At_Min_Throttle => 1, Angle_Limit => 60,
     Horizon_Limit_Degrees => 135, Horizon_Ignore_Sticks => 0, Anti_Gravity_Gain => 80, Yaw_Rate_Accel_Limit => 0,
     Rate_Accel_Limit => 0, Crash_Dthreshold => 50, Crash_Gthreshold => 400, Crash_Setpoint_Threshold => 350,
     Crash_Time => 500, Crash_Delay => 0, Crash_Recovery_Angle => 10, Crash_Recovery_Rate => 100, Crash_Limit_Yaw =>
     200, Iterm_Limit => 400, Dterm_Lpf2_Static_Hz => 150, Crash_Recovery => 0, Throttle_Boost => 5,
     Throttle_Boost_Cutoff => 15, Iterm_Rotation => 0, Iterm_Relax_Type => 1, Iterm_Relax_Cutoff => 15, Iterm_Relax
     => 1, Acro_Trainer_Angle_Limit => 20, Acro_Trainer_Debug_Axis => 0, Acro_Trainer_Gain => 75,
     Acro_Trainer_Lookahead_Ms => 50, Dterm_Lpf2_Type => 0, Dterm_Lpf1_Dyn_Min_Hz => 75, Dterm_Lpf1_Dyn_Max_Hz =>
     150, Launch_Control_Mode => 1, Launch_Control_Throttle_Percent => 20, Launch_Control_Angle_Limit => 0,
     Launch_Control_Gain => 40, Launch_Control_Allow_Trigger_Reset => 1, Thrust_Linearization => 0, D_Max => (40, 46,
     0), D_Max_Gain => 0, D_Max_Advance => 35, Motor_Output_Limit => 100, Auto_Profile_Cell_Count => 0, Profile_Name
     => (others => 0), Dyn_Idle_Min_Rpm => 0, Dyn_Idle_P_Gain => 50, Dyn_Idle_I_Gain => 50, Dyn_Idle_D_Gain => 50,
     Dyn_Idle_Max_Increase => 150, Feedforward_Transition => 0, Feedforward_Averaging => 1, Feedforward_Smooth_Factor
     => 65, Feedforward_Jitter_Factor => 7, Feedforward_Boost => 15, Feedforward_Max_Rate_Limit => 90,
     Feedforward_Yaw_Hold_Gain => 15, Feedforward_Yaw_Hold_Time => 100, Dterm_Lpf1_Dyn_Expo => 5, Level_Race_Mode =>
     0, Vbat_Sag_Compensation => 0, Simplified_Pids_Mode => 2, Simplified_Master_Multiplier => 100,
     Simplified_Roll_Pitch_Ratio => 100, Simplified_I_Gain => 100, Simplified_D_Gain => 100, Simplified_Pi_Gain =>
     100, Simplified_D_Max_Gain => 100, Simplified_Feedforward_Gain => 100, Simplified_Dterm_Filter => 1,
     Simplified_Dterm_Filter_Multiplier => 100, Simplified_Pitch_Pi_Gain => 100, Anti_Gravity_Cutoff_Hz => 5,
     Anti_Gravity_P_Gain => 100, Tpa_Mode => 1, Tpa_Rate => 65, Tpa_Breakpoint => 1350,
     Angle_Feedforward_Smoothing_Ms => 80, Angle_Earth_Ref => 100, Horizon_Delay_Ms => 500, Tpa_Low_Rate => 20,
     Tpa_Low_Breakpoint => 1050, Tpa_Low_Always => 0, Ez_Landing_Threshold => 25, Ez_Landing_Limit => 15,
     Ez_Landing_Speed => 50, Landing_Disarm_Threshold => 0, Spa_Center => (others => 0), Spa_Width => (others => 0),
     Spa_Mode => (others => 0), Tpa_Curve_Type => 0, Tpa_Curve_Stall_Throttle => 30, Tpa_Curve_Pid_Thr0 => 200,
     Tpa_Curve_Pid_Thr100 => 70, Tpa_Curve_Expo => 20, Tpa_Speed_Type => 0, Tpa_Speed_Basic_Delay => 1000,
     Tpa_Speed_Basic_Gravity => 50, Tpa_Speed_Adv_Prop_Pitch => 370, Tpa_Speed_Adv_Mass => 1000, Tpa_Speed_Adv_Drag_K
     => 1000, Tpa_Speed_Adv_Thrust => 2000, Tpa_Speed_Max_Voltage => 2520, Tpa_Speed_Pitch_Offset => 0, Yaw_Type =>
     0, Angle_Pitch_Offset => 0, Chirp_Lag_Freq_Hz => 3, Chirp_Lead_Freq_Hz => 30, Chirp_Amplitude_Roll => 230,
     Chirp_Amplitude_Pitch => 230, Chirp_Amplitude_Yaw => 180, Chirp_Frequency_Start_Deci_Hz => 2,
     Chirp_Frequency_End_Deci_Hz => 6000, Chirp_Time_Seconds => 20, Chirp_Repeat => 1)),  Position_Config =>
     (Altitude_Source => 0, Altitude_Prefer_Baro => 50, Altitude_Lpf => 300, Altitude_D_Lpf => 300,
     Rangefinder_Max_Range_Cm => 400),  Servo_Config => (Dev => (Servo_Center_Pulse => 1500, Servo_Pwm_Rate => 50,
     Io_Tags => (others => 0)), Servo_Lowpass_Freq => 0, Tri_Unarmed_Servo => 1, Channel_Forwarding_Start_Channel =>
     4),  Custom_Servo_Mixers => (others => (Target_Channel => 0, Input_Source => 0, Rate => 0, Speed => 0, Min => 0,
     Max => 0, Box => 0)),  Servo_Params => (others => (Reversed_Sources => 0, Min => 1000, Max => 2000, Middle =>
     1500, Rate => 100, Forward_From_Channel => -1)),  Gimbal_Config => (Mode => 0),  Led_Strip_Config =>
     (Ledstrip_Visual_Beeper => 1, Io_Tag => 0, Ledstrip_Grb_Rgb => 0, Ledstrip_Profile => 2, Ledstrip_Race_Color =>
     3, Ledstrip_Beacon_Color => 1, Ledstrip_Beacon_Period_Ms => 500, Ledstrip_Beacon_Percent => 50,
     Ledstrip_Beacon_Armed_Only => 0, Ledstrip_Visual_Beeper_Color => 1, Ledstrip_Brightness => 100,
     Ledstrip_Rainbow_Delta => 0, Ledstrip_Rainbow_Freq => 120),  Led_Strip_Status_Mode_Config => (Led_Configs =>
     (others => 0), Colors => ((H => 0, S => 0, V => 0), (H => 0, S => 255, V => 255), (H => 0, S => 0, V => 255), (H
     => 15, S => 0, V => 255), (H => 50, S => 0, V => 255), (H => 100, S => 0, V => 255), (H => 115, S => 0, V =>
     255), (H => 125, S => 0, V => 255), (H => 180, S => 0, V => 255), (H => 210, S => 0, V => 255), (H => 240, S =>
     0, V => 255), (H => 270, S => 0, V => 255), (H => 300, S => 0, V => 255), (H => 330, S => 0, V => 255), (H => 0,
     S => 0, V => 0), (H => 0, S => 0, V => 0)), Mode_Colors => ((Color => (1, 11, 2, 13, 10, 3)), (Color => (5, 11,
     3, 13, 10, 3)), (Color => (10, 11, 4, 13, 10, 3)), (Color => (8, 11, 4, 13, 10, 3)), (Color => (7, 11, 3, 13,
     10, 3)), (Color => (others => 0))), Special_Colors => (Color => (6, 10, 1, 0, 0, 2, 3, 6, 0, 0, 0)),
     Ledstrip_Aux_Channel => 3),  Serial_Config => (Serial_Update_Rate_Hz => 100, Reboot_Character => 82),
     Transponder_Config => (Provider => 1, Reserved => 0, Data => (18, 52, 86, 120, 154, 188, 0, 0, 0), Io_Tag => 0),
     Vtx_Config => (Vtx_Channel_Activation_Conditions => (others => (Aux_Channel_Index => 0, Band => 0, Channel => 0,
     Power => 0, Range_Value => (Start_Step => 0, End_Step => 0))), Half_Duplex => 1),  Vtx_Settings_Config => (Band
     => 0, Channel => 0, Power => 0, Freq => 0, Pit_Mode_Freq => 0, Low_Power_Disarm => 0, Softserial_Alt => 0,
     Vtx_Type => 0, Vtx_Uart => -1),  Osd_Custom_Text_Config => (Terminator => 1),  Osd_Config => (Cap_Alarm => 2200,
     Alt_Alarm => 100, Rssi_Alarm => 20, Units => 1, Timers => (2560, 2561), Enabled_Warnings => 921599, Ah_Max_Pitch
     => 20, Ah_Max_Roll => 40, Enabled_Stats => 1879062316, Esc_Temp_Alarm => 0, Esc_Rpm_Alarm => -1,
     Esc_Current_Alarm => -1, Core_Temp_Alarm => 70, Ah_Invert => 0, Osd_Profile_Index => 1, Overlay_Radio_Mode => 2,
     Profile => (others => (others => 0)), Link_Quality_Alarm => 80, Rssi_Dbm_Alarm => -60, Rsnr_Alarm => 4,
     Gps_Sats_Show_Pdop => 0, Rc_Channels => (others => -1), Display_Port_Device => 3, Distance_Alarm => 0,
     Logo_On_Arming => 0, Logo_On_Arming_Duration => 5, Camera_Frame_Width => 24, Camera_Frame_Height => 11,
     Framerate_Hz => 12, Cms_Background_Type => 0, Stat_Show_Cell_Value => 0, Osd_Craftname_Msgs => 0, Aux_Channel =>
     1, Aux_Scale => 200, Aux_Symbol => 65, Canvas_Cols => 53, Canvas_Rows => 20, Osd_Use_Quick_Menu => 1,
     Osd_Show_Spec_Prearm => 0, Arming_Logo => 0, Osd_Uart => -1, Osd_Custom_Text_Uart => -1, Osd_Custom_Text_Baud =>
     5),  Osd_Element_Config => (Item_Pos => (341, 341, 312, 185, 313, 341, 341, 341, 341, 341, 341, 341, 341, 341,
     341, 341, 341, 341, 341, 341, 341, 14772, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341,
     341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 142,
     341, 341, 312, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341,
     341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 341, 33, 341, 341)),  Adc_Config =>
     (Vbat => (Enabled => False, Io_Tag => 0, Device => 1), Rssi => (Enabled => False, Io_Tag => 0, Device => 1),
     Current => (Enabled => False, Io_Tag => 0, Device => 1), External1 => (Enabled => False, Io_Tag => 0, Device =>
     1), Device => 1, Vref_Int_Calibration => 0, Temp_Sensor_Calibration1 => 0, Temp_Sensor_Calibration2 => 0, Dmaopt
     => (1, -1, -1)),  Alt_Hold_Config => (Climb_Rate => 50, Deadband => 20),  Autopilot_Config =>
     (Landing_Altitude_M => 4, Hover_Throttle => 1275, Throttle_Min => 1100, Throttle_Max => 1900, Altitude_P => 30,
     Altitude_I => 30, Altitude_D => 30, Altitude_A => 30, Altitude_F => 30, Position_P => 30, Position_I => 30,
     Position_D => 30, Position_A => 30, Position_F => 30, Position_Cutoff => 30, Stop_Threshold => 10, Max_Angle =>
     50, Velocity_Drag_Coeff => 50, Max_Velocity => 500, Waypoint_Arrival_Radius => 500, Waypoint_Hold_Radius => 200,
     Stick_Deadband => 50, Throttle_Deadband => 50, Nav_Corner_Speed => 220, Nav_Corner_Delta_V => 440, Nav_Decel =>
     250, Nav_Accel => 250, Nav_Carrot_Lead_Time => 12, Nav_Carrot_Lead_Max => 2500, Nav_Preturn_Dist => 1500,
     Yaw_Mode => 0, Yaw_P => 30, Max_Yaw_Rate => 150, Min_Forward_Velocity => 300, Velocity_Buildup_Max_Pitch => 8,
     Max_Turn_Rate => 3, Hold_Orbit_Radius => 1000, Hold_Figure8_Width => 2000, Landing_Descent_Rate => 50,
     Landing_Detection_Time => 10, Landing_Spiral_Enable => 1, Landing_Spiral_Radius => 200, Landing_Spiral_Rate =>
     10, Landing_Velocity_Threshold => 50, Landing_Throttle_Threshold => 100, L1_Enable => 1, L1_Period => 20,
     L1_Min_Lookahead => 1000, L1_Max_Lookahead => 10000, L1_Max_Cross_Track_Error => 10000, L1_Turn_Rate => 8,
     Min_Nav_Altitude_M => 5, Rx_Loss_Policy => 0, Max_Distance_From_Home_M => 0, Geofence_Action => 0),
     Beeper_Dev_Config => (Io_Tag => 0, Is_Inverted => 0, Is_Open_Drain => 1, Frequency => 0),  Beeper_Config =>
     (Beeper_Off_Flags => 0, Dshot_Beacon_Tone => 1, Dshot_Beacon_Off_Flags => 514),  Board_Config => (Signature =>
     (others => 0), Manufacturer_Id => (others => 0), Board_Name => (others => 0), Board_Information_Set => 0,
     Signature_Set => 0),  I2c_Config => (others => (Io_Tag_Scl => 0, Io_Tag_Sda => 0, Pull_Up => False, Clock_Speed
     => 800)),  Spi_Pin_Config => (others => (Io_Tag_Sck => 0, Io_Tag_Miso => 0, Io_Tag_Mosi => 0, Tx_Dmaopt => -1,
     Rx_Dmaopt => -1)),  Dashboard_Config => (Device => 0, Address => 60),  Display_Port_Profile_Msp => (Col_Adjust
     => 0, Row_Adjust => 0, Invert => False, Black_Brightness => 0, White_Brightness => 0, Font_Selection => (0, 1,
     2, 3), Use_Device_Blink => 0),  Display_Port_Profile_Max7456 => (Col_Adjust => 0, Row_Adjust => 0, Invert =>
     False, Black_Brightness => 0, White_Brightness => 2, Font_Selection => (others => 0), Use_Device_Blink => 0),
     Dyn_Notch_Config => (Dyn_Notch_Min_Hz => 100, Dyn_Notch_Max_Hz => 600, Dyn_Notch_Q => 300, Dyn_Notch_Count =>
     3),  Flash_Config => (Cs_Tag => 0, Spi_Device => 0, Quad_Spi_Device => 0, Octo_Spi_Device => 0),
     Flight_Plan_Config => (Waypoint_Count => 0, Waypoints => (others => (Latitude => 0, Longitude => 0, Altitude =>
     0, Speed => 0, Duration => 0, Vert_Rate => 0, Type_Value => 0, Pattern => 0, Yaw_Behaviour => 0))),
     Gimbal_Track_Config => (Gimbal_Roll_Rc_Gain => 40, Gimbal_Pitch_Rc_Thr_Gain => 10, Gimbal_Pitch_Rc_Low_Gain =>
     10, Gimbal_Pitch_Rc_High_Gain => -20, Gimbal_Yaw_Rc_Gain => 20, Gimbal_Roll_Gain => 100, Gimbal_Roll_Offset =>
     0, Gimbal_Roll_Limit => 100, Gimbal_Pitch_Gain => 50, Gimbal_Pitch_Offset => -10, Gimbal_Pitch_Low_Limit => 100,
     Gimbal_Pitch_High_Limit => 100, Gimbal_Yaw_Gain => 50, Gimbal_Yaw_Offset => 0, Gimbal_Yaw_Limit => 100,
     Gimbal_Stabilisation => 0, Gimbal_Sensitivity => 15, Gimbal_Uart => -1),  Gps_Lap_Timer_Config => (Gate_Lat =>
     0, Gate_Lon => 0, Minimum_Lap_Time_Seconds => 10, Gate_Tolerance_M => 9),  Gps_Config => (Provider => 1,
     Sbas_Mode => 5, Auto_Config => 1, Auto_Baud => 0, Gps_Ublox_Acquire_Model => 1, Gps_Ublox_Flight_Model => 7,
     Gps_Update_Rate_Hz => 10, Gps_Ublox_Use_Galileo => False, Gps_Set_Home_Point_Once => False, Gps_Use_3d_Speed =>
     False, Sbas_Integrity => False, Gps_Ublox_Utc_Standard => 0, Gps_Ublox_Enable_Ana => False, Nmea_Custom_Commands
     => (others => 0), Gps_Uart => -1, Gps_Baud => 4),  Gps_Rescue_Config => (Min_Start_Dist_M => 15, Altitude_Mode
     => 0, Initial_Climb_M => 10, Ascend_Rate => 750, Return_Altitude_M => 30, Ground_Speed_Cm_S => 750,
     Descent_Distance_M => 20, Descend_Rate => 150, Sanity_Checks => 2, Min_Sats => 8, Allow_Arming_Without_Fix => 0,
     Yaw_P => 20),  Gyro_Device_Config => (others => (Index => 0, Bus_Type => 0, Spi_Bus => 0, Csn_Tag => 0, I2c_Bus
     => 0, I2c_Address => 0, Exti_Tag => 0, Alignment => 0, Custom_Alignment => (others => 0), Clk_In => 0)),
     Max7456_Config => (Clock_Config => 1, Cs_Tag => 0, Spi_Device => 0, Pre_Init_Opu => False),  Mco_Config =>
     (others => (Enabled => 0, Source => 0, Divider => 0)),  Motor_Config => (Dev => (Motor_Pwm_Rate => 480,
     Motor_Protocol => 7, Motor_Inversion => 0, Use_Continuous_Update => 0, Use_Burst_Dshot => 0, Use_Dshot_Telemetry
     => 0, Use_Dshot_Edt => 0, Io_Tags => (others => 0), Motor_Transport_Protocol => 0, Use_Dshot_Bitbang => 2,
     Use_Dshot_Bitbanged_Timer => 0, Motor_Output_Reordering => (0, 1, 2, 3, 4, 5, 6, 7)), Motor_Idle => 550,
     Maxthrottle => 2000, Mincommand => 1000, Kv => 1960, Motor_Pole_Count => 14),  Msp_Config => (Half_Duplex => 0,
     Msp_Uart => (20, -1, -1), Msp_Baud => (others => 5)),  Osd_Nav_Map_Config => (Mode => 0, Centre => 0,
     Min_Scale_M => 150),  Pilot_Config => (Craft_Name => (others => 0), Pilot_Name => (others => 0), Message =>
     (others => (others => 0))),  Pinio_Box_Config => (Permanent_Id => (others => 255)),  Pinio_Config => (Io_Tag =>
     (others => 0), Config => (others => 1)),  Pin_Pullup_Config => (others => (Io_Tag => 0)),  Pin_Pulldown_Config
     => (others => (Io_Tag => 0)),  Pos_Hold_Config => (Deadband => 5, Position_Source => 0, Opticalflow_Quality_Min
     => 30, Opticalflow_Max_Range => 400),  Rcdevice_Config => (Init_Device_Attempts => 6,
     Init_Device_Attempt_Interval => 1000, Feature => 0, Protocol_Version => 0, Rcdevice_Uart => -1),
     Rpm_Filter_Config => (Rpm_Filter_Harmonics => 3, Rpm_Filter_Weights => (others => 100), Rpm_Filter_Min_Hz =>
     100, Rpm_Filter_Fade_Range_Hz => 50, Rpm_Filter_Q => 500, Rpm_Filter_Lpf_Hz => 150),  Rx_Config => (Rcmap => (0,
     1, 3, 2, 4, 5, 6, 7), Serialrx_Provider => 9, Serialrx_Inverted => 0, Half_Duplex => 0,
     Spektrum_Bind_Pin_Override_Io_Tag => 0, Spektrum_Bind_Plug_Io_Tag => 0, Spektrum_Sat_Bind => 0,
     Spektrum_Sat_Bind_Autoreset => 1, Rssi_Channel => 0, Rssi_Scale => 100, Rssi_Invert => 0, Midrc => 1500,
     Mincheck => 1050, Maxcheck => 1900, Fpv_Cam_Angle_Degrees => 0, Air_Mode_Activate_Threshold => 25, Rx_Min_Usec
     => 885, Rx_Max_Usec => 2115, Max_Aux_Channel => 14, Rssi_Src_Frame_Errors => 0, Rssi_Offset => 0, Rc_Smoothing
     => 1, Rc_Smoothing_Setpoint_Cutoff => 0, Rc_Smoothing_Throttle_Cutoff => 0, Rc_Smoothing_Debug_Axis => 0,
     Rc_Smoothing_Auto_Factor_Rpy => 30, Rc_Smoothing_Auto_Factor_Throttle => 30, Rssi_Src_Frame_Lpf_Period => 30,
     Rssi_Smoothing => 125, Srxl2_Unit_Id => 1, Srxl2_Baud_Fast => 1, Sbus_Baud_Fast => 0, Msp_Override_Channels_Mask
     => 0, Msp_Override_Failsafe => 0, Crsf_Use_Negotiated_Baud => 0, Rx_Uart => -1),  Pwm_Config => (Io_Tags =>
     (others => 0), Input_Filtering_Mode => 0),  Ppm_Config => (Io_Tag => 0),  Rx_Cc2500_Spi_Config => (Auto_Bind =>
     0, Bind_Tx_Id => (others => 0), Bind_Offset => 0, Bind_Hop_Data => (others => 0), Rx_Num => 0, A1_Source => 0,
     Chip_Detect_Enabled => 1, Tx_En_Io_Tag => 0, Lna_En_Io_Tag => 0, Ant_Sel_Io_Tag => 0),
     Rx_Express_Lrs_Spi_Config => (Reset_Io_Tag => 0, Busy_Io_Tag => 0, Uid => (others => 0), Domain => 0, Rate_Index
     => 0, Model_Id => 255),  Rx_Spi_Config => (Rx_Spi_Protocol => 0, Rx_Spi_Id => 0, Rx_Spi_Rf_Channel_Count => 0,
     Csn_Tag => 0, Spibus => 0, Bind_Io_Tag => 0, Led_Io_Tag => 0, Led_Inversion => 0, Exti_Io_Tag => 0),
     Scheduler_Config => (Rx_Relax_Determinism => 25, Osd_Relax_Determinism => 25, Cpu_Late_Percentage_Limit => 10,
     Debug_Task => 0),  Sdcard_Config => (Device => 0, Card_Detect_Tag => 0, Chip_Select_Tag => 0,
     Card_Detect_Inverted => 0, Mode => 0),  Serial_Uart_Config => (others => (Tx_Dmaopt => -1, Rx_Dmaopt => -1)),
     Stats_Config => (Stats_Total_Flights => 0, Stats_Total_Time_S => 0, Stats_Total_Dist_M => 0,
     Stats_Min_Armed_Time_S => -1, Stats_Mah_Used => 0, Stats_Save_Move_Limit => 20),  Timer_Io_Config => ((Io_Tag =>
     41, Index => 2, Dmaopt => -1), (Io_Tag => 32, Index => 1, Dmaopt => 0), (Io_Tag => 33, Index => 3, Dmaopt => 0),
     (Io_Tag => 19, Index => 1, Dmaopt => 1), (Io_Tag => 18, Index => 1, Dmaopt => 0), (Io_Tag => 36, Index => 1,
     Dmaopt => 0), (Io_Tag => 40, Index => 1, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0,
     Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0),
     (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt
     => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0,
     Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0), (Io_Tag => 0,
     Index => 0, Dmaopt => 0), (Io_Tag => 0, Index => 0, Dmaopt => 0)),  Usb_Dev_Config => (Type_Value => 0,
     Msc_Button_Pin => 0, Msc_Button_Use_Pullup => 1, Detect_Pin => 0),  Vcd_Profile => (Video_System => 3, H_Offset
     => 0, V_Offset => 0),  Vtx_Io_Config => (Cs_Tag => 0, Power_Tag => 0, Data_Tag => 0, Clock_Tag => 0, Spi_Device
     => 0),  Vtx_Table_Config => (Bands => 0, Channels => 0, Frequency => (others => (others => 0)), Band_Names =>
     ((66, 65, 78, 68, 49, 32, 32, 32, 0), (66, 65, 78, 68, 50, 32, 32, 32, 0), (66, 65, 78, 68, 51, 32, 32, 32, 0),
     (66, 65, 78, 68, 52, 32, 32, 32, 0), (66, 65, 78, 68, 53, 32, 32, 32, 0), (66, 65, 78, 68, 54, 32, 32, 32, 0),
     (66, 65, 78, 68, 55, 32, 32, 32, 0), (66, 65, 78, 68, 56, 32, 32, 32, 0)), Band_Letters => (49, 50, 51, 52, 53,
     54, 55, 56), Channel_Names => ((49, 0), (50, 0), (51, 0), (52, 0), (53, 0), (54, 0), (55, 0), (56, 0)),
     Is_Factory_Band => (others => False), Power_Levels => 0, Power_Values => (others => 0), Power_Labels => ((76,
     86, 48, 0), (76, 86, 49, 0), (76, 86, 50, 0), (76, 86, 51, 0), (76, 86, 52, 0), (76, 86, 53, 0), (76, 86, 54,
     0), (76, 86, 55, 0))),  Fly_Sky_Config => (Tx_Id => 0, Rf_Channel_Map => (others => 0)),  Spektrum_Config =>
     (Protocol => 0, Mfg_Id => (others => 0), Num_Channels => 0),  Rx_Channel_Range_Configs => (others => (Min =>
     1000, Max => 2000)),  Rx_Failsafe_Channel_Configs => ((Mode => 0, Step => 30), (Mode => 0, Step => 30), (Mode =>
     0, Step => 30), (Mode => 0, Step => 5), (Mode => 1, Step => 30), (Mode => 1, Step => 30), (Mode => 1, Step =>
     30), (Mode => 1, Step => 30), (Mode => 1, Step => 30), (Mode => 1, Step => 30), (Mode => 1, Step => 30), (Mode
     => 1, Step => 30), (Mode => 1, Step => 30), (Mode => 1, Step => 30), (Mode => 1, Step => 30), (Mode => 1, Step
     => 30), (Mode => 1, Step => 30), (Mode => 1, Step => 30)),  Accelerometer_Config => (Acc_Lpf_Hz => 25,
     Acc_Hardware => 0, Acc_High_Fsr => False, Acc_Zero => (others => 0), Accelerometer_Trims => (others => 0)),
     Barometer_Config => (Baro_Bus_Type => 2, Baro_Spi_Device => 0, Baro_Spi_Csn => 0, Baro_I2c_Device => 0,
     Baro_I2c_Address => 0, Baro_Hardware => 0, Baro_Eoc_Tag => 0, Baro_Xclr_Tag => 0, Baro_Temp_Drift_Cm_Per10_C =>
     0),  Battery_Profiles => (others => (Vbatmaxcellvoltage => 430, Vbatmincellvoltage => 330,
     Vbatwarningcellvoltage => 350, Vbatfullcellvoltage => 410, Battery_Capacity => 0, Force_Battery_Cell_Count => 0,
     Consumption_Warning_Percentage => 10, Profile_Name => (others => 0))),  Battery_Config =>
     (Vbatnotpresentcellvoltage => 300, Lvc_Percentage => 100, Voltage_Meter_Source => 0, Current_Meter_Source => 2,
     Use_V_Bat_Alerts => True, Use_Consumption_Alerts => False, Vbathysteresis => 1, Vbat_Display_Lpf_Period => 30,
     Ibat_Lpf_Period => 10, Vbat_Duration_For_Warning => 0, Vbat_Duration_For_Critical => 0, Vbat_Sag_Lpf_Period =>
     2, Is_Battery_Continue_Enabled => False),  Board_Alignment => (Roll_Degrees => 0, Pitch_Degrees => 0,
     Yaw_Degrees => 0),  Compass_Config => (Mag_Alignment => 0, Mag_Hardware => 0, Mag_Bus_Type => 1, Mag_I2c_Device
     => 0, Mag_I2c_Address => 0, Mag_Spi_Device => 0, Mag_Spi_Csn => 0, Interrupt_Tag => 0, Mag_Zero => (others =>
     0), Mag_Custom_Alignment => (others => 0)),  Current_Sensor_Adc_Config => (Scale => 400, Offset => 0),
     Current_Sensor_Virtual_Config => (Scale => 0, Offset => 0),  Esc_Sensor_Config => (Half_Duplex => 0, Offset =>
     0, Esc_Sensor_Uart => -1),  Gyro_Config => (Gyro_Movement_Calibration_Threshold => 48, Gyro_Hardware_Lpf => 0,
     Gyro_High_Fsr => 0, Gyro_Lpf1_Static_Hz => 250, Gyro_Lpf2_Static_Hz => 500, Gyro_Soft_Notch_Hz_1 => 0,
     Gyro_Soft_Notch_Cutoff_1 => 0, Gyro_Soft_Notch_Hz_2 => 0, Gyro_Soft_Notch_Cutoff_2 => 0, Gyro_Offset_Yaw => 0,
     Check_Overflow => 2, Gyro_Lpf1_Type => 0, Gyro_Lpf2_Type => 0, Yaw_Spin_Recovery => 2, Yaw_Spin_Threshold =>
     1950, Gyro_Calibration_Duration => 125, Gyro_Lpf1_Dyn_Min_Hz => 250, Gyro_Lpf1_Dyn_Max_Hz => 500,
     Gyro_Filter_Debug_Axis => 0, Gyros_Detected => 0, Gyro_Lpf1_Dyn_Expo => 5, Simplified_Gyro_Filter => 1,
     Simplified_Gyro_Filter_Multiplier => 100, Gyro_Enabled_Bitmask => 1),  Opticalflow_Config =>
     (Opticalflow_Hardware => 0, Rotation => 0, Flip_X => 0, Opticalflow_Uart => -1),  Pitot_Config =>
     (Pitot_Bus_Type => 1, Pitot_I2c_Device => 0, Pitot_I2c_Address => 0, Pitot_Hardware => 1),  Rangefinder_Config
     => (Rangefinder_Hardware => 0, Rangefinder_Uart => -1),  Sonar_Config => (Trigger_Tag => 0, Echo_Tag => 0),
     Voltage_Sensor_Adc_Config => (others => (Vbatscale => 110, Vbatresdivval => 10, Vbatresdivmultiplier => 1)),
     Telemetry_Config => (Gps_No_Fix_Latitude => 0, Gps_No_Fix_Longitude => 0, Telemetry_Inverted => 0, Half_Duplex
     => 1, Frsky_Coordinate_Format => 0, Frsky_Unit => 1, Frsky_Vfas_Precision => 0, Hott_Alarm_Sound_Interval => 5,
     Pid_Values_As_Telemetry => 0, Report_Cell_Voltage => 0, Flysky_Sensors => (1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0), Mavlink_Mah_As_Heading_Divisor => 0, Disabled_Sensors => 1540096, Mavlink_Min_Txbuff => 35,
     Mavlink_Extended_Status_Rate => 2, Mavlink_Rc_Channels_Rate => 1, Mavlink_Position_Rate => 2,
     Mavlink_Extra1_Rate => 2, Mavlink_Extra2_Rate => 2, Mavlink_Extra3_Rate => 1, Crsf_Tlm_Accgyro => 0, Providers
     => (others => (Protocol => 0, Uart => -1, Baud => 0))));

end Adaflight.Config_Groups;
