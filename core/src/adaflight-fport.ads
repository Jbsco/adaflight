--  The FPORT receiver protocol: the frames unstuffed from the serial bytes
--  into a ring of three buffers between the markers, a frame dropped after
--  the frame time or past the buffer, the frame length and the FrSky
--  checksum checked at the status poll, a control frame decoded through the
--  SBUS channel block with its RSSI, a telemetry request noted for the reply
--  window after the frame, the MSP payload kept for the telemetry layer, the
--  RSSI dropped after half a second without a control frame, the empty
--  reply sent in the window when the telemetry layer has nothing to say,
--  and the raw channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;
with Adaflight.SBUS;

package Adaflight.FPORT with SPARK_Mode is
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Time_Ms is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   subtype Channel is SBUS.Channel;
   subtype Channel_Data is SBUS.Channel_Data;

   --  A buffer holds a request frame and two bytes more; the frame position
   --  runs one past it so an oversize frame is seen.
   Request_Frame_Length  : constant := 25;
   Buffer_Size           : constant := Request_Frame_Length + 2;
   subtype Buffer_Index is Natural range 0 .. Buffer_Size - 1;
   subtype Buffer_Length is Natural range 0 .. Buffer_Size;
   subtype Frame_Position is Natural range 0 .. Buffer_Size + 1;
   type Buffer_Bytes is array (Buffer_Index) of Byte;
   Ring_Size : constant := 3;
   subtype Ring_Index is Natural range 0 .. Ring_Size - 1;

   Frame_Marker              : constant := 16#7E#;
   Escape_Char               : constant := 16#7D#;
   Frame_Time_Us             : constant := 3_000;
   Min_Reply_Delay_Us        : constant := 500;
   Max_Reply_Delay_Us        : constant := 2_000;
   Max_Control_Age_Ms        : constant := 500;
   Max_Consecutive_Telemetry : constant := 2;

   Type_Control           : constant := 16#00#;
   Type_Telemetry_Request : constant := 16#01#;
   Type_Telemetry_Reply   : constant := 16#81#;
   Control_Payload_Length   : constant := 25;
   Telemetry_Payload_Length : constant := 8;
   Reply_Frame_Length       : constant := 8;

   --  The telemetry frame ids: a data request, a null frame, and the read
   --  and write frames that carry MSP.
   Frame_Id_Null  : constant := 16#00#;
   Frame_Id_Data  : constant := 16#10#;
   Frame_Id_Read  : constant := 16#30#;
   Frame_Id_Write : constant := 16#31#;

   type Frame_Buffer is record
      Data        : Buffer_Bytes := (others => 0);
      Length      : Buffer_Length := 0;
      Start_At_Us : Time_Us := 0;
   end record;
   type Ring is array (Ring_Index) of Frame_Buffer;

   --  A telemetry payload: the frame id, the value id, and the data word.
   type Payload is record
      Frame_Id : Byte := 0;
      Value_Id : Serial_Word := 0;
      Data     : Unsigned_32 := 0;
   end record;

   --  What the processing produced for the other units: whether the
   --  telemetry layer was consulted, with a payload, and whether the empty
   --  reply went out.
   type Process_Outputs is record
      Consulted              : Boolean := False;
      Consulted_With_Payload : Boolean := False;
      Sent_Empty_Reply       : Boolean := False;
   end record;

   type State is record
      Buffers              : Ring;
      Write_Index          : Ring_Index := 0;
      Read_Index           : Ring_Index := 0;
      Position             : Frame_Position := 0;
      Frame_Start_At_Us    : Time_Us := 0;
      Escaped              : Boolean := False;
      Telemetry_Frame      : Boolean := False;
      Clear_To_Send        : Boolean := False;
      Last_Telemetry_At_Us : Time_Us := 0;
      Has_MSP              : Boolean := False;
      MSP                  : Payload;
      Last_Control_At_Ms   : Time_Ms := 0;
      Last_Frame_Time_Us   : Time_Us := 0;
      Telemetry_Enabled    : Boolean := False;
      Has_Request          : Boolean := False;
      Rx_Driven_Rate       : Boolean := False;
      Consecutive          : Byte := 0;
      Data                 : Channel_Data := (others => 0);
   end record;

   --  Every channel starts at the count that reads as the center; the
   --  telemetry layer says whether it will answer the requests.
   procedure Init (S : out State; Mid_RC : SBUS.Center_Us; Telemetry : Boolean);

   --  One byte from the serial port at its arrival time. A marker closes a
   --  frame of two bytes or more into the ring when the ring has room,
   --  opens the reply window after a telemetry request, and starts the next
   --  frame. Another byte is unstuffed after an escape, noted as a telemetry
   --  request in the type position, and kept while the frame has room. A
   --  frame older than the frame time plus a margin is dropped.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The frame's status: one buffered frame taken from the ring when its
   --  length byte and checksum agree with it. A control frame decodes the
   --  channels and the RSSI and keeps its start as the frame time unless
   --  flagged. A telemetry request, with the telemetry on, asks for a reply
   --  or keeps an MSP payload. Processing is asked for when a reply or a
   --  payload waits and the reply window has opened. The RSSI drops to zero
   --  half a second after the last control frame.
   procedure Frame_Status (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report
   );

   --  The processing the status asked for: the telemetry layer consulted
   --  while the window is open, the empty reply sent when it left the
   --  window unused, and the payload consumed.
   procedure Process_Frame (
      S                 : in out State;
      Now_Us            : Time_Us;
      Telemetry_Handled : Boolean;
      Result            : out Process_Outputs
   );

   --  A reply the telemetry layer writes drops the frame in progress.
   procedure Begin_Reply (S : in out State);

   function Read_Raw (S : State; Ch : Channel) return Float is (SBUS.Raw_Us (S.Data (Ch)));

end Adaflight.FPORT;
