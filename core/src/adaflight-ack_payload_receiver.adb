package body Adaflight.Ack_Payload_Receiver with SPARK_Mode is
   use Adaflight.NRF24L01;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   package Radio renames Adaflight.SPI_Radio;

   Bind_Channel    : constant := 16#4C#;
   Bind_Mark_0     : constant := 16#AE#;
   Bind_Mark_1     : constant := 16#C9#;
   Bind_Reply_0    : constant := 16#83#;
   Bind_Reply_1    : constant := 16#A5#;
   Hops_When_Bound : constant := 4;
   Hop_Timeout_Us  : constant := 5_000;
   PWM_Min : constant := 1_000;
   PWM_Mid : constant := 1_500;
   PWM_Max : constant := 2_000;

   function Address_Bytes (A : Address) return Radio.Byte_Array is (A (0), A (1), A (2), A (3), A (4))
     with Post => Address_Bytes'Result'Length = 5;

   function Is_Bind_Packet (Buffer : Payload_Buffer) return Boolean is
     (Buffer (0) = Bind_Mark_0 and then Buffer (1) = Bind_Mark_1);

   --  The payload for the next acknowledgment, after the maximum retransmit
   --  flag is cleared.
   procedure Write_Ack (O : in out Radio.Output; Data : Byte_Array)
     with Pre => Data'Length <= 32
   is
   begin
      Write_Reg (O, STATUS, STATUS_MAX_RT);
      Write_Ack_Payload (O, Radio.Byte_Array (Data), 0);
   end Write_Ack;

   --  The bind packet sent back with the reply marks, the hop count and the
   --  payload size.
   procedure Write_Bind_Ack (Buffer : in out Payload_Buffer; O : in out Radio.Output) is
   begin
      Buffer (0) := Bind_Reply_0;
      Buffer (1) := Bind_Reply_1;
      Buffer (7) := Hops_When_Bound;
      Buffer (8) := Payload_Size;
      Write_Ack (O, Buffer (0 .. Payload_Size - 1));
   end Write_Bind_Ack;

   procedure Set_Bound (S : in out State; Now_Us : Unsigned_32; O : in out Radio.Output) is
      Channel : Unsigned_8 := 16#10# + (S.Rx_Tx_Address (0) and 16#07#);
   begin
      S.Phase := Data;
      Write_Register_Multi (O, RX_ADDR_P0, Address_Bytes (S.Rx_Tx_Address));
      Write_Register_Multi (O, TX_ADDR, Address_Bytes (S.Rx_Tx_Address));
      S.Time_Of_Last_Hop := Now_Us;
      S.Channel_Index := 0;
      S.Channel_Count := Hops_When_Bound;
      for I in Hop_Table'Range loop
         S.Channels (I) := Channel;
         Channel := Channel + 16#0C#;
      end loop;
      Set_Channel (O, S.Channels (0));
   end Set_Bound;

   procedure Hop (S : in out State; O : in out Radio.Output) is
   begin
      S.Channel_Index := S.Channel_Index + 1;
      if Natural (S.Channel_Index) >= S.Channel_Count then
         S.Channel_Index := 0;
      end if;
      Set_Channel (O, S.Channels (Natural (S.Channel_Index)));
   end Hop;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Now_Us : Unsigned_32; O : out Radio.Output) is
   begin
      S := (others => <>);
      O := (others => <>);
      Initialize (S.Radio, O, CONFIG_EN_CRC or CONFIG_CRCO or CONFIG_MASK_MAX_RT or CONFIG_MASK_TX_DS, Now_Us);
      Write_Reg (O, EN_AA, 16#01#);
      Write_Reg (O, EN_RXADDR, 16#01#);
      Write_Reg (O, SETUP_AW, 16#03#);
      Write_Reg (O, SETUP_RETR, 16#00#);
      Activate (O, 16#73#);
      Write_Reg (O, FEATURE, FEATURE_EN_ACK_PAY or FEATURE_EN_DPL);
      Write_Reg (O, DYNPD, 16#01#);
      Write_Register_Multi (O, TX_ADDR, Address_Bytes (S.Rx_Tx_Address));
      Write_Reg (O, RF_SETUP, RF_DR_250K or RF_PWR_N12);
      Write_Register_Multi (O, RX_ADDR_P0, Address_Bytes (S.Rx_Tx_Address));
      Write_Reg (O, RX_PW_P0, Payload_Size);
      S.Phase := Bind;
      S.Channel_Count := 1;
      S.Channel_Index := 0;
      Set_Channel (O, Bind_Channel);
      Set_Rx_Mode (S.Radio, O);
      Write_Ack (O, (0 .. Payload_Size - 1 => 0));
   end Init;

   -------------------
   -- Data_Received --
   -------------------

   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : in out Payload_Buffer; O : out Radio.Output; R : out Result)
   is
      Available : Boolean;
   begin
      O := (others => <>);
      R := None;
      case S.Phase is
         when Bind =>
            Read_Payload_If_Available (O, Fifo_Status, Payload_Size, Available);
            if Available and then Is_Bind_Packet (Buffer) then
               S.Rx_Tx_Address := (Buffer (2), Buffer (3), Buffer (4), Buffer (5), Buffer (6));
               R := Bind_Received;
               Write_Bind_Ack (Buffer, O);
               Set_Bound (S, Now_Us, O);
            end if;
         when Data =>
            Read_Payload_If_Available (O, Fifo_Status, Payload_Size, Available);
            if Available then
               Read_Reg (O, RPD);
               if Is_Bind_Packet (Buffer) then
                  R := Bind_Received;
                  Write_Bind_Ack (Buffer, O);
               else
                  R := Data_Received_Result;
               end if;
            end if;
            if R = Data_Received_Result or else Now_Us > S.Time_Of_Last_Hop + Hop_Timeout_Us then
               Hop (S, O);
               S.Time_Of_Last_Hop := Now_Us;
            end if;
      end case;
   end Data_Received;

   -----------------
   -- Set_RC_Data --
   -----------------

   procedure Set_RC_Data (Buffer : Payload_Buffer; RC : out RC_Channels) is
      --  A ten-bit channel: the high eight bits from one byte and the low two
      --  from the given pair of a shared byte.
      function Ten_Bit (High, Low : Unsigned_8; Pair : Natural) return Unsigned_16 is
        (PWM_Min + (Interfaces.Shift_Left (Unsigned_16 (High), 2)
                    or Unsigned_16 (Interfaces.Shift_Right (Low, 2 * Pair) and 16#03#)))
        with Pre => Pair <= 3;

      function Eight_Bit (High : Unsigned_8) return Unsigned_16 is
        (PWM_Min + Interfaces.Shift_Left (Unsigned_16 (High), 2));

      function Switch (On : Boolean) return Unsigned_16 is (if On then PWM_Max else PWM_Min);

      Rate  : constant Unsigned_8 := Buffer (7);
      Flags : constant Unsigned_8 := Buffer (8);
   begin
      RC := (others => 0);
      RC (0) := Ten_Bit (Buffer (2), Buffer (6), 0);
      RC (1) := Ten_Bit (Buffer (3), Buffer (6), 1);
      RC (2) := Ten_Bit (Buffer (4), Buffer (6), 2);
      RC (3) := Ten_Bit (Buffer (5), Buffer (6), 3);
      RC (4) := (if Rate = 2 then PWM_Max elsif Rate = 1 then PWM_Mid else PWM_Min);
      RC (5) := Switch ((Flags and 16#01#) /= 0);
      RC (6) := Switch ((Flags and 16#02#) /= 0);
      RC (7) := Switch ((Flags and 16#04#) /= 0);
      RC (8) := Switch ((Flags and 16#10#) /= 0);
      RC (9) := Switch ((Flags and 16#08#) /= 0);
      RC (10) := Ten_Bit (Buffer (9), Buffer (13), 0);
      RC (11) := Ten_Bit (Buffer (10), Buffer (13), 1);
      RC (12) := Ten_Bit (Buffer (11), Buffer (13), 2);
      RC (13) := Ten_Bit (Buffer (12), Buffer (13), 3);
      RC (14) := Eight_Bit (Buffer (14));
      RC (15) := Eight_Bit (Buffer (15));
   end Set_RC_Data;

end Adaflight.Ack_Payload_Receiver;
