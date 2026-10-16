--  The menu system's menus: their numbers, and the lines and hooks of the
--  quick menu, the main menu with its features menu and setup popup, the
--  save menus, the power, failsafe and RPM limit menus, the misc menu with
--  its RC preview, the persistent statistics menu, and the firmware menu
--  with its calibration menus, over the target's state: the configuration,
--  the firmware's identity, the readings the menus show, the menus' copies
--  of the settings they edit, the setup popup's lines, the calibration
--  statuses, and the requests to the runtime. The menus of later slices
--  have their numbers and one empty line.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Menu;

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

   --  The RC channels the preview shows: roll, pitch, throttle, yaw and the
   --  first four auxiliary channels.
   subtype RC_Reading is Float range -30_000.0 .. 30_000.0;
   type RC_Channels is array (0 .. 7) of RC_Reading;

   PID_Profile_Count     : constant := 4;
   Rate_Profile_Count    : constant := 4;
   Battery_Profile_Count : constant := 3;

   --  What the menus read: the accelerometer, whether arming waits for its
   --  calibration, the calibration's progress, whether the battery has
   --  charge drawn to restore, the reboot flag the save menus go by, the RC
   --  channels, the gyro and the barometer with their calibrations, and the
   --  board's manufacturer and name from the board information.
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
   --  and the gyro, accelerometer and barometer calibrations.
   type Requests is record
      MAh_Restores      : Natural := 0;
      MAh_Restored      : Interfaces.Unsigned_32 := 0;
      PID_Config_Inits  : Natural := 0;
      Gyro_Calibrations : Natural := 0;
      Acc_Calibrations  : Natural := 0;
      Baro_Calibrations : Natural := 0;
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
