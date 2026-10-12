--  The FrSky hub telemetry stream: every 125 ms a burst of frames, each a
--  header, an id and a sixteen-bit value with its two bytes stuffed, closed
--  by a tail. The accelerations and the climb rate go every cycle, the
--  altitude and the heading every fourth, the temperature, the rate, the
--  battery and the GPS values every eighth, and the time every fortieth.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.FrSky_Hub_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   --  The sensors a configuration can disable, in the order of their bits.
   type Sensor is (Voltage, Current, Fuel, Mode, Acc_X, Acc_Y, Acc_Z, Pitch, Roll, Heading, Altitude, Vario,
                   Lat_Long, Ground_Speed, Distance);
   type Sensor_Set is array (Sensor) of Boolean;

   type Coordinate_Format is (DMS, NMEA);
   type Units is (Imperial, Metric);
   type VFAS_Precision is (Low, High);

   --  The coordinates shown without a fix, in hundredths of a degree.
   subtype No_Fix_Coordinate is Integer_16 range -18000 .. 18000;
   subtype Gravity_Scale is Float range 0.0 .. 1.0;
   subtype Acceleration is Float range -1.0e6 .. 1.0e6;
   subtype Coordinate is Integer_32 range -(2 ** 31 - 1) .. 2 ** 31 - 1;

   type Settings is record
      Enabled             : Sensor_Set := (others => True);
      Format              : Coordinate_Format := DMS;
      Unit                : Units := Metric;
      Precision           : VFAS_Precision := Low;
      Report_Cell_Voltage : Boolean := False;
      No_Fix_Latitude     : No_Fix_Coordinate := 0;
      No_Fix_Longitude    : No_Fix_Coordinate := 0;
      Acc_Present         : Boolean := False;
      Altitude_Present    : Boolean := False;
      GPS_Present         : Boolean := False;
      Mag_Present         : Boolean := False;
      Pole_Count          : Unsigned_8 := 14;
      Acc_1G_Rec          : Gravity_Scale := 0.0;
   end record;

   --  The values of one call: the clocks, the accelerations in sensor
   --  units, the combined ESC reading, the GPS solution, the battery and
   --  the estimates.
   type Inputs is record
      Now_Us              : Unsigned_32 := 0;
      Now_Ms              : Unsigned_32 := 0;
      Acc_X               : Acceleration := 0.0;
      Acc_Y               : Acceleration := 0.0;
      Acc_Z               : Acceleration := 0.0;
      ESC_Valid           : Boolean := False;
      ESC_Rpm             : Integer_16 := 0;
      ESC_Temperature     : Unsigned_8 := 0;
      Fix                 : Boolean := False;
      Lat                 : Coordinate := 0;
      Lon                 : Coordinate := 0;
      Alt_Cm              : Integer_32 := 0;
      Ground_Speed        : Unsigned_16 := 0;
      Num_Sat             : Unsigned_8 := 0;
      Pdop                : Unsigned_16 := 0;
      Voltage_Configured  : Boolean := False;
      Amperage_Configured : Boolean := False;
      Cell_Count          : Unsigned_8 := 0;
      Voltage_Cv          : Unsigned_16 := 0;
      Amperage_Ca         : Integer_32 := 0;
      Capacity            : Unsigned_16 := 0;
      Percent             : Unsigned_8 := 0;
      Mah_Drawn           : Integer_32 := 0;
      Vario_Cms           : Integer_16 := 0;
      Altitude_Cm         : Integer_32 := 0;
      Yaw                 : Integer_16 := 0;
   end record;

   subtype Cycle_Count is Natural range 0 .. 39;

   type Stream is record
      Last_Cycle_Us : Unsigned_32 := 0;
      Cycle         : Cycle_Count := 0;
      Fix_Occurred  : Boolean := False;
      Current_Cell  : Unsigned_16 := 0;
   end record;

   Max_Output : constant := 256;
   subtype Output_Count is Natural range 0 .. Max_Output;

   type Output is record
      Tx    : Byte_Array (0 .. Max_Output - 1) := (others => 0);
      Count : Output_Count := 0;
   end record;

   --  One task call: nothing before the cycle time has passed, else the
   --  frames of this cycle and the tail.
   procedure Update (S : in out Stream; C : Settings; Inp : Inputs; O : out Output);

end Adaflight.FrSky_Hub_Telemetry;
