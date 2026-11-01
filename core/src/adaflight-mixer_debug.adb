package body Adaflight.Mixer_Debug with SPARK_Mode is

   --  A value held within the conversion bound, before and after a scale.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   --  A value scaled then rounded as the reference stores lrintf results, or
   --  scaled then truncated as it stores a float.
   function R10 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 10.0)));
   function R100 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 100.0)));
   function R1000 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 1000.0)));
   function R10000 (X : Float) return Debug.Integer_16 is (Debug.Rounded (Held (Held (X) * 10000.0)));
   function T10000 (X : Float) return Debug.Integer_16 is (Debug.Truncated (Held (Held (X) * 10000.0)));

   procedure Record_Update (D : in out Debug.State; S : Mixer.State) is
      T : Mixer.Debug_Taps renames S.Taps;
   begin
      if Debug.Selected (D, Debug.Dyn_Idle) and then T.Dyn_Idle_Set then
         --  The reference holds the P term's value at -1000 from below.
         Debug.Set (D, Debug.Dyn_Idle, 0, R10000 (Float'Max (-0.1, T.Dyn_Idle_P)));
         Debug.Set (D, Debug.Dyn_Idle, 1, R10000 (S.Dyn_Idle_I));
         Debug.Set (D, Debug.Dyn_Idle, 2, R10000 (T.Dyn_Idle_D));
         Debug.Set (D, Debug.Dyn_Idle, 3, R10 (T.Dyn_Idle_Hz));
      end if;
      if Debug.Selected (D, Debug.Sag_Compensation) and then T.Sag_Set then
         Debug.Set (D, Debug.Sag_Compensation, 0, R100 (T.Sag_Goodness));
         Debug.Set (D, Debug.Sag_Compensation, 1, R1000 (T.Sag_Attenuation));
      end if;
      if Debug.Selected (D, Debug.RPM_Limit) and then T.Limiter_Set then
         Debug.Set (D, Debug.RPM_Limit, 0, Debug.Rounded (Held (T.Limiter_Average)));
         Debug.Set (D, Debug.RPM_Limit, 1, R100 (T.Limiter_Offset));
         Debug.Set (D, Debug.RPM_Limit, 2, R100 (S.Limiter_Scale));
         Debug.Set (D, Debug.RPM_Limit, 3, R100 (T.Limiter_Throttle));
         Debug.Set (D, Debug.RPM_Limit, 4, Debug.Rounded (Held (T.Limiter_Error)));
         Debug.Set (D, Debug.RPM_Limit, 5, R100 (T.Limiter_P));
         Debug.Set (D, Debug.RPM_Limit, 6, R100 (S.Limiter_I));
         Debug.Set (D, Debug.RPM_Limit, 7, R100 (T.Limiter_D));
      end if;
      if Debug.Selected (D, Debug.EZ_Landing) then
         if T.Ez_Set then
            Debug.Set (D, Debug.EZ_Landing, 0, T10000 (T.Ez_Factor));
            Debug.Set (D, Debug.EZ_Landing, 2, T10000 (T.Ez_Upper));
            Debug.Set (D, Debug.EZ_Landing, 3, T10000 (T.Ez_Limit_Ratio));
            Debug.Set (D, Debug.EZ_Landing, 4, R10000 (T.Ez_Deflection_Limit));
            Debug.Set (D, Debug.EZ_Landing, 5, R10000 (T.Ez_Speed_Limit));
         end if;
         if T.Throttle_Set then
            Debug.Set (D, Debug.EZ_Landing, 1, T10000 (T.Final_Throttle));
         end if;
      end if;
   end Record_Update;

end Adaflight.Mixer_Debug;
