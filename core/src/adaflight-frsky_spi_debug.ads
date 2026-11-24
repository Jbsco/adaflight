--  The FrSky SPI receiver's debug values as the reference records them: the
--  D8 data error count, the X missing packet count and the X bad frame
--  count. Each value stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.FrSky_SPI;

package Adaflight.FrSky_SPI_Debug with SPARK_Mode is

   procedure Record_Update (D : in out Debug.State; S : FrSky_SPI.State)
     with Global => null;

end Adaflight.FrSky_SPI_Debug;
