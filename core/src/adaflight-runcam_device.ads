--  The RunCam device link over one serial line. Packets are a header, a
--  command, the data and a checksum; the older split cameras take a five
--  byte command with a tail. At the start the device information is asked
--  with retries, and on the last failure the older command goes out. One
--  request at a time waits for its reply with a timeout and retries, and
--  the camera's own requests are parsed for the attitude it asks for. The
--  camera buttons follow three switches once per activation, and the five
--  key cable is driven from the sticks: a connection opened and closed with
--  yaw, the keys from roll and pitch while in the menu, each press released
--  when the sticks return to centre.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.RunCam_Device with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;

   Header        : constant Byte := 16#CC#;
   Split_Header  : constant Byte := 16#55#;
   Split_Control : constant Byte := 16#01#;
   Split_Tail    : constant Byte := 16#AA#;

   Cmd_Device_Info : constant Unsigned_8 := 16#00#;
   Cmd_Camera      : constant Unsigned_8 := 16#01#;
   Cmd_Key_Press   : constant Unsigned_8 := 16#02#;
   Cmd_Key_Release : constant Unsigned_8 := 16#03#;
   Cmd_Connection  : constant Unsigned_8 := 16#04#;
   Cmd_Attitude    : constant Unsigned_8 := 16#50#;

   Feature_Power_Button : constant Unsigned_16 := 2 ** 0;
   Feature_Wifi_Button  : constant Unsigned_16 := 2 ** 1;
   Feature_Change_Mode  : constant Unsigned_16 := 2 ** 2;
   Feature_Attitude     : constant Unsigned_16 := 2 ** 9;

   --  The protocol the device speaks, numbered as the configuration does.
   type Protocol is (Split, V1_0, Unknown);

   type Settings is record
      Protocol_Setting : Protocol := Split;
      Feature          : Unsigned_16 := 0;
      Init_Attempts    : Natural := 6;
      Init_Interval_Ms : Unsigned_32 := 1000;
   end record;

   type Info is record
      Version  : Protocol := Split;
      Features : Unsigned_16 := 0;
   end record;

   type Result is (Success, Incorrect_Crc, Timeout);
   type Parser is (No_Parser, Info_Reply, Simulation);

   Max_Packet : constant := 64;
   subtype Packet_Fill is Natural range 0 .. Max_Packet;
   subtype Packet_Bytes is Byte_Array (0 .. Max_Packet - 1);
   subtype Reply_Length is Natural range 0 .. 5;

   --  The one request that waits for its reply. The request of the older
   --  protocol that follows a failed device information request never
   --  waits (finding F78), so every waiting request speaks the newer one.
   type Waiting is record
      Active       : Boolean := False;
      Command      : Unsigned_8 := 0;
      Expected     : Reply_Length := 0;
      Received     : Packet_Fill := 0;
      Reply        : Packet_Bytes := (others => 0);
      Timeout_Ms   : Unsigned_32 := 0;
      Timeout_At   : Unsigned_32 := 0;
      Parse_With   : Parser := No_Parser;
      Param        : Byte := 0;
      Param_Length : Natural range 0 .. 1 := 0;
      Retries      : Integer := 0;
      Outcome      : Result := Success;
   end record;

   --  The camera's own request being parsed; an unsupported command and
   --  the 200 ms reset return the state to the header (finding F77).
   Max_Data : constant := 61;
   subtype Data_Fill is Natural range 0 .. Max_Data;
   subtype Data_Bytes is Byte_Array (0 .. Max_Data - 1);

   State_Header      : constant Unsigned_8 := 0;
   State_Command     : constant Unsigned_8 := 1;
   State_Data_Length : constant Unsigned_8 := 2;
   State_Data        : constant Unsigned_8 := 3;
   State_Crc         : constant Unsigned_8 := 4;

   type Request is record
      State           : Unsigned_8 := State_Header;
      Expected_Length : Unsigned_8 := 0;
      Command         : Unsigned_8 := 0;
      Data            : Data_Bytes := (others => 0);
      Length          : Data_Fill := 0;
      Last_Byte_Ms    : Unsigned_32 := 0;
      Done            : Boolean := False;
   end record;

   type Switches is array (1 .. 3) of Boolean;

   type Device is record
      Port_Open        : Boolean := False;
      Device_Info      : Info;
      Ready            : Boolean := False;
      Wait             : Waiting;
      Req              : Request;
      Switch_Active    : Switches := (others => True);
      In_Menu          : Boolean := False;
      Button_Pressed   : Boolean := False;
      Waiting_Response : Boolean := False;
   end record;

   type Beep is (No_Beep, Connection_Open, Connection_Close);

   --  The stick positions in microseconds, the switches and the flags of
   --  a call, with the attitude in decidegrees.
   type Inputs is record
      Now_Ms          : Unsigned_32 := 0;
      Armed           : Boolean := False;
      Blocked         : Boolean := False;
      Menu_Open       : Boolean := False;
      Sticks_Disabled : Boolean := False;
      Camera          : Switches := (others => False);
      Throttle        : Float := 1500.0;
      Roll            : Float := 1500.0;
      Pitch           : Float := 1500.0;
      Yaw             : Float := 1500.0;
      Att_Roll        : Integer_16 := 0;
      Att_Pitch       : Integer_16 := 0;
      Att_Yaw         : Integer_16 := 0;
   end record;

   Max_Tx : constant := 256;
   subtype Tx_Count is Natural range 0 .. Max_Tx;
   subtype Tx_Bytes is Byte_Array (0 .. Max_Tx - 1);

   --  The bytes sent in one call.
   type Transmission is record
      Tx    : Tx_Bytes := (others => 0);
      Count : Tx_Count := 0;
   end record;

   --  Flushed says a request cleared the receive buffer in this call, so
   --  Consumed covers every byte offered.
   type Events is record
      Line     : Transmission;
      Sound    : Beep := No_Beep;
      Consumed : Natural := 0;
      Flushed  : Boolean := False;
   end record;

   --  The start: the port, the configured protocol and the first device
   --  information request when the port is open.
   procedure Init (D : out Device; C : Settings; Port_Opened : Boolean; Now_Ms : Unsigned_32; E : out Events);

   --  One task call with the bytes received since the last; the bytes not
   --  taken are offered again, unless a request flushed them. With the
   --  port closed the call does nothing, as the task never runs then.
   procedure Update (D : in out Device; C : Settings; Inp : Inputs; Rx : Byte_Array; E : out Events)
     with Post => E.Consumed <= Rx'Length;

end Adaflight.RunCam_Device;
