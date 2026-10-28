--  The SmartPort telemetry stream: the receiver polls the sensors on a
--  half-duplex line, and when it polls this one the next value of a table
--  goes back as a data frame of a frame id, a value id, a 32-bit value and
--  the FrSky checksum, with the two reserved bytes escaped. The table is
--  built once from the sensors enabled in the configuration and the
--  sensors present, and every seventh value is taken from the ESC table
--  instead, over each motor and the combined reading in turn. The frames
--  received are reassembled through the start byte, the sensor id and the
--  escaped payload with its checksum. Over an FPORT receiver the frame goes
--  back as its telemetry reply instead, behind the reply's length and type,
--  which the checksum counts.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.SmartPort_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   Start_Stop  : constant Byte := 16#7E#;
   Escape      : constant Byte := 16#7D#;
   Escape_Xor  : constant Byte := 16#20#;
   Data_Frame  : constant Unsigned_8 := 16#10#;
   Sensor_Id_1 : constant Byte := 16#1B#;
   Sensor_Id_2 : constant Byte := 16#0D#;
   --  The FPORT reply's length, the type byte and the payload, and its type.
   FPort_Reply_Length : constant Byte := 8;
   FPort_Reply_Type   : constant Byte := 16#81#;

   --  The sensors a configuration may disable.
   type Sensor is (Voltage, Current, Fuel, Mode, Acc_X, Acc_Y, Acc_Z, Pitch, Roll, Heading, Altitude, Vario,
                   Lat_Long, Ground_Speed, Distance, ESC_Current, ESC_Voltage, ESC_Rpm, ESC_Temperature,
                   Temperature, Cap_Used);
   type Sensor_Set is array (Sensor) of Boolean;

   --  What the table is built from: the enabled sensors, the battery
   --  meters configured, the sensors present and the GPS feature.
   type Build_Inputs is record
      Enabled              : Sensor_Set := (others => True);
      Voltage_Configured   : Boolean := False;
      Amperage_Configured  : Boolean := False;
      Acc_Present          : Boolean := False;
      Baro_Present         : Boolean := False;
      GPS_Feature          : Boolean := False;
   end record;

   --  Twenty-one sensors can be enabled at once; the table has room for
   --  all of them (finding F76).
   Max_Values     : constant := 21;
   Max_ESC_Values : constant := 4;
   subtype Value_Count is Natural range 0 .. Max_Values;
   subtype ESC_Count is Natural range 0 .. Max_ESC_Values;
   type Value_Ids is array (1 .. Max_Values) of Unsigned_16;
   type ESC_Ids is array (1 .. Max_ESC_Values) of Unsigned_16;

   --  One ESC reading: the voltage in hundredths of a volt, the current in
   --  hundredths of an ampere, the temperature in degrees and the
   --  electrical rate in hundreds of revolutions per minute.
   type ESC_Reading is record
      Present     : Boolean := False;
      Voltage     : Unsigned_16 := 0;
      Current     : Integer_32 := 0;
      Temperature : Unsigned_8 := 0;
      Rpm         : Integer_16 := 0;
   end record;

   Max_Motors : constant := 8;
   subtype Motor_Count is Natural range 0 .. Max_Motors;
   type ESC_Readings is array (0 .. Max_Motors - 1) of ESC_Reading;

   --  The accelerometer readings and the scale that brings them to g.
   subtype Acceleration is Float range -1.0e6 .. 1.0e6;
   subtype Gravity_Scale is Float range 0.0 .. 1.0;

   type Gains is record
      Roll, Pitch, Yaw : Unsigned_8 := 0;
   end record;

   --  The values of a call: the battery, the altitude and climb rate, the
   --  attitude in decidegrees, the accelerations with the gravity scale,
   --  the arming and mode flags, the GPS solution, the core temperature,
   --  the ESC readings with the motor count and the pole count, and the
   --  gains and rates reported when no GPS is in use.
   type Inputs is record
      Report_Cell_Voltage  : Boolean := False;
      Pid_Values           : Boolean := False;
      Voltage_Cv           : Unsigned_16 := 0;
      Cell_Voltage_Cv      : Unsigned_16 := 0;
      Amperage_Ca          : Integer_32 := 0;
      Capacity_Set         : Boolean := False;
      Percent_Remaining    : Unsigned_8 := 0;
      Mah_Drawn            : Integer_32 := 0;
      Altitude_Cm          : Integer_32 := 0;
      Vario_Cms            : Integer_16 := 0;
      Yaw, Pitch, Roll     : Integer_16 := 0;
      Acc_X, Acc_Y, Acc_Z  : Acceleration := 0.0;
      Acc_1G_Rec           : Gravity_Scale := 0.0;
      Arming_Disabled      : Boolean := False;
      Armed                : Boolean := False;
      Angle_Like           : Boolean := False;
      Horizon              : Boolean := False;
      Passthru             : Boolean := False;
      Mag                  : Boolean := False;
      Headfree             : Boolean := False;
      GPS_Present          : Boolean := False;
      GPS_Feature          : Boolean := False;
      Fix                  : Boolean := False;
      Fix_Home             : Boolean := False;
      Pdop                 : Unsigned_16 := 0;
      Num_Sat              : Unsigned_8 := 0;
      Ground_Speed         : Unsigned_16 := 0;
      Lat, Lon             : Integer_32 := 0;
      Home_Distance_M      : Unsigned_16 := 0;
      GPS_Altitude_Cm      : Integer_32 := 0;
      Core_Temperature     : Integer_16 := 0;
      ESC                  : ESC_Readings;
      ESC_Combined         : ESC_Reading;
      Motors               : Motor_Count := 4;
      Pole_Count           : Unsigned_8 := 14;
      P, I, D              : Gains;
      Rates                : Gains;
   end record;

   type Receive_State is record
      Rx           : Byte_Array (0 .. 6) := (others => 0);
      Rx_Count     : Natural range 0 .. 7 := 0;
      Skip         : Boolean := True;
      Await_Id     : Boolean := False;
      Stuffing     : Boolean := False;
      Checksum     : Unsigned_16 := 0;
   end record;

   --  A received payload.
   type Payload is record
      Valid    : Boolean := False;
      Frame_Id : Unsigned_8 := 0;
      Value_Id : Unsigned_16 := 0;
      Data     : Unsigned_32 := 0;
   end record;

   --  The table positions count in a byte as the reference does; a read
   --  past the table gives no value.
   type Stream is record
      Table       : Value_Ids := (others => 0);
      Size        : Value_Count := 0;
      Index       : Unsigned_8 := 0;
      ESC_Table   : ESC_Ids := (others => 0);
      ESC_Size    : ESC_Count := 0;
      ESC_Index   : Unsigned_8 := 0;
      Cycle       : Unsigned_8 := 0;
      Motor       : Unsigned_8 := 0;
      T1_Count    : Unsigned_8 := 0;
      T2_Count    : Unsigned_8 := 0;
      Receiver    : Receive_State;
   end record;

   --  A data frame is sixteen bytes at most once escaped, and an FPORT reply
   --  eighteen with its length and type.
   Max_Tx : constant := 18;
   subtype Tx_Count is Natural range 0 .. Max_Tx;
   subtype Tx_Bytes is Byte_Array (0 .. Max_Tx - 1);

   type Output is record
      Tx            : Tx_Bytes := (others => 0);
      Count         : Tx_Count := 0;
      Clear_To_Send : Boolean := False;
      Received      : Payload;
   end record;

   --  The tables from the configuration and the sensors present.
   procedure Build (S : in out Stream; B : Build_Inputs);
   --  A frame of the frame id, the value id and the value with its checksum,
   --  behind the FPORT reply's length and type when FPort asks for them.
   procedure Write_Frame (O : in out Output; Frame_Id : Unsigned_8; Value_Id : Unsigned_16; Value : Unsigned_32;
                          FPort : Boolean)
     with Pre  => O.Count = 0,
          Post => O.Count <= Max_Tx;

   --  One byte of the line; Last marks the last byte waiting, when a poll
   --  of this sensor clears it to send.
   procedure Receive (S : in out Stream; C : Byte; Last : Boolean; Clear_To_Send : in out Boolean;
                      Received : out Payload);

   --  The next value within the attempts allowed, once cleared to send, in
   --  the FPORT reply when FPort asks for it.
   procedure Process (S : in out Stream; Inp : Inputs; Attempts : Positive; Clear_To_Send : Boolean;
                      O : in out Output; FPort : Boolean := False);

   --  One task call: the bytes received are read up to the first complete
   --  payload, Consumed says how many were taken, then the reply goes out.
   procedure Update (S : in out Stream; Inp : Inputs; Rx : Byte_Array; Attempts : Positive; O : out Output;
                     Consumed : out Natural)
     with Post => Consumed <= Rx'Length;

end Adaflight.SmartPort_Telemetry;
