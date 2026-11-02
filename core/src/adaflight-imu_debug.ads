--  The accelerometer's debug values as the reference records them: on the
--  debug axis its trimmed sample before and after the filter and its jerk,
--  and the acceleration and jerk magnitudes. Each value comes from the
--  accelerometer's state and taps, so it stays as its site last wrote it.
with Adaflight.Accelerometer;
with Adaflight.Debug;
with Adaflight.Vectors;

package Adaflight.IMU_Debug with SPARK_Mode is

   --  After one accelerometer update, with the debug axis.
   procedure Record_Acc (D : in out Debug.State; S : Accelerometer.State; Debug_Axis : Vectors.Coordinate)
     with Global => null;

end Adaflight.IMU_Debug;
