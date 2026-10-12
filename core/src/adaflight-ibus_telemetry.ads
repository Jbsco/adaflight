--  The iBus telemetry sensors: the receiver polls addresses on the
--  half-duplex line with four byte requests, and the link answers from a
--  table of fifteen sensor ids, the first address polled becoming the base
--  of the table. A request is seen through a four byte window over the
--  bytes received, with the echo of each answer skipped by its length.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.IBus_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   Sensor_Count : constant := 15;
   type Sensor_Table is array (0 .. Sensor_Count - 1) of Unsigned_8;

   subtype Gravity_Scale is Float range 0.0 .. 1.0;
   subtype Acceleration is Float range -1.0e6 .. 1.0e6;
   subtype Throttle_Command is Float range 0.0 .. 32767.0;
   subtype Altitude_Cm is Float range -1.0e7 .. 1.0e7;

   type Settings is record
      Sensors             : Sensor_Table := (others => 0);
      Report_Cell_Voltage : Boolean := False;
      Acc_1G_Rec          : Gravity_Scale := 0.0;
   end record;

   --  The values a request may ask for.
   type Inputs is record
      Voltage_Cv       : Unsigned_16 := 0;
      Cell_Cv          : Unsigned_16 := 0;
      Amperage_Ca      : Integer_32 := 0;
      Capacity         : Unsigned_16 := 0;
      Percent          : Unsigned_8 := 0;
      Mah_Drawn        : Integer_32 := 0;
      Armed            : Boolean := False;
      Throttle_Low     : Boolean := False;
      Motor_Stop       : Boolean := False;
      Throttle         : Throttle_Command := 1000.0;
      Angle_Like       : Boolean := False;
      Passthru         : Boolean := False;
      Headfree_Or_Mag  : Boolean := False;
      Horizon          : Boolean := False;
      Failsafe         : Boolean := False;
      Acc_X            : Acceleration := 0.0;
      Acc_Y            : Acceleration := 0.0;
      Acc_Z            : Acceleration := 0.0;
      Roll             : Integer_16 := 0;
      Pitch            : Integer_16 := 0;
      Yaw              : Integer_16 := 0;
      Baro_Present     : Boolean := False;
      Baro_Temperature : Integer_32 := 0;
      Baro_Pressure    : Integer_32 := 0;
      Baro_Altitude    : Altitude_Cm := 0.0;
      Gyro_Temperature : Integer_16 := 0;
      Vario_Cms        : Integer_16 := 0;
      GPS_Present      : Boolean := False;
      Fix              : Boolean := False;
      Num_Sat          : Unsigned_8 := 0;
      Ground_Speed     : Unsigned_16 := 0;
      Ground_Course    : Unsigned_16 := 0;
      Lat              : Integer_32 := 0;
      Lon              : Integer_32 := 0;
      Alt_Cm           : Integer_32 := 0;
      Distance_Home    : Unsigned_16 := 0;
   end record;

   subtype Window_Bytes is Byte_Array (0 .. 3);

   type Link is record
      Base_Address : Unsigned_8 := 0;
      Window       : Window_Bytes := (others => 0);
      Ignore       : Unsigned_8 := 0;
   end record;

   Max_Output : constant := 512;
   subtype Output_Count is Natural range 0 .. Max_Output;

   type Output is record
      Tx    : Byte_Array (0 .. Max_Output - 1) := (others => 0);
      Count : Output_Count := 0;
   end record;

   --  One task call with the bytes received since the last, every one of
   --  them taken.
   procedure Update (L : in out Link; C : Settings; Inp : Inputs; Rx : Byte_Array; O : out Output);

end Adaflight.IBus_Telemetry;
