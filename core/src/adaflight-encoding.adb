package body Adaflight.Encoding with SPARK_Mode is

   --------------------
   -- Uvarint_Encode --
   --------------------

   procedure Uvarint_Encode
     (Value : Unsigned_32; Buffer : in out Byte_Array; Written : out Natural)
   is
      V : Unsigned_32 := Value;
   begin
      Written := 0;
      for I in 0 .. Max_Varint_Bytes - 1 loop
         pragma Loop_Invariant (Written = 0);
         if I >= Buffer'Length then
            return;
         end if;
         pragma Assert (Buffer'First + I <= Max_Buffer);
         if V < 16#80# then
            Buffer (Buffer'First + I) := Byte (V);
            Written := I + 1;
            return;
         end if;
         Buffer (Buffer'First + I) := Byte (V and 16#7F#) or 16#80#;
         V := Interfaces.Shift_Right (V, 7);
      end loop;
   end Uvarint_Encode;

   --------------------
   -- Uvarint_Decode --
   --------------------

   procedure Uvarint_Decode
     (Buffer : Byte_Array; Value : out Unsigned_32; Consumed : out Natural; Status : out Decode_Status)
   is
      Shift : Natural := 0;
      Acc   : Unsigned_32 := 0;
   begin
      Value := 0;
      Consumed := 0;
      Status := Truncated;
      for I in 0 .. Buffer'Length - 1 loop
         pragma Loop_Invariant (Shift = 7 * I and then Shift <= 7 * Max_Buffer);
         declare
            B : constant Byte := Buffer (Buffer'First + I);
         begin
            if B < 16#80# then
               if I > 5 or else (I = 5 and then B > 1) then
                  Status := Overflow;
                  return;
               end if;
               Value := Acc or Interfaces.Shift_Left (Unsigned_32 (B), Shift);
               Consumed := I + 1;
               Status := Decoded;
               return;
            end if;
            if Shift <= 28 then
               Acc := Acc or Interfaces.Shift_Left (Unsigned_32 (B and 16#7F#), Shift);
            end if;
            Shift := Shift + 7;
         end;
      end loop;
   end Uvarint_Decode;

end Adaflight.Encoding;
