package body Adaflight.IMU_Debug with SPARK_Mode is

   --  A value held within the conversion bound, before and after a scale.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   function Component (V : Vectors.Vector3; A : Vectors.Coordinate) return Float is
     (case A is when Vectors.X => V.X, when Vectors.Y => V.Y, when Vectors.Z => V.Z);

   procedure Record_Acc (D : in out Debug.State; S : Accelerometer.State; Debug_Axis : Vectors.Coordinate) is
   begin
      if Debug.Selected (D, Debug.Accelerometer) and then S.Taps.Updated then
         Debug.Set (D, Debug.Accelerometer, 0, Debug.Rounded (Held (Component (S.Taps.Pre_Filter, Debug_Axis))));
         Debug.Set (D, Debug.Accelerometer, 1, Debug.Rounded (Held (Component (S.Acc, Debug_Axis))));
         Debug.Set (D, Debug.Accelerometer, 3,
                    Debug.Rounded (Held (Held (Component (S.Jerk, Debug_Axis)) * 1.0e-2)));
         Debug.Set (D, Debug.Accelerometer, 2, Debug.Rounded (Held (Held (S.Magnitude) * 1.0e3)));
         Debug.Set (D, Debug.Accelerometer, 4, Debug.Rounded (Held (Held (S.Jerk_Magnitude) * 1.0e3)));
      end if;
   end Record_Acc;

end Adaflight.IMU_Debug;
