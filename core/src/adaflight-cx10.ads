--  The CX10 and CX10A receivers on the NRF24L01 with XN297 payloads. The
--  receiver listens on bind channel 2 for a packet with a good check and
--  the bind mark, whose transmitter id picks four hop channels. It then
--  answers nine times, each time on the bind channel and on every hop
--  channel, waiting for each answer to leave the transmit FIFO and for at
--  least 1 ms in all. A data packet gives the four sticks, the rate and
--  four switches on nine channels. The receiver hops after each data packet
--  and after 1.5 ms (CX10) or 6.5 ms (CX10A) without one; the timeout
--  compares plain 32-bit sums (F136).
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SPI_Radio;
with Adaflight.NRF24L01;

package Adaflight.CX10 with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   CRC_Length       : constant := 2;
   RC_Channel_Count : constant := 9;
   Buffer_Size      : constant := 32;

   type Variant is (CX10, CX10A);
   type Protocol_State is (Bind, Ack, Data);
   type Result is (None, Bind_Received, Data_Received_Result);

   function Payload_Size (Kind : Variant) return Natural is
     (case Kind is when CX10 => 15, when CX10A => 19);

   function Hop_Timeout_Us (Kind : Variant) return Unsigned_32 is
     (case Kind is when CX10 => 1_500, when CX10A => 6_500);

   type Transmitter_Id is array (0 .. 3) of Unsigned_8;
   type Hop_Table is array (0 .. 3) of Unsigned_8;
   subtype Payload_Buffer is Byte_Array (0 .. Buffer_Size - 1);

   --  The channels in the receiver's order: roll, pitch, throttle, yaw, then
   --  rate, flip, picture, video and headless.
   subtype RC_Index is Natural range 0 .. RC_Channel_Count - 1;
   type RC_Channels is array (RC_Index) of Unsigned_16;

   type State is record
      Kind             : Variant := CX10;
      Phase            : Protocol_State := Bind;
      Tx_Id            : Transmitter_Id := (others => 0);
      Channel_Index    : Unsigned_8 := 0;
      Channels         : Hop_Table := (others => 0);
      Time_Of_Last_Hop : Unsigned_32 := 0;
      Ack_Count        : Unsigned_8 := 0;
      Radio            : Adaflight.NRF24L01.Driver;
   end record;

   procedure Init (S : out State; Kind : Variant; Now_Us : Unsigned_32; O : out Adaflight.SPI_Radio.Output)
     with Global => null;

   --  One call with the FIFO status. When the FIFO holds a packet, the target
   --  reads it with its check into the receiver's buffer, which the call
   --  unscrambles in place. An answer sends the buffer's bytes with the
   --  answer mark in byte 9.
   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : in out Payload_Buffer; O : out Adaflight.SPI_Radio.Output; R : out Result)
     with Global => null;

   procedure Set_RC_Data (S : State; Buffer : Payload_Buffer; RC : in out RC_Channels)
     with Global => null;

end Adaflight.CX10;
