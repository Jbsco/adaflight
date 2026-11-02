--  The Ghost receiver's debug values as the reference records them. Under
--  the GHST mode: CRC failures and unknown frame types, each counted only
--  while that mode is selected as upstream counts inside its debug write,
--  and each link statistics frame's RSSI in dBm and link quality. Under the
--  GHST MSP mode: the MSP requests received, counted the same way.
with Adaflight.Debug;
with Adaflight.GHST;

package Adaflight.GHST_Debug with SPARK_Mode is

   --  After a frame status.
   procedure Record_Frame_Status (D : in out Debug.State; S : in out GHST.State)
     with Global => null;

   --  After a frame processing.
   procedure Record_Process (D : in out Debug.State; S : in out GHST.State)
     with Global => null;

end Adaflight.GHST_Debug;
