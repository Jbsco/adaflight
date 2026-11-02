--  The wing launch's debug values as the reference records them: after each
--  launch pass, the state, the climb angle target, the launch throttle, the
--  handover and the exit reason; and when the pass looked for a throw, the
--  forward acceleration, the swing speed and the detectors that fired.
with Adaflight.Debug;
with Adaflight.Wing_Launch;

package Adaflight.Launch_Debug with SPARK_Mode is

   --  After a launch pass.
   procedure Record_Pass (D : in out Debug.State; L : Wing_Launch.Launch)
     with Global => null;

end Adaflight.Launch_Debug;
