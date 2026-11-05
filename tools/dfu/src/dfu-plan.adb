package body DFU.Plan with SPARK_Mode is

   procedure Erase_Set (M : Memory; Images : Image_Array; Count : Image_Count; Erase : out Page_Set) is
   begin
      Erase := (others => False);
      for P in 1 .. M.Pages loop
         for K in 1 .. Count loop
            if Touches (M, P, Images (K)) then
               Erase (P) := True;
            end if;
            pragma Loop_Invariant (for all Q in Page_Index => (if Q /= P then Erase (Q) = Erase'Loop_Entry (Q)));
            pragma Loop_Invariant (Erase (P) = (for some L in 1 .. K => Touches (M, P, Images (L))));
         end loop;
         pragma Loop_Invariant
           (for all Q in Page_Index =>
              Erase (Q) = (Q <= P and then (for some K in 1 .. Count => Touches (M, Q, Images (K)))));
      end loop;
   end Erase_Set;

   procedure Place_Pair
     (M : Memory; First_Length, Second_Length : Data_Index; Images : out Image_Array; Ok : out Boolean)
   is
   begin
      Images := (others => (First => 0, Length => 0));
      Ok := False;
      if M.Pages < 3 or else First_Length = 0 or else Second_Length = 0 then
         return;
      end if;
      Images (1) := (First => M.First (1), Length => First_Length);
      Images (2) := (First => M.First (3), Length => Second_Length);
      Ok := Last (Images (1)) <= Interfaces.Unsigned_64 (M.Last (1))
        and then Last (Images (2)) <= Interfaces.Unsigned_64 (M.Last (M.Pages));
   end Place_Pair;

end DFU.Plan;
