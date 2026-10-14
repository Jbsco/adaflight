with Adaflight.XN297;

package body Adaflight.CX10 with SPARK_Mode is
   use Adaflight.NRF24L01;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   package Radio renames Adaflight.SPI_Radio;

   Tx_Address : constant Radio.Byte_Array := (16#55#, 16#0F#, 16#71#, 16#0C#, 16#00#);
   Rx_Address : constant Adaflight.XN297.Address := (16#49#, 16#26#, 16#87#, 16#7D#, 16#2F#);
   Bind_Channel  : constant := 16#02#;
   Bind_Mark     : constant := 16#AA#;
   Ack_Mark      : constant := 16#01#;
   Acks_To_Send  : constant := 8;
   Fifo_Poll_Us  : constant := 100;
   Ack_Period_Us : constant := 1_000;
   PWM_Min : constant := 1_000;
   PWM_Mid : constant := 1_500;
   PWM_Max : constant := 2_000;

   procedure Hop (S : in out State; O : in out Radio.Output) is
   begin
      S.Channel_Index := S.Channel_Index + 1;
      if S.Channel_Index >= 4 then
         S.Channel_Index := 0;
      end if;
      Set_Channel (O, S.Channels (Natural (S.Channel_Index)));
   end Hop;

   --  The packet when the FIFO holds one, unscrambled, and whether its check
   --  is good.
   procedure Read_Packet (S : State; Fifo_Status : Unsigned_8; Buffer : in out Payload_Buffer;
                          O : in out Radio.Output; Good : out Boolean)
   is
      Size      : constant Natural := Payload_Size (S.Kind);
      Available : Boolean;
      Check     : Unsigned_16;
   begin
      Good := False;
      Read_Payload_If_Available (O, Fifo_Status, Unsigned_8 (Size + CRC_Length), Available);
      if Available then
         Adaflight.XN297.Unscramble (Buffer, Size, Rx_Address, Check);
         Good := Buffer (Size) = Unsigned_8 (Interfaces.Shift_Right (Check, 8))
           and then Buffer (Size + 1) = Unsigned_8 (Check and 16#FF#);
      end if;
   end Read_Packet;

   procedure Await_Tx_Empty (O : in out Radio.Output) is
   begin
      Radio.Add (O, (Kind => Radio.Await_Set, A => FIFO_STATUS, B => FIFO_TX_EMPTY, Value => Fifo_Poll_Us,
                     others => <>));
   end Await_Tx_Empty;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Kind : Variant; Now_Us : Unsigned_32; O : out Radio.Output) is
   begin
      S := (others => <>);
      O := (others => <>);
      S.Kind := Kind;
      S.Phase := Bind;
      Initialize (S.Radio, O, 0, Now_Us);
      Setup_Basic (O);
      Set_Channel (O, Bind_Channel);
      Write_Reg (O, RF_SETUP, RF_DR_1M or RF_PWR_N12);
      Flush_Rx (O);
      Write_Register_Multi (O, TX_ADDR, Tx_Address);
      Write_Register_Multi (O, RX_ADDR_P0, (Rx_Address (0), Rx_Address (1), Rx_Address (2), Rx_Address (3),
                                            Rx_Address (4)));
      Write_Reg (O, RX_PW_P0, Unsigned_8 (Payload_Size (Kind) + CRC_Length));
      Set_Rx_Mode (S.Radio, O);
   end Init;

   -------------------
   -- Data_Received --
   -------------------

   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : in out Payload_Buffer; O : out Radio.Output; R : out Result)
   is
      Size : constant Natural := Payload_Size (S.Kind);
      Good : Boolean;
   begin
      O := (others => <>);
      R := None;
      case S.Phase is
         when Bind =>
            Read_Packet (S, Fifo_Status, Buffer, O, Good);
            if Good and then Buffer (0) = Bind_Mark then
               S.Tx_Id := (Buffer (1), Buffer (2), Buffer (3), Buffer (4));
               S.Channel_Index := 0;
               S.Channels := (16#03# + (S.Tx_Id (0) and 16#0F#), 16#16# + Interfaces.Shift_Right (S.Tx_Id (0), 4),
                              16#2D# + (S.Tx_Id (1) and 16#0F#), 16#40# + Interfaces.Shift_Right (S.Tx_Id (1), 4));
               R := Bind_Received;
               S.Phase := Ack;
               S.Ack_Count := 0;
            end if;
         when Ack =>
            S.Ack_Count := S.Ack_Count + 1;
            Buffer (9) := Ack_Mark;
            Set_Channel (O, Bind_Channel);
            Flush_Tx (O);
            Adaflight.XN297.Write_Payload (O, Buffer, Size, Rx_Address);
            Set_Tx_Mode (S.Radio, O);
            Await_Tx_Empty (O);
            for I in Hop_Table'Range loop
               Set_Channel (O, S.Channels (I));
               Adaflight.XN297.Write_Payload (O, Buffer, Size, Rx_Address);
               Set_Tx_Mode (S.Radio, O);
               Await_Tx_Empty (O);
            end loop;
            Radio.Add (O, (Kind => Radio.Delay_Rest, Value => Ack_Period_Us, others => <>));
            Set_Rx_Mode (S.Radio, O);
            if S.Ack_Count > Acks_To_Send then
               Set_Channel (O, S.Channels (0));
               S.Phase := Data;
            end if;
         when Data =>
            Read_Packet (S, Fifo_Status, Buffer, O, Good);
            if Good then
               Hop (S, O);
               S.Time_Of_Last_Hop := Now_Us;
               R := Data_Received_Result;
            end if;
            if Now_Us > S.Time_Of_Last_Hop + Hop_Timeout_Us (S.Kind) then
               Hop (S, O);
               S.Time_Of_Last_Hop := Now_Us;
            end if;
      end case;
   end Data_Received;

   -----------------
   -- Set_RC_Data --
   -----------------

   procedure Set_RC_Data (S : State; Buffer : Payload_Buffer; RC : in out RC_Channels) is
      Offset : constant Natural := (case S.Kind is when CX10 => 0, when CX10A => 4);

      --  A stick from two bytes, low first, without the flag in the top bit.
      function Stick (I : Natural) return Natural is
        (Natural (Buffer (I + 1) and 16#7F#) * 256 + Natural (Buffer (I)))
        with Pre => I < Buffer_Size - 1;

      function Switch (On : Boolean) return Unsigned_16 is (if On then PWM_Max else PWM_Min);

      Flags_1 : constant Unsigned_8 := Buffer (13 + Offset);
      Flags_2 : constant Unsigned_8 := Buffer (14 + Offset);
      Rate    : constant Unsigned_8 := Flags_1 and 16#03#;
   begin
      RC (0) := Unsigned_16'Mod (PWM_Max + PWM_Min - Stick (5 + Offset));
      RC (1) := Unsigned_16'Mod (PWM_Max + PWM_Min - Stick (7 + Offset));
      RC (2) := Unsigned_16 (Stick (9 + Offset));
      RC (3) := Unsigned_16 (Stick (11 + Offset));
      RC (4) := (if Rate = 0 then PWM_Min elsif Rate = 1 then PWM_Mid else PWM_Max);
      RC (5) := Switch ((Buffer (12 + Offset) and 16#10#) /= 0);
      RC (6) := Switch ((Flags_2 and 16#04#) /= 0);
      RC (7) := Switch ((Flags_2 and 16#02#) /= 0);
      RC (8) := Switch ((Flags_1 and 16#04#) /= 0);
   end Set_RC_Data;

end Adaflight.CX10;
