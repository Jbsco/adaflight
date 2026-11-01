--  The compass task's debug values as the reference records them: under the
--  calibration mode the aligned field, its length, the estimated bias and
--  the estimator's forgetting factor while calibrating; under the task rate
--  mode the task interval, the bus and read checks, the task rate, the data
--  rate and interval, and the execution time its caller passes. Each value
--  comes from the compass's taps, so it stays as its site last wrote it.
with Interfaces;
with Adaflight.Compass;
with Adaflight.Debug;

package Adaflight.Compass_Debug with SPARK_Mode is

   --  After one read cycle, with the time the cycle took. The task rate
   --  mode's previous sample time moves only while that mode is selected,
   --  as upstream keeps it inside the mode's block, so the taps change.
   procedure Record_Cycle (D : in out Debug.State; S : in out Compass.State; Execute_Us : Interfaces.Unsigned_32)
     with Global => null;

end Adaflight.Compass_Debug;
