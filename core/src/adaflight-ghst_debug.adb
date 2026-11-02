with Interfaces;

package body Adaflight.GHST_Debug with SPARK_Mode is
   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   function Count (V : Interfaces.Unsigned_16) return Debug.Integer_16 is (Debug.Wrapped (Interfaces.Integer_32 (V)));

   procedure Record_Frame_Status (D : in out Debug.State; S : in out GHST.State) is
   begin
      if Debug.Selected (D, Debug.GHST) and then S.Taps.CRC_Failed then
         S.CRC_Errors := S.CRC_Errors + 1;
         Debug.Set (D, Debug.GHST, 0, Count (S.CRC_Errors));
      end if;
   end Record_Frame_Status;

   procedure Record_Process (D : in out Debug.State; S : in out GHST.State) is
   begin
      if Debug.Selected (D, Debug.GHST) then
         if S.Taps.Statistics then
            Debug.Set (D, Debug.GHST, 2, -Debug.Integer_16 (S.Taps.RSSI));
            Debug.Set (D, Debug.GHST, 3, Debug.Integer_16 (S.Taps.LQ));
         end if;
         if S.Taps.Unknown then
            S.Unknown_Frames := S.Unknown_Frames + 1;
            Debug.Set (D, Debug.GHST, 1, Count (S.Unknown_Frames));
         end if;
      end if;
      if Debug.Selected (D, Debug.GHST_MSP) and then S.Taps.MSP_Frame then
         S.MSP_Requests := S.MSP_Requests + 1;
         Debug.Set (D, Debug.GHST_MSP, 0, Debug.Integer_16 (S.MSP_Requests));
      end if;
   end Record_Process;

end Adaflight.GHST_Debug;
