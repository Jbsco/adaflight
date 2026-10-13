--  The H8_3D receiver on the NRF24L01 with XN297 payloads. Unbound, it hops
--  the bind channels 6 to 38 every millisecond and binds to a packet whose
--  checksum covers its transmitter id; the id picks four hop channels and,
--  when the receiver holds none, becomes its stored id. A stored id at
--  start binds at once. A data packet with a good check gives the sticks,
--  throttle, rate, six switches, the camera tilt and three trims on
--  fourteen channels. The receiver hops after each data packet and after
--  5 ms without one; the timeout compares plain 32-bit sums (F136).
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SPI_Radio;
with Adaflight.NRF24L01;

package Adaflight.H8_3D with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Payload_Size     : constant := 20;
   CRC_Length       : constant := 2;
   RC_Channel_Count : constant := 14;
   Buffer_Size      : constant := 32;

   type Protocol_State is (Bind, Data);
   type Result is (None, Bind_Received, Data_Received_Result);

   type Transmitter_Id is array (0 .. 3) of Unsigned_8;
   type Hop_Table is array (0 .. 3) of Unsigned_8;
   subtype Payload_Buffer is Byte_Array (0 .. Buffer_Size - 1);

   --  The channels in the receiver's order: roll, pitch, throttle, yaw, then
   --  rate, flip, picture, video, headless, return home, camera tilt and three
   --  trims.
   subtype RC_Index is Natural range 0 .. RC_Channel_Count - 1;
   type RC_Channels is array (RC_Index) of Unsigned_16;

   type State is record
      Phase            : Protocol_State := Bind;
      Tx_Id            : Transmitter_Id := (others => 0);
      Channel_Index    : Unsigned_8 := 0;
      Channels         : Hop_Table := (others => 0);
      Hop_Timeout_Us   : Unsigned_32 := 1_000;
      Time_Of_Last_Hop : Unsigned_32 := 0;
      Stored_Id        : Unsigned_32 := 0;
      Radio            : Adaflight.NRF24L01.Driver;
   end record;

   --  Stored_Id is the receiver's id setting; a bind fills it once.
   procedure Init (S : out State; Stored_Id : Unsigned_32; Now_Us : Unsigned_32;
                   O : out Adaflight.SPI_Radio.Output)
     with Global => null;

   --  One call with the FIFO status. When the FIFO holds a packet, the target
   --  reads its 22 bytes into the receiver's buffer, which the call
   --  unscrambles in place.
   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : in out Payload_Buffer; O : out Adaflight.SPI_Radio.Output; R : out Result)
     with Global => null;

   procedure Set_RC_Data (Buffer : Payload_Buffer; RC : in out RC_Channels)
     with Global => null;

end Adaflight.H8_3D;
