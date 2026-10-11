package body Adaflight.Arming with SPARK_Mode is
   use type Interfaces.Integer_64;

   Arm_Delay_Ms               : constant := 500;
   Stick_Delay_Ms             : constant := 50;
   Stick_Autorepeat_Ms        : constant := 250;
   Failsafe_Power_On_Delay_Us : constant := 5_000_000;

   Only_Calibrating : constant Disable_Set := (Calibrating => True, others => False);

   --  A pulse in microseconds on the unit stick range, and a span of pulses.
   subtype Pulse_Us is Float range -1.0e4 .. 1.0e4;
   function Normalized (Pulse : Pulse_Us) return Float is ((Pulse - 1_500.0) * 2.0 / 1_000.0);
   function Span_Normalized (Pulse : Pulse_Us) return Float is (Pulse * 2.0 / 1_000.0);

   function Combo (Roll, Pitch, Yaw, Throttle : Stick_Position) return Stick_Positions is
     (0 => Roll, 1 => Pitch, 2 => Yaw, 3 => Throttle);

   procedure Bump (N : in out Small_Count) is
   begin
      if N < Small_Count'Last then
         N := N + 1;
      end if;
   end Bump;

   procedure Request (B : in out Beeps; Tone : Beep; Count : Small_Count := 0) is
   begin
      Bump (B.Calls);
      B.Last := Tone;
      B.Count := Count;
   end Request;

   --  The one-based position of the first set reason, zero for none.
   function First_Reason (D : Disable_Set) return Reason_Index is
   begin
      for R in Disable_Reason loop
         if D (R) then
            return Disable_Reason'Pos (R) + 1;
         end if;
      end loop;
      return 0;
   end First_Reason;

   function Is_Calibrating (C : Settings; Sensed : Inputs) return Boolean is
     ((C.Sensors.Gyro and then not Sensed.Gyro_Calibrated)
      or else (C.Sensors.Acc and then not Sensed.Acc_Calibrated)
      or else (C.Sensors.Baro and then not Sensed.Baro_Calibrated)
      or else (C.Sensors.Mag and then not Sensed.Mag_Calibrated));

   --  An accelerometer without a calibration blocks arming when a mode or
   --  the launch control angle limit would read it.
   function Acc_Needs_Calibration (C : Settings; Conds : Modes.Conditions; Sensed : Inputs) return Boolean is
     (C.Sensors.Acc and then not Sensed.Acc_Has_Calibration
      and then (Modes.Condition_Present (Conds, Modes.Angle)
                or else Modes.Condition_Present (Conds, Modes.Horizon)
                or else Modes.Condition_Present (Conds, Modes.Alt_Hold)
                or else Modes.Condition_Present (Conds, Modes.Pos_Hold)
                or else Modes.Condition_Present (Conds, Modes.GPS_Rescue)
                or else Modes.Condition_Present (Conds, Modes.Cam_Stab)
                or else Modes.Condition_Present (Conds, Modes.Calib)
                or else Modes.Condition_Present (Conds, Modes.Acro_Trainer)
                or else (Modes.Condition_Present (Conds, Modes.Launch_Control)
                         and then C.Launch_Control_Angle_Limit /= 0)));

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Conds : Modes.Conditions) is
   begin
      S := (others => <>);
      S.Disabled (Boot_Grace) := True;
      S.Sticks_Arm := not Modes.Condition_Present (Conds, Modes.Arm) and then C.Stick_Arming;
   end Init;

   ---------------------
   -- Throttle_Status --
   ---------------------

   function Throttle_Status (C : Settings; Channels : RC_Command.Channel_Values; Three_D_Switch : Boolean)
                             return Throttle_Level
   is
      Value     : constant Float := Normalized (Channels (RC_Command.Throttle_Channel));
      Min_Check : constant Float := Normalized (Float (C.Min_Check));
   begin
      if C.Three_D then
         if Three_D_Switch or else C.Switched_Mode_3D then
            if Value < Min_Check then
               return Throttle_Low;
            end if;
         elsif abs (Value - Normalized (Float (C.Mid_RC))) < Span_Normalized (Float (C.Deadband_3D_Throttle)) then
            return Throttle_Low;
         end if;
      elsif Value < Min_Check then
         return Throttle_Low;
      end if;
      return Throttle_High;
   end Throttle_Status;

   ----------------------
   -- Throttle_Percent --
   ----------------------

   function Throttle_Percent (C : Settings; Channels : RC_Command.Channel_Values; Three_D_Switch : Boolean)
                              return Integer
   is
      subtype Unit is Float range -1.0 .. 1.0;
      Value    : constant Unit :=
        Float'Max (-1.0, Float'Min (1.0, Normalized (Channels (RC_Command.Throttle_Channel))));
      Fraction : Unit := 0.0;
   begin
      if C.Three_D and then not Three_D_Switch and then not C.Switched_Mode_3D then
         declare
            Mid      : constant Float := Normalized (Float (C.Mid_RC));
            Deadband : constant Float := Span_Normalized (Float (C.Deadband_3D_Throttle));
         begin
            --  The quotients stay within the unit range in the reference's
            --  domain; the bounds and the zero divisor guard are inert there
            --  (DESIGN.md D24).
            if Value > Mid + Deadband then
               declare
                  Divisor : constant Float := 1.0 - Mid - Deadband;
               begin
                  if Divisor > 0.0 then
                     Fraction := Float'Max (-1.0, Float'Min (1.0, (Value - Mid - Deadband) / Divisor));
                  end if;
               end;
            elsif Value < Mid - Deadband then
               declare
                  Divisor : constant Float := Mid - Deadband + 1.0;
               begin
                  if Divisor > 0.0 then
                     Fraction := Float'Max (-1.0, Float'Min (1.0, (Value - Mid + Deadband) / Divisor));
                  end if;
               end;
            end if;
         end;
      else
         declare
            Min_Check : constant Float := Normalized (Float (C.Min_Check));
            Divisor   : constant Float := 1.0 - Min_Check;
         begin
            if Divisor > 0.0 then
               Fraction := Float'Max (0.0, Float'Min (1.0, (Value - Min_Check) / Divisor));
            end if;
            if C.Three_D and then Three_D_Switch and then C.Switched_Mode_3D then
               Fraction := -Fraction;
            end if;
         end;
      end if;
      return Integer (Float'Truncation (Fraction * 100.0));
   end Throttle_Percent;

   -------------------
   -- Update_Status --
   -------------------

   procedure Update_Status (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Conds    : Modes.Conditions;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us
   ) is
      Three_D_Switch : constant Boolean := Modes.Is_Active (M, Modes.Three_D);
      Arm_Switch_On  : constant Boolean := Modes.Is_Active (M, Modes.Arm);
   begin
      if S.Armed then
         return;
      end if;
      if S.Disabled (Boot_Grace) and then Now_Us / 1_000 >= Time_Us (C.Boot_Grace_Time) * 1_000 then
         S.Disabled (Boot_Grace) := False;
      end if;
      --  An arm switch left on while the link was down must not arm when
      --  the link returns.
      if not S.Sticks_Arm then
         if not S.Had_Rx and then Sensed.Rx_Signal and then Arm_Switch_On then
            S.Disabled (Not_Disarmed) := True;
         elsif Sensed.Rx_Signal and then not Arm_Switch_On then
            S.Disabled (Not_Disarmed) := False;
         end if;
         S.Had_Rx := Sensed.Rx_Signal;
      end if;
      if S.Disabled (Crash_Flip_Block) and then S.Disarm_Requested then
         S.Disabled (Crash_Flip_Block) := False;
      end if;
      S.Disabled (Box_Failsafe) := Modes.Is_Active (M, Modes.Failsafe);
      S.Disabled (Alt_Hold_Switch) := Modes.Is_Active (M, Modes.Alt_Hold);
      S.Disabled (Pos_Hold_Switch) := Modes.Is_Active (M, Modes.Pos_Hold);
      S.Disabled (Throttle) := Throttle_Status (C, Channels, Three_D_Switch) /= Throttle_Low;
      S.Disabled (Angle) := not Sensed.Upright and then not Modes.Is_Active (M, Modes.Crash_Flip);
      S.Disabled (Calibrating) := Is_Calibrating (C, Sensed);
      if Modes.Condition_Present (Conds, Modes.Prearm) then
         S.Disabled (No_Prearm) :=
           not (Modes.Is_Active (M, Modes.Prearm) and then (not S.Armed_With_Prearm or else C.Prearm_Allow_Rearm));
      end if;
      if Modes.Is_Active (M, Modes.Paralyze) then
         S.Disabled (Paralyzed) := True;
      end if;
      S.Disabled (Acc_Uncalibrated) := Acc_Needs_Calibration (C, Conds, Sensed);
      if not Sensed.Motor_Protocol_Enabled then
         S.Disabled (Motor_Protocol) := True;
      end if;
      if not S.Sticks_Arm then
         if not Arm_Switch_On then
            S.Disabled (Runaway_Disarm) := False;
            S.Disabled (Crash_Disarm) := False;
         end if;
         declare
            --  The calibration alone does not latch the switch when the first
            --  arm calibrates, nor the throttle alone in 3D without its switch.
            Ignore_Gyro     : constant Boolean :=
              C.Gyro_Cal_On_First_Arm
              and then (for all R in Disable_Reason =>
                          (if R /= Arm_Switch and then R /= Calibrating then not S.Disabled (R)));
            Ignore_Throttle : constant Boolean :=
              C.Three_D and then not Three_D_Switch and then not C.Switched_Mode_3D
              and then (for all R in Disable_Reason =>
                          (if R /= Arm_Switch and then R /= Throttle then not S.Disabled (R)));
         begin
            if Arming_Disabled (S) and then not Ignore_Gyro and then not Ignore_Throttle and then Arm_Switch_On then
               S.Disabled (Arm_Switch) := True;
            elsif not Arm_Switch_On then
               S.Disabled (Arm_Switch) := False;
            end if;
         end;
      end if;
   end Update_Status;

   ------------
   -- Disarm --
   ------------

   procedure Disarm (S : in out State; Reason : Disarm_Reason; Now_Us : Time_Us; Out_Step : in out Outputs) is
   begin
      Bump (Out_Step.Disarm_Calls);
      S.Last_Disarm_Reason := Reason;
      if S.Armed then
         S.Was_Ever_Armed := True;
         S.Armed := False;
         S.Last_Disarm_Us := Now_Us;
         if not (S.Disabled (Runaway_Disarm) or else S.Disabled (Crash_Disarm)) then
            Request (Out_Step.Beeper, Disarm_Tone);
         end if;
      end if;
   end Disarm;

   -------------
   -- Try_Arm --
   -------------

   --  Launch control arms only by a switch, with the launch box active, the
   --  motors running or airmode on, no 3D, and no flight mode selected.
   function Can_Use_Launch_Control (S : State; C : Settings; M : Modes.State) return Boolean is
     (not C.Fixed_Wing and then not S.Sticks_Arm and then Modes.Is_Active (M, Modes.Launch_Control)
      and then (not C.Motor_Stop or else M.Airmode_Enabled) and then not C.Three_D
      and then (for all F in Flight_Mode => not S.Flight_Modes (F)));

   Runaway_Sum_Threshold      : constant Float := 600.0;
   Runaway_Activate_Delay_Us  : constant := 75_000;
   Runaway_Stick_Percent      : constant Float := 15.0;
   Runaway_Sum_Limit          : constant Float := 100.0;
   Runaway_Gyro_Limit_RP      : constant := 15;
   Runaway_Gyro_Limit_Yaw     : constant := 50;
   Runaway_High_Throttle      : constant := 75;

   function Sticks_Active (Sensed : Inputs; Limit : Float) return Boolean is
     (for some A in Axes.Axis => Sensed.Deflection_Abs (A) * 100.0 >= Limit);

   procedure Try_Arm (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Conds    : Modes.Conditions;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Out_Step : in out Outputs
   ) is
   begin
      if C.Gyro_Cal_On_First_Arm then
         Bump (Out_Step.First_Arm_Gyro_Cal);
      end if;
      Update_Status (S, C, M, Conds, Sensed, Channels, Now_Us);
      if not Arming_Disabled (S) then
         if S.Armed then
            return;
         end if;
         if Can_Use_Launch_Control (S, C, M) and then S.Launch = Launch_Disabled then
            S.Launch := Launch_Active;
         end if;
         S.Armed := True;
         S.Runaway_Deactivate_Us := 0;
         S.Runaway_Accumulated_Us := 0;
         S.Runaway_Trigger_Us := 0;
         if Modes.Condition_Present (Conds, Modes.Prearm) then
            S.Armed_With_Prearm := True;
         end if;
         Bump (Out_Step.Headfree_Offsets);
         S.Disarm_At := Now_Us + Time_Us (C.Auto_Disarm_Delay) * 1_000_000;
         S.Last_Disabled_Reason := 0;
         Request (Out_Step.Beeper, Arm_Tone);
      elsif not Sensed.First_Arm_Gyro_Cal_Running then
         declare
            Reason : constant Reason_Index := First_Reason (S.Disabled);
         begin
            if S.Last_Disabled_Reason /= Reason then
               S.Last_Disabled_Reason := Reason;
               Request (Out_Step.Beeper, Warning_Tones, Reason);
            end if;
         end;
      end if;
   end Try_Arm;

   ----------------
   -- Process_Rx --
   ----------------

   --  Stable flight ends the runaway check: the throttle above the
   --  deactivation level with the sticks active, or above twice it, with every
   --  sum under its limit for the delay, halved at high throttle, summed over
   --  the stable spells.
   procedure Deactivate_Runaway_Check
     (S : in out State; C : Settings; M : Modes.State; Sensed : Inputs; Percent : Natural;
      Throttle_Active : Boolean; Now_Us : Time_Us)
     with Pre  => Percent <= 100,
          Post => S.Armed = S.Armed'Old and then S.Launch = S.Launch'Old and then S.Disabled = S.Disabled'Old
   is
      In_Stable_Flight : Boolean := False;
   begin
      if not C.Motor_Stop or else M.Airmode_Enabled or else Throttle_Active then
         declare
            Low : constant Natural := C.Runaway_Deactivate_Throttle;
            Mid : constant Natural := Integer'Min (Low * 2, Runaway_High_Throttle);
         begin
            if ((Percent >= Low and then Sticks_Active (Sensed, Runaway_Stick_Percent)) or else Percent >= Mid)
              and then abs Sensed.PID_Sums (Axes.Pitch) < Runaway_Sum_Limit
              and then abs Sensed.PID_Sums (Axes.Roll) < Runaway_Sum_Limit
              and then abs Sensed.PID_Sums (Axes.Yaw) < Runaway_Sum_Limit
            then
               In_Stable_Flight := True;
               if S.Runaway_Deactivate_Us = 0 then
                  S.Runaway_Deactivate_Us := Now_Us;
               end if;
            end if;
         end;
      end if;
      if In_Stable_Flight then
         if S.Runaway_Deactivate_Us = 0 then
            S.Runaway_Deactivate_Us := Now_Us;
         end if;
         declare
            Delay_Ms : constant Natural := (if Percent >= Runaway_High_Throttle then C.Runaway_Deactivate_Delay / 2
                                            else C.Runaway_Deactivate_Delay);
            Stable_Us : constant Interfaces.Integer_64 :=
              Interfaces.Integer_64 (Clock.Elapsed (Now_Us, S.Runaway_Deactivate_Us))
              + Interfaces.Integer_64 (S.Runaway_Accumulated_Us);
         begin
            if Stable_Us > Interfaces.Integer_64 (Delay_Ms) * 1_000 then
               S.Runaway_Check_Disabled := True;
            end if;
         end;
      else
         if S.Runaway_Deactivate_Us /= 0 then
            S.Runaway_Accumulated_Us := S.Runaway_Accumulated_Us + (Now_Us - S.Runaway_Deactivate_Us);
         end if;
         S.Runaway_Deactivate_Us := 0;
      end if;
   end Deactivate_Runaway_Check;

   procedure Process_Rx (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Out_Step : in out Outputs
   ) is
      Three_D_Switch  : constant Boolean := Modes.Is_Active (M, Modes.Three_D);
      Throttle_Active : constant Boolean := Throttle_Status (C, Channels, Three_D_Switch) /= Throttle_Low;
      Percent         : constant Natural := abs Throttle_Percent (C, Channels, Three_D_Switch);
      In_Launch       : constant Boolean := S.Launch = Launch_Active;
   begin
      if C.Three_D and then not Modes.Is_Active (M, Modes.Arm) then
         Disarm (S, Switch, Now_Us, Out_Step);
      end if;
      if Now_Us > Failsafe_Power_On_Delay_Us and then not Sensed.Failsafe_Monitoring then
         Out_Step.Start_Failsafe_Monitoring := True;
      end if;
      if S.Armed then
         if Percent >= C.Airmode_Threshold then
            S.Throttle_Raised := True;
         end if;
         if M.Airmode_Enabled and then not In_Launch then
            S.Airmode_Active := S.Throttle_Raised;
         end if;
      else
         S.Throttle_Raised := False;
         S.Airmode_Active := False;
      end if;
      if S.Armed and then (S.Airmode_Active or else Throttle_Active or else In_Launch or else C.Fixed_Wing) then
         Out_Step.Iterm_Reset := False;
         Out_Step.Stabilisation_On := True;
      else
         Out_Step.Iterm_Reset := True;
         Out_Step.Stabilisation_On := C.PID_At_Min_Throttle;
      end if;
      if S.Armed and then C.Runaway_Prevention and then not S.Runaway_Check_Disabled and then not C.Fixed_Wing then
         Deactivate_Runaway_Check (S, C, M, Sensed, Percent, Throttle_Active, Now_Us);
      end if;
      if S.Armed then
         if In_Launch and then Percent > C.Launch_Trigger_Throttle then
            S.Launch := Launch_Triggered;
            Bump (Out_Step.Iterm_Resets);
         end if;
      elsif S.Launch = Launch_Triggered then
         if C.Launch_Trigger_Reset and then not Modes.Is_Active (M, Modes.Launch_Control) then
            S.Launch := Launch_Disabled;
         end if;
      else
         S.Launch := Launch_Disabled;
      end if;
   end Process_Rx;

   ----------------------
   -- Process_PID_Loop --
   ----------------------

   procedure Process_PID_Loop (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Out_Step : in out Outputs
   ) is
      Three_D_Switch  : constant Boolean := Modes.Is_Active (M, Modes.Three_D);
      Throttle_Active : constant Boolean := Throttle_Status (C, Channels, Three_D_Switch) /= Throttle_Low;
   begin
      if S.Armed and then not C.Fixed_Wing and then C.Runaway_Prevention and then not S.Runaway_Check_Disabled
        and then not S.Flight_Modes (GPS_Rescue_Mode)
        and then (not C.Motor_Stop or else M.Airmode_Enabled or else Throttle_Active)
      then
         if (abs Sensed.PID_Sums (Axes.Pitch) >= Runaway_Sum_Threshold
             or else abs Sensed.PID_Sums (Axes.Roll) >= Runaway_Sum_Threshold
             or else abs Sensed.PID_Sums (Axes.Yaw) >= Runaway_Sum_Threshold)
           and then (Sensed.Gyro_Abs_Dps (Axes.Pitch) > Runaway_Gyro_Limit_RP
                     or else Sensed.Gyro_Abs_Dps (Axes.Roll) > Runaway_Gyro_Limit_RP
                     or else Sensed.Gyro_Abs_Dps (Axes.Yaw) > Runaway_Gyro_Limit_Yaw)
         then
            if S.Runaway_Trigger_Us = 0 then
               S.Runaway_Trigger_Us := Now_Us + Runaway_Activate_Delay_Us;
            elsif Clock.Elapsed (Now_Us, S.Runaway_Trigger_Us) > 0 then
               S.Disabled (Runaway_Disarm) := True;
               Disarm (S, Runaway_Takeoff, Now_Us, Out_Step);
            end if;
         else
            S.Runaway_Trigger_Us := 0;
         end if;
      else
         S.Runaway_Trigger_Us := 0;
      end if;
   end Process_PID_Loop;

   ---------------------
   -- Stick_Positions --
   ---------------------

   --  The stick combinations: arming and disarming, the calibrations, the
   --  profiles, the trims, and the dashboard, once per hold.
   procedure Process_Sticks (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Conds    : Modes.Conditions;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Delta_Us : Natural;
      Out_Step : in out Outputs
   ) is
      Min_Check : constant Float := Normalized (Float (C.Min_Check));
      Max_Check : constant Float := Normalized (Float (C.Max_Check));
      Held_Ms   : constant Natural := Delta_Us / 1_000;
      Current   : Stick_Positions;
   begin
      for Ch in RC_Command.Channel loop
         declare
            Value : constant Float := Normalized (Channels (Ch));
            Above : constant Boolean := Value > Min_Check;
            Below : constant Boolean := Value < Max_Check;
         begin
            Current (Ch) :=
              (if Above and then Below then Center elsif Above then High elsif Below then Low else Unplaced);
         end;
      end loop;
      if Current = S.Sticks then
         if S.Hold_Ms <= Hold_Time'Last - Held_Ms then
            S.Hold_Ms := S.Hold_Ms + Held_Ms;
         end if;
      else
         S.Hold_Ms := 0;
         S.Do_Not_Repeat := False;
      end if;
      S.Sticks := Current;

      if not S.Sticks_Arm then
         if Modes.Is_Active (M, Modes.Arm) then
            S.Disarm_Ticks := 0;
            Try_Arm (S, C, M, Conds, Sensed, Channels, Now_Us, Out_Step);
         else
            S.Disarm_Requested := True;
            S.Last_Disabled_Reason := 0;
            --  After a link loss the switch disarms only on validated frames,
            --  or on the failsafe switch, and only after three repeats.
            if S.Armed and then (Sensed.Failsafe_Receiving or else Modes.Is_Active (M, Modes.Failsafe)) then
               S.Disarm_Ticks := (S.Disarm_Ticks + 1) mod 256;
               if S.Disarm_Ticks > 3 then
                  Disarm (S, Switch, Now_Us, Out_Step);
               end if;
            end if;
         end if;
      elsif Current = Combo (Center, Center, Low, Low) then
         if S.Hold_Ms >= Arm_Delay_Ms and then not S.Do_Not_Repeat then
            S.Do_Not_Repeat := True;
            S.Disarm_Requested := True;
            if S.Armed then
               Disarm (S, Sticks, Now_Us, Out_Step);
            else
               Request (Out_Step.Beeper, Disarm_Repeat_Tone);
               S.Hold_Ms := S.Hold_Ms - Stick_Autorepeat_Ms;
               S.Do_Not_Repeat := False;
               S.Disabled (Runaway_Disarm) := False;
               S.Disabled (Crash_Disarm) := False;
            end if;
         end if;
         return;
      elsif Current = Combo (Center, Center, High, Low)
        and then not Modes.Is_Active (M, Modes.Stick_Command_Disable)
      then
         if S.Hold_Ms >= Arm_Delay_Ms and then not S.Do_Not_Repeat then
            S.Do_Not_Repeat := True;
            if not S.Armed then
               Try_Arm (S, C, M, Conds, Sensed, Channels, Now_Us, Out_Step);
               if S.Disabled = Only_Calibrating and then C.Gyro_Cal_On_First_Arm then
                  S.Do_Not_Repeat := False;
               end if;
            else
               S.Last_Disabled_Reason := 0;
            end if;
         end if;
         return;
      end if;

      if S.Armed or else S.Do_Not_Repeat or else S.Hold_Ms <= Stick_Delay_Ms
        or else S.Disabled (Runaway_Disarm) or else S.Disabled (Crash_Disarm)
      then
         return;
      end if;
      S.Do_Not_Repeat := True;
      if Current = Combo (Center, Low, Low, Low) then
         Out_Step.Commands (Gyro_Calibration) := True;
         if C.Sensors.Baro then
            Out_Step.Commands (Baro_Ground_Level) := True;
         end if;
         return;
      end if;
      if Current = Combo (Low, Center, Low, Low) then
         Out_Step.Commands (PID_Profile_1) := True;
         return;
      elsif Current = Combo (Center, High, Low, Low) then
         Out_Step.Commands (PID_Profile_2) := True;
         return;
      elsif Current = Combo (High, Center, Low, Low) then
         Out_Step.Commands (PID_Profile_3) := True;
         return;
      end if;
      if Current = Combo (High, Low, Low, Low) then
         Bump (Out_Step.Saves);
      end if;
      if Current = Combo (Center, Low, Low, High) then
         Out_Step.Commands (Acc_Calibration) := True;
         return;
      end if;
      if Current = Combo (Center, Low, High, High) then
         Out_Step.Commands (Mag_Calibration) := True;
         return;
      end if;
      if S.Flight_Modes (Angle_Mode) or else S.Flight_Modes (Horizon_Mode) then
         --  Level modes: the sticks trim the accelerometer, and the trims are
         --  saved once the throttle leaves the top.
         if S.Pending_Trim_Save and then Current (RC_Command.Throttle_Channel) /= High then
            Bump (Out_Step.Saves);
            S.Pending_Trim_Save := False;
            return;
         end if;
         declare
            Roll_Delta  : Trim_Delta := 0;
            Pitch_Delta : Trim_Delta := 0;
            Apply       : Boolean := False;
         begin
            if Current = Combo (Center, High, Center, High) then
               Pitch_Delta := 1;
               Apply := True;
            elsif Current = Combo (Center, Low, Center, High) then
               Pitch_Delta := -1;
               Apply := True;
            elsif Current = Combo (High, Center, Center, High) then
               Roll_Delta := 1;
               Apply := True;
            elsif Current = Combo (Low, Center, Center, High) then
               Roll_Delta := -1;
               Apply := True;
            end if;
            if Apply then
               Out_Step.Trim_Roll := Roll_Delta;
               Out_Step.Trim_Pitch := Pitch_Delta;
               S.Pending_Trim_Save := True;
               Request (Out_Step.Beeper, Confirmation_Tones, 1);
               S.Hold_Ms := S.Hold_Ms - Stick_Autorepeat_Ms;
               S.Do_Not_Repeat := False;
               return;
            end if;
         end;
      else
         if Current = Combo (Center, High, Center, High) then
            Out_Step.Commands (Rate_Profile_1) := True;
            return;
         elsif Current = Combo (Center, Low, Center, High) then
            Out_Step.Commands (Rate_Profile_2) := True;
            return;
         elsif Current = Combo (High, Center, Center, High) then
            Out_Step.Commands (Rate_Profile_3) := True;
            return;
         elsif Current = Combo (Low, Center, Center, High) then
            Out_Step.Commands (Rate_Profile_4) := True;
            return;
         end if;
      end if;
      if Current = Combo (Low, High, Center, Low) then
         Out_Step.Commands (Dashboard_Cycling_Off) := True;
      end if;
      if Current = Combo (High, High, Center, Low) then
         Out_Step.Commands (Dashboard_Cycling_On) := True;
      end if;
   end Process_Sticks;

   -------------------------
   -- Select_Flight_Modes --
   -------------------------

   procedure Set_Mode (S : in out State; Mode : Flight_Mode; On : Boolean; Out_Step : in out Outputs) is
   begin
      if S.Flight_Modes (Mode) /= On then
         S.Flight_Modes (Mode) := On;
         Request (Out_Step.Beeper, Confirmation_Tones, 1);
      end if;
   end Set_Mode;

   procedure Select_Flight_Modes (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Sensed   : Inputs;
      Out_Step : in out Outputs
   ) is
      Horizon_Allowed : Boolean := True;
   begin
      if (Modes.Is_Active (M, Modes.Angle) or else Sensed.Failsafe_Active) and then C.Sensors.Acc then
         Horizon_Allowed := False;
         Set_Mode (S, Angle_Mode, True, Out_Step);
      else
         Set_Mode (S, Angle_Mode, False, Out_Step);
      end if;
      if Modes.Is_Active (M, Modes.Horizon) and then Horizon_Allowed and then C.Sensors.Acc then
         Set_Mode (S, Angle_Mode, False, Out_Step);
         Set_Mode (S, Horizon_Mode, True, Out_Step);
      else
         Set_Mode (S, Horizon_Mode, False, Out_Step);
      end if;
      if not Modes.Is_Active (M, Modes.Prearm) and then S.Armed_With_Prearm then
         S.Armed_With_Prearm := False;
      end if;
      if C.Sensors.Acc or else C.Sensors.Mag then
         Set_Mode (S, Headfree_Mode,
                   Modes.Is_Active (M, Modes.Headfree) and then not S.Flight_Modes (GPS_Rescue_Mode), Out_Step);
         if Modes.Is_Active (M, Modes.Head_Adj) and then not S.Flight_Modes (GPS_Rescue_Mode) then
            Bump (Out_Step.Headfree_Offsets);
            if Sensed.Headfree_Offset_Set then
               Request (Out_Step.Beeper, Rx_Set_Tone);
            end if;
         end if;
      end if;
      Set_Mode (S, Passthru_Mode, Modes.Is_Active (M, Modes.Passthru), Out_Step);
      if C.Fixed_Wing then
         Set_Mode (S, Headfree_Mode, False, Out_Step);
      end if;
      Out_Step.Anti_Gravity := Modes.Is_Active (M, Modes.Anti_Gravity) or else C.Anti_Gravity_Feature;
   end Select_Flight_Modes;

   ----------------------
   -- Process_Rx_Modes --
   ----------------------

   procedure Process_Rx_Modes (
      S        : in out State;
      C        : Settings;
      M        : in out Modes.State;
      Conds    : Modes.Conditions;
      Aux      : Modes.Aux_Values;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Delta_Us : Natural;
      Out_Step : in out Outputs
   ) is
      Status        : constant Throttle_Level := Throttle_Status (C, Channels, Modes.Is_Active (M, Modes.Three_D));
      Auto_Delay_Us : constant Time_Us := Time_Us (C.Auto_Disarm_Delay) * 1_000_000;
   begin
      --  Armed with the motors stopped: beep, and disarm after the delay.
      if S.Armed and then C.Motor_Stop and then not C.Fixed_Wing and then not C.Three_D
        and then not M.Airmode_Enabled and then not S.Flight_Modes (GPS_Rescue_Mode)
      then
         if S.Sticks_Arm then
            if Status = Throttle_Low then
               if Auto_Delay_Us > 0 and then Clock.Elapsed (Now_Us, S.Disarm_At) > 0 then
                  Disarm (S, Throttle_Timeout, Now_Us, Out_Step);
                  S.Armed_Beeper_On := False;
               else
                  Request (Out_Step.Beeper, Armed_Tone);
                  S.Armed_Beeper_On := True;
               end if;
            else
               S.Disarm_At := Now_Us + Auto_Delay_Us;
               if S.Armed_Beeper_On then
                  Request (Out_Step.Beeper, Silence);
                  S.Armed_Beeper_On := False;
               end if;
            end if;
         elsif Status = Throttle_Low then
            Request (Out_Step.Beeper, Armed_Tone);
            S.Armed_Beeper_On := True;
         elsif S.Armed_Beeper_On then
            Request (Out_Step.Beeper, Silence);
            S.Armed_Beeper_On := False;
         end if;
      else
         S.Disarm_At := Now_Us + Auto_Delay_Us;
      end if;

      if not (Modes.Is_Active (M, Modes.Paralyze) and then not S.Armed) then
         Process_Sticks (S, C, M, Conds, Sensed, Channels, Now_Us, Delta_Us, Out_Step);
      end if;

      Modes.Update (M, Conds, Aux, Now_Us, C.Airmode_Feature);

      Select_Flight_Modes (S, C, M, Sensed, Out_Step);
   end Process_Rx_Modes;

end Adaflight.Arming;
