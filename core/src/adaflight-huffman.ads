--  Huffman encoder for the flight log read-back, streaming bits into a
--  caller owned byte array with the fixed code table of the reference.

with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Huffman with SPARK_Mode, Pure is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   --  Bit position within the current output byte, one bit set.
   subtype Bit_Mask is Byte
     with Static_Predicate => Bit_Mask in 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128;

   type Encoder is record
      Base          : Buffer_Index := 0;
      Position      : Buffer_Index := 0;
      Bytes_Written : Buffer_Index := 0;
      Out_Buf_Len   : Buffer_Index := 1;
      Out_Bit       : Bit_Mask := 16#80#;
   end record
     with Dynamic_Predicate =>
       Encoder.Bytes_Written <= Encoder.Out_Buf_Len
       and then Encoder.Position = Encoder.Base + Encoder.Bytes_Written;

   --  Starts an encoding into Output at Base with room for Out_Buf_Len
   --  bytes. The first output byte is cleared.
   procedure Start
     (E : out Encoder; Output : in out Byte_Array; Base : Buffer_Index; Out_Buf_Len : Buffer_Index)
     with Pre  => Out_Buf_Len >= 1 and then Base in Output'Range
       and then Base + Out_Buf_Len <= Output'Last,
          Post => E.Base = Base and then E.Position = Base and then E.Bytes_Written = 0
            and then E.Out_Buf_Len = Out_Buf_Len and then E.Out_Bit = 16#80#;

   --  Appends the codes of Input while the region has room for at least
   --  one more byte. Overflow reports that the region filled before the
   --  input was consumed; the first output byte of this call is then
   --  restored and the rest is left as written.
   procedure Encode
     (E : in out Encoder; Output : in out Byte_Array; Input : Byte_Array; Overflow : out Boolean)
     with Pre  => E.Base in Output'Range and then E.Base + E.Out_Buf_Len <= Output'Last
       and then E.Bytes_Written < E.Out_Buf_Len,
          Post => E.Base = E.Base'Old and then E.Out_Buf_Len = E.Out_Buf_Len'Old;

   --  Bytes holding at least one bit: the count the caller reports.
   function Length (E : Encoder) return Natural is
     (if E.Out_Bit /= 16#80# then E.Bytes_Written + 1 else E.Bytes_Written);

end Adaflight.Huffman;
