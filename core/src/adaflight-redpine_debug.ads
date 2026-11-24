--  The Redpine receiver's debug values as the reference records them: the
--  loop time and RSSI byte of the last packet taken, the missed packet
--  count, the protocol state after each data call, and the bind tuning's
--  lower and upper offsets. Each value stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.Redpine;

package Adaflight.Redpine_Debug with SPARK_Mode is

   --  After a data call.
   procedure Record_Update (D : in out Debug.State; S : Redpine.State)
     with Global => null;

end Adaflight.Redpine_Debug;
