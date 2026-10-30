package body Adaflight.Timer_Allocation with SPARK_Mode is

   procedure Load (T : out Table; Map : Config_Groups.Timer_Io_Config_Record_List_21) is
   begin
      T := (Map => Map, Owners => (others => <>));
   end Load;

   function Configured_Channel (T : Table; Tag : Unsigned_8) return Channel_Index is
   begin
      for S in Slot loop
         if T.Map (S).Io_Tag = Tag then
            return Channel_Of (T, S);
         end if;
      end loop;
      return 0;
   end Configured_Channel;

   function Channel_Owner (T : Table; K : Positive) return CLI_Resources.Timer_Owner is
   begin
      for S in Slot loop
         if Channel_Of (T, S) = K then
            return T.Owners (S);
         end if;
      end loop;
      return (Held => False, Owner => CLI_Resources.Owner'First, Ordinal => 0);
   end Channel_Owner;

   procedure Allocate
     (T : in out Table; Tag : Unsigned_8; Who : CLI_Resources.Owner; Ordinal : Ordinal_Number;
      K : out Channel_Index; S : out Natural)
   is
   begin
      K := 0;
      S := Slot'Last + 1;
      if Tag = 0 then
         return;
      end if;
      for I in Slot loop
         if T.Map (I).Io_Tag = Tag then
            K := Channel_Of (T, I);
            if K /= 0 and then Channel_Owner (T, K).Held then
               K := 0;
               return;
            end if;
            T.Owners (I) := (Held => True, Owner => Who, Ordinal => Ordinal);
            S := I;
            return;
         end if;
      end loop;
   end Allocate;

end Adaflight.Timer_Allocation;
