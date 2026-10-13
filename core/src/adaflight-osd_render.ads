--  The OSD element renderers that format readings: altitude, angles,
--  battery, heading, vario, PIDs, power, timers, signal, flight mode, flip
--  arrow and clock. Each renders one element from the readings into its
--  text, offsets, severity and flags, as the draw cycle hands them to the
--  display. The graphics, GPS, link, ESC and name elements come later;
--  settings, sensors and readings stay with the target.
with Interfaces;
with Adaflight.Battery;
with Adaflight.RTC;
with Adaflight.OSD_Format;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Warnings;

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

   --  What a renderer hands the draw cycle: the text, the offsets from the
   --  element's position, the severity, whether the text is drawn and
   --  whether the element is complete.
   type Output is record
      Line     : Text;
      Offset_X : Unsigned_8 := 0;
      Offset_Y : Unsigned_8 := 0;
      Attr     : Severity := Adaflight.OSD_Warnings.Normal;
      Draw     : Boolean := True;
      Rendered : Boolean := True;
   end record;

   --  The settings the renderers read.
   type Settings is record
      Units          : Adaflight.OSD_Format.Unit_System := Adaflight.OSD_Format.Metric;
      Alt_Alarm      : Unsigned_16 := 100;
      Cap_Alarm      : Unsigned_16 := 2200;
      RSSI_Alarm     : Unsigned_8 := 20;
      RSSI_Dbm_Alarm : Integer_16 := -60;
      Timers         : Adaflight.OSD_Elements.Timer_Settings := (16#0A00#, 16#0A01#);
      Aux_Symbol     : Unsigned_8 := Character'Pos ('A');
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
   end record;

   --  What persists between renders: the diversity latch of the RSSI dBm
   --  element, set once a second antenna reports.
   type State is record
      Diversity : Boolean := False;
   end record;

   --  The items this unit renders.
   function Supported (I : Item) return Boolean is
     (I in Altitude | Pitch_Angle | Roll_Angle | Anti_Gravity | Average_Cell_Voltage | Compass_Bar | Core_Temperature
         | Crosshairs | Current_Draw | Debug | Debug2 | Disarmed | G_Force | MAh_Drawn | Watt_Hours_Drawn
         | Main_Battery_Usage | Main_Battery_Voltage | Numerical_Heading | Numerical_Vario | PID_Rate_Profile
         | Roll_PIDs | Pitch_PIDs | Yaw_PIDs | Power | Remaining_Time_Estimate | RSSI_Value | RSSI_Dbm_Value
         | RSNR_Value | Throttle_Position | Timer_1 | Timer_2 | Aux_Value | Ready_Mode | Position_Hold_Ready
         | Total_Flights | Flip_Arrow | Fly_Mode | RTC_Date_Time);

   procedure Render (I : Item; Variant : Adaflight.OSD_Format.Element_Type; S : in out State; C : Settings;
                     Inp : Inputs; O : out Output)
     with Pre => Supported (I) and then Inp.Min_Cell /= Inp.Max_Cell and then Inp.Date.Month in 1 .. 12;

end Adaflight.OSD_Render;
