with Adaflight.Clock;

package body Adaflight.SFHSS with SPARK_Mode is
   use Adaflight.CC2500_Radio;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;

   FSCTRL0 : constant := 16#0C#;
   FSCAL3  : constant := 16#23#;
   FSCAL2  : constant := 16#24#;
   FSCAL1  : constant := 16#25#;
   CHANNR  : constant := 16#0A#;

   Bind_Channel : constant := 15;
   Max_Missing  : constant := 100;
   Hunt_Hop_Us  : constant := 500_000;
   Sync_Hop_Us  : constant := 6_800;
   Low_Half_Us  : constant := 3_500;
   High_Half_Us : constant := 500;

   Config_1 : constant Register_List :=
     ((16#02#, 16#01#), (16#03#, 16#07#), (16#04#, 16#D3#), (16#05#, 16#91#), (16#06#, 16#0D#), (16#07#, 16#04#),
      (16#08#, 16#0C#), (16#09#, 16#29#), (16#0B#, 16#06#));

   Config_2 : constant Register_List :=
     ((16#0D#, 16#5C#), (16#0E#, 16#4E#), (16#0F#, 16#C4#), (16#10#, 16#7C#), (16#11#, 16#43#), (16#12#, 16#03#),
      (16#13#, 16#23#), (16#14#, 16#3B#), (16#15#, 16#44#), (16#17#, 16#0F#), (16#18#, 16#08#), (16#19#, 16#1D#),
      (16#1A#, 16#6C#), (16#1B#, 16#03#), (16#1C#, 16#40#), (16#1D#, 16#91#), (16#21#, 16#56#), (16#22#, 16#10#),
      (16#23#, 16#A9#), (16#24#, 16#0A#), (16#25#, 16#00#), (16#26#, 16#11#), (16#29#, 16#59#), (16#2C#, 16#88#),
      (16#2D#, 16#31#), (16#2E#, 16#0B#), (16#3E#, 16#FF#));

   function Packet_Channel (P : Packet_Bytes) return Natural is (Natural (P (5) / 8));

   function Packet_Code (P : Packet_Bytes) return Hop_Code is
     (Hop_Code (Natural (P (11) mod 8) * 4 + Natural (P (12) / 64)));

   function Carries_High_Half (P : Packet_Bytes) return Boolean is ((P (12) and 16#08#) /= 0);

   function Failsafe (P : Packet_Bytes) return Boolean is ((P (12) and 16#04#) /= 0);

   function After (Now, Due : Unsigned_32) return Boolean is (Adaflight.Clock.Elapsed (Now, Due) > 0);

   --  A sum as a signed byte holds it, wrapping above 127.
   function Wrap (V : Integer) return Integer_8 is (Integer_8 (if V > 127 then V - 256 else V))
     with Pre => V in -128 .. 383;

   procedure Initialise (C : Settings; O : in out Output)
     with Global => null
   is
   begin
      Add (O, (Kind => Reset, others => <>));
      Write_All (O, Config_1);
      Write (O, FSCTRL0, Byte_Of (C.Bind_Offset));
      Write_All (O, Config_2);
      Calibrate_Channels (O, Count => Calibrated_Channels, Step => 6, Base => 16);
   end Initialise;

   procedure Listen (S : State; O : in out Output)
     with Global => null
   is
      Cal : constant Calibration :=
        (if S.Channel < Calibrated_Channels then S.Cal (Natural (S.Channel)) else (others => 0));
   begin
      Strobe (O, SIDLE);
      Write (O, FSCAL3, Cal (0));
      Write (O, FSCAL2, Cal (1));
      Write (O, FSCAL1, Cal (2));
      Write (O, CHANNR, Unsigned_8 ((Natural (S.Channel) * 6 + 16) mod 256));
      Strobe (O, SFRX);
      Strobe (O, SRX);
   end Listen;

   procedure Receive (Packet : in out Packet_Bytes; Inp : Inputs; O : in out Output; Got : out Boolean)
     with Global => null
   is
   begin
      Got := False;
      if not Inp.Exti or else (Inp.Rx_Bytes and 16#7F#) < Packet_Length then
         return;
      end if;
      for K in Packet_Bytes'Range loop
         Packet (K) := Inp.Fifo (K);
      end loop;
      Add (O, (Kind => Read_Fifo, A => Packet_Length, others => <>));
      Got := True;
   end Receive;

   procedure Parse (S : in out State; C : Settings; Check_Tx_Id : Boolean; O : in out Output; Ok : out Boolean)
     with Global => null,
          Pre    => Hops_Valid (S),
          Post   => Hops_Valid (S) and then S.Offset_Min = S.Offset_Min'Old and then S.Offset_Max = S.Offset_Max'Old
   is
      P : constant Packet_Bytes := S.Packet;
   begin
      Ok := False;
      if (P (14) and 16#80#) = 0
        or else P (0) /= 16#81#
        or else Packet_Channel (P) /= Natural (S.Channel)
        or else (Check_Tx_Id and then (C.Bind_Tx_Id (0) /= P (1) or else C.Bind_Tx_Id (1) /= P (2)))
      then
         return;
      end if;
      Set_RSSI_Dbm (S.Radio, O, P (13));
      S.Code := Packet_Code (P);
      Ok := True;
   end Parse;

   procedure Next_Channel (S : in out State; O : in out Output)
     with Global => null,
          Pre    => Hops_Valid (S),
          Post   => Hops_Valid (S) and then S.Code = S.Code'Old
   is
      Step : constant Integer := Integer (S.Code) + 2;
      Ch   : Integer := Integer (S.Channel) + Step;
   begin
      if Ch > 127 then
         Ch := Ch - 256;
      end if;
      if Ch > 29 then
         Ch := Ch - 31;
      end if;
      pragma Assert (if Ch < 0 then Step >= 32 or else (Ch = -1 and then Step <= 30));
      pragma Assert (if Step <= 31 then Ch <= 31);
      while Ch < 0 loop
         pragma Loop_Invariant (Ch in -128 .. -1);
         pragma Loop_Invariant (Step >= 32 or else (Ch = -1 and then Step <= 30));
         pragma Loop_Variant (Increases => Ch);
         Ch := Ch + Step;
         if Ch > 29 then
            Ch := Ch - 31;
         end if;
      end loop;
      S.Channel := Hop_Channel (Ch);
      Listen (S, O);
   end Next_Channel;

   procedure Init_Tune (S : in out State; Now_Ms : Unsigned_32; O : in out Output)
     with Global => null, Post => Hops_Valid (S)
   is
   begin
      S.Time_Tuned_Ms := Now_Ms;
      S.Offset_Min := -64;
      Write (O, FSCTRL0, Byte_Of (S.Offset_Min));
      S.Channel := Bind_Channel;
      Listen (S, O);
   end Init_Tune;

   procedure Tune_1 (S : in out State; C : in out Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null, Pre => Hops_Valid (S), Post => Hops_Valid (S)
   is
      Got : Boolean;
      Ok  : Boolean;
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
      Receive (S.Packet, Inp, O, Got);
      if Got then
         Parse (S, C, False, O, Ok);
         if Ok and then (S.Packet (14) and 16#7F#) > 40 then
            C.Bind_Tx_Id := (S.Packet (1), S.Packet (2));
            S.Offset_Max := S.Offset_Min;
            Strobe (O, SRX);
            S.Time_Tuned_Ms := Inp.Now_Ms;
            Done := True;
            return;
         end if;
         Strobe (O, SRX);
      end if;
   end Tune_1;

   procedure Tune_2 (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null, Pre => Hops_Valid (S), Post => Hops_Valid (S)
   is
      Got : Boolean;
      Ok  : Boolean;
   begin
      Done := False;
      LED_Blink (S.Radio, C.Pins, O, Inp.Now_Ms, 100);
      if Inp.Now_Ms - S.Time_Tuned_Ms > 880 or else S.Offset_Max > 122 then
         S.Time_Tuned_Ms := Inp.Now_Ms;
         Write (O, FSCTRL0, Byte_Of (S.Offset_Min));
         Strobe (O, SRX);
         Done := True;
         return;
      end if;
      Receive (S.Packet, Inp, O, Got);
      if Got then
         Parse (S, C, True, O, Ok);
         if Ok then
            S.Time_Tuned_Ms := Inp.Now_Ms;
            S.Offset_Max := S.Offset_Max + 4;
            Write (O, FSCTRL0, Byte_Of (S.Offset_Max));
         end if;
         Strobe (O, SRX);
      end if;
   end Tune_2;

   procedure Tune_3 (S : in out State; C : Settings; Inp : Inputs; O : in out Output; Done : out Boolean)
     with Global => null, Pre => Hops_Valid (S), Post => Hops_Valid (S)
   is
      Got : Boolean;
      Ok  : Boolean;
   begin
      Done := False;
      LED_Blink (S.Radio, C.Pins, O, Inp.Now_Ms, 100);
      if Inp.Now_Ms - S.Time_Tuned_Ms > 880 or else S.Offset_Min < -122 then
         Done := True;
         return;
      end if;
      Receive (S.Packet, Inp, O, Got);
      if Got then
         Parse (S, C, True, O, Ok);
         if Ok then
            S.Time_Tuned_Ms := Inp.Now_Ms;
            S.Offset_Min := S.Offset_Min - 4;
            Write (O, FSCTRL0, Byte_Of (S.Offset_Min));
         end if;
         Strobe (O, SRX);
      end if;
   end Tune_3;

   -----------
   -- Start --
   -----------

   procedure Start
     (S : out State; C : Settings; Inp : Inputs; O : out Output; Ok : out Boolean; Claim_RSSI : out Boolean)
   is
   begin
      S := (others => <>);
      O := (others => <>);
      Adaflight.CC2500_Radio.Start (S.Radio, C.Pins, Inp.Bind_Pin_Level, Inp.Chip_Ok, O, Claim_RSSI);
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
      Done      : Boolean;
      Got       : Boolean;
      Ok        : Boolean;
   begin
      O := (others => <>);
      Result := None;
      case S.Protocol is
         when Init =>
            if Inp.Now_Ms - S.Start_Time_Ms > 10 then
               LED_Off (O, C.Pins);
               Initialise (C, O);
               S.Protocol := Bind;
            end if;
         when Bind =>
            Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, True, Requested);
            if Requested then
               LED_On (O, C.Pins);
               Init_Tune (S, Inp.Now_Ms, O);
               S.Protocol := Bind_Tuning_1;
            else
               S.Protocol := Hunt;
               Next_Channel (S, O);
               Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
               S.Next_Hop_Us := Inp.Now_Us + Hunt_Hop_Us;
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
               if Integer (S.Offset_Max) - Integer (S.Offset_Min) <= 2 then
                  Init_Tune (S, Inp.Now_Ms, O);
                  S.Protocol := Bind_Tuning_1;
               else
                  C.Bind_Offset := Integer_8 ((Integer (S.Offset_Max) + Integer (S.Offset_Min)) / 2);
                  S.Protocol := Bind_Complete;
               end if;
            end if;
         when Bind_Complete =>
            Add (O, (Kind => Save_Config, others => <>));
            Result := Bind_Done;
            S.Protocol := Init;
         when Hunt =>
            Receive (S.Packet, Inp, O, Got);
            if Got then
               Parse (S, C, True, O, Ok);
               if Ok and then Carries_High_Half (S.Packet) then
                  S.Missing_Packets := 0;
                  LED_On (O, C.Pins);
                  S.Low_Seen := True;
                  S.High_Seen := True;
                  S.Protocol := Sync;
                  S.Next_Hop_Us := Inp.Now_Us + High_Half_Us;
                  return;
               end if;
               Strobe (O, SRX);
            elsif After (Inp.Now_Us, S.Next_Hop_Us) then
               LED_Blink (S.Radio, C.Pins, O, Inp.Now_Ms, 500);
               Switch_Antennae (S.Radio, O);
               Next_Channel (S, O);
               S.Next_Hop_Us := S.Next_Hop_Us + Hunt_Hop_Us;
            else
               Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, False, Requested);
               if Requested then
                  S.Protocol := Init;
               end if;
            end if;
         when Sync =>
            Receive (S.Packet, Inp, O, Got);
            if Got then
               Parse (S, C, True, O, Ok);
               if Ok then
                  S.Missing_Packets := 0;
                  if Carries_High_Half (S.Packet) then
                     S.Next_Hop_Us := Inp.Now_Us + High_Half_Us;
                     S.High_Seen := True;
                  else
                     S.Next_Hop_Us := Inp.Now_Us + Low_Half_Us;
                     Strobe (O, SRX);
                     S.Low_Seen := True;
                  end if;
                  if not Failsafe (S.Packet) then
                     Result := Data_Ready;
                  end if;
                  return;
               end if;
               Strobe (O, SRX);
            elsif After (Inp.Now_Us, S.Next_Hop_Us) then
               S.Next_Hop_Us := S.Next_Hop_Us + Sync_Hop_Us;
               if not S.Low_Seen and then not S.High_Seen then
                  S.Missing_Packets := S.Missing_Packets + 1;
                  if S.Missing_Packets > Max_Missing then
                     S.Protocol := Hunt;
                     Next_Channel (S, O);
                     Add (O, (Kind => Set_RSSI_Direct, Value => 0, others => <>));
                     S.Next_Hop_Us := Inp.Now_Us + Hunt_Hop_Us;
                     return;
                  end if;
                  if S.Missing_Packets >= 2 then
                     Switch_Antennae (S.Radio, O);
                  end if;
               end if;
               S.Low_Seen := False;
               S.High_Seen := False;
               Next_Channel (S, O);
            else
               Check_Bind_Requested (S.Radio, C.Pins, Inp.Bind_Pin_Level, False, Requested);
               if Requested then
                  S.Protocol := Init;
               end if;
            end if;
      end case;
   end Data_Received;

   -----------------
   -- Set_Rc_Data --
   -----------------

   procedure Set_Rc_Data (S : State; Rc : in out Channel_Values) is
      P     : Packet_Bytes renames S.Packet;
      First : constant Natural := (if Carries_High_Half (P) then 4 else 0);
   begin
      Rc (First) := Unsigned_16 (P (5) mod 8) * 512 + Unsigned_16 (P (6)) * 2 + Unsigned_16 (P (7) / 128);
      Rc (First + 1) := Unsigned_16 (P (7) mod 128) * 32 + Unsigned_16 (P (8) / 8);
      Rc (First + 2) := Unsigned_16 (P (8) mod 8) * 512 + Unsigned_16 (P (9)) * 2 + Unsigned_16 (P (10) / 128);
      Rc (First + 3) := Unsigned_16 (P (10) mod 128) * 32 + Unsigned_16 (P (11) / 8);
   end Set_Rc_Data;

end Adaflight.SFHSS;
