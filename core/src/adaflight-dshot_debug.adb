with Interfaces;

package body Adaflight.DShot_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

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

   --  A count raised by N, wrapped into sixteen bits.
   function Counted (V : Debug.Integer_16; N : DShot.Motor_Total) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (V) + Interfaces.Integer_32 (N)));

   procedure Record_Read (D : in out Debug.State; C : DShot.Read_Counts) is
   begin
      if Debug.Selected (D, Debug.DShot_Telemetry_Counts) then
         Debug.Set (D, Debug.DShot_Telemetry_Counts, 1, Counted (D.Data (1), C.Taps.Missing));
         Debug.Set (D, Debug.DShot_Telemetry_Counts, 0, Counted (D.Data (0), C.Taps.Reads));
      end if;
   end Record_Read;

   procedure Record_Timeout (D : in out Debug.State) is
   begin
      if Debug.Selected (D, Debug.DShot_Telemetry_Counts) then
         Debug.Set (D, Debug.DShot_Telemetry_Counts, 2, Counted (D.Data (2), 1));
      end if;
   end Record_Timeout;

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
