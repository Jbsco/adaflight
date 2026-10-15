--  The HoTT telemetry link: the receiver asks with two bytes on the single
--  wire, a request id and a sensor address, and the link answers with the
--  electric air module or the GPS module message in the binary mode, or
--  with the text mode's screen, a byte per call with a delay between bytes
--  and a checksum after the last. The messages are prepared from the
--  sensors five times a second, while one may be on its way out. The text
--  mode runs the telemetry task faster and turns the transmitter's buttons
--  into menu keys.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.HoTT_Telemetry with SPARK_Mode is
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

   type Battery_State is (OK, Warning, Critical, Not_Present, Init_State);

   type Settings is record
      Alarm_Interval_S : Unsigned_8 := 5;
      GPS_Present      : Boolean := False;
   end record;

   type Inputs is record
      Now_Us            : Unsigned_32 := 0;
      Task_Period_Us    : Integer_32 := 0;
      In_Menu           : Boolean := False;
      Now_Ms            : Unsigned_32 := 0;
      Voltage_Dv        : Unsigned_16 := 0;
      Voltage_State     : Battery_State := OK;
      Consumption_State : Battery_State := OK;
      Amperage_Ca       : Integer_32 := 0;
      Mah_Drawn         : Integer_32 := 0;
      Altitude_Cm       : Integer_32 := 0;
      Vario_Cms         : Integer_16 := 0;
      Fix               : Boolean := False;
      Num_Sat           : Unsigned_8 := 0;
      Lat               : Integer_32 := 0;
      Lon               : Integer_32 := 0;
      Ground_Speed      : Unsigned_16 := 0;
      Distance_Home     : Unsigned_16 := 0;
      Direction_Home    : Integer_16 := 0;
   end record;

   Message_Length : constant := 44;
   subtype Message is Byte_Array (0 .. Message_Length - 1);

   --  The text mode's screen: the start byte, the escape byte, the warning,
   --  eight rows of 21 characters and the stop byte.
   Text_Rows   : constant := 8;
   Text_Cols   : constant := 21;
   Text_Length : constant := 3 + Text_Rows * Text_Cols + 1;
   subtype Text_Message is Byte_Array (0 .. Text_Length - 1);
   subtype Message_Position is Natural range 0 .. Text_Length;

   Text_Sensor_Id : constant Byte := 16#E0#;
   Text_Escape    : constant Byte := 16#01#;

   type Message_Kind is (No_Message, EAM_Message, GPS_Message, Text_Mode_Message);

   --  The menu key a transmitter button gives.
   type Menu_Key is (None, Up, Down, Left, Right);

   type Link is record
      EAM              : Message := (others => 0);
      GPS              : Message := (others => 0);
      Last_Prepared_Us : Unsigned_32 := 0;
      Last_Request_Us  : Unsigned_32 := 0;
      Last_Alarm_Ms    : Unsigned_32 := 0;
      Serial_Timer_Us  : Unsigned_32 := 0;
      Sending          : Boolean := False;
      Pending          : Message_Kind := No_Message;
      Position         : Message_Position := 0;
      Remaining        : Unsigned_8 := 0;
      Crc              : Unsigned_8 := 0;
      Looking          : Boolean := True;
      Text             : Text_Message := (others => 0);
      Text_Alive       : Boolean := False;
      Saved_Period_Us  : Integer_32 := 0;
      Request_Wait_Us  : Unsigned_32 := 4000;
      Byte_Delay_Us    : Unsigned_32 := 3000;
      Escape_Back      : Boolean := False;
   end record;

   --  A byte sent and the bytes taken; the telemetry task's new period; and
   --  for the menu system a text mode request's menu open on this display,
   --  its exit with a save, its open again, and the external key.
   type Output is record
      Sent       : Boolean := False;
      B          : Byte := 0;
      Consumed   : Natural := 0;
      Reschedule : Boolean := False;
      Period_Us  : Integer_32 := 0;
      Open_Menu  : Boolean := False;
      Exit_Menu  : Boolean := False;
      Reopen     : Boolean := False;
      Key_Set    : Boolean := False;
      Key        : Menu_Key := None;
   end record;

   --  The link with its messages' constant bytes.
   procedure Init (L : out Link);

   --  The menu system's writes into the text mode's screen: a character
   --  within the rows and columns, and the escape byte that marks the
   --  screen as the menu's or asks the transmitter to leave it.
   procedure Text_Write (L : in out Link; Col, Row : Byte; C : Byte);

   procedure Text_Grab (L : in out Link)
     with Post => L.Text (1) = Text_Sensor_Id;

   procedure Text_Exit (L : in out Link)
     with Post => L.Text (1) = Text_Escape;

   --  One task call with the bytes waiting on the port; the bytes not
   --  taken wait for the next call.
   procedure Update (L : in out Link; C : Settings; Inp : Inputs; Rx : Byte_Array; O : out Output)
     with Post => O.Consumed <= Rx'Length;

end Adaflight.HoTT_Telemetry;
