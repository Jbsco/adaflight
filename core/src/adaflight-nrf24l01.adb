package body Adaflight.NRF24L01 with SPARK_Mode is
   use Adaflight.SPI_Radio;
   use type Interfaces.Unsigned_32;

   W_REGISTER    : constant := 16#20#;
   REGISTER_MASK : constant := 16#1F#;
   W_TX_PAYLOAD  : constant := 16#A0#;
   FLUSH_TX_CMD  : constant := 16#E1#;
   FLUSH_RX_CMD  : constant := 16#E2#;
   Settling_Us   : constant := 100_000;
   Power_Up_Us   : constant := 4_500;

   procedure Write_Reg (O : in out Output; Register, Value : Unsigned_8) is
   begin
      Write (O, W_REGISTER or (Register and REGISTER_MASK), Value);
   end Write_Reg;

   procedure Write_Register_Multi (O : in out Output; Register : Unsigned_8; Data : Adaflight.SPI_Radio.Byte_Array) is
   begin
      Write_Block (O, W_REGISTER or (Register and REGISTER_MASK), Data);
   end Write_Register_Multi;

   procedure Write_Payload (O : in out Output; Data : Adaflight.SPI_Radio.Byte_Array) is
   begin
      Write_Block (O, W_TX_PAYLOAD, Data);
   end Write_Payload;

   procedure Read_Payload (O : in out Output; Length : Unsigned_8) is
   begin
      Add (O, (Kind => Read_Fifo, A => Length, others => <>));
   end Read_Payload;

   procedure Flush_Tx (O : in out Output) is
   begin
      Strobe (O, FLUSH_TX_CMD);
   end Flush_Tx;

   procedure Flush_Rx (O : in out Output) is
   begin
      Strobe (O, FLUSH_RX_CMD);
   end Flush_Rx;

   procedure Initialize (D : out Driver; O : in out Output; Base_Config : Unsigned_8; Now_Us : Unsigned_32) is
   begin
      D.Standby_Config := CONFIG_PWR_UP or Base_Config;
      Set_Pin (O, Chip_Enable, False);
      if Now_Us < Settling_Us then
         Add (O, (Kind => Delay_Us, Value => Unsigned_16 ((Settling_Us - Now_Us) mod 2 ** 16),
                  Word => Settling_Us - Now_Us, others => <>));
      end if;
      Write_Reg (O, CONFIG, D.Standby_Config);
      Add (O, (Kind => Delay_Us, Value => Power_Up_Us, others => <>));
   end Initialize;

   procedure Setup_Basic (O : in out Output) is
   begin
      Write_Reg (O, EN_AA, 16#00#);
      Write_Reg (O, EN_RXADDR, 16#01#);
      Write_Reg (O, SETUP_AW, 16#03#);
      Write_Reg (O, DYNPD, 16#00#);
   end Setup_Basic;

   procedure Set_Standby_Mode (D : Driver; O : in out Output) is
   begin
      Set_Pin (O, Chip_Enable, False);
      Write_Reg (O, CONFIG, D.Standby_Config);
   end Set_Standby_Mode;

   procedure Set_Rx_Mode (D : Driver; O : in out Output) is
   begin
      Set_Pin (O, Chip_Enable, False);
      Write_Reg (O, CONFIG, D.Standby_Config or CONFIG_PRIM_RX);
      Clear_All_Interrupts (O);
      Set_Pin (O, Chip_Enable, True);
   end Set_Rx_Mode;

   procedure Set_Tx_Mode (D : Driver; O : in out Output) is
   begin
      Set_Standby_Mode (D, O);
      Clear_All_Interrupts (O);
      Set_Pin (O, Chip_Enable, True);
      Add (O, (Kind => Delay_Us, Value => 10, others => <>));
      Set_Pin (O, Chip_Enable, False);
   end Set_Tx_Mode;

   procedure Clear_All_Interrupts (O : in out Output) is
   begin
      Write_Reg (O, STATUS, STATUS_RX_DR or STATUS_TX_DS or STATUS_MAX_RT);
   end Clear_All_Interrupts;

   procedure Set_Channel (O : in out Output; Channel : Unsigned_8) is
   begin
      Write_Reg (O, RF_CH, Channel);
   end Set_Channel;

   procedure Read_Payload_If_Available (O : in out Output; Fifo_Status : Unsigned_8; Length : Unsigned_8;
                                        Available : out Boolean)
   is
   begin
      Available := (Fifo_Status and FIFO_RX_EMPTY) = 0;
      if Available then
         Read_Payload (O, Length);
      end if;
   end Read_Payload_If_Available;

end Adaflight.NRF24L01;
