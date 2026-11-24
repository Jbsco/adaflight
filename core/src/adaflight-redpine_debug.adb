with Interfaces;

package body Adaflight.Redpine_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   procedure Record_Update (D : in out Debug.State; S : Redpine.State) is
      T : Redpine.Debug_Taps renames S.Taps;
   begin
      if T.Packet_Set then
         Debug.Set (D, Debug.RX_Redpine_SPI, 0, Debug.Wrapped (T.Loop_Time_Us));
         Debug.Set (D, Debug.RX_Redpine_SPI, 1, Debug.Integer_16 (T.RSSI_Byte));
      end if;
      if T.Missing_Set then
         Debug.Set (D, Debug.RX_Redpine_SPI, 2, Debug.Wrapped (Interfaces.Integer_32 (T.Missing mod 65_536)));
      end if;
      Debug.Set (D, Debug.RX_Redpine_SPI, 3, Redpine.Protocol_State'Pos (S.Protocol));
      Debug.Set (D, Debug.RX_Redpine_SPI, 4, Debug.Integer_16 (S.Offset_Min));
      Debug.Set (D, Debug.RX_Redpine_SPI, 5, Debug.Integer_16 (S.Offset_Max));
   end Record_Update;

end Adaflight.Redpine_Debug;
