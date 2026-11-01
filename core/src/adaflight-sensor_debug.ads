--  The sensor debug values as the reference records them: the barometer
--  task's phase, pressure, temperature and altitudes, the pitot's airspeed,
--  pressures and temperature, and the attitude's GPS heading confidence,
--  usability and course error. Each site's values come from the units'
--  taps, so a value stays as its site last wrote it.
with Adaflight.Attitude;
with Adaflight.Barometer;
with Adaflight.Barometer_Task;
with Adaflight.Debug;
with Adaflight.Pitot;

package Adaflight.Sensor_Debug with SPARK_Mode is

   --  After one barometer task step.
   procedure Record_Baro (D : in out Debug.State; T : Barometer_Task.State; B : Barometer.State)
     with Global => null;

   --  After one pitot update.
   procedure Record_Pitot (D : in out Debug.State; S : Pitot.Sensor)
     with Global => null;

   --  After one attitude update.
   procedure Record_Attitude (D : in out Debug.State; S : Attitude.State)
     with Global => null;

end Adaflight.Sensor_Debug;
