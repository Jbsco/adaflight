--  The ESC sensor debug values as the reference records them: under the
--  sensor mode the motor a pass requested, the replies timed out and the
--  checksums failed, counted only while that mode is selected as upstream
--  increments them inside its write, and the combined reading's data age;
--  under the rate and temperature modes one slot per motor among the first
--  four from each decoded frame, the rate in tens of revolutions per minute
--  from the signed count read as unsigned. Each value comes from the
--  sensor's taps and state, so it stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.DShot;
with Adaflight.ESC_Sensor;

package Adaflight.ESC_Debug with SPARK_Mode is

   --  After one polling pass, with whether it requested a frame and the
   --  factor from the electrical rate to revolutions per second.
   procedure Record_Process (D : in out Debug.State; E : in out ESC_Sensor.Sensor; Requested : Boolean;
                             Erpm_To_Hz : DShot.Rate_Factor)
     with Global => null;

   --  After one combined reading.
   procedure Record_Combined (D : in out Debug.State; E : ESC_Sensor.Sensor)
     with Global => null;

end Adaflight.ESC_Debug;
