with Interfaces;

package body Adaflight.Serial_Receiver_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   --  An unsigned interval as upstream stores it in a sixteen-bit value.
   function Interval (V : Interfaces.Unsigned_32) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (V and 16#FFFF#)));

   procedure Record_SBUS (D : in out Debug.State; S : SBUS.State) is
   begin
      if Debug.Selected (D, Debug.SBUS) then
         Debug.Set (D, Debug.SBUS, 2, Debug.Wrapped (S.Taps.Frame_Time));
         if S.Taps.Status_Read then
            Debug.Set (D, Debug.SBUS, 0, Debug.Integer_16 (S.Taps.Flags));
         end if;
      end if;
   end Record_SBUS;

   procedure Record_FPORT (D : in out Debug.State; S : FPORT.State) is
   begin
      if Debug.Selected (D, Debug.FPORT) then
         Debug.Set (D, Debug.FPORT, 0, Interval (S.Taps.Frame_Interval));
         Debug.Set (D, Debug.FPORT, 1, Debug.Wrapped (Interfaces.Integer_32 (S.Frame_Errors)));
         Debug.Set (D, Debug.FPORT, 2, Debug.Integer_16 (S.Taps.Last_Error));
         Debug.Set (D, Debug.FPORT, 3, Interval (S.Taps.Telemetry_Interval));
      end if;
   end Record_FPORT;

end Adaflight.Serial_Receiver_Debug;
