--  The OSD display of the board: the MAX7456 chip's select pin held from the
--  start, the chip and its display port started over the chip's SPI bus when
--  the OSD feature is on and the display device setting allows it, the
--  stored canvas fitted to the display, the readiness the OSD replies report
--  and the font characters a configurator writes.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Battery;
with Adaflight.Config_Groups;
with Adaflight.ESC_Sensor;
with Adaflight.MSP_Font_In;
with Adaflight.OSD_Render;
with Adaflight.OSD_Task;
with Adaflight.Scheduler;
with Adaflight.STM32.GPS;
package Adaflight.STM32.OSD is
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   --  The select pin as the stored configuration names it, before the SPI
   --  buses start: driven high when the configuration asks for it, else an
   --  input with its pull up.
   procedure Preinit (C : Adaflight.Config_Groups.Configuration);

   --  The display device the configuration selects, started with the OSD
   --  feature on. Disable_Feature says no display started, which turns the
   --  feature off until the next start.
   procedure Init
     (C : in out Adaflight.Config_Groups.Configuration; Feature_OSD : Boolean; Disable_Feature : out Boolean);

   function Device return Adaflight.OSD_Task.Device_Kind;
   function Port_Present return Boolean;
   --  The display's columns and rows, zero before the chip answers.
   procedure Dimensions (Columns, Rows : out Interfaces.Unsigned_8);

   --  The display's readiness for the OSD replies: a chip that did not
   --  answer is started again first, with a redraw while disarmed.
   procedure Check_Ready (C : Adaflight.Config_Groups.Configuration; Armed : Boolean; Ready : out Boolean);

   --  The display as the menu takes it: grabbed and released, cleared,
   --  its layer and background selected, redrawn while disarmed, its
   --  heartbeat run, and text written at a position; Grabbed while the
   --  menu holds it, which the OSD task waits out.
   procedure Menu_Grab;
   procedure Menu_Release;
   function Grabbed return Boolean;
   procedure Menu_Clear;
   procedure Menu_Layer_Select (Layer : Natural);
   procedure Menu_Background (Kind : Natural);
   procedure Menu_Redraw (Armed : Boolean);
   procedure Menu_Heartbeat;
   procedure Menu_Write (X, Y : Interfaces.Unsigned_8; Text : String);

   --  Whether a font character write goes to the chip, which needs it found.
   function Font_Write_Taken return Boolean;
   procedure Write_Font (Address : Interfaces.Unsigned_16; Data : Adaflight.MSP_Font_In.Character_Data);

   --  What the OSD reads from the flight at a frame: the arming and its
   --  reasons, the failsafe, the boxes and flight modes, the attitude in
   --  decidegrees, the acceleration in g, the throttle and the sticks, the
   --  RSSI and the link's quality, the battery in centivolts, centiamps and milliamp hours, the
   --  motors with their outputs and range, which of them run above the disarm output, the ESC
   --  sensor's readings over every motor and for each one, the profiles, the
   --  estimated altitude and climb rate, the adjustment shown with its value,
   --  and the flight totals.
   type Motor_Flags is array (Adaflight.OSD_Render.Motor_Index) of Boolean;
   type Facts is record
      Armed             : Boolean := False;
      Was_Ever_Armed    : Boolean := False;
      Failsafe_Active   : Boolean := False;
      Trying_To_Arm     : Boolean := False;
      Arm_Box           : Boolean := False;
      OSD_Switch        : Boolean := False;
      Disabled          : Adaflight.Arming.Disable_Set := (others => False);
      Modes             : Adaflight.Arming.Mode_Set := (others => False);
      Airmode           : Boolean := False;
      Anti_Gravity      : Boolean := False;
      Crash_Flip_Box    : Boolean := False;
      Crash_Flip_Active : Boolean := False;
      Launch_Control    : Boolean := False;
      Acc_Present       : Boolean := False;
      G_Force           : Float range 0.0 .. 100.0 := 0.0;
      Roll              : Interfaces.Integer_16 := 0;
      Pitch             : Interfaces.Integer_16 := 0;
      Yaw               : Adaflight.OSD_Render.Yaw_Decidegrees := 0;
      Throttle_Percent  : Integer range -100 .. 100 := 0;
      Throttle_High     : Boolean := False;
      Pitch_High        : Boolean := False;
      Aux_Rc            : Float range 0.0 .. 5_000.0 := 1_500.0;
      RSSI_Percent      : Interfaces.Unsigned_8 range 0 .. 100 := 0;
      RSSI_Dbm          : Interfaces.Integer_16 := -130;
      RSNR              : Interfaces.Integer_16 := -30;
      Link_Quality      : Interfaces.Unsigned_16 range 0 .. 1_023 := 0;
      Link_Percent      : Interfaces.Unsigned_16 range 0 .. 300 := 0;
      Link_Source       : Adaflight.OSD_Render.Link_Quality_Source := Adaflight.OSD_Render.None;
      RF_Mode           : Interfaces.Unsigned_8 := 0;
      Uplink_mW         : Interfaces.Unsigned_16 := 0;
      GPS_Feature       : Boolean := False;
      GPS               : Adaflight.STM32.GPS.Readings;
      Battery           : Adaflight.Battery.Battery_State := Adaflight.Battery.OK;
      Pack_Voltage      : Interfaces.Unsigned_16 range 0 .. 20_000 := 0;
      Cell_Voltage      : Interfaces.Unsigned_16 := 0;
      Full_Cell_Voltage : Interfaces.Unsigned_16 := 410;
      Amperage          : Interfaces.Integer_32 range -100_000 .. 100_000 := 0;
      MAh_Drawn         : Interfaces.Integer_32 range 0 .. 2 ** 24 := 0;
      Battery_Percent   : Interfaces.Unsigned_8 := 0;
      Battery_Capacity  : Interfaces.Unsigned_16 := 0;
      Motors            : Adaflight.OSD_Render.Motor_Count := 4;
      Motor_Output      : Adaflight.OSD_Render.Motor_Outputs := (others => 0.0);
      Output_Low        : Float range 0.0 .. 3_000.0 := 1_000.0;
      Output_High       : Float range 0.0 .. 3_000.0 := 2_000.0;
      Motors_Running    : Boolean := False;
      Motor_Active      : Motor_Flags := (others => False);
      ESC_Feature       : Boolean := False;
      ESC_Erpm_To_Hz    : Float range 0.0 .. 1.0 := 0.0;
      ESC_Combined      : Adaflight.ESC_Sensor.Reading;
      ESC_Motors        : Adaflight.ESC_Sensor.Readings;
      PID_Index         : Interfaces.Unsigned_8 := 0;
      Rate_Index        : Interfaces.Unsigned_8 := 0;
      Altitude_Cm       : Interfaces.Integer_32 range -40_000_000 .. 40_000_000 := 0;
      Adjustment_Present : Boolean := False;
      Adjustment_Name    : Adaflight.OSD_Render.Name;
      Adjustment_Value   : Interfaces.Integer_32 := 0;
      Total_Flights      : Interfaces.Unsigned_32 := 0;
      Total_Time_S       : Interfaces.Unsigned_32 := 0;
      Total_Dist_M       : Interfaces.Unsigned_32 := 0;
      Vario             : Interfaces.Integer_16 := 0;
      Pos_Hold_Ready    : Boolean := False;
      Pos_Hold_Failure  : Boolean := False;
      Rescue_Configured : Boolean := False;
      Rescue_Available  : Boolean := False;
      Rescue_OK         : Boolean := True;
      Rescue_Heading_OK : Boolean := False;
   end record;

   --  The OSD's settings from the stored configuration and the firmware's
   --  version for its boot screen, again after the configuration changes.
   procedure Configure (C : Adaflight.Config_Groups.Configuration; Version : String)
     with Pre => Version'Length in 1 .. Adaflight.OSD_Task.Max_Version;

   --  The element positions analyzed again at the next frame.
   procedure Analyze_Again;

   --  The OSD task's check: due once a frame is.
   function Task_Due (Now_Us : Interfaces.Unsigned_32) return Boolean;

   --  One state of the OSD task: the display's answers for the state taken
   --  first, then the state, then its operations done on the display.
   procedure Run (F : Facts; Now_Us : Interfaces.Unsigned_32; Sched : in out Adaflight.Scheduler.State);
end Adaflight.STM32.OSD;
