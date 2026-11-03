package body Adaflight.LZMA with SPARK_Mode is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  Powers of two for the bit trees, which keep their index bounds linear.
   type Power_Table is array (0 .. 8) of Positive;
   Power : constant Power_Table := (1, 2, 4, 8, 16, 32, 64, 128, 256);

   --  The position slots 4 to 13: each one's base distance and the bits its
   --  reverse tree reads, whose probabilities start at the base less the slot.
   subtype Special_Slot is Natural range 4 .. 13;
   type Slot_Table is array (Special_Slot) of Natural;
   Special_Distance : constant Slot_Table := (4, 6, 8, 12, 16, 24, 32, 48, 64, 96);
   Special_Bits     : constant Slot_Table := (1, 1, 2, 2, 3, 3, 4, 4, 5, 5);

   subtype State_Index is Natural range 0 .. 11;

   procedure Decode (Source : Byte_Array; Target : out Byte_Array; M : out Model; Result : out Status) is
      Range_Value : Unsigned_32 := 16#FFFF_FFFF#;
      Code        : Unsigned_32 := 0;
      Read_Count  : Natural := 4;
      Exhausted   : Boolean := False;
      Corrupt     : Boolean := False;

      --  The next byte of the stream, zero past its end.
      procedure Next_Byte (B : out Unsigned_32)
        with Post => B <= 255
      is
      begin
         if Read_Count < Source'Length then
            B := Unsigned_32 (Source (Source'First + Read_Count));
            Read_Count := Read_Count + 1;
         else
            B := 0;
            Exhausted := True;
         end if;
      end Next_Byte;

      procedure Normalize is
         B : Unsigned_32;
      begin
         if Range_Value < 2 ** 24 then
            Next_Byte (B);
            Range_Value := Interfaces.Shift_Left (Range_Value, 8);
            Code := Interfaces.Shift_Left (Code, 8) or B;
         end if;
      end Normalize;

      procedure Decode_Bit (P : in out Probability; Bit : out Natural)
        with Post => Bit <= 1
      is
         Bound : constant Unsigned_32 := Interfaces.Shift_Right (Range_Value, 11) * Unsigned_32 (P);
      begin
         if Code < Bound then
            Range_Value := Bound;
            P := P + (2048 - P) / 32;
            Bit := 0;
         else
            Range_Value := Range_Value - Bound;
            Code := Code - Bound;
            P := P - P / 32;
            Bit := 1;
         end if;
         Normalize;
      end Decode_Bit;

      --  A bit tree of Bits levels whose probabilities start at Base.
      procedure Tree (P : in out Probabilities; Base : Natural; Bits : Positive; Value : out Natural)
        with Pre  => Bits <= 8 and then Base >= P'First and then Base <= Natural'Last - 256
                     and then Base + (Power (Bits) - 1) <= P'Last,
             Post => Value < Power (Bits)
      is
         Index : Natural := 1;
         Bit   : Natural;
      begin
         for I in 1 .. Bits loop
            pragma Loop_Invariant (Index >= Power (I - 1) and then Index < Power (I));
            Decode_Bit (P (Base + Index), Bit);
            Index := Index * 2 + Bit;
         end loop;
         Value := Index - Power (Bits);
      end Tree;

      --  A bit tree read least significant bit first.
      procedure Reverse_Tree (P : in out Probabilities; Base : Natural; Bits : Positive; Value : out Natural)
        with Pre  => Bits <= 8 and then Base >= P'First and then Base <= Natural'Last - 256
                     and then Base + (Power (Bits) - 1) <= P'Last,
             Post => Value < Power (Bits)
      is
         Index : Natural := 1;
         Bit   : Natural;
      begin
         Value := 0;
         for I in 0 .. Bits - 1 loop
            pragma Loop_Invariant (Index >= Power (I) and then Index < Power (I + 1) and then Value < Power (I));
            Decode_Bit (P (Base + Index), Bit);
            Index := Index * 2 + Bit;
            Value := Value + Bit * Power (I);
         end loop;
      end Reverse_Tree;

      procedure Direct_Bits (Count : Positive; Value : out Unsigned_32)
        with Pre => Count <= 26
      is
         T : Unsigned_32;
      begin
         Value := 0;
         for I in 1 .. Count loop
            Range_Value := Interfaces.Shift_Right (Range_Value, 1);
            Code := Code - Range_Value;
            T := 0 - Interfaces.Shift_Right (Code, 31);
            Code := Code + (Range_Value and T);
            if Code = Range_Value then
               Corrupt := True;
            end if;
            Normalize;
            Value := Interfaces.Shift_Left (Value, 1) + (T + 1);
         end loop;
      end Direct_Bits;

      --  A match length less two, from the match or the repeat coder.
      procedure Decode_Length (Repeat : Boolean; Len : out Natural)
        with Post => Len <= 271
      is
         Bit, V : Natural;
      begin
         if Repeat then
            Decode_Bit (M.Rep_Choice (0), Bit);
            if Bit = 0 then
               Tree (M.Rep_Low, 0, 3, V);
               Len := V;
            else
               Decode_Bit (M.Rep_Choice (1), Bit);
               if Bit = 0 then
                  Tree (M.Rep_Mid, 0, 3, V);
                  Len := 8 + V;
               else
                  Tree (M.Rep_High, 0, 8, V);
                  Len := 16 + V;
               end if;
            end if;
         else
            Decode_Bit (M.Len_Choice (0), Bit);
            if Bit = 0 then
               Tree (M.Len_Low, 0, 3, V);
               Len := V;
            else
               Decode_Bit (M.Len_Choice (1), Bit);
               if Bit = 0 then
                  Tree (M.Len_Mid, 0, 3, V);
                  Len := 8 + V;
               else
                  Tree (M.Len_High, 0, 8, V);
                  Len := 16 + V;
               end if;
            end if;
         end if;
      end Decode_Length;

      procedure Decode_Distance (Len : Natural; Distance : out Unsigned_32) is
         Len_State : constant Natural := Natural'Min (Len, 3);
         Slot, V   : Natural;
         Direct    : Unsigned_32;
      begin
         Tree (M.Pos_Slot, Len_State * 64, 6, Slot);
         if Slot < 4 then
            Distance := Unsigned_32 (Slot);
         elsif Slot < 14 then
            Reverse_Tree (M.Pos_Special, Special_Distance (Slot) - Slot, Special_Bits (Slot), V);
            Distance := Unsigned_32 (Special_Distance (Slot) + V);
         else
            Direct_Bits (Slot / 2 - 5, Direct);
            Reverse_Tree (M.Align, 0, 4, V);
            Distance := Interfaces.Shift_Left (Unsigned_32 (2 + Slot mod 2), Slot / 2 - 1)
              + Interfaces.Shift_Left (Direct, 4) + Unsigned_32 (V);
         end if;
      end Decode_Distance;

      Pos   : Natural := 0;
      State : State_Index := 0;
      Rep0, Rep1, Rep2, Rep3 : Unsigned_32 := 0;
      Swap : Unsigned_32;
      Bit, Len, Symbol, Match_Byte, Match_Bit : Natural;
      B : Unsigned_32;
   begin
      Target := (others => 0);
      M := (others => (others => 1024));
      if Source'Length < 9 then
         Result := Truncated;
         return;
      end if;
      declare
         Header : constant Unsigned_32 :=
           Interfaces.Shift_Left (Unsigned_32 (Source (Source'First)), 24)
           or Interfaces.Shift_Left (Unsigned_32 (Source (Source'First + 1)), 16)
           or Interfaces.Shift_Left (Unsigned_32 (Source (Source'First + 2)), 8)
           or Unsigned_32 (Source (Source'First + 3));
      begin
         if Header /= Unsigned_32 (Target'Length) then
            Result := Bad_Length;
            return;
         end if;
      end;
      Next_Byte (B);
      if B /= 0 then
         Result := Bad_Data;
         return;
      end if;
      for I in 1 .. 4 loop
         Next_Byte (B);
         Code := Interfaces.Shift_Left (Code, 8) or B;
      end loop;
      if Code = Range_Value then
         Result := Bad_Data;
         return;
      end if;

      while Pos < Target'Length loop
         pragma Loop_Invariant (Pos < Target'Length);
         Decode_Bit (M.Is_Match (State), Bit);
         if Bit = 0 then
            --  A literal, after a match decoded against the byte the last
            --  distance points at.
            Symbol := 1;
            if State >= 7 then
               if Rep0 >= Unsigned_32 (Pos) then
                  Result := Bad_Data;
                  return;
               end if;
               Match_Byte := Natural (Target (Target'First + Pos - Natural (Rep0) - 1));
               loop
                  pragma Loop_Invariant (Symbol in 1 .. 255 and then Match_Byte <= 255);
                  Match_Bit := Match_Byte / 128;
                  Match_Byte := (Match_Byte * 2) mod 256;
                  Decode_Bit (M.Literal ((1 + Match_Bit) * 256 + Symbol), Bit);
                  Symbol := Symbol * 2 + Bit;
                  exit when Match_Bit /= Bit or else Symbol >= 256;
               end loop;
            end if;
            while Symbol < 256 loop
               pragma Loop_Invariant (Symbol in 1 .. 255);
               Decode_Bit (M.Literal (Symbol), Bit);
               Symbol := Symbol * 2 + Bit;
            end loop;
            Target (Target'First + Pos) := Byte (Symbol - 256);
            Pos := Pos + 1;
            State := (if State < 4 then 0 elsif State < 10 then State - 3 else State - 6);
         else
            Decode_Bit (M.Is_Rep (State), Bit);
            if Bit = 1 then
               if Pos = 0 then
                  Result := Bad_Data;
                  return;
               end if;
               Decode_Bit (M.Is_Rep_G0 (State), Bit);
               if Bit = 0 then
                  Decode_Bit (M.Is_Rep0_Long (State), Bit);
                  if Bit = 0 then
                     --  One byte from the last distance.
                     if Rep0 >= Unsigned_32 (Pos) then
                        Result := Bad_Data;
                        return;
                     end if;
                     State := (if State < 7 then 9 else 11);
                     Target (Target'First + Pos) := Target (Target'First + Pos - Natural (Rep0) - 1);
                     Pos := Pos + 1;
                     Len := 0;
                  else
                     Len := 1;
                  end if;
               else
                  Decode_Bit (M.Is_Rep_G1 (State), Bit);
                  if Bit = 0 then
                     Swap := Rep1;
                  else
                     Decode_Bit (M.Is_Rep_G2 (State), Bit);
                     if Bit = 0 then
                        Swap := Rep2;
                     else
                        Swap := Rep3;
                        Rep3 := Rep2;
                     end if;
                     Rep2 := Rep1;
                  end if;
                  Rep1 := Rep0;
                  Rep0 := Swap;
                  Len := 1;
               end if;
               if Len = 1 then
                  Decode_Length (True, Len);
                  Len := Len + 2;
                  State := (if State < 7 then 8 else 11);
               end if;
            else
               Rep3 := Rep2;
               Rep2 := Rep1;
               Rep1 := Rep0;
               Decode_Length (False, Len);
               Decode_Distance (Len, Rep0);
               Len := Len + 2;
               State := (if State < 7 then 7 else 10);
            end if;
            if Len > 0 then
               --  A copy of Len bytes from the distance back; the end marker
               --  falls under it, as no output reaches that far back.
               if Rep0 >= Unsigned_32 (Pos) or else Len > Target'Length - Pos then
                  Result := Bad_Data;
                  return;
               end if;
               for K in 1 .. Len loop
                  pragma Loop_Invariant
                    (Pos = Pos'Loop_Entry + K - 1 and then Pos < Target'Length
                     and then Rep0 < Unsigned_32 (Pos));
                  Target (Target'First + Pos) := Target (Target'First + Pos - Natural (Rep0) - 1);
                  Pos := Pos + 1;
               end loop;
            end if;
         end if;
      end loop;
      Result := (if Exhausted then Truncated elsif Corrupt then Bad_Data else Done);
   end Decode;

end Adaflight.LZMA;
