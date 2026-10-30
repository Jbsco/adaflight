with Adaflight.Timer_Tables;

package body Adaflight.DShot_Bitbang with SPARK_Mode is

   procedure Init (B : in out Port_Buffer; Port_Mask : Unsigned_16; Inverted : Boolean) is
      Mask      : constant Unsigned_32 := Unsigned_32 (Port_Mask);
      Reset_Bit : constant Unsigned_32 := (if Inverted then Mask else Shift_Left (Mask, 16));
      Set_Bit   : constant Unsigned_32 := (if Inverted then Shift_Left (Mask, 16) else Mask);
      Hold      : constant := Frame_Bits * States_Per_Bit;
   begin
      for S in 0 .. Frame_Bits - 1 loop
         B (S * States_Per_Bit) := B (S * States_Per_Bit) or Set_Bit;
         B (S * States_Per_Bit + 1) := 0;
         B (S * States_Per_Bit + 2) := B (S * States_Per_Bit + 2) or Reset_Bit;
      end loop;
      B (Hold) := B (Hold) or Reset_Bit;
      B (Hold + 1) := 0;
      B (Hold + 2) := 0;
   end Init;

   procedure Set (B : in out Port_Buffer; Pin : Pin_Number; Value : Unsigned_16; Inverted : Boolean) is
      Middle : constant Unsigned_32 := Shift_Left (1, (if Inverted then Pin else Pin + 16));
      V      : Unsigned_16 := Value;
   begin
      for Pos in 0 .. Frame_Bits - 1 loop
         if (V and 16#8000#) = 0 then
            B (Pos * States_Per_Bit + 1) := B (Pos * States_Per_Bit + 1) or Middle;
         end if;
         V := Shift_Left (V, 1);
      end loop;
   end Set;

   procedure Clear (B : in out Port_Buffer) is
   begin
      for Pos in 0 .. Frame_Bits - 1 loop
         B (Pos * States_Per_Bit + 1) := 0;
      end loop;
   end Clear;

   procedure Read_Replies
     (T : in out Adaflight.DShot.Telemetry; Counts : in out Adaflight.DShot.Read_Counts;
      Q : in out Adaflight.DShot.Qualities; D : in out Adaflight.DShot.Edge_Decoder; Ports : in out Port_Inputs;
      Used_Ports : Port_Total; Motors : Motor_Pins; Count : Adaflight.DShot.Motor_Total; Use_Telemetry : Boolean;
      Commands : Adaflight.DShot.Command_List; Now_Us : Adaflight.DShot.Time_Us; Now_Ms : Adaflight.DShot.Time_Ms)
   is
      package S renames Adaflight.DShot;
      Raw : Unsigned_32;
   begin
      if not Use_Telemetry then
         return;
      end if;
      for M in 0 .. Count - 1 loop
         if not Ports (Motors (M).Port).Aborted then
            S.Decode_Samples (D, Ports (Motors (M).Port).Buffer, Ports (Motors (M).Port).Count, Motors (M).Pin, Now_Us,
                              Raw);
            if Raw /= S.No_Edge then
               Counts.Reads := Counts.Reads + 1;
               if Raw /= S.Invalid_Value then
                  if Raw = S.Extended_Acknowledge and then Commands (M) = S.Extended_Telemetry_Enable then
                     T.Motors (M).Received := S.State_Events_Bit;
                  else
                     T.Motors (M).Raw := S.Raw_Value (Raw);
                  end if;
               else
                  Counts.Invalids := Counts.Invalids + 1;
               end if;
               S.Count_Packet (Q (M), Raw /= S.Invalid_Value, Now_Ms);
            end if;
         end if;
      end loop;
      T.State := S.Not_Processed;
      for P in 0 .. Used_Ports - 1 loop
         Ports (P).Aborted := False;
         pragma Loop_Invariant (for all K in 0 .. P => not Ports (K).Aborted);
      end loop;
   end Read_Replies;

   --  Whether a map owner holds a channel of the timer.
   function Timer_Held (T : Adaflight.Timer_Allocation.Table; Timer : Positive) return Boolean
     with Global => null
   is
      K : Natural;
   begin
      for E in Adaflight.Timer_Allocation.Slot loop
         K := Adaflight.Timer_Allocation.Channel_Of (T, E);
         if T.Owners (E).Held and then K > 0 and then Adaflight.Timer_Tables.Channels (K).Timer = Timer then
            return True;
         end if;
      end loop;
      return False;
   end Timer_Held;

   --  The periods of the output states and the input samples in timer
   --  counts, the time the replies may take, and the frame's time.
   procedure Set_Periods (S : in out Setup; Protocol : Unsigned_8; Clock : Unsigned_32)
     with Global => null
   is
      Output_Hz : constant Unsigned_32 :=
        (case Protocol is when 7 => 1_800_000, when 6 => 900_000, when others => 450_000);
      Input_Hz  : constant Unsigned_32 := Output_Hz * 30 / 24;
   begin
      S.Frame_Us := 51_000_000 / Output_Hz;
      S.Output_Period := Clock / Output_Hz - 1;
      S.Input_Period := Clock / Input_Hz - 1;
      S.Timeout_Us := Integer_32 (140_000_000 / Input_Hz) * 5 / 4;
   end Set_Periods;

   procedure Configure
     (S : out Setup; T : Adaflight.Timer_Allocation.Table; Busy : Stream_Flags; Taken : Pin_Flags;
      Count : Adaflight.DShot.Motor_Total; Tags : Tag_List; Order : Order_List; Choice : Unsigned_8;
      Telemetry : Boolean; Inversion : Boolean; Protocol : Unsigned_8; Clock : Unsigned_32)
   is
      Owned       : Pin_Flags := (others => False);
      Tag         : Unsigned_8;
      K           : Natural;
      Flags       : Unsigned_8;
      Conflict    : Boolean;
      Found       : Boolean;
      Group       : Port_Index;
      Timer       : Port_Index;
      Row         : Pacer_Row;
      Ports_Used  : Port_Total := 0;
      Pacers_Used : Port_Total := 0;
   begin
      S := (Init_OK => False, Status => OK, Used_Ports => 0, Used_Pacers => 0, Timers => (others => <>),
            Ports => (others => <>), Motors => (others => <>), Streams => (others => 0), Output_Period => 0,
            Input_Period => 0, Timeout_Us => 0, Frame_Us => 0);
      for M in 0 .. Count - 1 loop
         Tag := Tags (Order (M));
         K := Adaflight.Timer_Allocation.Configured_Channel (T, Tag);
         if K = 0 then
            S.Status := Motor_Pin_Conflict;
            return;
         end if;
         Flags := (if Adaflight.Timer_Tables.Channels (K).N then 2 else 0);
         if Inversion then
            Flags := Flags xor 1;
         end if;
         if Telemetry then
            Flags := Flags xor 1;
         end if;
         if Taken (Tag) or else Owned (Tag) then
            S.Status := Motor_Pin_Conflict;
            return;
         end if;
         S.Motors (M).Tag := Tag;
         S.Motors (M).Pin := Pin_Number (Tag mod 16);
         S.Motors (M).Output := Flags;
         Owned (Tag) := True;
         pragma Loop_Invariant (S.Used_Ports = 0 and then S.Used_Pacers = 0);
      end loop;
      S.Init_OK := True;

      for Slot in Port_Index loop
         for R in Pacers'Range loop
            if not ((Choice = 1 and then Pacers (R).Timer /= 1) or else (Choice = 2 and then Pacers (R).Timer /= 8))
            then
               Conflict := Timer_Held (T, Pacers (R).Timer);
               for E in 0 .. Slot - 1 loop
                  Row := S.Ports (E).Pacer;
                  if Row > 0 and then Pacers (Row).Timer = Pacers (R).Timer
                    and then Pacers (Row).Channel = Pacers (R).Channel
                  then
                     Conflict := True;
                  end if;
               end loop;
               if not Conflict and then not Busy (Pacers (R).Stream) then
                  S.Ports (Slot).Pacer := R;
                  exit;
               end if;
            end if;
         end loop;
         pragma Loop_Invariant (S.Used_Ports = 0 and then S.Used_Pacers = 0);
      end loop;

      for M in 0 .. Count - 1 loop
         pragma Loop_Invariant (Pacers_Used <= Ports_Used);
         Tag := S.Motors (M).Tag;
         Found := False;
         Group := 0;
         for P in 0 .. Ports_Used - 1 loop
            if S.Ports (P).Port = Tag / 16 then
               Group := P;
               Found := True;
               exit;
            end if;
         end loop;
         if not Found then
            if Ports_Used = Max_Ports then
               S.Status := Too_Many_Ports;
               exit;
            end if;
            Group := Ports_Used;
            Row := S.Ports (Group).Pacer;
            if Row = 0 then
               S.Status := No_Pacer;
               exit;
            end if;
            S.Ports (Group).Port := Tag / 16;
            S.Ports (Group).Allocated := True;
            Ports_Used := Ports_Used + 1;
            S.Ports (Group).Stream := Pacers (Row).Stream;
            exit when S.Streams (Pacers (Row).Stream) /= 0;
            S.Streams (Pacers (Row).Stream) := Tag / 16;
            Set_Periods (S, Protocol, Clock);
            Found := False;
            Timer := 0;
            for I in 0 .. Pacers_Used - 1 loop
               if S.Timers (I).Timer = Pacers (Row).Timer then
                  Timer := I;
                  Found := True;
                  exit;
               end if;
            end loop;
            if not Found then
               Timer := Pacers_Used;
               S.Timers (Timer).Timer := Pacers (Row).Timer;
               Pacers_Used := Pacers_Used + 1;
            end if;
            S.Timers (Timer).Requests := S.Timers (Timer).Requests or Shift_Left (16#0200#, Pacers (Row).Channel - 1);
         end if;
         S.Motors (M).Group := Group;
         S.Motors (M).Configured := True;
         S.Motors (M).Enabled := True;
      end loop;
      S.Used_Ports := Ports_Used;
      S.Used_Pacers := Pacers_Used;
   end Configure;

   function Pacer_Owner (S : Setup; Timer : Positive; Channel : Positive) return Unsigned_8 is
      Row : Pacer_Row;
   begin
      for P in 0 .. S.Used_Ports - 1 loop
         Row := S.Ports (P).Pacer;
         if S.Ports (P).Allocated and then Row > 0 and then Pacers (Row).Timer = Timer
           and then Pacers (Row).Channel = Channel
         then
            return S.Ports (P).Port;
         end if;
      end loop;
      return 0;
   end Pacer_Owner;

end Adaflight.DShot_Bitbang;
