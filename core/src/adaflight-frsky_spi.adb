with Adaflight.Clock;

package body Adaflight.FrSky_SPI with SPARK_Mode is
   use Adaflight.CC2500_Radio;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;

   FSCTRL0  : constant := 16#0C#;
   MCSM0    : constant := 16#18#;
   ADDR     : constant := 16#09#;
   PKTCTRL1 : constant := 16#07#;
   FOCCFG   : constant := 16#19#;
   FIFOTHR  : constant := 16#03#;
   FSCAL3   : constant := 16#23#;
   FSCAL2   : constant := 16#24#;
   FSCAL1   : constant := 16#25#;
   CHANNR   : constant := 16#0A#;

   Sync_Delay_Max  : constant := 9_000;
   Max_Missing     : constant := 100;

   Base_Config : constant Register_List :=
     ((16#02#, 16#01#), (16#18#, 16#18#), (16#07#, 16#05#), (16#3E#, 16#FF#), (16#0C#, 16#00#), (16#0D#, 16#5C#),
      (16#13#, 16#23#), (16#14#, 16#7A#), (16#19#, 16#16#), (16#1A#, 16#6C#), (16#1B#, 16#03#), (16#1C#, 16#40#),
      (16#1D#, 16#91#), (16#21#, 16#56#), (16#22#, 16#10#), (16#23#, 16#A9#), (16#24#, 16#0A#), (16#25#, 16#00#),
      (16#26#, 16#11#), (16#29#, 16#59#), (16#2C#, 16#88#), (16#2D#, 16#31#), (16#2E#, 16#0B#), (16#03#, 16#07#),
      (16#09#, 16#00#));

   D_Config : constant Register_List :=
     ((16#17#, 16#0C#), (16#0E#, 16#76#), (16#0F#, 16#27#), (16#06#, 16#19#), (16#08#, 16#05#), (16#0B#, 16#08#),
      (16#10#, 16#AA#), (16#11#, 16#39#), (16#12#, 16#11#), (16#15#, 16#42#));

   X_Config : constant Register_List :=
     ((16#17#, 16#0C#), (16#0E#, 16#76#), (16#0F#, 16#27#), (16#06#, 16#1E#), (16#08#, 16#01#), (16#0B#, 16#0A#),
      (16#10#, 16#7B#), (16#11#, 16#61#), (16#12#, 16#13#), (16#15#, 16#51#));

   X_LBT_Config : constant Register_List :=
     ((16#17#, 16#0E#), (16#0E#, 16#80#), (16#0F#, 16#00#), (16#06#, 16#23#), (16#08#, 16#01#), (16#0B#, 16#08#),
      (16#10#, 16#7B#), (16#11#, 16#F8#), (16#12#, 16#03#), (16#15#, 16#53#));

   X_V2_Config : constant Register_List := ((16#17#, 16#0E#), (16#08#, 16#05#), (16#11#, 16#84#));

   X_LBT_V2_Config : constant Register_List := (1 => (16#08#, 16#05#));

   function Is_V2 (C : Settings) return Boolean is (C.Protocol in FrSky_X_V2 | FrSky_X_LBT_V2);

   Crc_Short : constant array (0 .. 15) of Unsigned_16 :=
     (16#0000#, 16#1189#, 16#2312#, 16#329B#, 16#4624#, 16#57AD#, 16#6536#, 16#74BF#,
      16#8C48#, 16#9DC1#, 16#AF5A#, 16#BED3#, 16#CA6C#, 16#DBE5#, 16#E97E#, 16#F8F7#);

   --  One byte into the D16 CRC.
   function Crc_Step (Crc : Unsigned_16; Byte : Unsigned_8) return Unsigned_16 is
     (Interfaces.Shift_Left (Crc, 8)
      xor (Crc_Short (Natural ((Unsigned_8 (Interfaces.Shift_Right (Crc, 8)) xor Byte) and 16#0F#))
           xor (16#1081# * Unsigned_16 ((Unsigned_8 (Interfaces.Shift_Right (Crc, 8)) xor Byte) / 16))));

   procedure Read_Packet (S : in out State; Inp : Inputs; O : in out Output; Count : Natural)
     with Global => null, Pre => Count in 20 .. 35
   is
   begin
      for K in 0 .. Count - 1 loop
         S.Payload (K) := Inp.Fifo (K);
      end loop;
      Add (O, (Kind => Read_Fifo, A => Unsigned_8 (Count), others => <>));
   end Read_Packet;

   function Valid_Bind_Packet (S : State; C : Settings) return Boolean is
     ((if C.Protocol = FrSky_D or else Is_V2 (C) then (S.Payload (S.Packet_Length - 1) and 16#80#) /= 0)
      and then Natural (S.Payload (0)) = S.Packet_Length - 3 and then S.Payload (1) = 16#03#
      and then S.Payload (2) = 16#01#);

   procedure Initialise (C : Settings; O : in out Output)
     with Global => null
   is
   begin
      Add (O, (Kind => Startup_Speed, others => <>));
      Add (O, (Kind => Reset, others => <>));
      Write_All (O, Base_Config);
      case C.Protocol is
         when FrSky_D =>
            Write_All (O, D_Config);
         when FrSky_X =>
            Write_All (O, X_Config);
         when FrSky_X_LBT =>
            Write_All (O, X_LBT_Config);
         when FrSky_X_V2 =>
            Write_All (O, X_Config);
            Write_All (O, X_V2_Config);
         when FrSky_X_LBT_V2 =>
            Write_All (O, X_LBT_Config);
            Write_All (O, X_LBT_V2_Config);
      end case;
      Calibrate_Channels (O, Count => 255, Step => 1, Base => 0);
      Add (O, (Kind => Normal_Speed, others => <>));
   end Initialise;

   procedure Initialise_Data (C : Settings; O : in out Output; In_Bind : Boolean)
     with Global => null
   is
   begin
      Write (O, FSCTRL0, Byte_Of (C.Bind_Offset));
      Write (O, MCSM0, 16#08#);
      Write (O, ADDR, (if In_Bind then 16#03# else C.Bind_Tx_Id (0)));
      Write (O, PKTCTRL1, 16#0D#);
      Write (O, FOCCFG, 16#16#);
      if not In_Bind then
         Write (O, FIFOTHR, 16#0E#);
      end if;
      Add (O, (Kind => Delay_Ms, Value => 10, others => <>));
   end Initialise_Data;

   procedure Tune_To_First (S : State; O : in out Output)
     with Global => null
   is
   begin
      Strobe (O, SIDLE);
      Write (O, FSCAL3, S.Cal (0) (0));
      Write (O, FSCAL2, S.Cal (0) (1));
      Write (O, FSCAL1, S.Cal (0) (2));
      Write (O, CHANNR, 0);
      Strobe (O, SFRX);
   end Tune_To_First;

   procedure Init_Tune_Rx (S : in out State; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Write (O, FOCCFG, 16#14#);
      S.Time_Tuned_Ms := Inp.Now_Ms;
      S.Bind_Offset := -126;
      Write (O, FSCTRL0, Byte_Of (S.Bind_Offset));
      Write (O, PKTCTRL1, 16#0C#);
      Write (O, MCSM0, 16#08#);
      Tune_To_First (S, O);
      Strobe (O, SRX);
   end Init_Tune_Rx;

   --  The offset steps every 50 ms, and at once from either end, wrapping in
   --  eight bits.
   procedure Tune_Rx
     (S : in out State; C : Settings; Inp : Inputs; Inc : Integer; O : in out Output; Found : out Boolean)
     with Global => null, Pre => Inc in -2 | 2
   is
   begin
      Found := False;
      if Inp.Now_Ms - S.Time_Tuned_Ms > 50 or else S.Bind_Offset = 126 or else S.Bind_Offset = -126 then
         S.Time_Tuned_Ms := Inp.Now_Ms;
         S.Bind_Offset := Integer_8 ((Integer (S.Bind_Offset) + Inc + 128) mod 256 - 128);
         Write (O, FSCTRL0, Byte_Of (S.Bind_Offset));
         Strobe (O, SRX);
      end if;
      if Inp.Exti and then Natural (Inp.Rx_Bytes and 16#7F#) >= S.Packet_Length then
         Read_Packet (S, Inp, O, S.Packet_Length);
         Found := Valid_Bind_Packet (S, C);
      end if;
   end Tune_Rx;

   procedure Init_Get_Bind (S : in out State; O : in out Output)
     with Global => null
   is
   begin
      Tune_To_First (S, O);
      Add (O, (Kind => Delay_Us, Value => 20, others => <>));
      Strobe (O, SRX);
      S.List_Length := 0;
      S.Bind_State := 0;
   end Init_Get_Bind;

   --  The V2 hop table from the transmitter id: a step and a start offset,
   --  then channels moved off the band's reserved ones.
   procedure Generate_V2_Hop_Data (C : in out Settings; Id : Natural)
     with Global => null, Pre => Id <= 65_535
   is
      Inc     : Natural := Id mod 46 + 1;
      Offset  : constant Natural := Id mod 5;
      Channel : Natural;
   begin
      if Inc = 12 or else Inc = 35 then
         Inc := Inc + 1;
      end if;
      for I in 0 .. 46 loop
         Channel := 5 * ((Inc * I) mod 65_536 mod 47) + Offset;
         if C.Protocol = FrSky_X_LBT_V2 then
            if Channel <= 1 or else Channel in 43 | 44 | 87 | 88 | 129 | 130 | 173 | 174 then
               Channel := Channel + 2;
            elsif Channel in 216 .. 218 then
               Channel := Channel + 3;
            end if;
         elsif Channel in 3 | 4 | 46 | 47 | 90 | 91 | 133 | 134 | 176 | 177 | 220 | 221 then
            Channel := Channel + 2;
         end if;
         C.Bind_Hop_Data (I) := Unsigned_8 (Channel);
      end loop;
      C.Bind_Hop_Data (47) := 0;
      C.Bind_Hop_Data (48) := 0;
      C.Bind_Hop_Data (49) := 0;
   end Generate_V2_Hop_Data;

   --  A chunk of the hop table from a bind packet, the transmitter id from
   --  the first; complete with all ten chunks.
   procedure Get_Bind (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null
   is
      Index : Natural;
   begin
      Done := False;
      if not Inp.Exti or else Natural (Inp.Rx_Bytes and 16#7F#) < S.Packet_Length then
         return;
      end if;
      Read_Packet (S, Inp, O, S.Packet_Length);
      if not Valid_Bind_Packet (S, C) then
         return;
      end if;
      if Is_V2 (C) then
         for K in 3 .. S.Packet_Length - 5 loop
            S.Payload (K) := S.Payload (K) xor 16#A7#;
         end loop;
         C.Bind_Tx_Id (0) := S.Payload (3);
         C.Bind_Tx_Id (1) := S.Payload (4);
         C.Bind_Tx_Id (2) := S.Payload (5);
         C.Rx_Num := S.Payload (6);
         Generate_V2_Hop_Data (C, Natural (S.Payload (4)) * 256 + Natural (S.Payload (3)));
         S.List_Length := 47;
         Done := True;
         return;
      end if;
      if S.Payload (5) = 0 then
         C.Bind_Tx_Id (0) := S.Payload (3);
         C.Bind_Tx_Id (1) := S.Payload (4);
         if C.Protocol = FrSky_D then
            C.Bind_Tx_Id (2) := S.Payload (17);
            C.Rx_Num := 0;
         else
            C.Bind_Tx_Id (2) := S.Payload (11);
            C.Rx_Num := S.Payload (12);
         end if;
      end if;
      for N in 0 .. 4 loop
         Index := Natural (S.Payload (5)) + N;
         if Index <= Hop_Table'Last then
            C.Bind_Hop_Data (Index) := (if Index >= 47 then 0 else S.Payload (6 + N));
         end if;
      end loop;
      if S.Payload (5) / 5 < 16 then
         S.Bind_State := S.Bind_State or Interfaces.Shift_Left (Unsigned_16'(1), Natural (S.Payload (5) / 5));
      end if;
      if S.Bind_State = 16#3FF# then
         S.List_Length := 47;
         Done := True;
      end if;
   end Get_Bind;

   procedure Next_Channel (S : in out State; C : Settings; O : in out Output; Skip : Unsigned_8)
     with Global => null
   is
      Hop : Natural;
   begin
      if S.List_Length = 0 then
         return;
      end if;
      S.Channel := S.Channel + Skip;
      while S.Channel >= S.List_Length loop
         pragma Loop_Variant (Decreases => S.Channel);
         S.Channel := S.Channel - S.List_Length;
      end loop;
      Strobe (O, SIDLE);
      Hop := Natural (C.Bind_Hop_Data (Natural (S.Channel) mod 50));
      Write (O, FSCAL3, S.Cal (Hop) (0));
      Write (O, FSCAL2, S.Cal (Hop) (1));
      Write (O, FSCAL1, S.Cal (Hop) (2));
      Write (O, CHANNR, Unsigned_8 (Hop));
      if C.Protocol = FrSky_D then
         Strobe (O, SFRX);
      end if;
   end Next_Channel;

   --  The hub stream's bytes for the frame: a new burst once the last is
   --  sent and its last frame acknowledged, a resend when the transmitter
   --  asks again, at most ten bytes a frame. The send position wraps at the
   --  buffer's size, so a burst that fills the buffer never completes.
   procedure Append_Hub_Data (S : in out State; C : Settings; Inp : Inputs; Count : out Natural)
     with Global => null, Post => Count <= 10
   is
      Id : constant Unsigned_8 := S.Payload (4);
   begin
      if Id = S.Hub_Id_Expected then
         S.Hub_Acknowledged := S.Hub_Sent;
         S.Hub_Id_Expected := (Id + 1) and 16#1F#;
         if S.Hub_Generated = 0 then
            S.Hub_Sent := 0;
            declare
               Hub_Inp : Adaflight.FrSky_Hub_Telemetry.Inputs := Inp.Hub;
               Hub_Out : Adaflight.FrSky_Hub_Telemetry.Output;
            begin
               Hub_Inp.Now_Us := Inp.Now_Us;
               Hub_Inp.Now_Ms := Inp.Now_Ms;
               Adaflight.FrSky_Hub_Telemetry.Update (S.Hub, C.Hub, Hub_Inp, Hub_Out);
               for K in 0 .. Hub_Out.Count - 1 loop
                  if S.Hub_Generated < Hub_Buffer_Size then
                     S.Hub_Data (S.Hub_Generated) := Hub_Out.Tx (K);
                     S.Hub_Generated := S.Hub_Generated + 1;
                  end if;
               end loop;
            end;
         end if;
      else
         S.Hub_Sent := S.Hub_Acknowledged;
      end if;
      Count := 0;
      for K in 0 .. 9 loop
         pragma Loop_Invariant (Count = K);
         if S.Hub_Sent = S.Hub_Generated then
            S.Hub_Generated := 0;
            exit;
         end if;
         S.Frame (8 + K) := S.Hub_Data (S.Hub_Sent);
         S.Hub_Sent := (S.Hub_Sent + 1) mod Hub_Buffer_Size;
         Count := Count + 1;
      end loop;
   end Append_Hub_Data;

   procedure Build_Telemetry_Frame (S : in out State; C : Settings; Inp : Inputs)
     with Global => null
   is
      Used : Natural := 0;
      A1_Value : constant Unsigned_8 :=
        (case C.A1 is
           when External_ADC    => Unsigned_8 ((Inp.ADC_External and 16#FF0#) / 16),
           when Constant_Value  => 100,
           when Battery_Voltage => Unsigned_8 ((Inp.Battery_Voltage / 5) and 16#FF#));
   begin
      S.Frame (0) := 16#11#;
      S.Frame (1) := C.Bind_Tx_Id (0);
      S.Frame (2) := C.Bind_Tx_Id (1);
      S.Frame (3) := A1_Value;
      S.Frame (4) := Unsigned_8 ((Inp.ADC_RSSI / 16) and 16#FF#);
      S.Frame (5) := Unsigned_8 ((Integer (S.Radio.RSSI_Dbm) + 65_536) mod 256);
      if S.Telemetry_Enabled then
         Append_Hub_Data (S, C, Inp, Used);
      end if;
      S.Frame (6) := Unsigned_8 (Used);
      S.Frame (7) := S.Payload (4);
   end Build_Telemetry_Frame;

   procedure D_Handle_Packet (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Result : out Received)
     with Global => null
   is
      Current   : constant Unsigned_32 := Inp.Now_Us;
      Requested : Boolean;
      Packet_Ok : Boolean;
   begin
      Result := None;
      case S.Protocol is
         when Starting =>
            S.List_Length := 47;
            Initialise_Data (C, O, False);
            S.Protocol := Update;
            Next_Channel (S, C, O, 1);
            Strobe (O, SRX);
         when Update | Data =>
            if S.Protocol = Update then
               S.Last_Packet_Us := Current;
               S.Protocol := Data;
               Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, False, Requested);
               if Requested then
                  S.Last_Packet_Us := 0;
                  S.Timeout_Us := 50;
                  S.Missing_Packets := 0;
                  S.Protocol := Init;
                  return;
               end if;
            end if;
            if Inp.Exti then
               Packet_Ok := False;
               if (Inp.Rx_Bytes and 16#7F#) >= 20 then
                  Read_Packet (S, Inp, O, 20);
                  if (S.Payload (19) and 16#80#) /= 0 then
                     Packet_Ok := True;
                     S.Missing_Packets := 0;
                     S.Timeout_Us := 1;
                     if S.Payload (0) = 16#11# and then S.Payload (1) = C.Bind_Tx_Id (0)
                       and then S.Payload (2) = C.Bind_Tx_Id (1) and then S.Payload (5) = C.Bind_Tx_Id (2)
                     then
                        LED_On (O, C.Pins);
                        Next_Channel (S, C, O, 1);
                        Set_RSSI_Dbm (S.Radio, O, S.Payload (18));
                        if S.Payload (3) mod 4 = 2 then
                           S.Telemetry_Us := Inp.Now_Us;
                           Build_Telemetry_Frame (S, C, Inp);
                           S.Protocol := Telemetry;
                        else
                           Strobe (O, SRX);
                           S.Protocol := Update;
                        end if;
                        Result := Data_Ready;
                        S.Last_Packet_Us := Current;
                     end if;
                  end if;
               end if;
               if not Packet_Ok then
                  Strobe (O, SFRX);
               end if;
            end if;
            if Integer (Adaflight.Clock.Elapsed (Current, S.Last_Packet_Us)) > Integer (S.Timeout_Us) * Sync_Delay_Max
            then
               if C.Pins.Tx_Enable then
                  Set_Pin (O, Tx_Enable, False);
               end if;
               if S.Timeout_Us = 1 then
                  if S.Missing_Packets >= 2 then
                     Switch_Antennae (S.Radio, O);
                  end if;
                  if S.Missing_Packets > Max_Missing then
                     S.Timeout_Us := 50;
                     Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
                  end if;
                  S.Missing_Packets := S.Missing_Packets + 1;
                  Next_Channel (S, C, O, 1);
               else
                  LED_Toggle (O, C.Pins);
                  Add (O, (Kind => Set_RSSI, Value => 0, others => <>));
                  Next_Channel (S, C, O, 13);
               end if;
               Strobe (O, SRX);
               S.Protocol := Update;
            end if;
         when Telemetry =>
            if Adaflight.Clock.Elapsed (Inp.Now_Us, S.Telemetry_Us) >= 1_380 then
               Strobe (O, SIDLE);
               Add (O, (Kind => Set_Power, A => 6, others => <>));
               Strobe (O, SFRX);
               if C.Pins.Tx_Enable then
                  Set_Pin (O, Tx_Enable, True);
               end if;
               Strobe (O, SIDLE);
               O.Tx_Data := Tx_Bytes (S.Frame);
               Add (O, (Kind => Write_Fifo, A => S.Frame (0) + 1, others => <>));
               S.Protocol := Data;
               S.Last_Packet_Us := Current;
            end if;
         when others =>
            null;
      end case;
   end D_Handle_Packet;

   function Valid_X_Packet (S : State; C : Settings) return Boolean is
      L   : constant Natural := S.Packet_Length;
      Crc : Unsigned_16 := 0;
   begin
      if Is_V2 (C) and then (S.Payload (L - 1) and 16#80#) = 0 then
         return False;
      end if;
      for K in 3 .. L - 5 loop
         Crc := Crc_Step (Crc, S.Payload (K));
      end loop;
      return Unsigned_8 (Interfaces.Shift_Right (Crc, 8)) = S.Payload (L - 4)
        and then Unsigned_8 (Crc and 16#FF#) = S.Payload (L - 3)
        and then Natural (S.Payload (0)) = L - 3
        and then S.Payload (1) = C.Bind_Tx_Id (0) and then S.Payload (2) = C.Bind_Tx_Id (1)
        and then (not Is_V2 (C) or else S.Payload (3) = C.Bind_Tx_Id (2))
        and then (C.Rx_Num = 0 or else S.Payload (6) = 0 or else S.Payload (6) = C.Rx_Num);
   end Valid_X_Packet;

   --  The SmartPort bytes waiting for the link, at most five a frame.
   procedure Append_SmartPort_Data (S : in out State; Count : out Natural)
     with Global => null, Post => Count <= 5
   is
   begin
      Count := 0;
      for K in 0 .. 4 loop
         pragma Loop_Invariant (Count = K);
         exit when S.Out_Reader = S.Out_Writer;
         S.Frame (7 + K) := S.Out_Data (S.Out_Reader);
         S.Out_Reader := (S.Out_Reader + 1) mod Hub_Buffer_Size;
         Count := Count + 1;
      end loop;
   end Append_SmartPort_Data;

   --  The X telemetry frame: transmitter id, RSSI and A1 in turn, the
   --  sequence marker answering the transmitter's, the data of a new or a
   --  resent sequence slot, and the CRC.
   procedure Build_X_Telemetry_Frame (S : in out State; C : Settings; Inp : Inputs)
     with Global => null
   is
      Marker : constant Unsigned_8 := S.Payload (21);
      Ack    : constant Sequence_Id := Natural (Interfaces.Shift_Right (Marker, 4) and 3);
      Count  : Natural;
      Crc    : Unsigned_16 := 0;
   begin
      S.Frame (0) := 16#0E#;
      S.Frame (1) := C.Bind_Tx_Id (0);
      S.Frame (2) := C.Bind_Tx_Id (1);
      S.Frame (3) := (if Is_V2 (C) then C.Bind_Tx_Id (2) else S.Payload (3));
      if S.Even_Run then
         S.Frame (4) := Unsigned_8 ((Integer (S.Radio.RSSI_Dbm) + 65_536) mod 256) or 16#80#;
      else
         S.Frame (4) :=
           (case C.A1 is
              when External_ADC    => Unsigned_8 ((Inp.ADC_External and 16#FE0#) / 32),
              when Constant_Value  => 50,
              when Battery_Voltage => Unsigned_8 (Inp.Legacy_Voltage and 16#7F#));
      end if;
      S.Even_Run := not S.Even_Run;
      if (Marker and 16#08#) /= 0 then
         S.Frame (5) := 16#88#;
         S.Local_Packet_Id := 0;
      elsif (Marker and 16#40#) /= 0 then
         S.Frame (5) := (S.Response and 16#F0#) or Unsigned_8 (Ack);
         for K in Telemetry_Data'Range loop
            S.Frame (6 + K) := S.Sent (Ack) (K);
         end loop;
      elsif S.Local_Packet_Id /= (Ack + 1) mod 4 then
         S.Frame (5) := (S.Response and 16#F0#) or Unsigned_8 (S.Local_Packet_Id);
         Append_SmartPort_Data (S, Count);
         S.Frame (6) := Unsigned_8 (Count);
         for K in Telemetry_Data'Range loop
            S.Sent (S.Local_Packet_Id) (K) := S.Frame (6 + K);
         end loop;
         S.Local_Packet_Id := (S.Local_Packet_Id + 1) mod 4;
      end if;
      for K in 3 .. 12 loop
         Crc := Crc_Step (Crc, S.Frame (K));
      end loop;
      S.Frame (13) := Unsigned_8 (Interfaces.Shift_Right (Crc, 8));
      S.Frame (14) := Unsigned_8 (Crc and 16#FF#);
   end Build_X_Telemetry_Frame;

   --  A valid packet's telemetry slot: stored by its sequence id, then either
   --  a resend request for the first missing slot or an acknowledgement of
   --  the slots received in order; five resend requests in a row reset the
   --  transport.
   procedure Take_Remote_Frame (S : in out State)
     with Global => null
   is
      New_Id  : constant Sequence_Id := Natural (S.Payload (21) and 3);
      To_Ack  : Sequence_Id := (S.Remote_Ack_Id + 1) mod 4;
      Next    : Sequence_Id;
      Resend  : Boolean := False;
   begin
      for K in Telemetry_Data'Range loop
         S.Remote (New_Id).Data (K) := S.Payload (22 + K);
      end loop;
      S.Remote (New_Id).Needs_Processing := True;
      S.Response := 0;
      if New_Id /= To_Ack then
         for Step in 1 .. 4 loop
            exit when To_Ack = New_Id;
            if not S.Remote (To_Ack).Needs_Processing then
               S.Response := Interfaces.Shift_Left (Unsigned_8 (To_Ack), 4) or 16#40#;
               Resend := True;
               if S.Retry_Count < 5 then
                  S.Retry_Count := S.Retry_Count + 1;
               end if;
               exit;
            end if;
            To_Ack := (To_Ack + 1) mod 4;
         end loop;
      end if;
      if not Resend then
         S.Retry_Count := 0;
         To_Ack := (S.Remote_Ack_Id + 1) mod 4;
         Next := To_Ack;
         for Step in 1 .. 4 loop
            exit when not S.Remote (To_Ack).Needs_Processing or else To_Ack = S.Remote_Ack_Id;
            Next := To_Ack;
            To_Ack := (To_Ack + 1) mod 4;
         end loop;
         S.Remote_Ack_Id := Next;
         S.Response := Interfaces.Shift_Left (Unsigned_8 (S.Remote_Ack_Id), 4);
      end if;
      if S.Retry_Count = 5 then
         S.Remote_Ack_Id := 3;
         for K in Sequence_Id loop
            S.Remote (K).Needs_Processing := False;
         end loop;
         S.Retry_Count := 0;
      end if;
   end Take_Remote_Frame;

   procedure X_Handle_Packet (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Result : out Received)
     with Global => null
   is
      Requested : Boolean;
      Since     : Integer_32;
   begin
      Result := None;
      case S.Protocol is
         when Starting =>
            S.List_Length := 47;
            Initialise_Data (C, O, False);
            S.Protocol := Update;
            Next_Channel (S, C, O, 1);
            Strobe (O, SRX);
         when Update | Data =>
            if S.Protocol = Update then
               S.Packet_Timer_Us := Inp.Now_Us;
               S.Protocol := Data;
               S.Frame_Received := False;
               S.Receive_Delay_Us := 5_300;
               Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, False, Requested);
               if Requested then
                  S.Packet_Timer_Us := 0;
                  S.Timeout_Us := 50;
                  S.Missing_Packets := 0;
                  S.Protocol := Init;
                  return;
               end if;
            end if;
            if Inp.Exti and then not S.Frame_Received
              and then Natural (Inp.Rx_Bytes and 16#7F#) >= S.Packet_Length
            then
               Read_Packet (S, Inp, O, S.Packet_Length);
               if Valid_X_Packet (S, C) then
                  S.Missing_Packets := 0;
                  S.Timeout_Us := 1;
                  S.Receive_Delay_Us := 0;
                  LED_On (O, C.Pins);
                  if S.Skip_Channels then
                     S.Channels_To_Skip :=
                       Interfaces.Shift_Left (S.Payload (5), 2) or Interfaces.Shift_Right (S.Payload (4), 6);
                     S.Telemetry_Received := True;
                     S.Skip_Channels := False;
                  end if;
                  Set_RSSI_Dbm (S.Radio, O, S.Payload (S.Packet_Length - 2));
                  Take_Remote_Frame (S);
                  S.Packet_Timer_Us := Inp.Now_Us;
                  S.Frame_Received := True;
               end if;
               if not S.Frame_Received then
                  S.Packet_Errors := S.Packet_Errors + 1;
                  Strobe (O, SFRX);
               end if;
            end if;
            Since := Adaflight.Clock.Elapsed (Inp.Now_Us, S.Packet_Timer_Us);
            if S.Telemetry_Received and then Since > S.Receive_Delay_Us then
               S.Protocol := Telemetry;
               Build_X_Telemetry_Frame (S, C, Inp);
            end if;
            if Integer (Since) > Integer (S.Timeout_Us) * Sync_Delay_Max then
               LED_Toggle (O, C.Pins);
               Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
               Next_Channel (S, C, O, 1);
               Strobe (O, SRX);
               S.Protocol := Update;
            end if;
            if S.Frame_Received then
               Result := Data_Ready;
               S.Frame_Received := False;
            end if;
         when Telemetry =>
            if Adaflight.Clock.Elapsed (Inp.Now_Us, S.Packet_Timer_Us) >= S.Receive_Delay_Us + S.Telemetry_Delay then
               Strobe (O, SIDLE);
               Add (O, (Kind => Set_Power, A => 6, others => <>));
               Strobe (O, SFRX);
               Add (O, (Kind => Delay_Us, Value => 30, others => <>));
               if C.Pins.Tx_Enable then
                  Set_Pin (O, Tx_Enable, True);
               end if;
               Strobe (O, SIDLE);
               O.Tx_Data := Tx_Bytes (S.Frame);
               Add (O, (Kind => Write_Fifo, A => S.Frame (0) + 1, others => <>));
               S.Protocol := Resume;
            end if;
         when Resume =>
            if Adaflight.Clock.Elapsed (Inp.Now_Us, S.Packet_Timer_Us) > S.Receive_Delay_Us + 3_700 then
               S.Packet_Timer_Us := Inp.Now_Us;
               S.Receive_Delay_Us := 5_300;
               S.Frame_Received := False;
               Next_Channel (S, C, O, S.Channels_To_Skip);
               Strobe (O, SRX);
               if C.Pins.Tx_Enable then
                  Set_Pin (O, Tx_Enable, False);
               end if;
               if S.Missing_Packets >= 2 then
                  Switch_Antennae (S.Radio, O);
               end if;
               if S.Missing_Packets > Max_Missing then
                  S.Timeout_Us := 50;
                  S.Skip_Channels := True;
                  S.Telemetry_Received := False;
                  S.Protocol := Update;
                  return;
               end if;
               S.Missing_Packets := S.Missing_Packets + 1;
               S.Protocol := Data;
            end if;
         when others =>
            null;
      end case;
   end X_Handle_Packet;

   -----------
   -- Start --
   -----------

   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean)
   is
      Pins_Ok : Boolean;
   begin
      S := (others => <>);
      O := (others => <>);
      Ok := False;
      Claim_RSSI := False;
      Adaflight.CC2500_Radio.Start (S.Radio, C.Pins, Inp.Bind_Pin_Level, Inp.Chip_Ok, O, Pins_Ok);
      if not Pins_Ok then
         return;
      end if;
      case C.Protocol is
         when FrSky_D =>
            S.Packet_Length := 20;
            S.Telemetry_Enabled := C.Telemetry and then Inp.Hub_Free;
         when FrSky_X =>
            S.Packet_Length := 32;
            S.Telemetry_Delay := 400;
         when FrSky_X_LBT =>
            S.Packet_Length := 35;
            S.Telemetry_Delay := 1_400;
         when FrSky_X_V2 =>
            S.Packet_Length := 32;
            S.Telemetry_Delay := 400;
         when FrSky_X_LBT_V2 =>
            S.Packet_Length := 32;
            S.Telemetry_Delay := 1_500;
      end case;
      Claim_RSSI := True;
      S.Missing_Packets := 0;
      S.Timeout_Us := 50;
      S.Start_Time_Ms := Inp.Now_Ms;
      S.Protocol := Init;
      Ok := True;
   end Start;

   ---------------------
   -- Set_Calibration --
   ---------------------

   procedure Set_Calibration (S : in out State; Table : Calibration_Table) is
   begin
      S.Cal := Table;
   end Set_Calibration;

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
      Found     : Boolean;
   begin
      O := (others => <>);
      Result := None;
      case S.Protocol is
         when Init =>
            if Inp.Now_Ms - S.Start_Time_Ms > 10 then
               Initialise (C, O);
               S.Protocol := Bind;
            end if;
         when Bind =>
            Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, True, Requested);
            if Requested or else C.Auto_Bind then
               LED_On (O, C.Pins);
               Init_Tune_Rx (S, Inp, O);
               S.Protocol := Bind_Tuning_Low;
            else
               S.Protocol := Starting;
            end if;
         when Bind_Tuning_Low =>
            Tune_Rx (S, C, Inp, 2, O, Found);
            if Found then
               S.Bind_Offset_Min := S.Bind_Offset;
               S.Bind_Offset := 126;
               S.Protocol := Bind_Tuning_High;
            end if;
         when Bind_Tuning_High =>
            Tune_Rx (S, C, Inp, -2, O, Found);
            if Found then
               S.Bind_Offset_Max := S.Bind_Offset;
               S.Bind_Offset := Integer_8 ((Integer (S.Bind_Offset_Max) + Integer (S.Bind_Offset_Min)) / 2);
               C.Bind_Offset := S.Bind_Offset;
               Init_Get_Bind (S, O);
               Initialise_Data (C, O, True);
               S.Protocol := (if S.Bind_Offset_Min < S.Bind_Offset_Max then Bind_Binding else Bind);
            end if;
         when Bind_Binding =>
            Get_Bind (S, C, Inp, O, Found);
            if Found then
               Strobe (O, SIDLE);
               S.Protocol := Bind_Complete;
            end if;
         when Bind_Complete =>
            if not C.Auto_Bind then
               Add (O, (Kind => Save_Config, others => <>));
            else
               for K in 1 .. 80 loop
                  LED_Toggle (O, C.Pins);
                  Add (O, (Kind => Delay_Ms, Value => 50, others => <>));
               end loop;
            end if;
            Result := Bind_Done;
            S.Protocol := Starting;
         when Starting .. Resume =>
            if C.Protocol = FrSky_D then
               D_Handle_Packet (S, C, Inp, O, Result);
            else
               X_Handle_Packet (S, C, Inp, O, Result);
            end if;
      end case;
   end Data_Received;

   -----------------
   -- Set_Rc_Data --
   -----------------

   procedure Set_X_Rc_Data (S : State; Rc : in out Channel_Values)
     with Global => null
   is
      P : Payload_Bytes renames S.Payload;
   begin
      if P (7) /= 0 then
         return;
      end if;
      for K in 0 .. 3 loop
         declare
            Low  : constant Natural := Natural (P (10 + 3 * K) and 16#0F#) * 256 + Natural (P (9 + 3 * K));
            High : constant Natural := Natural (P (11 + 3 * K)) * 16 mod 16#1000# + Natural (P (10 + 3 * K)) / 16;
         begin
            for J in 0 .. 1 loop
               declare
                  Word  : constant Natural := (if J = 0 then Low else High);
                  Value : constant Integer := Word mod 16#800#;
                  Index : constant Natural := 2 * K + J + (if Word >= 16#800# then 8 else 0);
               begin
                  Rc (Index) := Unsigned_16 (((Value - 64) * 2 + 860 * 3) / 3);
               end;
            end loop;
         end;
      end loop;
   end Set_X_Rc_Data;

   procedure Set_Rc_Data (S : in out State; C : Settings; Rc : in out Channel_Values) is
      Scaling  : constant Float := 2.0 / 3.0;
      Channels : Channel_Values := (others => 0);
      Error    : Boolean := False;

      function Scaled (Raw : Natural) return Unsigned_16 is
        (Unsigned_16 (Float'Truncation (Float (Raw) * Scaling)))
        with Pre => Raw <= 4_095;

      procedure Pair (First : Natural; Base : Payload_Index; High : Payload_Index)
        with Pre => First <= 6 and then Base <= Payload_Size - 2
      is
      begin
         Channels (First) := Scaled (Natural (S.Payload (High) and 16#0F#) * 256 + Natural (S.Payload (Base)));
         Channels (First + 1) := Scaled (Natural (S.Payload (High) and 16#F0#) * 16 + Natural (S.Payload (Base + 1)));
      end Pair;
   begin
      if C.Protocol /= FrSky_D then
         Set_X_Rc_Data (S, Rc);
         return;
      end if;
      Pair (0, 6, 10);
      Pair (2, 8, 11);
      Pair (4, 12, 16);
      Pair (6, 14, 17);
      for K in 0 .. 7 loop
         if Channels (K) < 800 or else Channels (K) > 2_200 then
            Error := True;
            exit;
         end if;
      end loop;
      if Error then
         S.Data_Errors := S.Data_Errors + 1;
      else
         Rc (0 .. 7) := Channels (0 .. 7);
      end if;
   end Set_Rc_Data;

end Adaflight.FrSky_SPI;
