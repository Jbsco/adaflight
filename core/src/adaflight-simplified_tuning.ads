--  Simplified tuning: the PID gains of a profile recomputed from the
--  reference defaults through the profile's sliders. The filter sliders come
--  with the configuration phase.
with Adaflight.PID_Profile;

package Adaflight.Simplified_Tuning with SPARK_Mode is

   --  Every gain and D max of the axes the mode covers, from the defaults
   --  through the master multiplier and the slider of each term; nothing
   --  while the mode is off.
   procedure Apply_PIDs (P : in out PID_Profile.Profile);

end Adaflight.Simplified_Tuning;
