package body Adaflight.FlySky with SPARK_Mode is
   use Adaflight.SPI_Radio;

   STANDBY   : constant := 16#A0#;
   RX        : constant := 16#C0#;
   TX        : constant := 16#D0#;
   RST_WRPTR : constant := 16#E0#;
   RST_RDPTR : constant := 16#F0#;

   MODE             : constant := 16#00#;
   CALC             : constant := 16#02#;
   CHANNEL_REGISTER : constant := 16#0F#;
   IF_CALIB         : constant := 16#22#;
   VCO_CURCAL       : constant := 16#24#;
   VCO_SBCAL        : constant := 16#25#;

   Mode_TRER : constant := 16#01#;
   Mode_TRSR : constant := 16#02#;
   Mode_CRCF : constant := 16#20#;

   Radio_Id     : constant := 16#5475_C52A#;
   Tx_Delay_Us  : constant := 500;
   Bind_Time_Us : constant := 200_000;

   type Register_Set is array (Unsigned_8 range 0 .. 49) of Unsigned_8;

   AFHDS_Registers : constant Register_Set :=
     (16#FF#, 16#42#, 16#00#, 16#14#, 16#00#, 16#FF#, 16#FF#, 16#00#, 16#00#, 16#00#, 16#00#, 16#03#, 16#19#,
      16#05#, 16#00#, 16#50#, 16#9E#, 16#4B#, 16#00#, 16#02#, 16#16#, 16#2B#, 16#12#, 16#00#, 16#62#, 16#80#,
      16#80#, 16#00#, 16#0A#, 16#32#, 16#C3#, 16#0F#, 16#13#, 16#C3#, 16#00#, 16#FF#, 16#00#, 16#00#, 16#3B#,
      16#00#, 16#17#, 16#47#, 16#80#, 16#03#, 16#01#, 16#45#, 16#18#, 16#00#, 16#01#, 16#0F#);

   AFHDS_2A_Registers : constant Register_Set :=
     (16#FF#, 16#62#, 16#00#, 16#25#, 16#00#, 16#FF#, 16#FF#, 16#00#, 16#00#, 16#00#, 16#00#, 16#03#, 16#19#,
      16#05#, 16#00#, 16#50#, 16#9E#, 16#4B#, 16#00#, 16#02#, 16#16#, 16#2B#, 16#12#, 16#4F#, 16#62#, 16#80#,
      16#FF#, 16#FF#, 16#2A#, 16#32#, 16#C3#, 16#1F#, 16#1E#, 16#FF#, 16#00#, 16#FF#, 16#00#, 16#00#, 16#3B#,
      16#00#, 16#17#, 16#47#, 16#80#, 16#03#, 16#01#, 16#45#, 16#18#, 16#00#, 16#01#, 16#0F#);

   type Channel_Rows is array (0 .. 15) of Channel_Map;

   AFHDS_Channels : constant Channel_Rows :=
     ((16#0A#, 16#5A#, 16#14#, 16#64#, 16#1E#, 16#6E#, 16#28#, 16#78#, 16#32#, 16#82#, 16#3C#, 16#8C#, 16#46#,
       16#96#, 16#50#, 16#A0#),
      (16#A0#, 16#50#, 16#96#, 16#46#, 16#8C#, 16#3C#, 16#82#, 16#32#, 16#78#, 16#28#, 16#6E#, 16#1E#, 16#64#,
       16#14#, 16#5A#, 16#0A#),
      (16#0A#, 16#5A#, 16#50#, 16#A0#, 16#14#, 16#64#, 16#46#, 16#96#, 16#1E#, 16#6E#, 16#3C#, 16#8C#, 16#28#,
       16#78#, 16#32#, 16#82#),
      (16#82#, 16#32#, 16#78#, 16#28#, 16#8C#, 16#3C#, 16#6E#, 16#1E#, 16#96#, 16#46#, 16#64#, 16#14#, 16#A0#,
       16#50#, 16#5A#, 16#0A#),
      (16#28#, 16#78#, 16#0A#, 16#5A#, 16#50#, 16#A0#, 16#14#, 16#64#, 16#1E#, 16#6E#, 16#3C#, 16#8C#, 16#32#,
       16#82#, 16#46#, 16#96#),
      (16#96#, 16#46#, 16#82#, 16#32#, 16#8C#, 16#3C#, 16#6E#, 16#1E#, 16#64#, 16#14#, 16#A0#, 16#50#, 16#5A#,
       16#0A#, 16#78#, 16#28#),
      (16#50#, 16#A0#, 16#28#, 16#78#, 16#0A#, 16#5A#, 16#1E#, 16#6E#, 16#3C#, 16#8C#, 16#32#, 16#82#, 16#46#,
       16#96#, 16#14#, 16#64#),
      (16#64#, 16#14#, 16#96#, 16#46#, 16#82#, 16#32#, 16#8C#, 16#3C#, 16#6E#, 16#1E#, 16#5A#, 16#0A#, 16#78#,
       16#28#, 16#A0#, 16#50#),
      (16#50#, 16#A0#, 16#46#, 16#96#, 16#3C#, 16#8C#, 16#28#, 16#78#, 16#0A#, 16#5A#, 16#32#, 16#82#, 16#1E#,
       16#6E#, 16#14#, 16#64#),
      (16#64#, 16#14#, 16#6E#, 16#1E#, 16#82#, 16#32#, 16#5A#, 16#0A#, 16#78#, 16#28#, 16#8C#, 16#3C#, 16#96#,
       16#46#, 16#A0#, 16#50#),
      (16#46#, 16#96#, 16#3C#, 16#8C#, 16#50#, 16#A0#, 16#28#, 16#78#, 16#0A#, 16#5A#, 16#1E#, 16#6E#, 16#32#,
       16#82#, 16#14#, 16#64#),
      (16#64#, 16#14#, 16#82#, 16#32#, 16#6E#, 16#1E#, 16#5A#, 16#0A#, 16#78#, 16#28#, 16#A0#, 16#50#, 16#8C#,
       16#3C#, 16#96#, 16#46#),
      (16#46#, 16#96#, 16#0A#, 16#5A#, 16#3C#, 16#8C#, 16#14#, 16#64#, 16#50#, 16#A0#, 16#28#, 16#78#, 16#1E#,
       16#6E#, 16#32#, 16#82#),
      (16#82#, 16#32#, 16#6E#, 16#1E#, 16#78#, 16#28#, 16#A0#, 16#50#, 16#64#, 16#14#, 16#8C#, 16#3C#, 16#5A#,
       16#0A#, 16#96#, 16#46#),
      (16#46#, 16#96#, 16#0A#, 16#5A#, 16#50#, 16#A0#, 16#3C#, 16#8C#, 16#28#, 16#78#, 16#1E#, 16#6E#, 16#32#,
       16#82#, 16#14#, 16#64#),
      (16#64#, 16#14#, 16#82#, 16#32#, 16#6E#, 16#1E#, 16#78#, 16#28#, 16#8C#, 16#3C#, 16#A0#, 16#50#, 16#5A#,
       16#0A#, 16#96#, 16#46#));

   function Packet_Us (C : Settings) return Unsigned_32 is (if C.Protocol = AFHDS_2A then 3_850 else 1_500);
   function First_Packet_Us (C : Settings) return Unsigned_32 is (if C.Protocol = AFHDS_2A then 4_850 else 1_900);
   function Sync_Packet_Us (C : Settings) return Unsigned_32 is (if C.Protocol = AFHDS_2A then 5_775 else 2_250);
   function Telemetry_Period_Us (C : Settings) return Unsigned_32 is
     (if C.Protocol = AFHDS_2A then 57_000 else Unsigned_32'Last);
   function Bind_Channel (C : Settings) return Unsigned_8 is (if C.Protocol = AFHDS_2A then 16#0D# else 0);

   function Word_At (P : Packet_Bytes; First : Natural) return Unsigned_32 is
     (Unsigned_32 (P (First)) + Unsigned_32 (P (First + 1)) * 2 ** 8 + Unsigned_32 (P (First + 2)) * 2 ** 16
      + Unsigned_32 (P (First + 3)) * 2 ** 24)
     with Pre => First <= Packet_Size - 4;

   procedure Put_Word (P : in out Packet_Bytes; First : Natural; Value : Unsigned_32)
     with Global => null, Pre => First <= Packet_Size - 4
   is
   begin
      for K in 0 .. 3 loop
         P (First + K) := Unsigned_8 ((Value / 2 ** (8 * K)) mod 256);
      end loop;
   end Put_Word;

   procedure A_Strobe (S : in out State; O : in out Output; Command : Unsigned_8)
     with Global => null
   is
   begin
      if Command = TX or else Command = RX then
         S.Consume_Exti := True;
         Add (O, (Kind => Reset_Exti, others => <>));
      else
         S.Consume_Exti := False;
      end if;
      Strobe (O, Command);
   end A_Strobe;

   procedure Next_Channel (S : in out State; Step : Natural; Channel : out Unsigned_8)
     with Global => null, Pre => Step <= 15
   is
   begin
      S.Hop := (S.Hop + Step) mod 16;
      Channel := S.Rf_Map (S.Hop);
   end Next_Channel;

   procedure Hop_To_Next (S : in out State; O : in out Output)
     with Global => null
   is
      Channel : Unsigned_8;
   begin
      Next_Channel (S, 1, Channel);
      Write (O, CHANNEL_REGISTER, Channel);
   end Hop_To_Next;

   procedure Reset_Timeout (S : in out State; C : Settings; Time_Us : Unsigned_32)
     with Global => null
   is
   begin
      S.Last_Packet_Us := Time_Us;
      S.Timeout_Us := First_Packet_Us (C);
      S.Count_Timeout := 0;
      S.Count_Packet := S.Count_Packet + 1;
   end Reset_Timeout;

   procedure Check_Timeout (S : in out State; C : Settings; O : in out Output; Now : Unsigned_32)
     with Global => null
   is
      Channel : Unsigned_8;
   begin
      if Now - S.Error_Rate_Us > 101 * Packet_Us (C) then
         S.Error_Rate := (if S.Count_Packet >= 100 then 0 else Unsigned_16 (100 - S.Count_Packet));
         S.Count_Packet := 0;
         S.Error_Rate_Us := Now;
      end if;
      if Now - S.Telemetry_Us > Telemetry_Period_Us (C) then
         S.Telemetry_Us := Now;
         S.Send_Telemetry := True;
      end if;
      if Now - S.Last_Packet_Us > S.Timeout_Us then
         declare
            Step_Over : constant Unsigned_32 := (Now - S.Last_Packet_Us) / Packet_Us (C);
         begin
            S.Last_Packet_Us := (if Step_Over > 1 then Now else S.Last_Packet_Us + S.Timeout_Us);
            A_Strobe (S, O, STANDBY);
            Next_Channel (S, Natural (Step_Over mod 16), Channel);
            Write (O, CHANNEL_REGISTER, Channel);
            A_Strobe (S, O, RX);
            if S.Count_Timeout > 31 then
               S.Timeout_Us := Sync_Packet_Us (C);
               Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
            else
               S.Timeout_Us := Packet_Us (C);
               S.Count_Timeout := S.Count_Timeout + 1;
            end if;
         end;
      end if;
   end Check_Timeout;

   procedure Check_RSSI (S : in out State; O : in out Output; Reading : Unsigned_8)
     with Global => null
   is
      Sum : Natural := 0;
   begin
      S.Samples (S.Sample_Index) := Reading;
      S.Sample_Index := (S.Sample_Index + 1) mod 16;
      for K in RSSI_Samples'Range loop
         Sum := Sum + Natural (S.Samples (K));
         pragma Loop_Invariant (Sum <= 255 * (K + 1));
      end loop;
      S.RSSI_Dbm := Unsigned_16 (50 + Sum / 48);
      Add (O, (Kind => Set_RSSI_Direct, Value => Unsigned_16 ((2_280 - 24 * Integer (S.RSSI_Dbm)) mod 65_536),
               others => <>));
   end Check_RSSI;

   procedure Read_Fifo (S : in out State; Inp : Inputs; O : in out Output; P : out Packet_Bytes; Count : Natural)
     with Global => null, Pre => Count in 1 .. Packet_Size
   is
   begin
      P := (others => 0);
      A_Strobe (S, O, RST_RDPTR);
      for K in 0 .. Count - 1 loop
         P (K) := Inp.Fifo (K);
      end loop;
      Add (O, (Kind => Read_Fifo, A => Unsigned_8 (Count), others => <>));
   end Read_Fifo;

   procedure Write_Fifo (S : in out State; O : in out Output; P : Packet_Bytes; Count : Natural)
     with Global => null, Pre => Count in 1 .. Packet_Size
   is
   begin
      A_Strobe (S, O, RST_WRPTR);
      for K in 0 .. Count - 1 loop
         O.Tx_Data (K) := P (K);
      end loop;
      Add (O, (Kind => Write_Fifo, A => Unsigned_8 (Count), others => <>));
   end Write_Fifo;

   procedure Write_Telemetry (S : in out State; O : in out Output; Received : Packet_Bytes; Voltage : Unsigned_16)
     with Global => null
   is
      P : Packet_Bytes := Received;
   begin
      P (0) := 16#AA#;
      P (9) := 16#00#;
      P (10) := 0;
      P (11) := Unsigned_8 (Voltage mod 256);
      P (12) := Unsigned_8 (Voltage / 256);
      P (13) := 16#FC#;
      P (14) := 0;
      P (15) := Unsigned_8 (S.RSSI_Dbm mod 256);
      P (16) := Unsigned_8 (S.RSSI_Dbm / 256);
      P (17) := 16#FE#;
      P (18) := 0;
      P (19) := Unsigned_8 (S.Error_Rate mod 256);
      P (20) := Unsigned_8 (S.Error_Rate / 256);
      for K in 21 .. 36 loop
         P (K) := 16#FF#;
      end loop;
      Write_Fifo (S, O, P, S.Telemetry_Bytes);
      S.Telemetry_Bytes := 21;
   end Write_Telemetry;

   procedure Process_2A
     (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Time_Us : Unsigned_32; Result : in out Received)
     with Global => null
   is
      P : Packet_Bytes;
   begin
      Read_Fifo (S, Inp, O, P, (if S.Bound then 37 else 27));
      case P (0) is
         when 16#58# | 16#56# | 16#AA# =>
            if Word_At (P, 5) = C.Receiver_Id and then Word_At (P, 1) = S.Tx_Id then
               Check_RSSI (S, O, Inp.RSSI_Register);
               Reset_Timeout (S, C, Time_Us);
               if P (0) = 16#58# then
                  for K in Payload_Bytes'Range loop
                     S.Payload (K) := P (9 + K);
                  end loop;
                  if S.Send_Telemetry then
                     Write_Telemetry (S, O, P, Inp.Battery_Voltage);
                     S.Send_Telemetry := False;
                     S.Tx_Request_Us := Time_Us;
                     S.Wait_Tx := True;
                  end if;
                  Result := Data_Ready;
               end if;
               if not S.Wait_Tx then
                  Hop_To_Next (S, O);
               end if;
            end if;
         when 16#BB# | 16#BC# =>
            if not S.Bound then
               Reset_Timeout (S, C, Time_Us);
               if P (11) /= 16#FF# then
                  for K in Channel_Map'Range loop
                     S.Rf_Map (K) := P (11 + K);
                  end loop;
               end if;
               S.Tx_Id := Word_At (P, 1);
               Put_Word (P, 5, C.Receiver_Id);
               for K in 11 .. 36 loop
                  P (K) := 16#FF#;
               end loop;
               S.Tx_Request_Us := Time_Us;
               S.Last_Bind_Us := Time_Us;
               S.Wait_Tx := True;
               Write_Fifo (S, O, P, Packet_Size);
            end if;
         when others =>
            null;
      end case;
      if not S.Wait_Tx then
         A_Strobe (S, O, RX);
      end if;
   end Process_2A;

   procedure Process_AFHDS
     (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Time_Us : Unsigned_32; Result : in out Received)
     with Global => null
   is
      P       : Packet_Bytes;
      Channel : Unsigned_8;
   begin
      Read_Fifo (S, Inp, O, P, (if S.Bound then 21 else 5));
      if S.Bound and then P (0) = 16#55# and then Word_At (P, 1) = S.Tx_Id then
         Check_RSSI (S, O, Inp.RSSI_Register);
         Reset_Timeout (S, C, Time_Us);
         for K in 0 .. 15 loop
            S.Payload (K) := P (5 + K);
         end loop;
         Hop_To_Next (S, O);
         Result := Data_Ready;
      end if;
      if not S.Bound and then P (0) = 16#AA# then
         Reset_Timeout (S, C, Time_Us);
         S.Tx_Id := Word_At (P, 1);
         declare
            Row    : constant Natural := Natural (S.Tx_Id mod 16);
            Offset : constant Unsigned_8 := Unsigned_8'Min (Unsigned_8 ((S.Tx_Id / 16) mod 16) + 1, 9);
         begin
            for K in Channel_Map'Range loop
               S.Rf_Map (K) := AFHDS_Channels (Row) (K) - Offset;
            end loop;
         end;
         Next_Channel (S, 0, Channel);
         Write (O, CHANNEL_REGISTER, Channel);
         S.Last_Bind_Us := Time_Us;
      end if;
      A_Strobe (S, O, RX);
   end Process_AFHDS;

   -----------
   -- Start --
   -----------

   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean)
   is
      Registers : constant Register_Set :=
        (if C.Protocol = AFHDS_2A then AFHDS_2A_Registers else AFHDS_Registers);
      Channel   : Unsigned_8 := Bind_Channel (C);
   begin
      S := (others => <>);
      O := (others => <>);
      Start_Common (S.Radio, C.Pins, Inp.Bind_Pin_Level, O);
      Write (O, MODE, 16#00#);
      Add (O, (Kind => Write_Id, Word => Radio_Id, others => <>));
      for R in Register_Set'Range loop
         if Registers (R) /= 16#FF# then
            Write (O, R, Registers (R));
         end if;
      end loop;
      A_Strobe (S, O, STANDBY);
      Write (O, CALC, 16#01#);
      Add (O, (Kind => Await_Clear, A => CALC, others => <>));
      Add (O, (Kind => Read_Register, A => IF_CALIB, others => <>));
      Write (O, VCO_CURCAL, 16#13#);
      Write (O, VCO_SBCAL, 16#09#);
      A_Strobe (S, O, STANDBY);
      if C.Tx_Id /= 0 then
         S.Bound := True;
         S.Tx_Id := C.Tx_Id;
         S.Rf_Map := C.Rf_Map;
         Next_Channel (S, 0, Channel);
      end if;
      Claim_RSSI := True;
      Write (O, CHANNEL_REGISTER, Channel);
      A_Strobe (S, O, RX);
      Reset_Timeout (S, C, Inp.Now_Us);
      Ok := True;
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
      Time_Us   : Unsigned_32 := 0;
      Requested : Boolean;
   begin
      O := (others => <>);
      Result := None;
      if S.Consume_Exti and then Inp.Exti_Flag then
         if Inp.Exti_Time_Us /= 0 then
            Time_Us := Inp.Exti_Time_Us;
         end if;
         Add (O, (Kind => Reset_Exti, others => <>));
         if (Inp.Mode_Register and Mode_TRSR) /= 0 and then (Inp.Mode_Register and Mode_TRER) = 0 then
            if S.Bound then
               Hop_To_Next (S, O);
            end if;
            A_Strobe (S, O, RX);
         elsif (Inp.Mode_Register and (Mode_CRCF or Mode_TRER)) = 0 then
            case C.Protocol is
               when AFHDS_2A =>
                  Process_2A (S, C, Inp, O, Time_Us, Result);
               when AFHDS =>
                  Process_AFHDS (S, C, Inp, O, Time_Us, Result);
            end case;
         else
            A_Strobe (S, O, RX);
         end if;
      end if;
      if S.Wait_Tx and then Inp.Now_Us - S.Tx_Request_Us > Tx_Delay_Us then
         A_Strobe (S, O, TX);
         S.Wait_Tx := False;
      end if;
      Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, True, Requested);
      if Requested then
         S.Bound := False;
         S.Tx_Id := 0;
         S.Rf_Map := (others => 0);
         Write (O, CHANNEL_REGISTER, Bind_Channel (C));
      end if;
      if S.Bound then
         Check_Timeout (S, C, O, Inp.Now_Us);
         LED_Blink_Rx_Loss (S.Radio, C.Pins, O, Inp.Now_Ms, Result = Data_Ready);
      else
         if Inp.Now_Us - S.Last_Bind_Us > Bind_Time_Us and then S.Rf_Map (0) /= 0 and then S.Tx_Id /= 0 then
            Result := Bind_Done;
            S.Bound := True;
            C.Tx_Id := S.Tx_Id;
            C.Rf_Map := S.Rf_Map;
            Add (O, (Kind => Save_Config, others => <>));
         end if;
         LED_Blink (S.Radio, C.Pins, O, Inp.Now_Ms, 250);
      end if;
   end Data_Received;

   -----------------
   -- Set_Rc_Data --
   -----------------

   procedure Set_Rc_Data (S : State; C : Settings; Rc : in out Channel_Values) is
   begin
      for K in 0 .. Channel_Count (C) - 1 loop
         Rc (K) := Unsigned_16 (S.Payload (2 * K + 1)) * 256 + Unsigned_16 (S.Payload (2 * K));
      end loop;
   end Set_Rc_Data;

end Adaflight.FlySky;
