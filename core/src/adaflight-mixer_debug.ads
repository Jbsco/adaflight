--  The mixer's debug values as the reference records them: the dynamic
--  idle's terms and slowest motor frequency, the sag compensation's battery
--  goodness and range attenuation, the RPM limiter's average, offset, scale,
--  throttle, error and terms, and the EZ landing's factor, throttle, limits
--  and ratio. Each value comes from the mixer's taps, so it stays as its site
--  last wrote it.
with Adaflight.Debug;
with Adaflight.Mixer;

package Adaflight.Mixer_Debug with SPARK_Mode is

   --  After one mixer loop.
   procedure Record_Update (D : in out Debug.State; S : Mixer.State)
     with Global => null;

end Adaflight.Mixer_Debug;
