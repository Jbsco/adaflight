--  The CRSF receiver's debug values as the reference records them: the
--  link statistics frame's uplink RSSI per antenna, link quality and RF mode,
--  its active antenna, SNR and transmitter power index, and its downlink
--  RSSI, link quality and SNR, and the transmitter statistics frame's RSSI,
--  SNR, link quality and RSSI percentage. Each value comes from the
--  receiver's taps, so it stays as its frame last carried it.
with Adaflight.CRSF;
with Adaflight.Debug;

package Adaflight.CRSF_Debug with SPARK_Mode is

   --  After the receiver's bytes of one pass.
   procedure Record_Statistics (D : in out Debug.State; S : CRSF.State)
     with Global => null;

end Adaflight.CRSF_Debug;
