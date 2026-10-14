--  The acknowledgment payload receiver on the NRF24L01: the radio answers
--  each packet with the payload the receiver last left for it. Unbound, the
--  receiver listens on channel 76 at a fixed address for a bind packet,
--  answers with the bind reply, takes the transmitter's address from the
--  packet with four hop channels from its first byte, and goes to data. A
--  data packet gives four sticks and four auxiliary channels at ten bits,
--  the rate, five switches and two eight-bit channels on eighteen channels,
--  the last two always zero. A bind packet while bound gets the bind reply
--  again. The receiver hops after each data packet and after 5 ms without
--  one; the timeout compares plain 32-bit sums (F136). Every start binds
--  anew, and a bind never stores the address (F147).
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SPI_Radio;
with Adaflight.NRF24L01;

package Adaflight.Ack_Payload_Receiver with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Payload_Size     : constant := 16;
   RC_Channel_Count : constant := 18;
   Buffer_Size      : constant := 32;

   type Protocol_State is (Bind, Data);
   type Result is (None, Bind_Received, Data_Received_Result);

   type Address is array (0 .. 4) of Unsigned_8;
   type Hop_Table is array (0 .. 7) of Unsigned_8;
   subtype Hop_Count is Natural range 1 .. 8;
   subtype Payload_Buffer is Byte_Array (0 .. Buffer_Size - 1);

   --  The channels in the receiver's order: roll, pitch, throttle, yaw, then
   --  rate, flip, picture, video, headless, return home, four ten-bit and
   --  four eight-bit auxiliary channels.
   subtype RC_Index is Natural range 0 .. RC_Channel_Count - 1;
   type RC_Channels is array (RC_Index) of Unsigned_16;

   type State is record
      Phase            : Protocol_State := Bind;
      Rx_Tx_Address    : Address := (16#4B#, 16#5C#, 16#6D#, 16#7E#, 16#8F#);
      Channel_Count    : Hop_Count := 1;
      Channel_Index    : Unsigned_8 := 0;
      Channels         : Hop_Table := (others => 0);
      Time_Of_Last_Hop : Unsigned_32 := 0;
      Radio            : Adaflight.NRF24L01.Driver;
   end record;

   procedure Init (S : out State; Now_Us : Unsigned_32; O : out Adaflight.SPI_Radio.Output)
     with Global => null;

   --  One call with the FIFO status. When the FIFO holds a packet, the target
   --  reads its 16 bytes into the receiver's buffer. A bind reply rewrites
   --  four of them before the radio sends them back.
   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : in out Payload_Buffer; O : out Adaflight.SPI_Radio.Output; R : out Result)
     with Global => null;

   procedure Set_RC_Data (Buffer : Payload_Buffer; RC : out RC_Channels)
     with Global => null;

end Adaflight.Ack_Payload_Receiver;
