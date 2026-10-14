--  Simplified tuning: the PID gains of a profile and the D term and gyro
--  lowpass filters recomputed from the defaults through the sliders.
with Adaflight.PID_Profile;
with Adaflight.Gyro_Filters;

package Adaflight.Simplified_Tuning with SPARK_Mode is

   --  Every gain and D max of the axes the mode covers, from the defaults
   --  through the master multiplier and the slider of each term; nothing
   --  while the mode is off.
   procedure Apply_PIDs (P : in out PID_Profile.Profile);

   --  The D term lowpass filters in use from their defaults through the
   --  filter slider: the dynamic range when it is on, then each static
   --  cutoff that is on; nothing while the slider is off.
   procedure Apply_Dterm_Filters (P : in out PID_Profile.Profile);

   --  The gyro lowpass filters the same way through the gyro filter slider.
   procedure Apply_Gyro_Filters (G : in out Gyro_Filters.Settings);

   --  The gains, the D term filters and the gyro filters, in that order.
   procedure Apply (P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings);

   --  Every slider turned off.
   procedure Disable (P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings);

end Adaflight.Simplified_Tuning;
