--  The Jeti EX Bus receiver protocol: the channel and request frames
--  assembled from the serial bytes into their own buffers with a new frame
--  after a gap, the length taken from the header once it is in range, the
--  frame's completion stamped for the telemetry, the sixteen channels decoded
--  at the status poll once the frame's CRC reads zero over it, and the raw
--  channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.Jeti_Ex_Bus with SPARK_Mode is
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Channel_Count : constant := 16;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Channel_Value is Natural range 0 .. 8_191;
   type Channel_Data is array (Channel) of Channel_Value;

   Header_Len            : constant := 6;
   CRC_Len               : constant := 2;
   Max_Channel_Frame     : constant := Header_Len + Channel_Count * 2 + CRC_Len;
   Max_Request_Frame     : constant := 8 + 26;
   Min_Frame_Gap_Us      : constant := 1_000;
   Start_Channel_Frame   : constant := 16#3E#;
   Start_Request_Frame   : constant := 16#3D#;
   Channel_Data_Id       : constant := 16#3E03#;
   Channel_Data_Request  : constant := 16#3E01#;

   --  The header bytes: the sync byte, the request flag, the message length,
   --  the packet id, the data id, and the data length.
   Header_Sync    : constant := 0;
   Header_Req     : constant := 1;
   Header_Msg_Len : constant := 2;
   Header_Sub_Len : constant := 5;

   subtype Frame_Index is Natural range 0 .. Max_Channel_Frame - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;
   subtype Frame_Length is Natural range Header_Len + CRC_Len .. Max_Channel_Frame;

   type Frame_State_Kind is (Zero, In_Progress, Received, Processed);
   type Buffer_Choice is (Channel_Buffer, Request_Buffer);

   function Max_Size (Target : Buffer_Choice) return Natural is
     (case Target is when Channel_Buffer => Max_Channel_Frame, when Request_Buffer => Max_Request_Frame);

   --  The two frame assemblies and the decoded channels. The position never
   --  passes the size of the buffer the bytes go to.
   type State is record
      Position           : Natural range 0 .. Max_Channel_Frame := 0;
      Length             : Frame_Length := Max_Channel_Frame;
      Frame_State        : Frame_State_Kind := Zero;
      Request_State      : Frame_State_Kind := Zero;
      Can_Tx             : Boolean := False;
      Target             : Buffer_Choice := Channel_Buffer;
      Channel_Frame      : Frame_Bytes := (others => 0);
      Request_Frame      : Frame_Bytes := (others => 0);
      Received_Length    : Frame_Length := Max_Channel_Frame;
      Data               : Channel_Data := (others => 0);
      Time_Last_Us       : Time_Us := 0;
      Channel_Stamp_Us   : Time_Us := 0;
      Request_Stamp_Us   : Time_Us := 0;
      Last_Frame_Time_Us : Time_Us := 0;
   end record
     with Dynamic_Predicate => State.Position <= Max_Size (State.Target);

   procedure Init (S : out State);

   --  One byte from the serial port at its arrival time: a gap over a
   --  millisecond drops the frame in progress, a frame starts on the channel
   --  or request sync byte into its buffer, the second byte says whether the
   --  receiver may transmit, the sixth byte's length takes the frame when in
   --  the buffer's range and drops it otherwise, and the last byte of that
   --  length completes the frame with its time.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The channel frame once received: complete with its channels and its
   --  time when the CRC over the frame reads zero, consumed either way.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report);

   --  The EX Bus CRC over the first bytes of a frame.
   function Frame_CRC16 (F : Frame_Bytes; Length : Natural) return Unsigned_16
     with Pre => Length <= Max_Channel_Frame;

   --  The channel value in microseconds, the word's eighth.
   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch)));

end Adaflight.Jeti_Ex_Bus;
