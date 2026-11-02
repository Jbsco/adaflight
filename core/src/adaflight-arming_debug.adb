with Interfaces;

package body Adaflight.Arming_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   function Flag (B : Boolean) return Debug.Integer_16 is (if B then 1 else 0);

   procedure Record_Runaway_Rx (D : in out Debug.State; S : Arming.State) is
   begin
      Debug.Set (D, Debug.Runaway_Takeoff, 2, Flag (S.Runaway_Taps.Deactivating));
      Debug.Set (D, Debug.Runaway_Takeoff, 3,
                 Debug.Wrapped (Interfaces.Integer_32 (S.Runaway_Taps.Deactivate_Ms and 16#FFFF#)));
   end Record_Runaway_Rx;

   procedure Record_Runaway_Loop (D : in out Debug.State; S : Arming.State) is
   begin
      Debug.Set (D, Debug.Runaway_Takeoff, 0, Flag (S.Runaway_Taps.Enabled));
      Debug.Set (D, Debug.Runaway_Takeoff, 1, Flag (S.Runaway_Taps.Activating));
   end Record_Runaway_Loop;

end Adaflight.Arming_Debug;
