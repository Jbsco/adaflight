with Interfaces;

package body Adaflight.ExpressLRS_Debug with SPARK_Mode is
   use type Interfaces.Integer_16;

   procedure Record_Update (D : in out Debug.State; R : ExpressLRS_Receiver.Receiver) is
      T : ExpressLRS_Receiver.Debug_Taps renames R.Taps;
   begin
      if T.Lock_Set and then Debug.Selected (D, Debug.RX_ExpressLRS_Phaselock) then
         Debug.Set (D, Debug.RX_ExpressLRS_Phaselock, 2, Debug.Wrapped (T.Frequency_Offset));
         Debug.Set (D, Debug.RX_ExpressLRS_Phaselock, 3, Debug.Wrapped (T.Phase_Shift_Us));
         Debug.Set (D, Debug.RX_ExpressLRS_Phaselock, 0, Debug.Wrapped (T.Raw_Offset_Us));
         Debug.Set (D, Debug.RX_ExpressLRS_Phaselock, 1, Debug.Wrapped (T.Offset_Us));
      end if;
      if T.Link_Set and then Debug.Selected (D, Debug.RX_ExpressLRS_SPI) then
         Debug.Set (D, Debug.RX_ExpressLRS_SPI, 0, Debug.Wrapped (Interfaces.Integer_32 (T.Lost_Connections)));
         Debug.Set (D, Debug.RX_ExpressLRS_SPI, 1, Debug.Integer_16 (T.RSSI_Filtered));
         Debug.Set (D, Debug.RX_ExpressLRS_SPI, 2, Debug.Integer_16 (T.SNR) / 4);
         Debug.Set (D, Debug.RX_ExpressLRS_SPI, 3, Debug.Integer_16 (T.Uplink_LQ));
      end if;
   end Record_Update;

end Adaflight.ExpressLRS_Debug;
