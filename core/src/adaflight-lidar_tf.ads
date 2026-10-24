--  The Benewake TF serial rangefinders, the TFmini, TF02 and TFnova, with
--  their ranges. Detection takes one of those three, needs a configured port,
--  opens it at 115200 baud, gives the task a 10 ms period, the range and a 90
--  degree cone, and sends the TFmini and TF02 the 100 Hz command. An update
--  reads the clock and every waiting byte through the frame state machine:
--  two sync bytes, six payload bytes and a checksum over all eight. A frame
--  whose checksum fits gives a reading, out of range below the minimum or
--  above the maximum, for a TF02 with a reliability under 7 or a TFnova with
--  a confidence under 90, and otherwise the distance, 13 cm less on a TFmini
--  whose integral time is 7. A wrong checksum counts an error. When no frame
--  came for more than 200 ms and no command went for more than 500 ms, the
--  update sends the command again. A read gives the last reading.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The serial port: its opening by port number and baud rate, the waiting
--  byte count, one byte read, a buffer written and the millisecond clock.
generic
   type Serial_Device is limited private;
   with procedure Open_Port
     (D : in out Serial_Device; Port : Interfaces.Integer_8; Baud : Interfaces.Unsigned_32; Opened : out Boolean);
   with procedure Bytes_Waiting (D : in out Serial_Device; Count : out Natural);
   with procedure Read_Byte (D : in out Serial_Device; B : out Byte);
   with procedure Write_Bytes (D : in out Serial_Device; Data : Byte_Array);
   with procedure Millis (D : in out Serial_Device; Now : out Interfaces.Unsigned_32);
package Adaflight.Lidar_TF with SPARK_Mode is
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;

   TFmini    : constant Byte := 2;
   TF02      : constant Byte := 3;
   TFnova    : constant Byte := 8;
   Port_None : constant Interfaces.Integer_8 := -1;

   type Frame_Phase is (Wait_Start_1, Wait_Start_2, Reading_Payload, Wait_Checksum);
   subtype Frame_Bytes is Byte_Array (0 .. 5);
   subtype Reading is Interfaces.Integer_32 range -2 .. 65_535;

   --  The task period, the range and the cones the driver reports.
   type Device is record
      Delay_Ms                  : Natural range 0 .. 255 := 0;
      Max_Range_Cm              : Interfaces.Unsigned_16 := 0;
      Cone_Decidegrees          : Natural range 0 .. 3600 := 0;
      Cone_Extended_Decidegrees : Natural range 0 .. 3600 := 0;
   end record;

   --  The detected type with its range, 0 for none, whether the port opened,
   --  the frame state, the last reading, the checksum errors, the times of
   --  the last frame and the last command, and the last frame's distance,
   --  strength and two trailing bytes.
   type State is record
      Hardware       : Byte := 0;
      Range_Min      : Interfaces.Unsigned_16 := 0;
      Range_Max      : Interfaces.Unsigned_16 := 0;
      Have_Port      : Boolean := False;
      Phase          : Frame_Phase := Wait_Start_1;
      Frame          : Frame_Bytes := (others => 0);
      Position       : Natural range 0 .. 6 := 0;
      Value          : Reading := 0;
      Errors         : Interfaces.Unsigned_32 := 0;
      Last_Frame_Ms  : Interfaces.Unsigned_32 := 0;
      Last_Reconf_Ms : Interfaces.Unsigned_32 := 0;
      Last_Distance  : Interfaces.Unsigned_16 := 0;
      Last_Strength  : Interfaces.Unsigned_16 := 0;
      Last_Byte_4    : Byte := 0;
      Last_Byte_5    : Byte := 0;
   end record;

   procedure Detect
     (D : in out Serial_Device; S : in out State; Hardware : Byte; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Device);

   procedure Init (S : in out State)
     with Global => null;

   procedure Update (D : in out Serial_Device; S : in out State);

   function Read (S : State) return Reading is (S.Value);

end Adaflight.Lidar_TF;
