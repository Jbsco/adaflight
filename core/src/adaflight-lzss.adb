with Interfaces;

package body Adaflight.LZSS with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   procedure Decode (Source : Byte_Array; Target : out Byte_Array; Result : out Status) is
      Total : constant Natural := Source'Length * 8;
      Bit   : Natural := 32;
      Size  : Natural := 0;

      --  The next N bits of the stream, most significant first.
      procedure Read (N : Positive; Value : out Natural)
        with Pre  => N <= 16 and then Bit <= Total - N,
             Post => Bit = Bit'Old + N and then Value < 2 ** N
      is
      begin
         Value := 0;
         for I in 1 .. N loop
            pragma Loop_Invariant (Bit = Bit'Loop_Entry + I - 1 and then Value < 2 ** (I - 1));
            Value := Value * 2
              + Natural (Interfaces.Shift_Right (Source (Source'First + Bit / 8), 7 - Bit mod 8) and 1);
            Bit := Bit + 1;
         end loop;
      end Read;

      Flag, Literal, Distance, Count : Natural;
   begin
      Target := (others => 0);
      if Source'Length < 4 then
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
      while Size < Target'Length loop
         pragma Loop_Invariant (Size < Target'Length and then Bit in 32 .. Total);
         if Bit >= Total then
            Result := Truncated;
            return;
         end if;
         Read (1, Flag);
         if Flag = 0 then
            if Bit > Total - 8 then
               Result := Truncated;
               return;
            end if;
            Read (8, Literal);
            Target (Target'First + Size) := Byte (Literal);
            Size := Size + 1;
         else
            if Bit > Total - (Offset_Bits + Count_Bits) then
               Result := Truncated;
               return;
            end if;
            Read (Offset_Bits, Distance);
            Read (Count_Bits, Count);
            Distance := Distance + 1;
            Count := Count + Min_Match;
            if Distance > Size then
               Result := Bad_Distance;
               return;
            elsif Count > Target'Length - Size then
               Result := Overrun;
               return;
            end if;
            for K in 1 .. Count loop
               pragma Loop_Invariant (Size = Size'Loop_Entry + K - 1 and then Size < Target'Length
                                      and then Distance <= Size);
               Target (Target'First + Size) := Target (Target'First + Size - Distance);
               Size := Size + 1;
            end loop;
         end if;
      end loop;
      Result := Done;
   end Decode;

end Adaflight.LZSS;
