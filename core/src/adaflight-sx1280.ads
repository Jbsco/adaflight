--  The SX1280 radio of the ExpressLRS SPI receiver. Every transfer waits
--  for the busy pin to fall, up to a millisecond, then sends the command,
--  register or buffer bytes over the receiver's SPI. Initialization needs
--  the receiver's interrupt pin, sets the 18 MHz clock, pulses the reset pin
--  low for 50 ms and lets it float for 20 ms, reads the firmware version,
--  which has to be neither 0 nor 65535, then sets standby on the RC
--  oscillator, automatic frequency synthesis and the high sensitivity gain
--  regime. The configuration sets the packet type, the modulation and
--  packet parameters of LoRa or FLRC, the interrupt masks, the output
--  power and the frequency. The interrupt runs a chain of DMA transfers,
--  each started when the busy pin is low or when it falls: the interrupt
--  status read, its clear, then for a received packet the buffer address,
--  the eight packet bytes, the packet statistics and the receiver's packet
--  processing, then the hop frequency when the receiver asks for one, the
--  telemetry packet and transmission when it asks for that, or the return to
--  reception, and the receiver interrupt enabled again. A hardware error
--  ends the chain after the clear, and the tick handler ends a chain that
--  holds the radio past a millisecond.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Radio_Device is limited private;
   with procedure Read_Busy (D : in out Radio_Device; Busy : out Boolean);
   with procedure Micros (D : in out Radio_Device; Now : out Interfaces.Unsigned_32);
   with procedure Exti_Configured (D : in out Radio_Device; Configured : out Boolean);
   with procedure Set_Normal_Speed (D : in out Radio_Device; Hz : Interfaces.Unsigned_32);
   with procedure Init_Reset_Pin (D : in out Radio_Device);
   with procedure Init_Busy_Pin (D : in out Radio_Device);
   with procedure Reset_Low (D : in out Radio_Device);
   with procedure Reset_Float (D : in out Radio_Device);
   with procedure Delay_Ms (D : in out Radio_Device; Ms : Natural);
   --  The busy pin's interrupt: configured once per chain, armed with the
   --  handler while the radio is busy, disabled before each transfer.
   with procedure Busy_Exti_Config (D : in out Radio_Device);
   with procedure Busy_Exti_Arm (D : in out Radio_Device);
   with procedure Busy_Exti_Disable (D : in out Radio_Device);
   --  The receiver's interrupt enabled again, and the time of its last one.
   with procedure Enable_Receiver_Exti (D : in out Radio_Device);
   with procedure Last_Exti_Time (D : in out Radio_Device; Time : out Interfaces.Unsigned_32);
   with procedure Bus_Write_Command (D : in out Radio_Device; Command : Byte; Value : Byte);
   --  A full-duplex transfer of the bytes, answered in place, and one whose
   --  answer is dropped.
   with procedure Bus_Transfer (D : in out Radio_Device; Data : in out Byte_Array);
   with procedure Bus_Write (D : in out Radio_Device; Data : Byte_Array);
   --  One DMA segment answered in place, one whose answer is dropped, a pair
   --  whose head is sent and whose tail is exchanged, and a pair whose two
   --  parts are sent.
   with procedure Run_Transfer (D : in out Radio_Device; Step : Byte; Data : in out Byte_Array);
   with procedure Run_Write (D : in out Radio_Device; Step : Byte; Data : Byte_Array);
   with procedure Run_Pair (D : in out Radio_Device; Step : Byte; Head : Byte_Array; Tail : in out Byte_Array);
   with procedure Run_Pair_Write (D : in out Radio_Device; Step : Byte; Head : Byte_Array; Tail : Byte_Array);
   --  The receiver's answers: whether a hop is due, the hop frequency,
   --  whether a telemetry response is due, its assembly and its packet, and
   --  the processing of a received packet into its status.
   with procedure Hop_Requested (D : in out Radio_Device; Requested : out Boolean);
   with procedure Current_Frequency (D : in out Radio_Device; Frequency : out Interfaces.Unsigned_32);
   with procedure Telemetry_Requested (D : in out Radio_Device; Requested : out Boolean);
   with procedure Do_Telemetry (D : in out Radio_Device);
   with procedure Telemetry_Buffer (D : in out Radio_Device; Data : out Byte_Array);
   with procedure Process_Packet
     (D : in out Radio_Device; Payload : Byte_Array; Timestamp : Interfaces.Unsigned_32; Status : out Byte);
   with procedure Set_Packet_Status (D : in out Radio_Device; Status : Byte);
package Adaflight.SX1280 with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   Packet_Bytes : constant := 8;

   subtype Packet is Byte_Array (0 .. Packet_Bytes - 1);

   type Operating_Mode is (Sleep, Calibration, Standby_RC, Standby_XOSC, Frequency_Synthesis, Receive, Transmit, CAD);

   --  The steps of the interrupt's chain, numbered for the bus log.
   type Step is
     (Irq_Get_Status, Irq_Clear_Status, Process_Irq, Do_Read_Buffer, Get_Packet_Stats, Set_Frequency,
      Start_Receiving_DMA, Send_Telemetry, Start_Transmitting_DMA, No_Step);

   Reason_Unknown  : constant Byte := 0;
   Reason_RX_Done  : constant Byte := 1;
   Reason_TX_Done  : constant Byte := 2;
   Reason_HW_Error : constant Byte := 4;

   --  The time the radio was claimed, 0 when free, whether a hop waits, the
   --  packet type, the last interrupt's reason, the packet statistics, the
   --  buffer address, the step waiting on the busy pin and the received
   --  packet.
   type Radio is record
      Processing   : Interfaces.Unsigned_32 := 0;
      Pending_Hop  : Boolean := False;
      FLRC         : Boolean := False;
      Irq_Reason   : Byte := Reason_Unknown;
      Packet_Stats : Byte_Array (0 .. 1) := (0, 0);
      FIFO_Addr    : Byte := 0;
      Waiting      : Step := No_Step;
      Rx_Buffer    : Packet := (others => 0);
   end record;

   procedure Init (D : in out Radio_Device; Has_Reset_Pin : Boolean; Has_Busy_Pin : Boolean; OK : out Boolean);

   procedure Is_Busy (D : in out Radio_Device; Busy : out Boolean);

   procedure Write_Command (D : in out Radio_Device; Command : Byte; Value : Byte);

   procedure Write_Command_Burst (D : in out Radio_Device; Command : Byte; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Read_Command_Burst (D : in out Radio_Device; Command : Byte; Data : in out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Write_Register_Burst (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Write_Register (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Value : Byte);

   procedure Read_Register_Burst (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Read_Register (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Value : out Byte);

   procedure Write_Buffer (D : in out Radio_Device; Offset : Byte; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Read_Buffer (D : in out Radio_Device; Offset : Byte; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Get_Status (D : in out Radio_Device; Status : out Byte);

   procedure Config
     (D               : in out Radio_Device;
      S               : in out Radio;
      Bandwidth       : Byte;
      Spreading       : Byte;
      Coding          : Byte;
      Frequency       : Interfaces.Unsigned_32;
      Preamble_Length : Byte;
      IQ_Inverted     : Boolean;
      FLRC_Sync_Word  : Interfaces.Unsigned_32;
      FLRC_CRC_Seed   : Interfaces.Unsigned_16;
      Is_FLRC         : Boolean);

   procedure Set_Output_Power (D : in out Radio_Device; Power : Interfaces.Integer_8);

   procedure Set_Mode (D : in out Radio_Device; Mode : Operating_Mode);

   procedure Set_Frequency_Reg (D : in out Radio_Device; Frequency : Interfaces.Unsigned_32);

   procedure Set_FIFO_Addr (D : in out Radio_Device; TX_Base : Byte; RX_Base : Byte);

   procedure Set_DIO_IRQ_Params
     (D         : in out Radio_Device;
      Irq_Mask  : Interfaces.Unsigned_16;
      DIO1_Mask : Interfaces.Unsigned_16;
      DIO2_Mask : Interfaces.Unsigned_16;
      DIO3_Mask : Interfaces.Unsigned_16);

   procedure Transmit_Data (D : in out Radio_Device; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Receive_Data (D : in out Radio_Device; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Start_Receiving (D : in out Radio_Device; S : in out Radio);

   --  The signal strength and the signal to noise ratio of the last packet.
   procedure Get_Last_Packet_Stats (S : Radio; RSSI : out Interfaces.Integer_8; SNR : out Interfaces.Integer_8)
     with Global => null;

   procedure Clear_Irq_Status (D : in out Radio_Device; Irq_Mask : Interfaces.Unsigned_16);

   --  The receiver's interrupt: the chain starts when the radio is free.
   procedure ISR (D : in out Radio_Device; S : in out Radio);

   --  The busy pin fell: the waiting step runs.
   procedure Busy_Fell (D : in out Radio_Device; S : in out Radio);

   --  Handled when the radio was claimed more than a millisecond ago.
   procedure Handle_From_Tick (D : in out Radio_Device; S : in out Radio; Handled : out Boolean);

   procedure Handle_From_Tock (D : in out Radio_Device; S : in out Radio);

end Adaflight.SX1280;
