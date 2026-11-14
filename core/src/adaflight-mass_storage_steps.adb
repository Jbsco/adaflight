package body Adaflight.Mass_Storage_Steps with SPARK_Mode is

   procedure Start_Storage is null;

   procedure Capacity (Blocks : out Interfaces.Unsigned_32; OK : out Boolean) is
   begin
      Blocks := 1_048_576;
      OK := True;
   end Capacity;

   procedure Ready (OK : out Boolean) is
   begin
      OK := True;
   end Ready;

   procedure Write_Protected (Yes : out Boolean) is
   begin
      Yes := False;
   end Write_Protected;

   procedure Read_Blocks
     (First : Interfaces.Unsigned_32; Count : Natural; Data : in out Adaflight.Bytes.Byte_Array; OK : out Boolean)
   is
      pragma Unreferenced (First);
   begin
      for I in Data'Range loop
         if (I - Data'First) / 512 < Count then
            Data (I) := 0;
         end if;
      end loop;
      OK := True;
   end Read_Blocks;

   procedure Write_Blocks
     (First : Interfaces.Unsigned_32; Count : Natural; Data : Adaflight.Bytes.Byte_Array; OK : out Boolean)
   is
      pragma Unreferenced (First, Count, Data);
   begin
      OK := True;
   end Write_Blocks;

end Adaflight.Mass_Storage_Steps;
