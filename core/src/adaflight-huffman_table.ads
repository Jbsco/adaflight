--  The fixed Huffman code table of the flight log read-back.

with Interfaces;

package Adaflight.Huffman_Table with SPARK_Mode, Pure is

   Table_Size : constant := 257;
   EOF_Symbol : constant := 256;
   subtype Symbol is Natural range 0 .. Table_Size - 1;

   subtype Code_Length is Natural range 0 .. 15;
   subtype Code_Bits is Interfaces.Unsigned_16 range 0 .. 16#FFF#;

   type Huffman_Code is record
      Len  : Code_Length;
      Code : Code_Bits;
   end record;

   function Code_Of (S : Symbol) return Huffman_Code
     with Post => Code_Of'Result.Len in 2 .. 12;

end Adaflight.Huffman_Table;
