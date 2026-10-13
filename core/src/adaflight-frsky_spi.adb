with Adaflight.Clock;

package body Adaflight.FrSky_SPI with SPARK_Mode is
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;

   SIDLE : constant := 16#36#;
   SRX   : constant := 16#34#;
   SFRX  : constant := 16#3A#;

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

   Packet_Length   : constant := 20;
   Sync_Delay_Max  : constant := 9_000;
   Max_Missing     : constant := 100;

   type Register_Value is record
      Register : Unsigned_8;
      Value    : Unsigned_8;
   end record;
   type Register_List is array (Positive range <>) of Register_Value;

   Base_Config : constant Register_List :=
     ((16#02#, 16#01#), (16#18#, 16#18#), (16#07#, 16#05#), (16#3E#, 16#FF#), (16#0C#, 16#00#), (16#0D#, 16#5C#),
      (16#13#, 16#23#), (16#14#, 16#7A#), (16#19#, 16#16#), (16#1A#, 16#6C#), (16#1B#, 16#03#), (16#1C#, 16#40#),
      (16#1D#, 16#91#), (16#21#, 16#56#), (16#22#, 16#10#), (16#23#, 16#A9#), (16#24#, 16#0A#), (16#25#, 16#00#),
      (16#26#, 16#11#), (16#29#, 16#59#), (16#2C#, 16#88#), (16#2D#, 16#31#), (16#2E#, 16#0B#), (16#03#, 16#07#),
      (16#09#, 16#00#));

   D_Config : constant Register_List :=
     ((16#17#, 16#0C#), (16#0E#, 16#76#), (16#0F#, 16#27#), (16#06#, 16#19#), (16#08#, 16#05#), (16#0B#, 16#08#),
      (16#10#, 16#AA#), (16#11#, 16#39#), (16#12#, 16#11#), (16#15#, 16#42#));

   procedure Add (O : in out Output; Item : Op)
     with Global => null, Post => O.Count = Natural'Min (O.Count'Old + 1, Max_Ops)
   is
   begin
      if O.Count < Max_Ops then
         O.Count := O.Count + 1;
         O.Ops (O.Count) := Item;
      end if;
   end Add;

   procedure Strobe (O : in out Output; Command : Unsigned_8)
     with Global => null
   is
   begin
      Add (O, (Kind => Strobe, A => Command, others => <>));
   end Strobe;

   procedure Write (O : in out Output; Register, Value : Unsigned_8)
     with Global => null
   is
   begin
      Add (O, (Kind => Write_Register, A => Register, B => Value, others => <>));
   end Write;

   procedure Set_Pin (O : in out Output; On : Pin; High : Boolean)
     with Global => null
   is
   begin
      Add (O, (Kind => (if High then Pin_High else Pin_Low), On => On, others => <>));
   end Set_Pin;

   procedure LED_On (O : in out Output; C : Settings)
     with Global => null
   is
   begin
      if C.LED_Pin then
         Set_Pin (O, LED, not C.LED_Inversion);
      end if;
   end LED_On;

   procedure LED_Toggle (O : in out Output; C : Settings)
     with Global => null
   is
   begin
      if C.LED_Pin then
         Add (O, (Kind => Pin_Toggle, On => LED, others => <>));
      end if;
   end LED_Toggle;

   function Byte_Of (V : Integer_8) return Unsigned_8 is
     (if V >= 0 then Unsigned_8 (V) else Unsigned_8 (Integer (V) + 256));

   --  A bind request: a falling edge on the bind pin raises one, and a check
   --  that resets takes it.
   procedure Check_Bind_Requested
     (S : in out State; C : Settings; Inp : Inputs; Reset : Boolean; Requested : out Boolean)
     with Global => null
   is
   begin
      if C.Bind_Pin then
         if S.Last_Bind_Pin and then not Inp.Bind_Pin_Level then
            S.Bind_Requested := True;
         end if;
         S.Last_Bind_Pin := Inp.Bind_Pin_Level;
      end if;
      Requested := S.Bind_Requested;
      if Requested and then Reset then
         S.Bind_Requested := False;
      end if;
   end Check_Bind_Requested;

   procedure Read_Packet (S : in out State; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      for K in 0 .. Packet_Length - 1 loop
         S.Payload (K) := Inp.Fifo (K);
      end loop;
      Add (O, (Kind => Read_Fifo, A => Packet_Length, others => <>));
   end Read_Packet;

   function Valid_Bind_Packet (P : Payload_Bytes) return Boolean is
     ((P (Packet_Length - 1) and 16#80#) /= 0
      and then P (0) = Packet_Length - 3 and then P (1) = 16#03# and then P (2) = 16#01#);

   procedure Initialise (O : in out Output)
     with Global => null
   is
   begin
      Add (O, (Kind => Startup_Speed, others => <>));
      Add (O, (Kind => Reset, others => <>));
      for R of Base_Config loop
         Write (O, R.Register, R.Value);
      end loop;
      for R of D_Config loop
         Write (O, R.Register, R.Value);
      end loop;
      Add (O, (Kind => Calibrate, others => <>));
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
   procedure Tune_Rx (S : in out State; Inp : Inputs; Inc : Integer; O : in out Output; Found : out Boolean)
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
      if Inp.Exti and then (Inp.Rx_Bytes and 16#7F#) >= Packet_Length then
         Read_Packet (S, Inp, O);
         Found := Valid_Bind_Packet (S.Payload);
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

   --  A chunk of the hop table from a bind packet, the transmitter id from
   --  the first; complete with all ten chunks.
   procedure Get_Bind (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null
   is
      Index : Natural;
   begin
      Done := False;
      if not Inp.Exti or else (Inp.Rx_Bytes and 16#7F#) < Packet_Length then
         return;
      end if;
      Read_Packet (S, Inp, O);
      if not Valid_Bind_Packet (S.Payload) then
         return;
      end if;
      if S.Payload (5) = 0 then
         C.Bind_Tx_Id (0) := S.Payload (3);
         C.Bind_Tx_Id (1) := S.Payload (4);
         C.Bind_Tx_Id (2) := S.Payload (17);
         C.Rx_Num := 0;
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
      Strobe (O, SFRX);
   end Next_Channel;

   procedure Set_RSSI_Dbm (S : in out State; O : in out Output; Value : Unsigned_8)
     with Global => null
   is
      Scaled : constant Integer := (Integer (Value) * 18) / 32;
   begin
      S.RSSI_Dbm := Integer_16 (if Value >= 128 then Scaled - 82 else Scaled + 65);
      Add (O, (Kind => Set_RSSI, Value => Unsigned_16 ((Integer (S.RSSI_Dbm) * 8) mod 65_536), others => <>));
   end Set_RSSI_Dbm;

   procedure Switch_Antennae (S : in out State; C : Settings; O : in out Output)
     with Global => null
   is
   begin
      if C.Antenna_Pin then
         Set_Pin (O, Antenna_Select, not S.Other_Antenna);
         S.Other_Antenna := not S.Other_Antenna;
      end if;
   end Switch_Antennae;

   procedure Build_Telemetry_Frame (S : in out State; C : Settings; Inp : Inputs)
     with Global => null
   is
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
      S.Frame (5) := Unsigned_8 ((Integer (S.RSSI_Dbm) + 65_536) mod 256);
      S.Frame (6) := 0;
      S.Frame (7) := S.Payload (4);
   end Build_Telemetry_Frame;

   procedure Handle_Packet (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Result : out Received)
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
               Check_Bind_Requested (S, C, Inp, False, Requested);
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
               if (Inp.Rx_Bytes and 16#7F#) >= Packet_Length then
                  Read_Packet (S, Inp, O);
                  if (S.Payload (19) and 16#80#) /= 0 then
                     Packet_Ok := True;
                     S.Missing_Packets := 0;
                     S.Timeout_Us := 1;
                     if S.Payload (0) = 16#11# and then S.Payload (1) = C.Bind_Tx_Id (0)
                       and then S.Payload (2) = C.Bind_Tx_Id (1) and then S.Payload (5) = C.Bind_Tx_Id (2)
                     then
                        LED_On (O, C);
                        Next_Channel (S, C, O, 1);
                        Set_RSSI_Dbm (S, O, S.Payload (18));
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
               if C.Tx_Enable_Pin then
                  Set_Pin (O, Tx_Enable, False);
               end if;
               if S.Timeout_Us = 1 then
                  if S.Missing_Packets >= 2 then
                     Switch_Antennae (S, C, O);
                  end if;
                  if S.Missing_Packets > Max_Missing then
                     S.Timeout_Us := 50;
                     Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
                  end if;
                  S.Missing_Packets := S.Missing_Packets + 1;
                  Next_Channel (S, C, O, 1);
               else
                  LED_Toggle (O, C);
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
               if C.Tx_Enable_Pin then
                  Set_Pin (O, Tx_Enable, True);
               end if;
               Strobe (O, SIDLE);
               O.Fifo_Data := S.Frame;
               Add (O, (Kind => Write_Fifo, A => S.Frame (0) + 1, others => <>));
               S.Protocol := Data;
               S.Last_Packet_Us := Current;
            end if;
         when others =>
            null;
      end case;
   end Handle_Packet;

   -----------
   -- Start --
   -----------

   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean)
   is
   begin
      S := (others => <>);
      O := (others => <>);
      Ok := False;
      Claim_RSSI := False;
      if C.LED_Pin then
         Set_Pin (O, LED, C.LED_Inversion);
      end if;
      if C.Bind_Pin then
         S.Last_Bind_Pin := Inp.Bind_Pin_Level;
      end if;
      if C.Chip_Detect then
         Add (O, (Kind => Reset, others => <>));
         if not Inp.Chip_Ok then
            return;
         end if;
      end if;
      if C.LNA_Pin then
         Set_Pin (O, LNA_Enable, True);
      end if;
      if C.Antenna_Pin then
         Set_Pin (O, Antenna_Select, True);
      end if;
      if C.Tx_Enable_Pin then
         Set_Pin (O, Tx_Enable, False);
      end if;
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
      S.Bind_Requested := True;
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
               Initialise (O);
               S.Protocol := Bind;
            end if;
         when Bind =>
            Check_Bind_Requested (S, C, Inp, True, Requested);
            if Requested or else C.Auto_Bind then
               LED_On (O, C);
               Init_Tune_Rx (S, Inp, O);
               S.Protocol := Bind_Tuning_Low;
            else
               S.Protocol := Starting;
            end if;
         when Bind_Tuning_Low =>
            Tune_Rx (S, Inp, 2, O, Found);
            if Found then
               S.Bind_Offset_Min := S.Bind_Offset;
               S.Bind_Offset := 126;
               S.Protocol := Bind_Tuning_High;
            end if;
         when Bind_Tuning_High =>
            Tune_Rx (S, Inp, -2, O, Found);
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
                  LED_Toggle (O, C);
                  Add (O, (Kind => Delay_Ms, Value => 50, others => <>));
               end loop;
            end if;
            Result := Bind_Done;
            S.Protocol := Starting;
         when Starting .. Resume =>
            Handle_Packet (S, C, Inp, O, Result);
      end case;
   end Data_Received;

   -----------------
   -- Set_Rc_Data --
   -----------------

   procedure Set_Rc_Data (S : in out State; Rc : in out Channel_Values) is
      Scaling  : constant Float := 2.0 / 3.0;
      Channels : Channel_Values := (others => 0);
      Error    : Boolean := False;

      function Scaled (Raw : Natural) return Unsigned_16 is
        (Unsigned_16 (Float'Truncation (Float (Raw) * Scaling)))
        with Pre => Raw <= 4_095;

      procedure Pair (First : Natural; Base : Payload_Index; High : Payload_Index)
        with Pre => First <= Channel_Count - 2 and then Base <= Payload_Size - 2
      is
      begin
         Channels (First) := Scaled (Natural (S.Payload (High) and 16#0F#) * 256 + Natural (S.Payload (Base)));
         Channels (First + 1) := Scaled (Natural (S.Payload (High) and 16#F0#) * 16 + Natural (S.Payload (Base + 1)));
      end Pair;
   begin
      Pair (0, 6, 10);
      Pair (2, 8, 11);
      Pair (4, 12, 16);
      Pair (6, 14, 17);
      for K in Channels'Range loop
         if Channels (K) < 800 or else Channels (K) > 2_200 then
            Error := True;
            exit;
         end if;
      end loop;
      if Error then
         S.Data_Errors := S.Data_Errors + 1;
      else
         Rc := Channels;
      end if;
   end Set_Rc_Data;

end Adaflight.FrSky_SPI;
