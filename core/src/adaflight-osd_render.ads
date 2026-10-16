--  The OSD element renderers: the readings (altitude, angles, battery,
--  heading, vario, PIDs, power, timers, signal, flight mode, flip arrow and
--  clock), the GPS, link, ESC, motor, log, name and text elements, the
--  graphics (artificial horizon, up and down reference, stick overlays, RC
--  channels) and the VTX channel, with the craft name, pilot name, horizon
--  sidebar, camera frame and stick overlay backgrounds. Each renders one
--  element from the readings into its text, offsets, severity, blink, direct
--  writes and flags, as the draw cycle hands them to the display. The draw
--  cycle comes later; settings, sensors and readings stay with the target.
with Interfaces;
with Adaflight.Battery;
with Adaflight.Filters;
with Adaflight.VTX_Table;
with Adaflight.RTC;
with Adaflight.OSD_Format;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Warnings;
with Adaflight.OSD_Nav_Map;

package Adaflight.OSD_Render with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Adaflight.Battery.Battery_State;
   use type Adaflight.OSD_Elements.Item;
   use type Adaflight.OSD_Format.Element_Type;
   use type Adaflight.OSD_Format.Unit_System;
   use all type Adaflight.OSD_Elements.Item;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   subtype Item is Adaflight.OSD_Elements.Item;
   subtype Severity is Adaflight.OSD_Warnings.Severity;
   subtype Text is Adaflight.OSD_Format.Text;

   Max_Name : constant := 16;

   --  A name as the configuration stores it, up to sixteen characters.
   type Name is record
      Data   : String (1 .. Max_Name) := (others => ' ');
      Length : Natural range 0 .. Max_Name := 0;
   end record;

   Max_Custom_Text : constant := 40;

   --  The custom text a serial port supplies.
   type Custom_Text is record
      Data   : String (1 .. Max_Custom_Text) := (others => ' ');
      Length : Natural range 0 .. Max_Custom_Text := 0;
   end record;

   subtype Profile_Number is Adaflight.OSD_Elements.Profile_Number;
   type Profile_Names is array (Profile_Number) of Name;
   subtype Message_Index is Natural range 0 .. 3;
   type Message_Names is array (Message_Index) of Name;

   type Link_Quality_Source is (None, CRSF, GHST, MAVLink);

   subtype Motor_Count is Positive range 1 .. 8;
   subtype Motor_Index is Adaflight.OSD_Elements.Motor_Index;
   RPM_Bound    : constant := 1_000_000.0;
   Output_Bound : constant := 3_000.0;
   type Motor_RPMs is array (Motor_Index) of Float range 0.0 .. RPM_Bound;
   type Motor_ERPMs is array (Motor_Index) of Natural range 0 .. 32_767;
   type Motor_Outputs is array (Motor_Index) of Float range 0.0 .. Output_Bound;

   subtype Coordinate_Range is Integer_32 range Integer_32'First + 1 .. Integer_32'Last;

   --  Whether a render sets or clears its element's blink bit.
   type Blink_Change is (Keep, Set, Clear);

   --  A character a renderer writes to the display itself, with the blink
   --  bit in its attribute while the element blinks.
   type Char_Write is record
      X, Y, Attr : Unsigned_8 := 0;
      Char       : Character := ' ';
   end record;
   Max_Writes : constant := 2;
   subtype Write_Count is Natural range 0 .. Max_Writes;
   type Char_Writes is array (1 .. Max_Writes) of Char_Write;

   subtype RC_Channel_Index is Natural range 0 .. 17;
   RC_Low  : constant := 800.0;
   RC_High : constant := 2200.0;
   type RC_Values is array (RC_Channel_Index) of Float range RC_Low .. RC_High;
   subtype RC_Channel_Setting is Integer_8 range -1 .. 17;
   type RC_Channel_Settings is array (0 .. 3) of RC_Channel_Setting;
   type Axis_Vector is array (0 .. 2) of Float range -1.0 .. 1.0;
   subtype Radio_Mode is Positive range 1 .. 4;
   type Frame_Phases is (Top, Middle, Bottom);

   --  What a renderer hands the draw cycle: the text, whether it stored the
   --  text (the element buffer keeps its old text otherwise), the offsets
   --  from the element's position, the severity, the blink bit's change,
   --  whether the text is drawn and whether the element is complete.
   type Output is record
      Line     : Text;
      Wrote    : Boolean := True;
      Offset_X : Unsigned_8 := 0;
      Offset_Y : Unsigned_8 := 0;
      Attr     : Severity := Adaflight.OSD_Warnings.Normal;
      Blink    : Blink_Change := Keep;
      Draw     : Boolean := True;
      Rendered : Boolean := True;
      Written  : Write_Count := 0;
      Writes   : Char_Writes;
   end record;

   --  The settings the renderers read.
   type Settings is record
      Units          : Adaflight.OSD_Format.Unit_System := Adaflight.OSD_Format.Metric;
      Alt_Alarm      : Unsigned_16 := 100;
      Cap_Alarm      : Unsigned_16 := 2200;
      RSSI_Alarm     : Unsigned_8 := 20;
      RSSI_Dbm_Alarm : Integer_16 := -60;
      Timers             : Adaflight.OSD_Elements.Timer_Settings := (16#0A00#, 16#0A01#);
      Aux_Symbol         : Unsigned_8 := Character'Pos ('A');
      Link_Quality_Alarm : Unsigned_16 := 80;
      Show_PDOP          : Boolean := False;
      OSD_Profile_Index  : Profile_Number := 1;
      OSD_Profile_Names  : Profile_Names;
      Framerate_Hz       : Unsigned_16 range 1 .. 60 := 12;
      AH_Max_Pitch         : Unsigned_8 := 20;
      AH_Max_Roll          : Unsigned_8 := 40;
      AH_Invert            : Boolean := False;
      Overlay_Radio_Mode   : Radio_Mode := 2;
      RC_Channels          : RC_Channel_Settings := (others => -1);
      Camera_Frame_Width   : Unsigned_8 := 24;
      Camera_Frame_Height  : Unsigned_8 := 11;
      VTX_Band             : Unsigned_8 := 0;
      VTX_Channel          : Unsigned_8 := 0;
      VTX_Frequency        : Unsigned_16 := 0;
      VTX_Power            : Unsigned_8 := 0;
      VTX_Low_Power_Disarm : Unsigned_8 := 0;
      Nav_Map              : Adaflight.OSD_Nav_Map.Settings;
   end record;

   subtype Axis_Index is Natural range 0 .. 2;

   --  One axis's gains as the PID line prints them.
   type PID_Gains is record
      P, I, D, D_Max : Unsigned_8 := 0;
      F              : Unsigned_16 := 0;
   end record;
   type PID_Axes is array (Axis_Index) of PID_Gains;

   --  The flight modes the mode element names, in its order of precedence.
   type Mode_Flags is record
      Failsafe, GPS_Rescue, Headfree, Passthru, Pos_Hold, Alt_Hold, Chirp, Angle, Horizon : Boolean := False;
   end record;

   subtype Debug_Index is Natural range 0 .. 7;
   type Debug_Values is array (Debug_Index) of Integer_16;

   Altitude_Bound : constant := Adaflight.OSD_Format.Altitude_Bound;
   Amperage_Bound : constant := 100_000;
   Voltage_Bound  : constant := 20_000;
   MAh_Bound      : constant := 10_000_000;
   G_Force_Bound  : constant := 100_000.0;
   Wh_Bound       : constant := 100_000.0;

   subtype Yaw_Decidegrees is Integer_16 range 0 .. 3599;

   --  What the renderers read: the altitude and the sensors behind it, the
   --  attitude, the battery, the temperature and current, the debug values,
   --  the charge, the profiles and gains, the timer clocks, the signal, the
   --  switches, the flight modes, the chirp and the clock.
   type Inputs is record
      Altitude_Cm           : Integer_32 range -Altitude_Bound .. Altitude_Bound := 0;
      Altitude_Asl_Cm       : Float range -Float (Altitude_Bound) .. Float (Altitude_Bound) := 0.0;
      Baro_Present          : Boolean := False;
      GPS_Present           : Boolean := False;
      GPS_Fix               : Boolean := False;
      Roll                  : Integer_16 := 0;
      Pitch                 : Integer_16 := 0;
      Yaw                   : Yaw_Decidegrees := 0;
      Anti_Gravity          : Boolean := False;
      Cell_Voltage          : Unsigned_16 := 0;
      Battery               : Adaflight.Battery.Battery_State := Adaflight.Battery.OK;
      Min_Cell              : Unsigned_16 := 330;
      Max_Cell              : Unsigned_16 := 430;
      Core_Temperature      : Integer_16 := 0;
      Amperage              : Integer_32 range -Amperage_Bound .. Amperage_Bound := 0;
      Debug                 : Debug_Values := (others => 0);
      G_Force               : Float range -G_Force_Bound .. G_Force_Bound := 0.0;
      MAh_Drawn             : Integer_32 range -MAh_Bound .. MAh_Bound := 0;
      Wh_Drawn              : Float range 0.0 .. Wh_Bound := 0.0;
      Profile_Capacity      : Unsigned_16 := 0;
      Battery_Percent       : Unsigned_8 := 0;
      Pack_Voltage          : Unsigned_16 range 0 .. Voltage_Bound := 0;
      Vario_Cm_S            : Integer_16 := 0;
      PID_Index             : Unsigned_8 := 0;
      Rate_Index            : Unsigned_8 := 0;
      PIDs                  : PID_Axes;
      Clocks                : Adaflight.OSD_Format.Timer_Clocks;
      RSSI_Percent          : Unsigned_8 := 0;
      RSSI_Dbm              : Integer_16 := 0;
      Antenna               : Integer_8 := 0;
      RSNR                  : Integer_16 := 0;
      Throttle_Percent      : Integer_8 := 0;
      Aux_Value             : Unsigned_16 := 0;
      Ready_Box             : Boolean := False;
      Pos_Hold_Ready        : Boolean := False;
      Total_Flights         : Unsigned_32 := 0;
      Crash_Flip            : Boolean := False;
      Upright               : Boolean := True;
      Small_Angle           : Unsigned_8 := 25;
      Modes                 : Mode_Flags;
      Acro_Trainer_Box      : Boolean := False;
      Airmode               : Boolean := False;
      Chirp_Total           : Unsigned_8 := 0;
      Chirp_Current         : Unsigned_8 := 0;
      Chirp_Finished        : Boolean := False;
      Chirp_Series_Finished : Boolean := False;
      Chirp_Axis            : Axis_Index := 0;
      Has_Time              : Boolean := False;
      Date                  : Adaflight.RTC.Date_Time;
      Zone                  : Adaflight.RTC.Settings;
      GPS_Fix_Home          : Boolean := False;
      GPS_Fix_Ever          : Boolean := False;
      Latitude              : Coordinate_Range := 0;
      Longitude             : Coordinate_Range := 0;
      Satellites            : Unsigned_8 := 0;
      PDOP                  : Unsigned_16 := 0;
      Speed_3D              : Unsigned_16 := 0;
      Ground_Speed          : Unsigned_16 := 0;
      GPS_Time_Ms           : Unsigned_32 := 0;
      Home_Distance_M       : Unsigned_16 := 0;
      Home_Direction        : Yaw_Decidegrees := 0;
      Flown_Cm              : Unsigned_32 := 0;
      Use_3D_Speed          : Boolean := False;
      GPS_Healthy           : Boolean := False;
      Lap_Running           : Boolean := False;
      Lap_Last_Ms           : Unsigned_32 := 0;
      Lap_Previous_Ms       : Unsigned_32 := 0;
      Lap_Best3_Ms          : Unsigned_32 := 0;
      Lap_Direction_Cdeg    : Integer_32 range 0 .. 35_999 := 0;
      Lap_Distance_Cm       : Unsigned_32 range 0 .. 100_000_000 := 0;
      Rescue_Min_Sats       : Unsigned_8 := 8;
      Rescue_Configured     : Boolean := False;
      Link_Source           : Link_Quality_Source := None;
      Link_Quality          : Unsigned_16 range 0 .. 1023 := 0;
      RF_Mode               : Unsigned_8 := 0;
      Link_Quality_Percent  : Unsigned_16 := 0;
      Uplink_Mw             : Unsigned_16 := 0;
      Blackbox_Box          : Boolean := False;
      Blackbox_Working      : Boolean := False;
      Blackbox_Full         : Boolean := False;
      Log_Number            : Integer_32 := 0;
      ESC_Sensor_Feature    : Boolean := False;
      ESC_Temperature       : Unsigned_8 := 0;
      Motors                : Motor_Count := 4;
      DShot                 : Adaflight.OSD_Elements.Motor_Telemetry_Array;
      DShot_Telemetry       : Boolean := False;
      DShot_RPM             : Motor_RPMs := (others => 0.0);
      ESC_RPM               : Motor_ERPMs := (others => 0);
      ERPM_To_Hz            : Float range 0.0 .. 1.0 := 0.0;
      Motors_Running        : Boolean := False;
      Motor_Output          : Motor_Outputs := (others => 0.0);
      Output_Low            : Float range 0.0 .. Output_Bound := 1000.0;
      Output_High           : Float range 0.0 .. Output_Bound := 2000.0;
      Craft_Name            : Name;
      Pilot_Name            : Name;
      Rate_Profile_Name     : Name;
      PID_Profile_Name      : Name;
      Battery_Index         : Unsigned_8 := 0;
      Battery_Profile_Name  : Name;
      Messages              : Message_Names;
      Custom_Text_Present   : Boolean := False;
      Custom                : Custom_Text;
      Adjustment_Present    : Boolean := False;
      Adjustment_Name       : Name;
      Adjustment_Value      : Integer_32 := 0;
      Rangefinder_Cm        : Integer_32 := 0;
      Earth_Up                : Axis_Vector := (others => 0.0);
      RC_Data                 : RC_Values := (others => 1500.0);
      VTX                     : Adaflight.VTX_Table.Table;
      VTX_Present             : Boolean := False;
      VTX_Status_OK           : Boolean := False;
      VTX_Status              : Unsigned_8 := 0;
      VTX_Power_OK            : Boolean := False;
      VTX_Power_Index         : Unsigned_8 := 0;
      VTX_Control_Disable_Box : Boolean := False;
      Item_Blinks             : Boolean := False;
      Screen_Rows             : Unsigned_8 := 0;
      Screen_Cols             : Unsigned_8 := 0;
      Nav                     : Adaflight.OSD_Nav_Map.Inputs;
      WP_Distance_M           : Float range -1.0e9 .. 1.0e9 := -1.0;
      WP_Bearing_Deci         : Integer_32 range -1 .. 3599 := -1;
      WP_ETA_S                : Unsigned_16 := 0;
      Pitot_Present           : Boolean := False;
      Airspeed_Cm_S           : Float range -200_000.0 .. 200_000.0 := 0.0;
   end record;

   --  What persists between renders: the diversity latch of the RSSI dBm
   --  element, set once a second antenna reports, the efficiency filter, the
   --  motor the ESC elements are on, and the rows the graphics walk.
   type State is record
      Diversity        : Boolean := False;
      Efficiency       : Adaflight.Filters.PT1;
      ESC_Motor        : Unsigned_8 := 0;
      Horizon_X        : Integer range -4 .. 4 := -4;
      Sidebar_Level    : Boolean := False;
      Sidebar_Y        : Integer range -3 .. 3 := -3;
      Frame_Phase      : Frame_Phases := Top;
      Frame_Row        : Unsigned_8 := 1;
      Overlay_Vertical : Boolean := True;
      Overlay_Y        : Unsigned_8 := 0;
      RC_Channel       : Natural range 0 .. 3 := 0;
      Nav_Map          : Adaflight.OSD_Nav_Map.State;
   end record;

   --  The state at the OSD's start: the efficiency filter at half a hertz
   --  over the frame period.
   procedure Init (S : out State; C : Settings)
     with Post => S.Diversity = False and then S.ESC_Motor = 0;

   --  The items this unit renders.
   function Supported (I : Item) return Boolean is
     (I in Altitude | Pitch_Angle | Roll_Angle | Anti_Gravity | Average_Cell_Voltage | Compass_Bar | Core_Temperature
         | Crosshairs | Current_Draw | Debug | Debug2 | Disarmed | G_Force | MAh_Drawn | Watt_Hours_Drawn
         | Main_Battery_Usage | Main_Battery_Voltage | Numerical_Heading | Numerical_Vario | PID_Rate_Profile
         | Roll_PIDs | Pitch_PIDs | Yaw_PIDs | Power | Remaining_Time_Estimate | RSSI_Value | RSSI_Dbm_Value
         | RSNR_Value | Throttle_Position | Timer_1 | Timer_2 | Aux_Value | Ready_Mode | Position_Hold_Ready
         | Total_Flights | Flip_Arrow | Fly_Mode | RTC_Date_Time | Flight_Distance | Home_Direction | Home_Distance
         | GPS_Longitude | GPS_Latitude | GPS_Sats | GPS_Speed | Efficiency | GPS_Lap_Time_Current
         | GPS_Lap_Time_Previous | GPS_Lap_Time_Best3 | Link_Quality | TX_Uplink_Power | Log_Status | ESC_Temperature
         | ESC_RPM | ESC_RPM_Frequency | Motor_Diagnostics | Rate_Profile_Name | PID_Profile_Name | Profile_Name
         | Battery_Profile_Name | Custom_Message_0 | Custom_Message_1 | Custom_Message_2 | Custom_Message_3
         | Custom_Serial_Text | Adjustment_Range | Lidar_Distance | Artificial_Horizon | Up_Down_Reference
         | Stick_Overlay_Left | Stick_Overlay_Right | RC_Channels | VTX_Channel | WP_Number | WP_Current_Lat
         | WP_Current_Lon | WP_Current_Alt | WP_Distance | WP_Direction | WP_Next_Number | WP_ETA | Airspeed);

   --  The items whose background this unit renders.
   function Background_Supported (I : Item) return Boolean is
     (I in Craft_Name | Pilot_Name | Horizon_Sidebars | Camera_Frame | Stick_Overlay_Left | Stick_Overlay_Right);

   procedure Render (I : Item; Variant : Adaflight.OSD_Format.Element_Type; S : in out State; C : Settings;
                     Inp : Inputs; O : out Output)
     with Pre => Supported (I) and then Inp.Min_Cell /= Inp.Max_Cell and then Inp.Date.Month in 1 .. 12
                 and then Integer_32 (Float'Truncation (Inp.Output_High))
                          > Integer_32 (Float'Truncation (Inp.Output_Low))
                 and then (if I in ESC_RPM | ESC_RPM_Frequency then S.ESC_Motor < Unsigned_8 (Inp.Motors));

   procedure Render_Background (I : Item; S : in out State; C : Settings; Inp : Inputs; Pos_X, Pos_Y : Unsigned_8;
                                O : out Output)
     with Pre => Background_Supported (I);

   --  The navigation map's row at the element's position.
   procedure Render_Nav_Map (S : in out State; C : Settings; Inp : Inputs; Pos_X, Pos_Y : Unsigned_8; O : out Output);

   --  The craft name as the configuration stores it: sixteen characters and
   --  the terminator.
   subtype Craft_Name_Buffer is String (1 .. Max_Name + 1);

   --  The warnings element: the warnings line with its blink and severity.
   --  With the craft name messages on, the link quality replaces the line
   --  while the blink hides it or the line is empty, and the first fifteen
   --  characters go to the craft name, zero filled after a shorter text;
   --  the line's reports go to the caller.
   procedure Render_Warnings
     (WS : in out Adaflight.OSD_Warnings.State; WC : Adaflight.OSD_Warnings.Settings;
      WI : Adaflight.OSD_Warnings.Inputs; Craft_Name_Messages, Blink_State : Boolean; Inp : Inputs;
      Craft : in out Craft_Name_Buffer; O : out Output; Reported : out Adaflight.OSD_Warnings.Reports);

end Adaflight.OSD_Render;
