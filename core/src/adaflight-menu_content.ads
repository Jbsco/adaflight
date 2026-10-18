--  The menu system's menus: their numbers, and the lines and hooks of the
--  quick menu, the main menu with its features menu and setup popup, and
--  the save menus, over the target's state: the configuration, the
--  readings the setup popup shows, the quick menu's copies of the
--  profiles it edits, the setup popup's lines, and the requests to the
--  runtime. The menus of later slices have their numbers and one empty
--  line.
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

   PID_Profile_Count     : constant := 4;
   Rate_Profile_Count    : constant := 4;
   Battery_Profile_Count : constant := 3;

   --  What the setup popup reads: the accelerometer, whether arming waits
   --  for its calibration, the calibration's progress, whether the battery
   --  has charge drawn to restore, and the reboot flag the save menus go by.
   type Readings is record
      Acc_Present              : Boolean := False;
      Acc_Calibration_Needed   : Boolean := False;
      Acc_Calibration_Complete : Boolean := True;
      Acc_Calibrated           : Boolean := False;
      Used_MAh                 : Boolean := False;
      Reboot_Required          : Boolean := False;
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

   --  The setup popup's lines from its last build, with the calibration
   --  status and the battery restore text from its last update.
   type Popup_Lines is record
      Acc_Line     : Boolean := False;
      Battery_Line : Boolean := False;
      Acc_Status   : Adaflight.Menu.Label_Text;
      Battery_Text : Adaflight.Menu.Label_Text;
   end record;

   --  What the menus ask of the runtime: the charge drawn set back to the
   --  stored value, and the PID controller's setup from the current
   --  profile.
   type Requests is record
      MAh_Restores     : Natural := 0;
      MAh_Restored     : Interfaces.Unsigned_32 := 0;
      PID_Config_Inits : Natural := 0;
   end record;

   type Target is record
      Config : Adaflight.Config_Groups.Configuration;
      Live   : Readings;
      Quick  : Quick_Copies;
      Popup  : Popup_Lines;
      Asked  : Requests;
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
