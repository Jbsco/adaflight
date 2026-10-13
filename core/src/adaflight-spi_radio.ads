--  Radio helpers shared by the SPI receivers: the operations a protocol
--  hands the target in order, the receiver's pins, the LED with its blink
--  timer, the bind button and bind requests, the RSSI from a packet's status
--  byte, the antenna switch, and the CC2500 strobes.
with Interfaces;

package Adaflight.SPI_Radio with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;

   --  CC2500 strobes.
   SIDLE : constant := 16#36#;
   SRX   : constant := 16#34#;
   SFRX  : constant := 16#3A#;
   SCAL  : constant := 16#33#;

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

   type Tx_Bytes is array (0 .. 19) of Unsigned_8;

   type Register_Value is record
      Register : Unsigned_8;
      Value    : Unsigned_8;
   end record;
   type Register_List is array (Positive range <>) of Register_Value;

   --  The frequency synthesizer calibration of one channel.
   type Calibration is array (0 .. 2) of Unsigned_8;

   --  The operations in order, and the FIFO bytes a write sends.
   type Output is record
      Ops     : Op_List;
      Count   : Natural range 0 .. Max_Ops := 0;
      Tx_Data : Tx_Bytes := (others => 0);
   end record;

   --  The pins the board has, and whether the chip is checked at start-up.
   type Pins is record
      Chip_Detect   : Boolean := True;
      Tx_Enable     : Boolean := False;
      LNA           : Boolean := False;
      Antenna       : Boolean := False;
      LED           : Boolean := False;
      LED_Inversion : Boolean := False;
      Bind          : Boolean := False;
   end record;

   --  The RSSI in dBm, the antenna pin when start-up set it, the antenna in
   --  use, the bind request with the bind pin's last level, and the LED's
   --  last blink.
   type Radio is record
      RSSI_Dbm       : Integer_16 := 0;
      Antenna_Pin    : Boolean := False;
      Other_Antenna  : Boolean := True;
      Bind_Requested : Boolean := False;
      Last_Bind_Pin  : Boolean := False;
      LED_Blink_Ms   : Unsigned_32 := 0;
   end record;

   procedure Add (O : in out Output; Item : Op)
     with Global => null, Post => O.Count = Natural'Min (O.Count'Old + 1, Max_Ops);

   procedure Strobe (O : in out Output; Command : Unsigned_8)
     with Global => null;

   procedure Write (O : in out Output; Register, Value : Unsigned_8)
     with Global => null;

   procedure Set_Pin (O : in out Output; On : Pin; High : Boolean)
     with Global => null;

   --  A signed setting as the register byte that holds it.
   function Byte_Of (V : Integer_8) return Unsigned_8 is
     (if V >= 0 then Unsigned_8 (V) else Unsigned_8 (Integer (V) + 256));

   procedure Write_All (O : in out Output; List : Register_List)
     with Global => null;

   --  The calibration of Count channels, the first at Base and each one Step
   --  above the one before, which the target measures and hands back.
   procedure Calibrate_Channels (O : in out Output; Count, Step, Base : Unsigned_8)
     with Global => null;

   procedure LED_On (O : in out Output; P : Pins)
     with Global => null;

   procedure LED_Off (O : in out Output; P : Pins)
     with Global => null;

   procedure LED_Toggle (O : in out Output; P : Pins)
     with Global => null;

   --  A toggle once the period has passed since the last one.
   procedure LED_Blink (R : in out Radio; P : Pins; O : in out Output; Now_Ms : Unsigned_32; Period_Ms : Unsigned_32)
     with Global => null;

   --  The pins at start-up: the LED off, the bind pin's level, the chip
   --  check, the LNA and antenna pins raised and the transmit pin lowered;
   --  false when the checked chip does not answer.
   procedure Start (R : out Radio; P : Pins; Bind_Pin_Level, Chip_Ok : Boolean; O : in out Output; Ok : out Boolean)
     with Global => null;

   --  A bind request: a falling edge on the bind pin raises one, and a check
   --  that resets takes it.
   procedure Check_Bind_Requested
     (R : in out Radio; P : Pins; Bind_Pin_Level : Boolean; Reset : Boolean; Requested : out Boolean)
     with Global => null;

   --  The RSSI in dBm from a packet's status byte, sent on eight times over.
   procedure Set_RSSI_Dbm (R : in out Radio; O : in out Output; Value : Unsigned_8)
     with Global => null;

   procedure Switch_Antennae (R : in out Radio; O : in out Output)
     with Global => null;

end Adaflight.SPI_Radio;
