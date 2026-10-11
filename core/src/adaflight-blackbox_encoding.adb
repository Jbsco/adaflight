with Adaflight.Encoding;
with Adaflight.Float_Bits;

package body Adaflight.Blackbox_Encoding with SPARK_Mode is

   --  The two's complement bits of a value, for the byte fields.
   function Bits (V : Integer_32) return Unsigned_32 is (Unsigned_32'Mod (V));

   function Low_Byte (U : Unsigned_32) return Byte is (Byte (U and 16#FF#));

   function Byte_At (U : Unsigned_32; Shift : Natural) return Byte is
     (Byte (Interfaces.Shift_Right (U, Shift) and 16#FF#))
     with Pre => Shift <= 24;

   -----------------------
   -- Write_Unsigned_VB --
   -----------------------

   procedure Write_Unsigned_VB (B : in out Byte_Array; S : in out Stream; Value : Unsigned_32) is
      V : Unsigned_32 := Value;
   begin
      for I in 1 .. Max_VB - 1 loop
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry and then S.Next = S.Next'Loop_Entry + (I - 1));
         exit when V <= 127;
         Write_U8 (B, S, Byte (V and 16#7F#) or 16#80#);
         V := Interfaces.Shift_Right (V, 7);
      end loop;
      Write_U8 (B, S, Byte (V and 16#7F#));
   end Write_Unsigned_VB;

   ---------------------
   -- Write_Signed_VB --
   ---------------------

   procedure Write_Signed_VB (B : in out Byte_Array; S : in out Stream; Value : Integer_32) is
   begin
      Write_Unsigned_VB (B, S, Encoding.Zigzag_Encode (Value));
   end Write_Signed_VB;

   ---------------------------
   -- Write_Signed_VB_Array --
   ---------------------------

   procedure Write_Signed_VB_Array (B : in out Byte_Array; S : in out Stream; Values : Int32_Array) is
   begin
      for I in Values'Range loop
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry
                                and then S.Next in S.Next'Loop_Entry
                                  .. S.Next'Loop_Entry + Max_VB * (I - Values'First));
         Write_Signed_VB (B, S, Values (I));
      end loop;
   end Write_Signed_VB_Array;

   -----------------------------
   -- Write_Signed16_VB_Array --
   -----------------------------

   procedure Write_Signed16_VB_Array (B : in out Byte_Array; S : in out Stream; Values : Int16_Array) is
   begin
      for I in Values'Range loop
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry
                                and then S.Next in S.Next'Loop_Entry
                                  .. S.Next'Loop_Entry + Max_VB * (I - Values'First));
         Write_Signed_VB (B, S, Integer_32 (Values (I)));
      end loop;
   end Write_Signed16_VB_Array;

   ---------------
   -- Write_S16 --
   ---------------

   procedure Write_S16 (B : in out Byte_Array; S : in out Stream; Value : Integer_16) is
      U : constant Unsigned_32 := Bits (Integer_32 (Value));
   begin
      Write_U8 (B, S, Low_Byte (U));
      Write_U8 (B, S, Byte_At (U, 8));
   end Write_S16;

   -----------------
   -- Write_Bytes --
   -----------------

   --  The three fields of a 32-bit group as 1 to 4 bytes each, low byte
   --  first, by the two-bit widths of the second selector, first field in
   --  the low bits.
   procedure Write_Bytes (B : in out Byte_Array; S : in out Stream; Values : Triple; Selector_2 : Unsigned_32)
     with Pre  => Fits (S, B) and then Remaining (S) >= 12,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 3 .. S.Next'Old + 12
   is
      Sel : Unsigned_32 := Selector_2;
   begin
      for X in Values'Range loop
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry
                                and then S.Next in S.Next'Loop_Entry + X .. S.Next'Loop_Entry + 4 * X);
         declare
            U : constant Unsigned_32 := Bits (Values (X));
         begin
            Write_U8 (B, S, Low_Byte (U));
            if (Sel and 3) >= 1 then
               Write_U8 (B, S, Byte_At (U, 8));
            end if;
            if (Sel and 3) >= 2 then
               Write_U8 (B, S, Byte_At (U, 16));
            end if;
            if (Sel and 3) = 3 then
               Write_U8 (B, S, Byte_At (U, 24));
            end if;
         end;
         Sel := Interfaces.Shift_Right (Sel, 2);
      end loop;
   end Write_Bytes;

   --  The second selector: the byte count less one of each field, in two
   --  bits, the first field in the low bits.
   function Byte_Selector (Values : Triple) return Unsigned_32 is
      Sel : Unsigned_32 := 0;
   begin
      for X in reverse Values'Range loop
         Sel := Interfaces.Shift_Left (Sel, 2);
         if Values (X) in -128 .. 127 then
            null;
         elsif Values (X) in -32_768 .. 32_767 then
            Sel := Sel or 1;
         elsif Values (X) in -8_388_608 .. 8_388_607 then
            Sel := Sel or 2;
         else
            Sel := Sel or 3;
         end if;
      end loop;
      return Sel;
   end Byte_Selector;

   ---------------------
   -- Write_Tag2_3S32 --
   ---------------------

   procedure Write_Tag2_3S32 (B : in out Byte_Array; S : in out Stream; Values : Triple) is
      Bits_2  : constant := 0;
      Bits_4  : constant := 1;
      Bits_6  : constant := 2;
      Bits_32 : constant := 3;
      Selector : Natural range Bits_2 .. Bits_32 := Bits_2;
      U0 : constant Unsigned_32 := Bits (Values (0));
      U1 : constant Unsigned_32 := Bits (Values (1));
      U2 : constant Unsigned_32 := Bits (Values (2));
   begin
      for X in Values'Range loop
         if Values (X) >= 32 or else Values (X) < -32 then
            Selector := Bits_32;
            exit;
         end if;
         if Values (X) >= 8 or else Values (X) < -8 then
            Selector := Natural'Max (Selector, Bits_6);
         elsif Values (X) >= 2 or else Values (X) < -2 then
            Selector := Natural'Max (Selector, Bits_4);
         end if;
      end loop;

      case Selector is
         when Bits_2 =>
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (U0 and 3, 4)
                      or Interfaces.Shift_Left (U1 and 3, 2) or (U2 and 3)));
         when Bits_4 =>
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (Unsigned_32'(Bits_4), 6) or (U0 and 16#0F#)));
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (U1 and 16#0F#, 4) or (U2 and 16#0F#)));
         when Bits_6 =>
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (Unsigned_32'(Bits_6), 6) or (U0 and 16#3F#)));
            Write_U8 (B, S, Low_Byte (U1));
            Write_U8 (B, S, Low_Byte (U2));
         when Bits_32 =>
            declare
               Sel : constant Unsigned_32 := Byte_Selector (Values);
            begin
               Write_U8 (B, S, Byte (Interfaces.Shift_Left (Unsigned_32'(Bits_32), 6) or (Sel and 16#3F#)));
               Write_Bytes (B, S, Values, Sel);
            end;
      end case;
   end Write_Tag2_3S32;

   ----------------------------
   -- Write_Tag2_3S_Variable --
   ----------------------------

   procedure Write_Tag2_3S_Variable (B : in out Byte_Array; S : in out Stream; Values : Triple;
                                     Selector : out Natural) is
      Bits_2   : constant := 0;
      Bits_554 : constant := 1;
      Bits_877 : constant := 2;
      Bits_32  : constant := 3;
      U0 : constant Unsigned_32 := Bits (Values (0));
      U1 : constant Unsigned_32 := Bits (Values (1));
      U2 : constant Unsigned_32 := Bits (Values (2));
   begin
      if Values (0) not in -256 .. 255 or else Values (1) not in -128 .. 127 or else Values (2) not in -128 .. 127 then
         Selector := Bits_32;
      elsif Values (0) not in -16 .. 15 or else Values (1) not in -16 .. 15 or else Values (2) not in -8 .. 7 then
         Selector := Bits_877;
      elsif Values (0) not in -2 .. 1 or else Values (1) not in -2 .. 1 or else Values (2) not in -2 .. 1 then
         Selector := Bits_554;
      else
         Selector := Bits_2;
      end if;

      case Selector is
         when Bits_2 =>
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (U0 and 3, 4)
                      or Interfaces.Shift_Left (U1 and 3, 2) or (U2 and 3)));
         when Bits_554 =>
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (Unsigned_32'(Bits_554), 6)
                                  or Interfaces.Shift_Left (U0 and 16#1F#, 1)
                                                            or Interfaces.Shift_Right (U1 and 16#1F#, 4)));
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (U1 and 16#0F#, 4) or (U2 and 16#0F#)));
         when Bits_877 =>
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (Unsigned_32'(Bits_877), 6)
                      or Interfaces.Shift_Right (U0 and 16#FF#, 2)));
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (U0 and 3, 6) or Interfaces.Shift_Right (U1 and 16#7F#, 1)));
            Write_U8 (B, S, Byte (Interfaces.Shift_Left (U1 and 1, 7) or (U2 and 16#7F#)));
         when others =>
            declare
               Sel : constant Unsigned_32 := Byte_Selector (Values);
            begin
               Write_U8 (B, S, Byte (Interfaces.Shift_Left (Unsigned_32'(Bits_32), 6) or (Sel and 16#3F#)));
               Write_Bytes (B, S, Values, Sel);
            end;
      end case;
   end Write_Tag2_3S_Variable;

   ---------------------
   -- Write_Tag8_4S16 --
   ---------------------

   procedure Write_Tag8_4S16 (B : in out Byte_Array; S : in out Stream; Values : Quad) is
      Field_Zero  : constant := 0;
      Field_4Bit  : constant := 1;
      Field_8Bit  : constant := 2;
      Field_16Bit : constant := 3;
      Selector    : Unsigned_32 := 0;
      Nibble_Open : Boolean := False;
      Buffer      : Byte := 0;
   begin
      --  The first field takes the low bits of the selector.
      for X in reverse Values'Range loop
         Selector := Interfaces.Shift_Left (Selector, 2);
         if Values (X) = 0 then
            null;
         elsif Values (X) in -8 .. 7 then
            Selector := Selector or Field_4Bit;
         elsif Values (X) in -128 .. 127 then
            Selector := Selector or Field_8Bit;
         else
            Selector := Selector or Field_16Bit;
         end if;
      end loop;
      Write_U8 (B, S, Low_Byte (Selector));

      for X in Values'Range loop
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry
                                and then S.Next in S.Next'Loop_Entry .. S.Next'Loop_Entry + 2 * X);
         declare
            U : constant Unsigned_32 := Bits (Values (X));
         begin
            case Selector and 3 is
               when Field_Zero =>
                  null;
               when Field_4Bit =>
                  if not Nibble_Open then
                     --  High nibble first.
                     Buffer := Byte (Interfaces.Shift_Left (U and 16#0F#, 4));
                     Nibble_Open := True;
                  else
                     Write_U8 (B, S, Buffer or Byte (U and 16#0F#));
                     Nibble_Open := False;
                  end if;
               when Field_8Bit =>
                  if not Nibble_Open then
                     Write_U8 (B, S, Low_Byte (U));
                  else
                     --  The high bits of the value close the open nibble, the
                     --  low bits open the next.
                     Write_U8 (B, S, Buffer or Byte (Interfaces.Shift_Right (U, 4) and 16#0F#));
                     Buffer := Byte (Interfaces.Shift_Left (U and 16#0F#, 4));
                  end if;
               when others =>
                  if not Nibble_Open then
                     Write_U8 (B, S, Byte_At (U, 8));
                     Write_U8 (B, S, Low_Byte (U));
                  else
                     Write_U8 (B, S, Buffer or Byte (Interfaces.Shift_Right (U, 12) and 16#0F#));
                     Write_U8 (B, S, Byte_At (U, 4));
                     Buffer := Byte (Interfaces.Shift_Left (U and 16#0F#, 4));
                  end if;
            end case;
         end;
         Selector := Interfaces.Shift_Right (Selector, 2);
      end loop;

      if Nibble_Open then
         Write_U8 (B, S, Buffer);
      end if;
   end Write_Tag8_4S16;

   ---------------------
   -- Write_Tag8_8SVB --
   ---------------------

   procedure Write_Tag8_8SVB (B : in out Byte_Array; S : in out Stream; Values : Int32_Array; Count : Natural) is
      Header : Unsigned_32 := 0;
   begin
      if Count = 0 then
         return;
      end if;
      if Count = 1 then
         Write_Signed_VB (B, S, Values (Values'First));
         return;
      end if;

      --  The first field takes the low bit of the header.
      for I in reverse 0 .. Count - 1 loop
         Header := Interfaces.Shift_Left (Header, 1);
         if Values (Values'First + I) /= 0 then
            Header := Header or 1;
         end if;
      end loop;
      Write_U8 (B, S, Low_Byte (Header));

      for I in 0 .. Count - 1 loop
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry
                                and then S.Next in S.Next'Loop_Entry .. S.Next'Loop_Entry + Max_VB * I);
         if Values (Values'First + I) /= 0 then
            Write_Signed_VB (B, S, Values (Values'First + I));
         end if;
      end loop;
   end Write_Tag8_8SVB;

   ---------------
   -- Write_U32 --
   ---------------

   procedure Write_U32 (B : in out Byte_Array; S : in out Stream; Value : Unsigned_32) is
   begin
      Stream_Buffers.Write_U32 (B, S, Value);
   end Write_U32;

   -----------------
   -- Write_Float --
   -----------------

   procedure Write_Float (B : in out Byte_Array; S : in out Stream; Value : Float) is
   begin
      Stream_Buffers.Write_U32 (B, S, Float_Bits.To_Bits (Value));
   end Write_Float;

end Adaflight.Blackbox_Encoding;
