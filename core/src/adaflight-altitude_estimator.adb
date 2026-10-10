package body Adaflight.Altitude_Estimator with SPARK_Mode is
   use Position_Filter;
   use type Interfaces.Unsigned_32;

   Sample_Time_S          : constant Float := 1.0 / Float (Task_Rate_Hz);
   Initial_Variance       : constant := 10_000.0;
   Jerk_Density_Z         : constant := 3_000.0;
   Acceleration_Noise     : constant := 500.0;
   Baro_Noise             : constant := 70.0;
   Gravity_Cmss           : constant Float := 980.665;
   Measurement_Timeout_Us : constant := 2_000_000;
   Max_Vertical_Speed_Cms : constant := 4_000.0;
   Step_Allowance_Cm      : constant := 50.0;
   Step_Max_Interval_S    : constant := 0.2;
   Step_Max_Rejects       : constant := 10;

   type Step_Action is (Full, Position_Only, Reject);

   function Held (V : Float) return Altitude_Cm is (Constrain_F (V, -State_Bound, State_Bound));

   --  The barometer's step gate: a reading more than the allowance from the
   --  last accepted one, at the vertical speed limit over the sample
   --  interval, is rejected until ten in a row, when it re-anchors the
   --  position alone.
   procedure Gate_Step
     (G : in out Step_Gate; Measured_Cm : Altitude_Cm; Interval_Us : Integer_32; Action : out Step_Action)
   is
   begin
      if G.Has_Reference then
         declare
            Interval_S : constant Float range 0.0 .. Step_Max_Interval_S :=
              Constrain_F (Float (Interval_Us) * 1.0e-6, 0.0, Step_Max_Interval_S);
            Allowance  : constant Float := Step_Allowance_Cm + Max_Vertical_Speed_Cms * Interval_S;
         begin
            if abs (Measured_Cm - G.Last_Accepted_Cm) > Allowance then
               if G.Rejects + 1 < Step_Max_Rejects then
                  G.Rejects := G.Rejects + 1;
                  Action := Reject;
                  return;
               end if;
               G.Rejects := 0;
               G.Last_Accepted_Cm := Measured_Cm;
               Action := Position_Only;
               return;
            end if;
         end;
      end if;
      G.Rejects := 0;
      G.Last_Accepted_Cm := Measured_Cm;
      G.Has_Reference := True;
      Action := Full;
   end Gate_Step;

   --  The filter and the barometer's offset, gate, and record back to their
   --  start, as at a change of arming; the outputs follow from the update.
   procedure Reset_Z (S : in out State) is
   begin
      Init (S.Up, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_Z);
      S.Last_Z_Measurement_Us := 0;
      S.Baro_Offset_Cm := 0.0;
      S.Baro_Offset_Set := False;
      S.Baro_Gate := (others => <>);
   end Reset_Z;

   --  A smoothing cutoff in hundredths of a hertz at the task rate.
   function Smoothing_Gain (Cutoff : Positive) return Unit_Interval is
     (Filters.PT2_Gain (Float (Cutoff) / 100.0, Sample_Time_S))
     with Pre => Cutoff <= 5_000;

   --  The smoothing filters back at their cutoffs; the outputs follow from
   --  the update.
   procedure Reset_Smoothing (S : in out State; C : Settings) is
   begin
      Filters.PT2_Init (S.Altitude_Filter, Smoothing_Gain (C.Altitude_LPF));
      Filters.PT2_Init (S.Derivative_Filter, Smoothing_Gain (C.Derivative_LPF));
   end Reset_Smoothing;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Armed : Boolean) is
      Up                : Position_Filter.Filter;
      Altitude_Filter   : Filters.PT2;
      Derivative_Filter : Filters.PT2;
   begin
      Filters.PT2_Init (Altitude_Filter, Smoothing_Gain (C.Altitude_LPF));
      Filters.PT2_Init (Derivative_Filter, Smoothing_Gain (C.Derivative_LPF));
      Init (Up, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_Z);
      S := (Up                => Up,
            Altitude_Filter   => Altitude_Filter,
            Derivative_Filter => Derivative_Filter,
            Was_Armed         => Armed,
            others            => <>);
   end Init;

   ------------
   -- Update --
   ------------

   --  The vertical acceleration in the earth frame, in centimeters per
   --  second squared, with gravity removed: the up row of the rotation over
   --  the scaled counts, as the reference forms it.
   function Vertical_Acceleration (Inp : Inputs) return Altitude_Cm
     with Pre => Vectors.Bounded (Inp.Acc, Acc_Bound) and then Vectors.Bounded (Inp.Rotation, Rotation_Bound)
   is
      subtype Scaled is Float range -Acc_Bound .. Acc_Bound;
      subtype Term is Float range -2.0 ** 21 .. 2.0 ** 21;
      subtype Pair is Float range -2.0 ** 22 .. 2.0 ** 22;
      subtype Up is Float range -2.0 ** 23 .. 2.0 ** 23;
      Ax : constant Scaled := Inp.Acc.X * Inp.One_G_Reciprocal;
      Ay : constant Scaled := Inp.Acc.Y * Inp.One_G_Reciprocal;
      Az : constant Scaled := Inp.Acc.Z * Inp.One_G_Reciprocal;
      R  : Vectors.Matrix33 renames Inp.Rotation;
      Earth_Up : constant Up :=
        Pair'(Term'(R (Vectors.Z, Vectors.X) * Ax) + Term'(R (Vectors.Z, Vectors.Y) * Ay))
        + Term'(R (Vectors.Z, Vectors.Z) * Az);
   begin
      return Held ((Earth_Up - 1.0) * Gravity_Cmss);
   end Vertical_Acceleration;

   --  The barometer's latest sample is ready while it is new and within the
   --  hold interval the sensor reports.
   procedure Baro_Ready (S : in out State; Inp : Inputs; Ready : out Boolean) is
      Has_New : constant Boolean := not S.Baro_Data_Available or else Inp.Baro_Sample_Time_Us /= S.Baro_Timestamp_Us;
   begin
      if Has_New then
         S.Baro_Data_Available := True;
         S.Baro_Timestamp_Us := Inp.Baro_Sample_Time_Us;
         S.Baro_Hold_Us := Inp.Baro_Interval_Us;
      end if;
      declare
         Age : constant Integer_32 := Clock.Elapsed (Inp.Now_Us, S.Baro_Timestamp_Us);
         Within_Hold : constant Boolean :=
           S.Baro_Data_Available and then S.Baro_Hold_Us > 0 and then Age >= 0 and then Age < S.Baro_Hold_Us;
      begin
         Ready := (Has_New and then S.Baro_Hold_Us <= 0) or else Within_Hold;
      end;
   end Baro_Ready;

   procedure Feed_Barometer (S : in out State; C : Settings; Inp : Inputs) is
      Ready  : Boolean;
      Action : Step_Action;
   begin
      if not Inp.Baro_Present then
         S.Baro_Data_Available := False;
         return;
      end if;
      if C.Source = GPS_Only or else C.Source = Rangefinder_Only then
         return;
      end if;
      Baro_Ready (S, Inp, Ready);
      if not Ready then
         return;
      end if;
      if not S.Baro_Offset_Set then
         S.Baro_Offset_Cm := Inp.Baro_Altitude_Cm;
         S.Baro_Offset_Set := True;
      end if;
      declare
         Trust    : constant Float range 0.1 .. 1.0 := Constrain_F (Float (C.Prefer_Baro) * 0.01, 0.1, 1.0);
         Noise    : constant Position_Filter.Noise := Baro_Noise / Trust;
         Relative : constant Altitude_Cm := Held (Inp.Baro_Altitude_Cm - S.Baro_Offset_Cm);
      begin
         Gate_Step (S.Baro_Gate, Relative, Inp.Baro_Interval_Us, Action);
         case Action is
            when Reject =>
               return;
            when Full =>
               Update_Position_To_Velocity (S.Up, Relative, Noise);
            when Position_Only =>
               Update_Position (S.Up, Relative, Noise);
         end case;
         S.Last_Z_Measurement_Us := Inp.Now_Us;
      end;
   end Feed_Barometer;

   procedure Update (S : in out State; C : Settings; Inp : Inputs) is
   begin
      if Inp.Armed /= S.Was_Armed then
         Reset_Z (S);
         Reset_Smoothing (S, C);
         S.Was_Armed := Inp.Armed;
      end if;
      Update_Acceleration (S.Up, (if Inp.Armed then Vertical_Acceleration (Inp) else 0.0), Acceleration_Noise);
      Predict (S.Up, Sample_Time_S);
      Feed_Barometer (S, C, Inp);
      S.Position_Up := S.Up.X (Position);
      S.Velocity_Up := S.Up.X (Velocity);
      S.Acceleration_Up := S.Up.X (Acceleration);
      S.Valid_Z := S.Last_Z_Measurement_Us > 0
        and then Clock.Elapsed (Inp.Now_Us, S.Last_Z_Measurement_Us) < Measurement_Timeout_Us;
      declare
         --  The trust falls with the position variance; a variance below zero
         --  has no meaning, so the trust is one there (DESIGN.md D33).
         Denominator : constant Float := 1.0 + S.Up.P (Position, Position) / Initial_Variance;
      begin
         if Denominator >= 1.0 then
            S.Trust_Z := Constrain_F (1.0 / Denominator, 0.0, 1.0);
         else
            S.Trust_Z := 1.0;
         end if;
      end;
      Filters.PT2_Apply (S.Altitude_Filter, S.Position_Up, S.Filtered_Altitude_Cm);
      S.Display_Altitude_Cm := S.Filtered_Altitude_Cm;
      S.Control_Altitude_Cm := S.Position_Up;
      S.Control_Derivative := S.Velocity_Up;
      S.Control_Acceleration := S.Acceleration_Up;
      Filters.PT2_Apply (S.Derivative_Filter, S.Control_Derivative, S.Filtered_Derivative);
   end Update;

   ---------------------------
   -- Estimated_Altitude_Cm --
   ---------------------------

   function Estimated_Altitude_Cm (S : State) return Integer is
   begin
      if abs S.Display_Altitude_Cm <= Float (Rounding_Bound) - 1.0 then
         return Round_Half_Even (S.Display_Altitude_Cm);
      elsif S.Display_Altitude_Cm > 0.0 then
         return Rounding_Bound;
      else
         return -Rounding_Bound;
      end if;
   end Estimated_Altitude_Cm;

end Adaflight.Altitude_Estimator;
