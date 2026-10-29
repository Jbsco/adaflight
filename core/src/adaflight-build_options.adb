package body Adaflight.Build_Options with SPARK_Mode is

   function In_Order (S : Selection) return List is
      L : List;
   begin
      for O in Option loop
         pragma Loop_Invariant (L.Length <= Option'Pos (O));
         if S (O) then
            L.Length := L.Length + 1;
            L.Numbers (L.Length) := Number (O);
         end if;
      end loop;
      return L;
   end In_Order;

end Adaflight.Build_Options;
