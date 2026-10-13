--  Redpine receiver on a CC2500 radio, in a fast and a slow mode. The first
--  call after 10 ms resets and configures the radio for its mode and
--  calibrates every channel. Binding switches to the fast mode, listens on
--  channel 0, raises the frequency offset by 16 every 220 ms until a bind
--  packet arrives, then widens the offset up and down by 2 while bind packets
--  keep arriving, keeps the midpoint, and collects the transmitter id and the
--  49-channel hop table in chunks of five. Bound, the receiver hops over the
--  table, takes packets from its transmitter with their loop time and the
--  RSSI from their status byte, hops on after a missed packet, switches
--  antennas after two misses, resynchronizes after 50 loop times, and
--  switches modes after 2 s without packets. The radio and the pins stay with
--  the target, which carries out the operations in order, hands back the
--  calibration and shows the receive FIFO.
with Interfaces;
with Adaflight.CC2500_Radio;

package Adaflight.Redpine with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_32 is Interfaces.Integer_32;

   Hop_Channels : constant := 49;
   type Hop_Table is array (0 .. 49) of Unsigned_8;
   type Tx_Id is array (0 .. 1) of Unsigned_8;

   --  The receiver's settings, the bind results among them, and the pins the
   --  board has.
   type Settings is record
      Auto_Bind     : Boolean := False;
      Bind_Tx_Id    : Tx_Id := (others => 0);
      Bind_Offset   : Integer_8 := 0;
      Bind_Hop_Data : Hop_Table := (others => 0);
      Pins          : Adaflight.CC2500_Radio.Pins;
   end record;

   Calibrated_Channels : constant := 255;
   type Calibration_Table is array (0 .. Calibrated_Channels - 1) of Adaflight.CC2500_Radio.Calibration;

   Packet_Length : constant := 13;
   type Packet_Bytes is array (0 .. Packet_Length - 1) of Unsigned_8;

   Fifo_Size : constant := 64;
   type Fifo_Bytes is array (0 .. Fifo_Size - 1) of Unsigned_8;

   type Protocol_State is
     (Init, Bind, Bind_Tuning_1, Bind_Tuning_2, Bind_Tuning_3, Bind_Complete, Starting, Update, Data);

   subtype Loop_Time is Integer_32 range 0 .. 255_000;

   --  The protocol state, the start time, the missed packets, the
   --  calibration, the bind tuning, the mode, the hop position, the loop
   --  time and the packet, total and protocol timers, the radio and the last
   --  packet.
   type State is record
      Protocol          : Protocol_State := Init;
      Start_Time_Ms     : Unsigned_32 := 0;
      Missing_Packets   : Unsigned_32 := 0;
      Cal               : Calibration_Table := (others => (others => 0));
      Time_Tuned_Ms     : Unsigned_32 := 0;
      Offset_Max        : Integer_8 := 0;
      Offset_Min        : Integer_8 := 0;
      Fast              : Boolean := True;
      Hop_Index         : Natural range 0 .. Hop_Channels - 1 := 0;
      Loop_Time_Us      : Loop_Time := 50_000;
      Packet_Timer_Us   : Unsigned_32 := 0;
      Total_Timer_Us    : Unsigned_32 := 0;
      Protocol_Timer_Us : Unsigned_32 := 0;
      Radio             : Adaflight.CC2500_Radio.Radio;
      Packet            : Packet_Bytes := (others => 0);
   end record;

   subtype Output is Adaflight.CC2500_Radio.Output;

   --  What a call reads: the clocks, the radio's interrupt line, the bytes in
   --  its receive FIFO and the bind pin; at start-up, the chip check.
   type Inputs is record
      Now_Us         : Unsigned_32 := 0;
      Now_Ms         : Unsigned_32 := 0;
      Exti           : Boolean := False;
      Rx_Bytes       : Unsigned_8 := 0;
      Fifo           : Fifo_Bytes := (others => 0);
      Bind_Pin_Level : Boolean := True;
      Chip_Ok        : Boolean := True;
   end record;

   type Received is (None, Bind_Done, Data_Ready);

   --  Start-up: the pins, the chip check, and the protocol from its initial
   --  state; false when the chip does not answer. The RSSI source passes to
   --  the protocol when none is set.
   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean);

   --  The calibration the target measured on the Calibrate operation.
   procedure Set_Calibration (S : in out State; Table : Calibration_Table);

   --  A bind request from outside, as the bind command makes it.
   procedure Request_Bind (S : in out State);

   --  One protocol call: the start-up, the bind tuning, then the hops.
   procedure Data_Received
     (S : in out State; C : in out Settings; Inp : Inputs; O : out Output; Result : out Received);

   Channel_Count : constant := 16;
   type Channel_Values is array (0 .. Channel_Count - 1) of Unsigned_16;

   --  The video transmitter settings a status frame asks for while disarmed.
   type VTX_Request is record
      Present : Boolean := False;
      Band    : Unsigned_8 := 0;
      Channel : Unsigned_8 := 0;
      Power   : Unsigned_8 := 0;
   end record;

   --  The channels of the last data packet: four sticks scaled from eleven
   --  bits and twelve switches; or a status frame's VTX settings.
   procedure Set_Rc_Data (S : State; Armed : Boolean; Rc : in out Channel_Values; VTX : out VTX_Request);

end Adaflight.Redpine;
