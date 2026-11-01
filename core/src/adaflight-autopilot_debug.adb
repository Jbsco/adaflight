with Interfaces;

package body Adaflight.Autopilot_Debug with SPARK_Mode is
   use type Axes.Axis;

   --  A value held within the conversion bound then rounded, as the
   --  reference stores lrintf results.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));
   function R1 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (X)));
   function R10 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 10.0)));

   procedure Record_Altitude (D : in out Debug.State; S : Altitude_Control.State) is
   begin
      if S.Taps.Controlled and then Debug.Selected (D, Debug.Autopilot_Altitude) then
         Debug.Set (D, Debug.Autopilot_Altitude, 0, R1 (S.Taps.Throttle));
         Debug.Set (D, Debug.Autopilot_Altitude, 1, R1 (S.Taps.Target_Cm));
         Debug.Set (D, Debug.Autopilot_Altitude, 2, R1 (S.Taps.Current_Cm));
         Debug.Set (D, Debug.Autopilot_Altitude, 3, R1 (S.Taps.P));
         Debug.Set (D, Debug.Autopilot_Altitude, 4, R1 (S.Taps.I));
         Debug.Set (D, Debug.Autopilot_Altitude, 5, R1 (S.Taps.D));
         Debug.Set (D, Debug.Autopilot_Altitude, 6, R1 (S.Taps.A));
         Debug.Set (D, Debug.Autopilot_Altitude, 7, R1 (S.Taps.F));
      end if;
   end Record_Altitude;

   procedure Record_Heading (D : in out Debug.State; S : Position_Control.State) is
   begin
      if Debug.Selected (D, Debug.Autopilot_Heading) then
         Debug.Set (D, Debug.Autopilot_Heading, 7, Debug.Wrapped (Interfaces.Integer_32 (S.Yaw_Disable_Reason)));
         if S.Taps.Yaw_Ran then
            Debug.Set (D, Debug.Autopilot_Heading, 0, R10 (S.Taps.Heading_Deg));
            Debug.Set (D, Debug.Autopilot_Heading, 1, R10 (S.Taps.Desired_Deg));
            Debug.Set (D, Debug.Autopilot_Heading, 2, R10 (S.Taps.Error_Deg));
            Debug.Set (D, Debug.Autopilot_Heading, 3, R10 (S.Taps.Yaw_Rate));
            Debug.Set (D, Debug.Autopilot_Heading, 4, R10 (S.Taps.Yaw_P));
         end if;
      end if;
   end Record_Heading;

   procedure Record_Hold (D : in out Debug.State; H : Position_Hold.State) is
   begin
      if H.Taps.Status_Set and then Debug.Selected (D, Debug.Autopilot_Heading) then
         Debug.Set (D, Debug.Autopilot_Heading, 6, Debug.Wrapped (Interfaces.Integer_32 (H.Taps.Sensor_Status)));
      end if;
   end Record_Hold;

   procedure Record_Position (D : in out Debug.State; S : Position_Control.State; Debug_Axis : Axes.Axis) is
      T     : Position_Control.Debug_Taps renames S.Taps;
      North : constant Boolean := Debug_Axis = Axes.Pitch;
      Flags : constant Natural := (if T.Anchor_Off then 10 else 0) + (if T.Buildup_Clamped then 1 else 0);
      function Sel (V : Position_Control.Vector2) return Float is (if North then V.Y else V.X);
   begin
      if T.Terms_Set then
         if Debug.Selected (D, Debug.Autopilot_PID) then
            Debug.Set (D, Debug.Autopilot_PID, 0, R1 (Sel (T.Velocity)));
            Debug.Set (D, Debug.Autopilot_PID, 1, R1 (Sel (T.Distance_Error)));
            Debug.Set (D, Debug.Autopilot_PID, 2, R10 (Sel (T.P)));
            Debug.Set (D, Debug.Autopilot_PID, 3, R10 (Sel (T.I)));
            Debug.Set (D, Debug.Autopilot_PID, 4, R10 (Sel (T.D)));
            Debug.Set (D, Debug.Autopilot_PID, 5, R10 (Sel (T.A)));
            Debug.Set (D, Debug.Autopilot_PID, 6, R10 (Sel (T.F)));
         end if;
         if Debug.Selected (D, Debug.Autopilot_Stop) then
            Debug.Set (D, Debug.Autopilot_Stop, 0, R1 (T.Velocity_Error.X));
            Debug.Set (D, Debug.Autopilot_Stop, 1, R1 (T.Velocity_Error.Y));
            Debug.Set (D, Debug.Autopilot_Stop, 2, R10 (T.Sum.X));
            Debug.Set (D, Debug.Autopilot_Stop, 3, R10 (T.Sum.Y));
            Debug.Set (D, Debug.Autopilot_Stop, 4, R10 (T.Angle_Roll));
            Debug.Set (D, Debug.Autopilot_Stop, 5, R10 (T.Angle_Pitch));
         end if;
         if Debug.Selected (D, Debug.Position_Nav) then
            Debug.Set (D, Debug.Position_Nav, 0, R1 (Sel (T.Target_Velocity)));
            Debug.Set (D, Debug.Position_Nav, 1, R1 (Sel (T.Velocity)));
            Debug.Set (D, Debug.Position_Nav, 2, R1 (Sel (T.Velocity_Error)));
            Debug.Set (D, Debug.Position_Nav, 3, R10 (Sel (T.P)));
            Debug.Set (D, Debug.Position_Nav, 4, R10 (Sel (T.I)));
            Debug.Set (D, Debug.Position_Nav, 5, R10 (Sel (T.D)));
            Debug.Set (D, Debug.Position_Nav, 6, R10 (Sel (T.A)));
            Debug.Set (D, Debug.Position_Nav, 7, Debug.Wrapped (Interfaces.Integer_32 (Flags)));
         end if;
         if Debug.Selected (D, Debug.Attitude) then
            Debug.Set (D, Debug.Attitude, 2, R1 (T.Speed));
            Debug.Set (D, Debug.Attitude, 6, R1 (T.Target_Speed));
         end if;
      end if;
      if T.Status_Set then
         Debug.Set (D, Debug.Autopilot_PID, 7, Debug.Wrapped (Interfaces.Integer_32 (T.Status)));
         Debug.Set (D, Debug.Autopilot_Stop, 6, Debug.Wrapped (Interfaces.Integer_32 (T.Status)));
         Debug.Set (D, Debug.Autopilot_Stop, 7, Debug.Wrapped (Interfaces.Integer_32 (T.Status)));
      end if;
      if T.Yaw_Ran and then Debug.Selected (D, Debug.Attitude) then
         Debug.Set (D, Debug.Attitude, 0, R1 (T.Heading_Deg));
      end if;
   end Record_Position;

end Adaflight.Autopilot_Debug;
