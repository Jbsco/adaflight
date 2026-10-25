--  The MSP serial port: the frame decoder for the three framings (version 1,
--  version 2 carried in a version 1 frame, and version 2 native), the port's
--  handling of the bytes between frames (the command line and reboot requests
--  with their guard time), the frame encoder for replies with the jumbo header
--  past 254 payload bytes, and the configurator activity.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Clock;

package Adaflight.MSP_Port with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   In_Buffer_Size      : constant := 192;
   Max_Payload         : constant := 512;
   Jumbo_Limit         : constant := 255;
   Pending_Guard_Ms    : constant := 100;
   Activity_Timeout_Ms : constant := 5_000;
   V1_Header_Size      : constant := 2;
   Jumbo_Header_Size   : constant := 2;
   V2_Header_Size      : constant := 5;
   V2_Frame_Id         : constant Byte := 255;

   type Framing is (V1, V2_Over_V1, V2_Native);
   type Packet_Kind is (Command, Reply);
   type Decoder_Phase is
     (Idle, Header_Start, Header_M, Header_X,
      Header_V1, Payload_V1, Checksum_V1,
      Header_V2_Over_V1, Payload_V2_Over_V1, Checksum_V2_Over_V1,
      Header_V2_Native, Payload_V2_Native, Checksum_V2_Native,
      Command_Received);
   type Port_Phase is (Idle, Packet, CLI_Active, CLI_Command);
   type Pending_Request is (None, Bootloader, Command_Line);

   subtype Command_Code is Natural range 0 .. 65_535;
   subtype Size is Natural range 0 .. In_Buffer_Size;
   subtype In_Index is Natural range 0 .. In_Buffer_Size - 1;
   subtype In_Buffer is Byte_Array (In_Index);

   --  The buffer position stays below what a phase may write: zero before a
   --  header, the header sizes while a header fills, and the data size while
   --  a payload fills, so no byte lands past the buffer.
   function Offset_In_Range (Phase : Decoder_Phase; Offset, Data_Size : Size) return Boolean is
     (case Phase is
        when Header_M | Header_X => Offset = 0,
        when Header_V1 => Offset < V1_Header_Size,
        when Header_V2_Native => Offset < V2_Header_Size,
        when Header_V2_Over_V1 => Offset < V1_Header_Size + V2_Header_Size,
        when Payload_V1 | Payload_V2_Over_V1 | Payload_V2_Native => Offset < Data_Size,
        when others => True);

   type Port is record
      Phase            : Port_Phase := Idle;
      Decoder          : Decoder_Phase := Idle;
      Kind             : Packet_Kind := Command;
      Version          : Framing := V1;
      Data             : In_Buffer := (others => 0);
      Command_Id       : Command_Code := 0;
      Flags            : Byte := 0;
      Offset           : Size := 0;
      Data_Size        : Size := 0;
      Checksum_1       : Byte := 0;
      Checksum_2       : Byte := 0;
      Pending          : Pending_Request := None;
      Last_Activity_Ms : Unsigned_32 := 0;
   end record
     with Dynamic_Predicate => Offset_In_Range (Port.Decoder, Port.Offset, Port.Data_Size);

   --  What the caller supplies per call: whether the bytes between frames are
   --  read as requests, whether a device streams on the port (its bytes are
   --  never requests or configurator activity), the reboot character, and
   --  whether the command line kept the port this call.
   type Options is record
      Evaluate_Non_MSP : Boolean := True;
      Peripheral       : Boolean := False;
      Reboot_Character : Byte := Character'Pos ('R');
      CLI_Running      : Boolean := False;
   end record;

   --  What one call produced: a complete command frame for the caller to
   --  answer, a complete reply frame, the command line opened after its guard
   --  time or entered at once, or a reboot request past its guard time.
   type Event is (Nothing, Command_Frame, Reply_Frame, CLI_Opened, CLI_Command_Entered, Reset_Requested);

   procedure Init (P : out Port);

   --  One scheduler call over the bytes waiting on the port. Between frames
   --  every byte refreshes the activity time: a frame start cancels a pending
   --  request, the reboot character and the hash mark set one, a start of text
   --  enters the command line, and any other byte cancels a pending reboot.
   --  Inside a frame the bytes feed the decoder until it completes one frame
   --  or rejects it, so at most one frame completes per call and the bytes
   --  after it wait for the next. A pending request fires once the port has
   --  been idle for the guard time. The command line keeps the port while it
   --  runs.
   procedure Process (P : in out Port; Input : Byte_Array; Consumed : out Natural;
                      Now_Ms : Unsigned_32; Opt : Options; Ev : out Event)
     with Post => Consumed <= Input'Length;

   Max_Header  : constant := 12;
   Max_Trailer : constant := 2;
   Max_Frame   : constant := Max_Header + Max_Payload + Max_Trailer;
   subtype Payload_Size is Natural range 0 .. Max_Payload;
   subtype Frame_Index is Natural range 0 .. Max_Frame - 1;
   subtype Frame_Buffer is Byte_Array (Frame_Index);

   --  The header carries the start, the framing letter, the direction, then
   --  the version 1 size and command (with the jumbo size when the size byte
   --  reads 255), the version 2 flags, command and size, or both. In the
   --  combined framing the jumbo size follows the version 1 header and the
   --  version 2 header follows it.
   function Header_Length (Version : Framing; Payload : Payload_Size) return Positive is
     (case Version is
        when V1         => (if Payload >= Jumbo_Limit then 7 else 5),
        when V2_Over_V1 => (if Payload + V2_Header_Size + 1 >= Jumbo_Limit then 12 else 10),
        when V2_Native  => 8);

   function Trailer_Length (Version : Framing) return Positive is (if Version = V2_Over_V1 then 2 else 1);

   function Frame_Length (Version : Framing; Payload : Payload_Size) return Positive is
     (Header_Length (Version, Payload) + Payload + Trailer_Length (Version));

   --  The reply frame in the request's framing: an error reply carries the
   --  error direction, and the checksums close the frame. A version 1 header
   --  holds a one-byte command.
   procedure Encode (Version : Framing; Command : Command_Code; Flags : Byte; Error : Boolean;
                     Payload : Byte_Array; Frame : out Frame_Buffer; Length : out Positive)
     with Pre  => Payload'Length <= Max_Payload and then (if Version = V1 then Command <= 255),
          Post => Length = Frame_Length (Version, Payload'Length);

   --  A frame goes out when the transmit buffer is empty, whatever its
   --  length, or when the frame fits the free room.
   function May_Send (Length : Natural; Buffer_Empty : Boolean; Free : Natural) return Boolean is
     (Buffer_Empty or else Free >= Length);

   --  A configurator is active while a port a device does not stream on has
   --  seen a byte within the timeout.
   function Configurator_Active (P : Port; Now_Ms : Unsigned_32; Peripheral : Boolean) return Boolean is
     (P.Last_Activity_Ms /= 0 and then not Peripheral
      and then Clock.Elapsed (Now_Ms, P.Last_Activity_Ms) < Activity_Timeout_Ms);

end Adaflight.MSP_Port;
