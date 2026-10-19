--  The Nooploop TOFSense serial rangefinders, six models with ranges from 2
--  cm to 5, 10, 17 or 33 m. Detection takes one of the models, needs a
--  configured serial port, opens it at 115200 baud and gives the task a 10 ms
--  period, the range and a 90 degree cone. An update reads the clock, notes
--  the first update's time, and reads every waiting byte through the frame
--  state machine: the sync bytes 0x57 and 0x00, then 14 more bytes, the last
--  the sum of the others. A frame whose sum fits gives a reading, out of range
--  for a negative 24-bit distance, one outside the model's range or a status
--  byte of 0xFF, and otherwise the distance in millimeters divided by 10. A
--  frame whose sum does not fit changes nothing. When no frame came for more
--  than 200 ms, or none ever and the first update was more than 200 ms ago,
--  an update more than 200 ms after the last failure report makes the reading
--  a hardware failure, as new data when it was not one already. A read gives
--  no new data until a new reading, then the reading once.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The serial port: its opening by port number and baud rate, the waiting
--  byte count, one byte read and the millisecond clock.
generic
   type Serial_Device is limited private;
   with procedure Open_Port
     (D : in out Serial_Device; Port : Interfaces.Integer_8; Baud : Interfaces.Unsigned_32; Opened : out Boolean);
   with procedure Bytes_Waiting (D : in out Serial_Device; Count : out Natural);
   with procedure Read_Byte (D : in out Serial_Device; B : out Byte);
   with procedure Millis (D : in out Serial_Device; Now : out Interfaces.Unsigned_32);
package Adaflight.Nooploop with SPARK_Mode is
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;

   Model_F2     : constant Byte := 9;
   Model_F2P    : constant Byte := 10;
   Model_F2PH   : constant Byte := 11;
   Model_F      : constant Byte := 12;
   Model_FP     : constant Byte := 13;
   Model_F2MINI : constant Byte := 14;
   Port_None    : constant Interfaces.Integer_8 := -1;

   Out_Of_Range     : constant Interfaces.Integer_32 := -1;
   Hardware_Failure : constant Interfaces.Integer_32 := -2;
   No_New_Data      : constant Interfaces.Integer_32 := -3;

   type Frame_Phase is (Wait_Sync_0, Wait_Sync_1, Reading_Frame);
   subtype Frame_Bytes is Byte_Array (0 .. 15);
   subtype Range_Cm is Interfaces.Unsigned_16 range 0 .. 3300;
   subtype Reading is Interfaces.Integer_32 range -3 .. 3300;

   type Device is record
      Delay_Ms                  : Natural range 0 .. 255 := 0;
      Max_Range_Cm              : Interfaces.Unsigned_16 := 0;
      Cone_Decidegrees          : Natural range 0 .. 3600 := 0;
      Cone_Extended_Decidegrees : Natural range 0 .. 3600 := 0;
   end record;

   --  The detected model with its range, 0 for none, whether the port opened,
   --  the frame state, the latest reading and whether a read took it, and the
   --  times of the last frame, the first update and the last failure report,
   --  0 for none.
   type State is record
      Hardware        : Byte := 0;
      Range_Min_Cm    : Range_Cm := 0;
      Range_Max_Cm    : Range_Cm := 0;
      Have_Port       : Boolean := False;
      Phase           : Frame_Phase := Wait_Sync_0;
      Frame           : Frame_Bytes := (others => 0);
      Position        : Natural range 0 .. 16 := 0;
      Latest          : Reading := No_New_Data;
      Has_New         : Boolean := False;
      Last_Frame_Ms   : Interfaces.Unsigned_32 := 0;
      First_Update_Ms : Interfaces.Unsigned_32 := 0;
      Last_Failure_Ms : Interfaces.Unsigned_32 := 0;
   end record;

   procedure Detect
     (D : in out Serial_Device; S : in out State; Hardware : Byte; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Device);

   procedure Init (S : in out State)
     with Global => null;

   procedure Update (D : in out Serial_Device; S : in out State);

   procedure Read (S : in out State; Distance : out Reading)
     with Global => null;

end Adaflight.Nooploop;
