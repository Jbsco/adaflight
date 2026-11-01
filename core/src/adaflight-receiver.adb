with Adaflight.Clock;

package body Adaflight.Receiver with SPARK_Mode is
   use type Interfaces.Integer_64;

   Hold_Time_Ms         : constant := 300;
   Loss_Trigger_Us      : constant := 150_000;
   Recheck_Interval_Us  : constant := 50_000;
   Suspend_Delay_Us     : constant := 1_500_000;
   Skip_On_Resume       : constant := 2;
   RSSI_Update_Interval : constant := 20_000;
   Frame_Resample_Us    : constant := 100_000;
   Smoothing_Reset_Us   : constant := 250_000;
   ADC_Divisor          : constant := 4;
   Offset_Scaling       : constant Float := 1_024.0 / 100.0;

   --  The reference's conversions of a value to its unsigned and signed
   --  16-bit counts, which take the whole part; a value outside the type is
   --  undefined there and is held at the bound here.
   function To_Unsigned_16 (V : Float) return Unsigned_16
     with Post => (if V <= 0.0 then To_Unsigned_16'Result = 0)
   is
   begin
      if V <= 0.0 then
         return 0;
      elsif V >= 65_535.0 then
         return 65_535;
      end if;
      declare
         Within : constant Float range 0.0 .. 65_535.0 := V;
         Whole  : constant Integer range 0 .. 65_535 := Integer (Float'Truncation (Within));
      begin
         return Whole;
      end;
   end To_Unsigned_16;

   function To_Signed_16 (V : Float) return Signed_16
     with Post => (if V <= -32_768.0 then To_Signed_16'Result = -32_768)
   is
   begin
      if V <= -32_768.0 then
         return -32_768;
      elsif V >= 32_767.0 then
         return 32_767;
      end if;
      declare
         Within : constant Float range -32_768.0 .. 32_767.0 := V;
         Whole  : constant Integer range -32_768 .. 32_767 := Integer (Float'Truncation (Within));
      begin
         return Whole;
      end;
   end To_Signed_16;

   function Wrapped (V : Interfaces.Integer_64) return Integer_32 is
     (Integer_32 (((V + 2 ** 31) mod 2 ** 32) - 2 ** 31))
     with Pre => V in -2 ** 33 .. 2 ** 33;

   function Wrapped_16 (V : Integer) return Sample is
     (Sample (((V + 32_768) mod 65_536) - 32_768))
     with Pre => V in -200_000 .. 200_000;

   function Pulse_Valid (C : Settings; V : Signal) return Boolean is
   begin
      if V < 0.0 or else V >= 65_536.0 then
         return False;
      end if;
      declare
         Within : constant Float range 0.0 .. 65_536.0 := V;
         Whole  : constant Integer range 0 .. 65_536 := Integer (Float'Truncation (Within));
      begin
         return Whole in C.Min_Usec .. C.Max_Usec;
      end;
   end Pulse_Valid;

   ----------
   -- Init --
   ----------

   procedure Init (
      S                : out State;
      C                : Settings;
      Now_Ms           : Time_Ms;
      Protocol_RSSI    : RSSI_Source;
      Protocol_Quality : Link_Quality_Source
   ) is
      K : constant Unit_Interval := (256.0 - Float (C.RSSI_Smoothing)) / 256.0;
   begin
      S := (Frame_Error_Filter => <>, RSSI_Filter => <>, RSSI_Dbm_Filter => <>, RSNR_Filter => <>, others => <>);
      for F in Flight_Channel loop
         declare
            Low        : constant Pulse_Us := C.Ranges (F).Low;
            High       : constant Pulse_Us := C.Ranges (F).High;
            Span       : constant Integer range -1_500 .. 1_500 := High - Low;
            Range_Src  : constant Float range -1_500.0 .. 1_500.0 := Float (Span);
            Range_Dest : constant Float := 2_000.0 - 1_000.0;
         begin
            pragma Assert (Span /= 0);
            pragma Assert (if Span >= 1 then Range_Src >= 1.0 else Range_Src <= -1.0);
            S.Scales (F).Scale := Range_Dest / Range_Src;
            S.Scales (F).Offset := 1_000.0 - Float (Low) * S.Scales (F).Scale;
         end;
      end loop;
      for Ch in Channel loop
         S.Data (Ch) := Float (C.Mid_RC);
         S.Valid_Until_Ms (Ch) := Now_Ms + Hold_Time_Ms;
      end loop;
      S.Data (Throttle) := (if C.Feature_3D then Float (C.Mid_RC) else Float (C.Min_Usec));
      S.RSSI_From := (if C.RSSI_ADC then ADC elsif C.RSSI_Channel > 0 then Rx_Channel else Protocol_RSSI);
      S.Quality_From := Protocol_Quality;
      Filters.PT1_Init (S.Frame_Error_Filter,
                        Filters.PT1_Gain (10.0 / Float (C.Frame_LPF_Period), Float (Frame_Resample_Us) * 1.0e-6));
      Filters.PT1_Init (S.RSSI_Filter, K);
      Filters.PT1_Init (S.RSSI_Dbm_Filter, K);
      Filters.PT1_Init (S.RSNR_Filter, K);
      S.Channels := Natural'Min (C.Max_Aux + Flight_Channel_Count, C.Reported_Channels);
   end Init;

   ---------------------
   -- Init_Arm_Switch --
   ---------------------

   procedure Set_Frame_Channels (S : in out State; C : Settings; Count : Natural) is
   begin
      S.Channels := Natural'Min (C.Max_Aux + Flight_Channel_Count, Count);
   end Set_Frame_Channels;

   procedure Init_Arm_Switch (S : in out State; Aux : Modes.Aux_Channel; Span : Modes.Channel_Range) is
      Value : constant Natural :=
        (if Span.Start_Step > 0 then 900 + 25 * (Span.Start_Step - 1) else 900 + 25 * (Span.End_Step + 1));
   begin
      S.Data (Aux + Flight_Channel_Count) := Float (Value);
   end Init_Arm_Switch;

   -------------
   -- Suspend --
   -------------

   procedure Suspend (S : in out State; C : Settings; Now_Us : Time_Us) is
   begin
      if C.Source in Parallel_PWM | PPM then
         S.Suspend_Until := Now_Us + Suspend_Delay_Us;
         S.Skip_Samples := Skip_On_Resume;
      end if;
   end Suspend;

   procedure Resume (S : in out State; C : Settings; Now_Us : Time_Us) is
   begin
      if C.Source in Parallel_PWM | PPM then
         S.Suspend_Until := Now_Us;
         S.Skip_Samples := Skip_On_Resume;
      end if;
   end Resume;

   --  The mean of the last sixteen frame results, full for a good frame.
   procedure Update_Quality_Samples (S : in out State; Value : Unsigned_16; Mean : out Unsigned_16) is
   begin
      S.Quality_Sum := (S.Quality_Sum + Value + 65_536 - S.Quality_Window (S.Quality_Index)) mod 65_536;
      S.Quality_Window (S.Quality_Index) := Value;
      S.Quality_Index := (S.Quality_Index + 1) mod Link_Quality_Samples;
      Mean := S.Quality_Sum / Link_Quality_Samples;
   end Update_Quality_Samples;

   --------------
   -- Set_RSSI --
   --------------

   procedure Set_RSSI_Direct (S : in out State; Value : Unsigned_16; Source : RSSI_Source) is
   begin
      if Source /= S.RSSI_From then
         return;
      end if;
      S.RSSI := Value;
      S.RSSI_Raw := Value;
   end Set_RSSI_Direct;

   procedure Set_RSSI (S : in out State; Value : Unsigned_16; Source : RSSI_Source) is
   begin
      if Source /= S.RSSI_From then
         return;
      end if;
      if Source = Frame_Errors then
         declare
            Filtered : Signal;
         begin
            Filters.PT1_Apply (S.Frame_Error_Filter, Float (Value), Filtered);
            S.RSSI_Raw := To_Unsigned_16 (Filtered);
         end;
      else
         S.RSSI_Raw := Value;
      end if;
   end Set_RSSI;

   procedure Set_RSSI_MSP (S : in out State; Value : Byte; Now_Us : Time_Us) is
   begin
      if S.RSSI_From = None then
         S.RSSI_From := MSP;
      end if;
      if S.RSSI_From = MSP then
         S.RSSI := Value * 4;
         S.Last_MSP_RSSI_Us := Now_Us;
      end if;
   end Set_RSSI_MSP;

   procedure Set_RSSI_Dbm (S : in out State; Value : Signed_16; Source : RSSI_Source) is
   begin
      if Source /= S.RSSI_From then
         return;
      end if;
      S.RSSI_Dbm_Raw := Value;
   end Set_RSSI_Dbm;

   procedure Set_RSSI_Dbm_Direct (S : in out State; Value : Signed_16; Source : RSSI_Source) is
   begin
      if Source /= S.RSSI_From then
         return;
      end if;
      S.RSSI_Dbm := Value;
      S.RSSI_Dbm_Raw := Value;
   end Set_RSSI_Dbm_Direct;

   procedure Set_RSNR (S : in out State; Value : Signed_16) is
   begin
      S.RSNR_Raw := Value;
   end Set_RSNR;

   procedure Set_RSNR_Direct (S : in out State; Value : Signed_16) is
   begin
      S.RSNR := Value;
      S.RSNR_Raw := Value;
   end Set_RSNR_Direct;

   procedure Set_Link_Quality_Direct (S : in out State; Value : Unsigned_16) is
   begin
      S.Link_Quality := Value;
   end Set_Link_Quality_Direct;

   procedure Set_RF_Mode (S : in out State; Value : Byte) is
   begin
      S.RF_Mode := Value;
   end Set_RF_Mode;

   procedure Set_Uplink_Power (S : in out State; Value : Unsigned_16) is
   begin
      S.Uplink_Power_mW := Value;
   end Set_Uplink_Power;

   procedure Set_Active_Antenna (S : in out State; Antenna : Antenna_Index) is
   begin
      S.Active_Antenna := Antenna;
   end Set_Active_Antenna;

   --  A frame's result into the link quality, and into the RSSI from frame
   --  errors as the share of good frames over each 100 milliseconds.
   procedure Set_Link_Quality (S : in out State; Valid_Frame : Boolean; Delta_Us : Time_Delta) is
   begin
      if S.Quality_From = None then
         declare
            Mean : Unsigned_16;
         begin
            Update_Quality_Samples (S, (if Valid_Frame then Link_Quality_Max else 0), Mean);
            S.Link_Quality := Mean;
         end;
      end if;
      if S.RSSI_From = Frame_Errors then
         S.Resample_Us := Wrapped (Interfaces.Integer_64 (S.Resample_Us) + Interfaces.Integer_64 (Delta_Us));
         if S.Frame_RSSI.Count < Unsigned_16'Last then
            S.Frame_RSSI := (Sum   => S.Frame_RSSI.Sum + (if Valid_Frame then RSSI_Max else 0),
                             Count => S.Frame_RSSI.Count + 1);
         end if;
         if S.Resample_Us >= Frame_Resample_Us then
            declare
               Left : constant Time_Delta := S.Resample_Us - Frame_Resample_Us;
            begin
               Set_RSSI (S, S.Frame_RSSI.Sum / S.Frame_RSSI.Count, S.RSSI_From);
               S.Frame_RSSI := (Sum => 0, Count => 0);
               S.Resample_Us := Left;
            end;
         end if;
      end if;
   end Set_Link_Quality;

   -----------------
   -- Frame_Check --
   -----------------

   procedure Frame_Check (
      S                : in out State;
      C                : Settings;
      Now_Us           : Time_Us;
      Delta_Us         : Time_Delta;
      Task_In_Progress : Boolean;
      Frame            : Frame_Report;
      Override         : Override_Report
   ) is
      Received    : Boolean := False;
      Data_Driven : Boolean := True;
   begin
      if Task_In_Progress then
         return;
      end if;
      case C.Source is
         when PPM =>
            if Frame.PPM_Received then
               Received := True;
            end if;
         when Parallel_PWM =>
            if Frame.PWM_Received then
               Received := True;
               Data_Driven := False;
            end if;
         when Serial | MSP | SPI | UDP =>
            Received := Frame.Complete and then not (Frame.Failsafe or else Frame.Dropped);
            Set_Link_Quality (S, Received, Delta_Us);
            S.Aux_Required := S.Aux_Required or else Frame.Processing_Required;
         when None =>
            null;
      end case;
      if Received then
         S.Need_Signal_Before := Now_Us + Loss_Trigger_Us;
         S.Signal_Received := True;
         if Data_Driven then
            S.Processing_Required := True;
         end if;
      elsif Clock.Elapsed (Now_Us, S.Need_Signal_Before) > 0 then
         S.Signal_Received := False;
         S.Need_Signal_Before := S.Need_Signal_Before + Recheck_Interval_Us;
         S.Processing_Required := True;
      end if;
      if Override_Polled (C, Override.Box) and then Override.Complete then
         S.Signal_Received := True;
         S.Processing_Required := True;
         S.Need_Signal_Before := Now_Us + Loss_Trigger_Us;
      end if;
   end Frame_Check;

   --  A sample's channel value smoothed over the last three samples once
   --  three have arrived, as the pulse receivers use it.
   procedure Moving_Average (S : in out State; Ch : Averaged_Channel; Value : Sample; Mean : out Sample) is
      Index : constant Natural range 0 .. Sample_Window - 1 := S.Sample_Index mod Sample_Window;
      Sum   : Integer range -3 * 32_768 .. 3 * 32_767 := 0;
   begin
      S.Window (Ch) (Index) := Value;
      if not S.Samples_Collected then
         if S.Sample_Index < Sample_Window then
            Mean := Value;
            return;
         end if;
         S.Samples_Collected := True;
      end if;
      for I in 0 .. Sample_Window - 1 loop
         pragma Loop_Invariant (Sum in -(I * 32_768) .. I * 32_767);
         Sum := Sum + S.Window (Ch) (I);
      end loop;
      S.Means (Ch) := Wrapped_16 (Sum);
      Mean := S.Means (Ch) / Sample_Window;
   end Moving_Average;

   --  The value of a channel without a valid signal: the center or the
   --  throttle minimum for the flight channels on automatic, the current or
   --  the last good value on hold, or the set step.
   function Failsafe_Value (
      S      : State;
      C      : Settings;
      Ch     : Channel;
      Switch : Boolean;
      Box_3D : Boolean
   ) return Unsigned_16 is
      Held : constant Unsigned_16 := To_Unsigned_16 (if Switch then S.Raw (Ch) else S.Data (Ch));
   begin
      case C.Failsafe (Ch).Mode is
         when Auto =>
            if Ch in Roll | Pitch | Yaw then
               return C.Mid_RC;
            elsif Ch = Throttle then
               if C.Feature_3D and then not Box_3D and then not C.Switched_Mode_3D then
                  return C.Mid_RC;
               else
                  return C.Min_Usec;
               end if;
            else
               return Held;
            end if;
         when Hold | Invalid =>
            return Held;
         when Set =>
            return Pulse_Min + 25 * C.Failsafe (Ch).Step;
      end case;
   end Failsafe_Value;

   --  The raw channels through the map and, for the flight channels, the
   --  calibration; a timed-out pulse of zero stays zero.
   --  A value as a 16-bit count holds it, truncated.
   function Whole (Value : Raw_Value) return Raw_Value is
      Truncated : constant Float := Float'Truncation (Value);
   begin
      pragma Assert (Truncated <= Value);
      pragma Assert (Truncated >= 0.0);
      return Truncated;
   end Whole;

   --  The override's sample of a raw channel: the MSP channel within the
   --  pulse limits when the override is on and the channel is set and
   --  fresh, else the provider's channel, both as whole microseconds.
   function Override_Sample (C : Settings; Provider : Raw_Value; Override : Override_Report; Ch : Channel)
     return Raw_Value
   is
      MSP : constant Raw_Value :=
        Float'Max (Float (C.Min_Usec), Float'Min (Override.Raw (Ch), Float (C.Max_Usec)));
   begin
      if Override.Box and then C.Override_Channels (Ch) and then Override.Fresh (Ch) then
         return Whole (MSP);
      end if;
      return Whole (Provider);
   end Override_Sample;

   procedure Read_Channels (S : in out State; C : Settings; Raw : Raw_Values; Override : Override_Report) is
   begin
      for Ch in 0 .. S.Channels - 1 loop
         declare
            Raw_Ch : constant Channel := (if Ch < Mappable_Count then C.Map (Ch) else Ch);
            Value  : Signal :=
              (if Override_Configured (C) then Override_Sample (C, Raw (Raw_Ch), Override, Raw_Ch) else Raw (Raw_Ch));
         begin
            if Ch < Flight_Channel_Count and then Value /= 0.0 then
               Value := Value * S.Scales (Ch).Scale + S.Scales (Ch).Offset;
            end if;
            S.Raw (Ch) := Value;
         end;
      end loop;
   end Read_Channels;

   --  The signal loss behaviour: a good channel resets its hold timer; in
   --  stage two the flight channels keep valid values and take the failsafe
   --  throttle and the center otherwise while the aux channels take their
   --  failsafe settings; before that the switch applies the settings at
   --  once, and a bad channel holds its last value for 300 milliseconds and
   --  then takes its setting, a bad flight channel dropping the validity.
   procedure Detect_Signal_Loss (
      S               : in out State;
      C               : Settings;
      Now_Ms          : Time_Ms;
      Switch          : Boolean;
      Box_3D          : Boolean;
      Failsafe_Active : Boolean;
      Valid           : out Validity
   ) is
   begin
      S.Flight_Valid := S.Signal_Received and then not Switch;
      for Ch in 0 .. S.Channels - 1 loop
         declare
            Value      : Signal := S.Raw (Ch);
            This_Valid : constant Boolean := S.Flight_Valid and then Pulse_Valid (C, Value);
         begin
            if This_Valid then
               S.Valid_Until_Ms (Ch) := Now_Ms + Hold_Time_Ms;
            end if;
            if Failsafe_Active then
               if Ch < Flight_Channel_Count then
                  if not This_Valid then
                     Value := (if Ch = Throttle then Float (C.Failsafe_Throttle) else Float (C.Mid_RC));
                  end if;
               else
                  Value := Float (Failsafe_Value (S, C, Ch, Switch, Box_3D));
               end if;
            elsif Switch then
               Value := Float (Failsafe_Value (S, C, Ch, Switch, Box_3D));
            elsif not This_Valid then
               if Clock.Elapsed (Now_Ms, S.Valid_Until_Ms (Ch)) < 0 then
                  Value := S.Data (Ch);
               else
                  if Ch < Flight_Channel_Count then
                     S.Flight_Valid := False;
                  end if;
                  Value := Float (Failsafe_Value (S, C, Ch, Switch, Box_3D));
               end if;
            end if;
            Value := Constrain_F (Value, Float (Pulse_Min), Float (Pulse_Max));
            if C.Source in Parallel_PWM | PPM and then Ch < Averaged_Count then
               declare
                  Mean : Sample;
               begin
                  Moving_Average (S, Ch, Sample (Float'Truncation (Value)), Mean);
                  S.Data (Ch) := Float (Mean);
               end;
            else
               S.Data (Ch) := Value;
            end if;
         end;
      end loop;
      Valid := (if S.Flight_Valid then Data_Received else Data_Failed);
   end Detect_Signal_Loss;

   ------------------------
   -- Calculate_Channels --
   ------------------------

   procedure Calculate_Channels (
      S               : in out State;
      C               : Settings;
      Now_Us          : Time_Us;
      Now_Ms          : Time_Ms;
      Raw             : Raw_Values;
      Override        : Override_Report;
      Box_Failsafe    : Boolean;
      Box_3D          : Boolean;
      Failsafe_Active : Boolean;
      Processed       : out Boolean;
      Frame_Processed : out Boolean;
      Valid           : out Validity
   ) is
   begin
      Processed := False;
      Frame_Processed := False;
      Valid := No_Report;
      if S.Aux_Required then
         Frame_Processed := True;
         S.Aux_Required := False;
      end if;
      if not S.Processing_Required then
         return;
      end if;
      S.Processing_Required := False;
      if S.Skip_Samples > 0 or else Now_Us <= S.Suspend_Until then
         if Now_Us > S.Suspend_Until then
            S.Skip_Samples := S.Skip_Samples - 1;
         end if;
         Processed := True;
         return;
      end if;
      Read_Channels (S, C, Raw, Override);
      Detect_Signal_Loss (S, C, Now_Ms, Box_Failsafe, Box_3D, Failsafe_Active, Valid);
      S.Sample_Index := (S.Sample_Index + 1) mod 256;
      Processed := True;
   end Calculate_Channels;

   -----------------
   -- Update_RSSI --
   -----------------

   procedure Update_RSSI (S : in out State; C : Settings; Now_Us : Time_Us; ADC_Sample : ADC_Count) is
      Pwm_Factor : constant Float := Float (RSSI_Max - 0) / Float (2_000 - 1_000);
      Pwm_Offset : constant Float := 0.0 - Pwm_Factor * Float (1_000);
   begin
      case S.RSSI_From is
         when Rx_Channel =>
            if C.RSSI_Channel > 0 then
               declare
                  Pwm   : constant Signed_16 := To_Signed_16 (S.Data (C.RSSI_Channel - 1));
                  Bound : constant Integer range 1_000 .. 2_000 := Integer'Min (Integer'Max (Pwm, 1_000), 2_000);
               begin
                  Set_RSSI_Direct (S, To_Unsigned_16 (Float (Bound) * Pwm_Factor + Pwm_Offset), Rx_Channel);
               end;
            end if;
         when ADC =>
            if Clock.Elapsed (Now_Us, S.ADC_Update_At_Us) >= 0 then
               S.ADC_Update_At_Us := Now_Us + RSSI_Update_Interval;
               Set_RSSI (S, ADC_Sample / ADC_Divisor, ADC);
            end if;
         when MSP =>
            if Clock.Elapsed (Now_Us, S.Last_MSP_RSSI_Us) > Suspend_Delay_Us then
               S.RSSI := 0;
            end if;
         when None | Rx_Protocol | Frame_Errors | Protocol_CRSF | Protocol_Mavlink =>
            null;
      end case;
      if Clock.Elapsed (Now_Us, S.Last_Smoothing_Us) > Smoothing_Reset_Us then
         S.Last_Smoothing_Us := Now_Us;
      elsif S.Last_Smoothing_Us /= Now_Us then
         declare
            K      : constant Float range 1.0 / 256.0 .. 1.0 := (256.0 - Float (C.RSSI_Smoothing)) / 256.0;
            Factor : constant Float range 0.0 .. 2.0e4 :=
              (Float (Now_Us - S.Last_Smoothing_Us) / 1.0e6) / (1.0 / 4.0);
            KF     : constant Float range 0.0 .. 2.0e4 := K * Factor;
            K2     : constant Float := KF / (KF - K + 1.0);
            Gain   : constant Unit_Interval := Constrain_F (K2, 0.0, 1.0);
            Out_F  : Signal;
         begin
            if S.RSSI /= S.RSSI_Raw then
               Filters.PT1_Update_Cutoff (S.RSSI_Filter, Gain);
               Filters.PT1_Apply (S.RSSI_Filter, Float (S.RSSI_Raw), Out_F);
               S.RSSI := To_Unsigned_16 (Out_F);
            end if;
            if S.RSSI_Dbm /= S.RSSI_Dbm_Raw then
               Filters.PT1_Update_Cutoff (S.RSSI_Dbm_Filter, Gain);
               Filters.PT1_Apply (S.RSSI_Dbm_Filter, Float (S.RSSI_Dbm_Raw), Out_F);
               S.RSSI_Dbm := To_Signed_16 (Out_F);
            end if;
            if S.RSNR /= S.RSNR_Raw then
               Filters.PT1_Update_Cutoff (S.RSNR_Filter, Gain);
               Filters.PT1_Apply (S.RSNR_Filter, Float (S.RSNR_Raw), Out_F);
               S.RSNR := To_Signed_16 (Out_F);
            end if;
            S.Last_Smoothing_Us := Now_Us;
         end;
      end if;
   end Update_RSSI;

   ----------
   -- RSSI --
   ----------

   function RSSI (S : State; C : Settings) return Unsigned_16 is
      Value : constant Unsigned_16 := (if C.RSSI_Invert then (RSSI_Max + 65_536 - S.RSSI) mod 65_536 else S.RSSI);
      Scaled : constant Float :=
        Float (C.RSSI_Scale) / 100.0 * Float (Value) + Float (C.RSSI_Offset) * Offset_Scaling;
   begin
      return To_Unsigned_16 (Scaled);
   end RSSI;

   --  The percentages take the low byte and the low 16 bits of their whole
   --  parts, as the reference's conversions do on the target.
   function RSSI_Percent (S : State; C : Settings) return Byte is
      Percent : constant Float range 0.0 .. 7_000.0 := Float (RSSI (S, C)) * (Float (100) / Float (RSSI_Max)) + 0.0;
   begin
      return Natural (Float'Truncation (Percent)) mod 256;
   end RSSI_Percent;

   function Link_Quality_Percent (S : State) return Unsigned_16 is
      Percent : constant Float range 0.0 .. 7_000.0 :=
        Float (S.Link_Quality) * (Float (100) / Float (Link_Quality_Max)) + 0.0;
   begin
      if S.Quality_From = None then
         return Natural (Float'Truncation (Percent)) mod 65_536;
      else
         return S.Link_Quality;
      end if;
   end Link_Quality_Percent;

end Adaflight.Receiver;
