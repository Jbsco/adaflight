--  The GPS link's debug values as the reference records them: the dynamic
--  model sent, the navigation interval, the baud detection progress or the
--  navigation message age, the baud rate or that age, the state with its
--  position, the task's execution time, the configuration acknowledgement
--  state and the bytes waiting, and the solution's satellite count and
--  dilutions. Each site's values come from the link's taps, so a value stays
--  as its site last wrote it.
with Adaflight.Debug;
with Adaflight.GPS_Frames;
with Adaflight.GPS_Link;

package Adaflight.GPS_Debug with SPARK_Mode is

   --  After one link update, with the time the update took.
   procedure Record_Update
     (D : in out Debug.State; L : GPS_Link.Link; R : GPS_Frames.Receiver; Execute_Time_Us : Natural)
     with Global => null;

end Adaflight.GPS_Debug;
