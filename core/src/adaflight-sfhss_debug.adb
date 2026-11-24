with Interfaces;

package body Adaflight.SFHSS_Debug with SPARK_Mode is

   function Code (P : SFHSS.Protocol_State) return Debug.Integer_16 is
     (case P is
         when SFHSS.Init => 0, when SFHSS.Hunt => 1, when SFHSS.Sync => 2, when SFHSS.Bind => 10,
         when SFHSS.Bind_Tuning_1 => 11, when SFHSS.Bind_Tuning_2 => 12, when SFHSS.Bind_Tuning_3 => 13,
         when SFHSS.Bind_Complete => 14);

   procedure Record_Update (D : in out Debug.State; S : SFHSS.State) is
   begin
      Debug.Set (D, Debug.RX_SFHSS_SPI, 0, Code (S.Protocol));
      Debug.Set (D, Debug.RX_SFHSS_SPI, 1, Debug.Wrapped (Interfaces.Integer_32 (S.Missing_Frames)));
      Debug.Set (D, Debug.RX_SFHSS_SPI, 2, Debug.Integer_16 (S.Offset_Max));
      Debug.Set (D, Debug.RX_SFHSS_SPI, 3, Debug.Integer_16 (S.Offset_Min));
   end Record_Update;

end Adaflight.SFHSS_Debug;
