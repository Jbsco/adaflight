with Interfaces;
with Adaflight.Dyn_Notch;

package body Adaflight.Gyro_Debug with SPARK_Mode is
   use type Axes.Axis;

   subtype Axis is Axes.Axis;

   --  A rate held within the rounding bound.
   function Held (X : Float) return Float is (Float'Max (-(2.0 ** 24 - 1.0), Float'Min (2.0 ** 24 - 1.0, X)));

   procedure Record_Filter
     (D : in out Debug.State; S : Gyro_Filters.State; Debug_Axis : Axes.Axis; Load_Percent : Natural) is
   begin
      for A in Axis loop
         Debug.Set (D, Debug.Gyro_Raw, Axis'Pos (A), Debug.Wrapped (Interfaces.Integer_32 (S.Taps.Raw_Last (A))));
         Debug.Set (D, Debug.Gyro_Filtered, Axis'Pos (A), Debug.Rounded (Held (S.Filtered (A))));
      end loop;
      Debug.Set (D, Debug.Gyro_Sample, 0, Debug.Rounded (Held (S.Rate (Debug_Axis))));
      Debug.Set (D, Debug.Gyro_Sample, 1, Debug.Rounded (Held (S.Taps.Downsampled)));
      Debug.Set (D, Debug.Gyro_Sample, 2, Debug.Rounded (Held (S.Taps.After_RPM)));
      Debug.Set (D, Debug.Gyro_Sample, 3, Debug.Rounded (Held (S.Taps.After_Static)));
      if S.Taps.Dyn_Ran then
         Debug.Set (D, Debug.FFT, 0, Debug.Rounded (Held (S.Taps.Dyn_In)));
         Debug.Set (D, Debug.FFT_Freq, 0, Debug.Rounded (Held (S.Taps.Dyn_In)));
         Debug.Set (D, Debug.Dyn_LPF, 0, Debug.Rounded (Held (S.Taps.Dyn_In)));
         Debug.Set (D, Debug.FFT, 1, Debug.Rounded (Held (S.Taps.Dyn_Out)));
         Debug.Set (D, Debug.Dyn_LPF, 3, Debug.Rounded (Held (S.Taps.Dyn_Out)));
      end if;
      if S.Dyn.Active and then S.Dyn.Average_Fresh then
         Debug.Set (D, Debug.FFT, 2, Debug.Rounded (Held (S.Dyn.Average (Debug_Axis))));
      end if;
      if S.Dyn.Active and then S.Dyn.Freq_Step and then S.Dyn.Freq_Axis = Debug_Axis then
         for P in Dyn_Notch.Notch_Index loop
            if P < S.Dyn.Count then
               Debug.Set (D, Debug.FFT_Freq, P + 1, Debug.Rounded (S.Dyn.Center (Debug_Axis, P)));
            end if;
         end loop;
         Debug.Set (D, Debug.Dyn_LPF, 1, Debug.Rounded (S.Dyn.Center (Debug_Axis, 0)));
      end if;
      Debug.Set (D, Debug.Dyn_LPF, 2, Debug.Rounded (S.Taps.LPF_Cutoff));
      Debug.Set (D, Debug.Gyro_Sample, 4, Debug.Wrapped (Interfaces.Integer_32 (Load_Percent)));
   end Record_Filter;

   procedure Record_Calibration (D : in out Debug.State; S : Gyro_Filters.State) is
   begin
      for I in Gyro_Filters.Gyro_Index loop
         if S.Enabled (I) and then S.Sensors (I).Cal_Step then
            if S.Sensors (I).Cal_Final then
               for A in Axis loop
                  if A = Axes.Roll then
                     Debug.Set (D, Debug.Gyro_Raw, 3, Debug.Rounded (S.Taps.Cal_Deviation (A)));
                  end if;
                  Debug.Set (D, Debug.Gyro_Calibration, Axis'Pos (A), Debug.Truncated (S.Taps.Cal_Deviation (A)));
               end loop;
            end if;
            if not S.Sensors (I).Cal_Failed then
               Debug.Set (D, Debug.Gyro_Calibration, 3,
                          Debug.Wrapped (Interfaces.Integer_32 (S.Sensors (I).Cycles_Remaining)));
            end if;
         end if;
      end loop;
   end Record_Calibration;

end Adaflight.Gyro_Debug;
