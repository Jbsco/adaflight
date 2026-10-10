with Interfaces;
package body Adaflight.Gyro_Filters with SPARK_Mode is
   use type Interfaces.Integer_32;

   Overflow_Trigger : constant Float := 31_980.0;
   Overflow_Reset   : constant Float := 30_340.0;

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
      S.Sensor_Rotation := Sensor_Alignment.Rotation_Matrix (C.Custom_Angles);
      S.Board_Rotation := Sensor_Alignment.Board_Rotation (C.Board);
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

   --  One calibration cycle: the counts join the sums and the deviation
   --  statistics, and the final cycle turns them into the zero offsets unless
   --  the deviation shows the craft moved, which restarts the calibration.
   procedure Calibration_Cycle (S : in out State; C : Settings; Sample : Raw_Vector; Finished : out Boolean)
     with Pre => S.Cycles_Remaining > 0
   is
      Cycles : constant Cycle_Count := Calibration_Cycles (C);
      Failed : Boolean := False;
   begin
      Finished := False;
      for A in Axis loop
         if S.Cycles_Remaining = Cycles then
            S.Cal_Sum (A) := 0.0;
            Stats_Clear (S.Cal_Stats (A));
            S.Zero (A) := 0.0;
         end if;
         --  The sum of a still craft's counts stays far inside the bound; the
         --  statistics count stays below its cap for any configured duration.
         S.Cal_Sum (A) := Constrain_F (S.Cal_Sum (A) + Float (Sample (A)), Cal_Total'First, Cal_Total'Last);
         if S.Cal_Stats (A).Count < Max_Samples then
            Stats_Push (S.Cal_Stats (A), Float (Sample (A)));
         end if;
         if S.Cycles_Remaining = 1 then
            declare
               Deviation : constant Float := Stats_Standard_Deviation (S.Cal_Stats (A));
            begin
               if C.Movement_Threshold /= 0 and then Deviation > Float (C.Movement_Threshold) then
                  Failed := True;
               else
                  --  A duration shortened below one cycle while calibrating would
                  --  divide by zero in the reference; the divisor stays at one.
                  S.Zero (A) :=
                    Constrain_F (S.Cal_Sum (A) / Float (Integer'Max (1, Cycles)), Offset'First, Offset'Last);
                  if A = Yaw then
                     S.Zero (A) := Constrain_F (S.Zero (A) - Float (C.Offset_Yaw) / 100.0, Offset'First, Offset'Last);
                  end if;
               end if;
            end;
         end if;
      end loop;
      if Failed then
         S.Cycles_Remaining := Cycles;
         return;
      end if;
      Finished := S.Cycles_Remaining = 1;
      S.Cycles_Remaining := S.Cycles_Remaining - 1;
   end Calibration_Cycle;

   procedure Accumulate (S : in out State; C : Settings; Sample : Raw_Vector; Finished : out Boolean) is
      use type Sensor_Alignment.Standard_Alignment;
   begin
      Finished := False;
      if Calibration_Complete (S) then
         declare
            --  The zeroed counts aligned to the body frame before the scale, as
            --  the reference orders them.
            Centered : Vectors.Vector3 :=
              (X => Float (Sample (Roll)) - S.Zero (Roll),
               Y => Float (Sample (Pitch)) - S.Zero (Pitch),
               Z => Float (Sample (Yaw)) - S.Zero (Yaw));
         begin
            if C.Alignment = Sensor_Alignment.Custom then
               Centered := Vectors.Apply_Rotation (Centered, S.Sensor_Rotation);
            else
               Centered := Sensor_Alignment.Align (Centered, C.Alignment);
            end if;
            if not Sensor_Alignment.Standard_Board (C.Board) then
               --  A sensor-aligned count is within 2 ** 19; the bound is stated
               --  for the board rotation's precondition.
               Centered := (X => Constrain_F (Centered.X, -2.0 ** 19, 2.0 ** 19),
                            Y => Constrain_F (Centered.Y, -2.0 ** 19, 2.0 ** 19),
                            Z => Constrain_F (Centered.Z, -2.0 ** 19, 2.0 ** 19));
               Centered := Vectors.Apply_Rotation (Centered, S.Board_Rotation);
            end if;
            S.Rate (Roll) := Constrain_F (Centered.X * C.Scale, -Signal_Bound, Signal_Bound);
            S.Rate (Pitch) := Constrain_F (Centered.Y * C.Scale, -Signal_Bound, Signal_Bound);
            S.Rate (Yaw) := Constrain_F (Centered.Z * C.Scale, -Signal_Bound, Signal_Bound);
         end;
      else
         Calibration_Cycle (S, C, Sample, Finished);
      end if;
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

   --  The overflow of a gyro without protection: a filtered rate near full
   --  scale on a checked axis flags it, and 50 ms of rates below the reset
   --  level on every axis clears it.
   procedure Check_Overflow (S : in out State; C : Settings; Now_Us : Time_Us) is
   begin
      if S.Overflow_Detected then
         declare
            Reset_Rate : constant Float := Overflow_Reset * C.Scale;
         begin
            if abs S.Filtered (Roll) < Reset_Rate and then abs S.Filtered (Pitch) < Reset_Rate
              and then abs S.Filtered (Yaw) < Reset_Rate
            then
               if Clock.Elapsed (Now_Us, S.Overflow_Time_Us) > 50_000 then
                  S.Overflow_Detected := False;
               end if;
            else
               S.Overflow_Time_Us := Now_Us;
            end if;
         end;
      else
         declare
            Trigger : constant Float := Overflow_Trigger * C.Scale;
            Hit     : Boolean := False;
         begin
            case C.Check_Overflow is
               when Yaw_Axis =>
                  Hit := abs S.Filtered (Yaw) > Trigger;
               when All_Axes =>
                  Hit := abs S.Filtered (Roll) > Trigger or else abs S.Filtered (Pitch) > Trigger
                         or else abs S.Filtered (Yaw) > Trigger;
               when No_Check =>
                  null;
            end case;
            if Hit then
               S.Overflow_Detected := True;
               S.Overflow_Time_Us := Now_Us;
               S.Yaw_Spin_Detected := False;
            end if;
         end;
      end if;
   end Check_Overflow;

   --  A yaw spin: the filtered yaw rate past the threshold flags it, and
   --  20 ms below the threshold less a margin clears it. The reference
   --  truncates the rate to an integer before the comparison, which the
   --  comparison against the next whole number reproduces.
   procedure Check_Yaw_Spin (S : in out State; Now_Us : Time_Us) is
   begin
      if S.Overflow_Detected then
         S.Yaw_Spin_Detected := False;
         return;
      end if;
      if S.Yaw_Spin_Detected then
         if abs S.Filtered (Yaw) < Float (S.Yaw_Spin_Limit) - 100.0 then
            if Clock.Elapsed (Now_Us, S.Yaw_Spin_Time_Us) > 20_000 then
               S.Yaw_Spin_Detected := False;
            end if;
         else
            S.Yaw_Spin_Time_Us := Now_Us;
         end if;
      elsif abs S.Filtered (Yaw) >= Float (S.Yaw_Spin_Limit + 1) then
         S.Yaw_Spin_Detected := True;
         S.Yaw_Spin_Time_Us := Now_Us;
      end if;
   end Check_Yaw_Spin;

   procedure Filter (S : in out State; C : Settings; Now_Us : Time_Us) is
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
                  declare
                     Count : constant Float range 1.0 .. 255.0 := Float (S.Samples);
                  begin
                     Value := S.Sample_Sum (A) / Count;
                  end;
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
      if C.Check_Overflow /= No_Check and then not C.Overflow_Protected then
         Check_Overflow (S, C, Now_Us);
      end if;
      if S.Yaw_Spin_Enabled then
         Check_Yaw_Spin (S, Now_Us);
      end if;
      if not S.Overflow_Detected then
         for A in Axis loop
            PT1_Apply (S.IMU_Filter (A), S.Filtered (A), S.Downsampled (A));
         end loop;
      end if;
   end Filter;

   -----------------------
   -- Start_Calibration --
   -----------------------

   procedure Start_Calibration (S : in out State; C : Settings; First_Arm : Boolean) is
   begin
      if First_Arm and then S.First_Arm_Started then
         return;
      end if;
      S.Cycles_Remaining := Calibration_Cycles (C);
      if First_Arm then
         S.First_Arm_Started := True;
      end if;
   end Start_Calibration;

   ----------------------------
   -- Init_Yaw_Spin_Recovery --
   ----------------------------

   procedure Init_Yaw_Spin_Recovery (S : in out State; C : Settings; Max_Yaw_Rate : Natural) is
   begin
      case C.Yaw_Spin is
         when On =>
            S.Yaw_Spin_Enabled := True;
            S.Yaw_Spin_Limit := C.Yaw_Spin_Threshold;
         when Auto =>
            --  A quarter of the maximum yaw rate, at least 200 degrees per
            --  second, of overshoot allowance.
            S.Yaw_Spin_Enabled := True;
            S.Yaw_Spin_Limit :=
              Integer'Max (Spin_Threshold'First,
                           Integer'Min (Spin_Threshold'Last, Max_Yaw_Rate + Integer'Max (Max_Yaw_Rate / 4, 200)));
         when Off =>
            S.Yaw_Spin_Enabled := False;
            S.Yaw_Spin_Limit := Spin_Threshold'Last;
      end case;
   end Init_Yaw_Spin_Recovery;

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
