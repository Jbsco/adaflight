--  The SUMD receiver protocol: the frame assembled from the serial bytes
--  after the sync byte, its channel count from the header and its CRC over
--  the header and the channels, the frame complete two bytes after the
--  channels, the status from the frame state byte once the CRC matches, and
--  the raw channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.SUMD with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Max_Channels : constant := 32;
   subtype Channel is Natural range 0 .. Receiver.Channel_Count - 1;
   type Channel_Data is array (Channel) of Natural range 0 .. 65_535;

   Buffer_Size : constant := Max_Channels * 2 + 5;
   subtype Buffer_Index is Natural range 0 .. Buffer_Size - 1;
   type Buffer is array (Buffer_Index) of Byte;

   Sync_Byte          : constant := 16#A8#;
   Time_Per_Frame_Us  : constant := 4_000;
   State_V1_OK        : constant := 16#01#;
   State_V3_OK        : constant := 16#03#;
   State_Failsafe     : constant := 16#81#;

   type State is record
      Done          : Boolean := False;
      Data          : Channel_Data := (others => 0);
      CRC           : Unsigned_16 := 0;
      Bytes         : Buffer := (others => 0);
      Channel_Count : Byte := 0;
      Last_Frame_Us : Time_Us := 0;
      Time_Last_Us  : Time_Us := 0;
      Index         : Byte := 0;
   end record;

   procedure Init (S : out State);

   --  One byte at its arrival time: a gap over the frame time restarts the
   --  frame, the sync byte starts it, the third byte gives the channel
   --  count, the CRC runs over the header and the channels, and the frame
   --  completes two bytes after them.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The status of a complete frame: nothing unless the CRC matches, then
   --  failsafe or complete by the state byte, with the channels taken; a
   --  frame that declares more channels than the buffer holds is dropped
   --  where the reference reads past its buffer (findings F32). The caller
   --  takes Last_Frame_Us as the receiver's frame time for a frame that is
   --  not failsafe.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report);

   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch)) / 8.0);

end Adaflight.SUMD;
