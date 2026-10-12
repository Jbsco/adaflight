--  The MSP tunnel over a telemetry link: requests arrive in chunks behind a
--  status byte with the sequence number, the start flag and the protocol
--  version, and are assembled up to the size the first chunk declares; the
--  reply goes back in chunks of the link's size behind the same status byte,
--  the reply header in the first chunk and the error bit set for a failed
--  request. The command processor stays with the target: the tunnel reports
--  a request ready, the owner processes it and hands back the reply.
with Interfaces;
with Adaflight.Bytes;

package Adaflight.MSP_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use Adaflight.Bytes;

   subtype Unsigned_16 is Interfaces.Unsigned_16;

   Protocol_Version         : constant := 2;
   Request_Buffer_Size      : constant := 192;
   Response_Buffer_Size     : constant := 512;
   Skips_After_EEPROM_Write : constant := 5;
   EEPROM_Write_Command     : constant := 250;
   Min_Chunk                : constant := 6;
   Max_Chunk                : constant := 255;

   --  The error codes a failed request answers with, and the processor's
   --  verdicts as the reference numbers them.
   Error_Version_Mismatch : constant := 0;
   Error_Processor        : constant := 2;
   Error_Request_Too_Big  : constant := 3;
   Result_Error_Response  : constant := -10;
   Result_Error           : constant := -1;

   subtype Request_Index is Natural range 0 .. Request_Buffer_Size - 1;
   subtype Request_Size is Natural range 0 .. Request_Buffer_Size;
   subtype Response_Index is Natural range 0 .. Response_Buffer_Size - 1;
   subtype Response_Size is Natural range 0 .. Response_Buffer_Size;
   subtype Chunk_Size is Natural range Min_Chunk .. Max_Chunk;
   subtype Chunk_Index is Natural range 0 .. Max_Chunk - 1;
   subtype Chunk_Buffer is Byte_Array (Chunk_Index);
   subtype Version is Natural range 0 .. 3;
   subtype Sequence is Natural range 0 .. 15;
   subtype Result_Code is Integer range -32_768 .. 32_767;

   --  The request being assembled and the reply being sent, with the version
   --  of the last request, the chunk sequence numbers each way, and whether
   --  the reply's header chunk has gone out.
   type Tunnel is record
      Request_Buffer   : Byte_Array (Request_Index) := (others => 0);
      Request_Expected : Request_Size := 0;
      Request_Filled   : Request_Size := 0;
      Request_Command  : Unsigned_16 := 0;
      Request_Flags    : Byte := 0;
      Started          : Boolean := False;
      Last_Seq         : Sequence := 0;
      Last_Version     : Version := 0;
      Response_Buffer  : Byte_Array (Response_Index) := (others => 0);
      Response_Length  : Response_Size := 0;
      Response_Read    : Response_Size := 0;
      Response_Command : Unsigned_16 := 0;
      Response_Result  : Result_Code := 0;
      Header_Sent      : Boolean := False;
      Seq              : Sequence := 0;
   end record
     with Dynamic_Predicate => Request_Filled <= Request_Expected and then Response_Read <= Response_Length;

   --  What a chunk did: nothing, completed a request for the processor, or
   --  prepared an error reply by itself.
   type Outcome is (Ignored, Request_Ready, Error_Reply_Ready);

   --  One chunk of a request. EEPROM_Write reports a completed write command,
   --  after which the owner skips a few telemetry requests before replying.
   procedure Handle_Frame (T : in out Tunnel; Payload : Byte_Array; Result : out Outcome; EEPROM_Write : out Boolean)
     with Pre => Payload'Length <= 255;

   --  The processor's reply to the request ready: its verdict and its payload,
   --  with an error byte appended when the verdict is an error.
   procedure Prepare_Reply (T : in out Tunnel; Result : Result_Code; Payload : Byte_Array)
     with Pre => Payload'Length < Response_Buffer_Size;

   --  The next chunk of the reply, Chunk_Max bytes while more follow and the
   --  remainder in the last; the header chunk first after a reply is prepared.
   procedure Send_Reply (T : in out Tunnel; Chunk_Max : Chunk_Size; Chunk : out Chunk_Buffer; Length : out Natural;
                         More : out Boolean)
     with Post => Length <= Chunk_Max;

   --  The request ready, and the reply prepared.
   function Request_Data (T : Tunnel) return Byte_Array is (T.Request_Buffer (0 .. T.Request_Expected - 1));
   function Response_Data (T : Tunnel) return Byte_Array is (T.Response_Buffer (0 .. T.Response_Length - 1));

end Adaflight.MSP_Telemetry;
