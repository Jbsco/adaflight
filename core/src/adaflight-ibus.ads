--  The IBUS receiver protocol: the frames of the two receiver families
--  assembled from the serial bytes with a new frame after a gap, the IA6B
--  frame sized by its first byte with a subtractive checksum over it, the
--  IA6 frame of thirty-one bytes after its sync byte with an additive
--  checksum over its slots, the eighteen channels unpacked from the fourteen
--  slots and their spare high bits, the telemetry request a short IA6B frame
--  carries with the echo of its reply to skip, and the raw channel value the
--  receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.IBUS with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Channel_Count : constant := 18;
   Slot_Count    : constant := 14;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Slot is Channel range 0 .. Slot_Count - 1;
   subtype Channel_Value is Natural range 0 .. 4_095;
   type Channel_Data is array (Channel) of Channel_Value;

   Buffer_Size : constant := 32;
   subtype Buffer_Index is Natural range 0 .. Buffer_Size - 1;
   type Frame_Bytes is array (Buffer_Index) of Byte;

   Telemetry_Packet_Length : constant := 4;
   Channel_Packet_Length   : constant := 32;
   IA6_Sync_Byte           : constant := 16#55#;
   IA6_Frame_Size          : constant := 31;
   Frame_Gap_Us            : constant := 500;

   type Model is (IA6B, IA6);

   --  The frame assembly and the decoded channels. The frame's first byte is
   --  its sync byte; an IA6 frame is thirty-one bytes with its slots from the
   --  second, an IA6B frame is as long as its first byte says with its slots
   --  from the third, and a complete frame has one of the known lengths.
   type State is record
      Kind               : Model := IA6B;
      Sync_Byte          : Byte := 0;
      Frame_Size         : Byte := 0;
      Channel_Offset     : Byte := 0;
      Bytes_To_Ignore    : Byte := 0;
      Checksum           : Unsigned_16 := 0;
      Done               : Boolean := False;
      Data               : Channel_Data := (others => 0);
      Frame              : Frame_Bytes := (others => 0);
      Position           : Byte := 0;
      Time_Last_Us       : Time_Us := 0;
      Completed_At_Us    : Time_Us := 0;
      Last_Frame_Time_Us : Time_Us := 0;
   end record
     with Dynamic_Predicate =>
       State.Frame (0) = State.Sync_Byte
       and then (case State.Kind is
                   when IA6  => State.Sync_Byte = IA6_Sync_Byte and then State.Frame_Size = IA6_Frame_Size
                                and then State.Channel_Offset = 1,
                   when IA6B => State.Frame_Size = State.Sync_Byte
                                and then State.Frame_Size in 0 | Telemetry_Packet_Length | Channel_Packet_Length
                                and then State.Channel_Offset = (if State.Frame_Size = 0 then 0 else 2))
       and then (if State.Done then State.Frame_Size >= Telemetry_Packet_Length);

   procedure Init (S : out State);

   --  One byte from the serial port at its arrival time: a gap over the frame
   --  gap starts a new frame and ends any echo skip, a byte of an echo is
   --  skipped, a frame starts on an IA6B length byte, on the IA6 sync byte
   --  before any family is known, or on the known sync byte, and the last
   --  byte of the frame's length completes it.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The frame's status when one is complete and its checksum matches: the
   --  channels decoded from an IA6 frame or a full IA6B frame, or a telemetry
   --  request from a short IA6B frame for the telemetry layer to answer.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report; Telemetry_Request : out Boolean);

   --  The length of the reply the telemetry layer sent on the shared line,
   --  whose echo the next bytes are.
   procedure Ignore_Echo (S : in out State; Count : Byte);

   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch)));

end Adaflight.IBUS;
