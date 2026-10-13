--  FlySky receivers on an A7105 radio: AFHDS with eight channels and AFHDS 2A
--  with fourteen. Start-up resets the radio, writes its id and register set,
--  calibrates it and listens on the bind channel, or when bound on the
--  stored map. Unbound, the receiver takes the transmitter id from bind
--  packets, with the channel map from an AFHDS 2A bind packet or computed
--  from the id for AFHDS, answers each AFHDS 2A bind packet, and stores the
--  binding 200 ms after the last one. Bound, it hops over the 16-channel map
--  on each packet and on timeouts, keeps a 16-sample RSSI average and the
--  packet error rate, and answers an AFHDS 2A channel packet with telemetry
--  every 57 ms. The radio and the pins stay with the target, which carries
--  out the operations in order and shows the interrupt flag and its time, the
--  mode and RSSI registers and the receive FIFO.
with Interfaces;
with Adaflight.SPI_Radio;

package Adaflight.FlySky with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Variant is (AFHDS, AFHDS_2A);
   type Channel_Map is array (0 .. 15) of Unsigned_8;

   --  The protocol, the stored binding, the receiver's id from the chip's
   --  unique id, and the pins the board has.
   type Settings is record
      Protocol    : Variant := AFHDS_2A;
      Tx_Id       : Unsigned_32 := 0;
      Rf_Map      : Channel_Map := (others => 0);
      Receiver_Id : Unsigned_32 := 0;
      Pins        : Adaflight.SPI_Radio.Pins;
   end record;

   Packet_Size : constant := 37;
   type Packet_Bytes is array (0 .. Packet_Size - 1) of Unsigned_8;

   Fifo_Size : constant := 64;
   type Fifo_Bytes is array (0 .. Fifo_Size - 1) of Unsigned_8;

   type RSSI_Samples is array (0 .. 15) of Unsigned_8;
   type Payload_Bytes is array (0 .. 27) of Unsigned_8;
   subtype Telemetry_Size is Natural range 21 .. 37;

   --  The timers and counters, the transmitter id, the bind and telemetry
   --  flags, the error rate, the RSSI average, the channel map and the hop
   --  position, the radio's interrupt use, the pins and the channel bytes.
   type State is record
      Timeout_Us      : Unsigned_32 := 0;
      Last_Packet_Us  : Unsigned_32 := 0;
      Last_Bind_Us    : Unsigned_32 := 0;
      Tx_Request_Us   : Unsigned_32 := 0;
      Count_Timeout   : Unsigned_32 := 0;
      Count_Packet    : Unsigned_32 := 0;
      Tx_Id           : Unsigned_32 := 0;
      Bound           : Boolean := False;
      Send_Telemetry  : Boolean := False;
      Wait_Tx         : Boolean := False;
      Error_Rate      : Unsigned_16 := 0;
      RSSI_Dbm        : Unsigned_16 := 0;
      Rf_Map          : Channel_Map := (others => 0);
      Hop             : Natural range 0 .. 15 := 0;
      Error_Rate_Us   : Unsigned_32 := 0;
      Telemetry_Us    : Unsigned_32 := 0;
      Samples         : RSSI_Samples := (others => 0);
      Sample_Index    : Natural range 0 .. 15 := 0;
      Telemetry_Bytes : Telemetry_Size := 37;
      Consume_Exti    : Boolean := True;
      Radio           : Adaflight.SPI_Radio.Radio;
      Payload         : Payload_Bytes := (others => 0);
   end record;

   subtype Output is Adaflight.SPI_Radio.Output;

   --  What a call reads: the clocks, the radio's interrupt flag and the time
   --  it was raised, the mode and RSSI registers, the receive FIFO, the bind
   --  pin and the battery voltage.
   type Inputs is record
      Now_Us          : Unsigned_32 := 0;
      Now_Ms          : Unsigned_32 := 0;
      Exti_Flag       : Boolean := False;
      Exti_Time_Us    : Unsigned_32 := 0;
      Mode_Register   : Unsigned_8 := 0;
      RSSI_Register   : Unsigned_8 := 0;
      Fifo            : Fifo_Bytes := (others => 0);
      Bind_Pin_Level  : Boolean := True;
      Battery_Voltage : Unsigned_16 := 0;
   end record;

   type Received is (None, Bind_Done, Data_Ready);

   --  Start-up: the pins, the radio's reset, id, registers and calibration,
   --  and the first channel. The RSSI source passes to the protocol when
   --  none is set.
   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean);

   --  A bind request from outside, as the bind command makes it.
   procedure Request_Bind (S : in out State);

   --  One protocol call: a finished transmission or reception, the delayed
   --  reply, a bind request, then the hop timeouts or the end of binding.
   procedure Data_Received
     (S : in out State; C : in out Settings; Inp : Inputs; O : out Output; Result : out Received);

   Max_Channels : constant := 14;
   type Channel_Values is array (0 .. Max_Channels - 1) of Unsigned_16;

   function Channel_Count (C : Settings) return Natural is (if C.Protocol = AFHDS_2A then 14 else 8);

   --  The channels of the last channel packet, two bytes each.
   procedure Set_Rc_Data (S : State; C : Settings; Rc : in out Channel_Values);

end Adaflight.FlySky;
