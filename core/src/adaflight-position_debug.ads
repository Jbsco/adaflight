--  The position estimator's debug values as the reference records them: the
--  earth frame acceleration, the barometer and GPS measurements as they fed,
--  the estimated position, velocity and acceleration on the debug axis and
--  the east and north velocities, the vertical estimate, and the displayed
--  altitude. Each site's values come from the estimator's taps, so a value
--  stays as its site last wrote it. The debug axis selects north for pitch
--  and east otherwise, as the reference maps it.
with Adaflight.Axes;
with Adaflight.Debug;
with Adaflight.Position_Estimator;

package Adaflight.Position_Debug with SPARK_Mode is

   --  After one estimator update, with the gyro configuration's debug axis.
   procedure Record_Update (D : in out Debug.State; S : Position_Estimator.State; Debug_Axis : Axes.Axis)
     with Global => null;

end Adaflight.Position_Debug;
