--  Spektrum DSM2 and DSMX receiver on a CYRF6936 radio. Start-up wakes and
--  resets the radio, checks it answers, and configures it. Unbound, the
--  receiver searches for bind packets, stepping over channels every 11 ms,
--  takes the manufacturer id, channel count and protocol from a packet whose
--  two checksums agree, saves them, and answers with 500 bind packets.
--  Bound, it derives its codes and CRC seed from the id, and for DSMX the 23
--  hop channels; a DSM2 receiver first finds its two channels. It then hops
--  on each packet and on timeouts, takes the RSSI from the radio, decodes
--  seven channel words a packet, sends telemetry every 176 ms when the
--  feature is on, and searches again after 31 misses. The radio and the pins
--  stay with the target, which carries out the operations in order and shows
--  the interrupt flag and its time, the receive registers and the buffer.
with Interfaces;
with Adaflight.SPI_Radio;

package Adaflight.Spektrum_SPI with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Manufacturer_Id is array (0 .. 3) of Unsigned_8;

   --  The stored binding (protocol, manufacturer id, channel count), the
   --  telemetry feature, and the pins the board has.
   type Settings is record
      Protocol     : Unsigned_8 := 0;
      Mfg_Id       : Manufacturer_Id := (others => 0);
      Num_Channels : Unsigned_8 := 0;
      Telemetry    : Boolean := False;
      Pins         : Adaflight.SPI_Radio.Pins;
   end record;

   type Receiver_Status is (Bind, Bind_2, Sync_A, Sync_B, Receive, Telemetry);

   type Channel_List is array (0 .. 22) of Unsigned_8;

   Packet_Size : constant := 16;
   type Packet_Bytes is array (0 .. Packet_Size - 1) of Unsigned_8;
   type Payload_Bytes is array (0 .. 13) of Unsigned_8;

   Fifo_Size : constant := 64;
   type Fifo_Bytes is array (0 .. Fifo_Size - 1) of Unsigned_8;

   --  The receiver's status, protocol and id, the channel and its index, the
   --  hop channels, the code columns and CRC seed, the misses, the channel
   --  count, the bind flag, the timers, the bind answers, the telemetry
   --  request, the last receive error, the pins and the channel bytes.
   type State is record
      Status            : Receiver_Status := Bind;
      Protocol          : Unsigned_8 := 0;
      Mfg_Id            : Manufacturer_Id := (others => 0);
      Rf_Channel        : Unsigned_8 := 0;
      Rf_Channel_Idx    : Natural range 0 .. 22 := 0;
      Rf_Channels       : Channel_List := (others => 0);
      Sop_Col           : Natural range 0 .. 7 := 0;
      Data_Col          : Natural range 0 .. 7 := 0;
      Crc_Seed          : Unsigned_16 := 0;
      Missed_Packets    : Unsigned_8 := 0;
      Num_Channels      : Unsigned_8 := 0;
      Bound             : Boolean := False;
      Timeout_Us        : Unsigned_32 := 0;
      Last_Packet_Us    : Unsigned_32 := 0;
      Bind_Packets      : Unsigned_16 := 0;
      Last_Telemetry_Us : Unsigned_32 := 0;
      Send_Telemetry    : Boolean := False;
      Is_Error          : Boolean := False;
      Radio             : Adaflight.SPI_Radio.Radio;
      Payload           : Payload_Bytes := (others => 0);
   end record;

   subtype Output is Adaflight.SPI_Radio.Output;

   --  What a call reads: the clocks, the interrupt flag and its time, the
   --  receive interrupt, count and status registers, the RSSI register, the
   --  receive buffer, the bind pin, the battery voltage and the RSSI
   --  percentage; at start-up, the chip check.
   type Inputs is record
      Now_Us          : Unsigned_32 := 0;
      Now_Ms          : Unsigned_32 := 0;
      Exti_Flag       : Boolean := False;
      Exti_Time_Us    : Unsigned_32 := 0;
      IRQ_Status      : Unsigned_8 := 0;
      Rx_Count        : Unsigned_8 := 0;
      Rx_Status       : Unsigned_8 := 0;
      RSSI_Register   : Unsigned_8 := 0;
      Fifo            : Fifo_Bytes := (others => 0);
      Bind_Pin_Level  : Boolean := True;
      Battery_Voltage : Unsigned_16 := 0;
      RSSI_Percent    : Unsigned_8 := 0;
      Chip_Ok         : Boolean := True;
   end record;

   type Received is (None, Bind_Done, Data_Ready);

   --  Start-up: the pins, the radio's wake-up, reset and check, its
   --  configuration, and binding or transfer by the stored id; false when the
   --  radio does not answer. The RSSI source passes to the protocol when none
   --  is set and the radio answered.
   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean);

   --  A bind request from outside, as the bind command makes it.
   procedure Request_Bind (S : in out State);

   --  One protocol call: a bind request, a finished reception, then the
   --  timeouts and the LED.
   procedure Data_Received
     (S : in out State; C : in out Settings; Inp : Inputs; O : out Output; Result : out Received);

   Channel_Count : constant := 12;
   type Channel_Values is array (0 .. 15) of Unsigned_16;

   --  The channels of the last packet: seven words, each naming its channel.
   procedure Set_Rc_Data (S : State; Rc : in out Channel_Values);

end Adaflight.Spektrum_SPI;
