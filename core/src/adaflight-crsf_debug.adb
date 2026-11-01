package body Adaflight.CRSF_Debug with SPARK_Mode is

   --  A frame byte or a signed byte as the reference's store into the debug
   --  array keeps it.
   function Value (I : Integer) return Debug.Integer_16 is (Debug.Integer_16 (I))
     with Pre => I in -128 .. 255;

   procedure Record_Statistics (D : in out Debug.State; S : CRSF.State) is
      T : CRSF.Debug_Taps renames S.Taps;
   begin
      if T.Stats_Set then
         if Debug.Selected (D, Debug.CRSF_Link_Statistics_Uplink) then
            Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 0, Value (T.Uplink_RSSI_1));
            Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 1, Value (T.Uplink_RSSI_2));
            Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 2, Value (T.Uplink_Quality));
            Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 3, Value (T.RF_Mode));
         end if;
         if Debug.Selected (D, Debug.CRSF_Link_Statistics_Pwr) then
            Debug.Set (D, Debug.CRSF_Link_Statistics_Pwr, 0, Value (T.Active_Antenna));
            Debug.Set (D, Debug.CRSF_Link_Statistics_Pwr, 1, Value (T.Uplink_SNR));
            Debug.Set (D, Debug.CRSF_Link_Statistics_Pwr, 2, Value (T.Uplink_Power));
         end if;
         if Debug.Selected (D, Debug.CRSF_Link_Statistics_Down) then
            Debug.Set (D, Debug.CRSF_Link_Statistics_Down, 0, Value (T.Downlink_RSSI));
            Debug.Set (D, Debug.CRSF_Link_Statistics_Down, 1, Value (T.Downlink_Quality));
            Debug.Set (D, Debug.CRSF_Link_Statistics_Down, 2, Value (T.Downlink_SNR));
         end if;
      end if;
      if T.Tx_Set and then Debug.Selected (D, Debug.CRSF_Link_Statistics_Uplink) then
         Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 4, Value (T.Tx_RSSI));
         Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 5, Value (T.Tx_SNR));
         Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 6, Value (T.Tx_Quality));
         Debug.Set (D, Debug.CRSF_Link_Statistics_Uplink, 7, Value (T.Tx_Percent));
      end if;
   end Record_Statistics;

end Adaflight.CRSF_Debug;
