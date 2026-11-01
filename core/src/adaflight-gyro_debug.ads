--  The gyro path's debug values as the reference records them: the raw
--  source's counts and the filtered rates on every axis, the debug axis's
--  rates through the stages and around the dynamic notches, the loop's load,
--  and a calibration cycle's deviations and cycles left.
with Adaflight.Axes;
with Adaflight.Debug;
with Adaflight.Gyro_Filters;

package Adaflight.Gyro_Debug with SPARK_Mode is

   --  After one filter loop, with the debug axis the gyro configuration names
   --  and the scheduler's average load percent.
   procedure Record_Filter
     (D : in out Debug.State; S : Gyro_Filters.State; Debug_Axis : Axes.Axis; Load_Percent : Natural)
     with Pre => Load_Percent <= 100;

   --  After one accumulation: for each sensor whose calibration cycle ran, its
   --  deviations on its final cycle, then its cycles left unless the cycle
   --  failed the movement check.
   procedure Record_Calibration (D : in out Debug.State; S : Gyro_Filters.State);

end Adaflight.Gyro_Debug;
