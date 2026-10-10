--  The XBUS receiver protocol: the Mode B frame of twelve or sixteen channel
--  words assembled from the serial bytes with a new frame after a gap, the
--  RJ01 outer frame around a Mode B frame with its own length byte and CRC,
--  the channels unpacked as the frame completes once its CRC matches, and
--  the raw channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.XBUS with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Channel_Count : constant := 12;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Channel_Value is Natural range 0 .. 65_535;
   type Channel_Data is array (Channel) of Channel_Value;

   Frame_Size_A1       : constant := 27;
   Frame_Size_A2       : constant := 35;
   RJ01_Frame_Size     : constant := 33;
   RJ01_Message_Length : constant := 30;
   RJ01_Offset_Bytes   : constant := 3;
   Max_Frame_Time_Us   : constant := 8_000;
   Start_Of_Frame_A1   : constant := 16#A1#;
   Start_Of_Frame_A2   : constant := 16#A2#;

   subtype Frame_Index is Natural range 0 .. Frame_Size_A2 - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;
   subtype Frame_Length is Natural range Frame_Size_A1 .. Frame_Size_A2
     with Static_Predicate => Frame_Length in Frame_Size_A1 | RJ01_Frame_Size | Frame_Size_A2;

   type Provider is (Mode_B, Mode_B_RJ01);

   --  The frame assembly and the decoded channels. The position stays below
   --  the frame's length while a frame comes in and at zero otherwise, and
   --  the length is one of the provider's.
   type State is record
      Kind           : Provider := Mode_B;
      Frame_Received : Boolean := False;
      Data_Incoming  : Boolean := False;
      Position       : Natural range 0 .. Frame_Size_A2 - 1 := 0;
      Length         : Frame_Length := Frame_Size_A1;
      Frame          : Frame_Bytes := (others => 0);
      Data           : Channel_Data := (others => 0);
      Time_Last_Us   : Time_Us := 0;
   end record
     with Dynamic_Predicate =>
       (if State.Data_Incoming then State.Position < State.Length else State.Position = 0)
       and then (case State.Kind is
                   when Mode_B      => State.Length in Frame_Size_A1 | Frame_Size_A2,
                   when Mode_B_RJ01 => State.Length = RJ01_Frame_Size);

   procedure Init (S : out State; Kind : Provider);

   --  One byte from the serial port at its arrival time: a gap over eight
   --  milliseconds drops the frame in progress, a frame starts on the
   --  twelve-channel start byte, or on the sixteen-channel one in Mode B,
   --  and the last byte of the frame's length unpacks it: a Mode B frame on
   --  its own and then, as for the RJ01 provider, as an outer frame when its
   --  length byte and CRC check, with the Mode B frame inside it.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  Complete once per unpacked frame.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report);

   --  The channel value in microseconds.
   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch)));

end Adaflight.XBUS;
