package body Adaflight.MAVLink_Entries with SPARK_Mode is

   ------------
   -- Lookup --
   ------------

   procedure Lookup (Id : Message_Id; Found : out Boolean; E : out Message_Entry) is
      Low  : Entry_Index := Entry_Index'First;
      High : Entry_Index := Entry_Index'Last;
   begin
      while Low < High loop
         pragma Loop_Variant (Decreases => High - Low);
         declare
            Mid : constant Entry_Index := (Low + 1 + High) / 2;
         begin
            if Id < Table (Mid).Id then
               High := Mid - 1;
            elsif Id > Table (Mid).Id then
               Low := Mid;
            else
               Low := Mid;
               exit;
            end if;
         end;
      end loop;
      Found := Table (Low).Id = Id;
      E := Table (Low);
   end Lookup;

end Adaflight.MAVLink_Entries;
