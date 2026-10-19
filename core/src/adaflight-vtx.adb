package body Adaflight.VTX with SPARK_Mode is
   use type VTX_Settings.Low_Power_Disarm;

   Spektrum_Band_Mask     : constant Unsigned_32 := 16#00E0_0000#;
   Spektrum_Channel_Mask  : constant Unsigned_32 := 16#000F_0000#;
   Spektrum_Pit_Mode_Mask : constant Unsigned_32 := 16#0000_0010#;
   Spektrum_Power_Mask    : constant Unsigned_32 := 16#0000_0007#;

   --  The Spektrum bands in the table's numbering: Fatshark, Raceband, E,
   --  B, A; a band past the five is not a table band.
   function Spektrum_Band (B : Unsigned_32) return Unsigned_8 is
     (case B is
         when 0 => 4,
         when 1 => 5,
         when 2 => 3,
         when 3 => 2,
         when 4 => 1,
         when others => 0);

   --  The Spektrum power steps as power indices of the device in use: off,
   --  under 14, 25, under 99, under 299, under 600, more and manual.
   function Spektrum_Power (P : Unsigned_32; Kind : Device_Kind) return Unsigned_8 is
     (case Kind is
         when Tramp_Device =>
           (case P is
               when 0 | 1 | 2 => 1,
               when 3         => 2,
               when 4         => 3,
               when 5         => 4,
               when 6         => 5,
               when others    => 3),
         when SmartAudio_Device =>
           (case P is
               when 0 | 1 | 2 | 3 => 1,
               when 4             => 2,
               when 5             => 3,
               when 6             => 4,
               when others        => 2),
         when MSP_Device | No_Device => 0);

   --  The device of the kind in use.

   procedure Device_Set_Frequency (V : in out State; Freq : Unsigned_16) is
   begin
      case V.Kind is
         when SmartAudio_Device => SmartAudio.Set_Frequency (V.SA, Freq);
         when Tramp_Device      => Tramp.Set_Frequency (V.TR, Freq);
         when MSP_Device        => VTX_MSP.Set_Frequency (V.MD, Freq);
         when No_Device         => null;
      end case;
   end Device_Set_Frequency;

   procedure Device_Set_Power_Index (V : in out State; T : VTX_Table.Table; Index : Unsigned_8) is
   begin
      case V.Kind is
         when SmartAudio_Device => SmartAudio.Set_Power_Index (V.SA, T, Index);
         when Tramp_Device      => Tramp.Set_Power_Index (V.TR, T, Index);
         when MSP_Device        => VTX_MSP.Set_Power_Index (V.MD, T, Index);
         when No_Device         => null;
      end case;
   end Device_Set_Power_Index;

   procedure Device_Set_Pit_Mode (V : in out State; On : Boolean) is
   begin
      case V.Kind is
         when SmartAudio_Device => SmartAudio.Set_Pit_Mode (V.SA, On);
         when Tramp_Device      => Tramp.Set_Pit_Mode (V.TR, On);
         when MSP_Device        => VTX_MSP.Set_Pit_Mode (V.MD, On);
         when No_Device         => null;
      end case;
   end Device_Set_Pit_Mode;

   procedure Device_Set_Band_Channel (V : in out State; T : VTX_Table.Table; Band, Channel : Unsigned_8) is
   begin
      case V.Kind is
         when SmartAudio_Device        => SmartAudio.Set_Band_Channel (V.SA, T, Band, Channel);
         when MSP_Device               => VTX_MSP.Set_Band_Channel (V.MD, Band, Channel);
         when Tramp_Device | No_Device => null;
      end case;
   end Device_Set_Band_Channel;

   procedure Device_Get_Band_Channel (V : State; T : VTX_Table.Table; Band, Channel : out Unsigned_8;
                                      Known : out Boolean) is
   begin
      Band := 0;
      Channel := 0;
      Known := False;
      case V.Kind is
         when SmartAudio_Device => SmartAudio.Get_Band_Channel (V.SA, T, Band, Channel, Known);
         when Tramp_Device      => Tramp.Get_Band_Channel (V.TR, Band, Channel, Known);
         when MSP_Device        => VTX_MSP.Get_Band_Channel (V.MD, Band, Channel, Known);
         when No_Device         => null;
      end case;
   end Device_Get_Band_Channel;

   procedure Device_Get_Power_Index (V : State; T : VTX_Table.Table; Index : in out Unsigned_8; Known : out Boolean) is
      I : Unsigned_8;
   begin
      Known := False;
      case V.Kind is
         when SmartAudio_Device =>
            SmartAudio.Get_Power_Index (V.SA, I, Known);
            if Known then
               Index := I;
            end if;
         when Tramp_Device =>
            Tramp.Get_Power_Index (V.TR, T, Index, Known);
         when MSP_Device =>
            VTX_MSP.Get_Power_Index (V.MD, T, Index, Known);
         when No_Device =>
            null;
      end case;
   end Device_Get_Power_Index;

   --  The power index for the state check, left as it is when unknown.
   procedure Device_Read_Power_Index (V : State; T : VTX_Table.Table; Index : in out Unsigned_8) is
      I     : Unsigned_8;
      Known : Boolean;
   begin
      case V.Kind is
         when SmartAudio_Device =>
            SmartAudio.Get_Power_Index (V.SA, I, Known);
            if Known then
               Index := I;
            end if;
         when Tramp_Device =>
            Tramp.Read_Power_Index (V.TR, T, Index);
         when MSP_Device =>
            I := Index;
            VTX_MSP.Get_Power_Index (V.MD, T, I, Known);
            if Known then
               Index := I;
            end if;
         when No_Device =>
            null;
      end case;
   end Device_Read_Power_Index;

   procedure Device_Get_Frequency (V : State; T : VTX_Table.Table; Freq : out Unsigned_16; Known : out Boolean) is
   begin
      Freq := 0;
      Known := False;
      case V.Kind is
         when SmartAudio_Device => SmartAudio.Get_Frequency (V.SA, T, Freq, Known);
         when Tramp_Device      => Tramp.Get_Frequency (V.TR, Freq, Known);
         when MSP_Device        => VTX_MSP.Get_Frequency (V.MD, T, Freq, Known);
         when No_Device         => null;
      end case;
   end Device_Get_Frequency;

   procedure Device_Get_Status (V : State; Pit : out Boolean; Known : out Boolean) is
   begin
      Pit := False;
      Known := False;
      case V.Kind is
         when SmartAudio_Device => SmartAudio.Get_Status (V.SA, Pit, Known);
         when Tramp_Device      => Tramp.Get_Pit_Mode (V.TR, Pit, Known);
         when MSP_Device        => VTX_MSP.Get_Status (V.MD, Pit, Known);
         when No_Device         => null;
      end case;
   end Device_Get_Status;

   --  The common layer: the band and channel go to the device, to a
   --  SmartAudio device only for a factory band, and a band not from the
   --  factory goes as its frequency too.

   procedure Common_Set_Band_Channel (V : in out State; T : VTX_Table.Table; Band, Channel : Unsigned_8) is
      Freq : constant Unsigned_16 := VTX_Table.Frequency_Of (T, Natural (Band), Natural (Channel));
   begin
      if Freq /= 0 then
         V.Selected_Channel := Channel;
         V.Selected_Band := Band;
         if V.Kind /= SmartAudio_Device or else T.Is_Factory (Natural (Band)) then
            Device_Set_Band_Channel (V, T, Band, Channel);
         end if;
         if not T.Is_Factory (Natural (Band)) then
            Device_Set_Frequency (V, Freq);
         end if;
      end if;
   end Common_Set_Band_Channel;

   procedure Common_Set_Power_Index (V : in out State; T : VTX_Table.Table; Index : Unsigned_8) is
   begin
      if Natural (Index) <= T.Power_Levels then
         Device_Set_Power_Index (V, T, Index);
      end if;
   end Common_Set_Power_Index;

   procedure Common_Set_Frequency (V : in out State; Freq : Unsigned_16) is
   begin
      V.Selected_Band := 0;
      V.Selected_Channel := 0;
      Device_Set_Frequency (V, Freq);
   end Common_Set_Frequency;

   --  Band and channel from the device, or from its frequency through the
   --  table while a non-factory band is selected. The outputs keep their
   --  values when the device has none.
   procedure Common_Get_Band_Channel (V : State; T : VTX_Table.Table; Band, Channel : in out Unsigned_8;
                                      Known : out Boolean) is
      B, C   : Unsigned_8;
      Freq   : Unsigned_16;
      Found  : Boolean;
      TB     : VTX_Table.Band_Count;
      TC     : VTX_Table.Channel_Count;
   begin
      Device_Get_Band_Channel (V, T, B, C, Known);
      if Known then
         Band := B;
         Channel := C;
      end if;
      if (not Known or else (Band = 0 and then Channel = 0))
        and then V.Selected_Band in 1 .. VTX_Table.Max_Bands and then V.Selected_Channel /= 0
        and then not T.Is_Factory (Natural (V.Selected_Band))
      then
         Device_Get_Frequency (V, T, Freq, Found);
         Known := Found;
         if Known then
            VTX_Table.Band_Channel_Of (T, Freq, TB, TC);
            Band := Unsigned_8 (TB);
            Channel := Unsigned_8 (TC);
         end if;
      end if;
   end Common_Get_Band_Channel;

   procedure Common_Get_Power_Index (V : State; T : VTX_Table.Table; Index : in out Unsigned_8; Known : out Boolean) is
   begin
      Device_Get_Power_Index (V, T, Index, Known);
   end Common_Get_Power_Index;

   procedure Common_Get_Frequency (V : State; T : VTX_Table.Table; Freq : in out Unsigned_16; Known : out Boolean) is
      F : Unsigned_16;
   begin
      Device_Get_Frequency (V, T, F, Known);
      if Known then
         Freq := F;
      end if;
   end Common_Get_Frequency;

   --  The settings as they apply now: the pit mode frequency at the
   --  switch, the default power while disarmed under the low power policy.
   function Effective (S : Settings; Inp : Inputs) return Settings
     with Post => Effective'Result.Pit_Mode_Freq = S.Pit_Mode_Freq and then Effective'Result.Low_Power = S.Low_Power
                  and then Effective'Result.Softserial_Alt = S.Softserial_Alt
   is
      R : Settings := S;
   begin
      if Inp.Pit_Switch and then S.Pit_Mode_Freq /= 0 then
         R.Band := 0;
         R.Freq := S.Pit_Mode_Freq;
         R.Power := VTX_Settings.Default_Power;
      end if;
      if not Inp.Armed and then not Inp.Failsafe
        and then (S.Low_Power = VTX_Settings.Always
                  or else (S.Low_Power = VTX_Settings.Until_First_Arm and then not Inp.Was_Ever_Armed))
      then
         R.Power := VTX_Settings.Default_Power;
      end if;
      return R;
   end Effective;

   procedure Process_Band_Channel (V : in out State; S : Settings; T : VTX_Table.Table; Inp : Inputs;
                                   Pending : out Boolean) is
      Band, Channel : Unsigned_8 := 0;
      Known         : Boolean;
      Wanted        : Settings;
   begin
      Pending := False;
      if not Inp.Armed then
         Common_Get_Band_Channel (V, T, Band, Channel, Known);
         if Known then
            Wanted := Effective (S, Inp);
            if Band /= Wanted.Band or else Channel /= Wanted.Channel then
               Common_Set_Band_Channel (V, T, Wanted.Band, Wanted.Channel);
               Pending := True;
            end if;
         end if;
      end if;
   end Process_Band_Channel;

   procedure Process_Frequency (V : in out State; S : Settings; T : VTX_Table.Table; Inp : Inputs;
                                Pending : out Boolean) is
      Freq   : Unsigned_16 := 0;
      Known  : Boolean;
      Wanted : Settings;
   begin
      Pending := False;
      if not Inp.Armed then
         Common_Get_Frequency (V, T, Freq, Known);
         if Known then
            Wanted := Effective (S, Inp);
            if Freq /= Wanted.Freq then
               Common_Set_Frequency (V, Wanted.Freq);
               Pending := True;
            end if;
         end if;
      end if;
   end Process_Frequency;

   procedure Process_Power (V : in out State; S : Settings; T : VTX_Table.Table; Inp : Inputs; Pending : out Boolean) is
      Index  : Unsigned_8 := 0;
      Known  : Boolean;
      Wanted : Settings;
   begin
      Pending := False;
      Common_Get_Power_Index (V, T, Index, Known);
      if Known then
         Wanted := Effective (S, Inp);
         if Index /= Wanted.Power then
            Common_Set_Power_Index (V, T, Wanted.Power);
            Pending := True;
         end if;
      end if;
   end Process_Power;

   procedure Process_Pit_Mode (V : in out State; S : Settings; Inp : Inputs; Pending : out Boolean) is
      Pit   : Boolean;
      Known : Boolean;
   begin
      Pending := False;
      if Inp.Armed then
         return;
      end if;
      Device_Get_Status (V, Pit, Known);
      if not Known then
         return;
      end if;
      if Inp.Pit_Switch /= V.Prev_Pit_Switch then
         V.Prev_Pit_Switch := Inp.Pit_Switch;
         if Inp.Pit_Switch then
            if S.Pit_Mode_Freq /= 0 then
               return;
            end if;
            if not Pit then
               Device_Set_Pit_Mode (V, True);
               Pending := True;
            end if;
         elsif Pit then
            Device_Set_Pit_Mode (V, False);
            Pending := True;
         end if;
      end if;
   end Process_Pit_Mode;

   --  The device state against the settings: band and channel of a
   --  configured band, else the frequency, and the power.
   function Process_State_Update (V : State; S : Settings; T : VTX_Table.Table; Inp : Inputs) return Boolean is
      Wanted : constant Settings := Effective (S, Inp);
      Seen   : Settings := Wanted;
      Known  : Boolean;
   begin
      if Wanted.Band /= 0 then
         Common_Get_Band_Channel (V, T, Seen.Band, Seen.Channel, Known);
      else
         Common_Get_Frequency (V, T, Seen.Freq, Known);
      end if;
      Device_Read_Power_Index (V, T, Seen.Power);
      return Seen.Band /= Wanted.Band or else Seen.Channel /= Wanted.Channel or else Seen.Power /= Wanted.Power
        or else Seen.Freq /= Wanted.Freq;
   end Process_State_Update;

   --  A control word from the receiver, once per change: band and channel
   --  through the table, the power through the device's steps, the pit
   --  mode at once, and the settings saved when they moved.
   procedure Spektrum_Control (V : in out State; S : in out Settings; T : VTX_Table.Table; Save : in out Boolean) is
      Word        : Unsigned_32;
      Band        : Unsigned_8;
      Channel     : Unsigned_8;
      Power       : Unsigned_8;
      Pit_Wanted  : Boolean;
      Pit         : Boolean;
      Known       : Boolean;
      New_S       : Settings := S;
   begin
      if (V.Spektrum_Word and Spektrum_Frame_Mask) /= Spektrum_Frame then
         return;
      end if;
      Word := V.Spektrum_Word;
      V.Spektrum_Word := 0;
      if V.Prev_Spektrum = Word then
         return;
      end if;
      V.Prev_Spektrum := Word;
      Pit_Wanted := (Word and Spektrum_Pit_Mode_Mask) /= 0;
      if V.Device_Present then
         Band := Spektrum_Band (Interfaces.Shift_Right (Word and Spektrum_Band_Mask, 21));
         Channel := Unsigned_8 (Interfaces.Shift_Right (Word and Spektrum_Channel_Mask, 16)) + 1;
         if S.Band /= Band or else S.Channel /= Channel then
            New_S.Band := Band;
            New_S.Channel := Channel;
            New_S.Freq := VTX_Table.Frequency_Of (T, Natural (Band), Natural (Channel));
         end if;
         Power := Spektrum_Power (Word and Spektrum_Power_Mask, V.Kind);
         if S.Power /= Power then
            New_S.Power := Power;
         end if;
         Device_Get_Status (V, Pit, Known);
         if Known and then Pit /= Pit_Wanted then
            Device_Set_Pit_Mode (V, Pit_Wanted);
         end if;
      end if;
      if New_S.Band /= S.Band or else New_S.Channel /= S.Channel or else New_S.Power /= S.Power
        or else New_S.Freq /= S.Freq
      then
         S.Band := New_S.Band;
         S.Channel := New_S.Channel;
         S.Power := New_S.Power;
         S.Freq := New_S.Freq;
         Save := True;
      end if;
   end Spektrum_Control;

   ----------
   -- Init --
   ----------

   procedure Init (V : out State; S : in out Settings; T : VTX_Table.Table; Kind : Device_Kind;
                   Port_Opened, Softserial : Boolean; Save : out Boolean) is
      Freq : Unsigned_16;
   begin
      V := (others => <>);
      Save := False;
      SmartAudio.Init (V.SA, Port_Opened and then Kind = SmartAudio_Device);
      Tramp.Init (V.TR, Port_Opened and then Kind = Tramp_Device);
      if not Port_Opened or else Kind = No_Device then
         return;
      end if;
      V.Kind := Kind;
      V.Device_Present := True;
      V.Prepend_Zero := Softserial and then S.Softserial_Alt;
      Freq := VTX_Table.Frequency_Of (T, Natural (S.Band), Natural (S.Channel));
      if S.Band /= 0 and then Freq /= S.Freq then
         S.Freq := Freq;
         Save := True;
      end if;
      if S.Pit_Mode_Freq /= 0 and then S.Pit_Mode_Freq < VTX_Table.Min_User_Frequency then
         S.Pit_Mode_Freq := VTX_Table.Min_User_Frequency;
         Save := True;
      end if;
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (V : in out State; S : in out Settings; T : VTX_Table.Table; Inp : Inputs; Rx : Byte_Array;
                     E : out Events) is
      Start   : Parameter;
      Pending : Boolean;
   begin
      E := (others => <>);
      if Inp.Cli_Mode or else not V.Device_Present then
         return;
      end if;
      Spektrum_Control (V, S, T, E.Save);
      Start := V.Schedule;
      loop
         case V.Schedule is
            when Power_Param =>
               Process_Power (V, S, T, Inp, Pending);
            when Band_Channel_Param =>
               if Effective (S, Inp).Band /= 0 then
                  Process_Band_Channel (V, S, T, Inp, Pending);
               else
                  Process_Frequency (V, S, T, Inp, Pending);
               end if;
            when Pit_Mode_Param =>
               Process_Pit_Mode (V, S, Inp, Pending);
            when Confirm_Param =>
               Pending := Process_State_Update (V, S, T, Inp);
         end case;
         V.Schedule := (if V.Schedule = Parameter'Last then Parameter'First else Parameter'Succ (V.Schedule));
         exit when Pending or else V.Schedule = Start;
      end loop;
      if not Inp.Armed or else Pending then
         case V.Kind is
            when SmartAudio_Device =>
               SmartAudio.Process (V.SA, T, Inp.Now_Ms, Rx, Inp.Control_Disabled, V.Prepend_Zero, E.Device);
               E.Consumed := Rx'Length;
            when Tramp_Device =>
               Tramp.Process (V.TR, Inp.Now_Us, Rx, Inp.Control_Disabled, E.Tramp_Tx, E.Consumed);
            when MSP_Device =>
               VTX_MSP.Process (V.MD, S, T,
                                (Now_Us         => Inp.Now_Us,
                                 Armed          => Inp.Armed,
                                 Was_Ever_Armed => Inp.Was_Ever_Armed,
                                 Failsafe       => Inp.Failsafe),
                                E.MSP_Frame, E.MSP_Send);
               E.MSP_Status_Due := E.MSP_Send or else not VTX_MSP.Is_Ready (V.MD);
            when No_Device =>
               null;
         end case;
      end if;
   end Update;

   ----------------------------
   -- Offer_Spektrum_Control --
   ----------------------------

   procedure Offer_Spektrum_Control (V : in out State; Word : Unsigned_32) is
   begin
      V.Spektrum_Word := Word;
   end Offer_Spektrum_Control;

   procedure Step_Band_Channel (V : in out State; S : in out Settings; Armed : Boolean;
                                Band_Step, Channel_Step : Unsigned_8) is
   begin
      if Armed then
         V.Locked := True;
      end if;
      if not V.Locked and then V.Device_Present then
         S.Band := S.Band + Band_Step;
         S.Channel := S.Channel + Channel_Step;
      end if;
   end Step_Band_Channel;

   procedure Increment_Band (V : in out State; S : in out Settings; Armed : Boolean) is
   begin
      Step_Band_Channel (V, S, Armed, 1, 0);
   end Increment_Band;

   procedure Decrement_Band (V : in out State; S : in out Settings; Armed : Boolean) is
   begin
      Step_Band_Channel (V, S, Armed, 255, 0);
   end Decrement_Band;

   procedure Increment_Channel (V : in out State; S : in out Settings; Armed : Boolean) is
   begin
      Step_Band_Channel (V, S, Armed, 0, 1);
   end Increment_Channel;

   procedure Decrement_Channel (V : in out State; S : in out Settings; Armed : Boolean) is
   begin
      Step_Band_Channel (V, S, Armed, 0, 255);
   end Decrement_Channel;

   ------------------------------
   -- Update_Activated_Channel --
   ------------------------------

   procedure Update_Activated_Channel (V : in out State; S : in out Settings; C : Conditions; Aux : Modes.Aux_Values;
                                       Armed : Boolean) is
   begin
      if Armed then
         V.Locked := True;
      end if;
      if not V.Device_Present then
         return;
      end if;
      for I in Condition_Index loop
         if Modes.Range_Active (Aux, C (I).Aux, C (I).Span) then
            if not V.Locked then
               if C (I).Band > 0 then
                  S.Band := C (I).Band;
               end if;
               if C (I).Channel > 0 then
                  S.Channel := C (I).Channel;
               end if;
            end if;
            if C (I).Power > 0 then
               S.Power := C (I).Power;
            end if;
         end if;
      end loop;
   end Update_Activated_Channel;

   ---------------------------
   -- Cycle_Band_Or_Channel --
   ---------------------------

   procedure Cycle_Band_Or_Channel (V : State; S : in out Settings; T : VTX_Table.Table;
                                    Band_Step, Channel_Step : Unsigned_8) is
      Band, Channel : Unsigned_8 := 0;
      Known         : Boolean;
      New_Band      : Integer;
      New_Channel   : Integer;
   begin
      if not V.Device_Present then
         return;
      end if;
      Common_Get_Band_Channel (V, T, Band, Channel, Known);
      if not Known then
         return;
      end if;
      New_Channel := Integer (Channel) + Integer (Channel_Step);
      if New_Channel > T.Channels then
         New_Channel := 1;
      elsif New_Channel < 1 then
         New_Channel := T.Channels;
      end if;
      New_Band := Integer (Band) + Integer (Band_Step);
      if New_Band > T.Bands then
         New_Band := 1;
      elsif New_Band < 1 then
         New_Band := T.Bands;
      end if;
      S.Band := Unsigned_8 (New_Band);
      S.Channel := Unsigned_8 (New_Channel);
   end Cycle_Band_Or_Channel;

   -----------------
   -- Cycle_Power --
   -----------------

   procedure Cycle_Power (V : State; S : in out Settings; T : VTX_Table.Table; Power_Step : Unsigned_8) is
      Power     : Unsigned_8 := 0;
      Known     : Boolean;
      New_Power : Integer;
   begin
      if not V.Device_Present then
         return;
      end if;
      Common_Get_Power_Index (V, T, Power, Known);
      if not Known then
         return;
      end if;
      New_Power := Integer (Power) + Integer (Power_Step);
      if New_Power >= T.Power_Levels then
         New_Power := 1;
      elsif New_Power < 0 then
         New_Power := T.Power_Levels;
      end if;
      S.Power := Unsigned_8 (New_Power);
   end Cycle_Power;

end Adaflight.VTX;
