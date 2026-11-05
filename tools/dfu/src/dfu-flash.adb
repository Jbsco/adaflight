package body DFU.Flash with SPARK_Mode is

   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   procedure Erase
     (M : DFU.Layout.Memory; Images : Image_Array; Count : Image_Count; Pages : out Natural;
      Bytes : out Interfaces.Unsigned_64; Failed : out Address; Ok : out Boolean)
   is
      Set : Page_Set;
   begin
      Pages := 0;
      Bytes := 0;
      Failed := 0;
      Ok := True;
      Erase_Set (M, Images, Count, Set);
      for P in 1 .. M.Pages loop
         pragma Loop_Invariant (Pages < P and then Bytes <= Interfaces.Unsigned_64 (P - 1) * 2 ** 32);
         if Set (P) then
            DFU.Session.Erase_Page (M.First (P), Ok);
            if not Ok then
               Failed := M.First (P);
               return;
            end if;
            Pages := Pages + 1;
            Bytes := Bytes + Interfaces.Unsigned_64 (M.Last (P) - M.First (P)) + 1;
         end if;
      end loop;
   end Erase;

   procedure Write
     (Images : Image_Array; Offsets : Offset_Array; Count : Image_Count; Data : Byte_Array;
      Transfer : DFU.Session.Transfer_Size; Failed : out Address; Ok : out Boolean)
   is
   begin
      Failed := 0;
      Ok := True;
      for K in 1 .. Count loop
         DFU.Session.Write
           (Images (K).First, Data (Offsets (K) .. Offsets (K) + Images (K).Length - 1), Transfer, Ok);
         if not Ok then
            Failed := Images (K).First;
            return;
         end if;
      end loop;
   end Write;

   procedure Verify
     (Images : Image_Array; Offsets : Offset_Array; Count : Image_Count; Data : Byte_Array;
      Transfer : DFU.Session.Transfer_Size; Failed : out Address; Ok : out Boolean)
   is
      Mismatch : Data_Index;
   begin
      Failed := 0;
      Ok := True;
      for K in 1 .. Count loop
         DFU.Session.Verify
           (Images (K).First, Data (Offsets (K) .. Offsets (K) + Images (K).Length - 1), Transfer, Ok, Mismatch);
         if not Ok then
            Failed := Images (K).First + Address (Mismatch);
            return;
         end if;
      end loop;
   end Verify;

end DFU.Flash;
