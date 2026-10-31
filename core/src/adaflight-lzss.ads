with Adaflight.Bytes; use Adaflight.Bytes;

--  The decode of an LZSS stream with no entropy stage: a 32-bit big-endian
--  length, then tokens read most significant bit first, each a flag bit and
--  either an 8-bit literal or a 12-bit distance less one and a 4-bit count
--  less three that copy from the output already written.
package Adaflight.LZSS with SPARK_Mode, Pure is

   Offset_Bits : constant := 12;
   Count_Bits  : constant := 4;
   Min_Match   : constant := 3;

   --  The largest stream the decode reads, which keeps its bit count within
   --  the natural range.
   Max_Source : constant := 2 ** 24;

   type Status is (Done, Truncated, Bad_Length, Bad_Distance, Overrun);

   --  Decodes Source into Target, which must be the length the stream's
   --  header gives; Truncated, Bad_Length, Bad_Distance and Overrun report a
   --  stream that ends early, a header of another length, a copy from before
   --  the output's start and a copy past its end.
   procedure Decode (Source : Byte_Array; Target : out Byte_Array; Result : out Status)
     with Pre => Source'Length <= Max_Source and then Target'Length <= Max_Source;

end Adaflight.LZSS;
