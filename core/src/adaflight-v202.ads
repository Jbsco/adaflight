--  The V202 receiver on the NRF24L01: 16-byte packets with a two-byte CRC
--  on a fixed address. Unbound, the receiver hops the first row of the
--  frequency table every millisecond and binds to the first packet with
--  both bind flags, taking the transmitter id that picks a table row and an
--  offset for its sixteen channels. Bound, a packet with that id gives the
--  throttle, the three sticks in sign and magnitude, and seven switches;
--  the receiver hops after each packet or after 10 ms without one.
with Interfaces;
with Adaflight.SPI_Radio;
with Adaflight.NRF24L01;

package Adaflight.V202 with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Payload_Size     : constant := 16;
   Hop_Count        : constant := 16;
   RC_Channel_Count : constant := 11;

   type Data_Rate is (Rate_250K, Rate_1M);
   type Bind_Phase is (Not_Bound, Bound);
   type Result is (None, Bind, Data);

   subtype Hop_Index is Natural range 0 .. Hop_Count - 1;
   type Hop_Table is array (Hop_Index) of Unsigned_8;
   type Transmitter_Id is array (0 .. 2) of Unsigned_8;
   type Packet is array (0 .. Payload_Size - 1) of Unsigned_8;

   --  The channels in the receiver's order: roll, pitch, throttle, yaw, then
   --  the seven auxiliaries.
   subtype RC_Index is Natural range 0 .. RC_Channel_Count - 1;
   type RC_Channels is array (RC_Index) of Unsigned_16;

   type State is record
      Channels        : Hop_Table := (others => 0);
      Channel_Index   : Hop_Index := 0;
      Phase           : Bind_Phase := Not_Bound;
      Packet_Timer_Us : Unsigned_32 := 0;
      Tx_Id           : Transmitter_Id := (others => 0);
      Rx_Timeout_Us   : Unsigned_32 := 0;
      Radio           : Adaflight.NRF24L01.Driver;
   end record;

   procedure Init (S : out State; Rate : Data_Rate; Now_Us : Unsigned_32; O : out Adaflight.SPI_Radio.Output)
     with Global => null;

   --  One call with the status register and, when the status shows data
   --  ready, the payload the target reads.
   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Status_Value : Unsigned_8; Payload : Packet;
                            RC : in out RC_Channels; O : out Adaflight.SPI_Radio.Output; R : out Result)
     with Global => null;

end Adaflight.V202;
