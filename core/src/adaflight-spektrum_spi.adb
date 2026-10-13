package body Adaflight.Spektrum_SPI with SPARK_Mode is
   use Adaflight.SPI_Radio;

   W_CHANNEL         : constant := 16#80#;
   W_TX_LENGTH       : constant := 16#81#;
   W_TX_CTRL         : constant := 16#82#;
   W_TX_CFG          : constant := 16#83#;
   W_RX_CTRL         : constant := 16#85#;
   W_RX_CFG          : constant := 16#86#;
   W_RX_IRQ_STATUS   : constant := 16#87#;
   W_XACT_CFG        : constant := 16#8F#;
   W_FRAMING_CFG     : constant := 16#90#;
   W_DATA64_THOLD    : constant := 16#92#;
   W_EOP_CTRL        : constant := 16#94#;
   W_CRC_SEED_LSB    : constant := 16#95#;
   W_CRC_SEED_MSB    : constant := 16#96#;
   W_TX_OFFSET_LSB   : constant := 16#9B#;
   W_TX_OFFSET_MSB   : constant := 16#9C#;
   W_MODE_OVERRIDE   : constant := 16#9D#;
   W_RX_OVERRIDE     : constant := 16#9E#;
   W_TX_OVERRIDE     : constant := 16#9F#;
   W_TX_BUFFER       : constant := 16#A0#;
   W_SOP_CODE        : constant := 16#A2#;
   W_DATA_CODE       : constant := 16#A3#;
   W_CLK_EN          : constant := 16#A8#;
   W_RX_ABORT        : constant := 16#A9#;
   W_AUTO_CAL_TIME   : constant := 16#B2#;
   W_AUTO_CAL_OFFSET : constant := 16#B5#;
   XACT_CFG          : constant := 16#0F#;

   RXE_IRQ : constant := 16#01#;
   RXC_IRQ : constant := 16#02#;
   BAD_CRC : constant := 16#08#;

   Bind_Timeout_Us      : constant := 11_000;
   Sync_Timeout_Us      : constant := 20_000;
   Long_Timeout_Us      : constant := 18_500;
   Mid_Timeout_Us       : constant := 7_500;
   Short_Timeout_Us     : constant := 4_500;
   Telemetry_Timeout_Us : constant := 1_500;
   Telemetry_Period_Us  : constant := 176_000;
   Max_Bind_Packets     : constant := 500;
   Max_Missed_Packets   : constant := 31;
   Max_Rf_Channel       : constant := 16#4F#;
   Initial_Bind_Channel : constant := 16#0D#;

   Radio_Config : constant Register_List :=
     ((W_CLK_EN, 16#02#), (W_AUTO_CAL_TIME, 16#3C#), (W_AUTO_CAL_OFFSET, 16#14#), (W_RX_CFG, 16#48#),
      (W_TX_OFFSET_LSB, 16#55#), (W_TX_OFFSET_MSB, 16#05#), (W_XACT_CFG, 16#2C#), (W_TX_CFG, 16#3F#),
      (W_DATA64_THOLD, 16#0E#));

   Bind_Config : constant Register_List :=
     ((W_TX_CFG, 16#3F#), (W_FRAMING_CFG, 16#4E#), (W_RX_OVERRIDE, 16#14#), (W_EOP_CTRL, 16#02#),
      (W_TX_OVERRIDE, 16#04#));

   Transfer_Config : constant Register_List :=
     ((W_TX_CFG, 16#2F#), (W_FRAMING_CFG, 16#EE#), (W_TX_OVERRIDE, 16#00#), (W_RX_OVERRIDE, 16#00#));

   type PN_Code is array (0 .. 7) of Unsigned_8;
   type PN_Table is array (0 .. 4, 0 .. 8) of PN_Code;

   PN_Codes : constant PN_Table :=
     (((16#03#, 16#BC#, 16#6E#, 16#8A#, 16#EF#, 16#BD#, 16#FE#, 16#F8#),
        (16#88#, 16#17#, 16#13#, 16#3B#, 16#2D#, 16#BF#, 16#06#, 16#D6#),
        (16#F1#, 16#94#, 16#30#, 16#21#, 16#A1#, 16#1C#, 16#88#, 16#A9#),
        (16#D0#, 16#D2#, 16#8E#, 16#BC#, 16#82#, 16#2F#, 16#E3#, 16#B4#),
        (16#8C#, 16#FA#, 16#47#, 16#9B#, 16#83#, 16#A5#, 16#66#, 16#D0#),
        (16#07#, 16#BD#, 16#9F#, 16#26#, 16#C8#, 16#31#, 16#0F#, 16#B8#),
        (16#EF#, 16#03#, 16#95#, 16#89#, 16#B4#, 16#71#, 16#61#, 16#9D#),
        (16#40#, 16#BA#, 16#97#, 16#D5#, 16#86#, 16#4F#, 16#CC#, 16#D1#),
        (16#D7#, 16#A1#, 16#54#, 16#B1#, 16#5E#, 16#89#, 16#AE#, 16#86#)),
      ((16#83#, 16#F7#, 16#A8#, 16#2D#, 16#7A#, 16#44#, 16#64#, 16#D3#),
        (16#3F#, 16#2C#, 16#4E#, 16#AA#, 16#71#, 16#48#, 16#7A#, 16#C9#),
        (16#17#, 16#FF#, 16#9E#, 16#21#, 16#36#, 16#90#, 16#C7#, 16#82#),
        (16#BC#, 16#5D#, 16#9A#, 16#5B#, 16#EE#, 16#7F#, 16#42#, 16#EB#),
        (16#24#, 16#F5#, 16#DD#, 16#F8#, 16#7A#, 16#77#, 16#74#, 16#E7#),
        (16#3D#, 16#70#, 16#7C#, 16#94#, 16#DC#, 16#84#, 16#AD#, 16#95#),
        (16#1E#, 16#6A#, 16#F0#, 16#37#, 16#52#, 16#7B#, 16#11#, 16#D4#),
        (16#62#, 16#F5#, 16#2B#, 16#AA#, 16#FC#, 16#33#, 16#BF#, 16#AF#),
        (16#40#, 16#56#, 16#32#, 16#D9#, 16#0F#, 16#D9#, 16#5D#, 16#97#)),
      ((16#40#, 16#56#, 16#32#, 16#D9#, 16#0F#, 16#D9#, 16#5D#, 16#97#),
        (16#8E#, 16#4A#, 16#D0#, 16#A9#, 16#A7#, 16#FF#, 16#20#, 16#CA#),
        (16#4C#, 16#97#, 16#9D#, 16#BF#, 16#B8#, 16#3D#, 16#B5#, 16#BE#),
        (16#0C#, 16#5D#, 16#24#, 16#30#, 16#9F#, 16#CA#, 16#6D#, 16#BD#),
        (16#50#, 16#14#, 16#33#, 16#DE#, 16#F1#, 16#78#, 16#95#, 16#AD#),
        (16#0C#, 16#3C#, 16#FA#, 16#F9#, 16#F0#, 16#F2#, 16#10#, 16#C9#),
        (16#F4#, 16#DA#, 16#06#, 16#DB#, 16#BF#, 16#4E#, 16#6F#, 16#B3#),
        (16#9E#, 16#08#, 16#D1#, 16#AE#, 16#59#, 16#5E#, 16#E8#, 16#F0#),
        (16#C0#, 16#90#, 16#8F#, 16#BB#, 16#7C#, 16#8E#, 16#2B#, 16#8E#)),
      ((16#C0#, 16#90#, 16#8F#, 16#BB#, 16#7C#, 16#8E#, 16#2B#, 16#8E#),
        (16#80#, 16#69#, 16#26#, 16#80#, 16#08#, 16#F8#, 16#49#, 16#E7#),
        (16#7D#, 16#2D#, 16#49#, 16#54#, 16#D0#, 16#80#, 16#40#, 16#C1#),
        (16#B6#, 16#F2#, 16#E6#, 16#1B#, 16#80#, 16#5A#, 16#36#, 16#B4#),
        (16#42#, 16#AE#, 16#9C#, 16#1C#, 16#DA#, 16#67#, 16#05#, 16#F6#),
        (16#9B#, 16#75#, 16#F7#, 16#E0#, 16#14#, 16#8D#, 16#B5#, 16#80#),
        (16#BF#, 16#54#, 16#98#, 16#B9#, 16#B7#, 16#30#, 16#5A#, 16#88#),
        (16#35#, 16#D1#, 16#FC#, 16#97#, 16#23#, 16#D4#, 16#C9#, 16#88#),
        (16#E1#, 16#D6#, 16#31#, 16#26#, 16#5F#, 16#BD#, 16#40#, 16#93#)),
      ((16#E1#, 16#D6#, 16#31#, 16#26#, 16#5F#, 16#BD#, 16#40#, 16#93#),
        (16#DC#, 16#68#, 16#08#, 16#99#, 16#97#, 16#AE#, 16#AF#, 16#8C#),
        (16#C3#, 16#0E#, 16#01#, 16#16#, 16#0E#, 16#32#, 16#06#, 16#BA#),
        (16#E0#, 16#83#, 16#01#, 16#FA#, 16#AB#, 16#3E#, 16#8F#, 16#AC#),
        (16#5C#, 16#D5#, 16#9C#, 16#B8#, 16#46#, 16#9C#, 16#7D#, 16#84#),
        (16#F1#, 16#C6#, 16#FE#, 16#5C#, 16#9D#, 16#A5#, 16#4F#, 16#B7#),
        (16#58#, 16#B5#, 16#B3#, 16#DD#, 16#0E#, 16#28#, 16#F1#, 16#B0#),
        (16#5F#, 16#30#, 16#3B#, 16#56#, 16#96#, 16#45#, 16#F4#, 16#A1#),
        (16#03#, 16#BC#, 16#6E#, 16#8A#, 16#EF#, 16#BD#, 16#FE#, 16#F8#)));

   Bind_Data_Code : constant Byte_Array (0 .. 15) :=
     (16#98#, 16#88#, 16#1B#, 16#E4#, 16#30#, 16#79#, 16#03#, 16#84#, 16#98#, 16#88#, 16#1B#, 16#E4#, 16#30#, 16#79#,
      16#03#, 16#84#);

   function Is_DSM2 (Protocol : Unsigned_8) return Boolean is (Protocol in 16#01# | 16#02# | 16#03# | 16#12#);

   function Mfg_Seed (S : State) return Unsigned_16 is
     (Unsigned_16 (S.Mfg_Id (0)) * 256 + Unsigned_16 (S.Mfg_Id (1)));

   function Receive_Timeout (S : State) return Unsigned_32 is
     (if S.Num_Channels < 8 then Long_Timeout_Us else Mid_Timeout_Us);

   function Code_Bytes (Code : PN_Code) return Byte_Array is
     (Byte_Array'(Code (0), Code (1), Code (2), Code (3), Code (4), Code (5), Code (6), Code (7)));

   procedure Start_Recv (O : in out Output)
     with Global => null
   is
   begin
      Write (O, W_RX_IRQ_STATUS, 16#80#);
      Write (O, W_RX_CTRL, 16#83#);
   end Start_Recv;

   procedure Set_Channel (S : State; O : in out Output)
     with Global => null
   is
      Row : constant Natural :=
        (if Is_DSM2 (S.Protocol) then Natural (S.Rf_Channel) mod 5 else (Integer (S.Rf_Channel) - 2) mod 5);
   begin
      Write (O, W_CRC_SEED_LSB, Unsigned_8 (S.Crc_Seed mod 256));
      Write (O, W_CRC_SEED_MSB, Unsigned_8 (S.Crc_Seed / 256));
      Write_Block (O, W_SOP_CODE, Code_Bytes (PN_Codes (Row, S.Sop_Col)));
      Write_Block
        (O, W_DATA_CODE, Code_Bytes (PN_Codes (Row, S.Data_Col)) & Code_Bytes (PN_Codes (Row, S.Data_Col + 1)));
      Write (O, W_CHANNEL, S.Rf_Channel);
   end Set_Channel;

   procedure Next_Sync_Channel (S : in out State; O : in out Output)
     with Global => null
   is
   begin
      S.Crc_Seed := not S.Crc_Seed;
      S.Rf_Channel := Unsigned_8 ((Natural (S.Rf_Channel) + 1) mod Max_Rf_Channel);
      Set_Channel (S, O);
   end Next_Sync_Channel;

   procedure Next_Channel (S : in out State; O : in out Output)
     with Global => null
   is
   begin
      S.Rf_Channel_Idx :=
        (if Is_DSM2 (S.Protocol) then (S.Rf_Channel_Idx + 1) mod 2 else (S.Rf_Channel_Idx + 1) mod 23);
      S.Crc_Seed := not S.Crc_Seed;
      S.Rf_Channel := S.Rf_Channels (S.Rf_Channel_Idx);
      Set_Channel (S, O);
   end Next_Channel;

   procedure Reset_Receive_Timeout (S : in out State; Time_Us : Unsigned_32)
     with Global => null
   is
   begin
      S.Last_Packet_Us := Time_Us;
      S.Timeout_Us := (if S.Crc_Seed = Mfg_Seed (S) then Short_Timeout_Us else Receive_Timeout (S));
   end Reset_Receive_Timeout;

   procedure Generate_DSMX_Channels (S : in out State)
     with Global => null
   is
      Id : constant Unsigned_32 :=
        not (Unsigned_32 (S.Mfg_Id (0)) * 2 ** 24 + Unsigned_32 (S.Mfg_Id (1)) * 2 ** 16
             + Unsigned_32 (S.Mfg_Id (2)) * 2 ** 8 + Unsigned_32 (S.Mfg_Id (3)));
      Seed : Unsigned_32 := Id;
      Idx  : Natural range 0 .. 23 := 0;
   begin
      while Idx < 23 loop
         Seed := Seed * 16#0019_660D# + 16#3C6E_F35F#;
         declare
            Next : constant Unsigned_8 := Unsigned_8 ((Seed / 256) mod 16#49#) + 3;
            I    : Natural range 0 .. 22 := 0;
            Low, Middle, High : Natural range 0 .. 23 := 0;
            Seen : Boolean := False;
         begin
            if ((Unsigned_32 (Next) xor Id) and 1) /= 0 then
               while I < Idx loop
                  pragma Loop_Invariant (Low + Middle + High = I and then I < Idx);
                  if S.Rf_Channels (I) = Next then
                     Seen := True;
                     exit;
                  end if;
                  if S.Rf_Channels (I) <= 27 then
                     Low := Low + 1;
                  elsif S.Rf_Channels (I) <= 51 then
                     Middle := Middle + 1;
                  else
                     High := High + 1;
                  end if;
                  exit when I = Idx - 1;
                  I := I + 1;
               end loop;
               if not Seen
                 and then ((Next < 28 and then Low < 8) or else (Next in 28 .. 51 and then Middle < 7)
                           or else (Next >= 52 and then High < 8))
               then
                  S.Rf_Channels (Idx) := Next;
                  Idx := Idx + 1;
               end if;
            end if;
         end;
      end loop;
   end Generate_DSMX_Channels;

   procedure Start_Bind (S : in out State; Now_Us : Unsigned_32; O : in out Output)
     with Global => null
   is
   begin
      S.Status := Bind;
      Write_All (O, Bind_Config);
      Write_Block (O, W_DATA_CODE, Code_Bytes (PN_Codes (0, 8)) & Code_Bytes (PN_Codes (0, 8)));
      S.Rf_Channel := Initial_Bind_Channel;
      Write (O, W_CHANNEL, S.Rf_Channel);
      S.Last_Packet_Us := Now_Us;
      S.Timeout_Us := Bind_Timeout_Us;
      Start_Recv (O);
   end Start_Bind;

   procedure Start_Transfer (S : in out State; C : Settings; Now_Us : Unsigned_32; O : in out Output)
     with Global => null
   is
   begin
      S.Status := Sync_A;
      S.Rf_Channel_Idx := 0;
      S.Missed_Packets := 0;
      Write_All (O, Transfer_Config);
      S.Num_Channels := C.Num_Channels;
      S.Protocol := C.Protocol;
      S.Crc_Seed := not Mfg_Seed (S);
      S.Sop_Col := Natural ((Natural (S.Mfg_Id (0)) + Natural (S.Mfg_Id (1)) + Natural (S.Mfg_Id (2)) + 2) mod 8);
      S.Data_Col := 7 - S.Sop_Col;
      if Is_DSM2 (S.Protocol) then
         S.Rf_Channels := (others => 0);
         Next_Sync_Channel (S, O);
      else
         Generate_DSMX_Channels (S);
         S.Rf_Channel_Idx := 22;
         Next_Channel (S, O);
      end if;
      S.Last_Packet_Us := Now_Us;
      S.Timeout_Us := Sync_Timeout_Us * 4;
      Start_Recv (O);
   end Start_Transfer;

   procedure Send_Packet (O : in out Output; Packet : Byte_Array)
     with Global => null, Pre => Packet'Length <= 16
   is
   begin
      Write (O, W_XACT_CFG, 16#24#);
      Write (O, W_TX_LENGTH, Unsigned_8 (Packet'Length));
      Write (O, W_TX_CTRL, 16#40#);
      Write_Block (O, W_TX_BUFFER, Packet);
      Write (O, W_TX_CTRL, 16#80#);
   end Send_Packet;

   procedure Send_Bind_Packet (S : State; O : in out Output)
     with Global => null
   is
      P   : Byte_Array (0 .. 9) :=
        (not S.Mfg_Id (0), not S.Mfg_Id (1), not S.Mfg_Id (2), not S.Mfg_Id (3), 16#01#, S.Num_Channels, S.Protocol,
         16#00#, 0, 0);
      Sum : Unsigned_16 := 384 - 16#10#;
   begin
      for I in 0 .. 7 loop
         Sum := Sum + Unsigned_16 (P (I));
      end loop;
      P (8) := Unsigned_8 (Sum / 256);
      P (9) := Unsigned_8 (Sum mod 256);
      Send_Packet (O, P);
   end Send_Bind_Packet;

   procedure Send_Telemetry_Packet (Inp : Inputs; O : in out Output)
     with Global => null
   is
      P : constant Byte_Array (0 .. 8) :=
        (16#7E#, 16#FF#, 16#FF#, 16#FF#, Unsigned_8 (Inp.Battery_Voltage / 256),
         Unsigned_8 (Inp.Battery_Voltage mod 256), 16#7F#, 16#FF#, Inp.RSSI_Percent);
   begin
      Send_Packet (O, P);
   end Send_Telemetry_Packet;

   function Mfg_Matches (S : State; P : Packet_Bytes) return Boolean is
     (if Is_DSM2 (S.Protocol) then P (0) = not S.Mfg_Id (2) and then P (1) = not S.Mfg_Id (3)
      else P (0) = S.Mfg_Id (2) and then P (1) = S.Mfg_Id (3));

   procedure Valid_Packet (S : in out State; Inp : Inputs; P : Packet_Bytes; Valid : out Boolean)
     with Global => null
   is
   begin
      Valid := False;
      if S.Is_Error then
         if S.Status /= Receive and then (Inp.Rx_Status and BAD_CRC) /= 0 then
            S.Crc_Seed := not S.Crc_Seed;
         else
            return;
         end if;
      end if;
      Valid := Mfg_Matches (S, P);
   end Valid_Packet;

   procedure Bind_Packet (S : in out State; C : in out Settings; P : Packet_Bytes; Time_Us : Unsigned_32;
                          O : in out Output; Result : in out Received)
     with Global => null
   is
      Sum : Unsigned_16 := 384 - 16#10#;
   begin
      if P (0) /= P (4) or else P (1) /= P (5) or else P (2) /= P (6) or else P (3) /= P (7) then
         S.Last_Packet_Us := Time_Us;
         S.Timeout_Us := Bind_Timeout_Us;
         return;
      end if;
      for I in 0 .. 7 loop
         Sum := Sum + Unsigned_16 (P (I));
      end loop;
      if Unsigned_16 (P (8)) /= Sum / 256 or else Unsigned_16 (P (9)) /= Sum mod 256 then
         return;
      end if;
      for I in 8 .. 13 loop
         Sum := Sum + Unsigned_16 (P (I));
      end loop;
      if Unsigned_16 (P (14)) /= Sum / 256 or else Unsigned_16 (P (15)) /= Sum mod 256 then
         return;
      end if;
      S.Mfg_Id := (not P (0), not P (1), not P (2), not P (3));
      S.Num_Channels := P (11);
      S.Protocol := P (12);
      C.Mfg_Id := S.Mfg_Id;
      C.Num_Channels := S.Num_Channels;
      C.Protocol := S.Protocol;
      Add (O, (Kind => Save_Config, others => <>));
      Write_Block (O, W_DATA_CODE, Bind_Data_Code);
      S.Bind_Packets := 0;
      S.Status := Bind_2;
      S.Last_Packet_Us := Time_Us;
      S.Timeout_Us := Bind_Timeout_Us;
      S.Bound := True;
      Result := Bind_Done;
   end Bind_Packet;

   procedure Read_Packet
     (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Time_Us : Unsigned_32;
      Result : in out Received)
     with Global => null
   is
      Count : constant Natural := Natural (Unsigned_8'Min (Inp.Rx_Count, Packet_Size));
      P     : Packet_Bytes := (others => 0);
      Valid : Boolean;
   begin
      for K in 0 .. Count - 1 loop
         P (K) := Inp.Fifo (K);
      end loop;
      Add (O, (Kind => Read_Fifo, A => Unsigned_8 (Count), others => <>));
      Write (O, W_XACT_CFG, 16#2C#);
      Write (O, W_RX_ABORT, 16#00#);
      if Count < 2 then
         return;
      end if;
      case S.Status is
         when Bind =>
            Bind_Packet (S, C, P, Time_Us, O, Result);
         when Sync_A =>
            Valid_Packet (S, Inp, P, Valid);
            if Valid then
               if Is_DSM2 (S.Protocol) then
                  S.Rf_Channels (0) := S.Rf_Channel;
                  S.Rf_Channels (1) := S.Rf_Channel;
                  S.Status := Sync_B;
                  Next_Sync_Channel (S, O);
               else
                  S.Status := Receive;
                  S.Missed_Packets := 0;
                  Next_Channel (S, O);
               end if;
               Reset_Receive_Timeout (S, Time_Us);
               Start_Recv (O);
               Result := Data_Ready;
            end if;
         when Sync_B =>
            Valid_Packet (S, Inp, P, Valid);
            if Valid then
               if S.Crc_Seed /= Mfg_Seed (S) then
                  S.Rf_Channels (0) := S.Rf_Channel;
               else
                  S.Rf_Channels (1) := S.Rf_Channel;
               end if;
               if S.Rf_Channels (0) /= S.Rf_Channels (1) then
                  S.Status := Receive;
                  S.Missed_Packets := 0;
                  Next_Channel (S, O);
                  Reset_Receive_Timeout (S, Time_Us);
                  Start_Recv (O);
               end if;
               Result := Data_Ready;
            end if;
         when Receive =>
            Valid_Packet (S, Inp, P, Valid);
            if Valid then
               Add (O, (Kind  => Set_RSSI,
                        Value => 403 + Unsigned_16 (Inp.RSSI_Register and 16#1F#) * 20,
                        others => <>));
               S.Missed_Packets := 0;
               for K in Payload_Bytes'Range loop
                  S.Payload (K) := P (2 + K);
               end loop;
               if S.Send_Telemetry and then S.Crc_Seed = Mfg_Seed (S) then
                  Send_Telemetry_Packet (Inp, O);
                  S.Send_Telemetry := False;
                  S.Last_Packet_Us := Time_Us;
                  S.Timeout_Us := Telemetry_Timeout_Us;
                  S.Status := Telemetry;
               else
                  Next_Channel (S, O);
                  Reset_Receive_Timeout (S, Time_Us);
                  Start_Recv (O);
               end if;
               Result := Data_Ready;
            end if;
         when Bind_2 | Telemetry =>
            null;
      end case;
   end Read_Packet;

   procedure Check_Timeout (S : in out State; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Now : constant Unsigned_32 := Inp.Now_Us;
   begin
      if C.Telemetry and then Now - S.Last_Telemetry_Us > Telemetry_Period_Us then
         S.Last_Telemetry_Us := Now;
         S.Send_Telemetry := True;
      end if;
      if Now - S.Last_Packet_Us <= S.Timeout_Us then
         return;
      end if;
      Write (O, W_XACT_CFG, 16#2C#);
      Write (O, W_RX_ABORT, 16#00#);
      S.Last_Packet_Us := S.Last_Packet_Us + S.Timeout_Us;
      case S.Status is
         when Bind =>
            S.Rf_Channel := Unsigned_8 ((Natural (S.Rf_Channel) + 2) mod Max_Rf_Channel);
            Write (O, W_CHANNEL, S.Rf_Channel);
            S.Timeout_Us := Bind_Timeout_Us;
            Start_Recv (O);
         when Bind_2 =>
            declare
               Sent : constant Unsigned_16 := S.Bind_Packets;
            begin
               S.Bind_Packets := Sent + 1;
               if Sent > Max_Bind_Packets then
                  Start_Transfer (S, C, Now, O);
               else
                  S.Timeout_Us := Bind_Timeout_Us;
                  Send_Bind_Packet (S, O);
               end if;
            end;
         when Sync_A | Sync_B =>
            if Is_DSM2 (S.Protocol) then
               Next_Sync_Channel (S, O);
            else
               Next_Channel (S, O);
            end if;
            S.Timeout_Us := Sync_Timeout_Us;
            Start_Recv (O);
         when Receive =>
            S.Missed_Packets := S.Missed_Packets + 1;
            if S.Missed_Packets < Max_Missed_Packets then
               Next_Channel (S, O);
               S.Timeout_Us := (if S.Crc_Seed = Mfg_Seed (S) then Short_Timeout_Us else Receive_Timeout (S));
               Start_Recv (O);
            else
               Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
               S.Status := Sync_A;
               S.Timeout_Us := Sync_Timeout_Us;
            end if;
         when Telemetry =>
            Next_Channel (S, O);
            S.Status := Receive;
            S.Timeout_Us := Receive_Timeout (S) - Telemetry_Timeout_Us;
            Start_Recv (O);
      end case;
   end Check_Timeout;

   -----------
   -- Start --
   -----------

   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean)
   is
   begin
      S := (others => <>);
      O := (others => <>);
      Start_Common (S.Radio, C.Pins, Inp.Bind_Pin_Level, O);
      Write (O, W_XACT_CFG, 16#82#);
      Add (O, (Kind => Await_Value, A => XACT_CFG, B => 16#82#, others => <>));
      Write (O, W_MODE_OVERRIDE, 16#01#);
      Ok := Inp.Chip_Ok;
      Claim_RSSI := Ok;
      if not Ok then
         return;
      end if;
      Write_All (O, Radio_Config);
      S.Last_Telemetry_Us := Inp.Now_Us + Telemetry_Period_Us;
      S.Send_Telemetry := False;
      if C.Mfg_Id /= (0, 0, 0, 0) then
         S.Bound := True;
         S.Mfg_Id := C.Mfg_Id;
         Start_Transfer (S, C, Inp.Now_Us, O);
      else
         S.Bound := False;
         Start_Bind (S, Inp.Now_Us, O);
      end if;
   end Start;

   ------------------
   -- Request_Bind --
   ------------------

   procedure Request_Bind (S : in out State) is
   begin
      S.Radio.Bind_Requested := True;
   end Request_Bind;

   -------------------
   -- Data_Received --
   -------------------

   procedure Data_Received
     (S : in out State; C : in out Settings; Inp : Inputs; O : out Output; Result : out Received)
   is
      Requested : Boolean;
      Time_Us   : Unsigned_32 := 0;
   begin
      O := (others => <>);
      Result := None;
      Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, True, Requested);
      if Requested then
         S.Bound := False;
         Start_Bind (S, Inp.Now_Us, O);
      end if;
      if Inp.Exti_Flag then
         if Inp.Exti_Time_Us /= 0 then
            Time_Us := Inp.Exti_Time_Us;
         end if;
         if (Inp.IRQ_Status and (RXC_IRQ or RXE_IRQ)) /= 0 then
            S.Is_Error := (Inp.IRQ_Status and RXE_IRQ) /= 0;
         end if;
         Add (O, (Kind => Reset_Exti, others => <>));
         Read_Packet (S, C, Inp, O, Time_Us, Result);
      end if;
      Check_Timeout (S, C, Inp, O);
      if not S.Bound then
         LED_Blink (S.Radio, C.Pins, O, Inp.Now_Ms, 250);
      elsif S.Status = Bind_2 then
         LED_Blink_Rx_Loss (S.Radio, C.Pins, O, Inp.Now_Ms, True);
      else
         LED_Blink_Rx_Loss (S.Radio, C.Pins, O, Inp.Now_Ms, Result = Data_Ready);
      end if;
   end Data_Received;

   -----------------
   -- Set_Rc_Data --
   -----------------

   procedure Set_Rc_Data (S : State; Rc : in out Channel_Values) is
      DSMX : constant Boolean := not Is_DSM2 (S.Protocol);
   begin
      for I in 0 .. 6 loop
         declare
            Word  : constant Unsigned_16 := Unsigned_16 (S.Payload (2 * I)) * 256 + Unsigned_16 (S.Payload (2 * I + 1));
            Chan  : constant Natural := Natural ((if DSMX then Word / 2 ** 11 else Word / 2 ** 10) mod 16);
            Value : constant Unsigned_16 := (if DSMX then (Word mod 2 ** 11) / 2 else Word mod 2 ** 10);
         begin
            if Chan < Natural (S.Num_Channels) then
               Rc (Chan) := 988 + Value;
            end if;
         end;
      end loop;
   end Set_Rc_Data;

end Adaflight.Spektrum_SPI;
