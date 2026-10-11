--  The telemetry frames of the CRSF link and the schedule that sends them:
--  every frame as sync byte, length, type, payload and checksum over caller
--  supplied readings, the round-robin schedule built from the sensors
--  present and the kinds enabled, the timed position and barometer frames,
--  the device info reply, the event-driven gate, and the link speed
--  negotiation of the third protocol version.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers; use Adaflight.Stream_Buffers;
with Adaflight.Clock;

package Adaflight.CRSF_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
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
   subtype Time_Us is Adaflight.Clock.Time_Us;

   Frame_Size_Max : constant := 64;
   Sync_Byte      : constant Byte := 16#C8#;

   Address_Flight_Controller : constant Byte := 16#C8#;
   Address_Radio_Transmitter : constant Byte := 16#EA#;
   Address_Receiver          : constant Byte := 16#EC#;

   Type_GPS           : constant Byte := 16#02#;
   Type_GPS_Time      : constant Byte := 16#03#;
   Type_GPS_Extended  : constant Byte := 16#06#;
   Type_Vario         : constant Byte := 16#07#;
   Type_Battery       : constant Byte := 16#08#;
   Type_Baro_Altitude : constant Byte := 16#09#;
   Type_Heartbeat     : constant Byte := 16#0B#;
   Type_Baro          : constant Byte := 16#11#;
   Type_Mag           : constant Byte := 16#12#;
   Type_Inertial      : constant Byte := 16#13#;
   Type_Attitude      : constant Byte := 16#1E#;
   Type_Flight_Mode   : constant Byte := 16#21#;
   Type_Ping          : constant Byte := 16#28#;
   Type_Device_Info   : constant Byte := 16#29#;
   Type_Command       : constant Byte := 16#32#;
   Type_MSP_Response  : constant Byte := 16#7B#;

   Command_General        : constant Byte := 16#0A#;
   Command_Speed_Proposal : constant Byte := 16#70#;
   Command_Speed_Response : constant Byte := 16#71#;
   Command_Polynomial     : constant Byte := 16#BA#;

   ---------------------------------------------------------------------------
   --  Readings
   ---------------------------------------------------------------------------

   --  Degrees times ten million, centimeters, centimeters per second, and
   --  the accuracies in millimeters, with the solution stamp that marks a
   --  new fix.
   type GPS_Solution is record
      Latitude            : Integer_32 := 0;
      Longitude           : Integer_32 := 0;
      Altitude_Cm         : Integer_32 := 0;
      Ground_Speed        : Unsigned_16 := 0;
      Ground_Course       : Unsigned_16 := 0;
      Satellites          : Unsigned_8 := 0;
      Fix                 : Boolean := False;
      Time                : Unsigned_32 := 0;
      Velocity_North      : Integer_16 := 0;
      Velocity_East       : Integer_16 := 0;
      Velocity_Down       : Integer_16 := 0;
      Horizontal_Accuracy : Unsigned_32 := 0;
      Vertical_Accuracy   : Unsigned_32 := 0;
      Speed_Accuracy      : Unsigned_32 := 0;
      Heading_Accuracy    : Unsigned_32 := 0;
      HDOP                : Unsigned_16 := 0;
      VDOP                : Unsigned_16 := 0;
      Date_Valid          : Boolean := False;
      Year                : Unsigned_16 := 0;
      Month               : Unsigned_8 := 0;
      Day                 : Unsigned_8 := 0;
      Hour                : Unsigned_8 := 0;
      Minute              : Unsigned_8 := 0;
      Second              : Unsigned_8 := 0;
      Millisecond         : Unsigned_16 := 0;
   end record;

   subtype Baro_Altitude is Float range -1.0E9 .. 1.0E9;

   type Barometer_Readings is record
      Pressure    : Integer_32 := 0;
      Temperature : Integer_32 := 0;
      Altitude_Cm : Baro_Altitude := 0.0;
   end record;

   subtype Mag_Field is Float range -10_000.0 .. 10_000.0;

   type Mag_Readings is record
      X : Mag_Field := 0.0;
      Y : Mag_Field := 0.0;
      Z : Mag_Field := 0.0;
   end record;

   --  Voltages in tenths and hundredths of a volt, the current in hundredths
   --  of an ampere.
   type Battery_Readings is record
      Legacy_Voltage      : Unsigned_16 := 0;
      Cell_Voltage        : Unsigned_16 := 0;
      Amperage            : Integer_32 := 0;
      Drawn_Mah           : Integer_32 := 0;
      Remaining_Percent   : Unsigned_8 := 0;
      Report_Cell_Voltage : Boolean := False;
   end record;

   --  Decidegrees, unreduced.
   type Attitude_Angles is record
      Pitch : Integer_16 := 0;
      Roll  : Integer_16 := 0;
      Yaw   : Integer_16 := 0;
   end record;

   Mode_Angle      : constant Unsigned_16 := 1;
   Mode_Horizon    : constant Unsigned_16 := 2;
   Mode_Alt_Hold   : constant Unsigned_16 := 8;
   Mode_Pos_Hold   : constant Unsigned_16 := 32;
   Mode_Chirp      : constant Unsigned_16 := 128;
   Mode_Passthru   : constant Unsigned_16 := 256;
   Mode_Failsafe   : constant Unsigned_16 := 1024;
   Mode_GPS_Rescue : constant Unsigned_16 := 2048;

   type Flight_State is record
      Mode_Flags            : Unsigned_16 := 0;
      Armed                 : Boolean := False;
      Failsafe_Switch       : Boolean := False;
      Rescue_Switch         : Boolean := False;
      Rescue_Plan           : Boolean := False;
      Position_Hold_Failure : Boolean := False;
      Airmode               : Boolean := False;
      Arming_Disabled       : Boolean := False;
      GPS_Feature           : Boolean := False;
      Rescue_Configured     : Boolean := False;
      Rescue_Min_Satellites : Unsigned_8 := 0;
   end record;

   subtype Rate_Dps is Float range -1.0E6 .. 1.0E6;
   subtype Acc_Count is Float range -1.0E6 .. 1.0E6;
   subtype Acc_Scale is Float range 0.0 .. 1.0;
   type Rates is array (0 .. 2) of Rate_Dps;
   type Counts is array (0 .. 2) of Acc_Count;

   --  The downsampled rates in degrees per second, the accelerometer counts
   --  with the reciprocal of one gravity in counts, and the temperature.
   type IMU_Sample is record
      Fresh             : Boolean := False;
      Gyro              : Rates := (others => 0.0);
      Acc               : Counts := (others => 0.0);
      Acc_1G_Reciprocal : Acc_Scale := 0.0;
      Temperature       : Integer_16 := 0;
   end record;

   Name_Length_Max : constant := 30;
   subtype Name_Length is Natural range 0 .. Name_Length_Max;

   type Sources is record
      GPS       : GPS_Solution;
      Baro      : Barometer_Readings;
      Vario     : Integer_16 := 0;
      Mag       : Mag_Readings;
      Battery   : Battery_Readings;
      Attitude  : Attitude_Angles;
      Flight    : Flight_State;
      IMU       : IMU_Sample;
      Name      : String (1 .. Name_Length_Max) := (others => ' ');
      Name_Last : Name_Length := 0;
   end record;

   ---------------------------------------------------------------------------
   --  Frames. Each writes one complete frame and asks for the room of the
   --  longest.
   ---------------------------------------------------------------------------

   procedure Write_GPS (B : in out Byte_Array; S : in out Stream; G : GPS_Solution)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_GPS_Time (B : in out Byte_Array; S : in out Stream; G : GPS_Solution)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_GPS_Extended (B : in out Byte_Array; S : in out Stream; G : GPS_Solution)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Vario (B : in out Byte_Array; S : in out Stream; Vario : Integer_16)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Baro (B : in out Byte_Array; S : in out Stream; Baro : Barometer_Readings)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Mag (B : in out Byte_Array; S : in out Stream; Mag : Mag_Readings)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Battery (B : in out Byte_Array; S : in out Stream; Bat : Battery_Readings)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Altitude (B : in out Byte_Array; S : in out Stream; Baro : Barometer_Readings; Vario : Integer_16)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Heartbeat (B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Ping (B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Attitude (B : in out Byte_Array; S : in out Stream; A : Attitude_Angles)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   --  The mode name by priority, then while disarmed outside a failsafe one
   --  character: arming blocked, rescue unavailable, or ready.
   procedure Write_Flight_Mode (B : in out Byte_Array; S : in out Stream; F : Flight_State;
                                Satellites : Unsigned_8; Fix : Boolean)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   procedure Write_Device_Info (B : in out Byte_Array; S : in out Stream; Name : String)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max and then Name'Length <= Name_Length_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   --  Nothing is written when the sample is not fresh.
   procedure Write_Inertial (B : in out Byte_Array; S : in out Stream; Now : Time_Us; IMU : IMU_Sample)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + Frame_Size_Max;

   MSP_Payload_Max : constant := 58;

   procedure Write_MSP_Response (B : in out Byte_Array; S : in out Stream; Origin : Byte; Payload : Byte_Array)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max and then Payload'Length <= MSP_Payload_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   --  The speed response carries a second checksum with the command
   --  polynomial before the frame checksum.
   procedure Write_Speed_Response (B : in out Byte_Array; S : in out Stream; Port : Unsigned_8; Reply : Boolean)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Frame_Size_Max;

   --  Altitude in decimeters packed into sixteen bits: decimeters above a
   --  thousand meter floor below 2276 meters, meters above with the high bit
   --  set, held at the top value above the range.
   function Packed_Altitude (Altitude_Dm : Integer_32) return Unsigned_16
     with Pre => Altitude_Dm in -2 ** 30 .. 2 ** 30;

   --  Climb rate in centimeters per second on a logarithmic eight bit scale.
   function Packed_Climb (Vertical_Speed : Integer_16) return Integer_8;

   --  Decidegrees reduced into a half turn, then radians times ten thousand.
   function Radians_10000 (Angle : Integer_16) return Integer_16;

   ---------------------------------------------------------------------------
   --  The schedule
   ---------------------------------------------------------------------------

   Kind_Voltage      : constant Unsigned_32 := 1;
   Kind_Current      : constant Unsigned_32 := 2;
   Kind_Fuel         : constant Unsigned_32 := 4;
   Kind_Mode         : constant Unsigned_32 := 8;
   Kind_Pitch        : constant Unsigned_32 := 128;
   Kind_Roll         : constant Unsigned_32 := 256;
   Kind_Heading      : constant Unsigned_32 := 512;
   Kind_Altitude     : constant Unsigned_32 := 1024;
   Kind_Vario        : constant Unsigned_32 := 2048;
   Kind_Lat_Long     : constant Unsigned_32 := 4096;
   Kind_Ground_Speed : constant Unsigned_32 := 8192;

   type Config is record
      Acc_Present         : Boolean := False;
      Baro_Present        : Boolean := False;
      Mag_Present         : Boolean := False;
      Gyro_Present        : Boolean := False;
      Disabled_Kinds      : Unsigned_32 := 0;
      Voltage_Configured  : Boolean := False;
      Amperage_Configured : Boolean := False;
      GPS_Feature         : Boolean := False;
      Telemetry_Feature   : Boolean := False;
      Inertial_Frames     : Boolean := False;
      Event_Driven        : Boolean := False;
      Use_Negotiated_Baud : Boolean := False;
   end record;

   Slot_Attitude      : constant Unsigned_16 := 1;
   Slot_Baro_Altitude : constant Unsigned_16 := 2;
   Slot_Battery       : constant Unsigned_16 := 4;
   Slot_Flight_Mode   : constant Unsigned_16 := 8;
   Slot_Mag           : constant Unsigned_16 := 16;
   Slot_GPS           : constant Unsigned_16 := 32;
   Slot_Vario         : constant Unsigned_16 := 64;
   Slot_Heartbeat     : constant Unsigned_16 := 128;

   Timed_GPS          : constant Unsigned_16 := 1;
   Timed_GPS_Time     : constant Unsigned_16 := 2;
   Timed_GPS_Extended : constant Unsigned_16 := 4;
   Timed_Baro         : constant Unsigned_16 := 8;
   Timed_Inertial     : constant Unsigned_16 := 16;

   Schedule_Max : constant := 10;
   subtype Slot_Index is Natural range 0 .. Schedule_Max - 1;
   type Slots is array (Slot_Index) of Unsigned_16;

   Cycle_Time_Us         : constant := 100_000;
   Frame_Interval_Max_Us : constant := 20_000;
   Baro_Interval_Us      : constant := 100_000;
   GPS_Time_Interval_Us  : constant := 30_000_000;
   Speed_Confirm_Us      : constant := 4_000;

   Baud_Count   : constant := 16;
   Default_Baud : constant := 420_000;
   type Baud_Table is array (0 .. Baud_Count - 1) of Unsigned_32;
   Baud_Rates : constant Baud_Table :=
     (0, 9600, 19200, 38400, 57600, 115200, 230400, 250000,
      400000, 460800, 500000, 921600, 1000000, 1500000, 2000000, 2470000);

   type Speed_Control is record
      Pending_Reply     : Boolean := False;
      New_Speed_Valid   : Boolean := False;
      Port_Id           : Unsigned_8 := 0;
      Index             : Natural range 0 .. Baud_Count := 0;
      Confirmation_Time : Time_Us := 0;
   end record
     with Dynamic_Predicate => Speed_Control.Port_Id <= 7;

   --  The slots keep stale entries past the count, and the slot index is not
   --  reset by a new schedule, so a shorter schedule reads them until the
   --  index wraps.
   type Telemetry is record
      Enabled                     : Boolean := False;
      Schedule                    : Slots := (others => 0);
      Count                       : Natural range 0 .. Schedule_Max := 0;
      Index                       : Slot_Index := 0;
      Timed                       : Unsigned_16 := 0;
      Inertial_Frames             : Boolean := False;
      Event_Driven                : Boolean := False;
      Use_Negotiated_Baud         : Boolean := False;
      Telemetry_Feature           : Boolean := False;
      Device_Info_Pending         : Boolean := False;
      Response_Pending            : Boolean := False;
      Last_Cycle_Time             : Time_Us := 0;
      Last_GPS_Solution_Time      : Unsigned_32 := 0;
      Last_GPS_Time_Solution_Time : Unsigned_32 := 0;
      Last_GPS_Time_Frame_Time    : Time_Us := 16#FE36_3C80#;
      Last_Baro_Time              : Time_Us := 0;
      Last_Check_Time             : Time_Us := 0;
      V3_Running                  : Boolean := False;
      Speed                       : Speed_Control;
   end record;

   --  Builds the schedule from the configuration when the link is active;
   --  heartbeats fill the schedule to five slots unless inertial frames run.
   procedure Init (T : in out Telemetry; Cfg : Config; Active : Boolean)
     with Post => T.Enabled = Active;

   --  Whether the task has work: a device info reply at once, otherwise a
   --  received frame at most every twenty milliseconds.
   procedure Update_Check (T : in out Telemetry; Now : Time_Us; Run : out Boolean);

   procedure Schedule_Response (T : in out Telemetry)
     with Post => T.Response_Pending;

   procedure Schedule_Device_Info (T : in out Telemetry)
     with Post => T.Device_Info_Pending;

   function Negotiation_In_Progress (T : Telemetry) return Boolean is
     (T.Speed.Pending_Reply or else T.Speed.New_Speed_Valid);

   function Desired_Speed (T : Telemetry) return Unsigned_32 is
     (if T.Speed.Index < Baud_Count then Baud_Rates (T.Speed.Index) else Default_Baud);

   --  A speed proposal names a port and a baud rate in four big-endian bytes.
   procedure Process_Command (T : in out Telemetry; Payload : Byte_Array)
     with Pre => Payload'Length >= 7;

   --  Answers a pending proposal, applies an accepted rate after the confirm
   --  delay (New_Baud non-zero), or sends a heartbeat while telemetry is off
   --  and the negotiated rate is in use.
   procedure Negotiate (T : in out Telemetry; Now : Time_Us; B : in out Byte_Array; S : in out Stream;
                        New_Baud : out Unsigned_32)
     with Pre  => Fits (S, B) and then Remaining (S) >= Frame_Size_Max,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + Frame_Size_Max;

   Update_Room : constant := 10 * Frame_Size_Max;

   --  One telemetry pass: nothing during a negotiation, the device info reply
   --  first, then with the event-driven gate open the timed frames or the
   --  next slot, else an inertial frame when configured.
   procedure Update (T : in out Telemetry; Now : Time_Us; Src : Sources; B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B) and then Remaining (S) >= Update_Room,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + Update_Room;

end Adaflight.CRSF_Telemetry;
