package body Adaflight.PID_Debug with SPARK_Mode is
   use type Axes.Axis;

   subtype Axis is Axes.Axis;
   subtype Level_Axis is PID_Controller.Level_Axis;

   --  A value held within the conversion bound, before and after a scale.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   --  A value scaled then rounded as the reference stores lrintf results.
   function R10 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 10.0)));
   function R100 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 100.0)));
   function R1000 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 1000.0)));

   procedure Record_Loop
     (D : in out Debug.State; S : PID_Controller.State; R : PID_Config.Runtime; Inp : PID_Controller.Inputs;
      Debug_Axis : Axes.Axis)
   is
      T       : PID_Controller.Debug_Taps renames S.Taps;
      Current : array (Level_Axis) of Float;
      Ki      : constant Float := R.Coefficient (Axes.Pitch).Ki;
   begin
      for A in Level_Axis loop
         Current (A) := Float (Inp.Attitude (A) - Inp.Trims (A)) / 10.0;
      end loop;
      if Debug.Selected (D, Debug.TPA) then
         Debug.Set (D, Debug.TPA, 0, R1000 (S.TPA_Factor));
         if T.Wing_TPA_Ran then
            Debug.Set (D, Debug.TPA, 1, Debug.Rounded (Held (T.Wing_Roll)));
            Debug.Set (D, Debug.TPA, 2, Debug.Rounded (Held (T.Wing_Pitch)));
            Debug.Set (D, Debug.TPA, 3, R1000 (T.Wing_Throttle));
            Debug.Set (D, Debug.TPA, 4, R10 (S.Wing_Speed));
            Debug.Set (D, Debug.TPA, 5, R1000 (T.Wing_Argument));
         end if;
      end if;
      if Debug.Selected (D, Debug.Anti_Gravity) then
         Debug.Set (D, Debug.Anti_Gravity, 0, R100 (T.Throttle_D_Raw));
         Debug.Set (D, Debug.Anti_Gravity, 1, R100 (T.Throttle_D_Smooth));
         Debug.Set (D, Debug.Anti_Gravity, 2,
                    (if Ki >= 2.0 ** (-20) then R1000 (1.0 + Held (T.Iterm_Accelerator) / Ki) else 0));
         Debug.Set (D, Debug.Anti_Gravity, 3, R1000 (T.P_Boost));
      end if;
      if T.Level_Ran (Axes.Roll) then
         if Debug.Selected (D, Debug.Angle_Mode) then
            Debug.Set (D, Debug.Angle_Mode, 0, R10 (S.Angle_Target (Axes.Roll)));
            Debug.Set (D, Debug.Angle_Mode, 1,
                       R10 ((S.Angle_Target (Axes.Roll) - Current (Axes.Roll)) * R.Angle_Gain));
            Debug.Set (D, Debug.Angle_Mode, 2, R10 (T.Angle_Feedforward));
            Debug.Set (D, Debug.Angle_Mode, 3, R10 (Current (Axes.Roll)));
         end if;
         if Debug.Selected (D, Debug.Angle_Target) then
            Debug.Set (D, Debug.Angle_Target, 0, R10 (S.Angle_Target (Axes.Roll)));
            Debug.Set (D, Debug.Angle_Target, 1, R10 (T.Sin_Angle));
            Debug.Set (D, Debug.Angle_Target, 3, R10 (Current (Axes.Roll)));
         end if;
      end if;
      if T.Yaw_Attenuated_Set and then Debug.Selected (D, Debug.Angle_Target) then
         Debug.Set (D, Debug.Angle_Target, 2, Debug.Truncated (Held (T.Yaw_Attenuated)));
      end if;
      if Debug.Selected (D, Debug.Current_Angle) then
         for A in Level_Axis loop
            if T.Level_Ran (A) then
               Debug.Set (D, Debug.Current_Angle, Axis'Pos (A), R10 (Current (A)));
            end if;
         end loop;
      end if;
      if T.Relax_Set and then Debug.Selected (D, Debug.ITerm_Relax) then
         Debug.Set (D, Debug.ITerm_Relax, 0, Debug.Rounded (Held (T.Relax_Hpf)));
         Debug.Set (D, Debug.ITerm_Relax, 1, R100 (T.Relax_Factor));
         Debug.Set (D, Debug.ITerm_Relax, 2, Debug.Rounded (Held (T.Relax_Error)));
      end if;
      if R.Landing_Disarm_Threshold > 0.0 and then Debug.Selected (D, Debug.EZ_Landing) then
         Debug.Set (D, Debug.EZ_Landing, 6, R100 (Inp.Max_Deflection));
         Debug.Set (D, Debug.EZ_Landing, 7, R1000 (Inp.Jerk_Magnitude));
      end if;
      if R.Wing_Build then
         for A in Axis loop
            if Debug.Selected (D, Debug.S_Term) then
               Debug.Set (D, Debug.S_Term, 2 * Axis'Pos (A), Debug.Rounded (Held (T.S_Base (A))));
               Debug.Set (D, Debug.S_Term, 2 * Axis'Pos (A) + 1, Debug.Rounded (Held (T.S_After (A))));
            end if;
            if Debug.Selected (D, Debug.SPA) then
               Debug.Set (D, Debug.SPA, Axis'Pos (A), R1000 (S.SPA (A)));
            end if;
            if Debug.Selected (D, Debug.Wing_Setpoint) then
               Debug.Set (D, Debug.Wing_Setpoint, 2 * Axis'Pos (A), Debug.Rounded (Held (T.Wing_Setpoint_In (A))));
               Debug.Set (D, Debug.Wing_Setpoint, 2 * Axis'Pos (A) + 1,
                          Debug.Rounded (Held (T.Wing_Setpoint_Out (A))));
            end if;
         end loop;
      end if;
      if Debug.Selected (D, Debug.D_LPF) then
         for A in Level_Axis loop
            Debug.Set (D, Debug.D_LPF, Axis'Pos (A), Debug.Rounded (Held (T.D_Raw_Delta (A))));
            Debug.Set (D, Debug.D_LPF, Axis'Pos (A) + 2, R10 (T.D_Pre_TPA (A)));
         end loop;
      end if;
      if T.D_Max_Set (Debug_Axis) and then Debug.Selected (D, Debug.D_Max) then
         Debug.Set (D, Debug.D_Max, 0, R100 (T.D_Max_Gyro_Factor (Debug_Axis)));
         Debug.Set (D, Debug.D_Max, 1, R100 (T.D_Max_Setpoint_Factor (Debug_Axis)));
         Debug.Set (D, Debug.D_Max, 2,
                    R10 (Held (Held (R.Coefficient (Debug_Axis).Kd) * Held (T.D_Max_Multiplier (Debug_Axis)))
                         / 0.000529));
         Debug.Set (D, Debug.D_Max, 3, R100 (T.D_Max_Multiplier (Debug_Axis)));
      end if;
   end Record_Loop;

end Adaflight.PID_Debug;
