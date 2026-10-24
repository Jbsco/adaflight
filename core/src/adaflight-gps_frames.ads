--  The GPS frame decoders of the two serial protocols. NMEA sentences are
--  parsed field by field under the sentence parity (GGA, RMC, GSV, GSA). UBX
--  messages are assembled through the preamble, class, id, length, payload
--  and Fletcher checksums (NAV-PVT, NAV-SAT, NAV-POSLLH, NAV-STATUS, NAV-DOP,
--  NAV-SOL, NAV-VELNED, NAV-SVINFO, MON-VER and the acknowledgements). Both
--  fill the solution with the position, the altitude, the dilution, the
--  accuracy, the velocity, the speeds, the satellite count, the time of week
--  and the date and time, set the fix flags and the satellite list, and ask
--  for the clock to be set while it has no time.
with Interfaces;

package Adaflight.GPS_Frames with SPARK_Mode is
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

   --  Latitude and longitude in ten-millionths of a degree, the altitude in
   --  centimetres.
   type Location is record
      Lat, Lon, Alt_Cm : Integer_32 := 0;
   end record;

   --  Dilution of precision times a hundred.
   type Dilution is record
      Pdop, Hdop, Vdop : Unsigned_16 := 0;
   end record;

   --  Horizontal and vertical accuracy in millimetres, speed accuracy in
   --  millimetres per second, heading accuracy in hundred-thousandths of a
   --  degree.
   type Accuracy is record
      Horizontal, Vertical, Speed, Heading : Unsigned_32 := 0;
   end record;

   --  North, east and down velocity in centimetres per second.
   type Velocity is record
      North, East, Down : Integer_16 := 0;
   end record;

   type Date_Time is record
      Year                             : Unsigned_16 := 0;
      Month, Day, Hour, Minute, Second : Unsigned_8 := 0;
      Millis                           : Unsigned_16 := 0;
      Valid                            : Boolean := False;
   end record;

   --  Speeds in centimetres per second, the course in tenths of a degree,
   --  the time in milliseconds into the week, and the interval between
   --  solutions in milliseconds, held between 50 and 2500.
   type Solution is record
      Llh                                   : Location;
      Dop                                   : Dilution;
      Acc                                   : Accuracy;
      Velned                                : Velocity;
      Speed_3d, Ground_Speed, Ground_Course : Unsigned_16 := 0;
      Num_Sat                               : Unsigned_8 := 0;
      Time                                  : Unsigned_32 := 0;
      Nav_Interval_Ms                       : Unsigned_32 := 0;
      Utc                                   : Date_Time;
   end record;

   --  A satellite of the list: the channel, or the constellation id past
   --  the legacy count, the satellite id, the quality flags and the signal
   --  strength.
   type Satellite is record
      Channel, Id, Quality, Cno : Unsigned_8 := 0;
   end record;

   Max_Satellites    : constant := 32;
   Legacy_Satellites : constant := 16;
   subtype Satellite_Index is Natural range 0 .. Max_Satellites - 1;
   type Satellites is array (Satellite_Index) of Satellite;

   --  The request to set the real time clock, made while the clock has no
   --  time.
   type Clock_Request is record
      Set                                 : Boolean := False;
      Year                                : Unsigned_16 := 0;
      Month, Day, Hours, Minutes, Seconds : Unsigned_8 := 0;
      Millis                              : Unsigned_16 := 0;
   end record;

   --  The sentence in progress. The field buffer holds up to fifteen
   --  characters and a terminator, so its last byte is always zero; a
   --  longer field is cut.
   type NMEA_Frame is (No_Frame, GGA, RMC, GSV, GSA);
   subtype Field_Index is Natural range 0 .. 15;
   type Field_Bytes is array (Field_Index) of Unsigned_8
     with Dynamic_Predicate => Field_Bytes (Field_Index'Last) = 0;
   subtype Field_Fill is Unsigned_8 range 0 .. 15;

   --  The values of a sentence, gathered field by field before the parity
   --  check and written to the solution after it.
   type NMEA_Values is record
      Latitude, Longitude, Altitude_Cm       : Integer_32 := 0;
      Num_Sat                                : Unsigned_8 := 0;
      Fix                                    : Boolean := False;
      Speed, Pdop, Hdop, Vdop, Ground_Course : Unsigned_16 := 0;
      Time, Date                             : Unsigned_32 := 0;
   end record;

   type NMEA_Decoder is record
      Values         : NMEA_Values;
      Field          : Field_Bytes := (others => 0);
      Param          : Unsigned_8 := 0;
      Offset         : Field_Fill := 0;
      Parity         : Unsigned_8 := 0;
      Checksum_Param : Boolean := False;
      Frame          : NMEA_Frame := No_Frame;
      Sv_Message     : Unsigned_8 := 0;
   end record;

   type UBX_Phase is (Sync_1, Sync_2, Message_Class, Message_Id, Length_Low, Length_High,
                      Payload_Content, Checksum_A, Checksum_B);

   --  The payload buffer fits the largest message kept, NAV-SAT at the
   --  satellite maximum. A longer payload is checksummed but cut; a declared
   --  length past the sanity limit restarts the frame.
   Payload_Size    : constant := 8 + 12 * Max_Satellites;
   Max_Sane_Length : constant := 776;
   subtype Payload_Index is Natural range 0 .. Payload_Size - 1;
   type Payload_Bytes is array (Payload_Index) of Unsigned_8;

   type Ack_State is (Idle, Waiting, Got_Ack, Got_Nack);
   type Platform is (Undefined, M5, M6, M7, M8, M9, M10);

   type UBX_Decoder is record
      Phase        : UBX_Phase := Sync_1;
      Class, Id    : Unsigned_8 := 0;
      Length       : Unsigned_16 := 0;
      Counter      : Unsigned_16 := 0;
      Payload      : Payload_Bytes := (others => 0);
      Ck_A, Ck_B   : Unsigned_8 := 0;
      Valid_Fix    : Boolean := False;
      New_Position : Boolean := False;
      New_Speed    : Boolean := False;
      Almost_Done  : Boolean := False;
      Ack          : Ack_State := Idle;
      Ack_Message  : Unsigned_8 := 0;
      Gnss_Reply   : Boolean := False;
      Version      : Platform := Undefined;
      M7_Or_Above  : Boolean := False;
      M8_Or_Above  : Boolean := False;
      M9_Or_Above  : Boolean := False;
   end record;

   type Receiver is record
      Sol           : Solution;
      Fix, Fix_Ever : Boolean := False;
      Sats          : Satellites := (others => <>);
      Num_Channels  : Unsigned_8 := 0;
      Last_Nav_Time : Unsigned_32 := 0;
      NMEA          : NMEA_Decoder;
      UBX           : UBX_Decoder;
   end record;

   --  The interval between solutions from the time of week, held between
   --  50 and 2500 milliseconds.
   procedure Nav_Interval (R : in out Receiver);

   --  One byte of an NMEA stream. New_Solution reports a GGA sentence that
   --  passed its parity. Clock carries the setting an RMC sentence asks for
   --  while the clock has no time.
   procedure Receive_NMEA (R : in out Receiver; C : Unsigned_8; Clock_Has_Time : Boolean;
                           New_Solution : out Boolean; Clock : out Clock_Request);

   --  One byte of a UBX stream. New_Solution reports the message that
   --  completed a new position and a new speed together.
   procedure Receive_UBX (R : in out Receiver; C : Unsigned_8; Clock_Has_Time : Boolean;
                          New_Solution : out Boolean; Clock : out Clock_Request);

end Adaflight.GPS_Frames;
