with Interfaces; use Interfaces;

package body Adaflight.Simplified_Tuning.Stored with SPARK_Mode is

   -----------
   -- Apply --
   -----------

   procedure Apply (P : in out Config_Groups.Pid_Profile_Record; G : in out Config_Groups.Gyro_Config_Record) is
      use Axes;
      Mode : constant Unsigned_8 := P.Simplified_Pids_Mode;
   begin
      if Mode /= 0 then
         for A in Roll .. (if Mode = 1 then Pitch else Yaw) loop
            declare
               T : constant Tuned_Gains :=
                 Tuned ((Master        => Hundredths (Natural (P.Simplified_Master_Multiplier)),
                         PI_Gain       => Hundredths (Natural (P.Simplified_Pi_Gain)),
                         D_Gain        => Hundredths (Natural (P.Simplified_D_Gain)),
                         FF_Gain       => Hundredths (Natural (P.Simplified_Feedforward_Gain)),
                         I_Gain        => Hundredths (Natural (P.Simplified_I_Gain)),
                         D_Max_Slider  => Hundredths (Natural (P.Simplified_D_Max_Gain)),
                         Pitch_D_Gain  =>
                           (if A = Pitch then Hundredths (Natural (P.Simplified_Roll_Pitch_Ratio)) else 1.0),
                         Pitch_PI_Gain =>
                           (if A = Pitch then Hundredths (Natural (P.Simplified_Pitch_Pi_Gain)) else 1.0)),
                        A);
               I : constant Natural := Axis'Pos (A);
            begin
               P.Pid (I).P := Unsigned_8 (T.P);
               P.Pid (I).I := Unsigned_8 (T.I);
               P.Pid (I).D := Unsigned_8 (T.D);
               P.Pid (I).F := Unsigned_16 (T.F);
               P.D_Max (I) := Unsigned_8 (T.D_Max);
            end;
         end loop;
      end if;
      if P.Simplified_Dterm_Filter /= 0 then
         declare
            M : constant Natural := Natural (P.Simplified_Dterm_Filter_Multiplier);
         begin
            if P.Dterm_Lpf1_Dyn_Min_Hz /= 0 then
               P.Dterm_Lpf1_Dyn_Min_Hz := Unsigned_16 (Scaled (75, M, Dyn_LPF_Max_Hz));
               P.Dterm_Lpf1_Dyn_Max_Hz := Unsigned_16 (Scaled (150, M, Dyn_LPF_Max_Hz));
            end if;
            if P.Dterm_Lpf1_Static_Hz /= 0 then
               P.Dterm_Lpf1_Static_Hz := Unsigned_16 (Scaled (75, M, Dyn_LPF_Max_Hz));
            end if;
            if P.Dterm_Lpf2_Static_Hz /= 0 then
               P.Dterm_Lpf2_Static_Hz := Unsigned_16 (Scaled (150, M, LPF_Max_Hz));
            end if;
         end;
      end if;
      if G.Simplified_Gyro_Filter /= 0 then
         declare
            M : constant Natural := Natural (G.Simplified_Gyro_Filter_Multiplier);
         begin
            if G.Gyro_Lpf1_Dyn_Min_Hz /= 0 then
               G.Gyro_Lpf1_Dyn_Min_Hz := Unsigned_16 (Scaled (250, M, Dyn_LPF_Max_Hz));
               G.Gyro_Lpf1_Dyn_Max_Hz := Unsigned_16 (Scaled (500, M, Dyn_LPF_Max_Hz));
            end if;
            if G.Gyro_Lpf1_Static_Hz /= 0 then
               G.Gyro_Lpf1_Static_Hz := Unsigned_16 (Scaled (250, M, Dyn_LPF_Max_Hz));
            end if;
            if G.Gyro_Lpf2_Static_Hz /= 0 then
               G.Gyro_Lpf2_Static_Hz := Unsigned_16 (Scaled (500, M, LPF_Max_Hz));
            end if;
         end;
      end if;
   end Apply;

   -------------
   -- Disable --
   -------------

   procedure Disable (P : in out Config_Groups.Pid_Profile_Record; G : in out Config_Groups.Gyro_Config_Record) is
   begin
      P.Simplified_Pids_Mode := 0;
      P.Simplified_Dterm_Filter := 0;
      G.Simplified_Gyro_Filter := 0;
   end Disable;

end Adaflight.Simplified_Tuning.Stored;
