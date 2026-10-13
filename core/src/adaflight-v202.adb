package body Adaflight.V202 with SPARK_Mode is
   use Adaflight.NRF24L01;
   package Radio renames Adaflight.SPI_Radio;

   Bind_Flags : constant := 16#C0#;
   Bind_Timeout_Us : constant := 1_000;
   Data_Timeout_Us : constant := 10_000;
   PWM_Min : constant := 1_000;
   PWM_Max : constant := 2_000;

   type Hop_Rows is array (0 .. 3) of Hop_Table;
   Hopping : constant Hop_Rows :=
     ((16#27#, 16#1B#, 16#39#, 16#28#, 16#24#, 16#22#, 16#2E#, 16#36#,
       16#19#, 16#21#, 16#29#, 16#14#, 16#1E#, 16#12#, 16#2D#, 16#18#),
      (16#2E#, 16#33#, 16#25#, 16#38#, 16#19#, 16#12#, 16#18#, 16#16#,
       16#2A#, 16#1C#, 16#1F#, 16#37#, 16#2F#, 16#23#, 16#34#, 16#10#),
      (16#11#, 16#1A#, 16#35#, 16#24#, 16#28#, 16#18#, 16#25#, 16#2A#,
       16#32#, 16#2C#, 16#14#, 16#27#, 16#36#, 16#34#, 16#1C#, 16#17#),
      (16#22#, 16#27#, 16#17#, 16#39#, 16#34#, 16#28#, 16#2B#, 16#1D#,
       16#18#, 16#2A#, 16#21#, 16#38#, 16#10#, 16#26#, 16#20#, 16#1F#));

   --  The packet's channels in the receiver's channel order.
   type Channel_Map is array (RC_Index) of RC_Index;
   Channel_Of : constant Channel_Map := (2, 3, 1, 0, 4, 5, 6, 7, 8, 9, 10);

   type Flag_List is array (Natural range <>) of Unsigned_8;
   Switch_Flags : constant Flag_List (4 .. 7) := (16#10#, 16#04#, 16#01#, 16#02#);
   Mode_Flags   : constant Flag_List (8 .. 10) := (16#02#, 16#08#, 16#20#);

   procedure Switch_Channel (S : in out State; O : in out Radio.Output) is
   begin
      Write_Reg (O, RF_CH, S.Channels (S.Channel_Index));
      S.Channel_Index := (if S.Channel_Index = Hop_Index'Last then 0 else S.Channel_Index + 1);
   end Switch_Channel;

   procedure Set_Tx_Id (S : in out State; P : Packet) is
      Sum       : constant Unsigned_8 := P (7) + P (8) + P (9);
      Row       : constant Natural := Natural (Sum and 16#03#);
      Increment : constant Unsigned_8 := Interfaces.Shift_Right (Sum and 16#1E#, 2);
   begin
      S.Tx_Id := (P (7), P (8), P (9));
      for I in Hop_Index loop
         declare
            Value : constant Unsigned_8 := Hopping (Row) (I) + Increment;
         begin
            S.Channels (I) := (if (Value and 16#0F#) /= 0 then Value else Value - 3);
         end;
      end loop;
   end Set_Tx_Id;

   --  A byte scaled onto 1000 .. 2000 in integer arithmetic, as C promotes it.
   function Scaled (A : Unsigned_8) return Unsigned_16 is (Unsigned_16 (Natural (A) * 1000 / 255 + 1000));

   function Stick (A : Unsigned_8) return Unsigned_16 is (Scaled (if A < 16#80# then 16#7F# - A else A));

   procedure Decode (S : in out State; P : Packet; Now_Us : Unsigned_32; RC : in out RC_Channels; R : out Result) is
   begin
      if S.Phase /= Bound then
         if (P (14) and Bind_Flags) = Bind_Flags then
            Set_Tx_Id (S, P);
            S.Phase := Bound;
            S.Rx_Timeout_Us := Bind_Timeout_Us;
         end if;
         R := Bind;
         return;
      end if;
      if (P (14) and Bind_Flags) = Bind_Flags then
         R := Bind;
         return;
      end if;
      if P (7) /= S.Tx_Id (0) or else P (8) /= S.Tx_Id (1) or else P (9) /= S.Tx_Id (2) then
         R := None;
         return;
      end if;
      S.Rx_Timeout_Us := Data_Timeout_Us;
      RC (Channel_Of (0)) := Scaled (P (0));
      for I in 1 .. 3 loop
         RC (Channel_Of (I)) := Stick (P (I));
      end loop;
      for I in Switch_Flags'Range loop
         RC (Channel_Of (I)) := (if (P (14) and Switch_Flags (I)) /= 0 then PWM_Max else PWM_Min);
      end loop;
      for I in Mode_Flags'Range loop
         RC (Channel_Of (I)) := (if (P (10) and Mode_Flags (I)) /= 0 then PWM_Max else PWM_Min);
      end loop;
      S.Packet_Timer_Us := Now_Us;
      R := Data;
   end Decode;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Rate : Data_Rate; Now_Us : Unsigned_32; O : out Radio.Output) is
      Address : constant Radio.Byte_Array (0 .. 4) := (16#66#, 16#88#, 16#68#, 16#68#, 16#68#);
   begin
      S := (others => <>);
      O := (others => <>);
      Initialize (S.Radio, O, CONFIG_EN_CRC or CONFIG_CRCO, Now_Us);
      Write_Reg (O, EN_AA, 16#00#);
      Write_Reg (O, EN_RXADDR, 16#01#);
      Write_Reg (O, SETUP_AW, 16#03#);
      Write_Reg (O, SETUP_RETR, 16#FF#);
      Write_Reg (O, RF_SETUP, (if Rate = Rate_250K then RF_DR_250K else RF_DR_1M) or RF_PWR_N12);
      Write_Reg (O, STATUS, STATUS_RX_DR or STATUS_TX_DS or STATUS_MAX_RT);
      Write_Reg (O, RX_PW_P0, Payload_Size);
      Write_Reg (O, FIFO_STATUS, 16#00#);
      Write_Register_Multi (O, RX_ADDR_P0, Address);
      Write_Register_Multi (O, TX_ADDR, Address);
      Flush_Tx (O);
      Flush_Rx (O);
      S.Channel_Index := 0;
      S.Phase := Not_Bound;
      S.Packet_Timer_Us := Now_Us;
      S.Channels := Hopping (0);
      S.Rx_Timeout_Us := Bind_Timeout_Us;
      Switch_Channel (S, O);
      Set_Rx_Mode (S.Radio, O);
   end Init;

   -------------------
   -- Data_Received --
   -------------------

   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Status_Value : Unsigned_8; Payload : Packet;
                            RC : in out RC_Channels; O : out Radio.Output; R : out Result)
   is
   begin
      O := (others => <>);
      if (Status_Value and STATUS_RX_DR) = 0 then
         if Now_Us - S.Packet_Timer_Us > S.Rx_Timeout_Us then
            Switch_Channel (S, O);
            S.Packet_Timer_Us := Now_Us;
         end if;
         R := None;
         return;
      end if;
      S.Packet_Timer_Us := Now_Us;
      Write_Reg (O, STATUS, STATUS_RX_DR);
      Read_Payload (O, Payload_Size);
      Flush_Rx (O);
      Switch_Channel (S, O);
      Decode (S, Payload, Now_Us, RC, R);
   end Data_Received;

end Adaflight.V202;
