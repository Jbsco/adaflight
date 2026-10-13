--  The MAVLink receiver protocol: the library's frame parser over both
--  framing versions, the X.25 checksum with each message's CRC extra, signed
--  frames taken without a signing key, a bad checksum restarting the parser
--  on a start byte, the RC channels override message copied into the
--  channels as it arrives with the frame time, the radio status message into
--  the receiver's RSSI, dBm, noise, and link quality and the transmitter's
--  free buffer for the telemetry, every other message queued for the
--  telemetry task, and the raw channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;
with Adaflight.MAVLink_Entries;

package Adaflight.MAVLink with SPARK_Mode is
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype CRC_Word is Interfaces.Unsigned_16;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;
   subtype Unsigned_16 is Natural range 0 .. 65_535;
   subtype Message_Id is MAVLink_Entries.Message_Id;

   Channel_Count : constant := 18;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Channel_Value is Natural range 0 .. 65_535;
   type Channel_Data is array (Channel) of Channel_Value;

   Max_Payload : constant := 255;
   subtype Payload_Index is Natural range 0 .. Max_Payload - 1;
   type Payload_Bytes is array (Payload_Index) of Byte;
   Signature_Length : constant := 13;
   subtype Signature_Count is Natural range 0 .. Signature_Length;
   Queue_Size : constant := 16;
   subtype Queue_Index is Natural range 0 .. Queue_Size - 1;

   Start_V2        : constant := 16#FD#;
   Start_V1        : constant := 16#FE#;
   CRC_Init        : constant := 16#FFFF#;
   Flag_In_V1      : constant := 1;
   RC_Override_Id  : constant := 70;
   Radio_Status_Id : constant := 109;
   RSSI_Dbm_Min    : constant := -130;

   --  The X.25 checksum over one more byte, as the library accumulates it.
   function Accumulate (CRC : CRC_Word; Data : Byte) return CRC_Word;

   type Framing is (Incomplete, OK, Bad_CRC, Bad_Signature);

   --  The parser's states, in the library's order.
   type Parse_State is
     (Uninit, Idle, Got_Start, Got_Length, Got_Incompat_Flags, Got_Compat_Flags, Got_Seq, Got_Sysid,
      Got_Compid, Got_Msgid1, Got_Msgid2, Got_Msgid3, Got_Payload, Got_CRC1, Got_Bad_CRC1,
      Signature_Wait, Signature_Wait_Bad_CRC);

   --  A frame as the parser fills it: the running checksum, the header
   --  fields, the payload zero-filled to the message's longest length, and
   --  the two checksum bytes from the wire.
   type Message is record
      Checksum       : CRC_Word := 0;
      Magic          : Byte := 0;
      Len            : Byte := 0;
      Incompat_Flags : Byte := 0;
      Compat_Flags   : Byte := 0;
      Seq            : Byte := 0;
      Sysid          : Byte := 0;
      Compid         : Byte := 0;
      Id             : Message_Id := 0;
      Payload        : Payload_Bytes := (others => 0);
      CK0            : Byte := 0;
      CK1            : Byte := 0;
   end record;

   type Parser is record
      Msg_Received   : Framing := Incomplete;
      State          : Parse_State := Uninit;
      Packet_Idx     : Byte := 0;
      Current_Rx_Seq : Byte := 0;
      Success_Count  : Unsigned_16 := 0;
      Drop_Count     : Unsigned_16 := 0;
      Flags          : Byte := 0;
      Signature_Left : Signature_Count := 0;
   end record;

   type Message_Queue is array (Queue_Index) of Message;

   type State is record
      Rx                 : Message;
      Status             : Parser;
      Received           : Message;
      Queue              : Message_Queue;
      Head               : Queue_Index := 0;
      Tail               : Queue_Index := 0;
      Frame_Received     : Boolean := False;
      Last_Frame_Time_Us : Time_Us := 0;
      Tx_Buffer_Valid    : Boolean := False;
      Tx_Buffer_Free     : Byte := 100;
      Data               : Channel_Data := (others => 1500);
   end record;

   --  Every channel starts at the configured center; the receiver takes the
   --  protocol's RSSI and link quality claims at its own init.
   procedure Init (S : out State; Mid_RC : Channel_Value);

   --  One byte from the serial port at its arrival time, through the frame
   --  parser. A complete frame with a good checksum is an RC channels
   --  override, taken into the channels with the byte's time as the frame
   --  time, a radio status, taken into the receiver and the transmitter
   --  buffer, or another message, queued.
   procedure Receive_Byte (S : in out State; Rx : in out Receiver.State; C : Serial_Word; Now_Us : Time_Us);

   --  The frame's status: complete once after each override message.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report);

   --  The oldest queued message for the telemetry task, when one waits.
   procedure Pop_Queue (S : in out State; Msg : out Message; Got : out Boolean);

   --  The telemetry may send when the last radio status left more free
   --  transmitter buffer than the configured minimum.
   function Should_Send_Telemetry (S : State; Min_Free : Byte) return Boolean is
     (S.Tx_Buffer_Valid and then S.Tx_Buffer_Free > Min_Free);

   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch)));

end Adaflight.MAVLink;
