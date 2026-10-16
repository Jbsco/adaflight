--  The OSD elements' bookkeeping: the item set with its position fields and
--  profile visibility, the blink bits the alarms set over the half second
--  cadence the display follows, and the list of the active elements in the
--  reference's display order. The renderers and the draw cycle come later;
--  the settings, the sensors and the readings stay with the target.
with Interfaces;
with Adaflight.Battery;
with Adaflight.OSD_Format;

package Adaflight.OSD_Elements with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Adaflight.Battery.Battery_State;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   --  The items in the reference's order, which fixes each one's place in
   --  the position table and in the blink bits.
   type Item is
     (RSSI_Value, Main_Battery_Voltage, Crosshairs, Artificial_Horizon, Horizon_Sidebars, Timer_1, Timer_2,
      Fly_Mode, Craft_Name, Throttle_Position, VTX_Channel, Current_Draw, MAh_Drawn, GPS_Speed, GPS_Sats,
      Altitude, Roll_PIDs, Pitch_PIDs, Yaw_PIDs, Power, PID_Rate_Profile, Warnings, Average_Cell_Voltage,
      GPS_Longitude, GPS_Latitude, Debug, Pitch_Angle, Roll_Angle, Main_Battery_Usage, Disarmed,
      Home_Direction, Home_Distance, Numerical_Heading, Numerical_Vario, Compass_Bar, ESC_Temperature,
      ESC_RPM, Remaining_Time_Estimate, RTC_Date_Time, Adjustment_Range, Core_Temperature, Anti_Gravity,
      G_Force, Motor_Diagnostics, Log_Status, Flip_Arrow, Link_Quality, Flight_Distance, Stick_Overlay_Left,
      Stick_Overlay_Right, Pilot_Name, ESC_RPM_Frequency, Rate_Profile_Name, PID_Profile_Name, Profile_Name,
      RSSI_Dbm_Value, RC_Channels, Camera_Frame, Efficiency, Total_Flights, Up_Down_Reference,
      TX_Uplink_Power, Watt_Hours_Drawn, Aux_Value, Ready_Mode, RSNR_Value, Sys_Goggle_Voltage,
      Sys_VTX_Voltage, Sys_Bitrate, Sys_Delay, Sys_Distance, Sys_Link_Quality, Sys_Goggle_DVR, Sys_VTX_DVR,
      Sys_Warnings, Sys_VTX_Temperature, Sys_Fan_Speed, GPS_Lap_Time_Current, GPS_Lap_Time_Previous,
      GPS_Lap_Time_Best3, Debug2, Custom_Message_0, Custom_Message_1, Custom_Message_2, Custom_Message_3,
      Lidar_Distance, Custom_Serial_Text, Battery_Profile_Name, WP_Number, WP_Current_Lat, WP_Current_Lon,
      WP_Current_Alt, WP_Distance, WP_Direction, WP_Next_Number, WP_ETA, Nav_Map, Position_Hold_Ready, Airspeed);

   Item_Count : constant := 99;

   type Positions is array (Item) of Unsigned_16;
   type Item_Set is array (Item) of Boolean;

   --  A position field: the column in bits 0 to 4 and 10, the row in bits 5
   --  to 9, the profiles in bits 11 to 13, the variant in bits 14 and 15.
   Profile_Count : constant := 3;
   subtype Profile_Index is Natural range 0 .. Profile_Count;
   subtype Profile_Number is Positive range 1 .. Profile_Count;
   subtype Profile_Mask is Unsigned_16 range 1 .. 4;

   function Profile_Of (Index : Profile_Index) return Profile_Mask is
     (case Index is when 0 | 1 => 1, when 2 => 2, when 3 => 4);

   function Column (P : Unsigned_16) return Unsigned_8 is
     (Unsigned_8 ((P and 16#1F#) or Interfaces.Shift_Right (P and 16#0400#, 5)));

   function Row (P : Unsigned_16) return Unsigned_8 is
     (Unsigned_8 (Interfaces.Shift_Right (P, 5) and 16#1F#));

   function Variant (P : Unsigned_16) return Adaflight.OSD_Format.Element_Type is
     (Adaflight.OSD_Format.Element_Type'Val (Interfaces.Shift_Right (P, 14)));

   function Make_Position (X, Y : Unsigned_8) return Unsigned_16 is
     ((Unsigned_16 (X) and 16#1F#) or (Interfaces.Shift_Left (Unsigned_16 (X), 5) and 16#0400#)
      or Interfaces.Shift_Left (Unsigned_16 (Y) and 16#1F#, 5));

   function Visible (P : Unsigned_16; Profile : Profile_Mask) return Boolean is
     ((Interfaces.Shift_Right (P and 16#3800#, 11) and Profile) /= 0);

   function Visible_In_Profile (P : Unsigned_16; N : Profile_Number) return Boolean is
     (Visible (P, Profile_Of (N)));

   Blink_Period_Us : constant := 500_000;

   --  The bits the alarms set and the state of the half second cadence; an
   --  item blinks while its bit is set in the on half.
   type Blink is record
      Bits  : Item_Set := (others => False);
      State : Boolean := True;
   end record;

   function Is_Blink (B : Blink; I : Item) return Boolean is (B.Bits (I) and then B.State);

   procedure Sync_Blink (B : in out Blink; Now_Us : Unsigned_32)
     with Post => B.Bits = B.Bits'Old and then B.State = ((Now_Us mod Blink_Period_Us) < Blink_Period_Us / 2);

   procedure Reset_Alarms (B : in out Blink)
     with Post => B.Bits = Item_Set'(others => False) and then B.State = B.State'Old;

   subtype Timer_Index is Natural range 0 .. 1;
   type Timer_Settings is array (Timer_Index) of Unsigned_16;

   --  The alarm thresholds; the capacity alarm yields to the battery
   --  profile's capacity, the ESC temperature alarm is off at zero.
   type Alarm_Settings is record
      Units              : Adaflight.OSD_Format.Unit_System := Adaflight.OSD_Format.Metric;
      RSSI_Alarm         : Unsigned_8 := 20;
      RSSI_Dbm_Alarm     : Integer_16 := -60;
      Link_Quality_Alarm : Unsigned_16 := 80;
      Timers             : Timer_Settings := (16#0A00#, 16#0A01#);
      Cap_Alarm          : Unsigned_16 := 2200;
      Alt_Alarm          : Unsigned_16 := 100;
      Distance_Alarm     : Unsigned_16 := 0;
      ESC_Temp_Alarm     : Unsigned_8 := 0;
      Rescue_Min_Sats    : Unsigned_8 := 8;
   end record;

   subtype Motor_Count is Natural range 0 .. 8;
   subtype Motor_Index is Natural range 0 .. 7;

   --  One ESC's DShot telemetry: whether a temperature arrived, and its value.
   type Motor_Telemetry is record
      Has_Temperature : Boolean := False;
      Temperature     : Unsigned_16 := 0;
   end record;
   type Motor_Telemetry_Array is array (Motor_Index) of Motor_Telemetry;

   Altitude_Bound : constant := 600_000_000;
   subtype Altitude_Range is Integer_32 range -Altitude_Bound .. Altitude_Bound;

   --  What the alarms read: the altitude, the signal, the battery, the GPS
   --  fix and satellites, the rescue, the timer clocks, the battery profile's
   --  capacity, the charge drawn, the home distance and the ESC temperatures.
   type Alarm_Inputs is record
      Altitude_Cm        : Altitude_Range := 0;
      RSSI_Percent       : Unsigned_8 := 0;
      RSSI_Dbm           : Integer_16 := 0;
      Link_Quality       : Unsigned_16 := 0;
      Battery            : Adaflight.Battery.Battery_State := Adaflight.Battery.OK;
      GPS_Present        : Boolean := False;
      GPS_Fix            : Boolean := False;
      GPS_Fix_Home       : Boolean := False;
      Satellites         : Unsigned_8 := 0;
      Rescue_Configured  : Boolean := False;
      Clocks             : Adaflight.OSD_Format.Timer_Clocks;
      Profile_Capacity   : Unsigned_16 := 0;
      MAh_Drawn          : Integer_32 := 0;
      Home_Distance_M    : Unsigned_16 := 0;
      ESC_Sensor_Feature : Boolean := False;
      ESC_Temperature    : Unsigned_8 := 0;
      Motors             : Motor_Count := 4;
      DShot              : Motor_Telemetry_Array;
   end record;

   function Capacity_Alarm (C : Alarm_Settings; Profile_Capacity : Unsigned_16) return Unsigned_16 is
     (if Profile_Capacity > 0 then Profile_Capacity else C.Cap_Alarm);

   --  The altitude the alarm compares: the selected unit's value over a
   --  hundred, truncated.
   function Alarm_Altitude (Alt : Altitude_Range; Units : Adaflight.OSD_Format.Unit_System) return Integer_32;

   procedure Update_Alarms (B : in out Blink; C : Alarm_Settings; Inp : Alarm_Inputs)
     with Post => B.State = B.State'Old;

   --  The adds of a list with every item visible; two items are added twice.
   Max_Active : constant := 101;
   subtype Active_Count is Natural range 0 .. Max_Active;
   type Item_List is array (1 .. Max_Active) of Item;

   type Active_List is record
      Items : Item_List := (others => Item'First);
      Count : Active_Count := 0;
   end record;

   Display_Order : constant array (1 .. 73) of Item :=
     (Main_Battery_Voltage, RSSI_Value, Crosshairs, Horizon_Sidebars, Up_Down_Reference, Timer_1, Timer_2,
      Remaining_Time_Estimate, Fly_Mode, Throttle_Position, VTX_Channel, Current_Draw, MAh_Drawn,
      Watt_Hours_Drawn, Craft_Name, Custom_Message_0, Custom_Message_1, Custom_Message_2, Custom_Message_3,
      Altitude, Roll_PIDs, Pitch_PIDs, Yaw_PIDs, Power, PID_Rate_Profile, Warnings, Average_Cell_Voltage,
      Debug, Debug2, Pitch_Angle, Roll_Angle, Main_Battery_Usage, Disarmed, Numerical_Heading, Ready_Mode,
      Position_Hold_Ready, Numerical_Vario, Compass_Bar, Anti_Gravity, Log_Status, Motor_Diagnostics,
      Flip_Arrow, Pilot_Name, RTC_Date_Time, Adjustment_Range, Core_Temperature, Link_Quality,
      TX_Uplink_Power, RSSI_Dbm_Value, RSNR_Value, Stick_Overlay_Left, Stick_Overlay_Right,
      Rate_Profile_Name, PID_Profile_Name, Battery_Profile_Name, Profile_Name, RC_Channels, Camera_Frame,
      Total_Flights, Aux_Value, Sys_Goggle_Voltage, Sys_VTX_Voltage, Sys_Bitrate, Sys_Delay, Sys_Distance,
      Sys_Link_Quality, Sys_Goggle_DVR, Sys_VTX_DVR, Sys_Warnings, Sys_VTX_Temperature, Sys_Fan_Speed,
      Lidar_Distance, Custom_Serial_Text);

   --  The sensors and features the active list reads.
   type Element_Inputs is record
      Acc_Present        : Boolean := False;
      GPS_Present        : Boolean := False;
      ESC_Sensor_Feature : Boolean := False;
      DShot_Telemetry    : Boolean := False;
   end record;

   procedure Add_Active_Elements (A : out Active_List; Pos : Positions; Profile : Profile_Mask; Inp : Element_Inputs);

   function Is_Active (A : Active_List; I : Item) return Boolean is
     (for some K in 1 .. A.Count => A.Items (K) = I);

   function Need_Accelerometer (A : Active_List) return Boolean is
     (Is_Active (A, Artificial_Horizon) or else Is_Active (A, Pitch_Angle) or else Is_Active (A, Roll_Angle)
      or else Is_Active (A, G_Force) or else Is_Active (A, Flip_Arrow) or else Is_Active (A, Up_Down_Reference));

end Adaflight.OSD_Elements;
