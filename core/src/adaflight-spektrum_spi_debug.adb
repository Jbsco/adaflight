package body Adaflight.Spektrum_SPI_Debug with SPARK_Mode is

   procedure Record_Update (D : in out Debug.State; S : Spektrum_SPI.State) is
      T : Spektrum_SPI.Debug_Taps renames S.Taps;
   begin
      if T.Missed_Set then
         Debug.Set (D, Debug.RX_Spektrum_SPI, 0, Debug.Integer_16 (T.Missed));
      end if;
      if T.Error_Set then
         Debug.Set (D, Debug.RX_Spektrum_SPI, 1, Boolean'Pos (T.Error));
      end if;
      if T.Tx_Set then
         Debug.Set (D, Debug.RX_Spektrum_SPI, 2, Boolean'Pos (T.Tx_Pending));
      end if;
   end Record_Update;

end Adaflight.Spektrum_SPI_Debug;
