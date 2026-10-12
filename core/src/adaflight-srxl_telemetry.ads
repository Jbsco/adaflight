--  The Spektrum SRXL telemetry frames: three slots in turn, the link
--  quality and the rate frames always, then one user frame cycling over
--  the flight pack current, the two GPS frames and the text generator
--  line, each frame two address bytes, a length, sixteen payload bytes
--  and a checksum, handed to the receiver driver when its buffer is empty.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.SRXL_Telemetry with SPARK_Mode is
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

   type Settings is record
      Report_Cell_Voltage : Boolean := False;
      GPS_Feature         : Boolean := False;
   end record;

   subtype Rpm_Average is Float range 0.0 .. 1.6e7;
   subtype Coordinate is Integer_32 range -(2 ** 31 - 1) .. 2 ** 31 - 1;

   type Inputs is record
      Now_Us           : Unsigned_32 := 0;
      Buffer_Empty     : Boolean := True;
      Menu_On_Display  : Boolean := False;
      Voltage_Cv       : Unsigned_16 := 0;
      Cell_Cv          : Unsigned_16 := 0;
      Core_Temperature : Integer_16 := 0;
      ESC_Valid        : Boolean := False;
      ESC_Rpm          : Integer_16 := 0;
      Dshot_Telemetry  : Boolean := False;
      Dshot_Rpm        : Rpm_Average := 0.0;
      Amperage_Ca      : Integer_32 := 0;
      Mah_Drawn        : Integer_32 := 0;
      Fix              : Boolean := False;
      Num_Sat          : Unsigned_8 := 0;
      Lat              : Coordinate := 0;
      Lon              : Coordinate := 0;
      Alt_Cm           : Integer_32 := 0;
      Ground_Speed     : Unsigned_16 := 0;
      Ground_Course    : Unsigned_16 := 0;
      Pdop             : Unsigned_16 := 0;
   end record;

   Rows          : constant := 9;
   Columns       : constant := 13;
   Input_Columns : constant := 12;
   subtype Row_Index is Natural range 0 .. Rows - 1;
   subtype Column_Index is Natural range 0 .. Columns - 1;
   type Text_Buffer is array (Row_Index, Column_Index) of Byte;
   type Line_Flags is array (Row_Index) of Boolean;

   type Stream is record
      Index        : Natural range 0 .. 2 := 0;
      User_Index   : Natural range 0 .. 3 := 0;
      Sent_Amps    : Unsigned_16 := 0;
      Sent_Mah     : Unsigned_16 := 0;
      Last_Pack_Us : Unsigned_32 := 0;
      Text         : Text_Buffer := (others => (others => 0));
      Line_Sent    : Line_Flags := (others => False);
      Line_No      : Row_Index := 0;
   end record;

   Frame_Size : constant := 21;
   subtype Frame is Byte_Array (0 .. Frame_Size - 1);

   type Output is record
      Tx    : Frame := (others => 0);
      Count : Natural range 0 .. Frame_Size := 0;
   end record;

   --  A character of the text generator, from the menu system; a changed
   --  character marks its line for sending.
   procedure Put_Char (S : in out Stream; Column, Row : Natural; C : Byte);

   --  One task call: the next slot's frame when the driver's buffer is
   --  empty, or nothing when the slot's frame has nothing to say.
   procedure Update (S : in out Stream; C : Settings; Inp : Inputs; O : out Output);

end Adaflight.SRXL_Telemetry;
