with Interfaces;
with Adaflight.Dyn_Notch;

package body Adaflight.Gyro_Debug with SPARK_Mode is
   use type Axes.Axis;

   subtype Axis is Axes.Axis;

   --  A rate held within the conversion bound.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   procedure Record_Filter
     (D : in out Debug.State; S : Gyro_Filters.State; Debug_Axis : Axes.Axis; Load_Percent : Natural) is
   begin
      if Debug.Selected (D, Debug.Gyro_Raw) then
         for A in Axis loop
            Debug.Set (D, Debug.Gyro_Raw, Axis'Pos (A), Debug.Wrapped (Interfaces.Integer_32 (S.Taps.Raw_Last (A))));
         end loop;
      end if;
      if Debug.Selected (D, Debug.Gyro_Filtered) then
         for A in Axis loop
            Debug.Set (D, Debug.Gyro_Filtered, Axis'Pos (A), Debug.Rounded (Held (S.Filtered (A))));
         end loop;
      end if;
      if Debug.Selected (D, Debug.Gyro_Sample) then
         Debug.Set (D, Debug.Gyro_Sample, 0, Debug.Rounded (Held (S.Rate (Debug_Axis))));
         Debug.Set (D, Debug.Gyro_Sample, 1, Debug.Rounded (Held (S.Taps.Downsampled)));
         Debug.Set (D, Debug.Gyro_Sample, 2, Debug.Rounded (Held (S.Taps.After_RPM)));
         Debug.Set (D, Debug.Gyro_Sample, 3, Debug.Rounded (Held (S.Taps.After_Static)));
         Debug.Set (D, Debug.Gyro_Sample, 4, Debug.Wrapped (Interfaces.Integer_32 (Load_Percent)));
      end if;
      if S.Taps.Dyn_Ran then
         if Debug.Selected (D, Debug.FFT) then
            Debug.Set (D, Debug.FFT, 0, Debug.Rounded (Held (S.Taps.Dyn_In)));
            Debug.Set (D, Debug.FFT, 1, Debug.Rounded (Held (S.Taps.Dyn_Out)));
         end if;
         if Debug.Selected (D, Debug.FFT_Freq) then
            Debug.Set (D, Debug.FFT_Freq, 0, Debug.Rounded (Held (S.Taps.Dyn_In)));
         end if;
         if Debug.Selected (D, Debug.Dyn_LPF) then
            Debug.Set (D, Debug.Dyn_LPF, 0, Debug.Rounded (Held (S.Taps.Dyn_In)));
            Debug.Set (D, Debug.Dyn_LPF, 3, Debug.Rounded (Held (S.Taps.Dyn_Out)));
         end if;
      end if;
      if S.Dyn.Active and then S.Dyn.Average_Fresh and then Debug.Selected (D, Debug.FFT) then
         Debug.Set (D, Debug.FFT, 2, Debug.Rounded (Held (S.Dyn.Average (Debug_Axis))));
      end if;
      if S.Dyn.Active and then S.Dyn.Freq_Step and then S.Dyn.Freq_Axis = Debug_Axis then
         if Debug.Selected (D, Debug.FFT_Freq) then
            for P in Dyn_Notch.Notch_Index loop
               if P < S.Dyn.Count then
                  Debug.Set (D, Debug.FFT_Freq, P + 1, Debug.Rounded (S.Dyn.Center (Debug_Axis, P)));
               end if;
            end loop;
         end if;
         if Debug.Selected (D, Debug.Dyn_LPF) then
            Debug.Set (D, Debug.Dyn_LPF, 1, Debug.Rounded (S.Dyn.Center (Debug_Axis, 0)));
         end if;
      end if;
      if Debug.Selected (D, Debug.Dyn_LPF) then
         Debug.Set (D, Debug.Dyn_LPF, 2, Debug.Rounded (S.Taps.LPF_Cutoff));
      end if;
   end Record_Filter;

   procedure Record_Calibration (D : in out Debug.State; S : Gyro_Filters.State) is
   begin
      for I in Gyro_Filters.Gyro_Index loop
         if S.Enabled (I) and then S.Sensors (I).Cal_Step then
            if S.Sensors (I).Cal_Final then
               if Debug.Selected (D, Debug.Gyro_Raw) then
                  Debug.Set (D, Debug.Gyro_Raw, 3, Debug.Rounded (S.Taps.Cal_Deviation (Axes.Roll)));
               end if;
               if Debug.Selected (D, Debug.Gyro_Calibration) then
                  for A in Axis loop
                     Debug.Set (D, Debug.Gyro_Calibration, Axis'Pos (A), Debug.Truncated (S.Taps.Cal_Deviation (A)));
                  end loop;
               end if;
            end if;
            if not S.Sensors (I).Cal_Failed and then Debug.Selected (D, Debug.Gyro_Calibration) then
               Debug.Set (D, Debug.Gyro_Calibration, 3,
                          Debug.Wrapped (Interfaces.Integer_32 (S.Sensors (I).Cycles_Remaining)));
            end if;
         end if;
      end loop;
   end Record_Calibration;

   procedure Record_Multi (D : in out Debug.State; S : Gyro_Filters.State; C : Gyro_Filters.Settings) is
      Slot : Natural range 0 .. 4 := 0;
   begin
      if not (Debug.Selected (D, Debug.Multi_Gyro_Raw) or else Debug.Selected (D, Debug.Multi_Gyro_Scaled)
              or else Debug.Selected (D, Debug.Multi_Gyro_Diff))
      then
         return;
      end if;
      for I in Gyro_Filters.Gyro_Index loop
         pragma Loop_Invariant (Slot <= I);
         if S.Enabled (I) and then Slot < 4 then
            declare
               Roll_Rate  : constant Float := S.Sensors (I).Aligned (Axes.Roll) * C.Scale;
               Pitch_Rate : constant Float := S.Sensors (I).Aligned (Axes.Pitch) * C.Scale;
            begin
               Debug.Set (D, Debug.Multi_Gyro_Raw, 2 * Slot, S.Sensors (I).Raw_Roll);
               Debug.Set (D, Debug.Multi_Gyro_Raw, 2 * Slot + 1, S.Sensors (I).Raw_Pitch);
               Debug.Set (D, Debug.Multi_Gyro_Scaled, 2 * Slot, Debug.Rounded (Held (Roll_Rate)));
               Debug.Set (D, Debug.Multi_Gyro_Scaled, 2 * Slot + 1, Debug.Rounded (Held (Pitch_Rate)));
               Debug.Set (D, Debug.Multi_Gyro_Diff, 2 * Slot,
                          Debug.Rounded (Held (Held (Roll_Rate) - Held (S.Filtered (Axes.Roll)))));
               Debug.Set (D, Debug.Multi_Gyro_Diff, 2 * Slot + 1,
                          Debug.Rounded (Held (Held (Pitch_Rate) - Held (S.Filtered (Axes.Pitch)))));
            end;
            Slot := Slot + 1;
         end if;
      end loop;
   end Record_Multi;

end Adaflight.Gyro_Debug;
