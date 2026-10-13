package body Adaflight.SYMA with SPARK_Mode is
   use Adaflight.NRF24L01;
   use type Interfaces.Unsigned_8;
   package Radio renames Adaflight.SPI_Radio;

   Hop_Timeout_Us : constant := 10_000;
   PWM_Min        : constant := 1_000;
   PWM_Mid        : constant := 1_500;
   PWM_Max        : constant := 2_000;

   X5C_Address  : constant Address := (16#6D#, 16#6A#, 16#73#, 16#73#, 16#73#);
   X5C_Channels : constant Hop_Table :=
     (16#1D#, 16#2F#, 16#26#, 16#3D#, 16#15#, 16#2B#, 16#25#, 16#24#,
      16#27#, 16#2C#, 16#1C#, 16#3E#, 16#39#, 16#2D#, 16#22#, 0);

   function Radio_Bytes (A : Address) return Radio.Byte_Array is
     (A (0), A (1), A (2), A (3), A (4));

   --  Whether a packet binds; an X bind packet also gives the address.
   procedure Check_Bind (S : in out State; P : Payload_Buffer; Bound : out Boolean) is
   begin
      if S.Kind = X then
         Bound := P (5) = 16#AA# and then P (6) = 16#AA# and then P (7) = 16#AA#;
         if Bound then
            S.Rx_Tx_Address := (P (4), P (3), P (2), P (1), P (0));
         end if;
      else
         Bound := P (0) = 0 and then P (1) = 0 and then P (14) = 16#C0# and then P (15) = 16#17#;
      end if;
   end Check_Bind;

   procedure Hop (S : in out State; O : in out Radio.Output) is
   begin
      S.Packet_Count := S.Packet_Count + 1;
      if (S.Packet_Count and 1) = 0 then
         S.Channel_Index := (if S.Channel_Index + 1 >= S.Channel_Count then 0 else S.Channel_Index + 1);
      end if;
      Set_Channel (O, S.Channels (S.Channel_Index));
   end Hop;

   --  The X's four channels from its address, written as one 32-bit word
   --  stored low byte first.
   procedure Set_X_Hopping (S : in out State; First : Unsigned_8) is
      A    : Unsigned_32 := Unsigned_32 (First and 16#1F#);
      Word : Unsigned_32;
   begin
      if A = 16#06# then
         A := 16#07#;
      end if;
      declare
         Inc : constant Unsigned_32 := A * 16#0101_0101#;
      begin
         Word := (if A = 16#16# then 16#2848_1131#
                  elsif A = 16#1E# then 16#3818_4121#
                  elsif A < 16#10# then 16#3A2A_1A0A# + Inc
                  elsif A < 16#18# then 16#1231_FA1A# + Inc
                  else 16#19FA_2202# + Inc);
      end;
      for I in 0 .. 3 loop
         S.Channels (I) := Unsigned_8 (Interfaces.Shift_Right (Word, 8 * I) and 16#FF#);
      end loop;
   end Set_X_Hopping;

   function Unsigned_Pulse (V : Unsigned_8) return Unsigned_16 is (Unsigned_16 (Natural (V) * 1000 / 255 + PWM_Min));

   function Signed_Pulse (V : Unsigned_8) return Unsigned_16 is
     (Unsigned_16 (PWM_Mid + (if (V and 16#80#) /= 0 then -1 else 1) * (Natural (V and 16#7F#) * 1000 / 254)));

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Kind : Variant; Now_Us : Unsigned_32; O : out Radio.Output) is
   begin
      S := (others => <>);
      O := (others => <>);
      S.Kind := Kind;
      Initialize (S.Radio, O, CONFIG_EN_CRC or CONFIG_CRCO, Now_Us);
      Setup_Basic (O);
      if Kind = X then
         S.Payload_Size := 10;
         Write_Reg (O, RF_SETUP, RF_DR_250K or RF_PWR_N12);
         S.Phase := Bind;
         Write_Register_Multi (O, RX_ADDR_P0, Radio_Bytes (S.Rx_Tx_Address));
      else
         S.Payload_Size := 16;
         Write_Reg (O, RF_SETUP, RF_DR_1M or RF_PWR_N12);
         Write_Register_Multi (O, RX_ADDR_P0, Radio_Bytes (X5C_Address));
         S.Phase := Data;
         S.Channel_Count := 15;
         for I in 0 .. 14 loop
            S.Channels (I) := X5C_Channels (I);
         end loop;
      end if;
      Set_Channel (O, S.Channels (0));
      Write_Reg (O, RX_PW_P0, S.Payload_Size);
      Set_Rx_Mode (S.Radio, O);
   end Init;

   -------------------
   -- Data_Received --
   -------------------

   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : Payload_Buffer; O : out Radio.Output; R : out Result)
   is
      Available : Boolean;
      Bound     : Boolean := False;
   begin
      O := (others => <>);
      R := None;
      case S.Phase is
         when Bind =>
            Read_Payload_If_Available (O, Fifo_Status, S.Payload_Size, Available);
            if Available then
               Check_Bind (S, Buffer, Bound);
            end if;
            if Available and then Bound then
               R := Bind_Received;
               S.Phase := Data;
               Set_X_Hopping (S, S.Rx_Tx_Address (0));
               Write_Register_Multi (O, RX_ADDR_P0, Radio_Bytes (S.Rx_Tx_Address));
               S.Packet_Count := 0;
               S.Channel_Index := 0;
               Set_Channel (O, S.Channels (0));
            end if;
         when Data =>
            Read_Payload_If_Available (O, Fifo_Status, S.Payload_Size, Available);
            if Available then
               Hop (S, O);
               S.Time_Of_Last_Hop := Now_Us;
               R := Data_Received_Result;
            end if;
            if Now_Us > S.Time_Of_Last_Hop + Hop_Timeout_Us then
               Hop (S, O);
               S.Time_Of_Last_Hop := Now_Us;
            end if;
      end case;
   end Data_Received;

   -----------------
   -- Set_RC_Data --
   -----------------

   procedure Set_RC_Data (S : State; Buffer : Payload_Buffer; RC : in out RC_Channels) is
      function Switch (On : Boolean) return Unsigned_16 is (if On then PWM_Max else PWM_Min);
   begin
      RC (2) := Unsigned_Pulse (Buffer (0));
      RC (0) := Signed_Pulse (Buffer (3));
      if S.Kind = X then
         RC (1) := Signed_Pulse (Buffer (1));
         RC (3) := Signed_Pulse (Buffer (2));
         RC (4) := (case Interfaces.Shift_Right (Buffer (5) and 16#C0#, 6) is
                       when 0 => PWM_Min, when 1 => PWM_Mid, when others => PWM_Max);
         RC (5) := Switch ((Buffer (6) and 16#40#) /= 0);
         RC (6) := Switch ((Buffer (4) and 16#40#) /= 0);
         RC (7) := Switch ((Buffer (4) and 16#80#) /= 0);
         RC (8) := Switch ((Buffer (14) and 16#80#) /= 0);
      else
         RC (1) := Signed_Pulse (Buffer (2));
         RC (3) := Signed_Pulse (Buffer (1));
         RC (4) := Switch ((Buffer (14) and 16#04#) /= 0);
         RC (5) := Switch ((Buffer (14) and 16#01#) /= 0);
         RC (6) := Switch ((Buffer (14) and 16#08#) /= 0);
         RC (7) := Switch ((Buffer (14) and 16#10#) /= 0);
      end if;
   end Set_RC_Data;

end Adaflight.SYMA;
