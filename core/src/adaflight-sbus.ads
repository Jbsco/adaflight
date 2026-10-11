--  The SBUS receiver protocol: the 25-byte frame assembled from the serial
--  bytes, resynchronized on the begin byte after a gap, the sixteen
--  eleven-bit channels and the two digital channels unpacked from it, the
--  failsafe and signal loss flags as the frame's status, and the raw
--  channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.SBUS with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;
   subtype Center_Us is Natural range 1200 .. 1700;

   Channel_Count : constant := 18;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Channel_Value is Natural range 0 .. 2_047;
   subtype Packed_Channel is Channel range 0 .. 15;
   type Channel_Data is array (Channel) of Channel_Value;

   Frame_Size : constant := 25;
   subtype Frame_Index is Natural range 0 .. Frame_Size - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;

   --  The twenty-two channel bytes and the flags byte that the SBUS frame
   --  and the FPORT control frame both carry.
   Block_Size : constant := 23;
   subtype Block_Index is Natural range 0 .. Block_Size - 1;
   type Channel_Block is array (Block_Index) of Byte;

   Begin_Byte          : constant := 16#0F#;
   Digital_Channel_Min : constant := 173;
   Digital_Channel_Max : constant := 1_812;

   type Frame_State is record
      Bytes           : Frame_Bytes := (others => 0);
      Start_At_Us     : Time_Us := 0;
      Last_Byte_At_Us : Time_Us := 0;
      Position        : Natural range 0 .. Frame_Size := 0;
      Done            : Boolean := False;
   end record;

   type State is record
      Frame              : Frame_State;
      Data               : Channel_Data := (others => 0);
      Last_Frame_Time_Us : Time_Us := 0;
   end record;

   --  Every channel starts at the value that reads as the center.
   procedure Init (S : out State; Mid_RC : Center_Us);

   --  One byte from the serial port at its arrival time: a gap longer than
   --  five byte times starts a new frame, a frame starts only on the begin
   --  byte, and the twenty-fifth byte completes it.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The channel block decoded: the sixteen eleven-bit channels from the
   --  little-endian bit stream, the two digital channels from their flags,
   --  and the status complete, with failsafe when the receiver flags it and
   --  dropped when it flags a signal loss.
   procedure Decode (Block : Channel_Block; Data : in out Channel_Data; Status : out Receiver.Frame_Report);

   --  The frame's status when one is complete, with the channels decoded
   --  and the frame's start kept as the frame time unless the receiver
   --  flags failsafe or a signal loss.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report);

   --  A channel count in microseconds, as fitted to the X4R.
   function Raw_Us (V : Channel_Value) return Float is (5.0 * Float (V) / 8.0 + 880.0);

   function Read_Raw (S : State; Ch : Channel) return Float is (Raw_Us (S.Data (Ch)));

end Adaflight.SBUS;
