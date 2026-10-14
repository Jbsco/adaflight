--  The NRF24L01 radio driver the NRF24 receivers share: register writes as
--  SPI commands, the payload write and read, the FIFO flushes, the power-up
--  with its settling wait, and the standby, receive and transmit modes
--  through the chip enable pin. Register reads are inputs the target
--  supplies.
with Interfaces;
with Adaflight.SPI_Radio;

package Adaflight.NRF24L01 with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Output is Adaflight.SPI_Radio.Output;

   CONFIG      : constant := 16#00#;
   EN_AA       : constant := 16#01#;
   EN_RXADDR   : constant := 16#02#;
   SETUP_AW    : constant := 16#03#;
   SETUP_RETR  : constant := 16#04#;
   RF_CH       : constant := 16#05#;
   RF_SETUP    : constant := 16#06#;
   STATUS      : constant := 16#07#;
   RX_ADDR_P0  : constant := 16#0A#;
   TX_ADDR     : constant := 16#10#;
   RX_PW_P0    : constant := 16#11#;
   FIFO_STATUS : constant := 16#17#;
   DYNPD       : constant := 16#1C#;

   CONFIG_EN_CRC  : constant := 16#08#;
   CONFIG_CRCO    : constant := 16#04#;
   CONFIG_PWR_UP  : constant := 16#02#;
   CONFIG_PRIM_RX : constant := 16#01#;
   STATUS_RX_DR   : constant := 16#40#;
   STATUS_TX_DS   : constant := 16#20#;
   STATUS_MAX_RT  : constant := 16#10#;
   FIFO_RX_EMPTY  : constant := 16#01#;
   FIFO_TX_EMPTY  : constant := 16#10#;

   RF_DR_250K : constant := 16#20#;
   RF_DR_1M   : constant := 16#00#;
   RF_DR_2M   : constant := 16#08#;
   RF_PWR_N12 : constant := 16#02#;

   type Driver is record
      Standby_Config : Unsigned_8 := 0;
   end record;

   procedure Write_Reg (O : in out Output; Register, Value : Unsigned_8)
     with Global => null;

   procedure Write_Register_Multi (O : in out Output; Register : Unsigned_8; Data : Adaflight.SPI_Radio.Byte_Array)
     with Global => null, Pre => Data'Length <= 32;

   procedure Write_Payload (O : in out Output; Data : Adaflight.SPI_Radio.Byte_Array)
     with Global => null, Pre => Data'Length <= 32;

   --  A payload of Length bytes from the receive FIFO into the target's
   --  buffer.
   procedure Read_Payload (O : in out Output; Length : Unsigned_8)
     with Global => null;

   procedure Flush_Tx (O : in out Output) with Global => null;
   procedure Flush_Rx (O : in out Output) with Global => null;

   --  Power-up into standby with the base configuration, after the chip's
   --  settling time of 100 ms from start.
   procedure Initialize (D : out Driver; O : in out Output; Base_Config : Unsigned_8; Now_Us : Unsigned_32)
     with Global => null;

   procedure Setup_Basic (O : in out Output) with Global => null;
   procedure Set_Standby_Mode (D : Driver; O : in out Output) with Global => null;
   procedure Set_Rx_Mode (D : Driver; O : in out Output) with Global => null;
   procedure Set_Tx_Mode (D : Driver; O : in out Output) with Global => null;
   procedure Clear_All_Interrupts (O : in out Output) with Global => null;
   procedure Set_Channel (O : in out Output; Channel : Unsigned_8) with Global => null;

   --  The payload when the FIFO status shows one waiting.
   procedure Read_Payload_If_Available (O : in out Output; Fifo_Status : Unsigned_8; Length : Unsigned_8;
                                        Available : out Boolean)
     with Global => null, Post => Available = ((Fifo_Status and FIFO_RX_EMPTY) = 0);

end Adaflight.NRF24L01;
