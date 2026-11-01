with Interfaces;

package body Adaflight.Sensor_Debug with SPARK_Mode is

   --  A value held within the conversion bound then rounded, as the
   --  reference stores lrintf results.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));
   function R1 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (X)));
   function R100 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 100.0)));

   procedure Record_Baro (D : in out Debug.State; T : Barometer_Task.State; B : Barometer.State) is
   begin
      if Debug.Selected (D, Debug.Baro) then
         if T.Taps.Stepped then
            Debug.Set (D, Debug.Baro, 0, Debug.Wrapped (Barometer_Task.Phase'Pos (T.Taps.Entry_Phase)));
         end if;
         if B.Taps.Level_Set then
            Debug.Set (D, Debug.Baro, 4, R1 (B.Taps.Level_Cm));
         end if;
         if B.Taps.Sampled then
            Debug.Set (D, Debug.Baro, 1, R1 (Float (B.Taps.Pressure) / 100.0));
            Debug.Set (D, Debug.Baro, 2, Debug.Wrapped (Interfaces.Integer_32 (B.Taps.Temperature)));
            Debug.Set (D, Debug.Baro, 3, R1 (B.Taps.Altitude_Cm));
         end if;
      end if;
   end Record_Baro;

   procedure Record_Pitot (D : in out Debug.State; S : Pitot.Sensor) is
   begin
      if S.Taps.Updated and then Debug.Selected (D, Debug.Pitot) then
         Debug.Set (D, Debug.Pitot, 0, R1 (S.Taps.Airspeed));
         Debug.Set (D, Debug.Pitot, 1, R1 (S.Taps.Diff_Pressure));
         Debug.Set (D, Debug.Pitot, 2, R1 (S.Taps.Filtered));
         Debug.Set (D, Debug.Pitot, 3, R1 (Held (S.Taps.Temperature) - 273.15));
      end if;
   end Record_Pitot;

   procedure Record_Attitude (D : in out Debug.State; S : Attitude.State) is
   begin
      if S.Taps.Course_Err_Set and then Debug.Selected (D, Debug.Attitude) then
         Debug.Set (D, Debug.Attitude, 3, R100 (S.Taps.Course_Error));
         Debug.Set (D, Debug.Attitude, 1, R100 (S.Taps.Confidence));
         Debug.Set (D, Debug.Attitude, 4, (if S.Taps.Usable then 0 else 1));
      end if;
   end Record_Attitude;

end Adaflight.Sensor_Debug;
