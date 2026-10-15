--  The MSP in messages that hand the board running values: the receiver's
--  channels, a GPS solution, the clock, and the RSSI a transmitter reports.
--  A request reads zero past its end. Receiver channels past the eighteen
--  are an error that hands nothing on.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.MSP_Receiver;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Runtime_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Raw_RC_Command  : constant := 200;
   Set_Raw_GPS_Command : constant := 201;
   Set_TX_Info_Command : constant := 186;
   Set_RTC_Command     : constant := 246;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Raw_RC_Command | Set_Raw_GPS_Command | Set_TX_Info_Command | Set_RTC_Command);

   type Result is (Ack, Error);

   --  A GPS solution: the fix, the satellites in use, the position in
   --  degrees times ten million, the altitude in centimeters and the ground
   --  speed in centimeters per second.
   type GPS_Solution is record
      Fix          : Boolean := False;
      Satellites   : Byte := 0;
      Latitude     : Interfaces.Integer_32 := 0;
      Longitude    : Interfaces.Integer_32 := 0;
      Altitude_Cm  : Interfaces.Integer_32 := 0;
      Ground_Speed : Interfaces.Unsigned_16 := 0;
   end record;

   --  The running values a message hands on, each with whether it came: the
   --  receiver's channels, zero past their count; the GPS solution, marked
   --  as an MSP update; the clock in milliseconds since the epoch; and the
   --  transmitter's RSSI.
   type Effects is record
      RC_Frame   : Boolean := False;
      Frame      : MSP_Receiver.Channel_Data := (others => 0);
      Count      : MSP_Receiver.Count_Range := 0;
      GPS        : Boolean := False;
      Solution   : GPS_Solution;
      Clock      : Boolean := False;
      Clock_Ms   : Interfaces.Integer_64 := 0;
      RSSI       : Boolean := False;
      RSSI_Value : Byte := 0;
   end record;

   No_Effects : constant Effects := (others => <>);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process (Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result; E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then E = No_Effects);

end Adaflight.MSP_Runtime_In;
