package body Adaflight.Gyro_Filters with SPARK_Mode is

   --  The notch center limit: 95 percent of the sensor-rate Nyquist frequency
   --  from an integer division of the period, truncated as the reference does.
   function Nyquist_Limit (Loop_Time : PID_Config.Loop_Time_Us) return Natural
     with Post => Nyquist_Limit'Result <= 4750
   is
      Half_Rate : constant Natural := 500_000 / Loop_Time;
   begin
      return Natural (Float'Truncation (Float (Half_Rate) * 0.95));
   end Nyquist_Limit;

   function Adjusted_Notch (Hz : Hertz; Cutoff : Hertz; Limit : Natural) return Natural
     with Pre  => Limit <= 4750 and then (Hz = 0 or else Cutoff < Hz),
          Post => Adjusted_Notch'Result <= 4750
            and then (Adjusted_Notch'Result = 0 or else Cutoff < Adjusted_Notch'Result)
   is
   begin
      if Hz > Limit then
         if Cutoff < Limit then
            return Limit;
         else
            return 0;
         end if;
      end if;
      return Hz;
   end Adjusted_Notch;

   procedure Init_Notch
     (Used : out Boolean; Notch : out Axis_Notch; Hz : Hertz; Cutoff : Hertz;
      Limit : Natural; Dt : Seconds)
     with Pre => Limit <= 4750 and then (Hz = 0 or else Cutoff < Hz)
   is
      Center : constant Natural := Adjusted_Notch (Hz, Cutoff, Limit);
   begin
      Notch := (others => <>);
      Used := Center /= 0 and then Cutoff /= 0;
      if Used then
         PID_Filters.Lemma_Convert_Successor (Cutoff);
         PID_Filters.Lemma_Convert_Monotone (Cutoff + 1, Center);
         declare
            Q : constant Quality := Notch_Q (Float (Center), Float (Cutoff));
         begin
            for A in Axis loop
               SVF_Notch_Init (Notch (A), Float (Center), Dt, Q);
            end loop;
         end;
      end if;
   end Init_Notch;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
      Dt_Loop   : constant Seconds := Float (C.Loop_Time_Us) * 1.0e-6;
      Dt_Sample : constant Seconds := Float (C.Sample_Time_Us) * 1.0e-6;
      LPF1_Hz   : constant Hertz :=
        (if C.LPF1_Dyn_Min_Hz > 0 then C.LPF1_Dyn_Min_Hz else C.LPF1_Static_Hz);
   begin
      S := (others => <>);
      for A in Axis loop
         PID_Filters.Init_Stage
           (S.Lowpass1 (A), C.LPF1_Type, LPF1_Hz, Nyquist_Limit (C.Loop_Time_Us), Dt_Loop, Inclusive => True);
      end loop;
      for A in Axis loop
         PID_Filters.Init_Stage
           (S.Lowpass2 (A), C.LPF2_Type, C.LPF2_Static_Hz, Nyquist_Limit (C.Sample_Time_Us), Dt_Sample,
            Inclusive => True);
      end loop;
      S.Downsample_Filter := S.Lowpass2 (Roll).Used;
      Init_Notch (S.Notch1_Used, S.Notch1, C.Notch1_Hz, C.Notch1_Cutoff, Nyquist_Limit (C.Loop_Time_Us), Dt_Loop);
      Init_Notch (S.Notch2_Used, S.Notch2, C.Notch2_Hz, C.Notch2_Cutoff, Nyquist_Limit (C.Loop_Time_Us), Dt_Loop);
      if C.LPF1_Dyn_Min_Hz > 0 then
         S.Dyn_LPF :=
           (case C.LPF1_Type is
              when PID_Profile.PT1 => PID_Config.PT1, when PID_Profile.SVF => PID_Config.SVF,
              when PID_Profile.PT2 => PID_Config.PT2, when PID_Profile.PT3 => PID_Config.PT3);
      end if;
      S.Dyn_LPF_Min := C.LPF1_Dyn_Min_Hz;
      S.Dyn_LPF_Max := C.LPF1_Dyn_Max_Hz;
      S.Dyn_LPF_Expo := C.LPF1_Dyn_Expo;
      declare
         K : constant Unit_Interval := PT1_Gain (IMU_Downsample_Cutoff_Hz, Dt_Loop);
      begin
         for A in Axis loop
            PT1_Init (S.IMU_Filter (A), K);
         end loop;
      end;
   end Init;

   ----------------
   -- Accumulate --
   ----------------

   procedure Accumulate (S : in out State; C : Settings; Sample : Raw_Vector) is
   begin
      for A in Axis loop
         S.Rate (A) := (Float (Sample (A)) - C.Zero (A)) * C.Scale;
      end loop;
      if S.Downsample_Filter then
         for A in Axis loop
            PID_Filters.Apply_Stage (S.Lowpass2 (A), S.Rate (A), S.Sample_Sum (A));
         end loop;
      else
         for A in Axis loop
            S.Sample_Sum (A) := Constrain_F (S.Sample_Sum (A) + S.Rate (A), -Signal_Bound, Signal_Bound);
         end loop;
         S.Samples := (S.Samples + 1) mod 256;
      end if;
   end Accumulate;

   ------------
   -- Filter --
   ------------

   procedure Filter (S : in out State; C : Settings) is
      pragma Unreferenced (C);
   begin
      for A in Axis loop
         declare
            Value : Signal := 0.0;
            Stage_Out : Signal;
         begin
            if S.Downsample_Filter then
               Value := S.Sample_Sum (A);
            else
               if S.Samples > 0 then
                  Value := S.Sample_Sum (A) / Float (S.Samples);
               end if;
               S.Sample_Sum (A) := 0.0;
            end if;
            if S.Notch1_Used then
               SVF_Notch_Apply (S.Notch1 (A), Value, Stage_Out);
               Value := Stage_Out;
            end if;
            if S.Notch2_Used then
               SVF_Notch_Apply (S.Notch2 (A), Value, Stage_Out);
               Value := Stage_Out;
            end if;
            PID_Filters.Apply_Stage (S.Lowpass1 (A), Value, Stage_Out);
            S.Filtered (A) := Stage_Out;
         end;
      end loop;
      S.Samples := 0;
      for A in Axis loop
         PT1_Apply (S.IMU_Filter (A), S.Filtered (A), S.Downsampled (A));
      end loop;
   end Filter;

   ----------------------------
   -- Update_Dynamic_Lowpass --
   ----------------------------

   procedure Update_Dynamic_Lowpass (S : in out State; C : Settings; Throttle : Unit_Interval) is
      Dt     : constant Seconds := Float (C.Loop_Time_Us) * 1.0e-6;
      Cutoff : Float;
   begin
      if S.Dyn_LPF = None then
         return;
      end if;
      if S.Dyn_LPF_Expo > 0 then
         Cutoff := PID_Filters.Dynamic_Cutoff (Throttle, S.Dyn_LPF_Min, S.Dyn_LPF_Max, S.Dyn_LPF_Expo);
      else
         Cutoff := Float'Max (PID_Filters.Dynamic_Throttle (Throttle) * Float (S.Dyn_LPF_Max), Float (S.Dyn_LPF_Min));
      end if;
      Cutoff := Constrain_F (Cutoff, 0.0, 2300.0);
      case S.Dyn_LPF is
         when None => null;
         when PID_Config.PT1 =>
            for A in Axis loop
               PT1_Update_Cutoff (S.Lowpass1 (A).P1, PT1_Gain (Cutoff, Dt));
            end loop;
         when PID_Config.SVF =>
            Cutoff := Float'Min (Cutoff, 0.475 / Dt);
            for A in Axis loop
               SVF_Lowpass_Update (S.Lowpass1 (A).S, Cutoff, Dt);
            end loop;
         when PID_Config.PT2 =>
            for A in Axis loop
               PT2_Update_Cutoff (S.Lowpass1 (A).P2, PT2_Gain (Cutoff, Dt));
            end loop;
         when PID_Config.PT3 =>
            for A in Axis loop
               PT3_Update_Cutoff (S.Lowpass1 (A).P3, PT3_Gain (Cutoff, Dt));
            end loop;
      end case;
   end Update_Dynamic_Lowpass;

end Adaflight.Gyro_Filters;
