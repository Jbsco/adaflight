--  Integer encodings used by the flight log and the protocols: zigzag
--  mapping of signed values and unsigned variable-length integers.

with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Encoding with SPARK_Mode, Pure is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   subtype Integer_32 is Interfaces.Integer_32;

   --  Maps small magnitudes of either sign to small unsigned values.
   function Zigzag_Encode (Value : Integer_32) return Unsigned_32 is
     (if Value >= 0 then 2 * Unsigned_32 (Value) else 2 * Unsigned_32 (-(Value + 1)) + 1);

   Max_Varint_Bytes : constant := 5;

   --  Writes Value as a base 128 varint into Buffer starting at
   --  Buffer'First. Written is zero when Buffer is too short. Every byte
   --  below the last carries the continuation bit, including the value 128,
   --  which the reference emits as a single bare byte its decoder rejects.
   procedure Uvarint_Encode
     (Value : Unsigned_32; Buffer : in out Byte_Array; Written : out Natural)
     with Post => Written <= Max_Varint_Bytes and then Written <= Buffer'Length;

   type Decode_Status is (Decoded, Truncated, Overflow);

   --  Reads a base 128 varint from Buffer starting at Buffer'First. Consumed
   --  is the number of bytes read when Status is Decoded, and zero otherwise.
   procedure Uvarint_Decode
     (Buffer : Byte_Array; Value : out Unsigned_32; Consumed : out Natural; Status : out Decode_Status)
     with Post => Consumed <= Buffer'Length
       and then (if Status /= Decoded then Consumed = 0);

end Adaflight.Encoding;
