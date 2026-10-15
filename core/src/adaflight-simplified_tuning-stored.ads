--  Simplified tuning over the stored configuration: a PID profile's gains and
--  D term lowpass filters and the gyro lowpass filters recomputed from the
--  defaults through the stored sliders.
with Adaflight.Config_Groups;

package Adaflight.Simplified_Tuning.Stored with SPARK_Mode is

   --  The gains and D max of the axes the stored mode covers, any mode past
   --  roll and pitch covering every axis; then the D term lowpass filters in
   --  use and the gyro lowpass filters in use, each through its slider when
   --  the slider is on.
   procedure Apply (P : in out Config_Groups.Pid_Profile_Record; G : in out Config_Groups.Gyro_Config_Record);

   --  Every slider turned off.
   procedure Disable (P : in out Config_Groups.Pid_Profile_Record; G : in out Config_Groups.Gyro_Config_Record);

end Adaflight.Simplified_Tuning.Stored;
