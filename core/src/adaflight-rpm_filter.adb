package body Adaflight.RPM_Filter with SPARK_Mode is

   --  The time one pass over the whole bank may take.
   Update_Window_S : constant := 0.001;

   ----------
   -- Init --
   ----------

   procedure Init
     (S : out State; C : Settings; Loop_Time_Us : PID_Config.Loop_Time_Us;
      Motors : Motor_Count; Telemetry : Boolean)
   is
      Dt     : constant PID_Config.Seconds := Float (Loop_Time_Us) * 1.0e-6;
      Max_Hz : constant Notch_Frequency := 0.48 * 1.0e6 / Float (Loop_Time_Us);
      Min_Hz : constant Notch_Frequency := Float (C.Min_Hz);
      Q      : constant Quality := Float (C.Q) / 100.0;
   begin
      S := (others => <>);
      if not Telemetry or else C.Harmonics = 0 or else Max_Hz < Min_Hz then
         return;
      end if;
      S.Min_Hz := Min_Hz;
      S.Max_Hz := Max_Hz;
      S.Fade_Range_Hz := Float (C.Fade_Range_Hz);
      S.Q := Q;
      S.Dt := Dt;
      S.Motors := Motors;
      for H in Harmonic loop
         S.Weights (H) := Constrain_F (Float (C.Weights (H)) / 100.0, 0.0, 1.0);
      end loop;
      for M in 0 .. Motors - 1 loop
         for H in 0 .. C.Harmonics - 1 loop
            Weighted_Notch_Init (S.Notches (M, H), Min_Hz * Float (H + 1), Dt, Q, 0.0);
         end loop;
      end loop;
      declare
         Loops_Per_Window : constant Float range 0.005 .. 20.0 := Update_Window_S / Dt;
         Notches_Per_Axis : constant Float range 0.0 .. 24.0 := Float (Motors * C.Harmonics);
         Updates          : constant Float := Float'Ceiling (Notches_Per_Axis / Loops_Per_Window);
      begin
         S.Updates_Per_Loop := Integer (Constrain_F (Updates, 0.0, Float (Update_Count'Last)));
      end;
      S.Harmonics := C.Harmonics;
   end Init;

   ---------
   -- Run --
   ---------

   --  A notch's blend: faded over the range above the minimum frequency,
   --  then scaled by its harmonic's weight.
   function Blend (Margin : Notch_Frequency; Fade_Range_Hz : Float; Gain : Unit_Interval) return Unit_Interval
     with Pre => Fade_Range_Hz in 0.0 .. 1_000.0
   is
      Weight : Unit_Interval := 1.0;
   begin
      if Margin < Fade_Range_Hz then
         Weight := Margin / Fade_Range_Hz;
      end if;
      return Weight * Gain;
   end Blend;

   --  The scheduled share of the bank moves to the motors' frequencies.
   procedure Update (S : in out State; Motor_Hz : Motor_Frequencies; Dt_Scale : Cycle_Multiplier)
     with Pre  => S.Harmonics > 0,
          Post => S.Harmonics = S.Harmonics'Old and then S.Motors = S.Motors'Old
                  and then S.Weights = S.Weights'Old
   is
      Corrected_Dt : constant Period := S.Dt * Dt_Scale;
   begin
      for I in 1 .. S.Updates_Per_Loop loop
         declare
            H : constant Harmonic := S.Harmonic_Index;
            M : constant Motor_Index := S.Motor;
         begin
            if S.Weights (H) > 0.0 then
               declare
                  Hz     : constant Notch_Frequency :=
                    Constrain_F (Float (H + 1) * Motor_Hz (M), S.Min_Hz, S.Max_Hz);
                  Margin : constant Notch_Frequency := Hz - S.Min_Hz;
               begin
                  Weighted_Notch_Update
                    (S.Notches (M, H), Hz, Corrected_Dt, S.Q, Blend (Margin, S.Fade_Range_Hz, S.Weights (H)));
               end;
            end if;
            S.Harmonic_Index := (H + 1) mod S.Harmonics;
            if S.Harmonic_Index = 0 then
               S.Motor := (M + 1) mod S.Motors;
            end if;
         end;
      end loop;
   end Update;

   --  Every notch of a weighted harmonic, over the motors.
   procedure Apply (S : in out State; Values : in out Axis_Signals)
     with Pre  => S.Harmonics > 0,
          Post => S.Harmonics = S.Harmonics'Old
   is
   begin
      for H in 0 .. S.Harmonics - 1 loop
         if S.Weights (H) > 0.0 then
            for M in 0 .. S.Motors - 1 loop
               Weighted_Notch_Apply (S.Notches (M, H), Values);
            end loop;
         end if;
      end loop;
   end Apply;

   procedure Run
     (S : in out State; Motor_Hz : Motor_Frequencies; Dt_Scale : Cycle_Multiplier;
      Values : in out Axis_Signals)
   is
   begin
      if S.Harmonics = 0 then
         return;
      end if;
      Update (S, Motor_Hz, Dt_Scale);
      Apply (S, Values);
   end Run;

end Adaflight.RPM_Filter;
