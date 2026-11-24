with Interfaces;

package body Adaflight.FrSky_SPI_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   function Low_Half (V : Interfaces.Unsigned_32) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (V mod 65_536)));

   procedure Record_Update (D : in out Debug.State; S : FrSky_SPI.State) is
      T : FrSky_SPI.Debug_Taps renames S.Taps;
   begin
      if T.Error_Count_Set then
         Debug.Set (D, Debug.RX_FrSky_SPI, 0, Debug.Wrapped (Interfaces.Integer_32 (S.Data_Errors)));
      end if;
      if T.Missing_Set then
         Debug.Set (D, Debug.RX_FrSky_SPI, 1, Low_Half (T.Missing));
      end if;
      if T.Bad_Frame_Set then
         Debug.Set (D, Debug.RX_FrSky_SPI, 2, Low_Half (S.Packet_Errors));
      end if;
   end Record_Update;

end Adaflight.FrSky_SPI_Debug;
