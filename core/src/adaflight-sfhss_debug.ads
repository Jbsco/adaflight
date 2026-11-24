--  The SFHSS receiver's debug values as the reference records them: the
--  protocol state, the count of hops that missed a half, and the bind
--  tuning's upper and lower offsets. Every change of these fields writes its
--  value, so each value is the field as it stands.
with Adaflight.Debug;
with Adaflight.SFHSS;

package Adaflight.SFHSS_Debug with SPARK_Mode is

   procedure Record_Update (D : in out Debug.State; S : SFHSS.State)
     with Global => null;

end Adaflight.SFHSS_Debug;
