--  S-FHSS receiver on a CC2500 radio. The first call after 10 ms resets and
--  configures the radio and calibrates its 30 channels. Binding listens on
--  channel 15, raises the frequency offset by 16 every 220 ms until a packet
--  with good link quality arrives, takes the transmitter id from it, then
--  widens the offset up and down by 4 while packets keep arriving and keeps
--  the midpoint. Bound, the receiver hunts for its transmitter with a hop
--  every 500 ms, follows the hop code each packet contains, takes channels 1
--  to 4 and 5 to 8 from alternate packets with the RSSI from their status
--  byte, and hops on timeouts, switching antennas after two misses and
--  hunting again after 100. The radio and the pins stay with the target,
--  which carries out the operations in order, hands back the calibration and
--  shows the receive FIFO.
with Interfaces;
with Adaflight.CC2500_Radio;

package Adaflight.SFHSS with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;

   type Tx_Id is array (0 .. 1) of Unsigned_8;

   --  The receiver's settings, the bind results among them, and the pins the
   --  board has.
   type Settings is record
      Bind_Tx_Id  : Tx_Id := (others => 0);
      Bind_Offset : Integer_8 := 0;
      Pins        : Adaflight.CC2500_Radio.Pins;
   end record;

   Calibrated_Channels : constant := 30;
   type Calibration_Table is array (0 .. Calibrated_Channels - 1) of Adaflight.CC2500_Radio.Calibration;

   Packet_Length : constant := 15;
   type Packet_Bytes is array (0 .. Packet_Length - 1) of Unsigned_8;

   Fifo_Size : constant := 64;
   type Fifo_Bytes is array (0 .. Fifo_Size - 1) of Unsigned_8;

   type Protocol_State is (Init, Hunt, Sync, Bind, Bind_Tuning_1, Bind_Tuning_2, Bind_Tuning_3, Bind_Complete);

   subtype Hop_Channel is Integer_8 range 0 .. Integer_8'Last;
   subtype Hop_Code is Integer_8 range 0 .. 31;

   --  The protocol state, the start time, the hop channel and code, the
   --  missed hops, the calibration, the bind tuning, the next hop time, the
   --  halves received since the last hop, the radio and the last packet.
   type State is record
      Protocol        : Protocol_State := Init;
      Start_Time_Ms   : Unsigned_32 := 0;
      Channel         : Hop_Channel := 0;
      Code            : Hop_Code := 0;
      Missing_Packets : Unsigned_32 := 0;
      Cal             : Calibration_Table := (others => (others => 0));
      Time_Tuned_Ms   : Unsigned_32 := 0;
      Offset_Max      : Integer_8 := 0;
      Offset_Min      : Integer_8 := 0;
      Next_Hop_Us     : Unsigned_32 := 0;
      Low_Seen        : Boolean := False;
      High_Seen       : Boolean := False;
      Radio           : Adaflight.CC2500_Radio.Radio;
      Packet          : Packet_Bytes := (others => 0);
   end record;

   --  A channel past 31 arises only under a hop code of 30 or 31.
   function Hops_Valid (S : State) return Boolean is (S.Channel <= 31 or else S.Code >= 30);

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
   --  state. It reports success whether or not the chip answers. The RSSI
   --  source passes to the protocol when none is set and the chip answered.
   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean)
     with Post => Hops_Valid (S);

   --  The calibration the target measured on the Calibrate operation.
   procedure Set_Calibration (S : in out State; Table : Calibration_Table)
     with Pre => Hops_Valid (S), Post => Hops_Valid (S);

   --  A bind request from outside, as the bind command makes it.
   procedure Request_Bind (S : in out State)
     with Pre => Hops_Valid (S), Post => Hops_Valid (S);

   --  One protocol call: the start-up, the bind tuning, the hunt and the
   --  synchronized hops.
   procedure Data_Received
     (S : in out State; C : in out Settings; Inp : Inputs; O : out Output; Result : out Received)
     with Pre => Hops_Valid (S), Post => Hops_Valid (S);

   Channel_Count : constant := 8;
   type Channel_Values is array (0 .. Channel_Count - 1) of Unsigned_16;

   --  The four channels of the last data packet, 5 to 8 when it says so.
   procedure Set_Rc_Data (S : State; Rc : in out Channel_Values);

end Adaflight.SFHSS;
