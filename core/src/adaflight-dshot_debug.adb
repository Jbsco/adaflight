with Interfaces;

package body Adaflight.DShot_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   --  A value held within the conversion bound.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   procedure Record_Update (D : in out Debug.State; T : DShot.Telemetry) is
   begin
      if not T.Taps.Processed then
         return;
      end if;
      if Debug.Selected (D, Debug.DShot_RPM_Telemetry) then
         for M in 0 .. T.Count - 1 loop
            if T.Taps.Erpm_Seen (M) then
               Debug.Set (D, Debug.DShot_RPM_Telemetry, M,
                          Debug.Wrapped (Interfaces.Integer_32 (T.Taps.Erpm (M) and 16#FFFF#)));
            end if;
         end loop;
      end if;
      if Debug.Selected (D, Debug.RPM_Filter) then
         for M in 0 .. T.Count - 1 loop
            Debug.Set (D, Debug.RPM_Filter, M, Debug.Rounded (Held (T.Frequency (M))));
         end loop;
      end if;
   end Record_Update;

   procedure Record_Decode (D : in out Debug.State; E : DShot.Edge_Decoder) is
   begin
      Debug.Set (D, Debug.DShot_Telemetry_Counts, 3, Debug.Integer_16 (E.Skip_Used));
   end Record_Decode;

   procedure Record_Errors (D : in out Debug.State; T : DShot.Telemetry; Q : DShot.Qualities;
                            Count : DShot.Motor_Total; Use_Telemetry : Boolean) is
   begin
      if Debug.Selected (D, Debug.DShot_RPM_Errors) and then Use_Telemetry then
         for M in 0 .. Natural'Min (Count, 4) - 1 loop
            Debug.Set (D, Debug.DShot_RPM_Errors, M, DShot.Invalid_Percent (Q (M), DShot.Motor_Active (T, M)));
         end loop;
      end if;
   end Record_Errors;

end Adaflight.DShot_Debug;
