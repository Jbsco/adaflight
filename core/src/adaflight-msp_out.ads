--  The MSP out messages that report the flight controller's state: the
--  status with the mode flags and the arming disable flags, the raw sensor
--  readings, the motor outputs, the RC channels, the attitude as angles and
--  as a quaternion, the estimated and rangefinder altitudes, the battery
--  readings and state, the debug values, the GPS solution, home vector and
--  satellites, the ESC sensor and motor telemetry, the pitot readings, the
--  transmitter information and the real-time clock. The caller gathers the
--  state into a snapshot. Each reply narrows its values to the field widths
--  of the protocol: integers wrap, readings and rates round to the nearest
--  integer with ties to even, pulses and pitot readings truncate, and the
--  battery readings and GPS altitude saturate.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.MSP_Box;
with Adaflight.Arming;
with Adaflight.Battery;
with Adaflight.Receiver;

package Adaflight.MSP_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Sonar_Altitude_Command      : constant := 58;
   Status_Command              : constant := 101;
   Raw_IMU_Command             : constant := 102;
   Motor_Command               : constant := 104;
   RC_Command                  : constant := 105;
   Attitude_Command            : constant := 108;
   Altitude_Command            : constant := 109;
   Analog_Command              : constant := 110;
   Battery_State_Command       : constant := 130;
   Status_Ex_Command           : constant := 150;
   Attitude_Quaternion_Command : constant := 167;
   Debug_Command               : constant := 254;
   Raw_GPS_Command             : constant := 106;
   Comp_GPS_Command            : constant := 107;
   ESC_Sensor_Data_Command     : constant := 134;
   Motor_Telemetry_Command     : constant := 139;
   GPS_SV_Info_Command         : constant := 164;
   Pitot_Command               : constant := 170;
   TX_Info_Command             : constant := 187;
   RTC_Command                 : constant := 247;

   PID_Profile_Count          : constant := 4;
   Control_Rate_Profile_Count : constant := 4;
   Battery_Profile_Count      : constant := 3;
   Motor_Count                : constant := 8;
   Channel_Count              : constant := 18;
   Debug_Count                : constant := 8;
   Arming_Flag_Count          : constant :=
     Adaflight.Arming.Disable_Reason'Pos (Adaflight.Arming.Disable_Reason'Last) + 1;
   Max_Satellites             : constant := 32;
   GPS_Fix_Flag               : constant := 2;
   Max_Reply_Length           : constant := 1 + 4 * Max_Satellites;

   type Sensor is (Acc, Baro, Mag, GPS, Rangefinder, Gyro, Optical_Flow, Pitot);
   type Sensor_Set is array (Sensor) of Boolean;

   subtype Flag_Count is Natural range 0 .. 64;

   type Status_Values is record
      PID_Delta_Us     : Integer_32 := 0;
      I2C_Errors       : Unsigned_16 := 0;
      Sensors          : Sensor_Set := (others => False);
      Mode_Flags       : MSP_Box.Packed_Words := (others => 0);
      Mode_Flag_Count  : Flag_Count := 0;
      PID_Profile      : Natural range 0 .. PID_Profile_Count - 1 := 0;
      Load_Percent     : Unsigned_16 := 0;
      Rate_Profile     : Natural range 0 .. Control_Rate_Profile_Count - 1 := 0;
      Arming_Disabled  : Adaflight.Arming.Disable_Set := (others => False);
      Reboot_Required  : Boolean := False;
      Core_Temperature : Integer_16 := 0;
      Battery_Profile  : Natural range 0 .. Battery_Profile_Count - 1 := 0;
   end record;

   --  Accelerometer and compass readings within the range of exact rounding.
   Reading_Bound : constant := 16_000_000.0;
   subtype Reading is Float range -Reading_Bound .. Reading_Bound;
   subtype Axis is Natural range 0 .. 2;
   type Readings is array (Axis) of Reading;
   type Rates is array (Axis) of Integer_16;

   type IMU_Values is record
      Acc      : Readings := (others => 0.0);
      Gyro_Dps : Rates := (others => 0);
      Mag      : Readings := (others => 0.0);
   end record;

   subtype Motor_Index is Natural range 0 .. Motor_Count - 1;
   type Motor_Flags is array (Motor_Index) of Boolean;
   type Motor_Outputs is array (Motor_Index) of Unsigned_16;

   --  Whether the motors run at all, each motor's own enable, and each
   --  output as the motor protocol's external value.
   type Motor_Values is record
      Enabled       : Boolean := False;
      Motor_Enabled : Motor_Flags := (others => False);
      External      : Motor_Outputs := (others => 0);
   end record;

   subtype Pulse is Float range 0.0 .. 65_535.0;
   subtype Channel_Index is Natural range 0 .. Channel_Count - 1;
   type Channel_Values is array (Channel_Index) of Pulse;

   type RC_Values is record
      Count    : Natural range 0 .. Channel_Count := 0;
      Channels : Channel_Values := (others => 0.0);
   end record;

   subtype Component is Float range -1.0 .. 1.0;

   --  Angles in tenths of a degree and the attitude quaternion.
   type Attitude_Values is record
      Roll  : Integer_16 := 0;
      Pitch : Integer_16 := 0;
      Yaw   : Integer_16 := 0;
      W     : Component := 1.0;
      X     : Component := 0.0;
      Y     : Component := 0.0;
      Z     : Component := 0.0;
   end record;

   type Altitude_Values is record
      Estimate_Cm    : Integer_32 := 0;
      Vario          : Integer_16 := 0;
      Rangefinder_Cm : Integer_32 := 0;
   end record;

   --  Voltages in tenths and hundredths of a volt, current in hundredths of
   --  an ampere.
   type Battery_Values is record
      Legacy_Voltage : Unsigned_16 := 0;
      MAh_Drawn      : Integer_32 := 0;
      RSSI           : Unsigned_16 := 0;
      Amperage       : Integer_32 := 0;
      Voltage        : Unsigned_16 := 0;
      Cell_Count     : Unsigned_8 := 0;
      Capacity_MAh   : Unsigned_16 := 0;
      State          : Adaflight.Battery.Battery_State := Adaflight.Battery.OK;
   end record;

   subtype Debug_Index is Natural range 0 .. Debug_Count - 1;
   type Debug_Values is array (Debug_Index) of Integer_16;

   type Satellite is record
      Channel : Unsigned_8 := 0;
      Id      : Unsigned_8 := 0;
      Quality : Unsigned_8 := 0;
      Signal  : Unsigned_8 := 0;
   end record;
   subtype Satellite_Index is Natural range 0 .. Max_Satellites - 1;
   type Satellite_Infos is array (Satellite_Index) of Satellite;

   --  The solution, the home vector with the direction in tenths of a degree,
   --  the update toggle, and the satellites the receiver reports.
   type GPS_Values is record
      Fix               : Boolean := False;
      Satellite_Count   : Unsigned_8 := 0;
      Latitude          : Integer_32 := 0;
      Longitude         : Integer_32 := 0;
      Altitude_Cm       : Integer_32 := 0;
      Ground_Speed      : Unsigned_16 := 0;
      Ground_Course     : Unsigned_16 := 0;
      PDOP              : Unsigned_16 := 0;
      HDOP              : Unsigned_16 := 0;
      VDOP              : Unsigned_16 := 0;
      In_View           : Unsigned_8 := 0;
      Distance_To_Home  : Unsigned_16 := 0;
      Direction_To_Home : Integer_16 := 0;
      Update            : Unsigned_8 := 0;
      Channels          : Natural range 0 .. Max_Satellites := 0;
      Satellites        : Satellite_Infos := (others => (others => 0));
   end record;

   subtype Rpm_Value is Float range 0.0 .. 2.0E9;
   subtype ESC_Rpm_Value is Float range 0.0 .. 16_000_000.0;

   --  One motor's telemetry from both sources: the DShot rate, activity,
   --  invalid share in hundredths of a percent, the kinds received with the
   --  extended values, and the ESC sensor's record with its rate in hundreds
   --  of electrical revolutions per minute and that rate as revolutions per
   --  minute.
   type Motor_Telemetry is record
      DShot_Rpm       : Rpm_Value := 0.0;
      DShot_Active    : Boolean := False;
      Invalid_Percent : Integer_16 := 0;
      Kinds           : Unsigned_8 := 0;
      Temperature     : Unsigned_16 := 0;
      Voltage         : Unsigned_16 := 0;
      Current         : Unsigned_16 := 0;
      ESC_Temperature : Unsigned_8 := 0;
      ESC_Voltage     : Unsigned_16 := 0;
      ESC_Current     : Integer_32 := 0;
      ESC_Consumption : Integer_32 := 0;
      ESC_Erpm        : Integer_16 := 0;
      ESC_Rpm         : ESC_Rpm_Value := 0.0;
   end record;
   type Motor_Telemetries is array (Motor_Index) of Motor_Telemetry;

   type ESC_Values is record
      ESC_Sensor      : Boolean := False;
      DShot_Telemetry : Boolean := False;
      Count           : Natural range 0 .. Motor_Count := 0;
      Motors          : Motor_Telemetries;
   end record;

   subtype Pitot_Reading is Float range -2.0E9 .. 2.0E9;

   --  Airspeed in centimeters per second and the differential pressure in
   --  pascals.
   type Pitot_Values is record
      Airspeed      : Pitot_Reading := 0.0;
      Diff_Pressure : Pitot_Reading := 0.0;
   end record;

   type Clock_Values is record
      Valid   : Boolean := False;
      Year    : Unsigned_16 := 0;
      Month   : Unsigned_8 := 0;
      Day     : Unsigned_8 := 0;
      Hours   : Unsigned_8 := 0;
      Minutes : Unsigned_8 := 0;
      Seconds : Unsigned_8 := 0;
      Millis  : Unsigned_16 := 0;
   end record;

   type Snapshot is record
      Status      : Status_Values;
      IMU         : IMU_Values;
      Motors      : Motor_Values;
      RC          : RC_Values;
      Attitude    : Attitude_Values;
      Altitude    : Altitude_Values;
      Battery     : Battery_Values;
      Debug       : Debug_Values := (others => 0);
      GPS         : GPS_Values;
      ESC         : ESC_Values;
      Pitot       : Pitot_Values;
      RSSI_Source : Adaflight.Receiver.RSSI_Source := Adaflight.Receiver.None;
      Clock       : Clock_Values;
   end record;

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in Sonar_Altitude_Command | Status_Command | Raw_IMU_Command | Motor_Command | RC_Command
               | Attitude_Command | Altitude_Command | Analog_Command | Battery_State_Command
               | Status_Ex_Command | Attitude_Quaternion_Command | Debug_Command | Raw_GPS_Command
               | Comp_GPS_Command | ESC_Sensor_Data_Command | Motor_Telemetry_Command | GPS_SV_Info_Command
               | Pitot_Command | TX_Info_Command | RTC_Command);

   --  Whether the reply exists for this state: the ESC data needs the ESC
   --  sensor or the DShot telemetry. An unsupported reply is an error.
   function Supported (Command : Unsigned_16; V : Snapshot) return Boolean is
     (Handles (Command)
      and then (Command /= ESC_Sensor_Data_Command or else V.ESC.ESC_Sensor or else V.ESC.DShot_Telemetry));

   --  The reply to one of these out messages; any other command, or one not
   --  supported, writes nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Supported (Command, V) then S.Next = S.Next'Old);

end Adaflight.MSP_Out;
