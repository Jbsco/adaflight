with Adaflight.Clock;

package body Adaflight.Redpine with SPARK_Mode is
   use Adaflight.SPI_Radio;
   use type Interfaces.Unsigned_16;

   FSCTRL0  : constant := 16#0C#;
   PKTCTRL1 : constant := 16#07#;
   MCSM0    : constant := 16#18#;
   FSCAL3   : constant := 16#23#;
   FSCAL2   : constant := 16#24#;
   FSCAL1   : constant := 16#25#;
   CHANNR   : constant := 16#0A#;

   Mode_Switch_Us : constant := 2_000_000;
   Default_Loop   : constant := 50_000;

   Base_Config : constant Register_List :=
     ((16#02#, 16#01#), (16#03#, 16#07#), (16#06#, 16#0B#), (16#07#, 16#0C#), (16#08#, 16#05#), (16#09#, 16#00#));

   Fast_Config : constant Register_List :=
     ((16#0B#, 16#0A#), (16#0C#, 16#00#), (16#0D#, 16#5D#), (16#0E#, 16#93#), (16#0F#, 16#B1#), (16#10#, 16#2D#),
      (16#11#, 16#3B#), (16#12#, 16#73#), (16#13#, 16#23#), (16#14#, 16#56#), (16#15#, 16#00#), (16#17#, 16#0C#),
      (16#18#, 16#08#), (16#19#, 16#1D#), (16#1A#, 16#1C#), (16#1B#, 16#C7#), (16#1C#, 16#00#), (16#1D#, 16#B0#),
      (16#21#, 16#B6#), (16#22#, 16#10#), (16#23#, 16#EA#), (16#24#, 16#0A#), (16#25#, 16#00#), (16#26#, 16#11#),
      (16#29#, 16#59#), (16#2C#, 16#88#), (16#2D#, 16#31#), (16#2E#, 16#0B#), (16#3E#, 16#FF#));

   Slow_Config : constant Register_List :=
     ((16#0B#, 16#06#), (16#0C#, 16#00#), (16#0D#, 16#5D#), (16#0E#, 16#93#), (16#0F#, 16#B1#), (16#10#, 16#78#),
      (16#11#, 16#93#), (16#12#, 16#03#), (16#13#, 16#22#), (16#14#, 16#F8#), (16#15#, 16#44#), (16#17#, 16#0C#),
      (16#18#, 16#08#), (16#19#, 16#16#), (16#1A#, 16#6C#), (16#1B#, 16#43#), (16#1C#, 16#40#), (16#1D#, 16#91#),
      (16#21#, 16#56#), (16#22#, 16#10#), (16#23#, 16#A9#), (16#24#, 16#0A#), (16#25#, 16#00#), (16#26#, 16#11#),
      (16#29#, 16#59#), (16#2C#, 16#88#), (16#2D#, 16#31#), (16#2E#, 16#0B#), (16#3E#, 16#FF#));

   function After (Now, Since : Unsigned_32; Limit : Integer_32) return Boolean is
     (Adaflight.Clock.Elapsed (Now, Since) > Limit);

   --  A sum as a signed byte holds it, wrapping above 127.
   function Wrap (V : Integer) return Integer_8 is (Integer_8 (if V > 127 then V - 256 else V))
     with Pre => V in -128 .. 383;

   procedure Initialise (S : State; O : in out Output)
     with Global => null
   is
   begin
      Add (O, (Kind => Reset, others => <>));
      Write_All (O, Base_Config);
      if S.Fast then
         Write_All (O, Fast_Config);
      else
         Write_All (O, Slow_Config);
      end if;
      Calibrate_Channels (O, Count => Calibrated_Channels, Step => 1, Base => 0);
   end Initialise;

   procedure Tune_To (S : State; Channel : Unsigned_8; O : in out Output)
     with Global => null
   is
      Cal : constant Calibration :=
        (if Channel < Calibrated_Channels then S.Cal (Natural (Channel)) else (others => 0));
   begin
      Write (O, FSCAL3, Cal (0));
      Write (O, FSCAL2, Cal (1));
      Write (O, FSCAL1, Cal (2));
      Write (O, CHANNR, Channel);
   end Tune_To;

   procedure Next_Channel (S : in out State; C : Settings; O : in out Output)
     with Global => null
   is
   begin
      S.Hop_Index := (if S.Hop_Index = Hop_Channels - 1 then 0 else S.Hop_Index + 1);
      Strobe (O, SIDLE);
      Tune_To (S, C.Bind_Hop_Data (S.Hop_Index), O);
   end Next_Channel;

   procedure Init_Bind_Tune (S : in out State; C : in out Settings; Now_Ms : Unsigned_32; O : in out Output)
     with Global => null
   is
   begin
      S.Time_Tuned_Ms := Now_Ms;
      S.Offset_Min := -64;
      Write (O, FSCTRL0, Byte_Of (S.Offset_Min));
      Write (O, PKTCTRL1, 16#0C#);
      Write (O, MCSM0, 16#08#);
      Strobe (O, SIDLE);
      Tune_To (S, 0, O);
      Strobe (O, SFRX);
      Strobe (O, SRX);
      for I in 0 .. Hop_Channels - 1 loop
         C.Bind_Hop_Data (I) := 0;
      end loop;
   end Init_Bind_Tune;

   procedure Read_Packet (Packet : out Packet_Bytes; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      for K in Packet_Bytes'Range loop
         Packet (K) := Inp.Fifo (K);
      end loop;
      Add (O, (Kind => Read_Fifo, A => Packet_Length, others => <>));
   end Read_Packet;

   procedure Bind_Packet (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Got : out Boolean)
     with Global => null, Post => S.Offset_Min = S.Offset_Min'Old and then S.Offset_Max = S.Offset_Max'Old
   is
   begin
      Got := False;
      if not Inp.Exti then
         return;
      end if;
      if (Inp.Rx_Bytes and 16#7F#) /= Packet_Length then
         Strobe (O, SFRX);
         return;
      end if;
      Read_Packet (S.Packet, Inp, O);
      if S.Packet (1) = 16#03# and then S.Packet (2) = 16#01# then
         C.Bind_Tx_Id := (S.Packet (3), S.Packet (4));
         for N in 0 .. 4 loop
            if Natural (S.Packet (5)) + N <= Hop_Table'Last then
               C.Bind_Hop_Data (Natural (S.Packet (5)) + N) := S.Packet (6 + N);
            end if;
         end loop;
         Got := True;
      end if;
   end Bind_Packet;

   procedure Tune_1 (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null
   is
      Got : Boolean;
   begin
      Done := False;
      if S.Offset_Min >= 126 then
         S.Offset_Min := -126;
      end if;
      if Inp.Now_Ms - S.Time_Tuned_Ms > 220 then
         S.Time_Tuned_Ms := Inp.Now_Ms;
         S.Offset_Min := Wrap (Integer (S.Offset_Min) + 16);
         Write (O, FSCTRL0, Byte_Of (S.Offset_Min));
         Strobe (O, SRX);
      end if;
      Bind_Packet (S, C, Inp, O, Got);
      if Got then
         S.Offset_Max := S.Offset_Min;
         Strobe (O, SRX);
         S.Time_Tuned_Ms := Inp.Now_Ms;
         Done := True;
      end if;
   end Tune_1;

   procedure Tune_2 (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null
   is
      Got : Boolean;
   begin
      Done := False;
      LED_Blink (S.Radio, C.Pins, O, Inp.Now_Ms, 100);
      if Inp.Now_Ms - S.Time_Tuned_Ms > 880 or else S.Offset_Max > 124 then
         S.Time_Tuned_Ms := Inp.Now_Ms;
         Write (O, FSCTRL0, Byte_Of (S.Offset_Min));
         Strobe (O, SRX);
         Done := True;
         return;
      end if;
      Bind_Packet (S, C, Inp, O, Got);
      if Got then
         S.Time_Tuned_Ms := Inp.Now_Ms;
         S.Offset_Max := S.Offset_Max + 2;
         Write (O, FSCTRL0, Byte_Of (S.Offset_Max));
      end if;
   end Tune_2;

   procedure Tune_3 (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null
   is
      Got : Boolean;
   begin
      Done := False;
      LED_Blink (S.Radio, C.Pins, O, Inp.Now_Ms, 100);
      if Inp.Now_Ms - S.Time_Tuned_Ms > 880 or else S.Offset_Min < -124 then
         Done := True;
         return;
      end if;
      Bind_Packet (S, C, Inp, O, Got);
      if Got then
         S.Time_Tuned_Ms := Inp.Now_Ms;
         S.Offset_Min := S.Offset_Min - 2;
         Write (O, FSCTRL0, Byte_Of (S.Offset_Min));
      end if;
   end Tune_3;

   procedure Handle_Packet
     (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Result : in out Received)
     with Global => null, Pre => S.Protocol in Starting | Update | Data
   is
      Requested : Boolean;
   begin
      if S.Protocol = Starting then
         S.Protocol := Update;
         Next_Channel (S, C, O);
         Strobe (O, SRX);
         if C.Pins.Tx_Enable then
            Set_Pin (O, Tx_Enable, False);
         end if;
         S.Protocol_Timer_Us := Inp.Now_Us;
         return;
      end if;
      if S.Protocol = Update then
         S.Packet_Timer_Us := 0;
         S.Total_Timer_Us := Inp.Now_Us;
         S.Protocol := Data;
         Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, False, Requested);
         if Requested then
            S.Packet_Timer_Us := 0;
            S.Missing_Packets := 0;
            S.Protocol := Init;
            return;
         end if;
      end if;
      if Inp.Exti then
         if (Inp.Rx_Bytes and 16#7F#) = Packet_Length then
            Read_Packet (S.Packet, Inp, O);
            if S.Packet (1) = C.Bind_Tx_Id (0) and then S.Packet (2) = C.Bind_Tx_Id (1) then
               S.Loop_Time_Us := Integer_32 (S.Packet (10)) * (if S.Fast then 100 else 1_000);
               S.Packet_Timer_Us := Inp.Now_Us + Unsigned_32 (S.Loop_Time_Us / 8);
               S.Total_Timer_Us := Inp.Now_Us;
               S.Protocol_Timer_Us := Inp.Now_Us;
               S.Missing_Packets := 0;
               LED_On (O, C.Pins);
               Set_RSSI_Dbm (S.Radio, O, S.Packet (11));
               Result := Data_Ready;
               Next_Channel (S, C, O);
               Strobe (O, SRX);
            end if;
         else
            Strobe (O, SFRX);
         end if;
      end if;
      if After (Inp.Now_Us, S.Total_Timer_Us, 50 * S.Loop_Time_Us) then
         LED_Toggle (O, C.Pins);
         Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
         Next_Channel (S, C, O);
         Strobe (O, SRX);
         S.Protocol := Update;
      elsif After (Inp.Now_Us, S.Packet_Timer_Us, S.Loop_Time_Us) and then S.Packet_Timer_Us /= 0 then
         S.Packet_Timer_Us := Inp.Now_Us;
         Next_Channel (S, C, O);
         Strobe (O, SRX);
         S.Missing_Packets := S.Missing_Packets + 1;
         if S.Missing_Packets >= 2 then
            Switch_Antennae (S.Radio, O);
         end if;
      elsif After (Inp.Now_Us, S.Protocol_Timer_Us, Mode_Switch_Us) then
         S.Fast := not S.Fast;
         S.Loop_Time_Us := Default_Loop;
         S.Protocol_Timer_Us := Inp.Now_Us;
         S.Protocol := Init;
      end if;
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
      Adaflight.SPI_Radio.Start (S.Radio, C.Pins, Inp.Bind_Pin_Level, Inp.Chip_Ok, O, Ok);
      Claim_RSSI := Ok;
      if not Ok then
         return;
      end if;
      S.Missing_Packets := 0;
      S.Start_Time_Ms := Inp.Now_Ms;
      S.Protocol := Init;
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
      Done      : Boolean;
   begin
      O := (others => <>);
      Result := None;
      case S.Protocol is
         when Init =>
            if Inp.Now_Ms - S.Start_Time_Ms > 10 then
               Initialise (S, O);
               S.Protocol := Bind;
            end if;
         when Bind =>
            Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, True, Requested);
            if Requested or else C.Auto_Bind then
               S.Fast := True;
               Initialise (S, O);
               LED_On (O, C.Pins);
               Init_Bind_Tune (S, C, Inp.Now_Ms, O);
               S.Protocol := Bind_Tuning_1;
            else
               S.Protocol := Starting;
            end if;
         when Bind_Tuning_1 =>
            Tune_1 (S, C, Inp, O, Done);
            if Done then
               S.Protocol := Bind_Tuning_2;
            end if;
         when Bind_Tuning_2 =>
            Tune_2 (S, C, Inp, O, Done);
            if Done then
               S.Protocol := Bind_Tuning_3;
            end if;
         when Bind_Tuning_3 =>
            Tune_3 (S, C, Inp, O, Done);
            if Done then
               if Integer (S.Offset_Max) - Integer (S.Offset_Min) <= 10 then
                  Init_Bind_Tune (S, C, Inp.Now_Ms, O);
                  S.Protocol := Bind_Tuning_1;
               else
                  C.Bind_Offset := Integer_8 ((Integer (S.Offset_Max) + Integer (S.Offset_Min)) / 2);
                  S.Protocol := Bind_Complete;
                  Strobe (O, SIDLE);
                  for I in 0 .. Hop_Channels - 1 loop
                     if C.Bind_Hop_Data (I) = 0 then
                        S.Protocol := Bind_Tuning_1;
                        exit;
                     end if;
                  end loop;
               end if;
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
         when Starting | Update | Data =>
            Handle_Packet (S, C, Inp, O, Result);
      end case;
   end Data_Received;

   -----------------
   -- Set_Rc_Data --
   -----------------

   procedure Set_Rc_Data (S : State; Armed : Boolean; Rc : in out Channel_Values; VTX : out VTX_Request) is
      P : Packet_Bytes renames S.Packet;

      function Scale (V : Unsigned_16) return Unsigned_16 is ((2 * V + 2_452) / 3)
        with Pre => V <= 2_047;

      function Switch (B : Unsigned_8; Mask : Unsigned_8) return Unsigned_16 is
        (if (B and Mask) /= 0 then 2_000 else 1_000);
   begin
      VTX := (others => <>);
      if P (3) = 1 and then P (4) = 0 then
         if not Armed then
            VTX := (Present => True, Band => P (5) + 1, Channel => P (6), Power => P (7));
         end if;
         return;
      end if;
      Rc (0) := Scale (Unsigned_16 (P (4) and 7) * 256 + Unsigned_16 (P (3)));
      Rc (1) := Scale (Unsigned_16 (P (5) and 16#7F#) * 16 + Unsigned_16 (P (4) / 16));
      Rc (2) := Scale (Unsigned_16 (P (7) and 7) * 256 + Unsigned_16 (P (6)));
      Rc (3) := Scale (Unsigned_16 (P (8) and 16#7F#) * 16 + Unsigned_16 (P (7) / 16));
      Rc (4) := Switch (P (4), 16#08#);
      Rc (5) := Switch (P (5), 16#80#);
      Rc (6) := Switch (P (7), 16#08#);
      Rc (7) := Switch (P (8), 16#80#);
      for K in 0 .. 7 loop
         Rc (8 + K) := Switch (P (9), 2 ** K);
      end loop;
   end Set_Rc_Data;

end Adaflight.Redpine;
