--  The MSP out messages that report the hardware configuration: the mixer,
--  the motors, the compass declination, the GPS receiver, the GPS rescue and
--  its gains, the accelerometer trims, the flight log, the sensors selected
--  and detected, the gyros detected, and the flash and SD card storage. The
--  caller gathers the configuration, the storage state and the build's
--  options into a snapshot. A reply whose option is left out of the build is
--  unsupported, or reports the sensor or the storage as absent.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;

package Adaflight.MSP_Hardware_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Integer_16 is Interfaces.Integer_16;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Mixer_Config_Command          : constant := 42;
   Dataflash_Summary_Command     : constant := 70;
   SD_Card_Summary_Command       : constant := 79;
   Blackbox_Config_Command       : constant := 80;
   Sensor_Config_Command         : constant := 96;
   Motor_Config_Command          : constant := 131;
   GPS_Config_Command            : constant := 132;
   Compass_Config_Command        : constant := 133;
   GPS_Rescue_Command            : constant := 135;
   GPS_Rescue_PIDs_Command       : constant := 136;
   Acc_Trim_Command              : constant := 240;
   Sensor_Config_Active_Command  : constant := 16#300A#;
   Gyro_Sensor_Active_Command    : constant := 16#300D#;

   Max_Gyros        : constant := 8;
   Max_Reply_Length : constant := 32;

   --  The sensors in their protocol order: gyro, accelerometer, barometer,
   --  compass, rangefinder, optical flow and pitot.
   type Sensor is (Gyro, Acc, Baro, Mag, Rangefinder, Optical_Flow, Pitot);
   type Sensor_Flags is array (Sensor) of Boolean;
   type Sensor_Bytes is array (Sensor) of Unsigned_8;
   type Gyro_Bytes is array (1 .. Max_Gyros) of Unsigned_8;

   --  The value a sensor's hardware selection takes when it is not built.
   None_Selection : constant Sensor_Bytes :=
     (Gyro => 0, Acc => 1, Baro => 1, Mag => 1, Rangefinder => 0, Optical_Flow => 0, Pitot => 1);

   --  The SD card's file system as its driver reports it.
   type File_System_State is (Unknown, Fatal, Initialization, Ready);

   --  The motors: the throttle and command limits in microseconds, the
   --  motor count, the poles, the DShot telemetry and ESC sensor feature
   --  when each is built, and the motors' rating in revolutions per minute a
   --  volt.
   type Motor_Values is record
      Max_Throttle        : Unsigned_16 := 0;
      Min_Command         : Unsigned_16 := 0;
      Motor_Count         : Unsigned_8 := 0;
      Pole_Count          : Unsigned_8 := 0;
      DShot_Telemetry     : Boolean := False;
      Use_DShot_Telemetry : Boolean := False;
      ESC_Sensor          : Boolean := False;
      ESC_Sensor_Feature  : Boolean := False;
      KV                  : Unsigned_16 := 0;
   end record;

   --  The GPS rescue settings with the autopilot's lean, throttle and gains.
   type Rescue_Values is record
      Max_Angle                : Unsigned_8 := 0;
      Return_Altitude_M        : Unsigned_16 := 0;
      Descent_Distance_M       : Unsigned_16 := 0;
      Ground_Speed_Cm_S        : Unsigned_16 := 0;
      Throttle_Min             : Unsigned_16 := 0;
      Throttle_Max             : Unsigned_16 := 0;
      Hover_Throttle           : Unsigned_16 := 0;
      Sanity_Checks            : Unsigned_8 := 0;
      Min_Sats                 : Unsigned_8 := 0;
      Ascend_Rate              : Unsigned_16 := 0;
      Descend_Rate             : Unsigned_16 := 0;
      Allow_Arming_Without_Fix : Unsigned_8 := 0;
      Altitude_Mode            : Unsigned_8 := 0;
      Min_Start_Dist_M         : Unsigned_16 := 0;
      Initial_Climb_M          : Unsigned_16 := 0;
      Altitude_P               : Unsigned_8 := 0;
      Altitude_I               : Unsigned_8 := 0;
      Altitude_D               : Unsigned_8 := 0;
      Position_P               : Unsigned_8 := 0;
      Position_I               : Unsigned_8 := 0;
      Position_D               : Unsigned_8 := 0;
      Yaw_P                    : Unsigned_8 := 0;
   end record;

   --  The flight log: the device, the logging rate divider and P ratio as
   --  the recorder computes them, the sample rate and the disabled fields.
   type Blackbox_Values is record
      Built           : Boolean := False;
      Device          : Unsigned_8 := 0;
      Rate_Denom      : Unsigned_8 := 0;
      P_Ratio         : Unsigned_16 := 0;
      Sample_Rate     : Unsigned_8 := 0;
      Fields_Disabled : Unsigned_32 := 0;
   end record;

   --  The flash volume when the file system is built and the chip carries
   --  one: its readiness, its partition's first and last sectors, its size
   --  and the bytes stored.
   type Flash_Values is record
      Built        : Boolean := False;
      Supported    : Boolean := False;
      Ready        : Boolean := False;
      Start_Sector : Unsigned_16 := 0;
      End_Sector   : Unsigned_16 := 0;
      Size         : Unsigned_32 := 0;
      Offset       : Unsigned_32 := 0;
   end record;

   --  The SD card when its driver is built and configured: the card's
   --  presence and health, the file system's state, the card's
   --  initialization, the last error, the contiguous free bytes and the
   --  card's 512-byte blocks.
   type SD_Card_Values is record
      Built        : Boolean := False;
      Configured   : Boolean := False;
      Inserted     : Boolean := False;
      Functional   : Boolean := False;
      State        : File_System_State := Unknown;
      Initialized  : Boolean := False;
      Last_Error   : Unsigned_8 := 0;
      Free_Bytes   : Unsigned_32 := 0;
      Block_Count  : Unsigned_32 := 0;
   end record;

   type Snapshot is record
      Mixer_Mode         : Unsigned_8 := 0;
      Yaw_Reversed       : Boolean := False;
      Motor              : Motor_Values;
      Mag_Declination    : Integer_16 := 0;
      GPS                : Boolean := False;
      GPS_Provider       : Unsigned_8 := 0;
      SBAS_Mode          : Unsigned_8 := 0;
      Auto_Config        : Unsigned_8 := 0;
      Auto_Baud          : Unsigned_8 := 0;
      Set_Home_Once      : Boolean := False;
      Use_Galileo        : Boolean := False;
      Rescue             : Boolean := False;
      Rescue_Settings    : Rescue_Values;
      Trim_Pitch         : Integer_16 := 0;
      Trim_Roll          : Integer_16 := 0;
      Blackbox           : Blackbox_Values;
      Built              : Sensor_Flags := (others => False);
      Selected           : Sensor_Bytes := (others => 0);
      Detected           : Sensor_Bytes := (others => 0);
      Gyro_Count         : Natural range 0 .. Max_Gyros := 0;
      Detected_Gyros     : Gyro_Bytes := (others => 0);
      Flash              : Flash_Values;
      SD_Card            : SD_Card_Values;
   end record;

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in Mixer_Config_Command | Dataflash_Summary_Command | SD_Card_Summary_Command
               | Blackbox_Config_Command | Sensor_Config_Command | Motor_Config_Command | GPS_Config_Command
               | Compass_Config_Command | GPS_Rescue_Command | GPS_Rescue_PIDs_Command | Acc_Trim_Command
               | Sensor_Config_Active_Command | Gyro_Sensor_Active_Command);

   --  Whether the reply exists for this build: the compass declination
   --  needs the compass, the GPS replies the GPS, the rescue replies the
   --  rescue, and the trims the accelerometer.
   function Supported (Command : Unsigned_16; V : Snapshot) return Boolean is
     (Handles (Command)
      and then (Command /= Compass_Config_Command or else V.Built (Mag))
      and then (Command /= GPS_Config_Command or else V.GPS)
      and then (Command not in GPS_Rescue_Command | GPS_Rescue_PIDs_Command or else V.Rescue)
      and then (Command /= Acc_Trim_Command or else V.Built (Acc)));

   --  The reply to one of these out messages; any other command, or one not
   --  supported, writes nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Supported (Command, V) then S.Next = S.Next'Old);

end Adaflight.MSP_Hardware_Out;
