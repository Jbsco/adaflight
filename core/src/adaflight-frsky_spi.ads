--  FrSky SPI receiver on a CC2500 radio, D8 protocol. Start-up resets,
--  configures and calibrates the radio on every channel. Binding tunes the
--  frequency offset up and down on bind packets, then collects the hop table
--  and the transmitter id from them. Bound, the receiver hops over the table,
--  takes channel packets from its transmitter with the RSSI from their status
--  byte, answers in the telemetry slot, and on timeouts hops on, switches
--  antennas and drops the RSSI. The radio and the pins stay with the target,
--  which carries out the operations in order, hands back the calibration and
--  shows the receive FIFO.
with Interfaces;

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

   --  The receiver's settings, the bind results among them, and the pins the
   --  board has.
   type Settings is record
      Auto_Bind     : Boolean := False;
      Bind_Tx_Id    : Tx_Id := (others => 0);
      Bind_Offset   : Integer_8 := 0;
      Bind_Hop_Data : Hop_Table := (others => 0);
      Rx_Num        : Unsigned_8 := 0;
      A1            : A1_Source := Battery_Voltage;
      Chip_Detect   : Boolean := True;
      Tx_Enable_Pin : Boolean := False;
      LNA_Pin       : Boolean := False;
      Antenna_Pin   : Boolean := False;
      LED_Pin       : Boolean := False;
      LED_Inversion : Boolean := False;
      Bind_Pin      : Boolean := False;
   end record;

   Calibrated_Channels : constant := 255;
   type Calibration is array (0 .. 2) of Unsigned_8;
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
      RSSI_Dbm          : Integer_16 := 0;
      Other_Antenna     : Boolean := True;
      Bind_Requested    : Boolean := False;
      Last_Bind_Pin     : Boolean := False;
      Last_Packet_Us    : Unsigned_32 := 0;
      Telemetry_Us      : Unsigned_32 := 0;
      Data_Errors       : Unsigned_16 := 0;
      Frame             : Frame_Bytes := (others => 0);
      Payload           : Payload_Bytes := (others => 0);
   end record;

   type Op_Kind is
     (Reset, Startup_Speed, Normal_Speed, Strobe, Write_Register, Read_Fifo, Write_Fifo, Set_Power, Delay_Ms,
      Delay_Us, Calibrate, Pin_High, Pin_Low, Pin_Toggle, Set_RSSI, Set_RSSI_Direct, Save_Config);
   type Pin is (LED, Tx_Enable, LNA_Enable, Antenna_Select);

   --  One operation: the strobe, register, byte count or power level, the
   --  register value, the pin, and the RSSI or the delay.
   type Op is record
      Kind  : Op_Kind := Strobe;
      A     : Unsigned_8 := 0;
      B     : Unsigned_8 := 0;
      On    : Pin := LED;
      Value : Unsigned_16 := 0;
   end record;

   Max_Ops : constant := 200;
   type Op_List is array (1 .. Max_Ops) of Op;

   --  The operations in order, and the FIFO bytes a write sends.
   type Output is record
      Ops       : Op_List;
      Count     : Natural range 0 .. Max_Ops := 0;
      Fifo_Data : Frame_Bytes := (others => 0);
   end record;

   --  What a call reads: the clocks, the radio's interrupt line, the bytes in
   --  its receive FIFO, the bind pin, and the telemetry's analog readings.
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
      Chip_Ok         : Boolean := True;
   end record;

   type Received is (None, Bind_Done, Data_Ready);

   --  Start-up: the pins, the chip check, and the D8 protocol from its
   --  initial state; false when the chip does not answer. The RSSI source
   --  passes to the protocol when none is set.
   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean);

   --  The calibration the target measured on the Calibrate operation.
   procedure Set_Calibration (S : in out State; Table : Calibration_Table);

   --  A bind request from outside, as the bind command makes it.
   procedure Request_Bind (S : in out State);

   --  One protocol call: the start-up, the bind states, then the D8 states.
   procedure Data_Received
     (S : in out State; C : in out Settings; Inp : Inputs; O : out Output; Result : out Received);

   Channel_Count : constant := 8;
   type Channel_Values is array (0 .. Channel_Count - 1) of Unsigned_16;

   --  The channels of the last data packet, kept unless one is out of range.
   procedure Set_Rc_Data (S : in out State; Rc : in out Channel_Values);

end Adaflight.FrSky_SPI;
