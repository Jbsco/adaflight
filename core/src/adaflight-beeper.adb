with Adaflight.Clock;

package body Adaflight.Beeper with SPARK_Mode is
   use type Interfaces.Integer_32;

   Confirmation_On  : constant := 2;
   Confirmation_Gap : constant := 20;
   Warning_Long_Per : constant := 5;
   Flash_Count      : constant := 5;
   Flash_Steps      : constant := 5;
   Pause_Steps      : constant := 50;
   Long_Code_Steps  : constant := 25;
   Short_Code_Steps : constant := 5;
   Minimum_Satellites : constant := 4;
   Beacon_Guard_Us    : constant := 1_200_000;
   Beacon_Interval_Us : constant := 450_000;
   Beacon_Max_Age_Us  : constant := 60_000_000;

   Short_Beep         : constant Sequence := (10, 10, others => Stop);
   Arming_Beep        : constant Sequence := (30, 5, 5, 5, others => Stop);
   Arming_Fix_Beep    : constant Sequence := (5, 5, 15, 5, 5, 5, 15, 30, others => Stop);
   Arming_No_Fix_Beep : constant Sequence := (30, 5, 30, 5, 30, 5, others => Stop);
   Armed_Beep         : constant Sequence := (0, 245, 10, 5, others => Stop);
   Disarm_Beep        : constant Sequence := (15, 5, 15, 5, others => Stop);
   Disarm_Repeat_Beep : constant Sequence := (0, 100, 10, others => Stop);
   Low_Battery_Beep   : constant Sequence := (25, 50, others => Stop);
   Critical_Battery_Beep : constant Sequence := (50, 2, others => Stop);
   Lost_Beep          : constant Sequence := (50, 50, others => Stop);
   SOS_Beep           : constant Sequence :=
     (10, 10, 10, 10, 10, 40, 40, 10, 40, 10, 40, 40, 10, 10, 10, 10, 10, 70, others => Stop);
   Ready_Beep         : constant Sequence := (4, 5, 4, 5, 8, 5, 15, 5, 8, 5, 4, 5, 4, 5, others => Stop);
   Two_Short_Beeps    : constant Sequence := (5, 5, 5, 5, others => Stop);
   Two_Longer_Beeps   : constant Sequence := (20, 15, 35, 5, others => Stop);
   Calibrated_Beep    : constant Sequence := (20, 10, 20, 10, 20, 10, others => Stop);
   Camera_Open_Beep   : constant Sequence := (5, 15, 10, 15, 20, others => Stop);
   Camera_Close_Beep  : constant Sequence := (10, 8, 5, others => Stop);

   function Priority (M : Sound) return Table_Index is
     (case M is
         when Gyro_Calibrated => 0, when Rx_Lost => 1, when Rx_Lost_Landing => 2,
         when Disarming => 3, when Arming => 4, when Arming_GPS_Fix => 5,
         when Arming_GPS_No_Fix => 6, when Battery_Critical_Low => 7, when Battery_Low => 8,
         when GPS_Status => 9, when Rx_Set => 10, when Acc_Calibration => 11,
         when Acc_Calibration_Fail => 12, when Ready => 13, when Multi_Beeps => 14,
         when Disarm_Repeat => 15, when Armed => 16, when System_Init => 17, when USB => 18,
         when Blackbox_Erase => 19, when Crash_Flip => 20, when Camera_Open => 21,
         when Camera_Close => 22, when All_Sounds => 23);

   function Has_Sequence (M : Sound) return Boolean is (M not in System_Init | USB | All_Sounds);

   --  The sequence of a sound; the satellite count and the multi beeps play
   --  the buffer.
   function Sequence_Of (S : State; M : Sound) return Sequence is
     (case M is
         when Gyro_Calibrated => Calibrated_Beep, when Rx_Lost => Lost_Beep,
         when Rx_Lost_Landing => SOS_Beep, when Disarming => Disarm_Beep,
         when Arming => Arming_Beep, when Arming_GPS_Fix => Arming_Fix_Beep,
         when Arming_GPS_No_Fix => Arming_No_Fix_Beep,
         when Battery_Critical_Low => Critical_Battery_Beep, when Battery_Low => Low_Battery_Beep,
         when GPS_Status | Multi_Beeps => S.Multi, when Rx_Set => Short_Beep,
         when Acc_Calibration | Blackbox_Erase => Two_Short_Beeps,
         when Acc_Calibration_Fail | Crash_Flip => Two_Longer_Beeps, when Ready => Ready_Beep,
         when Disarm_Repeat => Disarm_Repeat_Beep, when Armed => Armed_Beep,
         when Camera_Open => Camera_Open_Beep, when Camera_Close => Camera_Close_Beep,
         when System_Init | USB | All_Sounds => (others => Stop));

   --  Silent on the bench: the USB flag set, no battery, and a link.
   function Bench_Suppressed (C : Settings; Cond : Conditions) return Boolean is
     (C.Off_Flags (USB) and then not Cond.Battery_Present
      and then (Cond.USB_Active or else Cond.Configurator_Active));

   --------------------
   -- Silence_Beeper --
   --------------------

   procedure Silence_Beeper (S : in out State) is
   begin
      S.Is_On := False;
      S.Warning_Led := False;
      S.Current := Silence;
      S.Pos := 0;
      S.Next_Toggle_Us := 0;
   end Silence_Beeper;

   -------------
   -- Request --
   -------------

   procedure Request (S : in out State; C : Settings; Cond : Conditions; M : Mode) is
   begin
      if M = Silence or else Bench_Suppressed (C, Cond) or else Cond.Mute_Switch then
         Silence_Beeper (S);
         return;
      end if;
      if not Has_Sequence (M) then
         return;
      end if;
      if S.Current /= Silence and then Priority (M) >= Priority (S.Current) then
         return;
      end if;
      S.Current := M;
      S.Pos := 0;
      S.Next_Toggle_Us := 0;
   end Request;

   --  Count beeps of On tenths added to the buffer at Pos, Off between them
   --  and Off_Last after the last when it is not zero, leaving room for the
   --  stop.
   procedure Add_Beeps (
      Buffer   : in out Sequence;
      Pos      : in out Step_Index;
      Count    : Natural;
      On       : Step;
      Off      : Step;
      Off_Last : Step
   ) is
      Left : Natural := Count;
   begin
      while Pos < 2 * Max_Multi - 1 and then Left > 0 loop
         pragma Loop_Invariant (Pos < 2 * Max_Multi - 1);
         Buffer (Pos) := On;
         Pos := Pos + 1;
         if Left > 1 or else Off_Last /= 0 then
            Buffer (Pos) := (if Left > 1 then Off else Off_Last);
            Pos := Pos + 1;
         end if;
         Left := Left - 1;
      end loop;
   end Add_Beeps;

   ------------------------
   -- Confirmation_Beeps --
   ------------------------

   procedure Confirmation_Beeps (S : in out State; C : Settings; Cond : Conditions; Count : Beep_Count) is
      Pos : Step_Index := 0;
   begin
      Add_Beeps (S.Multi, Pos, Count, Confirmation_On, Confirmation_Gap, Confirmation_Gap);
      S.Multi (Pos) := Stop;
      Request (S, C, Cond, Multi_Beeps);
   end Confirmation_Beeps;

   -------------------
   -- Warning_Beeps --
   -------------------

   procedure Warning_Beeps (S : in out State; C : Settings; Cond : Conditions; Count : Beep_Count) is
      Pos : Step_Index := 0;
   begin
      Add_Beeps (S.Multi, Pos, Flash_Count - 1, Flash_Steps, Flash_Steps, Pause_Steps);
      Add_Beeps (S.Multi, Pos, Count / Warning_Long_Per, Long_Code_Steps, Long_Code_Steps, Pause_Steps);
      Add_Beeps (S.Multi, Pos, Count mod Warning_Long_Per, Short_Code_Steps, Long_Code_Steps, 0);
      S.Multi (Pos) := Stop;
      Request (S, C, Cond, Multi_Beeps);
   end Warning_Beeps;

   --  One beep per satellite with a fix above the minimum count.
   procedure Satellite_Beeps (S : in out State; C : Settings; Cond : Conditions) is
      Pos : Step_Index := 0;
   begin
      if not C.Off_Flags (GPS_Status) then
         if Cond.GPS_Fix and then Cond.Satellites > Minimum_Satellites then
            Add_Beeps (S.Multi, Pos, Cond.Satellites, 5, 10, 50);
            S.Multi (Pos) := Stop;
            Request (S, C, Cond, Multi_Beeps);
         end if;
      end if;
   end Satellite_Beeps;

   type Advance is (On_First, On, Off, Done, Error);

   --  The next step of the playing sequence: the toggle time from its
   --  duration, odd positions on and even off, a repeat back to the start
   --  once, and a stop. A sequence that runs to the end of its buffer
   --  without a stop ends as an error.
   procedure Advance_Sequence (S : in out State; Now_Us : Time_Us; Result : out Advance)
     with Pre  => S.Current /= Silence,
          Post => S.Current = S.Current'Old
   is
      Seq        : constant Sequence := Sequence_Of (S, S.Current);
      Orig       : constant Step_Index := S.Pos;
      Was_Repeat : Boolean := False;
   begin
      loop
         case Seq (S.Pos) is
            when Repeat =>
               if Was_Repeat then
                  Result := Error;
                  return;
               end if;
               Was_Repeat := True;
               S.Pos := 0;
            when Stop =>
               Result := Done;
               return;
            when 0 =>
               if S.Pos = Step_Index'Last then
                  Result := Error;
                  return;
               end if;
               S.Pos := S.Pos + 1;
            when others =>
               S.Next_Toggle_Us := Now_Us + 1_000 * 10 * Unsigned_32 (Seq (S.Pos));
               if S.Pos = Step_Index'Last then
                  Result := Error;
                  return;
               end if;
               S.Pos := S.Pos + 1;
               if S.Pos mod 2 = 1 then
                  Result := (if Orig /= 0 then On else On_First);
               else
                  Result := Off;
               end if;
               return;
         end case;
      end loop;
   end Advance_Sequence;

   ------------
   -- Update --
   ------------

   procedure Update (
      S      : in out State;
      C      : Settings;
      Cond   : Conditions;
      Now_Us : Time_Us;
      Result : out Update_Outputs
   ) is
      Visual : Boolean := False;
      Next   : Advance;
   begin
      Result := (others => False);
      if Cond.Beep_Switch then
         Request (S, C, Cond, Rx_Set);
      elsif Cond.GPS_Feature and then Cond.Satellite_Switch then
         Satellite_Beeps (S, C, Cond);
      end if;
      declare
         Requested : Boolean := False;
      begin
         if not Cond.Motors_Running then
            if Cond.Failsafe_Monitoring and then not Cond.Failsafe_Receiving
              and then not Cond.Configurator_Active and then not C.Beacon_Off_Flags (Rx_Lost)
            then
               Requested := True;
            end if;
            if Cond.Beep_Switch and then Cond.Failsafe_Receiving
              and then not C.Beacon_Off_Flags (Rx_Set) and then not Bench_Suppressed (C, Cond)
            then
               Requested := True;
            end if;
         end if;
         if Requested
           and then Clock.Elapsed (Now_Us, Cond.Last_Disarm_Us) > Beacon_Guard_Us
           and then not Cond.Trying_To_Arm
           and then Clock.Elapsed (Now_Us, S.Last_Beacon_Us) > Beacon_Interval_Us
         then
            S.Last_Beacon_Us := Now_Us;
            Result.Beacon_Command := True;
         end if;
         declare
            Age : constant Interfaces.Integer_32 := Clock.Elapsed (Now_Us, S.Last_Beacon_Us);
         begin
            if Age < 0 or else Age > Beacon_Max_Age_Us then
               S.Last_Beacon_Us := Now_Us - Beacon_Max_Age_Us;
            end if;
         end;
      end;
      if S.Current = Silence then
         return;
      end if;
      if S.Next_Toggle_Us /= 0 and then Clock.Elapsed (S.Next_Toggle_Us, Now_Us) > 0 then
         Result.Ignore_Exec_Time := True;
         return;
      end if;
      Advance_Sequence (S, Now_Us, Next);
      if Next = On_First and then S.Current in Arming | Arming_GPS_Fix | Arming_GPS_No_Fix then
         S.Arming_Beep_Us := Now_Us;
      end if;
      case Next is
         when On_First | On =>
            if not C.Off_Flags (S.Current) and then not Bench_Suppressed (C, Cond) then
               S.Is_On := True;
               Visual := True;
            end if;
            S.Warning_Led := True;
         when Off =>
            S.Is_On := False;
            S.Warning_Led := False;
         when Done | Error =>
            Silence_Beeper (S);
      end case;
      if Visual and then not S.Visual_Was_On then
         Result.Visual_Beep := True;
      end if;
      S.Visual_Was_On := Visual;
   end Update;

end Adaflight.Beeper;
