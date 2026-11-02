with Adaflight.Maths;

package body Adaflight.Optical_Flow_Debug with SPARK_Mode is

   --  A value held within the conversion bound, before and after a scale.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   --  A rate in thousandths, rounded as the reference stores it.
   function Milli (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 1.0e3)));

   procedure Record_Process (D : in out Debug.State; S : Optical_Flow.Sensor) is
   begin
      if Debug.Selected (D, Debug.Optical_Flow) and then S.Taps.Processed then
         Debug.Set (D, Debug.Optical_Flow, 0, Milli (S.Taps.Rotated_X));
         Debug.Set (D, Debug.Optical_Flow, 1, Milli (S.Taps.Rotated_Y));
         Debug.Set (D, Debug.Optical_Flow, 2, Milli (S.Taps.Gyro_X * Adaflight.Maths.Rad_Per_Degree));
         Debug.Set (D, Debug.Optical_Flow, 3, Milli (S.Taps.Gyro_Y * Adaflight.Maths.Rad_Per_Degree));
         Debug.Set (D, Debug.Optical_Flow, 4, (if S.X_Valid then Milli (S.Taps.Compensated_X) else 0));
         Debug.Set (D, Debug.Optical_Flow, 5, (if S.Y_Valid then Milli (S.Taps.Compensated_Y) else 0));
         Debug.Set (D, Debug.Optical_Flow, 6, Milli (S.Processed_Flow.X));
         Debug.Set (D, Debug.Optical_Flow, 7, Milli (S.Processed_Flow.Y));
      end if;
   end Record_Process;

end Adaflight.Optical_Flow_Debug;
