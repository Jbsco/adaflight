--  The ExpressLRS telemetry link: the sender that carries a telemetry frame
--  to the transmitter five bytes per telemetry slot and confirms each chunk
--  through the bit the transmitter sends back, with a resync when the bit
--  stays wrong for too long, the receiver that assembles an MSP frame from
--  the transmitter's chunks the same way, and the schedule of the payloads
--  the sender offers.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.ExpressLRS_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Bytes_Per_Call     : constant := 5;
   Frame_Max          : constant := 64;
   Max_Packages       : constant := 63;
   Max_Missed_Packets : constant := 20;
   MSP_Buffer_Size    : constant := 65;
   MSP_Max_Packages   : constant := MSP_Buffer_Size / Bytes_Per_Call + 1;

   subtype Frame_Length is Natural range 0 .. Frame_Max;
   subtype Frame_Data is Byte_Array (0 .. Frame_Max - 1);
   subtype Chunk_Length is Natural range 0 .. Bytes_Per_Call;
   subtype Chunk is Byte_Array (0 .. Bytes_Per_Call - 1);

   type Sender_State is (Idle, Send_Pending, Sending, Wait_Until_Next_Confirm, Resync, Resync_Then_Send);

   --  The frame under way, the chunk position, the size of the last chunk
   --  handed out, the package number, the confirm bit awaited, and the count
   --  of wrong bits against its limit.
   type Sender is record
      Data               : Frame_Data := (others => 0);
      Length             : Frame_Length := 0;
      Offset             : Frame_Length := 0;
      Bytes_Last_Payload : Chunk_Length := 0;
      Current_Package    : Byte := 1;
      Wait_Until_Confirm : Boolean := True;
      Wait_Count         : Unsigned_16 := 0;
      Max_Wait_Count     : Unsigned_16 := 80;
      State              : Sender_State := Idle;
   end record
     with Dynamic_Predicate => Sender.Offset <= Sender.Length;

   --  The limit of eighty wrong bits is the transmitter's boost rate.
   procedure Reset_Sender (S : out Sender);

   --  A frame to send: an idle sender starts it, a busy one resyncs first.
   procedure Set_Data (S : in out Sender; Data : Byte_Array)
     with Pre => Data'Length <= Frame_Max;

   function Is_Active (S : Sender) return Boolean is (S.State /= Idle);

   --  The chunk for a telemetry slot, up to Max_Len bytes, with its package
   --  number: the resync marker while resyncing, zero for the last chunk of
   --  a frame with more than one, and zero again when nothing is sent.
   procedure Current_Payload (S : in out Sender; Out_Data : out Chunk; Max_Len : Chunk_Length;
                              Package_Index : out Byte);

   --  The confirm bit from the transmitter: the awaited value advances the
   --  frame, the other value counts toward the resync.
   procedure Confirm (S : in out Sender; Value : Boolean);

   --  The wrong bit limit from the telemetry ratio and burst: the packets
   --  between telemetry slots, times the missed packets allowed.
   procedure Update_Rate (S : in out Sender; Ratio : Natural; Burst : Positive)
     with Pre => Ratio <= 255 and then Burst <= 255;

   --  The MSP frame under assembly, its chunk position and package number,
   --  the confirm bit sent back, and whether the frame is complete.
   subtype MSP_Length is Natural range 0 .. MSP_Buffer_Size;
   subtype MSP_Buffer is Byte_Array (0 .. MSP_Buffer_Size - 1);

   type Receiver is record
      Data            : MSP_Buffer := (others => 0);
      Length          : MSP_Length := 0;
      Offset          : MSP_Length := 0;
      Current_Package : Byte := 1;
      Confirm         : Boolean := False;
      Finished        : Boolean := False;
   end record
     with Dynamic_Predicate => Receiver.Offset <= Receiver.Length;

   procedure Reset_Receiver (R : in out Receiver);

   --  The room for the next frame, and a fresh start on it.
   procedure Set_Receive_Length (R : in out Receiver; Max_Length : MSP_Length);

   --  A chunk with its package number: the resync marker restarts the frame
   --  and toggles the bit, a package after the last is ignored, the expected
   --  package or a final package (zero after the first) is taken, and a first
   --  package in mid frame restarts it without a resync.
   procedure Receive (R : in out Receiver; Package_Index : Byte; Payload : Chunk);

   function Has_Finished (R : Receiver) return Boolean is (R.Finished);

   --  A complete frame taken by the caller frees the receiver for the next.
   procedure Unlock (R : in out Receiver);

   --  The payloads offered in turn, each when its sensors are on.
   type Payload_Type is (GPS, Battery, Attitude, Flight_Mode);
   type Payload_Set is array (Payload_Type) of Boolean;

   --  What the telemetry's start reads: the telemetry and GPS features, an
   --  accelerometer, the battery's voltage and current meters, and the
   --  sensors the telemetry configuration leaves out.
   type Start_Inputs is record
      Telemetry_Feature   : Boolean := False;
      GPS_Feature         : Boolean := False;
      Accelerometer       : Boolean := False;
      Voltage_Configured  : Boolean := False;
      Amperage_Configured : Boolean := False;
      Disabled_Sensors    : Interfaces.Unsigned_32 := 0;
   end record;

   --  The payloads the start allowed, the next one in turn, and the device
   --  information and MSP replies waiting to go first.
   type Payload_Schedule is record
      Sensors             : Payload_Set := (others => False);
      Index               : Payload_Type := GPS;
      Device_Info_Pending : Boolean := False;
      MSP_Reply_Pending   : Boolean := False;
   end record;

   --  The start with the telemetry feature on: the payloads the sensors allow
   --  join the set, and the MSP receiver and the waiting replies start
   --  afresh. With the feature off nothing changes.
   procedure Start (P : in out Payload_Schedule; R : in out Receiver; Inp : Start_Inputs);

   type Next_Payload is (None, Device_Info, MSP_Reply, GPS_Frame, Battery_Frame, Attitude_Frame, Flight_Mode_Frame);

   --  The next payload: a waiting device information reply, else a waiting
   --  MSP reply, else the payload in turn when its sensors are on, the turn
   --  moving on whether or not they are.
   procedure Next (P : in out Payload_Schedule; Kind : out Next_Payload);

   --  An MSP frame from the transmitter by its frame type: a device ping, an
   --  MSP request or write, or anything else.
   type MSP_Kind is (Other, Ping, MSP_Frame);
   function Kind_Of (Frame : MSP_Buffer) return MSP_Kind is
     (case Frame (2) is
         when 16#28# => Ping,
         when 16#7A# | 16#7C# => MSP_Frame,
         when others => Other);

   --  A ping asks for the device information; an MSP frame the MSP handler
   --  buffered asks for a reply.
   procedure Process_MSP (P : in out Payload_Schedule; Kind : MSP_Kind; Buffered : Boolean);

end Adaflight.ExpressLRS_Telemetry;
