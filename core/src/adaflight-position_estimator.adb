package body Adaflight.Position_Estimator with SPARK_Mode is
   use Position_Filter;

   Sample_Time_S           : constant Float := 1.0 / Float (Task_Rate_Hz);
   Initial_Variance        : constant := 10_000.0;
   Jerk_Density_Z          : constant := 3_000.0;
   Jerk_Density_XY         : constant := 1_500.0;
   Acceleration_Noise_Z    : constant := 500.0;
   Acceleration_Noise_XY   : constant := 1_500.0;
   Baro_Noise              : constant := 70.0;
   GPS_Velocity_Noise      : constant := 200.0;
   GPS_Position_Noise      : constant := 160.0;
   GPS_Velocity_Z_Noise    : constant := 100.0;
   GPS_Altitude_Noise      : constant := 200.0;
   Velocity_Accuracy_Denom : constant := 300.0;
   Position_Accuracy_Denom : constant := 1_000.0;
   Altitude_Accuracy_Denom : constant := 1_500.0;
   Cross_Cal_Tau_GPS_S     : constant := 200.0;
   Cross_Cal_Tau_RF_S      : constant := 2.0;
   Rangefinder_Noise       : constant := 100.0;
   Rangefinder_Min_Alt_Cm  : constant := 10.0;
   Near_Field_Min_Cm       : constant := 0.0;
   Near_Field_Noise_Scale  : constant := 4.0;
   Ground_Effect_Alt_Cm    : constant := 50.0;
   Ground_Effect_Full_Cm   : constant := 20.0;
   Ground_Effect_Scale     : constant := 200.0;
   Ground_Latch_Hold_Us    : constant := 1_000_000;
   Ground_Latch_Fade_Us    : constant := 1_000_000;
   On_Ground_Tolerance_Cm  : constant := 50.0;
   Min_Ground_Trust        : constant Float := Float'Machine (1.0 / Ground_Effect_Scale);
   Flow_Velocity_Noise     : constant := 200.0;
   Flow_Timeout_Us         : constant := 100_000;
   Radians_Per_Decidegree  : constant := 0.0174532925;
   Gravity_Cmss            : constant Float := 980.665;
   Measurement_Timeout_Us  : constant := 2_000_000;
   Max_Vertical_Speed_Cms  : constant := 4_000.0;
   Step_Allowance_Cm       : constant := 50.0;
   Step_Max_Interval_S     : constant := 0.2;
   Step_Max_Rejects        : constant := 10;

   --  One latitude unit, or one longitude unit at the equator, in
   --  centimetres, rounded at each step as the constant is formed.
   Earth_Angle_To_Cm : constant Float :=
     Float'Machine (Float'Machine (Float'Machine (Float'Machine (111.3195) * 1000.0) * 100.0) / 10_000_000.0);

   type Step_Action is (Full, Position_Only, Reject);

   function Held (V : Float) return Altitude_Cm is (Constrain_F (V, -State_Bound, State_Bound));

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function To_Unsigned (I : Integer_32) return Unsigned_32 is
     (if I < 0 then not Unsigned_32 (-(I + 1)) else Unsigned_32 (I));

   --  A latitude difference in thirty-two bits.
   function Wrapped_Difference (A, B : Integer_32) return Integer_32 is
     (To_Signed (To_Unsigned (A) - To_Unsigned (B)));

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

   --  The vertical filter, the barometer's offset, gate and record, the
   --  rangefinder's offset and gate, the ground effect latch, the GPS
   --  altitude offset and the calibration entries back to their start, as
   --  at a change of arming; the outputs follow from the update.
   procedure Reset_Z (S : in out State) is
   begin
      Init (S.Up, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_Z);
      S.Last_Z_Measurement_Us := 0;
      S.GPS_Alt_Offset_Cm := 0.0;
      S.GPS_Alt_Offset_Set := False;
      S.Baro_Offset_Cm := 0.0;
      S.Baro_Offset_Set := False;
      S.Baro_Gate := (others => <>);
      S.Baro_Raw_Cm := 0.0;
      S.Baro_Active := False;
      S.RF_Offset_Cm := 0.0;
      S.RF_Offset_Set := False;
      S.RF_Gate := (others => <>);
      S.Ground_AGL_Valid := False;
      S.RF_Active := False;
      S.GPS_Anchor_Tau_S := Cross_Cal_Tau_GPS_S;
      S.GPS_Anchor_Active := False;
   end Reset_Z;

   --  The horizontal filters back to their start; the origin stays, and the
   --  outputs follow from the next update.
   procedure Reset_XY_Filter (S : in out State) is
   begin
      Init (S.East, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_XY);
      Init (S.North, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_XY);
   end Reset_XY_Filter;

   --  The horizontal outputs and validity dropped with the filters, for a
   --  reset between updates.
   procedure Zero_XY_Outputs (S : in out State) is
   begin
      S.Valid_XY := False;
      S.Position_East := 0.0;
      S.Position_North := 0.0;
      S.Velocity_East := 0.0;
      S.Velocity_North := 0.0;
      S.Acceleration_East := 0.0;
      S.Acceleration_North := 0.0;
   end Zero_XY_Outputs;

   procedure Start_XY (S : in out State; Inp : Inputs; Enable : Boolean) is
   begin
      if Enable and then not S.XY_Enabled then
         Reset_XY_Filter (S);
         S.Last_XY_Measurement_Us := 0;
         S.Origin_Set := False;
         if Inp.GPS_Present and then Inp.GPS_Fix then
            S.Origin := Inp.GPS_Location;
            S.Origin_Set := True;
         end if;
      end if;
      S.XY_Enabled := Enable;
   end Start_XY;

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
      Up, East, North   : Position_Filter.Filter;
      Altitude_Filter   : Filters.PT2;
      Derivative_Filter : Filters.PT2;
   begin
      Filters.PT2_Init (Altitude_Filter, Smoothing_Gain (C.Altitude_LPF));
      Filters.PT2_Init (Derivative_Filter, Smoothing_Gain (C.Derivative_LPF));
      Init (Up, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_Z);
      Init (East, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_XY);
      Init (North, 0.0, 0.0, 0.0, Initial_Variance, Initial_Variance, Initial_Variance, Jerk_Density_XY);
      S := (Up                => Up,
            East              => East,
            North             => North,
            Altitude_Filter   => Altitude_Filter,
            Derivative_Filter => Derivative_Filter,
            Was_Armed         => Armed,
            others            => <>);
   end Init;

   ---------------
   -- Enable_XY --
   ---------------

   procedure Enable_XY (S : in out State; Inp : Inputs; Enable : Boolean) is
   begin
      if Enable and then not S.XY_Enabled then
         Zero_XY_Outputs (S);
      end if;
      Start_XY (S, Inp, Enable);
   end Enable_XY;

   --------------
   -- Reset_XY --
   --------------

   procedure Reset_XY (S : in out State; Inp : Inputs) is
   begin
      Reset_XY_Filter (S);
      Zero_XY_Outputs (S);
      S.Last_XY_Measurement_Us := 0;
      S.Origin_Set := False;
      if Inp.GPS_Present and then Inp.GPS_Fix then
         S.Origin := Inp.GPS_Location;
         S.Origin_Set := True;
      end if;
   end Reset_XY;

   -----------------
   -- Take_Update --
   -----------------

   procedure Take_Update (S : in out State; Who : Consumer; Taken : out Boolean) is
   begin
      Taken := S.Pending (Who);
      S.Pending (Who) := False;
   end Take_Update;

   ------------
   -- Update --
   ------------

   type Linear is record
      East, North, Up : Distance_Cm := 0.0;
   end record;

   --  The linear acceleration in the earth frame, in centimeters per second
   --  squared, with gravity removed: the north, west and up rows of the
   --  rotation over the scaled counts, east being the negated west row.
   function Linear_Acceleration (Inp : Inputs) return Linear
     with Pre => Vectors.Bounded (Inp.Acc, Acc_Bound) and then Vectors.Bounded (Inp.Rotation, Rotation_Bound)
   is
      subtype Scaled is Float range -Acc_Bound .. Acc_Bound;
      subtype Term is Float range -2.0 ** 21 .. 2.0 ** 21;
      subtype Pair is Float range -2.0 ** 22 .. 2.0 ** 22;
      subtype Earth is Float range -2.0 ** 23 .. 2.0 ** 23;
      Ax : constant Scaled := Inp.Acc.X * Inp.One_G_Reciprocal;
      Ay : constant Scaled := Inp.Acc.Y * Inp.One_G_Reciprocal;
      Az : constant Scaled := Inp.Acc.Z * Inp.One_G_Reciprocal;
      R  : Vectors.Matrix33 renames Inp.Rotation;
      North : constant Earth :=
        Pair'(Term'(R (Vectors.X, Vectors.X) * Ax) + Term'(R (Vectors.X, Vectors.Y) * Ay))
        + Term'(R (Vectors.X, Vectors.Z) * Az);
      West  : constant Earth :=
        Pair'(Term'(R (Vectors.Y, Vectors.X) * Ax) + Term'(R (Vectors.Y, Vectors.Y) * Ay))
        + Term'(R (Vectors.Y, Vectors.Z) * Az);
      Up    : constant Earth :=
        Pair'(Term'(R (Vectors.Z, Vectors.X) * Ax) + Term'(R (Vectors.Z, Vectors.Y) * Ay))
        + Term'(R (Vectors.Z, Vectors.Z) * Az);
   begin
      return (East  => Held ((-West) * Gravity_Cmss),
              North => Held (North * Gravity_Cmss),
              Up    => Held ((Up - 1.0) * Gravity_Cmss));
   end Linear_Acceleration;

   function GPS_Altitude_Allowed (C : Settings) return Boolean is
     (C.Source in Default | GPS_Only | Rangefinder_Prefer);

   --  The vertical position sources drive the velocity state only while
   --  nothing measures the vertical velocity, which the GPS does.
   function Drives_Velocity (C : Settings; Inp : Inputs) return Boolean is
     (not (GPS_Altitude_Allowed (C) and then Inp.GPS_Present and then Inp.GPS_Fix));

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

   --  The rangefinder is a vertical source unless the altitude comes from
   --  the GPS or the barometer alone.
   function RF_Feeds_Z (C : Settings) return Boolean is (C.Source not in GPS_Only | Baro_Only);

   --  A rangefinder altitude is usable from a healthy sensor between the
   --  floor the caller gives and the configured range.
   function RF_Sample_Valid (Inp : Inputs; Max_Cm, Min_Cm : Float) return Boolean is
     (Inp.RF_Present and then Inp.RF_Healthy
      and then Float (Inp.RF_Altitude_Cm) >= Min_Cm and then Float (Inp.RF_Altitude_Cm) <= Max_Cm);

   --  The barometer noise multiplier in ground effect, from the height above
   --  the ground the rangefinder reads, or the last one it read: at full
   --  strength for a second after a reading, released over the next. The
   --  trust falls from one at fifty centimetres to a two hundredth at twenty.
   procedure Ground_Effect (S : in out State; C : Settings; Inp : Inputs; Scale : out Float)
     with Post => Scale in 0.98 .. 251.0
   is
      AGL  : Float range 0.0 .. 65_535.0;
      Fade : Unit_Interval := 1.0;
   begin
      Scale := 1.0;
      if not RF_Feeds_Z (C) then
         return;
      end if;
      if RF_Sample_Valid (Inp, Float (C.Max_Range_Cm), Near_Field_Min_Cm) then
         AGL := Float (Inp.RF_Altitude_Cm);
         S.Ground_AGL_Cm := AGL;
         S.Ground_AGL_Time_Us := Inp.Now_Us;
         S.Ground_AGL_Valid := True;
      elsif S.Ground_AGL_Valid then
         declare
            Age : constant Integer_32 := Clock.Elapsed (Inp.Now_Us, S.Ground_AGL_Time_Us);
         begin
            if Age < 0 or else Age >= Ground_Latch_Hold_Us + Ground_Latch_Fade_Us then
               S.Ground_AGL_Valid := False;
               return;
            end if;
            AGL := Constrain_F (S.Ground_AGL_Cm, 0.0, 65_535.0);
            if Age > Ground_Latch_Hold_Us then
               Fade := 1.0 - Float (Age - Ground_Latch_Hold_Us) / Float (Ground_Latch_Fade_Us);
            end if;
         end;
      else
         return;
      end if;
      declare
         T     : constant Unit_Interval :=
           Constrain_F ((AGL - Ground_Effect_Full_Cm) / (Ground_Effect_Alt_Cm - Ground_Effect_Full_Cm), 0.0, 1.0);
         Trust : constant Float range 0.004 .. 1.01 := Min_Ground_Trust + T * Float'Machine (1.0 - Min_Ground_Trust);
         Full   : constant Float range 0.98 .. 251.0 := 1.0 / Trust;
         Excess : constant Float range -0.02 .. 250.0 := Full - 1.0;
         Faded  : constant Float range -0.02 .. 250.0 := Excess * Fade;
      begin
         Scale := 1.0 + Faded;
      end;
   end Ground_Effect;

   procedure Feed_Barometer (S : in out State; C : Settings; Inp : Inputs) is
      Ready  : Boolean;
      Action : Step_Action;
      Scale  : Float;
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
      Ground_Effect (S, C, Inp, Scale);
      declare
         Trust    : constant Float range 0.1 .. 1.0 := Constrain_F (Float (C.Prefer_Baro) * 0.01, 0.1, 1.0);
         Noise    : constant Position_Filter.Noise := Baro_Noise / Trust * Scale;
         Relative : constant Altitude_Cm := Held (Inp.Baro_Altitude_Cm - S.Baro_Offset_Cm);
      begin
         S.Taps.Baro_Fed := True;
         S.Taps.Baro_Rel_Cm := Relative;
         Gate_Step (S.Baro_Gate, Relative, Inp.Baro_Interval_Us, Action);
         case Action is
            when Reject =>
               return;
            when Full =>
               if Drives_Velocity (C, Inp) then
                  Update_Position_To_Velocity (S.Up, Relative, Noise);
               else
                  Update_Position (S.Up, Relative, Noise);
               end if;
            when Position_Only =>
               Update_Position (S.Up, Relative, Noise);
         end case;
         S.Last_Z_Measurement_Us := Inp.Now_Us;
         S.Baro_Raw_Cm := Inp.Baro_Altitude_Cm;
         S.Baro_Active := True;
      end;
   end Feed_Barometer;

   --  The rangefinder's latest sample is ready while it is new and within
   --  the interval the sensor measured between its samples.
   procedure RF_Ready (S : in out State; Inp : Inputs; Ready : out Boolean) is
      Has_New : constant Boolean := not S.RF_Data_Available or else Inp.RF_Sample_Time_Us /= S.RF_Timestamp_Us;
   begin
      if Has_New then
         S.RF_Data_Available := True;
         S.RF_Timestamp_Us := Inp.RF_Sample_Time_Us;
         S.RF_Hold_Us := Inp.RF_Interval_Us;
      end if;
      declare
         Age : constant Integer_32 := Clock.Elapsed (Inp.Now_Us, S.RF_Timestamp_Us);
         Within_Hold : constant Boolean :=
           S.RF_Data_Available and then S.RF_Hold_Us > 0 and then Age >= 0 and then Age < S.RF_Hold_Us;
      begin
         Ready := (Has_New and then S.RF_Hold_Us <= 0) or else Within_Hold;
      end;
   end RF_Ready;

   --  The vertical frame is rebased only while no mode holds an absolute
   --  altitude target.
   function May_Rebase (Inp : Inputs) return Boolean is
     (not (Inp.Altitude_Hold_Mode or else Inp.Position_Hold_Mode or else Inp.Rescue_Mode or else Inp.Autopilot_Mode));

   --  The vertical origin moved so the estimate reads the new position, the
   --  barometer and GPS offsets and the barometer gate carried with it.
   procedure Rebase (S : in out State; New_Position_Cm : Altitude_Cm) is
      Shift : constant Altitude_Cm := Held (New_Position_Cm - S.Up.X (Position));
   begin
      Shift_Position (S.Up, Shift);
      S.Baro_Offset_Cm := Held (S.Baro_Offset_Cm - Shift);
      S.Baro_Gate.Last_Accepted_Cm := Held (S.Baro_Gate.Last_Accepted_Cm + Shift);
      S.GPS_Alt_Offset_Cm := Held (S.GPS_Alt_Offset_Cm - Shift);
   end Rebase;

   --  The rangefinder against the ground height beneath its first sample:
   --  on the ground, disarmed or with no vertical estimate the first reading
   --  itself, in the air the estimate rebased onto the reading, or the
   --  difference kept in the offset while a mode holds an altitude. The
   --  near field is fused with a larger noise, and the sample goes through
   --  its step gate.
   procedure Feed_Rangefinder (S : in out State; C : Settings; Inp : Inputs)
     with Global => null
   is
      Feeds_Z : constant Boolean := RF_Feeds_Z (C);
      Ready   : Boolean;
      Action  : Step_Action;
   begin
      if not RF_Sample_Valid (Inp, Float (C.Max_Range_Cm), Near_Field_Min_Cm) then
         S.RF_Data_Available := False;
         return;
      end if;
      RF_Ready (S, Inp, Ready);
      if not Ready then
         return;
      end if;
      declare
         Altitude : constant Float range 0.0 .. 65_535.0 := Float (Inp.RF_Altitude_Cm);
      begin
         if not S.RF_Offset_Set then
            if not Inp.Armed or else not S.Valid_Z or else abs S.Up.X (Position) < On_Ground_Tolerance_Cm then
               S.RF_Offset_Cm := Altitude;
            elsif Feeds_Z and then May_Rebase (Inp) then
               S.RF_Offset_Cm := 0.0;
               Rebase (S, Altitude);
            else
               S.RF_Offset_Cm := Held (Altitude - S.Up.X (Position));
            end if;
            S.RF_Offset_Set := True;
         end if;
         declare
            Relative : constant Altitude_Cm := Held (Altitude - S.RF_Offset_Cm);
            Noise    : Position_Filter.Noise := Rangefinder_Noise;
         begin
            S.Taps.RF_Fed := True;
            S.Taps.RF_Rel_Cm := Relative;
            if not Feeds_Z then
               return;
            end if;
            if C.Source in Rangefinder_Only | Rangefinder_Prefer then
               Noise := Noise * 0.25;
            end if;
            if Altitude < Rangefinder_Min_Alt_Cm then
               Noise := Noise * Near_Field_Noise_Scale;
            end if;
            Gate_Step (S.RF_Gate, Relative, Inp.RF_Interval_Us, Action);
            case Action is
               when Reject =>
                  return;
               when Full =>
                  if Drives_Velocity (C, Inp) then
                     Update_Position_To_Velocity (S.Up, Relative, Noise);
                  else
                     Update_Position (S.Up, Relative, Noise);
                  end if;
               when Position_Only =>
                  Update_Position (S.Up, Relative, Noise);
            end case;
            S.RF_Active := True;
            S.Last_Z_Measurement_Us := Inp.Now_Us;
         end;
      end;
   end Feed_Rangefinder;

   --  A fix is ready while new, or within the hold interval that its rate
   --  gives, so a slow receiver still corrects every task.
   procedure GPS_Ready (S : in out State; Inp : Inputs; Ready : out Boolean) is
      Has_New : constant Boolean := Inp.GPS_Stamp /= S.GPS_Stamp;
   begin
      if Has_New then
         S.GPS_Stamp := Inp.GPS_Stamp;
         S.GPS_Data_Available := True;
         S.GPS_Received_At_Us := Inp.Now_Us;
         if Inp.GPS_Rate_Hz > 0.0 then
            S.GPS_Hold_Us := Integer_32 (Round_Half_Even (1.0E6 / Inp.GPS_Rate_Hz));
         else
            S.GPS_Hold_Us := 0;
         end if;
      end if;
      Ready := Has_New
        or else (S.GPS_Data_Available and then S.GPS_Hold_Us > 0
                 and then Clock.Elapsed (Inp.Now_Us, S.GPS_Received_At_Us) < S.GPS_Hold_Us);
   end GPS_Ready;

   --  A measurement noise from an accuracy in millimetres: the base noise
   --  scaled by the accuracy over its denominator, between one and ten.
   function Accuracy_R (Acc_Mm : Unsigned_32; Denom : Float; Base : Float) return Noise
     with Pre => Denom >= 1.0 and then Base in 1.0 .. 1_000.0
   is
      Max   : constant Float := 10.0 * Base;
      Ratio : constant Float range 9.9 .. 10.1 := Max / Base;
      Scale : constant Float range 1.0 .. 10.1 := Constrain_F (Float (Acc_Mm) / Denom, 1.0, Ratio);
   begin
      return Base * Scale;
   end Accuracy_R;

   -----------------
   -- Distance_2d --
   -----------------

   procedure Distance_2d (From, To : Location; Cos_Lat : Longitude_Scale; East, North : out Float) is
      Delta_Lon : constant Integer_32 := Longitude_Difference (To.Lon, From.Lon);
      Delta_Lat : constant Integer_32 := Wrapped_Difference (To.Lat, From.Lat);
   begin
      declare
         subtype Local_Cm is Float range -2.5e9 .. 2.5e9;
         Lon      : constant Float range -2.15e9 .. 2.15e9 := Float (Delta_Lon);
         Scaled   : constant Float range -2.18e9 .. 2.18e9 := Lon * Cos_Lat;
         East_Cm  : constant Local_Cm := Scaled * Earth_Angle_To_Cm;
         North_Cm : constant Local_Cm := Float (Delta_Lat) * Earth_Angle_To_Cm;
      begin
         East := East_Cm;
         North := North_Cm;
      end;
   end Distance_2d;

   --  The GPS fix into the horizontal filters against the origin, with the
   --  velocity first, and into the vertical filter against the first
   --  altitude, the noises from the reported accuracies; a position beyond
   --  the state bound is held at it.
   procedure Feed_GPS (S : in out State; C : Settings; Inp : Inputs) is
      Ready      : Boolean;
      XY_Allowed : constant Boolean := C.Horizontal /= Optical_Flow_Alone;
   begin
      if not Inp.GPS_Present or else not Inp.GPS_Fix then
         S.GPS_Data_Available := False;
         return;
      end if;
      GPS_Ready (S, Inp, Ready);
      if not Ready then
         return;
      end if;
      if S.XY_Enabled and then not S.Origin_Set and then XY_Allowed then
         S.Origin := Inp.GPS_Location;
         S.Origin_Set := True;
      end if;
      if S.XY_Enabled and then XY_Allowed and then S.Origin_Set then
         declare
            East, North : Float;
            R_Pos : constant Noise := Accuracy_R (Inp.GPS_H_Acc, Position_Accuracy_Denom, GPS_Position_Noise);
            R_Vel : constant Noise := Accuracy_R (Inp.GPS_S_Acc, Velocity_Accuracy_Denom, GPS_Velocity_Noise);
         begin
            Distance_2d (S.Origin, Inp.GPS_Location, Inp.Cos_Lat, East, North);
            S.Taps.GPS_XY_Fed := True;
            S.Taps.GPS_R_Pos := R_Pos;
            S.Taps.GPS_R_Vel := R_Vel;
            S.Taps.GPS_Vel_East := Inp.GPS_Velocity_East;
            S.Taps.GPS_Vel_North := Inp.GPS_Velocity_North;
            Update_Velocity_To_Position (S.East, Float (Inp.GPS_Velocity_East), R_Vel);
            Update_Velocity_To_Position (S.North, Float (Inp.GPS_Velocity_North), R_Vel);
            Update_Position (S.East, Held (East), R_Pos);
            Update_Position (S.North, Held (North), R_Pos);
            S.Last_XY_Measurement_Us := Inp.Now_Us;
         end;
      end if;
      if GPS_Altitude_Allowed (C) then
         if not S.GPS_Alt_Offset_Set then
            S.GPS_Alt_Offset_Cm := Held (Float (Inp.GPS_Location.Alt_Cm));
            S.GPS_Alt_Offset_Set := True;
         end if;
         declare
            R_Vel_Up : constant Noise := Accuracy_R (Inp.GPS_S_Acc, Velocity_Accuracy_Denom, GPS_Velocity_Z_Noise);
            R_Alt    : constant Noise := Accuracy_R (Inp.GPS_V_Acc, Altitude_Accuracy_Denom, GPS_Altitude_Noise);
            Vel_Up   : constant Altitude_Cm := -Float (Inp.GPS_Velocity_Down);
            Rel_Alt  : constant Altitude_Cm := Held (Float (Inp.GPS_Location.Alt_Cm) - S.GPS_Alt_Offset_Cm);
         begin
            S.Taps.GPS_Alt_Fed := True;
            S.Taps.GPS_Rel_Alt_Cm := Rel_Alt;
            S.Taps.GPS_Vel_Up := Vel_Up;
            Update_Velocity_To_Position (S.Up, Vel_Up, R_Vel_Up);
            Update_Position (S.Up, Rel_Alt, R_Alt);
            S.Last_Z_Measurement_Us := Inp.Now_Us;
            if C.Prefer_Baro < 50 then
               declare
                  Scale : constant Float range 1.0 .. 10.0 :=
                    Constrain_F (Float (Inp.GPS_V_Acc) / Altitude_Accuracy_Denom, 1.0, 10.0);
               begin
                  S.GPS_Anchor_Tau_S := Cross_Cal_Tau_GPS_S * Scale;
                  S.GPS_Anchor_Active := True;
               end;
            end if;
         end;
      end if;
   end Feed_GPS;

   --  The optical flow noise falls with the quality above its minimum, a
   --  negative value refusing the sample at or below it.
   function Flow_Noise (Quality : Integer_16; Minimum : Natural) return Float
     with Post => Flow_Noise'Result = -1.0 or else Flow_Noise'Result in 199.0 .. 20_001.0
   is
      Span : constant Integer := 100 - Minimum;
      Norm : Float range 0.01 .. 1.0;
   begin
      if Integer (Quality) <= Minimum then
         return -1.0;
      end if;
      if Span = 0 then
         Norm := 1.0;
      else
         Norm := Constrain_F (Float (Integer (Quality) - Minimum) / Float (Span), 0.01, 1.0);
      end if;
      return Flow_Velocity_Noise / Norm;
   end Flow_Noise;

   subtype Small_Angle is Float range -7.0 .. 7.0;

   function Decidegrees_To_Radians (D : Integer) return Small_Angle is (Float (D) / 10.0 * Radians_Per_Decidegree)
     with Pre => D in -3_600 .. 3_600;

   --  The optical flow sample is ready while new or within the interval the
   --  driver measured between its samples, its delay before a second one.
   procedure Flow_Ready (S : in out State; Inp : Inputs; Ready : out Boolean) is
      Has_New : constant Boolean := not S.Flow_Data_Available or else Inp.Flow_Time_Stamp_Us /= S.Flow_Timestamp_Us;
   begin
      if Has_New then
         declare
            Source : Integer_32 := Integer_32 (Inp.Flow_Delay_Ms) * 1_000;
         begin
            if S.Flow_Data_Available then
               declare
                  Measured : constant Integer_32 := Clock.Elapsed (Inp.Flow_Time_Stamp_Us, S.Flow_Timestamp_Us);
               begin
                  if Measured > 0 and then Measured <= Flow_Timeout_Us then
                     Source := Measured;
                  end if;
               end;
            end if;
            S.Flow_Data_Available := True;
            S.Flow_Timestamp_Us := Inp.Flow_Time_Stamp_Us;
            S.Flow_Hold_Us := Source;
         end;
      end if;
      declare
         Age : constant Integer_32 := Clock.Elapsed (Inp.Now_Us, S.Flow_Timestamp_Us);
      begin
         Ready := Has_New
           or else (S.Flow_Data_Available and then S.Flow_Hold_Us > 0 and then Age >= 0 and then Age < S.Flow_Hold_Us);
      end;
   end Flow_Ready;

   --  The optical flow rates over the rangefinder height, levelled by the
   --  tilt and turned east and north by the heading, advanced over the
   --  sensor's gyro delay with the filters' acceleration, into the
   --  horizontal velocities, while the horizontal axes run and both axes of
   --  the sample are usable.
   procedure Feed_Optical_Flow (S : in out State; C : Settings; Inp : Inputs)
     with Global => null
   is
      Ready : Boolean;
      Noise : Float;
   begin
      if not S.XY_Enabled then
         return;
      end if;
      if not Inp.Flow_Present or else not Inp.Flow_Healthy then
         S.Flow_Data_Available := False;
         return;
      end if;
      if C.Horizontal = GPS_Alone then
         return;
      end if;
      if not RF_Sample_Valid
          (Inp, Float'Min (Float (C.Max_Range_Cm), Float (C.Flow_Max_Range_Cm)), Rangefinder_Min_Alt_Cm)
      then
         return;
      end if;
      Noise := Flow_Noise (Inp.Flow_Quality, C.Flow_Quality_Min);
      if Noise < 0.0 then
         return;
      end if;
      Flow_Ready (S, Inp, Ready);
      if not Ready or else not Inp.Flow_Valid_X or else not Inp.Flow_Valid_Y then
         return;
      end if;
      declare
         Altitude  : constant Float range 0.0 .. 65_535.0 := Float (Inp.RF_Altitude_Cm);
         subtype Speed is Float range -2.7e11 .. 2.7e11;
         subtype Turned is Float range -5.5e11 .. 5.5e11;
         Right     : constant Speed := Inp.Flow_Rate_X * Altitude;
         Forward   : constant Speed := Inp.Flow_Rate_Y * Altitude;
         Cos_Pitch : constant Cosine := Cos_Approx (Decidegrees_To_Radians (Inp.Pitch_Decidegrees));
         Cos_Roll  : constant Cosine := Cos_Approx (Decidegrees_To_Radians (Inp.Roll_Decidegrees));
         Vel_Right : constant Speed := Right * Cos_Roll;
         Vel_Fwd   : constant Speed := Forward * Cos_Pitch;
         Yaw       : constant Small_Angle := Decidegrees_To_Radians (Inp.Yaw_Decidegrees);
         Cos_Yaw   : constant Cosine := Cos_Approx (Yaw);
         Sin_Yaw   : constant Cosine := Sin_Approx (Yaw);
         East      : constant Turned := Vel_Fwd * Sin_Yaw - Vel_Right * Cos_Yaw;
         North     : constant Turned := Vel_Fwd * Cos_Yaw + Vel_Right * Sin_Yaw;
         Delay_S   : constant Float range 0.0 .. 2_200.0 := Float (Inp.Flow_Gyro_Delay_Us) * 1.0e-6;
         East_Now  : constant Float := East + S.East.X (Acceleration) * Delay_S;
         North_Now : constant Float := North + S.North.X (Acceleration) * Delay_S;
      begin
         Update_Velocity_To_Position (S.East, Held (East_Now), Noise);
         Update_Velocity_To_Position (S.North, Held (North_Now), Noise);
         S.Taps.Flow_Fed := True;
         S.Taps.Flow_East := Held (East_Now);
         S.Taps.Flow_North := Held (North_Now);
         S.Last_XY_Measurement_Us := Inp.Now_Us;
      end;
   end Feed_Optical_Flow;

   --  The barometer offset drawn toward the offset the vertical estimate
   --  implies, at the rate of the faster anchor fed this task, the
   --  rangefinder before the GPS, while armed and the barometer fed; the
   --  entries are spent either way.
   procedure Cross_Calibrate (S : in out State; Armed : Boolean)
     with Global => null
   is
      Alpha : Unit_Interval := 0.0;
   begin
      if S.RF_Active then
         Alpha := Constrain_F (Sample_Time_S / Cross_Cal_Tau_RF_S, 0.0, 1.0);
      elsif S.GPS_Anchor_Active then
         Alpha := Constrain_F (Sample_Time_S / S.GPS_Anchor_Tau_S, 0.0, 1.0);
      end if;
      if Alpha > 0.0 and then Armed and then S.Baro_Active then
         declare
            Ideal : constant Float := S.Baro_Raw_Cm - S.Up.X (Position);
         begin
            S.Baro_Offset_Cm := Held (S.Baro_Offset_Cm + Alpha * (Ideal - S.Baro_Offset_Cm));
         end;
      end if;
      S.Baro_Active := False;
      S.RF_Active := False;
      S.GPS_Anchor_Active := False;
   end Cross_Calibrate;

   --  The trust falls with the position variance; a variance below zero has
   --  no meaning, so the trust is one there (DESIGN.md D33).
   function Trust (Variance : Float) return Unit_Interval
     with Pre => abs Variance <= 2.0 * Position_Filter.Variance_Bound
   is
      Denominator : constant Float := 1.0 + Variance / Initial_Variance;
   begin
      if Denominator >= 1.0 then
         return Constrain_F (1.0 / Denominator, 0.0, 1.0);
      else
         return 1.0;
      end if;
   end Trust;

   procedure Update (S : in out State; C : Settings; Inp : Inputs) is
      Want_XY : constant Boolean :=
        Inp.Armed and then (Inp.Position_Hold_Mode or else Inp.Rescue_Mode
                            or else (Inp.GPS_Present and then Inp.GPS_Fix and then C.Horizontal /= Optical_Flow_Alone)
                            or else (Inp.Flow_Present and then Inp.RF_Present and then Inp.Flow_Healthy
                                     and then Inp.RF_Healthy and then C.Horizontal /= GPS_Alone));
      A : Linear;
   begin
      if Inp.Armed /= S.Was_Armed then
         Reset_Z (S);
         Reset_Smoothing (S, C);
         S.Was_Armed := Inp.Armed;
      end if;
      if Want_XY /= S.XY_Enabled then
         Start_XY (S, Inp, Want_XY);
      end if;
      A := Linear_Acceleration (Inp);
      S.Taps.Updated := True;
      S.Taps.Accel_East := A.East;
      S.Taps.Accel_North := A.North;
      S.Taps.Accel_Up := A.Up;
      Update_Acceleration (S.Up, (if Inp.Armed then A.Up else 0.0), Acceleration_Noise_Z);
      Predict (S.Up, Sample_Time_S);
      if S.XY_Enabled and then Inp.Armed then
         if S.Last_XY_Measurement_Us = 0
           or else Clock.Elapsed (Inp.Now_Us, S.Last_XY_Measurement_Us) >= Measurement_Timeout_Us
         then
            Reset_XY_Filter (S);
         else
            Update_Acceleration (S.East, A.East, Acceleration_Noise_XY);
            Update_Acceleration (S.North, A.North, Acceleration_Noise_XY);
            Predict (S.East, Sample_Time_S);
            Predict (S.North, Sample_Time_S);
         end if;
      end if;
      Feed_GPS (S, C, Inp);
      Feed_Barometer (S, C, Inp);
      Feed_Rangefinder (S, C, Inp);
      Feed_Optical_Flow (S, C, Inp);
      Cross_Calibrate (S, Inp.Armed);
      S.Position_East := S.East.X (Position);
      S.Position_North := S.North.X (Position);
      S.Position_Up := S.Up.X (Position);
      S.Velocity_East := S.East.X (Velocity);
      S.Velocity_North := S.North.X (Velocity);
      S.Velocity_Up := S.Up.X (Velocity);
      S.Acceleration_East := S.East.X (Acceleration);
      S.Acceleration_North := S.North.X (Acceleration);
      S.Acceleration_Up := S.Up.X (Acceleration);
      if S.XY_Enabled then
         S.Valid_XY := S.Last_XY_Measurement_Us > 0
           and then Clock.Elapsed (Inp.Now_Us, S.Last_XY_Measurement_Us) < Measurement_Timeout_Us;
      else
         S.Valid_XY := False;
      end if;
      S.Valid_Z := S.Last_Z_Measurement_Us > 0
        and then Clock.Elapsed (Inp.Now_Us, S.Last_Z_Measurement_Us) < Measurement_Timeout_Us;
      declare
         Pair_Bound : constant := 2.0 * Position_Filter.Variance_Bound;
         subtype Variance_Pair is Float range -Pair_Bound .. Pair_Bound;
         Variance_Sum : constant Variance_Pair := S.East.P (Position, Position) + S.North.P (Position, Position);
      begin
         S.Trust_XY := Trust (Variance_Sum * 0.5);
      end;
      S.Trust_Z := Trust (S.Up.P (Position, Position));
      S.Pending := (others => True);
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

end Adaflight.Position_Estimator;
