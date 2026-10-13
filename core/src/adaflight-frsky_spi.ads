--  FrSky SPI receiver on a CC2500 radio, D8 and the four D16 (X) variants.
--  Start-up resets, configures and calibrates the radio on every channel.
--  Binding tunes the frequency offset up and down on bind packets, then
--  collects the hop table and the transmitter id from them, or for the V2
--  variants takes the id from one packet and generates the table. Bound, the
--  receiver hops over the table, takes channel packets from its transmitter
--  with the RSSI from their status byte, and answers in the telemetry slot:
--  D8 with the FrSky hub stream's bytes ten at a time, X with the sequenced
--  telemetry transport. On timeouts it hops on, switches antennas and drops
--  the RSSI. The radio and the pins stay with the target,
--  which carries out the operations in order, hands back the calibration and
--  shows the receive FIFO.
with Interfaces;
with Adaflight.SPI_Radio;
with Adaflight.FrSky_Hub_Telemetry;

package Adaflight.FrSky_SPI with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   type Hop_Table is array (0 .. 49) of Unsigned_8;
   type Tx_Id is array (0 .. 2) of Unsigned_8;
   type A1_Source is (Battery_Voltage, External_ADC, Constant_Value);
   type SPI_Protocol is (FrSky_D, FrSky_X, FrSky_X_LBT, FrSky_X_V2, FrSky_X_LBT_V2);

   --  The receiver's settings, the bind results among them, and the pins the
   --  board has.
   type Settings is record
      Protocol      : SPI_Protocol := FrSky_D;
      Auto_Bind     : Boolean := False;
      Bind_Tx_Id    : Tx_Id := (others => 0);
      Bind_Offset   : Integer_8 := 0;
      Bind_Hop_Data : Hop_Table := (others => 0);
      Rx_Num        : Unsigned_8 := 0;
      A1            : A1_Source := Battery_Voltage;
      Pins          : Adaflight.SPI_Radio.Pins;
      Telemetry     : Boolean := False;
      Hub           : Adaflight.FrSky_Hub_Telemetry.Settings;
   end record;

   Calibrated_Channels : constant := 255;
   subtype Calibration is Adaflight.SPI_Radio.Calibration;
   type Calibration_Table is array (0 .. 255) of Calibration;

   Payload_Size : constant := 35;
   subtype Payload_Index is Natural range 0 .. Payload_Size - 1;
   type Payload_Bytes is array (Payload_Index) of Unsigned_8;

   Fifo_Size : constant := 64;
   type Fifo_Bytes is array (0 .. Fifo_Size - 1) of Unsigned_8;

   type Protocol_State is
     (Init, Bind, Bind_Tuning_Low, Bind_Tuning_High, Bind_Binding, Bind_Complete, Starting, Update, Data,
      Telemetry, Resume);

   type Frame_Bytes is array (0 .. 19) of Unsigned_8;

   subtype Sequence_Id is Natural range 0 .. 3;
   type Telemetry_Data is array (0 .. 5) of Unsigned_8;
   type Remote_Frame is record
      Data             : Telemetry_Data := (others => 0);
      Needs_Processing : Boolean := False;
   end record;
   type Remote_Frames is array (Sequence_Id) of Remote_Frame;
   type Local_Frames is array (Sequence_Id) of Telemetry_Data;

   Hub_Buffer_Size : constant := 64;
   type Hub_Bytes is array (0 .. Hub_Buffer_Size - 1) of Unsigned_8;

   --  The protocol state, the timers, the calibration, the bind tuning, the
   --  hop position, the RSSI, the antenna, the bind request and the frames.
   type State is record
      Protocol          : Protocol_State := Init;
      Start_Time_Ms     : Unsigned_32 := 0;
      Missing_Packets   : Unsigned_32 := 0;
      Timeout_Us        : Integer_32 range 1 .. 50 := 50;
      Cal               : Calibration_Table := (others => (others => 0));
      Time_Tuned_Ms     : Unsigned_32 := 0;
      List_Length       : Unsigned_8 := 0;
      Bind_State        : Unsigned_16 := 0;
      Bind_Offset       : Integer_8 := 0;
      Bind_Offset_Min   : Integer_8 := 0;
      Bind_Offset_Max   : Integer_8 := 0;
      Channel           : Unsigned_8 := 0;
      Radio             : Adaflight.SPI_Radio.Radio;
      Last_Packet_Us    : Unsigned_32 := 0;
      Telemetry_Us      : Unsigned_32 := 0;
      Data_Errors       : Unsigned_16 := 0;
      Frame             : Frame_Bytes := (others => 0);
      Payload           : Payload_Bytes := (others => 0);
      Packet_Length     : Natural range 20 .. 35 := 20;
      Telemetry_Delay   : Integer_32 range 0 .. 1_500 := 0;
      Retry_Count       : Natural range 0 .. 5 := 0;
      Skip_Channels     : Boolean := True;
      Remote_Ack_Id     : Sequence_Id := 0;
      Packet_Timer_Us   : Unsigned_32 := 0;
      Frame_Received    : Boolean := False;
      Receive_Delay_Us  : Integer_32 range 0 .. 5_300 := 0;
      Channels_To_Skip  : Unsigned_8 := 1;
      Packet_Errors     : Unsigned_32 := 0;
      Telemetry_Received : Boolean := False;
      Remote            : Remote_Frames;
      Response          : Unsigned_8 := 0;
      Sent              : Local_Frames := (others => (others => 0));
      Local_Packet_Id   : Sequence_Id := 0;
      Even_Run          : Boolean := False;
      Out_Data          : Hub_Bytes := (others => 0);
      Out_Writer        : Natural range 0 .. Hub_Buffer_Size - 1 := 0;
      Out_Reader        : Natural range 0 .. Hub_Buffer_Size - 1 := 0;
      Telemetry_Enabled : Boolean := False;
      Hub               : Adaflight.FrSky_Hub_Telemetry.Stream;
      Hub_Data          : Hub_Bytes := (others => 0);
      Hub_Generated     : Natural range 0 .. Hub_Buffer_Size := 0;
      Hub_Sent          : Natural range 0 .. Hub_Buffer_Size - 1 := 0;
      Hub_Acknowledged  : Natural range 0 .. Hub_Buffer_Size - 1 := 0;
      Hub_Id_Expected   : Unsigned_8 := 0;
   end record;

   subtype Output is Adaflight.SPI_Radio.Output;

   --  What a call reads: the clocks, the radio's interrupt line, the bytes in
   --  its receive FIFO, the bind pin, the telemetry's analog readings and the
   --  hub stream's readings; at start-up, the chip check and whether the hub
   --  stream is free for this receiver.
   type Inputs is record
      Now_Us          : Unsigned_32 := 0;
      Now_Ms          : Unsigned_32 := 0;
      Exti            : Boolean := False;
      Rx_Bytes        : Unsigned_8 := 0;
      Fifo            : Fifo_Bytes := (others => 0);
      Bind_Pin_Level  : Boolean := True;
      ADC_External    : Unsigned_16 := 0;
      ADC_RSSI        : Unsigned_16 := 0;
      Battery_Voltage : Unsigned_16 := 0;
      Legacy_Voltage  : Unsigned_16 := 0;
      Hub             : Adaflight.FrSky_Hub_Telemetry.Inputs;
      Chip_Ok         : Boolean := True;
      Hub_Free        : Boolean := True;
   end record;

   type Received is (None, Bind_Done, Data_Ready);

   --  Start-up: the pins, the chip check, and the protocol from its initial
   --  state; false when the chip does not answer. The RSSI source
   --  passes to the protocol when none is set.
   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean);

   --  The calibration the target measured on the Calibrate operation.
   procedure Set_Calibration (S : in out State; Table : Calibration_Table);

   --  A bind request from outside, as the bind command makes it.
   procedure Request_Bind (S : in out State);

   --  One protocol call: the start-up, the bind states, then the protocol's
   --  own states.
   procedure Data_Received
     (S : in out State; C : in out Settings; Inp : Inputs; O : out Output; Result : out Received);

   Max_Channels : constant := 16;
   type Channel_Values is array (0 .. Max_Channels - 1) of Unsigned_16;

   --  The channels a protocol carries: eight for D8, sixteen for X.
   function Channel_Count (C : Settings) return Natural is (if C.Protocol = FrSky_D then 8 else 16);

   --  The channels of the last data packet: D8 keeps them unless one is out
   --  of range, X skips a failsafe packet and places a channel with its
   --  shift bit eight higher.
   procedure Set_Rc_Data (S : in out State; C : Settings; Rc : in out Channel_Values);

end Adaflight.FrSky_SPI;
