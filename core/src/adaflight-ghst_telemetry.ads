--  The Ghost telemetry frames the flight controller hands to its receiver:
--  a schedule of up to four frame types built from the configuration, one
--  frame per cycle of a tenth of a second divided by the schedule length,
--  each frame the receiver address, a length, a type, ten payload bytes
--  and a checksum over the type and payload.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.GHST_Telemetry with SPARK_Mode is
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

   type Frame_Kind is (Pack, GPS_Primary, GPS_Secondary, Mag_Baro);

   type Settings is record
      Voltage_Enabled      : Boolean := True;
      Current_Enabled      : Boolean := True;
      Fuel_Enabled         : Boolean := True;
      Altitude_Enabled     : Boolean := True;
      Lat_Long_Enabled     : Boolean := True;
      Ground_Speed_Enabled : Boolean := True;
      Heading_Enabled      : Boolean := True;
      Report_Cell_Voltage  : Boolean := False;
      Voltage_Configured   : Boolean := False;
      Amperage_Configured  : Boolean := False;
      GPS_Feature          : Boolean := False;
      Baro_Present         : Boolean := False;
      Mag_Present          : Boolean := False;
   end record;

   type Inputs is record
      Now_Us         : Unsigned_32 := 0;
      Voltage_Cv     : Unsigned_16 := 0;
      Cell_Cv        : Unsigned_16 := 0;
      Amperage_Ca    : Integer_32 := 0;
      Mah_Drawn      : Integer_32 := 0;
      Armed          : Boolean := False;
      Lat            : Integer_32 := 0;
      Lon            : Integer_32 := 0;
      Alt_Cm         : Integer_32 := 0;
      Fix            : Boolean := False;
      Fix_Home       : Boolean := False;
      Ground_Speed   : Unsigned_16 := 0;
      Ground_Course  : Unsigned_16 := 0;
      Num_Sat        : Unsigned_8 := 0;
      Distance_Home  : Unsigned_16 := 0;
      Direction_Home : Integer_16 := 0;
      Altitude_Cm    : Integer_32 := 0;
      Yaw            : Integer_16 := 0;
   end record;

   Max_Schedule : constant := 4;
   subtype Schedule_Count is Natural range 0 .. Max_Schedule;
   subtype Schedule_Index is Natural range 0 .. Max_Schedule - 1;
   type Schedule is array (Schedule_Index) of Frame_Kind;

   type Link is record
      Table         : Schedule := (others => Pack);
      Count         : Schedule_Count := 0;
      Index         : Schedule_Index := 0;
      Last_Cycle_Us : Unsigned_32 := 0;
   end record;

   Frame_Size : constant := 14;
   subtype Frame is Byte_Array (0 .. Frame_Size - 1);

   type Output is record
      Tx    : Frame := (others => 0);
      Count : Natural range 0 .. Frame_Size := 0;
   end record;

   --  The schedule from the configuration and the sensors present.
   procedure Init (L : out Link; C : Settings);

   --  One task call: the next frame of the schedule when its cycle has
   --  come, nothing with an empty schedule.
   procedure Update (L : in out Link; C : Settings; Inp : Inputs; O : out Output);

end Adaflight.GHST_Telemetry;
