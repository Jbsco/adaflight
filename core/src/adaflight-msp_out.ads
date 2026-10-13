--  The MSP out messages that report the flight controller's state: the
--  status with the mode flags and the arming disable flags, the raw sensor
--  readings, the motor outputs, the RC channels, the attitude as angles and
--  as a quaternion, the estimated and rangefinder altitudes, the battery
--  readings and state, and the debug values. The caller gathers the state
--  into a snapshot. Each reply narrows its values to the field widths of
--  the protocol: integers wrap, readings round to the nearest integer with
--  ties to even, pulses truncate, and the battery readings saturate.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.MSP_Box;
with Adaflight.Arming;
with Adaflight.Battery;

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

   PID_Profile_Count          : constant := 4;
   Control_Rate_Profile_Count : constant := 4;
   Battery_Profile_Count      : constant := 3;
   Motor_Count                : constant := 8;
   Channel_Count              : constant := 18;
   Debug_Count                : constant := 8;
   Arming_Flag_Count          : constant :=
     Adaflight.Arming.Disable_Reason'Pos (Adaflight.Arming.Disable_Reason'Last) + 1;
   Max_Reply_Length           : constant := 2 * Channel_Count;

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

   type Snapshot is record
      Status   : Status_Values;
      IMU      : IMU_Values;
      Motors   : Motor_Values;
      RC       : RC_Values;
      Attitude : Attitude_Values;
      Altitude : Altitude_Values;
      Battery  : Battery_Values;
      Debug    : Debug_Values := (others => 0);
   end record;

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in Sonar_Altitude_Command | Status_Command | Raw_IMU_Command | Motor_Command | RC_Command
               | Attitude_Command | Altitude_Command | Analog_Command | Battery_State_Command
               | Status_Ex_Command | Attitude_Quaternion_Command | Debug_Command);

   --  The reply to one of these out messages; any other command writes
   --  nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Handles (Command) then S.Next = S.Next'Old);

end Adaflight.MSP_Out;
