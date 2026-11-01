package body Adaflight.Position_Debug with SPARK_Mode is
   use type Axes.Axis;

   --  A value held within the conversion bound then rounded, as the
   --  reference stores lrintf results.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));
   function R1 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (X)));

   procedure Record_Update (D : in out Debug.State; S : Position_Estimator.State; Debug_Axis : Axes.Axis) is
      T     : Position_Estimator.Debug_Taps renames S.Taps;
      North : constant Boolean := Debug_Axis = Axes.Pitch;
   begin
      if Debug.Selected (D, Debug.Position_Est) then
         if T.Updated then
            Debug.Set (D, Debug.Position_Est, 5, R1 (if North then T.Accel_North else T.Accel_East));
            Debug.Set (D, Debug.Position_Est, 0, R1 (if North then S.Position_North else S.Position_East));
            Debug.Set (D, Debug.Position_Est, 1, R1 (if North then S.Velocity_North else S.Velocity_East));
            Debug.Set (D, Debug.Position_Est, 2, R1 (if North then S.Acceleration_North else S.Acceleration_East));
         end if;
         if T.GPS_XY_Fed then
            Debug.Set (D, Debug.Position_Est, 6, R1 (T.GPS_R_Pos));
            Debug.Set (D, Debug.Position_Est, 7, R1 (T.GPS_R_Vel));
         end if;
      end if;
      if Debug.Selected (D, Debug.Velocity_Est) then
         if T.GPS_XY_Fed then
            Debug.Set (D, Debug.Velocity_Est, 0, T.GPS_Vel_East);
            Debug.Set (D, Debug.Velocity_Est, 1, T.GPS_Vel_North);
         end if;
         if T.Updated then
            Debug.Set (D, Debug.Velocity_Est, 6, R1 (T.Accel_East));
            Debug.Set (D, Debug.Velocity_Est, 7, R1 (T.Accel_North));
            Debug.Set (D, Debug.Velocity_Est, 4, R1 (S.Velocity_East));
            Debug.Set (D, Debug.Velocity_Est, 5, R1 (S.Velocity_North));
         end if;
      end if;
      if Debug.Selected (D, Debug.Altitude) then
         if T.Baro_Fed then
            Debug.Set (D, Debug.Altitude, 1, R1 (T.Baro_Rel_Cm));
         end if;
         if T.GPS_Alt_Fed then
            Debug.Set (D, Debug.Altitude, 2, R1 (T.GPS_Rel_Alt_Cm));
            Debug.Set (D, Debug.Altitude, 4, R1 (T.GPS_Vel_Up));
         end if;
         if T.Updated then
            Debug.Set (D, Debug.Altitude, 6, R1 (T.Accel_Up));
            Debug.Set (D, Debug.Altitude, 3, R1 (S.Position_Up));
            Debug.Set (D, Debug.Altitude, 5, R1 (S.Velocity_Up));
            Debug.Set (D, Debug.Altitude, 7, R1 (S.Acceleration_Up));
         end if;
      end if;
      if T.Updated and then Debug.Selected (D, Debug.RTH) then
         Debug.Set (D, Debug.RTH, 1, R1 (S.Display_Altitude_Cm));
      end if;
   end Record_Update;

end Adaflight.Position_Debug;
