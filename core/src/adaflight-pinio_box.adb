with Adaflight.MSP_Box;

package body Adaflight.PINIO_Box with SPARK_Mode is

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Ids : Permanent_Ids) is
      Found : Boolean;
      Which : Adaflight.Modes.Box;
   begin
      S := (others => (others => <>));
      for I in PINIO_Index loop
         Adaflight.MSP_Box.Find_By_Permanent_Id (Ids (I), Found, Which);
         if Found then
            S (I) := (Assigned => True, Which => Which);
         end if;
      end loop;
   end Init;

   ------------
   -- Update --
   ------------

   function Update (S : State; On : Box_Flags) return Output_Sets is
      R : Output_Sets := (others => (others => <>));
   begin
      for I in PINIO_Index loop
         if S (I).Assigned then
            R (I) := (Set => True, Level => On (S (I).Which));
         end if;
         pragma Loop_Invariant
           (for all J in 0 .. I =>
              R (J).Set = S (J).Assigned and then (if S (J).Assigned then R (J).Level = On (S (J).Which)));
         pragma Loop_Invariant (for all J in I + 1 .. PINIO_Index'Last => not R (J).Set);
      end loop;
      return R;
   end Update;

end Adaflight.PINIO_Box;
