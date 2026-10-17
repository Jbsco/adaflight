package body Adaflight.MSP_Write_Plans with SPARK_Mode is

   function In_Range (S : Setting; V : Integer_64) return Boolean is
      I : constant Info := Describe (S);
   begin
      case I.How is
         when Direct =>
            return V in I.Min .. I.Max;
         when Lookup =>
            return V in 0 .. Integer_64 (Value_Count (I.Table)) - 1
              and then Value_Name (I.Table, Natural (V))'Length > 0;
         when List | Bitset | Text | Identifier =>
            return True;
      end case;
   end In_Range;

   procedure Add (P : in out Plan; S : Setting; Value : Integer_64; Profile : Natural; Index : Natural := 0) is
   begin
      P.Count := P.Count + 1;
      P.Items (P.Count) := (S => S, Value => Value, Profile => Profile, Index => Index);
   end Add;

   procedure Apply (C : in out Configuration; P : Plan) is
   begin
      for K in 1 .. P.Count loop
         Set (C, P.Items (K).S, P.Items (K).Value, P.Items (K).Profile, P.Items (K).Index);
      end loop;
   end Apply;

end Adaflight.MSP_Write_Plans;
