package body Adaflight.Config_Store with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   ---------------------
   -- Check_Structure --
   ---------------------

   procedure Check_Structure (Image : Byte_Array; Valid : out Boolean; Size : out Natural) is
      Last     : constant Natural := Image'Length;
      P        : Natural := Header_Size;
      CRC      : Unsigned_16 := CRC_Start;
      Rec_Size : Natural;
   begin
      Valid := False;
      Size := 0;
      if Byte_At (Image, 1) /= Magic then
         return;
      end if;
      CRC := CRC16_CCITT_Update (CRC, Image (Image'First .. Image'First + 1));
      loop
         pragma Loop_Invariant (P in Header_Size .. Last);
         pragma Loop_Variant (Increases => P);
         Rec_Size := U16_At (Image, P);
         exit when Rec_Size = 0;
         if P + Rec_Size >= Last or else Rec_Size < Record_Header then
            return;
         end if;
         CRC := CRC16_CCITT_Update (CRC, Image (Image'First + P .. Image'First + P + Rec_Size - 1));
         P := P + Rec_Size;
      end loop;
      for K in 0 .. Trailer_Size - 1 loop
         CRC := CRC16_CCITT (CRC, Byte_At (Image, P + K));
      end loop;
      Size := P + Trailer_Size;
      Valid := CRC = CRC_Check;
   end Check_Structure;

   ----------
   -- Find --
   ----------

   function Find (Image : Byte_Array; Number : Group_Number; Class : Interfaces.Unsigned_8) return Natural is
      Last     : constant Natural := Image'Length;
      P        : Natural := Header_Size;
      Rec_Size : Natural;
   begin
      loop
         pragma Loop_Invariant (P in Header_Size .. Last);
         pragma Loop_Variant (Increases => P);
         Rec_Size := U16_At (Image, P);
         if Rec_Size = 0 or else P + Rec_Size >= Last or else Rec_Size < Record_Header then
            return 0;
         end if;
         if U16_At (Image, P + 2) = Natural (Number) and then (Byte_At (Image, P + 5) and Class_Mask) = Class then
            return P;
         end if;
         P := P + Rec_Size;
      end loop;
   end Find;

   ----------
   -- Load --
   ----------

   procedure Load
     (Image : Byte_Array; Reg : Registry; Defaults : Byte_Array; Data : in out Byte_Array; Hashes : out Hash_List;
      Success : out Boolean)
   is
   begin
      Hashes := (others => 0);
      Success := True;
      for I in Reg'Range loop
         declare
            G     : constant Group := Reg (I);
            First : constant Integer := Data'First + G.Offset;
            R     : constant Natural := Find (Image, G.Number, System_Class);
         begin
            Data (First .. First + G.Size - 1) :=
              Defaults (Defaults'First + G.Offset .. Defaults'First + G.Offset + G.Size - 1);
            if R = 0 then
               Success := False;
            elsif Byte_At (Image, R + 4) = G.Version then
               declare
                  Take : constant Natural := Natural'Min (U16_At (Image, R) - Record_Header, G.Size);
                  From : constant Natural := Image'First + R + Record_Header;
               begin
                  Data (First .. First + Take - 1) := Image (From .. From + Take - 1);
               end;
            else
               Success := False;
            end if;
            Hashes (Hashes'First + (I - Reg'First)) :=
              FNV_Update (FNV_Offset_Basis, Data (First .. First + G.Size - 1));
         end;
      end loop;
   end Load;

   -----------
   -- Dirty --
   -----------

   function Dirty (Image : Byte_Array; Reg : Registry; Data : Byte_Array; Hashes : Hash_List) return Boolean is
      Valid : Boolean;
      Size  : Natural;
   begin
      if not Version_Valid (Image) then
         return True;
      end if;
      Check_Structure (Image, Valid, Size);
      pragma Unreferenced (Size);
      if not Valid then
         return True;
      end if;
      for I in Reg'Range loop
         declare
            First : constant Integer := Data'First + Reg (I).Offset;
         begin
            if Hashes (Hashes'First + (I - Reg'First))
              /= FNV_Update (FNV_Offset_Basis, Data (First .. First + Reg (I).Size - 1))
            then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Dirty;

   ------------------
   -- Image_Length --
   ------------------

   function Image_Length (Reg : Registry) return Natural is
      Length : Natural := Header_Size;
   begin
      for I in Reg'Range loop
         pragma Loop_Invariant (Length <= Header_Size + (I - Reg'First) * (Record_Header + Max_Group_Size));
         Length := Length + Record_Header + Reg (I).Size;
      end loop;
      return Length + Trailer_Size;
   end Image_Length;

   ----------
   -- Save --
   ----------

   procedure Save
     (Reg : Registry; Data : Byte_Array; Hashes : Hash_List; Image : in out Byte_Array; Written : out Boolean;
      Fits : out Boolean)
   is
      P   : Natural := 0;
      CRC : Unsigned_16 := CRC_Start;

      procedure Put (B : Byte)
        with Pre  => P < Image'Length,
             Post => P = P'Old + 1
      is
      begin
         Image (Image'First + P) := B;
         CRC := CRC16_CCITT (CRC, B);
         P := P + 1;
      end Put;
   begin
      Written := False;
      Fits := True;
      if not Dirty (Image, Reg, Data, Hashes) then
         return;
      end if;
      if Image_Length (Reg) > Image'Length then
         Fits := False;
         return;
      end if;
      Image := (others => 0);
      Written := True;
      Put (Storage_Version);
      Put (Magic);
      for I in Reg'Range loop
         pragma Loop_Invariant (P in Header_Size .. Image'Length);
         declare
            G         : constant Group := Reg (I);
            Rec_Size  : constant Natural := Record_Header + G.Size;
            First     : constant Integer := Data'First + G.Offset;
         begin
            exit when Rec_Size > Image'Length - P;
            Put (Byte (Rec_Size mod 256));
            Put (Byte (Rec_Size / 256));
            Put (Byte (G.Number and 16#FF#));
            Put (Byte (Interfaces.Shift_Right (G.Number, 8)));
            Put (G.Version);
            Put (System_Class);
            Image (Image'First + P .. Image'First + P + G.Size - 1) := Data (First .. First + G.Size - 1);
            CRC := CRC16_CCITT_Update (CRC, Data (First .. First + G.Size - 1));
            P := P + G.Size;
         end;
      end loop;
      if Trailer_Size <= Image'Length - P then
         Put (0);
         Put (0);
         Image (Image'First + P) := not Byte (Interfaces.Shift_Right (CRC, 8));
         Image (Image'First + P + 1) := not Byte (CRC and 16#FF#);
      end if;
   end Save;

end Adaflight.Config_Store;
