--  The menu system's menus: their numbers, and the lines and hooks of the
--  quick menu, the main menu with its features menu and setup popup, the
--  profile menu with its PID, rate, simplified tuning, misc, launch
--  control, filter and profile copy menus, the VTX selection with its
--  error menu, the MSP VTX menu with its confirmation, the save menus, the
--  OSD menu with
--  its active elements, timers and alarms
--  menus, the blackbox menu with its erase and mass storage
--  confirmations, the LED strip, power, failsafe and RPM limit menus, the
--  misc menu with its RC preview and GPS lap timer menu, the persistent
--  statistics menu, and the firmware menu with its calibration menus, over
--  the target's state: the configuration, the firmware's identity, the
--  readings the menus show, the VTX layer with its running table and the
--  MSP VTX menu's status line, the menus' copies of the settings they edit,
--  the setup popup's lines, the calibration statuses, and the requests to
--  the runtime. The menus of later slices have their numbers and one empty
--  line.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Menu;
with Adaflight.VTX;
with Adaflight.VTX_Table;

package Adaflight.Menu_Content with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Menu_Id is Adaflight.Menu.Menu_Id;

   Main_Menu             : constant Menu_Id := Adaflight.Menu.Main_Menu;
   Save_Exit             : constant Menu_Id := 1;
   Save_Exit_Reboot      : constant Menu_Id := 2;
   Setup_Popup           : constant Menu_Id := 3;
   Features              : constant Menu_Id := 4;
   Profile_Menu          : constant Menu_Id := 5;
   OSD_Menu              : constant Menu_Id := 6;
   Firmware_Menu         : constant Menu_Id := 7;
   Misc_Menu             : constant Menu_Id := 8;
   Blackbox_Menu         : constant Menu_Id := 9;
   LED_Strip_Menu        : constant Menu_Id := 10;
   Power_Menu            : constant Menu_Id := 11;
   Failsafe_Menu         : constant Menu_Id := 12;
   Persistent_Stats_Menu : constant Menu_Id := 13;
   Calibrate_Acc_Menu    : constant Menu_Id := 14;
   Quick_Menu            : constant Menu_Id := 15;
   RPM_Limit_Menu        : constant Menu_Id := 16;
   RC_Preview_Menu       : constant Menu_Id := 17;
   GPS_Lap_Timer_Menu    : constant Menu_Id := 18;
   Calibration_Menu      : constant Menu_Id := 19;
   Set_Gate_Menu         : constant Menu_Id := 20;
   Erase_Flash_Menu      : constant Menu_Id := 21;
   Storage_Device_Menu   : constant Menu_Id := 22;
   Active_Elements_Menu  : constant Menu_Id := 23;
   Timers_Menu           : constant Menu_Id := 24;
   Alarms_Menu           : constant Menu_Id := 25;
   VTX_Error_Menu        : constant Menu_Id := 26;
   VTX_RTC6705_Menu      : constant Menu_Id := 27;
   VTX_SmartAudio_Menu   : constant Menu_Id := 28;
   VTX_Tramp_Menu        : constant Menu_Id := 29;
   VTX_MSP_Menu          : constant Menu_Id := 30;
   PID_Menu              : constant Menu_Id := 31;
   Rate_Menu             : constant Menu_Id := 32;
   Simplified_Menu       : constant Menu_Id := 33;
   Profile_Other_Menu    : constant Menu_Id := 34;
   Filter_Profile_Menu   : constant Menu_Id := 35;
   Filter_Global_Menu    : constant Menu_Id := 36;
   Dynamic_Filter_Menu   : constant Menu_Id := 37;
   Copy_Profile_Menu     : constant Menu_Id := 38;
   Launch_Control_Menu   : constant Menu_Id := 39;
   VTX_MSP_Confirm       : constant Menu_Id := 40;

   --  The RC channels the preview shows: roll, pitch, throttle, yaw and the
   --  first four auxiliary channels.
   subtype RC_Reading is Float range -30_000.0 .. 30_000.0;
   type RC_Channels is array (0 .. 7) of RC_Reading;

   --  The PID loop's frequency in hertz, which the blackbox menu shows cut
   --  to a whole sixteen-bit number, and the SD card's file system state in
   --  the reference's numbering.
   subtype PID_Hertz is Float range 0.0 .. 65_535.0;
   type File_System_State is (Unknown, Fatal, Initialization, Ready);

   PID_Profile_Count     : constant := 4;
   Rate_Profile_Count    : constant := 4;
   Battery_Profile_Count : constant := 3;

   --  What the menus read: the accelerometer, whether arming waits for its
   --  calibration, the calibration's progress, whether the battery has
   --  charge drawn to restore, the reboot flag the save menus go by, the RC
   --  channels, the gyro and the barometer with their calibrations, the
   --  board's manufacturer and name from the board information, the lap
   --  timer's gate readings and distance to the gate, the features active at
   --  run time, whether the flight recorder lets its configuration change,
   --  the PID loop's frequency, the SD card with its file system, contiguous
   --  free bytes and size in blocks, the flash with its partition's sectors,
   --  sector size and write offset, whether mass storage is ready, and the
   --  VTX device, present or not, with its type in the reference's
   --  numbering.
   type Readings is record
      Acc_Present               : Boolean := False;
      Acc_Calibration_Needed    : Boolean := False;
      Acc_Calibration_Complete  : Boolean := True;
      Acc_Calibrated            : Boolean := False;
      Used_MAh                  : Boolean := False;
      Reboot_Required           : Boolean := False;
      RC_Data                   : RC_Channels := (others => 0.0);
      Gyro_Present              : Boolean := False;
      Gyro_Calibration_Complete : Boolean := False;
      Baro_Present              : Boolean := False;
      Baro_Calibrated           : Boolean := False;
      Manufacturer_Id           : Adaflight.Menu.Label_Text;
      Board_Name                : Adaflight.Menu.Label_Text;
      Gate_Set_Readings         : Interfaces.Unsigned_16 := 0;
      Gate_Distance_Cm          : Interfaces.Unsigned_32 := 0;
      Runtime_Features          : Interfaces.Unsigned_32 := 0;
      Blackbox_May_Edit         : Boolean := True;
      PID_Frequency             : PID_Hertz := 0.0;
      Card_Inserted             : Boolean := False;
      Card_Functional           : Boolean := False;
      Card_File_System          : File_System_State := Unknown;
      Card_Free_Bytes           : Interfaces.Unsigned_32 := 0;
      Card_Blocks               : Interfaces.Unsigned_32 := 0;
      Flash_Supported           : Boolean := False;
      Flash_Sectors             : Natural range 0 .. 65_536 := 0;
      Flash_Sector_Size         : Interfaces.Unsigned_32 := 0;
      Flash_Offset              : Interfaces.Unsigned_32 := 0;
      Storage_Ready             : Boolean := False;
      VTX_Present               : Boolean := False;
      VTX_Type                  : Interfaces.Unsigned_8 := 0;
   end record;

   --  The firmware's identity the firmware menu shows, which the build
   --  sets: its identifier, version, source revision and target.
   type Firmware_Identity is record
      Identifier  : Adaflight.Menu.Label_Text;
      Version     : Adaflight.Menu.Label_Text;
      Revision    : Adaflight.Menu.Label_Text;
      Target_Name : Adaflight.Menu.Label_Text;
   end record;

   --  The firmware menu's copies of the board's manufacturer and name, cut
   --  to the board information's lengths.
   Manufacturer_Id_Length : constant := 4;
   Board_Name_Length      : constant := 20;

   type Board_Copies is record
      Manufacturer_Id : Adaflight.Menu.Label_Text;
      Board_Name      : Adaflight.Menu.Label_Text;
   end record;

   --  The calibration menu's statuses of the gyro, the accelerometer and
   --  the barometer from its last update.
   type Calibration_Statuses is record
      Gyro : Adaflight.Menu.Label_Text;
      Acc  : Adaflight.Menu.Label_Text;
      Baro : Adaflight.Menu.Label_Text;
   end record;

   --  The quick menu's copies of the rate and battery profiles and of the
   --  motor output limit, with the profiles they came from.
   type Quick_Copies is record
      PID_Profile        : Natural range 0 .. PID_Profile_Count - 1 := 0;
      Rate_Profile       : Natural range 0 .. Rate_Profile_Count - 1 := 0;
      Battery_Profile    : Natural range 0 .. Battery_Profile_Count - 1 := 0;
      Rate               : Adaflight.Config_Groups.Control_Rate_Config_Record;
      Battery            : Adaflight.Config_Groups.Battery_Profile_Record;
      Motor_Output_Limit : Interfaces.Unsigned_8 := 100;
   end record;

   --  The power menu's copies of the meter sources, the active battery
   --  profile's cell voltages and the meters' scales and offsets.
   type Power_Copies is record
      Voltage_Meter_Source  : Interfaces.Unsigned_8 := 0;
      Current_Meter_Source  : Interfaces.Unsigned_8 := 0;
      Battery_Profile       : Natural range 0 .. Battery_Profile_Count - 1 := 0;
      Min_Cell_Voltage      : Interfaces.Unsigned_16 := 0;
      Max_Cell_Voltage      : Interfaces.Unsigned_16 := 0;
      Warning_Cell_Voltage  : Interfaces.Unsigned_16 := 0;
      Voltage_Scale         : Interfaces.Unsigned_8 := 0;
      Current_Scale         : Interfaces.Integer_16 := 0;
      Current_Offset        : Interfaces.Integer_16 := 0;
      Virtual_Scale         : Interfaces.Integer_16 := 0;
      Virtual_Offset        : Interfaces.Unsigned_16 := 0;
   end record;

   --  The failsafe menu's copies of the procedure, the guard time, the
   --  landing time and the stage 2 throttle.
   type Failsafe_Copies is record
      Procedure_Kind : Interfaces.Unsigned_8 := 0;
      Guard_Time     : Interfaces.Unsigned_8 := 0;
      Landing_Time   : Interfaces.Unsigned_8 := 0;
      Throttle       : Interfaces.Unsigned_16 := 0;
   end record;

   --  The RPM limit menu's copies of the limit's switch and value and the
   --  motors' KV.
   type RPM_Limit_Copies is record
      Active : Boolean := False;
      Limit  : Interfaces.Unsigned_16 := 0;
      KV     : Interfaces.Unsigned_16 := 0;
   end record;

   --  The misc menu's copies of the idle offset in tens, the camera angle
   --  and the crash flip rate.
   type Misc_Copies is record
      Idle_Offset    : Interfaces.Unsigned_8 := 0;
      FPV_Cam_Angle  : Interfaces.Unsigned_8 := 0;
      Crashflip_Rate : Interfaces.Unsigned_8 := 0;
   end record;

   --  The profile menu's copies: the PID and rate profiles it selected, the
   --  profiles its lines show, and every profile's number and name as the
   --  lines name them.
   type Profile_Texts is array (0 .. 3) of Adaflight.Menu.Label_Text;
   type Profile_Copies is record
      PID_Index  : Interfaces.Unsigned_8 := 0;
      PID_Line   : Interfaces.Unsigned_8 := 0;
      Rate_Index : Interfaces.Unsigned_8 := 0;
      Rate_Line  : Interfaces.Unsigned_8 := 0;
      PID_Names  : Profile_Texts;
      Rate_Names : Profile_Texts;
   end record;

   --  The PID menu's copies of each axis's P, I and D gains and
   --  feedforward, with the profile's text from its last entry.
   type Gain_Table is array (0 .. 2, 0 .. 2) of Interfaces.Unsigned_8;
   type Feedforward_Table is array (0 .. 2) of Interfaces.Unsigned_16;
   type PID_Copies is record
      Gains        : Gain_Table := (others => (others => 0));
      Feedforward  : Feedforward_Table := (others => 0);
      Profile_Text : Adaflight.Menu.Label_Text;
   end record;

   --  The rate menu's copy of the rate profile, with the profile's text
   --  from its last entry.
   type Rate_Copies is record
      Profile      : Adaflight.Config_Groups.Control_Rate_Config_Record :=
        Adaflight.Config_Groups.Defaults.Control_Rate_Profiles (0);
      Profile_Text : Adaflight.Menu.Label_Text;
   end record;

   --  The simplified tuning menu's copies of the PID tuning mode, the master
   --  multiplier, the pitch to roll ratios, the I, D, P and I, D max and
   --  feedforward gains, and the D term and gyro filter switches with their
   --  multipliers.
   type Simplified_Copies is record
      Mode             : Interfaces.Unsigned_8 := 0;
      Master           : Interfaces.Unsigned_8 := 0;
      Roll_Pitch_Ratio : Interfaces.Unsigned_8 := 0;
      I_Gain           : Interfaces.Unsigned_8 := 0;
      D_Gain           : Interfaces.Unsigned_8 := 0;
      PI_Gain          : Interfaces.Unsigned_8 := 0;
      D_Max_Gain       : Interfaces.Unsigned_8 := 0;
      FF_Gain          : Interfaces.Unsigned_8 := 0;
      Pitch_PI_Gain    : Interfaces.Unsigned_8 := 0;
      DTerm_Filter     : Interfaces.Unsigned_8 := 0;
      DTerm_Multiplier : Interfaces.Unsigned_8 := 0;
      Gyro_Filter      : Interfaces.Unsigned_8 := 0;
      Gyro_Multiplier  : Interfaces.Unsigned_8 := 0;
   end record;

   --  The misc profile menu's copies of the feedforward settings, the angle
   --  and horizon gains and limits, the anti gravity gain, the throttle
   --  boost and linearization, the I term relax, the motor output limit, the
   --  cell count the profile takes, the D max gains, the battery sag
   --  compensation, the throttle PID attenuation and the landing disarm
   --  threshold.
   type D_Max_Table is array (0 .. 2) of Interfaces.Unsigned_8;
   type Other_Copies is record
      FF_Transition        : Interfaces.Unsigned_8 := 0;
      FF_Averaging         : Interfaces.Unsigned_8 := 0;
      FF_Smooth            : Interfaces.Unsigned_8 := 0;
      FF_Jitter            : Interfaces.Unsigned_8 := 0;
      FF_Boost             : Interfaces.Unsigned_8 := 0;
      Angle_P              : Interfaces.Unsigned_8 := 0;
      Angle_FF             : Interfaces.Unsigned_8 := 0;
      Angle_Limit          : Interfaces.Unsigned_8 := 0;
      Angle_Earth_Ref      : Interfaces.Unsigned_8 := 0;
      Horizon_Strength     : Interfaces.Unsigned_8 := 0;
      Horizon_Sticks       : Interfaces.Unsigned_8 := 0;
      Horizon_Degrees      : Interfaces.Unsigned_8 := 0;
      Anti_Gravity_Gain    : Interfaces.Unsigned_8 := 0;
      Throttle_Boost       : Interfaces.Unsigned_8 := 0;
      Thrust_Linearization : Interfaces.Unsigned_8 := 0;
      Iterm_Relax          : Interfaces.Unsigned_8 := 0;
      Iterm_Relax_Type     : Interfaces.Unsigned_8 := 0;
      Iterm_Relax_Cutoff   : Interfaces.Unsigned_8 := 0;
      Motor_Output_Limit   : Interfaces.Unsigned_8 := 0;
      Auto_Cell_Count      : Interfaces.Integer_8 := 0;
      D_Max                : D_Max_Table := (others => 0);
      D_Max_Gain           : Interfaces.Unsigned_8 := 0;
      D_Max_Advance        : Interfaces.Unsigned_8 := 0;
      Vbat_Sag             : Interfaces.Unsigned_8 := 0;
      TPA_Rate             : Interfaces.Unsigned_8 := 0;
      TPA_Breakpoint       : Interfaces.Unsigned_16 := 0;
      TPA_Low_Rate         : Interfaces.Integer_8 := 0;
      TPA_Low_Breakpoint   : Interfaces.Unsigned_16 := 0;
      TPA_Low_Always       : Interfaces.Unsigned_8 := 0;
      Landing_Disarm       : Interfaces.Unsigned_8 := 0;
   end record;

   --  The launch control menu's copies of the mode, the trigger reset
   --  switch, the trigger throttle, the angle limit and the I term gain.
   type Launch_Copies is record
      Mode             : Interfaces.Unsigned_8 := 0;
      Allow_Reset      : Interfaces.Unsigned_8 := 0;
      Throttle_Percent : Interfaces.Unsigned_8 := 0;
      Angle_Limit      : Interfaces.Unsigned_8 := 0;
      Gain             : Interfaces.Unsigned_8 := 0;
   end record;

   --  The global filter menu's copies of the gyro lowpass and notch filters.
   type Filter_Global_Copies is record
      Gyro_LPF1     : Interfaces.Unsigned_16 := 0;
      Gyro_LPF2     : Interfaces.Unsigned_16 := 0;
      Notch1_Hz     : Interfaces.Unsigned_16 := 0;
      Notch1_Cutoff : Interfaces.Unsigned_16 := 0;
      Notch2_Hz     : Interfaces.Unsigned_16 := 0;
      Notch2_Cutoff : Interfaces.Unsigned_16 := 0;
   end record;

   --  The dynamic filter menu's copies of the dynamic notch's count, Q and
   --  range, and the gyro and D term dynamic lowpass ranges and expos.
   type Dynamic_Filter_Copies is record
      Notch_Count  : Interfaces.Unsigned_8 := 0;
      Notch_Q      : Interfaces.Unsigned_16 := 0;
      Notch_Min_Hz : Interfaces.Unsigned_16 := 0;
      Notch_Max_Hz : Interfaces.Unsigned_16 := 0;
      Gyro_Min     : Interfaces.Unsigned_16 := 0;
      Gyro_Max     : Interfaces.Unsigned_16 := 0;
      Gyro_Expo    : Interfaces.Unsigned_8 := 0;
      DTerm_Min    : Interfaces.Unsigned_16 := 0;
      DTerm_Max    : Interfaces.Unsigned_16 := 0;
      DTerm_Expo   : Interfaces.Unsigned_8 := 0;
   end record;

   --  The profile filter menu's copies of the D term lowpass and notch
   --  filters and the yaw lowpass.
   type Filter_Profile_Copies is record
      DTerm_LPF1         : Interfaces.Unsigned_16 := 0;
      DTerm_LPF2         : Interfaces.Unsigned_16 := 0;
      DTerm_Notch_Hz     : Interfaces.Unsigned_16 := 0;
      DTerm_Notch_Cutoff : Interfaces.Unsigned_16 := 0;
      Yaw_Lowpass        : Interfaces.Unsigned_16 := 0;
   end record;

   --  The profile copy menu's PID and rate profile destinations, from one,
   --  zero for none.
   type Copy_Targets is record
      PID_Target  : Interfaces.Unsigned_8 := 0;
      Rate_Target : Interfaces.Unsigned_8 := 0;
   end record;

   --  The VTX error menu's two status lines from its last entry.
   type VTX_Status_Lines is record
      Line_1 : Adaflight.Menu.Label_Text;
      Line_2 : Adaflight.Menu.Label_Text;
   end record;

   --  The VTX device menus' copies of the pit mode, none, off or on, the
   --  band, channel and power index, and the frequency of the band and
   --  channel.
   type VTX_Copies is record
      Pit_Mode : Interfaces.Unsigned_8 := 0;
      Band     : Interfaces.Unsigned_8 := 1;
      Channel  : Interfaces.Unsigned_8 := 1;
      Freq_Ref : Interfaces.Unsigned_16 := 0;
      Power    : Interfaces.Unsigned_8 := 1;
   end record;

   --  The VTX device menus' status line before the driver first sets it.
   Initial_VTX_Status : constant Adaflight.Menu.Label_Text :=
     (Data => "- -- ---- ----" & (1 .. 17 => ' '), Length => 14);

   --  The OSD menu's copies of the OSD profile, the MAX7456 display's
   --  inversion and black and white brightness, and the menu background.
   type OSD_Copies is record
      Profile          : Interfaces.Unsigned_8 := 0;
      Invert           : Boolean := False;
      Black_Brightness : Interfaces.Unsigned_8 := 0;
      White_Brightness : Interfaces.Unsigned_8 := 0;
      Background       : Interfaces.Unsigned_8 := 0;
   end record;

   --  The timers menu's copies of each timer's source, precision and alarm.
   type Timer_Fields is array (0 .. 1) of Interfaces.Unsigned_8;
   type Timer_Copies is record
      Source    : Timer_Fields := (others => 0);
      Precision : Timer_Fields := (others => 0);
      Alarm     : Timer_Fields := (others => 0);
   end record;

   --  The alarms menu's copies of the RSSI, link quality, RSSI in dBm,
   --  signal to noise, capacity, altitude and distance alarms, and the
   --  battery voltage's warning and critical durations.
   type Alarm_Copies is record
      RSSI              : Interfaces.Unsigned_8 := 0;
      Link_Quality      : Interfaces.Unsigned_16 := 0;
      RSSI_Dbm          : Interfaces.Integer_16 := 0;
      RSNR              : Interfaces.Integer_16 := 0;
      Capacity          : Interfaces.Unsigned_16 := 0;
      Altitude          : Interfaces.Unsigned_16 := 0;
      Distance          : Interfaces.Unsigned_16 := 0;
      Warning_Duration  : Interfaces.Unsigned_8 := 0;
      Critical_Duration : Interfaces.Unsigned_8 := 0;
   end record;

   --  The blackbox menu's copies of the device, the sample rate and the
   --  debug mode, with its texts from its last entry or erase: the PID
   --  loop's frequency, the device's status, and the used and free space.
   type Blackbox_Copies is record
      Device        : Interfaces.Unsigned_8 := 0;
      Rate          : Interfaces.Unsigned_8 := 0;
      Debug_Mode    : Interfaces.Unsigned_8 := 0;
      PID_Frequency : Adaflight.Menu.Label_Text;
      Status        : Adaflight.Menu.Label_Text;
      Used          : Adaflight.Menu.Label_Text;
      Free          : Adaflight.Menu.Label_Text;
   end record;

   --  The LED strip menu's copies of the strip's feature, the profile, the
   --  race and beacon colors, the beacon's period, on share and armed-only
   --  switch, and the visual beeper with its color.
   LED_Profile_Count : constant := 3;
   LED_Color_Count   : constant := 14;

   type LED_Copies is record
      Enabled             : Interfaces.Unsigned_8 := 0;
      Profile             : Interfaces.Unsigned_8 := 0;
      Race_Color          : Interfaces.Unsigned_8 := 0;
      Beacon_Color        : Interfaces.Unsigned_8 := 0;
      Beacon_Period       : Interfaces.Unsigned_16 := 0;
      Beacon_On_Percent   : Interfaces.Unsigned_8 := 0;
      Beacon_Armed_Only   : Interfaces.Unsigned_8 := 0;
      Visual_Beeper       : Interfaces.Unsigned_8 := 0;
      Visual_Beeper_Color : Interfaces.Unsigned_8 := 0;
   end record;

   --  The GPS lap timer menu's copies of the minimum lap time and the gate
   --  radius.
   type Lap_Copies is record
      Minimum_Lap_Time : Interfaces.Unsigned_16 := 0;
      Gate_Tolerance   : Interfaces.Unsigned_8 := 0;
   end record;

   --  The RC preview's channels, rounded at its last update.
   type RC_Values is array (0 .. 7) of Interfaces.Integer_16;

   --  The persistent statistics menu's copies of the totals and the
   --  minimum armed time.
   type Stats_Copies is record
      Total_Flights  : Interfaces.Unsigned_32 := 0;
      Total_Time_S   : Interfaces.Unsigned_32 := 0;
      Total_Dist_M   : Interfaces.Unsigned_32 := 0;
      Min_Armed_Time : Interfaces.Integer_8 := 0;
   end record;

   --  The setup popup's lines from its last build, with the calibration
   --  status and the battery restore text from its last update.
   type Popup_Lines is record
      Acc_Line     : Boolean := False;
      Battery_Line : Boolean := False;
      Acc_Status   : Adaflight.Menu.Label_Text;
      Battery_Text : Adaflight.Menu.Label_Text;
   end record;

   --  What the menus ask of the runtime: the charge drawn set back to the
   --  stored value, the PID controller's setup from the current profile,
   --  the gyro, accelerometer and barometer calibrations, the lap timer's
   --  gate setting started and ended, the LED strip turned on and off, the
   --  flash erased with its beep, and the reset to mass storage with the time
   --  zone offset it takes, the OSD's active elements analyzed again, and
   --  the OSD profile changed with the profile asked for, and the PID and
   --  rate profiles changed with the profiles asked for, and the motors'
   --  output range set again.
   type Requests is record
      MAh_Restores       : Natural := 0;
      MAh_Restored       : Interfaces.Unsigned_32 := 0;
      PID_Config_Inits   : Natural := 0;
      Gyro_Calibrations  : Natural := 0;
      Acc_Calibrations   : Natural := 0;
      Baro_Calibrations  : Natural := 0;
      Gate_Starts        : Natural := 0;
      Gate_Ends          : Natural := 0;
      LED_Strip_Enables  : Natural := 0;
      LED_Strip_Disables : Natural := 0;
      Flash_Erases       : Natural := 0;
      Erase_Beeps        : Natural := 0;
      MSC_Resets         : Natural := 0;
      MSC_Reset_Offset   : Interfaces.Integer_16 := 0;
      Element_Analyses   : Natural := 0;
      Profile_Changes    : Natural := 0;
      Profile_Asked      : Interfaces.Unsigned_8 := 0;
      PID_Changes        : Natural := 0;
      PID_Asked          : Interfaces.Unsigned_8 := 0;
      Rate_Changes       : Natural := 0;
      Rate_Asked         : Interfaces.Unsigned_8 := 0;
      Endpoint_Inits     : Natural := 0;
   end record;

   type Target is record
      Config      : Adaflight.Config_Groups.Configuration;
      Identity    : Firmware_Identity;
      Live        : Readings;
      Quick       : Quick_Copies;
      Power       : Power_Copies;
      Failsafe    : Failsafe_Copies;
      RPM_Limit   : RPM_Limit_Copies;
      Misc        : Misc_Copies;
      OSD         : OSD_Copies;
      Elements    : Adaflight.Config_Groups.Unsigned_16_List_99 := (others => 0);
      Timers      : Timer_Copies;
      Alarms      : Alarm_Copies;
      Blackbox    : Blackbox_Copies;
      Profile     : Profile_Copies;
      PID         : PID_Copies;
      Rate        : Rate_Copies;
      Simplified  : Simplified_Copies;
      Other       : Other_Copies;
      Launch      : Launch_Copies;
      Global_Filt : Filter_Global_Copies;
      Dynamic     : Dynamic_Filter_Copies;
      Profile_Flt : Filter_Profile_Copies;
      Copy        : Copy_Targets;
      VTX_Status  : VTX_Status_Lines;
      VTX         : Adaflight.VTX.State;
      MSP_Status  : Adaflight.Menu.Label_Text := Initial_VTX_Status;
      MSP         : VTX_Copies;
      VTX_Table   : Adaflight.VTX_Table.Table;
      LED         : LED_Copies;
      Lap         : Lap_Copies;
      Preview     : RC_Values := (others => 0);
      Stats       : Stats_Copies;
      Board       : Board_Copies;
      Popup       : Popup_Lines;
      Calibration : Calibration_Statuses;
      Asked       : Requests;
   end record;

   --  The menu the menu system opens with: the quick menu when the OSD's
   --  setting asks for it, else the main menu.
   function Start_Menu (T : Target) return Menu_Id is
     (if T.Config.Osd_Config.Osd_Use_Quick_Menu /= 0 then Quick_Menu else Main_Menu);

   function Hooks_Of (Id : Menu_Id) return Adaflight.Menu.Hook_Set;

   --  The MSP VTX menu's status line from the VTX device, which the target
   --  updates when the VTX layer's events ask for it.
   procedure Update_MSP_Status (T : in out Target);

   procedure Load (T : Target; Id : Menu_Id; M : out Adaflight.Menu.Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M);

   procedure On_Enter (T : in out Target; Id : Menu_Id; Reply : out Adaflight.Menu.Answer);

   procedure On_Leave (T : in out Target; Id : Menu_Id; Self : Integer; Chain_Back : out Boolean);

   procedure On_Display_Update (T : in out Target; Id : Menu_Id; Selected : Natural; Chain_Back : out Boolean);

   procedure Line_Call (T : in out Target; Id : Menu_Id; Line : Natural; Reply : out Adaflight.Menu.Answer);

   procedure Set_Value (T : in out Target; Id : Menu_Id; Line : Natural; Value : Interfaces.Integer_32);

   procedure Refresh (T : Target; Id : Menu_Id; M : in out Adaflight.Menu.Table)
     with Post => M.Count = M.Count'Old and then (if Adaflight.Menu.Fixed_In_Range (M'Old)
                                                  then Adaflight.Menu.Fixed_In_Range (M));

   function Lookup (T : Target; Id : Menu_Id; Line : Natural; Index : Natural) return Adaflight.Menu.Label_Text;

end Adaflight.Menu_Content;
