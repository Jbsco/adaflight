--  The LTM telemetry stream: every 100 ms an attitude frame, then a GPS
--  frame or a status frame in turn, and an origin frame every tenth cycle.
--  Each frame is a two-byte start, the frame letter, the little-endian
--  fields and the exclusive-or of the fields.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.LTM_Telemetry with SPARK_Mode is
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

   Cycle_Ms : constant := 100;

   --  The attitude in decidegrees, the mode flags in their order of
   --  precedence, the battery voltage in hundredths of a volt, the charge
   --  drawn, the signal in its 0 to 1023 scale, and the GPS solution with
   --  the home position.
   type Inputs is record
      Pitch, Roll, Yaw : Integer_16 := 0;
      Passthru         : Boolean := False;
      Headfree         : Boolean := False;
      Angle            : Boolean := False;
      Horizon          : Boolean := False;
      Rescue           : Boolean := False;
      Position_Hold    : Boolean := False;
      Altitude_Hold    : Boolean := False;
      Armed            : Boolean := False;
      Failsafe         : Boolean := False;
      Voltage_Cv       : Unsigned_16 := 0;
      Mah_Drawn        : Integer_32 := 0;
      Rssi             : Unsigned_16 := 0;
      GPS_Present      : Boolean := False;
      Fix              : Boolean := False;
      Num_Sat          : Unsigned_8 := 0;
      Lat, Lon         : Integer_32 := 0;
      Ground_Speed     : Unsigned_16 := 0;
      Altitude_Cm      : Integer_32 := 0;
      Home_Lat         : Integer_32 := 0;
      Home_Lon         : Integer_32 := 0;
      Fix_Home         : Boolean := False;
   end record;

   subtype Cycle_Step is Unsigned_8 range 0 .. 9;

   type Stream is record
      Step          : Cycle_Step := 0;
      Last_Cycle_Ms : Unsigned_32 := 0;
   end record;

   --  A cycle writes at most the attitude, a GPS or status frame and the
   --  origin frame.
   Max_Output : constant := 10 + 18 + 18;
   subtype Output_Count is Natural range 0 .. Max_Output;
   subtype Output_Bytes is Byte_Array (0 .. Max_Output - 1);

   type Output is record
      Data  : Output_Bytes := (others => 0);
      Count : Output_Count := 0;
   end record;

   --  One task call: a cycle goes out when 100 ms have passed since the
   --  last one and the stream is enabled.
   procedure Update (S : in out Stream; Inp : Inputs; Now_Ms : Unsigned_32; Enabled : Boolean; O : out Output);

end Adaflight.LTM_Telemetry;
