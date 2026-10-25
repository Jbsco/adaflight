package body Adaflight.ExpressLRS_Receiver with SPARK_Mode is
   use Adaflight.ExpressLRS;
   use Adaflight.Filters;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_16;
   package Tlm renames Adaflight.ExpressLRS_Telemetry;

   Packet_RC   : constant Byte := 0;
   Packet_MSP  : constant Byte := 1;
   Packet_Sync : constant Byte := 2;
   Packet_Tlm  : constant Byte := 3;

   MSP_Bind                    : constant Byte := 16#09#;
   MSP_Model_Id                : constant Byte := 16#0A#;
   MSP_Set_RX_Config           : constant Byte := 45;
   MSP_Command_Index           : constant := 7;
   Model_Match_Mask            : constant Byte := 16#3F#;
   OTA_Version                 : constant := 3;
   Mode_Cycle_Multiplier_Slow  : constant := 10;
   Config_Check_Ms             : constant := 200;
   Link_Stats_Check_Ms         : constant := 100;
   Consider_Connection_Good_Ms : constant := 1_000;
   Telem_Min_Link_Interval     : constant := 512;
   Packet_To_Tock_Delay_Us     : constant := 250;
   RSSI_Channel                : constant := 15;
   LQ_Channel                  : constant := 14;
   Arm_Channel                 : constant := 4;

   Binding_UID : constant UID_Bytes := (0, 1, 2, 3, 4, 5);

   --  A value truncated to a signed byte as the reference's assignment does.
   function To_Int8 (V : Integer_32) return Integer_8 is
     (if Byte'Mod (V) >= 128 then Integer_8 (Integer (Byte'Mod (V)) - 256) else Integer_8 (Byte'Mod (V)));

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function Wrapped_Difference (A, B : Unsigned_32) return Integer_32 is (To_Signed (A - B));

   --  An arithmetic shift right of a signed value, as the reference's
   --  compiler shifts.
   function Shift_Right_Arith (V : Integer_32; N : Natural) return Integer_32 is
     (To_Signed (Interfaces.Shift_Right_Arithmetic (Unsigned_32'Mod (V), N)))
     with Pre => N <= 31;

   function Is_2400 (R : Receiver) return Boolean is (Band_Of (R.Domain) = Band_2400);

   function Mod_Of (R : Receiver) return Mod_Settings is
     (if Is_2400 (R) then Rates_2400 (R.Rate) else Rates_900 (R.Rate));

   function Perf_Of (R : Receiver) return Perf_Params is
     (if Is_2400 (R) then Perf_2400 (R.Rate) else Perf_900 (R.Rate));

   function Rate_Count (R : Receiver) return Positive is (if Is_2400 (R) then 6 else 4);

   -------------------
   -- The timer side --
   -------------------

   procedure Set_Period (T : in out Timer; Period : Unsigned_32) is
   begin
      T.Period := Period;
      T.Period_Count := T.Period_Count + 1;
   end Set_Period;

   --  The time base and the half-period for an interval, the phase shift
   --  bounded to a half-period.
   procedure Timer_Set_Interval (T : in out Timer; Interval : Interval_Us) is
   begin
      T.Interval := Interval;
      T.Max_Period := (Interval / 2) + (Interval / 4);
      Set_Period (T, Unsigned_32 (Interval / 2) - 1);
   end Timer_Set_Interval;

   procedure Timer_Set_Phase_Shift (T : in out Timer; Shift : Integer_32) is
      Limit : constant Integer_32 := Integer_32 (T.Interval / 2);
   begin
      T.Phase_Shift_Us := Integer_32'Max (-Limit, Integer_32'Min (Limit, Shift));
   end Timer_Set_Phase_Shift;

   procedure Timer_Stop (T : in out Timer) is
   begin
      T.Counter_Resets := T.Counter_Resets + 1;
      T.Running := False;
   end Timer_Stop;

   procedure Timer_Resume (T : in out Timer) is
   begin
      T.Phase := Tock;
      Set_Period (T, Unsigned_32 (T.Interval / 2));
      T.Counter_Resets := T.Counter_Resets + 1;
      T.Running := True;
   end Timer_Resume;

   ------------------------
   -- The mean of the SNR --
   ------------------------

   procedure Mean_Add (M : in out Mean_Accumulator; V : Integer_8) is
   begin
      if M.Count < Mean_Samples_Max then
         M.Count := M.Count + 1;
         M.Sum := M.Sum + Integer_32 (V);
      end if;
   end Mean_Add;

   procedure Mean_Take (M : in out Mean_Accumulator; Default : Integer_8; Result : out Integer_8) is
   begin
      if M.Count > 0 then
         Result := Integer_8 (M.Sum / Integer_32 (M.Count));
         M := (Sum => 0, Count => 0);
      else
         Result := Default;
      end if;
   end Mean_Take;

   ----------------------
   -- The phase lock --
   ----------------------

   procedure Phase_Lock_Reset (R : in out Receiver) is
   begin
      Simple_Lowpass_Init (R.Lock.Offset_Filter, 2, 5);
      Simple_Lowpass_Init (R.Lock.Offset_Dx_Filter, 4, 5);
      R.Events := (others => <>);
   end Phase_Lock_Reset;

   function Both_Events (R : Receiver) return Boolean is (R.Events.Internal_Seen and then R.Events.External_Seen);

   function Event_Result (R : Receiver) return Integer_32 is
     (if Both_Events (R) then Wrapped_Difference (R.Events.External_Us, R.Events.Internal_Us) else 0);

   procedure Timer_Frequency_Offset_Step (T : in out Timer; Up : Boolean) is
   begin
      if Up and then T.Frequency_Offset_Ticks < Integer_32'Last then
         T.Frequency_Offset_Ticks := T.Frequency_Offset_Ticks + 1;
      elsif not Up and then T.Frequency_Offset_Ticks > Integer_32'First then
         T.Frequency_Offset_Ticks := T.Frequency_Offset_Ticks - 1;
      end if;
   end Timer_Frequency_Offset_Step;

   procedure Update_Phase_Lock (R : in out Receiver) is
      Filtered : Simple_Input;
   begin
      if R.Connection /= Disconnected and then Both_Events (R) then
         declare
            Max_Offset : constant Integer_32 := Integer_32 (Mod_Of (R).Interval_Us / 4);
            Raw        : constant Integer_32 := Event_Result (R);
         begin
            R.Lock.Raw_Offset_Us := Integer_32'Max (-Max_Offset, Integer_32'Min (Max_Offset, Raw));
         end;
         Simple_Lowpass_Update (R.Lock.Offset_Filter, R.Lock.Raw_Offset_Us, Filtered);
         R.Lock.Offset_Us := Filtered;
         Simple_Lowpass_Update (R.Lock.Offset_Dx_Filter, R.Lock.Raw_Offset_Us - R.Lock.Previous_Raw_Offset_Us,
                                Filtered);
         R.Lock.Offset_Delta_Us := Filtered;
         R.Lock.Previous_Raw_Offset_Us := R.Lock.Raw_Offset_Us;
         if R.Timer_St = Timer_Locked and then R.Nonce mod 8 = 0 then
            if R.Lock.Offset_Us > 0 then
               Timer_Frequency_Offset_Step (R.Timing, Up => True);
            elsif R.Lock.Offset_Us < 0 then
               Timer_Frequency_Offset_Step (R.Timing, Up => False);
            end if;
         end if;
         if R.Connection /= Connected then
            Timer_Set_Phase_Shift (R.Timing, Shift_Right_Arith (R.Lock.Raw_Offset_Us, 1));
         else
            Timer_Set_Phase_Shift (R.Timing, Shift_Right_Arith (R.Lock.Offset_Us, 2));
         end if;
      end if;
      R.Events := (others => <>);
   end Update_Phase_Lock;

   -----------------------
   -- The radio requests --
   -----------------------

   procedure Start_Receiving (R : in out Receiver) is
   begin
      R.Start_Count := R.Start_Count + 1;
   end Start_Receiving;

   procedure Set_RF_Link_Rate (R : in out Receiver; Index : Rate_Index)
     with Pre => Rate_Valid (R.Domain, Index), Post => R.Domain = R.Domain'Old
   is
      M : Mod_Settings;
   begin
      R.Rate := Index;
      M := Mod_Of (R);
      R.Current_Freq := Initial_Frequency (R.Hops, R.Freq_Offset);
      R.Cycle_Interval_Ms := Unsigned_16'Mod
        ((11 * Unsigned_32 (Entry_Count (R.Hops)) * Unsigned_32 (M.Hop_Interval) * Unsigned_32 (M.Interval_Us))
         / (10 * 1_000));
      R.Config := (Bandwidth      => M.Bandwidth,
                   Spreading      => M.Spreading,
                   Coding         => M.Coding,
                   Frequency      => R.Current_Freq,
                   Preamble       => Byte (M.Preamble),
                   IQ_Inverted    => R.In_Binding_Mode or else (R.UID (5) and 1) /= 0,
                   FLRC_Sync_Word => UID_Seed (R.UID),
                   FLRC_CRC_Seed  => R.CRC_Initializer,
                   Is_FLRC        => M.Radio = SX128x_FLRC);
      R.Config_Count := R.Config_Count + 1;
      if R.Domain = CE2400 then
         R.Power_Count := R.Power_Count + 1;
      end if;
      Timer_Set_Interval (R.Timing, Interval_Us (M.Interval_Us));
      Simple_Lowpass_Init (R.RSSI_Filter, 2, 5);
      Simple_Lowpass_Init (R.RSNR_Filter, 2, 5);
      R.Next_Rate := Index;
      R.Burst_Valid := False;
      R.RF_Mode_Report := Byte (RF_Rate'Pos (M.Rate));
   end Set_RF_Link_Rate;

   procedure Update_CRC_Init (R : in out Receiver) is
   begin
      if R.In_Binding_Mode then
         R.CRC_Initializer := 0;
      else
         R.CRC_Initializer := (Interfaces.Shift_Left (Unsigned_16 (R.UID (4)), 8) or Unsigned_16 (R.UID (5)))
           xor OTA_Version;
      end if;
   end Update_CRC_Init;

   --------------------------
   -- The connection states --
   --------------------------

   procedure Lost_Connection (R : in out Receiver) is
   begin
      R.Lost_Connections := R.Lost_Connections + 1;
      R.RF_Mode_Cycle_Multiplier := 1;
      R.Connection := Disconnected;
      R.Timer_St := Timer_Disconnected;
      R.Timing.Frequency_Offset_Ticks := 0;
      R.Freq_Offset := 0;
      R.Lock.Offset_Us := 0;
      R.Lock.Offset_Delta_Us := 0;
      R.Lock.Raw_Offset_Us := 0;
      R.Lock.Previous_Raw_Offset_Us := 0;
      R.Got_Connection_Ms := 0;
      R.Uplink_LQ := 0;
      Reset (R.LQ);
      Phase_Lock_Reset (R);
      R.Already_Telem_Resp := False;
      R.Already_FHSS := False;
      if not R.In_Binding_Mode then
         Timer_Stop (R.Timing);
         Set_RF_Link_Rate (R, R.Next_Rate);
         Start_Receiving (R);
      end if;
   end Lost_Connection;

   procedure Tentative_Connection (R : in out Receiver; Now_Ms : Unsigned_32) is
   begin
      R.Connection := Tentative;
      R.Timer_St := Timer_Disconnected;
      R.Freq_Offset := 0;
      R.Lock.Offset_Us := 0;
      R.Lock.Previous_Raw_Offset_Us := 0;
      Phase_Lock_Reset (R);
      R.SNR_Mean := (Sum => 0, Count => 0);
      R.RF_Mode_Cycled_At_Ms := Now_Ms;
   end Tentative_Connection;

   procedure Got_Connection (R : in out Receiver; C : in out Settings; Now_Ms : Unsigned_32) is
   begin
      if R.Connection = Connected then
         return;
      end if;
      R.Lock_RF_Mode := True;
      R.Connection := Connected;
      R.Timer_St := Timer_Tentative;
      R.Got_Connection_Ms := Now_Ms;
      if C.Rate /= R.Next_Rate then
         C.Rate := R.Next_Rate;
         R.Config_Changed := True;
      end if;
   end Got_Connection;

   procedure Initialize (R : in out Receiver; C : Settings; Now_Ms : Unsigned_32)
     with Pre => Rate_Valid (C.Domain, C.Rate) and then C.Domain = R.Domain, Post => R.Domain = R.Domain'Old
   is
   begin
      Generate (R.Hops, UID_Seed (R.UID), C.Domain);
      Reset (R.LQ);
      R.Nonce := 0;
      R.Freq_Offset := 0;
      R.Config_Changed := False;
      R.RSSI := 0;
      R.RSSI_Filtered := 0;
      R.RSNR_Filtered := 0;
      R.SNR := 0;
      R.Uplink_LQ := 0;
      R.Switch_Mode := 0;
      Set_RF_Link_Rate (R, (if R.In_Binding_Mode then R.Binding_Rate else C.Rate));
      R.Started := False;
      R.Already_FHSS := False;
      R.Already_Telem_Resp := False;
      R.Lock_RF_Mode := False;
      R.Timer_St := Timer_Disconnected;
      R.Connection := Disconnected;
      R.RF_Mode_Cycled_At_Ms := Now_Ms;
      R.Config_Checked_At_Ms := Now_Ms;
      R.Stats_Updated_At_Ms := Now_Ms;
      R.Got_Connection_Ms := Now_Ms;
      R.Last_Sync_Packet_Ms := Now_Ms;
      R.Last_Valid_Packet_Ms := Now_Ms;
      R.RF_Mode_Cycle_Multiplier := Mode_Cycle_Multiplier_Slow / 2;
   end Initialize;

   ----------
   -- Init --
   ----------

   procedure Init (R : out Receiver; C : Settings; Now_Ms : Unsigned_32) is
   begin
      R := (Domain => C.Domain, others => <>);
      R.Binding_Rate := (if Is_2400 (R) then 5 else 2);
      if (for some I in C.UID'Range => C.UID (I) /= 0) then
         R.In_Binding_Mode := False;
         R.UID := C.UID;
      else
         R.In_Binding_Mode := True;
         R.UID := Binding_UID;
      end if;
      Update_CRC_Init (R);
      Phase_Lock_Reset (R);
      Timer_Set_Interval (R.Timing, 20_000);
      Timer_Stop (R.Timing);
      Initialize (R, C, Now_Ms);
      Tlm.Reset_Sender (R.Sender);
      Tlm.Set_Receive_Length (R.MSP, Tlm.MSP_Buffer_Size);
   end Init;

   ---------------------------
   -- The packets' contents --
   ---------------------------

   procedure Unpack_Analog (P : Packet; RC : in out Channels) is
      Merged   : Natural := 0;
      Value    : Unsigned_32 := 0;
      Position : Natural := 1;
   begin
      for N in 0 .. 3 loop
         pragma Loop_Invariant (Position in 1 .. 6 and then Merged <= 15 and then Value < 2 ** 16
                                and then Merged = 8 * (Position - 1) - 10 * N);
         while Merged < 10 loop
            pragma Loop_Invariant (Position in 1 .. 5 and then Merged <= 15 and then Value < 2 ** 16
                                   and then Merged = 8 * (Position - 1) - 10 * N);
            Value := Value or Interfaces.Shift_Left (Unsigned_32 (P (Position)), Merged);
            Position := Position + 1;
            Merged := Merged + 8;
         end loop;
         RC (N) := 988 + Unsigned_16 (Value and 16#3FF#);
         Value := Interfaces.Shift_Right (Value, 10);
         Merged := Merged - 10;
      end loop;
      RC (Arm_Channel) := Unsigned_16 (Switch_1b (Natural (Interfaces.Shift_Right (P (6), 7))));
   end Unpack_Analog;

   --  The range scaling of Adaflight.Maths over small operands, so its
   --  bounds are visible here.
   subtype Scale_Operand is Integer_32 range -2 ** 12 .. 2 ** 12;
   function Scaled (Value, Src_From, Src_To, Dest_From, Dest_To : Scale_Operand) return Integer_32 is
     ((Dest_To - Dest_From) * (Value - Src_From) / (Src_To - Src_From) + Dest_From)
     with Pre => Src_From < Src_To and then Value >= Src_From;

   procedure Set_RSSI_Channels (R : Receiver; RC : in out Channels) is
      Sensitivity : constant Integer_32 := Integer_32 (Perf_Of (R).Sensitivity_Dbm);
      Clamped     : constant Integer_32 :=
        Integer_32'Max (Sensitivity, Integer_32'Min (-50, Integer_32 (R.RSSI_Filtered)));
   begin
      RC (LQ_Channel) := Unsigned_16 (Scaled (Integer_32 (R.Uplink_LQ), 0, 100, 988, 2_011));
      RC (RSSI_Channel) := Unsigned_16 (Scaled (Clamped, Sensitivity, -50, 988, 2_011));
   end Set_RSSI_Channels;

   procedure Unpack_Hybrid_8 (R : Receiver; P : Packet; RC : in out Channels) is
      Switch_Byte  : constant Byte := P (6) and 16#7F#;
      Switch_Index : constant Natural := Natural (Interfaces.Shift_Right (Switch_Byte and 16#38#, 3));
   begin
      Unpack_Analog (P, RC);
      if Switch_Index >= 6 then
         RC (11) := Unsigned_16 (Switch_Nb (Natural (Switch_Byte and 16#0F#), 15));
      else
         RC (5 + Switch_Index) := Unsigned_16 (Switch_3b (Natural (Switch_Byte and 16#07#)));
      end if;
      Set_RSSI_Channels (R, RC);
   end Unpack_Hybrid_8;

   procedure Unpack_Hybrid_Wide (R : in out Receiver; P : Packet; RC : in out Channels) is
      Switch_Byte : constant Byte := P (6) and 16#7F#;
   begin
      Unpack_Analog (P, RC);
      if R.Wide_Switch_Index = 7 then
         R.Tx_Power := Switch_Byte and 16#3F#;
      elsif R.Tlm_Denom < 2 or else R.Tlm_Denom > 4 then
         RC (5 + R.Wide_Switch_Index) := Unsigned_16 (Switch_Nb (Natural (Switch_Byte and 16#7F#), 127));
      else
         RC (5 + R.Wide_Switch_Index) := Unsigned_16 (Switch_Nb (Natural (Switch_Byte and 16#3F#), 63));
      end if;
      Set_RSSI_Channels (R, RC);
   end Unpack_Hybrid_Wide;

   function Min_LQ_For_Chaos (R : Receiver) return Natural is
      Entries  : constant Natural := Entry_Count (R.Hops);
      Interval : constant Natural := Mod_Of (R).Hop_Interval;
   begin
      return Interval * ((Interval * Entries + 99) / (Interval * Entries));
   end Min_LQ_For_Chaos;

   procedure Unpack_Bind (R : in out Receiver; C : in out Settings; P : Packet) is
   begin
      C.UID := (0, 0, P (3), P (4), P (5), P (6));
      R.UID := C.UID;
      R.In_Binding_Mode := False;
      Update_CRC_Init (R);
      R.Config_Changed := True;
   end Unpack_Bind;

   procedure Process_MSP (R : in out Receiver; C : in out Settings; P : Packet) is
      Package_Index  : constant Byte := P (1);
      Chunk          : constant Tlm.Chunk := P (2 .. 6);
      Confirm_Before : Boolean;
   begin
      if R.In_Binding_Mode and then Package_Index = 1 and then P (2) = MSP_Bind then
         Unpack_Bind (R, C, P);
         return;
      end if;
      if R.Connection /= Connected then
         return;
      end if;
      Confirm_Before := R.MSP.Confirm;
      Tlm.Receive (R.MSP, Package_Index, Chunk);
      if Confirm_Before /= R.MSP.Confirm then
         R.Next_Telemetry := Link;
      end if;
      if Tlm.Has_Finished (R.MSP) then
         if R.MSP.Data (MSP_Command_Index) = MSP_Set_RX_Config
           and then R.MSP.Data (MSP_Command_Index + 1) = MSP_Model_Id
         then
            if C.Model_Id /= R.MSP.Data (9) then
               C.Model_Id := R.MSP.Data (9);
               R.Config_Changed := True;
               R.Connection := Disconnect_Pending;
            end if;
         elsif R.Model_Match then
            R.MSP_Frame := R.MSP.Data;
            R.MSP_Ready_Count := R.MSP_Ready_Count + 1;
         end if;
         Tlm.Unlock (R.MSP);
      end if;
   end Process_MSP;

   procedure Process_Sync (R : in out Receiver; C : Settings; P : Packet; Now_Ms : Unsigned_32;
                           Start_Timer : out Boolean) is
      Nonce      : constant Byte := P (2);
      Switch_Enc : constant Byte := P (3) and 1;
      Tlm_Ratio  : constant Natural := Natural (Interfaces.Shift_Right (P (3), 1) and 7);
      Air_Rate   : constant Natural := Natural (Interfaces.Shift_Right (P (3), 4));
      Model_Xor  : constant Byte := (not C.Model_Id) and Model_Match_Mask;
      Denom      : Byte;
   begin
      Start_Timer := False;
      if P (4) /= R.UID (3) or else P (5) /= R.UID (4) then
         return;
      end if;
      if (P (6) and not Model_Match_Mask) /= (R.UID (5) and not Model_Match_Mask) then
         return;
      end if;
      R.Last_Sync_Packet_Ms := Now_Ms;
      R.Next_Rate := (if Is_2400 (R) then Rate_Index_2400 (Air_Rate, R.Rate) else Rate_Index_900 (Air_Rate, R.Rate));
      R.Switch_Mode := Switch_Enc;
      Denom := Ratio_Value (Telemetry_Ratio'Val (Tlm_Ratio + Telemetry_Ratio'Pos (No_Telemetry)));
      if R.Tlm_Denom /= Denom then
         R.Tlm_Denom := Denom;
         R.Burst_Valid := False;
      end if;
      declare
         Model_Matched : constant Boolean := P (6) = (R.UID (5) xor Model_Xor);
      begin
         if R.Connection = Disconnected or else R.Nonce /= Nonce or else Byte (R.Hops.Index) /= P (1)
           or else R.Model_Match /= Model_Matched
         then
            Set_Index (R.Hops, P (1));
            R.Nonce := Nonce;
            Tentative_Connection (R, Now_Ms);
            R.Model_Match := Model_Matched;
            if not R.Timing.Running then
               Start_Timer := True;
            end if;
         end if;
      end;
   end Process_Sync;

   --  The CRC over the first seven bytes with the type kept and the high
   --  CRC bits replaced: by the hop slot and one for a channels packet in
   --  the wide switch mode, by zero otherwise.
   --  The first byte as the reference rewrites it in place before the check.
   function Checked_First_Byte (R : Receiver; P : Packet) return Byte is
      Kind : constant Byte := P (0) and 3;
      High : constant Byte :=
        (if Kind = Packet_RC and then R.Switch_Mode = 0 then Byte (Natural (R.Nonce) mod Mod_Of (R).Hop_Interval + 1)
         else 0);
   begin
      return Kind or Interfaces.Shift_Left (High, 2);
   end Checked_First_Byte;

   function Valid_CRC (R : Receiver; P : Packet) return Boolean is
      In_CRC : constant Unsigned_16 :=
        Interfaces.Shift_Left (Unsigned_16 (Interfaces.Shift_Right (P (0), 2)), 8) or Unsigned_16 (P (7));
      Data   : Byte_Array (0 .. 6) := P (0 .. 6);
   begin
      Data (0) := Checked_First_Byte (R, P);
      return In_CRC = Unsigned_16 (CRC14 (Data, R.CRC_Initializer));
   end Valid_CRC;

   --------------------
   -- Process_Packet --
   --------------------

   procedure Process_Packet (R : in out Receiver; C : in out Settings; P : Packet; Time_Stamp_Us : Unsigned_32;
                             Now_Ms : Unsigned_32; RSSI, SNR : Integer_8; Payload : in out Packet;
                             Status : out Packet_Status) is
      Kind        : constant Byte := P (0) and 3;
      Start_Timer : Boolean := False;
   begin
      Status := None;
      R.Packet_St := None;
      if not Valid_CRC (R, P) then
         return;
      end if;
      R.Events.External_Us := Time_Stamp_Us + Packet_To_Tock_Delay_Us;
      R.Events.External_Seen := True;
      R.Last_Valid_Packet_Ms := Now_Ms;
      case Kind is
         when Packet_RC =>
            if R.Connection = Connected and then R.Model_Match then
               if R.Switch_Mode = 0 then
                  R.Wide_Switch_Index := Hybrid_Wide_Switch_Index (R.Nonce);
                  if (R.Tlm_Denom > 1 and then R.Tlm_Denom < 8) or else R.Wide_Switch_Index = 7 then
                     Tlm.Confirm (R.Sender, (P (6) and 16#40#) /= 0);
                  end if;
               else
                  Tlm.Confirm (R.Sender, (P (6) and 16#40#) /= 0);
               end if;
               Payload := P;
               Payload (0) := Checked_First_Byte (R, P);
            end if;
         when Packet_MSP =>
            Process_MSP (R, C, P);
         when Packet_Sync =>
            Process_Sync (R, C, P, Now_Ms, Start_Timer);
            Start_Timer := Start_Timer and then not R.In_Binding_Mode;
         when others =>
            return;
      end case;
      R.RSSI := RSSI;
      R.SNR := SNR;
      Mean_Add (R.SNR_Mean, R.SNR);
      Increase (R.LQ);
      R.RF_Mode_Cycle_Multiplier := Mode_Cycle_Multiplier_Slow;
      if Start_Timer then
         Timer_Resume (R.Timing);
      end if;
      R.Packet_St := Data;
      Status := Data;
   end Process_Packet;

   ------------------
   -- Hop_Required --
   ------------------

   procedure Hop_Required (R : in out Receiver; Required : out Boolean) is
      Interval : constant Natural := Mod_Of (R).Hop_Interval;
      Freq     : Unsigned_32;
   begin
      Required := False;
      if R.Already_FHSS or else R.In_Binding_Mode or else (Natural (R.Nonce) + 1) mod Interval /= 0
        or else R.Connection = Disconnected
      then
         return;
      end if;
      R.Already_FHSS := True;
      Next_Frequency (R.Hops, R.Freq_Offset, Freq);
      R.Current_Freq := Freq;
      Required := True;
   end Hop_Required;

   ---------------------------------
   -- Telemetry_Response_Required --
   ---------------------------------

   function Telemetry_Response_Required (R : Receiver) return Boolean is
     (not (R.In_Binding_Mode or else R.Connection = Disconnected or else R.Tlm_Denom = 1
           or else (Natural (R.Nonce) + 1) mod Natural (R.Tlm_Denom) /= 0));

   procedure Update_Telemetry_Burst (R : in out Receiver) is
      Hz : Natural;
   begin
      if R.Burst_Valid then
         return;
      end if;
      R.Burst_Valid := True;
      Hz := Rate_Hz (Mod_Of (R).Rate);
      declare
         Burst : constant Natural := Telem_Min_Link_Interval * Hz / Natural (R.Tlm_Denom) / 1_000;
      begin
         R.Burst_Max := Byte (Natural'Min ((if Burst > 1 then Burst - 1 else 1), 255));
      end;
      Tlm.Update_Rate (R.Sender, Natural (R.Tlm_Denom), Positive (R.Burst_Max));
   end Update_Telemetry_Burst;

   procedure Handle_Telemetry_Update (R : in out Receiver; Next_Frame : Byte_Array; Has_Next : Boolean)
     with Pre => Next_Frame'Length <= Tlm.Frame_Max
   is
   begin
      if R.Connection /= Connected or else Mod_Of (R).Ratio = No_Telemetry then
         return;
      end if;
      if not Tlm.Is_Active (R.Sender) and then Has_Next then
         Tlm.Set_Data (R.Sender, Next_Frame);
      end if;
      Update_Telemetry_Burst (R);
   end Handle_Telemetry_Update;

   --  The response: the link statistics with the sender's confirm bit, or
   --  the sender's next chunk while the burst lasts.
   procedure Send_Telemetry_Response (R : in out Receiver) is
      Pkt           : Packet := (others => 0);
      Chunk         : Tlm.Chunk;
      Package_Index : Byte;
      SNR_Mean      : Integer_8;
      CRC           : Unsigned_16;
   begin
      R.Already_Telem_Resp := True;
      if R.Next_Telemetry = Link or else not Tlm.Is_Active (R.Sender) then
         Pkt (0) := Packet_Tlm;
         Pkt (1) := 1;
         Pkt (2) := (if R.RSSI_Filtered > 0 then 0 else Byte'Mod (-Integer (R.RSSI_Filtered)) and 16#7F#);
         Pkt (3) := (if R.Model_Match then 16#80# else 0);
         Mean_Take (R.SNR_Mean, -16, SNR_Mean);
         Pkt (4) := (R.Uplink_LQ and 16#7F#) or (if R.MSP.Confirm then 16#80# else 0);
         Pkt (5) := Byte'Mod (SNR_Mean);
         R.Next_Telemetry := Data;
         R.Burst_Count := 1;
      else
         if R.Burst_Count < R.Burst_Max then
            R.Burst_Count := R.Burst_Count + 1;
         else
            R.Next_Telemetry := Link;
         end if;
         Pkt (0) := Packet_Tlm;
         Tlm.Current_Payload (R.Sender, Chunk, Tlm.Bytes_Per_Call, Package_Index);
         Pkt (1) := 2 or Interfaces.Shift_Left (Package_Index and 16#3F#, 2);
         Pkt (2 .. 6) := Chunk;
      end if;
      CRC := Unsigned_16 (CRC14 (Pkt (0 .. 6), R.CRC_Initializer));
      Pkt (0) := Pkt (0) or Interfaces.Shift_Left (Byte (Interfaces.Shift_Right (CRC, 8)), 2);
      Pkt (7) := Byte'Mod (CRC);
      R.Telemetry_Packet := Pkt;
   end Send_Telemetry_Response;

   ------------------
   -- Do_Telemetry --
   ------------------

   procedure Do_Telemetry (R : in out Receiver; Next_Frame : Byte_Array; Has_Next : Boolean) is
   begin
      Handle_Telemetry_Update (R, Next_Frame, Has_Next);
      Send_Telemetry_Response (R);
   end Do_Telemetry;

   ------------------
   -- Timer_Update --
   ------------------

   procedure Timer_Update (R : in out Receiver; C : in out Settings; Now_Us : Unsigned_32) is
      Half : constant Unsigned_32 := Unsigned_32 (R.Timing.Interval / 2);
   begin
      if R.Timing.Phase = Tick then
         Set_Period (R.Timing, Half + Unsigned_32'Mod (R.Timing.Frequency_Offset_Ticks) - 1);
         Update_Phase_Lock (R);
         if not R.In_Binding_Mode then
            R.Nonce := R.Nonce + 1;
         end if;
         R.Uplink_LQ := R.LQ.Value;
         if not R.Already_Telem_Resp then
            New_Period (R.LQ);
         end if;
         R.Already_Telem_Resp := False;
         R.Already_FHSS := False;
         R.Timing.Phase := Tock;
      else
         Set_Period (R.Timing, Half + Unsigned_32'Mod (R.Timing.Phase_Shift_Us)
                                + Unsigned_32'Mod (R.Timing.Frequency_Offset_Ticks) - 1);
         R.Timing.Phase_Shift_Us := 0;
         R.Events.Internal_Us := Now_Us;
         R.Events.Internal_Seen := True;
         R.Timing.Phase := Tick;
      end if;
      pragma Unreferenced (C);
   end Timer_Update;

   --------------------------
   -- The receiver's task --
   --------------------------

   procedure Cycle_RF_Mode (R : in out Receiver; Now_Ms : Unsigned_32) is
   begin
      if R.Connection = Connected or else R.In_Binding_Mode then
         return;
      end if;
      if not R.Lock_RF_Mode
        and then Now_Ms - R.RF_Mode_Cycled_At_Ms
                 > Unsigned_32 (R.Cycle_Interval_Ms) * Unsigned_32 (R.RF_Mode_Cycle_Multiplier)
      then
         R.RF_Mode_Cycled_At_Ms := Now_Ms;
         R.Last_Sync_Packet_Ms := Now_Ms;
         Set_RF_Link_Rate (R, (R.Rate + 1) mod Rate_Count (R));
         R.Stats_Updated_At_Ms := Now_Ms;
         Reset (R.LQ);
         Start_Receiving (R);
         R.RF_Mode_Cycle_Multiplier := 1;
      end if;
   end Cycle_RF_Mode;

   procedure Report_Direct (R : in out Receiver) is
   begin
      R.RSSI_Report := 0;
      R.RSSI_Direct := True;
      R.RSSI_Dbm_Report := -130;
      R.RSNR_Report := -30;
      R.LQ_Report := 0;
      R.Report_Count := R.Report_Count + 1;
   end Report_Direct;

   procedure Handle_Connection_State (R : in out Receiver; C : in out Settings; Now_Ms : Unsigned_32)
     with Pre => Rate_Valid (C.Domain, C.Rate) and then C.Domain = R.Domain
   is
      Delta_Ms : Integer_32;
   begin
      if R.Connection /= Disconnected and then Mod_Of (R).Index /= R.Next_Rate then
         Lost_Connection (R);
         R.Last_Sync_Packet_Ms := Now_Ms;
         R.RF_Mode_Cycled_At_Ms := Now_Ms;
         Report_Direct (R);
      end if;
      if R.Connection = Tentative
        and then Now_Ms - R.Last_Sync_Packet_Ms > Unsigned_32 (Perf_Of (R).Lock_Timeout_Ms)
      then
         Lost_Connection (R);
         R.RF_Mode_Cycled_At_Ms := Now_Ms;
         R.Last_Sync_Packet_Ms := Now_Ms;
      end if;
      Cycle_RF_Mode (R, Now_Ms);
      Delta_Ms := Integer_32'Max (0, Wrapped_Difference (Now_Ms, R.Last_Valid_Packet_Ms));
      if R.Connection = Disconnect_Pending
        or else (R.Connection = Connected
                 and then Unsigned_32 (Delta_Ms) > Unsigned_32 (Perf_Of (R).Disconnect_Timeout_Ms))
      then
         Lost_Connection (R);
      end if;
      if R.Connection = Tentative and then abs R.Lock.Offset_Delta_Us <= 10 and then R.Lock.Offset_Us < 100
        and then Natural (R.LQ.Value) > Min_LQ_For_Chaos (R)
      then
         Got_Connection (R, C, Now_Ms);
      end if;
      if R.Timer_St = Timer_Tentative and then Now_Ms - R.Got_Connection_Ms > Consider_Connection_Good_Ms
        and then abs R.Lock.Offset_Delta_Us <= 5
      then
         R.Timer_St := Timer_Locked;
      end if;
      if R.Connection = Connected and then abs R.Lock.Offset_Delta_Us > 10 and then R.Lock.Offset_Us >= 100
        and then Natural (R.LQ.Value) <= Min_LQ_For_Chaos (R)
      then
         Lost_Connection (R);
      end if;
   end Handle_Connection_State;

   procedure Handle_Config_Update (R : in out Receiver; Now_Ms : Unsigned_32) is
   begin
      if Now_Ms - R.Config_Checked_At_Ms > Config_Check_Ms then
         R.Config_Checked_At_Ms := Now_Ms;
         if R.Config_Changed then
            R.Save_Count := R.Save_Count + 1;
            R.Initialize_Pending := True;
            R.Config_Changed := False;
         end if;
      end if;
   end Handle_Config_Update;

   function Power_Value (Index : Byte) return Unsigned_16 is
     (case Index is
         when 0 => 0, when 1 => 10, when 2 => 25, when 3 => 100, when 4 => 500, when 5 => 1_000,
         when 6 => 2_000, when 7 => 250, when 8 => 50, when others => 0);

   procedure Handle_Link_Stats (R : in out Receiver; Now_Ms : Unsigned_32) is
      Filtered : Simple_Input;
   begin
      if Now_Ms - R.Stats_Updated_At_Ms > Link_Stats_Check_Ms then
         R.Stats_Updated_At_Ms := Now_Ms;
         if R.Connection = Connected then
            Simple_Lowpass_Update (R.RSSI_Filter, Integer_32 (R.RSSI), Filtered);
            R.RSSI_Filtered := To_Int8 (Filtered);
            declare
               Sensitivity : constant Integer_32 := Integer_32 (Perf_Of (R).Sensitivity_Dbm);
               Clamped     : constant Integer_32 :=
                 Integer_32'Max (Sensitivity, Integer_32'Min (-50, Integer_32 (R.RSSI_Filtered)));
            begin
               R.RSSI_Report := Unsigned_16 (Scaled (Clamped, Sensitivity, -50, 0, 1_023));
            end;
            R.RSSI_Direct := False;
            R.RSSI_Dbm_Report := Integer_16 (R.RSSI_Filtered);
            Simple_Lowpass_Update (R.RSNR_Filter, Integer_32 (R.SNR) / 4, Filtered);
            R.RSNR_Filtered := To_Int8 (Filtered);
            R.RSNR_Report := Integer_16 (R.RSNR_Filtered);
            R.LQ_Report := R.Uplink_LQ;
            R.Uplink_Power_Report := Power_Value (R.Tx_Power);
            R.Report_Count := R.Report_Count + 1;
         else
            Report_Direct (R);
         end if;
      end if;
   end Handle_Link_Stats;

   procedure Enter_Binding_Mode (R : in out Receiver) is
   begin
      R.UID := Binding_UID;
      R.In_Binding_Mode := True;
      R.Nonce := 0;
      Update_CRC_Init (R);
      Set_RF_Link_Rate (R, R.Binding_Rate);
      Start_Receiving (R);
   end Enter_Binding_Mode;

   -------------------
   -- Data_Received --
   -------------------

   procedure Data_Received (R : in out Receiver; C : in out Settings; Now_Ms : Unsigned_32; System_Ready : Boolean;
                            Bind_Requested : Boolean; Status : out Packet_Status) is
   begin
      Status := None;
      if not R.Started and then System_Ready then
         R.Started := True;
         Start_Receiving (R);
      end if;
      if R.Initialize_Pending then
         Initialize (R, C, Now_Ms);
         R.Initialize_Pending := False;
      end if;
      if Bind_Requested then
         Enter_Binding_Mode (R);
      end if;
      Handle_Connection_State (R, C, Now_Ms);
      Handle_Config_Update (R, Now_Ms);
      Handle_Link_Stats (R, Now_Ms);
      if R.Packet_St /= None then
         Status := R.Packet_St;
         R.Packet_St := None;
      end if;
   end Data_Received;

   -----------------
   -- Set_RC_Data --
   -----------------

   procedure Set_RC_Data (R : in out Receiver; Payload : Packet; RC : in out Channels) is
   begin
      if R.Switch_Mode = 0 then
         Unpack_Hybrid_Wide (R, Payload, RC);
      else
         Unpack_Hybrid_8 (R, Payload, RC);
      end if;
   end Set_RC_Data;

   ----------
   -- Stop --
   ----------

   procedure Stop (R : in out Receiver; C : in out Settings) is
   begin
      if R.Started then
         Lost_Connection (R);
      end if;
      pragma Unreferenced (C);
   end Stop;

end Adaflight.ExpressLRS_Receiver;
