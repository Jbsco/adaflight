with Interfaces; use type Interfaces.Unsigned_32;
with Adaflight.Clock;
with Adaflight.PID_Profile;

package body Adaflight.RC_Command with SPARK_Mode is

   Min_Smoothing_Cutoff_Hz : constant Float := 15.0;

   function Saturate_Signal (X : Float) return Signal is
     (Constrain_F (X, -Signal_Bound, Signal_Bound));

   --  A quotient whose divisor the caller has kept away from zero.
   function Bounded_Ratio (N : Float; D : Float) return Float
     with Pre  => abs N <= 16.0 and then abs D > 1.0e-6,
          Post => abs Bounded_Ratio'Result <= 1.6e7
   is
   begin
      return N / D;
   end Bounded_Ratio;
   Rate_Smoothing_Factor   : constant Float := 0.1;

   --  The quadratic Bezier segment solved for the parameter at X, then
   --  evaluated, as the reference builds its throttle curve.
   function Quadratic_Bezier
     (X : Unit_Interval; P0X, P1X, P2X : Unit_Interval; P0Y, P1Y, P2Y : Float) return Float
     with Pre  => P0Y in -2.0 .. 2.0 and then P1Y in -2.0 .. 2.0 and then P2Y in -2.0 .. 2.0,
          Post => Quadratic_Bezier'Result in -8.0 .. 8.0
   is
      A    : constant Float := P0X - 2.0 * P1X + P2X;
      B    : constant Float := 2.0 * P1X - 2.0 * P0X;
      Cc   : constant Float := P0X - X;
      T    : Float := 0.0;
      Disc : Float;
   begin
      pragma Assert (abs A <= 4.0 and then abs B <= 4.0 and then abs Cc <= 1.0);
      if abs A < 1.0e-6 then
         if abs B > 1.0e-6 then
            T := Bounded_Ratio (-Cc, B);
         end if;
      else
         Disc := B * B - 4.0 * A * Cc;
         if Disc >= 0.0 then
            declare
               Root : constant Float := Float'Min (Sqrt_Bounded (Constrain_F (Disc, 0.0, 64.0)), 8.0);
               T1   : constant Float := Bounded_Ratio (-B + Root, 2.0 * A);
               T2   : constant Float := Bounded_Ratio (-B - Root, 2.0 * A);
            begin
               if T1 >= 0.0 and then T1 <= 1.0 then
                  T := T1;
               else
                  T := T2;
               end if;
            end;
         end if;
      end if;
      T := Constrain_F (T, 0.0, 1.0);
      return (1.0 - T) * (1.0 - T) * P0Y + 2.0 * (1.0 - T) * T * P1Y + T * T * P2Y;
   end Quadratic_Bezier;

   procedure Update_Feedforward_Filters (S : in out State; R : Runtime) is
      K : constant Unit_Interval :=
        PT1_Gain_From_Delay (R.Feedforward_Smooth_Factor, 1.0 / S.Smoothed_Rate_Hz);
   begin
      for A in Axis loop
         PT1_Update_Cutoff (S.Speed_Filters (A), K);
         PT1_Update_Cutoff (S.Delta_Filters (A), K);
      end loop;
   end Update_Feedforward_Filters;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Config; R : Runtime) is
      Thr_Mid   : constant Unit_Interval := Float (C.Rates.Throttle_Mid) / 100.0;
      Expo      : constant Unit_Interval := Float (C.Rates.Throttle_Expo) / 100.0;
      Thr_Hover : constant Unit_Interval := Float (C.Rates.Throttle_Hover) / 100.0;
      CP1X : constant Unit_Interval := Thr_Mid * 0.5;
      CP1Y : constant Float := Thr_Hover * 0.5 * (1.0 + Expo);
      CP2X : constant Unit_Interval := (1.0 + Thr_Mid) * 0.5;
      CP2Y : constant Float := 1.0 + ((Thr_Hover - 1.0) * 0.5 * (1.0 + Expo));
   begin
      S := (others => <>);
      S.Command_Divider := 500.0 - Float (C.Controls.Deadband);
      S.Yaw_Divider := 500.0 - Float (C.Controls.Yaw_Deadband);
      for I in Table_Index loop
         declare
            X : constant Unit_Interval := Float (I) / Float (Throttle_Points - 1);
            Y : constant Float :=
              (if X <= Thr_Mid
               then Quadratic_Bezier (X, 0.0, CP1X, Thr_Mid, 0.0, CP1Y, Thr_Hover)
               else Quadratic_Bezier (X, Thr_Mid, CP2X, 1.0, Thr_Hover, CP2Y, 1.0));
            P : constant Float := Constrain_F (Scale_Range_F (Y, 0.0, 1.0, 1000.0, 2000.0), -7000.0, 10_000.0);
         begin
            S.Table (I) := Pulse (Integer'Max (1000, Integer'Min (2000, Round_Half_Even (P))));
         end;
      end loop;
      S.Auto_Setpoint_Factor := 1.5 / (1.0 + (Float (C.Receiver.Auto_Factor_Setpoint) / 10.0));
      S.Auto_Throttle_Factor := 1.5 / (1.0 + (Float (C.Receiver.Auto_Factor_Throttle) / 10.0));
      S.Setpoint_Cutoff_Hz := C.Receiver.Setpoint_Cutoff;
      S.Throttle_Cutoff_Hz := C.Receiver.Throttle_Cutoff;
      Update_Feedforward_Filters (S, R);
      S.Averaging := Averaging_Count (Adaflight.PID_Profile.Feedforward_Averaging'Pos (R.Feedforward_Average));
      PT1_Init (S.Yaw_Hold_Filter, 0.0);
      for A in Axis loop
         S.Max_Rate (A) := Adaflight.Rates.Apply (C.Rates, A, 1.0, 1.0);
         if S.Averaging > 0 then
            Moving_Average_Init (S.Averages (A), S.Averaging + 1);
         end if;
      end loop;
   end Init;

   -------------------------
   -- Update_Refresh_Rate --
   -------------------------

   procedure Update_Refresh_Rate
     (S : in out State; Time_Us : Unsigned_32; Receiving : Boolean; Frame_Time_Us : Unsigned_32)
   is
      Delta_Us : Integer := 0;
   begin
      if Receiving then
         S.Previous_Interval_Us := S.Current_Interval_Us;
         declare
            Rx_Time : constant Unsigned_32 := (if Frame_Time_Us /= 0 then Frame_Time_Us else Time_Us);
         begin
            if S.Last_Rx_Time_Us /= 0 then
               Delta_Us := Integer (Clock.Elapsed (Rx_Time, S.Last_Rx_Time_Us));
            end if;
            S.Last_Rx_Time_Us := Rx_Time;
         end;
      elsif S.Last_Rx_Time_Us /= 0 then
         Delta_Us := Integer (Clock.Elapsed (Time_Us, S.Last_Rx_Time_Us));
      end if;
      S.Current_Interval_Us := Integer'Max (Interval_Us'First, Integer'Min (Interval_Us'Last, Delta_Us));
      S.Current_Rate_Hz := 1.0e6 / Float (S.Current_Interval_Us);
      S.Rate_Valid := Delta_Us = S.Current_Interval_Us;
   end Update_Refresh_Rate;

   function Lookup_Throttle (S : State; Tmp : Natural) return Pulse
     with Pre => Tmp <= 1000
   is
      Steps  : constant := Throttle_Points - 1;
      Scaled : constant Natural := Tmp * Steps;
      Idx    : constant Natural := Scaled / 1000;
      Remainder : constant Natural := Scaled mod 1000;
   begin
      if Idx >= Steps then
         return S.Table (Steps);
      end if;
      return Pulse (Integer'Max (1000, Integer'Min (2000, Integer (Scale_Range
        (Interfaces.Integer_32 (Remainder), 0, 1000,
         Interfaces.Integer_32 (S.Table (Idx)), Interfaces.Integer_32 (S.Table (Idx + 1)))))));
   end Lookup_Throttle;

   ---------------------
   -- Update_Commands --
   ---------------------

   procedure Update_Commands (S : in out State; C : Config; Data : Channel_Values) is
   begin
      S.Data_New := True;
      for A in Axis loop
         declare
            RC : Float := Constrain_F (Data (Axis'Pos (A)) - Float (C.Receiver.Mid_RC), -500.0, 500.0);
            Deadband : constant Float :=
              (if A = Yaw then Float (C.Controls.Yaw_Deadband) else Float (C.Controls.Deadband));
         begin
            if A = Yaw then
               RC := RC * (if C.Controls.Yaw_Reversed then 1.0 else -1.0);
            end if;
            S.Command (Axis'Pos (A)) := Constrain_F (Apply_Deadband_F (RC, Deadband), -500.0, 500.0);
         end;
      end loop;
      declare
         Raw : constant Integer := Integer (Float'Truncation (Data (Throttle_Channel)));
         Tmp : Integer := Integer'Max (C.Receiver.Min_Check, Integer'Min (2000, Raw));
      begin
         pragma Assert (Tmp in C.Receiver.Min_Check .. 2000);
         Tmp := (Tmp - C.Receiver.Min_Check) * 1000 / (2000 - C.Receiver.Min_Check);
         pragma Assert (Tmp in 0 .. 1000);
         S.Command (Throttle_Channel) := Float (Lookup_Throttle (S, Tmp));
      end;
   end Update_Commands;

   procedure Should_Update_Smoothing (S : in out State; Update : out Boolean) is
   begin
      Update := False;
      if S.Rate_Valid then
         declare
            Delta_Rate : constant Float := S.Current_Rate_Hz - S.Smoothed_Rate_Hz;
            Outlier    : constant Boolean := abs Delta_Rate > S.Smoothed_Rate_Hz * 0.2;
         begin
            if Outlier then
               declare
                  Negative : constant Boolean := Delta_Rate < 0.0;
               begin
                  if S.Outlier_Count = 0 then
                     S.Prev_Outlier_Negative := Negative;
                     S.Outlier_Count := 1;
                  elsif Negative /= S.Prev_Outlier_Negative then
                     S.Outlier_Count := 0;
                     S.Prev_Outlier_Negative := Negative;
                  else
                     S.Outlier_Count := Natural'Min (3, S.Outlier_Count + 1);
                  end if;
               end;
               S.Valid_Count := 0;
            else
               S.Smoothed_Rate_Hz := Constrain_F
                 (S.Smoothed_Rate_Hz + Rate_Smoothing_Factor * (S.Current_Rate_Hz - S.Smoothed_Rate_Hz),
                  Rate_Hz'First, Rate_Hz'Last);
               S.Valid_Count := Natural'Min (3, S.Valid_Count + 1);
               S.Outlier_Count := 0;
            end if;
            if S.Valid_Count = 3 then
               S.Valid_Count := 0;
               Update := True;
               return;
            end if;
            if S.Outlier_Count = 3 then
               S.Smoothed_Rate_Hz := S.Current_Rate_Hz;
               S.Outlier_Count := 0;
            end if;
         end;
      else
         S.Valid_Count := 0;
         S.Outlier_Count := 0;
      end if;
   end Should_Update_Smoothing;

   procedure Set_Filter_Cutoffs (S : in out State; C : Config) is
      Dt : constant Float := Float (C.Loop_Time) * 1.0e-6;
   begin
      if S.Setpoint_Cutoff_Hz = 0 or else C.Receiver.Setpoint_Cutoff = 0 then
         S.Setpoint_Cutoff_Hz := Cutoff_Hz (Float'Truncation
           (Float'Max (Min_Smoothing_Cutoff_Hz, S.Smoothed_Rate_Hz * S.Auto_Setpoint_Factor)));
      else
         S.Setpoint_Cutoff_Hz := C.Receiver.Setpoint_Cutoff;
      end if;
      if C.Receiver.Throttle_Cutoff = 0 then
         S.Throttle_Cutoff_Hz := Cutoff_Hz (Float'Truncation
           (Float'Max (Min_Smoothing_Cutoff_Hz, S.Smoothed_Rate_Hz * S.Auto_Throttle_Factor)));
      else
         S.Throttle_Cutoff_Hz := C.Receiver.Throttle_Cutoff;
      end if;
      declare
         K_Setpoint : constant Unit_Interval := PT3_Gain (Float (S.Setpoint_Cutoff_Hz), Dt);
         K_Throttle : constant Unit_Interval := PT3_Gain (Float (S.Throttle_Cutoff_Hz), Dt);
      begin
         for A in Axis loop
            PT3_Update_Cutoff (S.Setpoint_Filters (Axis'Pos (A)), K_Setpoint);
            PT3_Update_Cutoff (S.Feedforward_Filters (A), K_Setpoint);
         end loop;
         PT3_Update_Cutoff (S.Setpoint_Filters (Throttle_Channel), K_Throttle);
         for A in Axis range Roll .. Pitch loop
            PT3_Update_Cutoff (S.Deflection_Filters (A), K_Setpoint);
         end loop;
      end;
   end Set_Filter_Cutoffs;

   subtype Frame_Rate is Float range 5.0 .. 1250.0;

   procedure Calculate_Feedforward (S : in out State; R : Runtime; A : Axis)
     with Post => S.Averaging = S.Averaging'Old
   is
      Rx_Interval  : constant Float := Float (S.Current_Interval_Us) * 1.0e-6;
      Command      : constant Float := S.Command (Axis'Pos (A));
      Delta_Cmd    : constant Float := Command - S.Prev_Command (A);
      Delta_Abs    : Float := abs Delta_Cmd;
      Duplicate    : constant Boolean := Delta_Abs = 0.0;
      Setpoint     : constant Signal := S.Raw_Setpoint (A);
      Setpoint_Delta : constant Float := Setpoint - S.Prev_Setpoint (A);
      Rx_Rate      : Frame_Rate := S.Current_Rate_Hz;
      Speed        : Float := 0.0;
      Speed_Delta  : Float;
      Feedforward  : Float;
      Boost        : Float;
   begin
      S.Prev_Command (A) := Saturate_Signal (Command);
      S.Prev_Setpoint (A) := Setpoint;
      if R.Feedforward_Interpolate then
         declare
            Prev_Interval : constant Float := S.Prev_Interval (A);
         begin
            if not Duplicate then
               if S.Prev_Duplicate (A) then
                  pragma Assert (Rx_Interval + Prev_Interval in 0.0008 .. 0.2);
                  Rx_Rate := 1.0 / (Rx_Interval + Prev_Interval);
               end if;
               Speed := Setpoint_Delta * Rx_Rate;
            elsif not S.Prev_Duplicate (A) then
               if abs Setpoint < 0.9 * S.Max_Rate (A) then
                  Speed := S.Prev_Speed (A) + S.Prev_Speed_Delta (A);
                  Delta_Abs := S.Prev_Delta_Abs (A);
               end if;
            else
               Speed := 0.0;
               S.Prev_Speed (A) := 0.0;
            end if;
            S.Prev_Interval (A) := Rx_Interval;
         end;
      else
         Speed := Setpoint_Delta * S.Current_Rate_Hz;
      end if;
      S.Prev_Duplicate (A) := Duplicate;
      declare
         Jitter : Float :=
           ((Delta_Abs + S.Prev_Delta_Abs (A)) * 0.5 + 1.0) * R.Feedforward_Jitter_Factor_Inv;
         Filtered_Speed : Signal;
         Filtered_Delta : Signal;
      begin
         Jitter := Float'Min (Jitter, 1.0);
         S.Prev_Delta_Abs (A) := Saturate_Signal (Delta_Abs);
         PT1_Apply (S.Speed_Filters (A), Saturate_Signal (Speed), Filtered_Speed);
         Speed_Delta := Filtered_Speed - S.Prev_Speed (A);
         S.Prev_Speed (A) := Filtered_Speed;
         PT1_Apply (S.Delta_Filters (A), Saturate_Signal (Speed_Delta), Filtered_Delta);
         S.Prev_Speed_Delta (A) := Filtered_Delta;
         Boost := Saturate_Signal (Filtered_Delta * Rx_Rate * R.Feedforward_Boost_Factor);
         Feedforward := Filtered_Speed;
         if A /= Yaw then
            Feedforward := Saturate_Signal (Feedforward + Boost);
            Feedforward := Feedforward * Jitter;
            if R.Feedforward_Max_Rate_Limit /= 0 and then Feedforward * Setpoint > 0.0 then
               declare
                  Limit : constant Float :=
                    (S.Max_Rate (A) - abs Setpoint) * Float (R.Feedforward_Max_Rate_Limit);
               begin
                  Feedforward := (if Limit > 0.0 then Constrain_F (Feedforward, -Limit, Limit) else 0.0);
               end;
            end if;
         else
            Feedforward := Feedforward * Jitter;
            declare
               Gain : constant Unit_Interval := PT1_Gain_From_Delay (R.Feedforward_Yaw_Hold_Time, Rx_Interval);
               Lowpassed : Signal;
            begin
               PT1_Update_Cutoff (S.Yaw_Hold_Filter, Gain);
               PT1_Apply (S.Yaw_Hold_Filter, Setpoint, Lowpassed);
               Feedforward := Saturate_Signal (Feedforward + R.Feedforward_Yaw_Hold_Gain * (Setpoint - Lowpassed));
            end;
         end if;
         if R.Feedforward_Transition /= 0.0 and then S.Deflection_Abs (A) < R.Feedforward_Transition then
            Feedforward := Saturate_Signal (Feedforward * (S.Deflection_Abs (A) * R.Feedforward_Transition_Inv));
         end if;
         if S.Averaging > 0 then
            declare
               Averaged : Signal;
            begin
               Moving_Average_Update (S.Averages (A), Saturate_Signal (Feedforward), Averaged);
               Feedforward := Averaged;
            end;
         end if;
         S.Feedforward_Raw (A) := Saturate_Signal (Feedforward);
      end;
   end Calculate_Feedforward;

   procedure Process_Smoothing (S : in out State; C : Config) is
   begin
      if S.Data_New then
         for A in Axis loop
            S.To_Smooth (A) := S.Raw_Setpoint (A);
         end loop;
         S.Throttle_To_Smooth := S.Command (Throttle_Channel);
      end if;
      if not C.Receiver.Smoothing then
         return;
      end if;
      for A in Axis loop
         PT3_Apply (S.Setpoint_Filters (Axis'Pos (A)), S.To_Smooth (A), S.Setpoint_Rate (A));
      end loop;
      declare
         Smoothed : Signal;
      begin
         PT3_Apply (S.Setpoint_Filters (Throttle_Channel), S.Throttle_To_Smooth, Smoothed);
         S.Command (Throttle_Channel) := Constrain_F (Smoothed, -500.0, 2000.0);
      end;
      for A in Axis loop
         PT3_Apply (S.Feedforward_Filters (A), S.Feedforward_Raw (A), S.Feedforward_Smoothed (A));
         S.Deflection_Smoothed (A) := S.Deflection (A);
      end loop;
   end Process_Smoothing;

   -------------
   -- Process --
   -------------

   procedure Process (S : in out State; C : Config; R : Runtime) is
   begin
      if S.Data_New then
         declare
            Update_Smoothing : Boolean;
         begin
            Should_Update_Smoothing (S, Update_Smoothing);
            if Update_Smoothing then
               Update_Feedforward_Filters (S, R);
               if C.Receiver.Smoothing then
                  Set_Filter_Cutoffs (S, C);
               end if;
            end if;
         end;
         S.Max_Deflection_Abs := 0.0;
         for A in Axis loop
            declare
               Command_F : constant Float :=
                 (if A = Yaw then S.Command (Axis'Pos (A)) / S.Yaw_Divider
                  else S.Command (Axis'Pos (A)) / S.Command_Divider);
               Deflection : constant Float := Constrain_F (Command_F, -1.0, 1.0);
               Magnitude  : constant Float := abs Deflection;
               Limit      : constant Float := Float (C.Rates.Limits (A));
            begin
               S.Deflection (A) := Deflection;
               S.Deflection_Abs (A) := Magnitude;
               S.Max_Deflection_Abs := Float'Max (S.Max_Deflection_Abs, Magnitude);
               S.Raw_Setpoint (A) := Constrain_F
                 (Adaflight.Rates.Apply (C.Rates, A, Deflection, Magnitude), -1.0 * Limit, 1.0 * Limit);
               Calculate_Feedforward (S, R, A);
            end;
         end loop;
      end if;
      Process_Smoothing (S, C);
      S.Data_New := False;
   end Process;

end Adaflight.RC_Command;
