--  The Spektrum SPI receiver's debug values as the reference records them:
--  the missed packet count, the receive error flag at each packet check, and
--  whether a telemetry packet was still unsent at its timeout. Each value
--  stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.Spektrum_SPI;

package Adaflight.Spektrum_SPI_Debug with SPARK_Mode is

   --  Whether the receiver's debug mode is selected, for the call's inputs.
   function Selected (D : Debug.State) return Boolean is (Debug.Selected (D, Debug.RX_Spektrum_SPI));

   --  After a data call.
   procedure Record_Update (D : in out Debug.State; S : Spektrum_SPI.State)
     with Global => null;

end Adaflight.Spektrum_SPI_Debug;
