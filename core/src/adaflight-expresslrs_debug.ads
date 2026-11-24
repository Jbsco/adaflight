--  The ExpressLRS receiver's debug values as the reference records them:
--  the phase lock's raw and filtered offsets with the timer's frequency
--  offset and phase shift after a lock update, and the lost connection
--  count, filtered signal strength, signal to noise in decibels and uplink
--  link quality after the data task. Each value stays as its site last
--  wrote it.
with Adaflight.Debug;
with Adaflight.ExpressLRS_Receiver;

package Adaflight.ExpressLRS_Debug with SPARK_Mode is

   procedure Record_Update (D : in out Debug.State; R : ExpressLRS_Receiver.Receiver)
     with Global => null;

end Adaflight.ExpressLRS_Debug;
