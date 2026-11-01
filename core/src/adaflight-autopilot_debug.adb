with Interfaces;

package body Adaflight.Autopilot_Debug with SPARK_Mode is

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

end Adaflight.Autopilot_Debug;
