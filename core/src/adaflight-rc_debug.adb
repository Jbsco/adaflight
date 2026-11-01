with Interfaces;

package body Adaflight.RC_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   subtype Axis is Axes.Axis;

   --  A value held within the conversion bound, before and after a scale.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   --  A value scaled then rounded, as the reference stores lrintf results.
   function R1 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (X)));
   function R001 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 0.01)));
   function R10 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 10.0)));
   function R100 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 100.0)));
   function R1000 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 1000.0)));

   --  An integer held to the positive sixteen-bit range then wrapped, as a C
   --  minimum against the sixteen-bit maximum stores.
   function Low_Word (V : Integer) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (Integer'Min (32_767, V))));

   function Flag (B : Boolean) return Debug.Integer_16 is (if B then 1 else 0);

   procedure Record_Pass
     (D : in out Debug.State; S : RC_Command.State; Debug_Axis : Axes.Axis; Link_Quality_Percent : Natural;
      Receiving : Boolean)
   is
      T : RC_Command.Debug_Taps renames S.Taps;
   begin
      if Debug.Selected (D, Debug.RX_Timing) then
         if T.Refreshed then
            Debug.Set (D, Debug.RX_Timing, 0, Low_Word (T.Delta_Us / 10));
            Debug.Set (D, Debug.RX_Timing, 2, Flag (S.Rate_Valid));
            Debug.Set (D, Debug.RX_Timing, 3, Low_Word (S.Current_Interval_Us / 10));
            Debug.Set (D, Debug.RX_Timing, 4, R1 (S.Current_Rate_Hz));
            Debug.Set (D, Debug.RX_Timing, 6, Debug.Wrapped (Interfaces.Integer_32 (Link_Quality_Percent)));
            Debug.Set (D, Debug.RX_Timing, 7, Flag (Receiving));
         end if;
         if T.Rx_Time_Set then
            Debug.Set (D, Debug.RX_Timing, 1, Debug.Wrapped (Interfaces.Integer_32 (T.Rx_Time_Us / 100)));
         end if;
         if T.Passed then
            Debug.Set (D, Debug.RX_Timing, 5, R1 (S.Smoothed_Rate_Hz));
         end if;
      end if;
      if Debug.Selected (D, Debug.RC_Smoothing) then
         if T.Refreshed then
            Debug.Set (D, Debug.RC_Smoothing, 0, R1 (S.Current_Rate_Hz));
         end if;
         if T.Counts_Set then
            Debug.Set (D, Debug.RC_Smoothing, 6, Debug.Wrapped (Interfaces.Integer_32 (T.Outliers)));
            Debug.Set (D, Debug.RC_Smoothing, 7, Debug.Wrapped (Interfaces.Integer_32 (T.Valids)));
         end if;
         if T.FF_Filters_Set then
            Debug.Set (D, Debug.RC_Smoothing, 4, R1000 (T.FF_Gain));
         end if;
         if T.Cutoffs_Set then
            Debug.Set (D, Debug.RC_Smoothing, 2, Debug.Wrapped (Interfaces.Integer_32 (S.Setpoint_Cutoff_Hz)));
            Debug.Set (D, Debug.RC_Smoothing, 3, Debug.Wrapped (Interfaces.Integer_32 (S.Throttle_Cutoff_Hz)));
            Debug.Set (D, Debug.RC_Smoothing, 1, R1 (T.Cutoff_Rate_Hz));
         end if;
         if T.Passed then
            Debug.Set (D, Debug.RC_Smoothing, 5, R1 (S.Smoothed_Rate_Hz));
         end if;
      end if;
      if T.Passed and then Debug.Selected (D, Debug.RC_Smoothing_Rate) then
         Debug.Set (D, Debug.RC_Smoothing_Rate, 0, Low_Word (T.Pass_Interval_Us / 10));
         Debug.Set (D, Debug.RC_Smoothing_Rate, 3, Flag (T.Smoothing_Updated));
         Debug.Set (D, Debug.RC_Smoothing_Rate, 2, R1 (S.Smoothed_Rate_Hz));
      end if;
      if T.Passed and then Debug.Selected (D, Debug.RC_Interpolation) then
         for A in Axis loop
            Debug.Set (D, Debug.RC_Interpolation, Axis'Pos (A), R1 (S.To_Smooth (A)));
         end loop;
         Debug.Set (D, Debug.RC_Interpolation, 3,
                    Debug.Wrapped (Interfaces.Integer_32 (R1 (S.Throttle_To_Smooth)) - 1000));
      end if;
      if T.Passed and then Debug.Selected (D, Debug.Angle_Rate) then
         for A in Axis loop
            Debug.Set (D, Debug.Angle_Rate, Axis'Pos (A), Debug.Truncated (Held (T.Angle_Rate (A))));
         end loop;
      end if;
      if T.Passed and then Debug.Selected (D, Debug.Feedforward) then
         Debug.Set (D, Debug.Feedforward, 6, R001 (T.Yaw_FF_No_Hold));
         Debug.Set (D, Debug.Feedforward, 7, R001 (T.Yaw_Hold));
         Debug.Set (D, Debug.Feedforward, 0, R1 (S.Raw_Setpoint (Debug_Axis)));
         Debug.Set (D, Debug.Feedforward, 1, R001 (S.Prev_Speed (Debug_Axis)));
         Debug.Set (D, Debug.Feedforward, 2, R001 (T.Boost (Debug_Axis)));
         Debug.Set (D, Debug.Feedforward, 3, R10 (S.Prev_Delta_Abs (Debug_Axis)));
         Debug.Set (D, Debug.Feedforward, 4, R100 (T.Jitter (Debug_Axis)));
         Debug.Set (D, Debug.Feedforward, 5, Flag (S.Prev_Duplicate (Debug_Axis)));
      end if;
      if Debug.Selected (D, Debug.Feedforward_Limit) then
         if T.FF_Filters_Set then
            Debug.Set (D, Debug.Feedforward_Limit, 6, R1000 (T.FF_Gain));
            Debug.Set (D, Debug.Feedforward_Limit, 7, R1 (T.FF_Rate_Hz));
         end if;
         if T.Passed then
            Debug.Set (D, Debug.Feedforward_Limit, 0, R100 (T.Jitter (Debug_Axis)));
            Debug.Set (D, Debug.Feedforward_Limit, 1, R1 (S.Max_Rate (Debug_Axis)));
            Debug.Set (D, Debug.Feedforward_Limit, 2, R1 (S.Raw_Setpoint (Debug_Axis)));
            Debug.Set (D, Debug.Feedforward_Limit, 3, R001 (T.FF_Before_Average (Debug_Axis)));
            Debug.Set (D, Debug.Feedforward_Limit, 4, R001 (T.Speed_Unsmoothed (Debug_Axis)));
            Debug.Set (D, Debug.Feedforward_Limit, 5, R001 (S.Prev_Speed (Debug_Axis)));
         end if;
      end if;
   end Record_Pass;

end Adaflight.RC_Debug;
