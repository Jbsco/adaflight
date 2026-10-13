--  Jeti EX Bus telemetry: the answer to a transmitter's telemetry request,
--  sent when the receiver may transmit, the request is fresh and checks out,
--  and the bus is quiet. The first 255 answers describe the sensors one text
--  message each, the device descriptions included; the answers after them
--  carry the values of the enabled sensors, one group of fifteen at a time
--  and at most four values a message. GPS sensors leave the values when the
--  text phase ends and return once a GPS is detected. The port, the readings
--  and the receiver's frames stay with the target.
with Interfaces;
with Adaflight.Jeti_Ex_Bus;

package Adaflight.Jeti_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   Sensor_Count : constant := 32;
   subtype Sensor_Index is Natural range 0 .. Sensor_Count - 1;
   type Sensor_Set is array (Sensor_Index) of Boolean;

   --  The sensors present at start: the battery meters, the barometer, the
   --  accelerometer and the compass, the GPS and ESC sensor features, and a
   --  debug mode.
   type Settings is record
      Voltage_Meter  : Boolean := True;
      Current_Meter  : Boolean := True;
      Baro           : Boolean := False;
      Acc            : Boolean := True;
      Mag            : Boolean := False;
      GPS_Feature    : Boolean := False;
      ESC_Feature    : Boolean := False;
      Debug_Mode     : Boolean := False;
   end record;

   Max_Motors : constant := 8;
   subtype Motor_Index is Natural range 0 .. Max_Motors - 1;
   subtype Erpm_Hundreds is Natural range 0 .. 32_767;
   type Motor_Rpms is array (Motor_Index) of Erpm_Hundreds;
   type Motor_Ages is array (Motor_Index) of Unsigned_8;
   subtype Acc_Reading is Float range -1.0E6 .. 1.0E6;
   type Acc_Readings is array (0 .. 2) of Acc_Reading;
   type Debug_Values is array (0 .. 7) of Integer_16;

   --  What the sensors read: the battery, the altitude and vario, the
   --  attitude, the GPS solution and home, the accelerometer, the ESC
   --  telemetry, the debug values, and whether a GPS is detected.
   type Inputs is record
      Legacy_Voltage  : Unsigned_16 := 0;
      Pack_Voltage    : Unsigned_16 := 0;
      Amperage        : Integer_32 := 0;
      Altitude_Cm     : Integer_32 := 0;
      MAh_Drawn       : Integer_32 := 0;
      Vario           : Integer_16 := 0;
      Roll            : Integer_16 := 0;
      Pitch           : Integer_16 := 0;
      Yaw             : Integer_16 := 0;
      Satellites      : Unsigned_8 := 0;
      Longitude       : Integer_32 := 0;
      Latitude        : Integer_32 := 0;
      Ground_Speed    : Unsigned_16 := 0;
      Home_Distance   : Unsigned_16 := 0;
      Home_Direction  : Integer_16 := 0;
      Ground_Course   : Unsigned_16 := 0;
      GPS_Altitude_Cm : Integer_32 := 0;
      GPS_Sensor      : Boolean := False;
      Acc_ADC         : Acc_Readings := (others => 0.0);
      One_G           : Positive range 1 .. 65_535 := 2_048;
      Motor_Count     : Natural range 0 .. Max_Motors := 4;
      Rpm             : Motor_Rpms := (others => 0);
      Data_Age        : Motor_Ages := (others => 255);
      Erpm_To_Hz      : Float range 0.0 .. 100.0 := 0.0;
      Debug           : Debug_Values := (others => 0);
   end record;

   --  The enabled sensors, the first of them, the next value to send, the
   --  description counter, the text answers left, and whether the GPS
   --  sensors are back in the values.
   type State is record
      Enabled      : Sensor_Set := (others => False);
      First_Active : Sensor_Index := 0;
      Item         : Sensor_Index := 0;
      Description  : Unsigned_8 := 16#FF#;
      Request_Loop : Unsigned_8 := 16#FF#;
      All_Active   : Boolean := True;
   end record;

   Max_Frame : constant := 40;
   type Frame_Bytes is array (1 .. Max_Frame) of Unsigned_8;
   type Output is record
      Data   : Frame_Bytes := (others => 0);
      Length : Natural range 0 .. Max_Frame := 0;
   end record;

   --  The sensors the settings enable, and the first of them.
   procedure Init (S : out State; C : Settings);

   --  One call of the telemetry task: a stale request is dropped, a request
   --  that is not a telemetry request or fails its CRC is dropped, and a
   --  telemetry request is answered once no byte waits on the port; the
   --  answer ends the receiver's permission to transmit.
   procedure Handle
     (S       : in out State;
      Rx      : in out Adaflight.Jeti_Ex_Bus.State;
      C       : Settings;
      Inp     : Inputs;
      Now_Us  : Unsigned_32;
      Waiting : Natural;
      O       : out Output);

end Adaflight.Jeti_Telemetry;
