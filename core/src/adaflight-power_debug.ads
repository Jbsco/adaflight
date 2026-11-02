--  The power sensors' debug values as the reference records them: after a
--  voltage update the unfiltered and displayed voltages, the stability bits
--  and verdicts, the last stable voltage and the voltage state; after an
--  analog current update the sensor's millivolts and centiamps, the latest
--  amperage and the charge drawn; after an internal ADC pass the core
--  temperature, the two raw samples and the reference millivolts. Each
--  value comes from the units' state and taps, so it stays as its site last
--  wrote it.
with Adaflight.Battery;
with Adaflight.Debug;
with Adaflight.Internal_ADC;

package Adaflight.Power_Debug with SPARK_Mode is

   --  After one voltage update, with the settings the update took.
   procedure Record_Battery (D : in out Debug.State; S : Battery.State; C : Battery.Settings)
     with Global => null;

   --  After one current update.
   procedure Record_Current (D : in out Debug.State; S : Battery.State)
     with Global => null;

   --  After one internal ADC pass.
   procedure Record_Internal_ADC (D : in out Debug.State; S : Internal_ADC.Sampler)
     with Global => null;

end Adaflight.Power_Debug;
