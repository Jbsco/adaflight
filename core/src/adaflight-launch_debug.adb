with Interfaces;

package body Adaflight.Launch_Debug with SPARK_Mode is

   procedure Record_Pass (D : in out Debug.State; L : Wing_Launch.Launch) is
      use type Interfaces.Integer_32;
   begin
      if Debug.Selected (D, Debug.Launch) then
         if L.Taps.Detect_Called then
            declare
               Flags : constant Interfaces.Integer_32 :=
                 (if L.Taps.Bungee then 1 else 0) + (if L.Taps.Swing then 2 else 0) + (if L.Taps.Forward then 4 else 0);
            begin
               Debug.Set (D, Debug.Launch, 3, Debug.Rounded (L.Taps.Ax_G * 100.0));
               Debug.Set (D, Debug.Launch, 4, Debug.Rounded (L.Taps.Swing_Cms));
               Debug.Set (D, Debug.Launch, 6, Debug.Wrapped (Flags));
            end;
         end if;
         Debug.Set (D, Debug.Launch, 0, Debug.Wrapped (Wing_Launch.State'Pos (L.Current)));
         Debug.Set (D, Debug.Launch, 1, Debug.Rounded (L.Pitch_Target_Deg * 10.0));
         Debug.Set (D, Debug.Launch, 2, Debug.Rounded (L.Throttle * 1000.0));
         Debug.Set (D, Debug.Launch, 5, Debug.Rounded (L.Handover * 1000.0));
         Debug.Set (D, Debug.Launch, 7, Debug.Wrapped (Wing_Launch.Exit_Reason'Pos (L.Why)));
      end if;
   end Record_Pass;

end Adaflight.Launch_Debug;
