--  The runaway takeoff debug values as the reference records them: after
--  each PID loop pass whether the check is enabled and whether its
--  activation delay runs, and after each receiver pass whether the
--  deactivation delay runs and the stable time accumulated, in
--  milliseconds. Each value comes from the arming state's taps, so it stays
--  as its site last wrote it.
with Adaflight.Arming;
with Adaflight.Debug;

package Adaflight.Arming_Debug with SPARK_Mode is

   --  After a receiver pass.
   procedure Record_Runaway_Rx (D : in out Debug.State; S : Arming.State)
     with Global => null;

   --  After a PID loop pass.
   procedure Record_Runaway_Loop (D : in out Debug.State; S : Arming.State)
     with Global => null;

end Adaflight.Arming_Debug;
