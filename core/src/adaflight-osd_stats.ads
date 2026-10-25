--  The OSD statistics: the extremes tracked while armed from the readings
--  of each cycle, and the text of every statistic on the page after a
--  flight with its label, from the extremes, the settings and the readings
--  of the moment. The readings, the settings and the display stay with the
--  target.
with Interfaces;
with Adaflight.OSD_Format;
with Adaflight.RTC;

package Adaflight.OSD_Stats with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   --  The statistics in the reference's numbering, and the order the page
   --  shows them in.
   type Stat is
     (RTC_Date_Time, Timer_1, Timer_2, Max_Speed, Max_Distance, Min_Battery, End_Battery, Battery, Min_RSSI,
      Max_Current, Used_MAh, Max_Altitude, Blackbox, Blackbox_Number, Max_G_Force, Max_ESC_Temp, Max_ESC_RPM,
      Min_Link_Quality, Flight_Distance, Max_FFT, Total_Flights, Total_Time, Total_Dist, Min_RSSI_Dbm,
      Watt_Hours_Drawn, Min_RSNR, Best_3_Consec_Laps, Best_Lap, Full_Throttle_Time, Full_Throttle_Counter,
      Avg_Throttle);
   type Stat_Set is array (Stat) of Boolean;
   type Display_Order is array (1 .. 31) of Stat;
   Order : constant Display_Order :=
     (RTC_Date_Time, Timer_1, Timer_2, Max_Altitude, Max_Speed, Max_Distance, Flight_Distance, Min_Battery,
      End_Battery, Battery, Min_RSSI, Max_Current, Used_MAh, Blackbox, Blackbox_Number, Max_G_Force, Max_ESC_Temp,
      Max_ESC_RPM, Min_Link_Quality, Max_FFT, Min_RSSI_Dbm, Min_RSNR, Total_Flights, Total_Time, Total_Dist,
      Watt_Hours_Drawn, Best_3_Consec_Laps, Best_Lap, Full_Throttle_Time, Full_Throttle_Counter, Avg_Throttle);

   subtype G_Force is Float range -1.0e6 .. 1.0e6;

   --  The extremes of a flight, in the reference's widths: speeds, voltages,
   --  currents, distances and temperatures as sixteen-bit values.
   type Statistics is record
      Armed_Time_Us    : Unsigned_32 := 0;
      Max_Speed        : Integer_16 := 0;
      Min_Voltage      : Integer_16 := 0;
      End_Voltage      : Unsigned_16 := 0;
      Max_Current      : Integer_16 := 0;
      Min_RSSI         : Unsigned_8 := 0;
      Max_Altitude     : Integer_32 := 0;
      Max_Distance     : Unsigned_16 := 0;
      Max_G_Force      : G_Force := 0.0;
      Max_ESC_Temp_Ix  : Integer_16 := 0;
      Max_ESC_Temp     : Integer_16 := 0;
      Max_ESC_RPM      : Integer_32 := 0;
      Min_Link_Quality : Unsigned_16 := 0;
      Min_RSSI_Dbm     : Integer_16 := 0;
      Min_RSNR         : Integer_16 := 0;
   end record;

   subtype Motor_Index is Natural range 0 .. 7;
   subtype Motor_Count is Natural range 0 .. 8;
   type Temperatures is array (Motor_Index) of Unsigned_8;
   subtype Erpm is Natural range 0 .. 32_767;
   subtype Rpm_Average is Float range -1.0e7 .. 1.0e7;

   --  The readings one update compares: the speeds, the voltages and
   --  which one the statistics track, the current, the signal, the
   --  altitude, the acceleration, the home distance with its fixes, and
   --  the ESC temperatures and rotation from the sensor or the telemetry.
   type Readings is record
      Speed_3D             : Unsigned_16 := 0;
      Ground_Speed         : Unsigned_16 := 0;
      Use_3D_Speed         : Boolean := False;
      Pack_Voltage         : Unsigned_16 := 0;
      Cell_Voltage         : Unsigned_16 := 0;
      Show_Cell_Value      : Boolean := False;
      Amperage             : Integer_32 := 0;
      RSSI_Percent         : Unsigned_8 := 0;
      Altitude_Cm          : Integer_32 := 0;
      Acceleration         : G_Force := 0.0;
      Link_Quality_Percent : Unsigned_16 := 0;
      RSSI_Dbm             : Integer_16 := 0;
      RSNR                 : Integer_16 := 0;
      GPS_Fix              : Boolean := False;
      GPS_Fix_Home         : Boolean := False;
      Distance_To_Home     : Unsigned_16 := 0;
      ESC_Sensor_Feature   : Boolean := False;
      ESC_Temperature      : Unsigned_8 := 0;
      ESC_Erpm             : Erpm := 0;
      Erpm_To_Hz           : Float range 0.0 .. 1.0 := 0.0;
      DShot_Telemetry      : Boolean := False;
      Motors               : Motor_Count := 0;
      DShot_Max_Temp       : Temperatures := (others => 0);
      DShot_RPM_Average    : Rpm_Average := 0.0;
   end record;

   function Stats_Voltage (R : Readings) return Unsigned_16 is
     (if R.Show_Cell_Value then R.Cell_Voltage else R.Pack_Voltage);

   --  The reset at arming: the extremes at their far ends, the link quality
   --  floor at 99 without a link quality source and 100 with one.
   procedure Reset (S : out Statistics; Has_Link_Quality_Source : Boolean);

   --  The average ESC rotation: the sensor's combined reading converted, the
   --  telemetry's average, or zero without either.
   function Average_ESC_RPM (R : Readings) return Integer_32;

   --  One update while armed: each extreme against its reading, the ESC
   --  temperature from the sensor when its feature is on and from the
   --  telemetry's per-motor maxima otherwise, with the motor that set it.
   procedure Update (S : in out Statistics; R : Readings);

   subtype Watt_Hours is Float range 0.0 .. 1.0e5;

   --  What the page reads beyond the extremes: the units, the timers and
   --  their clocks, the meters present, the charge drawn, the flight log
   --  device and its storage, the sensors present, the persistent totals,
   --  the lap times, the throttle statistics and the clock.
   type Page is record
      Units                 : Adaflight.OSD_Format.Unit_System := Adaflight.OSD_Format.Metric;
      Timer_1               : Unsigned_16 := 0;
      Timer_2               : Unsigned_16 := 0;
      Clocks                : Adaflight.OSD_Format.Timer_Clocks;
      Show_Cell_Value       : Boolean := False;
      GPS_Feature           : Boolean := False;
      Current_Meter         : Boolean := False;
      Pack_Voltage          : Unsigned_16 := 0;
      Cell_Voltage          : Unsigned_16 := 0;
      Flight_Distance_Cm    : Unsigned_32 := 0;
      MAh_Drawn             : Integer_32 := 0;
      Wh_Drawn              : Watt_Hours := 0.0;
      Blackbox_Device       : Natural range 0 .. 3 := 0;
      Blackbox_Working      : Boolean := False;
      SD_Blocks             : Unsigned_32 := 0;
      SD_Free_Bytes         : Unsigned_32 := 0;
      Flash_Sectors         : Unsigned_32 := 0;
      Flash_Sector_Size     : Unsigned_32 := 0;
      Flash_Offset          : Unsigned_32 := 0;
      Log_Number            : Integer_32 := -1;
      Acc_Present           : Boolean := False;
      Dyn_Notch_Active      : Boolean := False;
      Max_FFT               : Integer_32 := 0;
      Total_Flights         : Unsigned_32 := 0;
      Total_Time_S          : Unsigned_32 := 0;
      Total_Dist_M          : Unsigned_32 := 0;
      Best_3_Consec_Ms      : Unsigned_32 := 0;
      Best_Lap_Ms           : Unsigned_32 := 0;
      Full_Throttle_Time_Us : Unsigned_32 := 0;
      Full_Throttle_Count   : Unsigned_32 := 0;
      Average_Throttle      : Integer_8 := 0;
      RTC_Variant           : Adaflight.OSD_Format.Element_Type := Adaflight.OSD_Format.Type_1;
      Has_Time              : Boolean := False;
      Date                  : Adaflight.RTC.Date_Time;
      Zone                  : Adaflight.RTC.Settings;
   end record;

   Device_Flash  : constant := 1;
   Device_SDCard : constant := 2;

   --  The flight log storage in kilobytes: the card's blocks over two
   --  thousand, or the flash partition's sectors by their size.
   function Storage_Total (P : Page) return Unsigned_32 is
     (if not P.Blackbox_Working then 0
      elsif P.Blackbox_Device = Device_SDCard then P.SD_Blocks / 2_000
      elsif P.Blackbox_Device = Device_Flash then (P.Flash_Sectors * P.Flash_Sector_Size) / 1_024
      else 0);

   --  The statistic's text: shown or not, with its label beside the value
   --  or the value alone across the label's place.
   type Stat_Line is record
      Shown   : Boolean := False;
      Labeled : Boolean := True;
      Label   : Adaflight.OSD_Format.Text;
      Value   : Adaflight.OSD_Format.Text;
   end record;

   Altitude_Bound : constant := 40_000_000;

   --  A lap time in seconds and hundredths, rounded, or blank at zero.
   procedure Lap_Time (Ms : Unsigned_32; T : out Adaflight.OSD_Format.Text);

   --  The storage used in percent, or a fault when the device is not
   --  working.
   procedure Blackbox_Status (P : Page; T : out Adaflight.OSD_Format.Text)
     with Pre => not P.Blackbox_Working or else Storage_Total (P) > 0;

   --  The text of one statistic.
   procedure Stat_Text (Which : Stat; S : Statistics; P : Page; Line : out Stat_Line)
     with Pre => P.Date.Month in 1 .. 12
                 and then Adaflight.OSD_Format.Timer_Source_Of (P.Timer_1) <= 4
                 and then Adaflight.OSD_Format.Timer_Source_Of (P.Timer_2) <= 4
                 and then S.Max_Altitude in -Altitude_Bound .. Altitude_Bound
                 and then (not P.Blackbox_Working or else P.Blackbox_Device not in Device_Flash | Device_SDCard
                           or else Storage_Total (P) > 0);

end Adaflight.OSD_Stats;
