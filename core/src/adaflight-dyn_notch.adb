package body Adaflight.Dyn_Notch with SPARK_Mode is
   use type SDFT.Magnitudes;

   Smooth_Hz        : constant Float := 4.0;
   OSD_Min_Throttle : constant := 20;
   Floor_Min_Hz     : constant Float := 60.0;

   function Saturate (X : Float) return Signal is
     (Constrain_F (X, -Signal_Bound, Signal_Bound));

   --  A spectral value read within the power bound.
   function Bounded (X : Float) return Power is
     (Constrain_F (X, 0.0, Power_Bound));

   function Clamped_Bin (X : Integer) return SDFT.Bin is
     (Integer'Max (0, Integer'Min (SDFT.Bin_Count - 1, X)));

   --  Centers spread evenly over the range, so the notches find their peaks
   --  sooner. A body of its own, so its arithmetic carries none of the
   --  initialization's context.
   function Initial_Center (P : Notch_Index; Count : Positive; Span : Float; Min_Hz : Float) return Center_Hz
     with Pre => Count <= Max_Notches and then Span in 0.0 .. 1_000.0 and then Min_Hz in 20.0 .. 250.0;
   function Initial_Center (P : Notch_Index; Count : Positive; Span : Float; Min_Hz : Float) return Center_Hz is
   begin
      return Constrain_F ((Float (P) + 0.5) * Span / Float (Count) + Min_Hz, 0.0, 1_000.0);
   end Initial_Center;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Loop_Time_Us : PID_Config.Loop_Time_Us) is
   begin
      S := (others => <>);
      if Loop_Time_Us > 500 then
         return;
      end if;
      declare
         Dt        : constant Float range 9.0e-5 .. 5.1e-4 := Float (Loop_Time_Us) * 1.0e-6;
         Loop_Rate : constant Float range 1_900.0 .. 11_200.0 := 1.0 / Dt;
         Nyquist   : constant Float range 950.0 .. 5_600.0 := Loop_Rate / 2.0;
         Max_F     : constant Float range 200.0 .. 1_000.0 :=
           Float'Min (Float'Max (Float (C.Min_Hz), Float (C.Max_Hz)), Nyquist);
         Span      : constant Float range 0.0 .. 1_000.0 := Float'Max (0.0, Max_F - Float (C.Min_Hz));
         Samples   : constant Batch_Size :=
           Integer'Max (1, Integer'Min (SDFT.Bin_Count, Integer (Float'Truncation (Nyquist / Max_F))));
         Rate      : constant Float range 50.0 .. 11_200.0 := Loop_Rate / Float (Samples);
         Res       : constant Float range 0.5 .. 200.0 := Rate / Float (SDFT.Sample_Size);
         Start     : constant SDFT.Bin :=
           Integer'Min (SDFT.Bin_Count - 2, Integer'Max (1, Round_Half_Even (Float (C.Min_Hz) / Res)));
         Stop      : constant SDFT.Bin :=
           Integer'Max (Start, Integer'Min (SDFT.Bin_Count - 1, Round_Half_Even (Max_F / Res)));
         Floor     : SDFT.Bin := Clamped_Bin (Integer'Max (Start, Round_Half_Even (Floor_Min_Hz / Res)));
      begin
         --  The noise floor leaves the motion band out unless that leaves it
         --  fewer than four bins.
         if Floor > Stop - 3 then
            Floor := Start;
         end if;
         S.Q := Float (C.Q) / 100.0;
         S.Min_Hz := Float (C.Min_Hz);
         S.Max_Hz := Max_F;
         S.Count := C.Count;
         S.Active := C.Count > 0;
         S.Dt := Dt;
         S.Sample_Count := Samples;
         S.Sample_Count_Rcp := 1.0 / Float (Samples);
         S.Resolution_Hz := Res;
         S.Start_Bin := Start;
         S.End_Bin := Stop;
         S.Floor_Start_Bin := Floor;
         S.PT1_Looptime_S := Float (Calc_Ticks) / Loop_Rate;
         for A in Axis loop
            SDFT.Init (S.Transforms (A), Start, Stop, Samples);
         end loop;
         for A in Axis loop
            for P in Notch_Index loop
               if P < S.Count then
                  S.Center (A, P) := Initial_Center (P, S.Count, Span, S.Min_Hz);
                  SVF_Notch_Init (S.Notch (A, P), S.Center (A, P), Dt, S.Q);
               end if;
            end loop;
         end loop;
      end;
   end Init;

   ----------
   -- Push --
   ----------

   procedure Push (S : in out State; A : Axis; Sample : Signal) is
   begin
      S.Accumulator (A) := Saturate (S.Accumulator (A) + Sample);
   end Push;

   -------------
   -- Process --
   -------------

   --  The windowed spectrum of the current axis and the noise sum over the
   --  floor band.
   procedure Step_Window (S : in out State)
     with Post => S.Peaks = S.Peaks'Old and then S.Center = S.Center'Old and then S.Tick = S.Tick'Old;
   procedure Step_Window (S : in out State) is
      Sum : Noise_Level := 0.0;
   begin
      if S.Transforms (S.Current_Axis).End_Bin >= 1
        and then S.Transforms (S.Current_Axis).Start_Bin <= SDFT.Bin_Count - 2
      then
         SDFT.Win_Sq (S.Transforms (S.Current_Axis), S.Data);
      end if;
      for B in S.Floor_Start_Bin .. S.End_Bin loop
         Sum := Constrain_F (Sum + Bounded (S.Data (B)), -Power_Bound, Power_Bound);
      end loop;
      S.Noise_Threshold := Sum;
   end Step_Window;

   --  The largest peaks in height order, then sorted by bin with the void
   --  peaks left at the end.
   procedure Step_Detect_Peaks (S : in out State)
     with Post => S.Noise_Threshold = S.Noise_Threshold'Old and then S.Center = S.Center'Old
                  and then S.Tick = S.Tick'Old;
   procedure Step_Detect_Peaks (S : in out State) is
      B : Integer range 0 .. SDFT.Bin_Count := S.Start_Bin + 1;
   begin
      for P in Notch_Index loop
         if P < S.Count then
            S.Peaks (P) := (Bin => 0, Value => 0.0);
         end if;
      end loop;
      while B < S.End_Bin loop
         pragma Loop_Invariant (B >= 1 and then B < S.End_Bin);
         if S.Data (B) > S.Data (B - 1) and then S.Data (B) > S.Data (B + 1) then
            for P in Notch_Index loop
               if P < S.Count and then S.Data (B) > S.Peaks (P).Value then
                  for K in reverse P + 1 .. S.Count - 1 loop
                     S.Peaks (K) := S.Peaks (K - 1);
                  end loop;
                  S.Peaks (P) := (Bin => B, Value => Bounded (S.Data (B)));
                  exit;
               end if;
            end loop;
            --  The neighbour of a peak is no peak.
            B := B + 1;
         end if;
         exit when B >= S.End_Bin;
         B := B + 1;
      end loop;
      for P in reverse 1 .. S.Count - 1 loop
         for K in 0 .. P - 1 loop
            if S.Peaks (K).Bin > S.Peaks (K + 1).Bin and then S.Peaks (K + 1).Bin /= 0 then
               declare
                  Temp : constant Peak := S.Peaks (K);
               begin
                  S.Peaks (K) := S.Peaks (K + 1);
                  S.Peaks (K + 1) := Temp;
               end;
            end if;
         end loop;
      end loop;
   end Step_Detect_Peaks;

   --  The offset of a peak within its neighbours, within half a bin for a
   --  peak between two lower neighbours; the guard on the quotient is inert
   --  for one.
   function Parabola_Offset (Y0, Y1, Y2 : Power) return Float
     with Post => abs Parabola_Offset'Result <= 1.0;
   function Parabola_Offset (Y0, Y1, Y2 : Power) return Float is
      Denom : constant Float := 2.0 * (Y0 - 2.0 * Y1 + Y2);
   begin
      if Denom /= 0.0 and then abs (Y0 - Y2) <= abs Denom then
         return (Y0 - Y2) / Denom;
      end if;
      return 0.0;
   end Parabola_Offset;

   --  Toward a big peak the center moves up to ten times faster: the peak
   --  over the floor, held between one and ten, as the reference's clamp
   --  of an infinite or negative quotient gives at a zero or negative floor.
   function Speed_Up (Value : Power; Noise : Noise_Level) return Float
     with Post => Speed_Up'Result in 1.0 .. 10.0;
   function Speed_Up (Value : Power; Noise : Noise_Level) return Float is
   begin
      if Noise = 0.0 then
         return 10.0;
      elsif Noise < 0.0 or else Value <= Noise then
         return 1.0;
      elsif Value >= Noise * 10.0 then
         return 10.0;
      end if;
      return Constrain_F (Value / Noise, 1.0, 10.0);
   end Speed_Up;

   --  The noise floor without the peaks, doubled, and the center of each
   --  peak above it refined by a parabola and smoothed toward the notch.
   procedure Step_Calc_Frequencies (S : in out State; Throttle_Percent : Natural)
     with Post => S.Peaks = S.Peaks'Old and then S.Data = S.Data'Old and then S.Tick = S.Tick'Old;
   procedure Step_Calc_Frequencies (S : in out State; Throttle_Percent : Natural) is
      Peak_Count : Natural range 0 .. Max_Notches := 0;
      Noise      : Noise_Level := S.Noise_Threshold;
      Divisor    : Positive;
   begin
      for P in Notch_Index loop
         if P < S.Count and then S.Peaks (P).Bin > S.Floor_Start_Bin and then S.Peaks (P).Bin < SDFT.Bin_Count - 1 then
            Noise := Constrain_F (Noise - 0.75 * Bounded (S.Data (S.Peaks (P).Bin - 1)), -Power_Bound, Power_Bound);
            Noise := Constrain_F (Noise - Bounded (S.Data (S.Peaks (P).Bin)), -Power_Bound, Power_Bound);
            Noise := Constrain_F (Noise - 0.75 * Bounded (S.Data (S.Peaks (P).Bin + 1)), -Power_Bound, Power_Bound);
            Peak_Count := Peak_Count + 1;
         end if;
      end loop;
      Divisor := Integer'Max (1, S.End_Bin - S.Floor_Start_Bin - Peak_Count + 1);
      Noise := Noise / Float (Divisor);
      Noise := Constrain_F (Noise * 2.0, -Power_Bound, Power_Bound);
      S.Noise_Threshold := Noise;
      for P in Notch_Index loop
         if P < S.Count and then S.Peaks (P).Bin /= 0 and then S.Peaks (P).Bin < SDFT.Bin_Count - 1
           and then S.Peaks (P).Value > Noise
         then
            declare
               Bin_F    : constant SDFT.Bin := S.Peaks (P).Bin;
               Mean_Bin : constant Float range -2.0 .. 40.0 :=
                 Float (Bin_F) + Parabola_Offset (Bounded (S.Data (Bin_F - 1)), Bounded (S.Data (Bin_F)),
                                                  Bounded (S.Data (Bin_F + 1)));
               High     : constant Float := Float'Max (S.Min_Hz, S.Max_Hz);
               Target   : constant Float range 20.0 .. 1_000.0 :=
                 Constrain_F (Mean_Bin * S.Resolution_Hz, S.Min_Hz, High);
               Gain     : constant Unit_Interval :=
                 PT1_Gain (Smooth_Hz * Speed_Up (S.Peaks (P).Value, Noise), S.PT1_Looptime_S);
               Center   : constant Center_Hz := S.Center (S.Current_Axis, P);
            begin
               --  The step toward the target stays between the limits, which the
               --  clamp states for the type.
               S.Center (S.Current_Axis, P) := Constrain_F (Center + Gain * (Target - Center), 0.0, 1_000.0);
            end;
         end if;
      end loop;
      if Throttle_Percent > OSD_Min_Throttle then
         for P in Notch_Index loop
            if P < S.Count and then not (Float (S.Max_Center) > S.Center (S.Current_Axis, P)) then
               S.Max_Center := Integer (Float'Truncation (S.Center (S.Current_Axis, P)));
            end if;
         end loop;
      end if;
      S.Freq_Step := True;
      S.Freq_Axis := S.Current_Axis;
   end Step_Calc_Frequencies;

   --  The notches of the peaks that moved their centers, then the next axis.
   procedure Step_Update_Filters (S : in out State)
     with Post => S.Center = S.Center'Old and then S.Peaks = S.Peaks'Old and then S.Tick = S.Tick'Old;
   procedure Step_Update_Filters (S : in out State) is
   begin
      for P in Notch_Index loop
         if P < S.Count and then S.Peaks (P).Bin /= 0 and then S.Peaks (P).Value > S.Noise_Threshold then
            SVF_Notch_Update (S.Notch (S.Current_Axis, P), S.Center (S.Current_Axis, P), S.Dt, S.Q);
         end if;
      end loop;
      S.Current_Axis := (if S.Current_Axis = Yaw then Roll else Axis'Succ (S.Current_Axis));
   end Step_Update_Filters;

   procedure Process (S : in out State; Throttle_Percent : Natural) is
   begin
      case S.Current_Step is
         when Window =>
            Step_Window (S);
         when Detect_Peaks =>
            Step_Detect_Peaks (S);
         when Calc_Frequencies =>
            Step_Calc_Frequencies (S, Throttle_Percent);
         when Update_Filters =>
            Step_Update_Filters (S);
      end case;
      S.Current_Step := (if S.Current_Step = Update_Filters then Window else Step'Succ (S.Current_Step));
   end Process;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out State; Throttle_Percent : Natural) is
   begin
      S.Average_Fresh := False;
      S.Freq_Step := False;
      if S.Sample_Index = S.Sample_Count then
         S.Sample_Index := 0;
         S.Average_Fresh := True;
         for A in Axis loop
            S.Average (A) := Saturate (S.Accumulator (A) * S.Sample_Count_Rcp);
            S.Accumulator (A) := 0.0;
         end loop;
         S.Tick := Calc_Ticks;
      end if;
      for A in Axis loop
         if S.Sample_Index < S.Transforms (A).Num_Batches then
            SDFT.Push_Batch (S.Transforms (A), S.Average (A), S.Sample_Index);
         end if;
      end loop;
      if S.Sample_Index < Batch_Position'Last then
         S.Sample_Index := S.Sample_Index + 1;
      end if;
      if S.Tick > 0 then
         Process (S, Throttle_Percent);
         S.Tick := S.Tick - 1;
      end if;
   end Update;

   ------------
   -- Filter --
   ------------

   procedure Filter (S : in out State; A : Axis; Value : in out Signal) is
      Output : Signal;
   begin
      for P in Notch_Index loop
         if P < S.Count then
            SVF_Notch_Apply (S.Notch (A, P), Value, Output);
            Value := Output;
         end if;
      end loop;
   end Filter;

end Adaflight.Dyn_Notch;
