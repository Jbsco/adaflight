with Adaflight.Board;
package body Adaflight.STM32.Timers is

   Map    : Timer_Pin_Map renames Adaflight.Board.Timer_Map;
   Owners : array (Map'Range) of Owner := (others => Free);

   function Tagged_Pin (Tag : Unsigned_8) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Unsigned_8) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   --  The timer table's entry an option counts among a pin's entries, or 0.
   function Table_Index (Where : Pin; Option : Natural) return Natural is
      Seen : Natural := 0;
   begin
      for T in Timer_Table'Range loop
         if Timer_Table (T).Where = Where then
            Seen := Seen + 1;
            if Seen = Option then
               return T;
            end if;
         end if;
      end loop;
      return 0;
   end Table_Index;

   procedure Allocate
     (Tag : Unsigned_8; Who : Owner; E : out Timer_Entry; Map_Index : out Natural; Found : out Boolean)
   is
   begin
      E := Timer_Table (Timer_Table'First);
      Map_Index := 0;
      Found := False;
      if not Tagged_Pin (Tag) then
         return;
      end if;
      for I in Map'Range loop
         if Map (I).P = Pin_Of (Tag) then
            declare
               T : constant Natural := Table_Index (Map (I).P, Map (I).Timer_Option);
            begin
               if T = 0 then
                  return;
               end if;
               for J in Map'Range loop
                  if Table_Index (Map (J).P, Map (J).Timer_Option) = T then
                     if Owners (J) /= Free then
                        return;
                     end if;
                     exit;
                  end if;
               end loop;
               Owners (I) := Who;
               E := Timer_Table (T);
               Map_Index := I;
               Found := True;
               return;
            end;
         end if;
      end loop;
   end Allocate;

end Adaflight.STM32.Timers;
