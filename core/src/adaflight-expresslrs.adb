package body Adaflight.ExpressLRS with SPARK_Mode is

   --------------
   -- UID_Seed --
   --------------

   function UID_Seed (UID : Byte_Array) return Unsigned_32 is
     (Interfaces.Shift_Left (Unsigned_32 (UID (UID'First + 2)), 24)
      + Interfaces.Shift_Left (Unsigned_32 (UID (UID'First + 3)), 16)
      + Interfaces.Shift_Left (Unsigned_32 (UID (UID'First + 4)), 8)
      + Unsigned_32 (UID (UID'First + 5) xor OTA_Version));

   ------------
   -- Random --
   ------------

   --  The linear congruential generator behind the shuffle: a value below
   --  Max from the high half of the next seed.
   procedure Random (Seed : in out Unsigned_32; Max : Positive; Value : out Natural)
     with Post => Value < Max
   is
      Multiplier : constant Unsigned_32 := 214_013;
      Increment  : constant Unsigned_32 := 2_531_011;
      Modulus    : constant Unsigned_32 := 2 ** 31;
   begin
      Seed := (Multiplier * Seed + Increment) mod Modulus;
      Value := Natural (Interfaces.Shift_Right (Seed, 16) mod Unsigned_32 (Max));
   end Random;

   --------------
   -- Generate --
   --------------

   procedure Generate (H : in out Hopping; Seed : Unsigned_32; Domain : Frequency_Domain) is
      Config    : constant Domain_Config := Domains (Domain);
      FC        : constant Channel_Count := Config.Channels;
      Blocks    : constant Positive := Sequence_Length / FC;
      New_Count : constant Sequence_Count := Blocks * FC;
      Draw      : Natural;
   begin
      H.Seed := Seed;
      H.Domain := Domain;
      H.Sync_Channel := FC / 2 + 1;
      H.Spread := (Config.Stop_Reg - Config.Start_Reg) * Spread_Scale / Unsigned_32 (FC - 1);
      H.Index := H.Index mod New_Count;
      H.Count := New_Count;

      for I in 0 .. New_Count - 1 loop
         if I mod FC = 0 then
            H.Sequence (I) := H.Sync_Channel;
         elsif I mod FC = H.Sync_Channel then
            H.Sequence (I) := 0;
         else
            H.Sequence (I) := I mod FC;
         end if;
      end loop;

      --  Each block keeps its sync channel first and swaps every other entry
      --  with a drawn entry of the same block.
      for Block in 0 .. Blocks - 1 loop
         for J in 1 .. FC - 1 loop
            Random (H.Seed, FC - 1, Draw);
            declare
               I     : constant Sequence_Index := Block * FC + J;
               Other : constant Sequence_Index := Block * FC + Draw + 1;
               Temp  : constant Channel_Number := H.Sequence (I);
            begin
               H.Sequence (I) := H.Sequence (Other);
               H.Sequence (Other) := Temp;
            end;
         end loop;
      end loop;
   end Generate;

   ---------------
   -- Set_Index --
   ---------------

   procedure Set_Index (H : in out Hopping; Value : Byte) is
   begin
      H.Index := Natural (Value) mod H.Count;
   end Set_Index;

   --------------------
   -- Next_Frequency --
   --------------------

   procedure Next_Frequency (H : in out Hopping; Correction : Interfaces.Integer_32; Freq : out Unsigned_32) is
   begin
      H.Index := (H.Index + 1) mod H.Count;
      Freq := Domains (H.Domain).Start_Reg + H.Spread * Unsigned_32 (H.Sequence (H.Index)) / Spread_Scale
        - Unsigned_32'Mod (Correction);
   end Next_Frequency;

   -----------
   -- CRC14 --
   -----------

   --  The table entry for one byte: the byte above the six low bits, run
   --  through eight rounds of the polynomial.
   function CRC14_Entry (B : Byte) return Unsigned_16 is
      C : Unsigned_16 := Interfaces.Shift_Left (Unsigned_16 (B), 6);
   begin
      for Round in 1 .. 8 loop
         C := Interfaces.Shift_Left (C, 1) xor (if (C and 16#2000#) /= 0 then CRC14_Polynomial else 0);
      end loop;
      return C;
   end CRC14_Entry;

   function CRC14 (Data : Byte_Array; Init : Unsigned_16) return CRC14_Value is
      C : Unsigned_16 := Init;
   begin
      for I in Data'Range loop
         C := Interfaces.Shift_Left (C, 8)
           xor CRC14_Entry (Byte ((Interfaces.Shift_Right (C, 6) xor Unsigned_16 (Data (I))) and 16#FF#));
      end loop;
      return C and 16#3FFF#;
   end CRC14;

   -----------
   -- Reset --
   -----------

   procedure Reset (L : out Link_Quality) is
   begin
      L := (others => <>);
   end Reset;

   --------------
   -- Increase --
   --------------

   procedure Increase (L : in out Link_Quality) is
   begin
      if not Period_Is_Set (L) then
         L.Bits (L.Index) := L.Bits (L.Index) or Mask (L);
         L.Value := L.Value + 1;
      end if;
   end Increase;

   ----------------
   -- New_Period --
   ----------------

   procedure New_Period (L : in out Link_Quality) is
   begin
      if L.Bit = 31 then
         L.Bit := 0;
         L.Index := L.Index + 1;
      elsif L.Index = LQ_Depth - 1 and then L.Bit + 1 = LQ_Last_Bit then
         L.Index := 0;
         L.Bit := 0;
      else
         L.Bit := L.Bit + 1;
      end if;

      if Period_Is_Set (L) then
         L.Bits (L.Index) := L.Bits (L.Index) and not Mask (L);
         L.Value := L.Value - 1;
      end if;
   end New_Period;

end Adaflight.ExpressLRS;
