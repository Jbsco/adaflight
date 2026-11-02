with Interfaces;

package body Adaflight.Gimbal_Debug with SPARK_Mode is

   procedure Record_Set (D : in out Debug.State; T : Gimbal_Control.State) is
   begin
      if T.Taps.Set_Called and then Debug.Selected (D, Debug.Gimbal) then
         Debug.Set (D, Debug.Gimbal, 0, Debug.Wrapped (Interfaces.Integer_32 (T.Taps.Head_Roll)));
         Debug.Set (D, Debug.Gimbal, 1, Debug.Wrapped (Interfaces.Integer_32 (T.Taps.Head_Pitch)));
         Debug.Set (D, Debug.Gimbal, 2, Debug.Wrapped (Interfaces.Integer_32 (T.Taps.Head_Yaw)));
         Debug.Set (D, Debug.Gimbal, 3, Debug.Wrapped (Interfaces.Integer_32 (T.Taps.Roll)));
         Debug.Set (D, Debug.Gimbal, 4, Debug.Wrapped (Interfaces.Integer_32 (T.Taps.Pitch)));
         Debug.Set (D, Debug.Gimbal, 5, Debug.Wrapped (Interfaces.Integer_32 (T.Taps.Yaw)));
      end if;
   end Record_Set;

end Adaflight.Gimbal_Debug;
