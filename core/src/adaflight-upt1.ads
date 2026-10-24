--  The Upixels UP-T1 serial module, a laser rangefinder and an optical flow
--  sensor in one, whose frames the rangefinder update parses for both. Either
--  detection opens the configured port at 115200 baud when the other has not,
--  and gives the rangefinder task a 10 ms period, a 12 m range and a 90
--  degree cone, or the optical flow task a 20 ms period, an 8 cm minimum
--  range, a quality threshold of 30 and a 60 ms gyro delay. The parser waits
--  for 22 bytes of the module's startup text, sends the command that selects
--  the protocol, then takes frames of a header 0xFE, a length 0x0A, ten data
--  bytes, their exclusive-or and a footer 0x55. A frame gives the distance in
--  centimeters when the laser status is 0xF5 and the distance lies between 25
--  and 12000 mm, and out of range otherwise, and counts a wrong checksum or
--  footer as an error. The flow integrals of the frames with a valid laser
--  status and a positive integration time sum over the update and give a rate
--  in radians per second over the summed window when it is at most 1 s. Five
--  invalid flow frames in a row zero the rate and the quality. A read gives
--  the distance once, then no new data.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The serial port: its opening by port number and baud rate, the waiting
--  byte count, one byte read, a buffer written and the microsecond clock.
generic
   type Serial_Device is limited private;
   with procedure Open_Port
     (D : in out Serial_Device; Port : Interfaces.Integer_8; Baud : Interfaces.Unsigned_32; Opened : out Boolean);
   with procedure Bytes_Waiting (D : in out Serial_Device; Count : out Natural);
   with procedure Read_Byte (D : in out Serial_Device; B : out Byte);
   with procedure Write_Bytes (D : in out Serial_Device; Data : Byte_Array);
   with procedure Micros (D : in out Serial_Device; Now : out Interfaces.Unsigned_32);
package Adaflight.UPT1 with SPARK_Mode is
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;

   Port_None    : constant Interfaces.Integer_8 := -1;
   Out_Of_Range : constant Interfaces.Integer_32 := -1;
   No_New_Data  : constant Interfaces.Integer_32 := -3;

   type Frame_Phase is (Wait_Reset, Wait_Header, Wait_Length, Reading_Data, Wait_Checksum, Wait_Footer);
   subtype Data_Bytes is Byte_Array (0 .. 9);
   subtype Reading is Interfaces.Integer_32 range -3 .. 1200;
   subtype Rate is Float range -1.0E12 .. 1.0E12;

   type Rangefinder_Device is record
      Delay_Ms                  : Natural range 0 .. 255 := 0;
      Max_Range_Cm              : Interfaces.Unsigned_16 := 0;
      Cone_Decidegrees          : Natural range 0 .. 3600 := 0;
      Cone_Extended_Decidegrees : Natural range 0 .. 3600 := 0;
   end record;

   type Flow_Device is record
      Delay_Ms      : Natural range 0 .. 255 := 0;
      Min_Range_Cm  : Interfaces.Integer_16 := 0;
      Min_Quality   : Byte := 0;
      Gyro_Delay_Us : Interfaces.Unsigned_32 := 0;
   end record;

   --  The flow sample: its time, the quality of the last usable frame, the
   --  rates, and whether the range, the flow and the window were valid in
   --  the last frame.
   type Flow_Data is record
      Time_Stamp_Us : Interfaces.Unsigned_32 := 0;
      Quality       : Interfaces.Integer_16 := 0;
      Rate_X        : Rate := 0.0;
      Rate_Y        : Rate := 0.0;
      Range_Valid   : Boolean := False;
      Flow_Valid    : Boolean := False;
      Dt_Valid      : Boolean := False;
   end record;

   --  The last frame's values and the parser phase before the last byte,
   --  which the reference shows through its debug values.
   type Debug_Values is record
      Distance_Mm    : Interfaces.Unsigned_16 := 0;
      Confidence     : Byte := 0;
      Flow_X         : Interfaces.Integer_16 := 0;
      Flow_Y         : Interfaces.Integer_16 := 0;
      Valid_Status   : Byte := 0;
      Integration_Us : Interfaces.Unsigned_16 := 0;
      Reported       : Interfaces.Integer_32 range -99 .. 1200 := 0;
      Phase_Seen     : Frame_Phase := Wait_Reset;
   end record;

   --  Whether the port opened, the parser state, the reading and whether a
   --  read took it, the checksum and footer errors, the bytes received since
   --  the start, the flow sample with the last usable quality, the last
   --  laser distance in millimeters with its time, the invalid flow frames
   --  in a row, and the debug values.
   type State is record
      Have_Port        : Boolean := False;
      Phase            : Frame_Phase := Wait_Reset;
      Frame            : Data_Bytes := (others => 0);
      Position         : Natural range 0 .. 10 := 0;
      Value            : Reading := 0;
      Errors           : Interfaces.Unsigned_16 := 0;
      Has_New          : Boolean := False;
      Byte_Count       : Interfaces.Unsigned_32 := 0;
      Flow             : Flow_Data;
      Flow_Quality     : Byte := 0;
      Distance_Mm      : Interfaces.Integer_32 := No_New_Data;
      Distance_Time_Us : Interfaces.Unsigned_32 := 0;
      Invalid_Count    : Natural range 0 .. 5 := 0;
      Debug            : Debug_Values;
   end record;

   procedure Detect_Rangefinder
     (D : in out Serial_Device; S : in out State; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Rangefinder_Device);

   procedure Detect_Flow
     (D : in out Serial_Device; S : in out State; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Flow_Device);

   procedure Init (S : in out State)
     with Global => null;

   procedure Update (D : in out Serial_Device; S : in out State);

   procedure Read (S : in out State; Distance : out Reading)
     with Global => null;

   function Flow (S : State) return Flow_Data is (S.Flow);

end Adaflight.UPT1;
