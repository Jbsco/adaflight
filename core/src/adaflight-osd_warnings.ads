--  The OSD warnings line: one message chosen in the reference's order of
--  precedence from the rescue, the arming disable reasons rotated every
--  half second, the DShot beacon guard, the failsafe, the ESC alarms, the
--  crash flip, the launch control, the signal alarms, the battery states,
--  the load, the rescue availability, the position hold failure, the
--  headfree mode, the core temperature, the capacity, the visual beeper
--  and the chirp excitation, each with its severity and blink. The
--  settings, the sensors and the clock stay with the target, which brings
--  the values the line reads.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Battery;
with Adaflight.OSD_Format;

package Adaflight.OSD_Warnings with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_8;
   use type Adaflight.Battery.Battery_State;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Unsigned_8 is Interfaces.Unsigned_8;

   Max_Size       : constant := 31;
   Preferred_Size : constant := 12;

   type Severity is (Normal, Info, Warning, Critical);

   type Warning_Kind is
     (Arming_Disable, Battery_Not_Full, Battery_Warning, Battery_Critical, Visual_Beeper, Crash_Flip, ESC_Fail,
      Core_Temperature, Fail_Safe, Launch_Control, GPS_Rescue_Unavailable, GPS_Rescue_Failing, RSSI,
      Link_Quality, RSSI_Dbm, Over_Cap, RSNR, Load, Pos_Hold_Failed, Autopilot_Abort);
   type Warning_Set is array (Warning_Kind) of Boolean;

   subtype Unit_System is Adaflight.OSD_Format.Unit_System;

   Alarm_Off : constant := -1;

   --  The warnings enabled, the units, and the alarm thresholds; the ESC
   --  temperature alarm is off at zero, the other ESC alarms at minus one.
   type Settings is record
      Enabled            : Warning_Set := (others => True);
      Units              : Unit_System := Adaflight.OSD_Format.Metric;
      RSSI_Alarm         : Natural range 0 .. 100 := 20;
      RSSI_Dbm_Alarm     : Integer range -130 .. 0 := -60;
      RSNR_Alarm         : Integer range -30 .. 20 := 4;
      Link_Quality_Alarm : Natural range 0 .. 100 := 80;
      Core_Temp_Alarm    : Natural range 0 .. 255 := 70;
      Cap_Alarm          : Natural range 0 .. 20_000 := 0;
      ESC_RPM_Alarm      : Integer range Alarm_Off .. 32_767 := Alarm_Off;
      ESC_Current_Alarm  : Integer range Alarm_Off .. 32_767 := Alarm_Off;
      ESC_Temp_Alarm     : Natural range 0 .. 255 := 0;
   end record;

   subtype Motor_Count is Natural range 0 .. 8;
   subtype Motor_Index is Natural range 0 .. 7;

   --  One ESC's telemetry: present, with its electrical rotation count,
   --  current and temperature.
   type ESC_Data is record
      Present     : Boolean := False;
      RPM         : Integer_16 := 0;
      Current     : Integer_32 := 0;
      Temperature : Unsigned_8 := 0;
   end record;
   type ESC_Array is array (Motor_Index) of ESC_Data;
   type Motor_Flags is array (Motor_Index) of Boolean;

   subtype Percent is Natural range 0 .. 100;

   --  What the line reads: the clock, the arming and battery states, the
   --  rescue, the flags, the ESCs, the modes, the attitude and throttle,
   --  the signal, the temperatures and charge, the beeper and the chirp.
   type Inputs is record
      Now_Us                  : Unsigned_32 := 0;
      Battery                 : Adaflight.Battery.Battery_State := Adaflight.Battery.OK;
      Armed                   : Boolean := False;
      Was_Ever_Armed          : Boolean := False;
      GPS_Rescue_Mode         : Boolean := False;
      GPS_Rescue_OK           : Boolean := True;
      Arm_Box                 : Boolean := False;
      Disable_Flags           : Adaflight.Arming.Disable_Set := (others => False);
      Trying_To_Arm           : Boolean := False;
      Last_Beacon_Time_Us     : Unsigned_32 := 0;
      Failsafe_Active         : Boolean := False;
      ESC_Sensor_Feature      : Boolean := False;
      DShot_Telemetry         : Boolean := False;
      Motors                  : Motor_Count := 4;
      Erpm_To_Hz              : Float range 0.0 .. 1.0 := 0.0;
      ESC_Sensor              : ESC_Array;
      DShot_Sensor            : ESC_Array;
      Motor_Active            : Motor_Flags := (others => False);
      Crash_Flip_Box          : Boolean := False;
      Crash_Flip_Active       : Boolean := False;
      Launch_Control_Active   : Boolean := False;
      Acc_Present             : Boolean := False;
      Pitch_Decidegrees       : Integer_16 := 0;
      Pitch_Trim              : Integer_16 := 0;
      Throttle_Percent        : Integer range -100 .. 100 := 0;
      Launch_Throttle_Percent : Percent := 0;
      RSSI_Percent            : Percent := 0;
      RSSI_Dbm                : Integer_16 := 0;
      RSNR                    : Integer_16 := 0;
      Link_Quality_Percent    : Natural range 0 .. 300 := 0;
      Rescue_Configured       : Boolean := False;
      Rescue_Available        : Boolean := False;
      Rescue_Heading_OK       : Boolean := False;
      Armed_Time_Us           : Unsigned_32 := 0;
      Pos_Hold_Failure        : Boolean := False;
      Headfree_Mode           : Boolean := False;
      Core_Temperature        : Integer_16 := 0;
      Battery_Capacity        : Natural range 0 .. 65_535 := 0;
      MAh_Drawn               : Natural range 0 .. 2 ** 24 := 0;
      Has_Used_MAh            : Boolean := False;
      Average_Cell_Voltage    : Natural range 0 .. 65_535 := 0;
      Full_Cell_Voltage       : Natural range 0 .. 65_535 := 0;
      Visual_Beeper           : Boolean := False;
      Chirp_Repeat_Total      : Natural range 0 .. 255 := 0;
      Chirp_Repeat_Current    : Natural range 0 .. 255 := 0;
      Chirp_Finished          : Boolean := False;
      Chirp_Series_Finished   : Boolean := False;
      Chirp_Axis              : Natural range 0 .. 2 := 0;
   end record;

   --  The arming disable reason on display and when it was chosen; none
   --  starts the rotation at the lowest reason.
   type State is record
      Update_Time_Us : Unsigned_32 := 0;
      Display_Reason : Adaflight.Arming.Disable_Reason := Adaflight.Arming.No_Gyro;
      Display_Set    : Boolean := False;
   end record;

   type Text is record
      Data   : String (1 .. Max_Size) := (others => ' ');
      Length : Natural range 0 .. Max_Size := 0;
   end record;

   --  The reference's name of a reason.
   function Reason_Name (R : Adaflight.Arming.Disable_Reason) return String is
     (case R is
        when Adaflight.Arming.No_Gyro => "NOGYRO", when Adaflight.Arming.Failsafe_Active => "FAILSAFE",
        when Adaflight.Arming.Rx_Loss => "RXLOSS", when Adaflight.Arming.Not_Disarmed => "NOT_DISARMED",
        when Adaflight.Arming.Box_Failsafe => "BOXFAILSAFE", when Adaflight.Arming.Runaway_Disarm => "RUNAWAY",
        when Adaflight.Arming.Crash_Disarm => "CRASH", when Adaflight.Arming.Throttle => "THROTTLE",
        when Adaflight.Arming.Angle => "ANGLE", when Adaflight.Arming.Boot_Grace => "BOOTGRACE",
        when Adaflight.Arming.No_Prearm => "NOPREARM", when Adaflight.Arming.CPU_Load => "LOAD",
        when Adaflight.Arming.Calibrating => "CALIB", when Adaflight.Arming.CLI_Open => "CLI",
        when Adaflight.Arming.CMS_Open => "CMS", when Adaflight.Arming.BST_Open => "BST",
        when Adaflight.Arming.MSP_Open => "MSP", when Adaflight.Arming.Paralyzed => "PARALYZE",
        when Adaflight.Arming.No_GPS_Fix => "GPS", when Adaflight.Arming.Rescue_Switch => "RESCUE_SW",
        when Adaflight.Arming.DShot_Telemetry => "DSHOT_TELEM",
        when Adaflight.Arming.Reboot_Required => "REBOOT_REQD",
        when Adaflight.Arming.DShot_Bitbang => "DSHOT_BBANG", when Adaflight.Arming.Acc_Uncalibrated => "NO_ACC_CAL",
        when Adaflight.Arming.Motor_Protocol => "MOTOR_PROTO", when Adaflight.Arming.Crash_Flip_Block => "FLIP_SWITCH",
        when Adaflight.Arming.Alt_Hold_Switch => "ALT_HOLD_SW", when Adaflight.Arming.Pos_Hold_Switch => "POS_HOLD_SW",
        when Adaflight.Arming.Autopilot_Switch => "AUTOPILOT_SW", when Adaflight.Arming.Arm_Switch => "ARM_SWITCH");

   --  The line for this frame, its blink and severity, and whether it showed
   --  the visual beeper, which the target then clears.
   procedure Render (S : in out State; C : Settings; In_Flight : Inputs; Line : out Text; Blinking : out Boolean;
                     Attr : out Severity; Beeper_Shown : out Boolean);

end Adaflight.OSD_Warnings;
