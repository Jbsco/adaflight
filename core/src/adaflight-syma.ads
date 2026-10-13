--  The SYMA X and X5C receivers on the NRF24L01. The X binds to a packet that
--  carries its transmitter's address and three bind marks, takes that
--  address and derives four hop channels from it; the X5C starts bound on a
--  fixed address and fifteen channels. Data packets give the throttle, the
--  three sticks in sign and magnitude, a rate and four switches. The
--  receiver hops every second packet and after 10 ms without one; the
--  timeout compares plain 32-bit sums (F136). The payload buffer is the
--  receiver's and keeps the bytes a shorter packet does not write (F137).
with Interfaces;
with Adaflight.SPI_Radio;
with Adaflight.NRF24L01;

package Adaflight.SYMA with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Variant is (X, X5C);
   type Protocol_State is (Bind, Data);
   type Result is (None, Bind_Received, Data_Received_Result);

   Max_Hops         : constant := 16;
   RC_Channel_Count : constant := 9;
   Buffer_Size      : constant := 16;

   subtype Hop_Index is Natural range 0 .. Max_Hops - 1;
   type Hop_Table is array (Hop_Index) of Unsigned_8;
   type Address is array (0 .. 4) of Unsigned_8;
   type Payload_Buffer is array (0 .. Buffer_Size - 1) of Unsigned_8;

   --  The channels in the receiver's order: roll, pitch, throttle, yaw, rate,
   --  flip, picture, video and headless.
   subtype RC_Index is Natural range 0 .. RC_Channel_Count - 1;
   type RC_Channels is array (RC_Index) of Unsigned_16;

   type State is record
      Kind             : Variant := X;
      Phase            : Protocol_State := Bind;
      Payload_Size     : Unsigned_8 := 10;
      Rx_Tx_Address    : Address := (16#AB#, 16#AC#, 16#AD#, 16#AE#, 16#AF#);
      Channel_Count    : Natural range 1 .. Max_Hops := 4;
      Channel_Index    : Hop_Index := 0;
      Channels         : Hop_Table := (16#4B#, 16#30#, 16#40#, 16#20#, others => 0);
      Packet_Count     : Unsigned_32 := 0;
      Time_Of_Last_Hop : Unsigned_32 := 0;
      Radio            : Adaflight.NRF24L01.Driver;
   end record;

   procedure Init (S : out State; Kind : Variant; Now_Us : Unsigned_32; O : out Adaflight.SPI_Radio.Output)
     with Global => null;

   --  One call with the FIFO status. When the FIFO holds a packet, the
   --  target reads its first Payload_Size bytes into the buffer, which the
   --  caller passes back with them.
   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : Payload_Buffer; O : out Adaflight.SPI_Radio.Output; R : out Result)
     with Global => null;

   procedure Set_RC_Data (S : State; Buffer : Payload_Buffer; RC : in out RC_Channels)
     with Global => null;

end Adaflight.SYMA;
