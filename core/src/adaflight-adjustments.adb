with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Clock;
with Adaflight.Simplified_Tuning;

package body Adaflight.Adjustments with SPARK_Mode is
   use Adaflight.PID_Profile;

   Step_Deflection    : constant Float := 0.4;
   Reset_Period_Ms    : constant Time_Ms := 500;
   Display_Latency_Ms : constant Time_Ms := 2_000;

   subtype Delta_Value is Integer range -1 .. 1;

   --  The reference's own ceilings on the adjusted settings; the feedforward
   --  stops at the profile's bound (DESIGN.md D6).
   RC_Rate_Max : constant := 255;
   Expo_Max    : constant := 100;
   Rate_Max    : constant := 255;
   PID_Max     : constant := 200;

   function Clamp (V : Integer; Low : Integer; High : Integer) return Integer is
     (Integer'Min (Integer'Max (V, Low), High))
     with Pre  => Low <= High,
          Post => Clamp'Result in Low .. High;

   function Position_Limit (K : Select_Kind; Six : Boolean) return Position_Count is
     (if K = Rate_Profile and then Six then 6 else Positions (K));

   --  The modes of the PID audio by switch position: the three sums to the
   --  left of the center, off from the center up.
   type Audio_Map is array (Natural range 0 .. 6) of Audio_Mode;
   Audio_By_Position : constant Audio_Map :=
     (PID_Sum_X, PID_Sum_Y, PID_Sum_XY, Off, Off, Off, Off);

   procedure Beep (Result : in out Outputs; Count : Beep_Count)
     with Pre  => Result.Beep_Requests < Max_Ranges,
          Post => Result.Beep_Requests = Result.Beep_Requests'Old + 1
                  and then Result.PID_Reinit = Result.PID_Reinit'Old
                  and then Result.RC_Reinit = Result.RC_Reinit'Old
                  and then Result.Battery_Reinit = Result.Battery_Reinit'Old
   is
   begin
      Result.Beeps := Count;
      Result.Beep_Requests := Result.Beep_Requests + 1;
   end Beep;

   --  A stepping function moved by one step, pitch before roll where both
   --  move, as the reference orders them; the value is the last one set.
   procedure Step (
      R      : in out Rates.Profile;
      P      : in out PID_Profile.Profile;
      K      : Function_Kind;
      D      : Delta_Value;
      Value  : out Shown_Value;
      Result : in out Outputs
   )
     with Pre  => Result.Beep_Requests < Max_Ranges,
          Post => Result.Beep_Requests = Result.Beep_Requests'Old + 1
   is
      procedure Set_Rate (A : Axis) is
      begin
         R.Super_Rates (A) := Clamp (R.Super_Rates (A) + D, 0, Rate_Max);
      end Set_Rate;

      procedure Set_P (A : Axis) is
      begin
         P.Gains (A).P := Clamp (P.Gains (A).P + D, 0, PID_Max);
      end Set_P;

      procedure Set_I (A : Axis) is
      begin
         P.Gains (A).I := Clamp (P.Gains (A).I + D, 0, PID_Max);
      end Set_I;

      procedure Set_D (A : Axis) is
      begin
         P.Gains (A).D := Clamp (P.Gains (A).D + D, 0, PID_Max);
      end Set_D;

      procedure Set_F (A : Axis) is
      begin
         P.Gains (A).F := Clamp (P.Gains (A).F + D, 0, F_Gain_Max);
      end Set_F;
   begin
      Beep (Result, (if D > 0 then 2 else 1));
      case K is
         when RC_Rate =>
            R.RC_Rates (Roll) := Clamp (R.RC_Rates (Roll) + D, 1, RC_Rate_Max);
            R.RC_Rates (Pitch) := Clamp (R.RC_Rates (Pitch) + D, 1, RC_Rate_Max);
            Value := R.RC_Rates (Pitch);
         when RC_Expo =>
            R.RC_Expo (Roll) := Clamp (R.RC_Expo (Roll) + D, 0, Expo_Max);
            R.RC_Expo (Pitch) := Clamp (R.RC_Expo (Pitch) + D, 0, Expo_Max);
            Value := R.RC_Expo (Pitch);
         when Throttle_Expo =>
            R.Throttle_Expo := Clamp (R.Throttle_Expo + D, 0, Expo_Max);
            Value := R.Throttle_Expo;
            Result.RC_Reinit := True;
         when Pitch_Roll_Rate =>
            Set_Rate (Pitch);
            Set_Rate (Roll);
            Value := R.Super_Rates (Roll);
         when Pitch_Rate =>
            Set_Rate (Pitch);
            Value := R.Super_Rates (Pitch);
         when Roll_Rate =>
            Set_Rate (Roll);
            Value := R.Super_Rates (Roll);
         when Yaw_Rate =>
            Set_Rate (Yaw);
            Value := R.Super_Rates (Yaw);
         when Pitch_Roll_P =>
            Set_P (Pitch);
            Set_P (Roll);
            Value := P.Gains (Roll).P;
         when Pitch_P =>
            Set_P (Pitch);
            Value := P.Gains (Pitch).P;
         when Roll_P =>
            Set_P (Roll);
            Value := P.Gains (Roll).P;
         when Yaw_P =>
            Set_P (Yaw);
            Value := P.Gains (Yaw).P;
         when Pitch_Roll_I =>
            Set_I (Pitch);
            Set_I (Roll);
            Value := P.Gains (Roll).I;
         when Pitch_I =>
            Set_I (Pitch);
            Value := P.Gains (Pitch).I;
         when Roll_I =>
            Set_I (Roll);
            Value := P.Gains (Roll).I;
         when Yaw_I =>
            Set_I (Yaw);
            Value := P.Gains (Yaw).I;
         when Pitch_Roll_D =>
            Set_D (Pitch);
            Set_D (Roll);
            Value := P.Gains (Roll).D;
         when Pitch_D =>
            Set_D (Pitch);
            Value := P.Gains (Pitch).D;
         when Roll_D =>
            Set_D (Roll);
            Value := P.Gains (Roll).D;
         when Yaw_D =>
            Set_D (Yaw);
            Value := P.Gains (Yaw).D;
         when RC_Rate_Yaw =>
            R.RC_Rates (Yaw) := Clamp (R.RC_Rates (Yaw) + D, 1, RC_Rate_Max);
            Value := R.RC_Rates (Yaw);
         when Pitch_Roll_F =>
            Set_F (Pitch);
            Set_F (Roll);
            Value := P.Gains (Roll).F;
         when Pitch_F =>
            Set_F (Pitch);
            Value := P.Gains (Pitch).F;
         when Roll_F =>
            Set_F (Roll);
            Value := P.Gains (Roll).F;
         when Yaw_F =>
            Set_F (Yaw);
            Value := P.Gains (Yaw).F;
         when Feedforward_Transition =>
            P.Feedforward_Transition := Clamp (P.Feedforward_Transition + D, 1, Expo_Max);
            Value := P.Feedforward_Transition;
         when None | Rate_Profile | Horizon_Strength | PID_Audio | OSD_Profile | LED_Profile
            | LED_Dimmer | Master_Multiplier | Battery_Profile =>
            Value := -1;
      end case;
   end Step;

   --  A stepping function set from a dial's value, in the same order.
   procedure Absolute (
      R      : in out Rates.Profile;
      P      : in out PID_Profile.Profile;
      K      : Function_Kind;
      V      : Integer;
      Value  : out Shown_Value;
      Result : in out Outputs
   )
     with Post => Result.Beep_Requests = Result.Beep_Requests'Old
   is
      procedure Set_Rate (A : Axis) is
      begin
         R.Super_Rates (A) := Clamp (V, 0, Rate_Max);
      end Set_Rate;

      procedure Set_P (A : Axis) is
      begin
         P.Gains (A).P := Clamp (V, 0, PID_Max);
      end Set_P;

      procedure Set_I (A : Axis) is
      begin
         P.Gains (A).I := Clamp (V, 0, PID_Max);
      end Set_I;

      procedure Set_D (A : Axis) is
      begin
         P.Gains (A).D := Clamp (V, 0, PID_Max);
      end Set_D;

      procedure Set_F (A : Axis) is
      begin
         P.Gains (A).F := Clamp (V, 0, F_Gain_Max);
      end Set_F;
   begin
      case K is
         when RC_Rate =>
            R.RC_Rates (Roll) := Clamp (V, 1, RC_Rate_Max);
            R.RC_Rates (Pitch) := R.RC_Rates (Roll);
            Value := R.RC_Rates (Pitch);
         when RC_Expo =>
            R.RC_Expo (Roll) := Clamp (V, 0, Expo_Max);
            R.RC_Expo (Pitch) := R.RC_Expo (Roll);
            Value := R.RC_Expo (Pitch);
         when Throttle_Expo =>
            R.Throttle_Expo := Clamp (V, 0, Expo_Max);
            Value := R.Throttle_Expo;
            Result.RC_Reinit := True;
         when Pitch_Roll_Rate =>
            Set_Rate (Pitch);
            Set_Rate (Roll);
            Value := R.Super_Rates (Roll);
         when Pitch_Rate =>
            Set_Rate (Pitch);
            Value := R.Super_Rates (Pitch);
         when Roll_Rate =>
            Set_Rate (Roll);
            Value := R.Super_Rates (Roll);
         when Yaw_Rate =>
            Set_Rate (Yaw);
            Value := R.Super_Rates (Yaw);
         when Pitch_Roll_P =>
            Set_P (Pitch);
            Set_P (Roll);
            Value := P.Gains (Roll).P;
         when Pitch_P =>
            Set_P (Pitch);
            Value := P.Gains (Pitch).P;
         when Roll_P =>
            Set_P (Roll);
            Value := P.Gains (Roll).P;
         when Yaw_P =>
            Set_P (Yaw);
            Value := P.Gains (Yaw).P;
         when Pitch_Roll_I =>
            Set_I (Pitch);
            Set_I (Roll);
            Value := P.Gains (Roll).I;
         when Pitch_I =>
            Set_I (Pitch);
            Value := P.Gains (Pitch).I;
         when Roll_I =>
            Set_I (Roll);
            Value := P.Gains (Roll).I;
         when Yaw_I =>
            Set_I (Yaw);
            Value := P.Gains (Yaw).I;
         when Pitch_Roll_D =>
            Set_D (Pitch);
            Set_D (Roll);
            Value := P.Gains (Roll).D;
         when Pitch_D =>
            Set_D (Pitch);
            Value := P.Gains (Pitch).D;
         when Roll_D =>
            Set_D (Roll);
            Value := P.Gains (Roll).D;
         when Yaw_D =>
            Set_D (Yaw);
            Value := P.Gains (Yaw).D;
         when RC_Rate_Yaw =>
            R.RC_Rates (Yaw) := Clamp (V, 1, RC_Rate_Max);
            Value := R.RC_Rates (Yaw);
         when Pitch_Roll_F =>
            Set_F (Pitch);
            Set_F (Roll);
            Value := P.Gains (Roll).F;
         when Pitch_F =>
            Set_F (Pitch);
            Value := P.Gains (Pitch).F;
         when Roll_F =>
            Set_F (Roll);
            Value := P.Gains (Roll).F;
         when Yaw_F =>
            Set_F (Yaw);
            Value := P.Gains (Yaw).F;
         when Feedforward_Transition =>
            P.Feedforward_Transition := Clamp (V, 1, Expo_Max);
            Value := P.Feedforward_Transition;
         when None | Rate_Profile | Horizon_Strength | PID_Audio | OSD_Profile | LED_Profile
            | LED_Dimmer | Master_Multiplier | Battery_Profile =>
            Value := -1;
      end case;
   end Absolute;

   --  A selecting function set to a switch position: a profile change with
   --  its reinitialization and one beep per position, the horizon strength
   --  with a beep per eight of change, the master multiplier moved from its
   --  position at entry through the dial's sensitivity, or a peripheral mode.
   procedure Select_Position (
      S      : in out State;
      P      : in out PID_Profile.Profile;
      K      : Select_Kind;
      Pos    : Position;
      Six    : Boolean;
      Scale  : Dial_Setting;
      Value  : out Shown_Value;
      Result : in out Outputs
   )
     with Pre  => Pos < Position_Limit (K, Six) and then Result.Beep_Requests < Max_Ranges,
          Post => Result.Beep_Requests <= Result.Beep_Requests'Old + 1
                  and then S.Step_Count = S.Step_Count'Old and then S.Dial_Count = S.Dial_Count'Old
   is
      Beeps : Beep_Count := 0;
   begin
      Value := Pos;
      case K is
         when Rate_Profile =>
            if S.Selected.Rate_Profile /= Pos then
               if Pos < Rate_Profile_Count then
                  S.Selected.Rate_Profile := Pos;
               end if;
               Result.RC_Reinit := True;
               Beeps := Pos + 1;
            end if;
         when Battery_Profile =>
            if S.Selected.Battery_Profile /= Pos then
               S.Selected.Battery_Profile := Pos;
               Result.Battery_Reinit := True;
               Beeps := Pos + 1;
            end if;
         when Horizon_Strength =>
            declare
               New_Value : constant Natural range 10 .. 200 := Clamp (Pos, 10, PID_Max);
            begin
               if P.Level.D /= New_Value then
                  Beeps := ((New_Value - P.Level.D) / 8 + 1) mod 256;
                  P.Level.D := New_Value;
               end if;
            end;
         when Master_Multiplier =>
            if not S.Base_Set then
               S.Center_Position := Pos;
               S.Base_Multiplier := P.Simplified_Master_Multiplier;
               S.Base_Set := True;
            end if;
            declare
               Sensitivity : constant Natural range 0 .. 250 :=
                 Clamp ((if Scale > 0 then Scale else 125), 0, 250);
               Change      : constant Integer := (Pos - S.Center_Position) * Sensitivity / 100;
               New_Value   : constant Tuning_Factor := Clamp (S.Base_Multiplier + Change, 20, 200);
            begin
               if New_Value /= P.Simplified_Master_Multiplier then
                  P.Simplified_Master_Multiplier := New_Value;
                  Simplified_Tuning.Apply_PIDs (P);
                  Result.PID_Reinit := True;
               end if;
               Value := P.Simplified_Master_Multiplier;
               return;
            end;
         when PID_Audio =>
            if Audio_By_Position (Pos) /= S.Selected.Audio then
               S.Selected.Audio := Audio_By_Position (Pos);
            end if;
         when OSD_Profile =>
            null;
         when LED_Profile =>
            if S.Selected.LED_Profile /= Pos then
               S.Selected.LED_Profile := Pos;
            end if;
         when LED_Dimmer =>
            if S.Selected.LED_Brightness /= Pos then
               S.Selected.LED_Brightness := Pos;
            end if;
      end case;
      if Beeps > 0 then
         Beep (Result, Beeps);
      end if;
   end Select_Position;

   --  The display takes a value other than the rate profile's, and clears
   --  its name two seconds after the last change.
   procedure Show (S : in out State; Value : Shown_Value; K : Function_Kind; Now_Ms : Time_Ms)
     with Post => S.Step_Count = S.Step_Count'Old and then S.Dial_Count = S.Dial_Count'Old
   is
      use type Interfaces.Integer_32;
   begin
      if Value /= -1 and then K /= Rate_Profile then
         S.Shown := (Kind => K, Value => Value, Changed_Ms => Now_Ms);
      end if;
      if Clock.Elapsed (Now_Ms, S.Shown.Changed_Ms + Display_Latency_Ms) >= 0 then
         S.Shown.Kind := None;
      end if;
   end Show;

   --  Every range that is set joins the step list when it steps from a zero
   --  center, and the dial list otherwise.
   procedure List_Ranges (S : in out State; R : Ranges)
     with Post => S.Listed
   is
   begin
      S.Step_Count := 0;
      S.Dial_Count := 0;
      for I in Range_Index loop
         pragma Loop_Invariant (S.Step_Count + S.Dial_Count <= I);
         if R (I) /= Unset then
            if R (I).Center = 0 and then R (I).Kind not in Select_Kind then
               S.Steps (S.Step_Count) := (Index => I, Timeout_Ms => 0, Ready => True);
               S.Step_Count := S.Step_Count + 1;
            else
               S.Dials (S.Dial_Count) := (Index => I, Last_Aux => 0.0);
               S.Dial_Count := S.Dial_Count + 1;
            end if;
         end if;
      end loop;
      S.Listed := True;
   end List_Ranges;

   ----------------
   -- Reset_List --
   ----------------

   procedure Reset_List (S : in out State) is
   begin
      S.Listed := False;
   end Reset_List;

   -------------
   -- Process --
   -------------

   procedure Process (
      S      : in out State;
      C      : Settings;
      R      : Ranges;
      Rate   : in out Rate_Profiles;
      P      : in out PID_Profile.Profile;
      Inp    : Inputs;
      Result : out Outputs
   ) is
      use type Interfaces.Integer_32;
      Active : constant Rate_Profile_Index := S.Selected.Rate_Profile;
      Center : constant Float := Modes.Normalized (Float (C.Mid_RC));
      Low    : constant Float range -1.25 .. -1.15 := Modes.Step_Normalized (0);
      High   : constant Float range 1.15 .. 1.25 := Modes.Step_Normalized (Modes.Max_Range_Step);

      --  The steps: the ready timer runs while the range is active, a held
      --  switch past the deflection applies one step and waits for the timer,
      --  and the switch back at the center arms the next step at once.
      procedure Process_Steps
        with Pre  => Result.Beep_Requests = 0,
             Post => Result.Beep_Requests <= S.Step_Count
      is
      begin
         for I in 0 .. S.Step_Count - 1 loop
            pragma Loop_Invariant (Result.Beep_Requests <= I);
            pragma Loop_Invariant (S.Step_Count = S.Step_Count'Loop_Entry
                                   and then S.Dial_Count = S.Dial_Count'Loop_Entry);
            declare
               Rg : constant Adjustment_Range := R (S.Steps (I).Index);
            begin
               if not Modes.Range_Active (Inp.Aux, Rg.Aux, Rg.Span) or else Rg.Kind = None then
                  S.Steps (I).Timeout_Ms := 0;
               else
                  if Clock.Elapsed (Inp.Now_Ms, S.Steps (I).Timeout_Ms) >= 0 then
                     S.Steps (I).Timeout_Ms := Inp.Now_Ms + Reset_Period_Ms;
                     S.Steps (I).Ready := True;
                  end if;
                  if Inp.Rx_Signal then
                     declare
                        Deflection : constant Float := Modes.Normalized (Inp.Aux (Rg.Switch_Aux)) - Center;
                     begin
                        if Deflection > Step_Deflection or else Deflection < -Step_Deflection then
                           if S.Steps (I).Ready then
                              declare
                                 Value : Shown_Value;
                              begin
                                 Step (Rate (Active), P, Rg.Kind, (if Deflection > Step_Deflection then 1 else -1),
                                       Value, Result);
                                 S.Config_Dirty := True;
                                 Result.PID_Reinit := True;
                                 S.Steps (I).Ready := False;
                                 Show (S, Value, Rg.Kind, Inp.Now_Ms);
                              end;
                           end if;
                        else
                           S.Steps (I).Ready := True;
                           S.Steps (I).Timeout_Ms := Inp.Now_Ms + Reset_Period_Ms;
                        end if;
                     end;
                  end if;
               end if;
            end;
         end loop;
      end Process_Steps;

      --  The dials: a changed switch channel in an active range selects by
      --  its position or sets the function from the dial; an inactive range
      --  forgets the channel, and the master multiplier its position at entry.
      procedure Process_Dials
        with Pre => Result.Beep_Requests <= S.Step_Count
      is
      begin
         for I in 0 .. S.Dial_Count - 1 loop
            pragma Loop_Invariant (Result.Beep_Requests <= S.Step_Count + I);
            pragma Loop_Invariant (S.Step_Count = S.Step_Count'Loop_Entry
                                   and then S.Dial_Count = S.Dial_Count'Loop_Entry);
            declare
               Rg : constant Adjustment_Range := R (S.Dials (I).Index);
               Ch : constant Modes.Aux_Channel := Rg.Switch_Aux;
            begin
               if Modes.Range_Active (Inp.Aux, Rg.Aux, Rg.Span) and then Rg.Kind /= None then
                  if Inp.Aux (Ch) /= S.Dials (I).Last_Aux then
                     declare
                        Value : Shown_Value := -1;
                     begin
                        if Rg.Kind in Select_Kind then
                           declare
                              Count    : constant Position_Count :=
                                Position_Limit (Rg.Kind, C.Rate_Profile_6_Position);
                              Fraction : constant Float range 0.0 .. 1.1 :=
                                (Constrain_F (Modes.Normalized (Inp.Aux (Ch)), Low, High) - Low) / (High - Low);
                              Pos      : constant Position :=
                                Natural'Min (Integer (Float'Truncation (Fraction * Float (Count))), Count - 1);
                           begin
                              Select_Position (S, P, Rg.Kind, Pos, C.Rate_Profile_6_Position, Rg.Scale, Value, Result);
                           end;
                           if not (Rg.Span.Start_Step = 0 and then Rg.Span.End_Step = Modes.Max_Range_Step) then
                              S.Config_Dirty := True;
                           end if;
                        elsif Rg.Center /= 0 then
                           declare
                              Raw : constant Float :=
                                Modes.Normalized (Inp.Aux (Ch)) * Float (Rg.Scale) + Float (Rg.Center);
                              V   : constant Integer :=
                                Integer (Float'Truncation (Constrain_F (Raw, -2.0 ** 30, 2.0 ** 30)));
                           begin
                              Absolute (Rate (Active), P, Rg.Kind, V, Value, Result);
                           end;
                           if not (Rg.Span.Start_Step = 0 and then Rg.Span.End_Step = Modes.Max_Range_Step) then
                              S.Config_Dirty := True;
                           end if;
                           Result.PID_Reinit := True;
                        end if;
                        Show (S, Value, Rg.Kind, Inp.Now_Ms);
                     end;
                     S.Dials (I).Last_Aux := Inp.Aux (Ch);
                  end if;
               else
                  S.Dials (I).Last_Aux := 0.0;
                  if Rg.Kind = Master_Multiplier then
                     S.Base_Set := False;
                  end if;
               end if;
            end;
         end loop;
      end Process_Dials;
   begin
      Result := (others => <>);
      if not S.Listed then
         List_Ranges (S, R);
      end if;
      Process_Steps;
      if Inp.Rx_Signal then
         Process_Dials;
      end if;
      Show (S, -1, None, Inp.Now_Ms);
   end Process;

end Adaflight.Adjustments;
