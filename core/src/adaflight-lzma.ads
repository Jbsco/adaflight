with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The decode of an LZMA stream with the smallest model: a 32-bit big-endian
--  length, then raw LZMA1 data with no literal context bits, no literal
--  position bits and no position bits, its dictionary the output already
--  written. The decode stops at the length, so an end marker after it is not
--  read.
package Adaflight.LZMA with SPARK_Mode, Pure is

   --  The largest stream the decode reads and output it writes.
   Max_Source : constant := 2 ** 24;

   type Status is (Done, Truncated, Bad_Length, Bad_Data);

   --  An adaptive bit probability, in 2048ths.
   subtype Probability is Interfaces.Unsigned_16 range 1 .. 2047;

   type Probabilities is array (Natural range <>) of Probability;

   --  The model's probabilities: the decode sets them at its start, so the
   --  caller only provides their room.
   type Model is record
      Is_Match     : Probabilities (0 .. 11);
      Is_Rep       : Probabilities (0 .. 11);
      Is_Rep_G0    : Probabilities (0 .. 11);
      Is_Rep_G1    : Probabilities (0 .. 11);
      Is_Rep_G2    : Probabilities (0 .. 11);
      Is_Rep0_Long : Probabilities (0 .. 11);
      Pos_Slot     : Probabilities (0 .. 4 * 64 - 1);
      Pos_Special  : Probabilities (0 .. 114);
      Align        : Probabilities (0 .. 15);
      Len_Choice   : Probabilities (0 .. 1);
      Len_Low      : Probabilities (0 .. 7);
      Len_Mid      : Probabilities (0 .. 7);
      Len_High     : Probabilities (0 .. 255);
      Rep_Choice   : Probabilities (0 .. 1);
      Rep_Low      : Probabilities (0 .. 7);
      Rep_Mid      : Probabilities (0 .. 7);
      Rep_High     : Probabilities (0 .. 255);
      Literal      : Probabilities (0 .. 16#2FF#);
   end record;

   --  Decodes Source into Target, which must be the length the stream's
   --  header gives, with M as the model's room; Truncated, Bad_Length and
   --  Bad_Data report a stream that ends early, a header of another length,
   --  and a range coder or match the format does not allow.
   procedure Decode (Source : Byte_Array; Target : out Byte_Array; M : out Model; Result : out Status)
     with Pre => Source'Length <= Max_Source and then Target'Length <= Max_Source;

end Adaflight.LZMA;
