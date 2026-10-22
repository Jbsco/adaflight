with Adaflight.Bytes;

package body Adaflight.ESC_Info with SPARK_Mode is

   --------------------
   -- Checksum_Holds --
   --------------------

   function Checksum_Holds (F : Frame; K : Kind) return Boolean is
      Length : constant Positive := Length_Of (K);
      CRC    : Byte := 0;
   begin
      for I in 0 .. Length - 2 loop
         CRC := Bytes.CRC8 (CRC, F (I), 7);
      end loop;
      return CRC = F (Length - 1);
   end Checksum_Holds;

   ----------------------
   -- Type_Text_Length --
   ----------------------

   function Type_Text_Length (F : Frame) return Natural is
   begin
      for I in 0 .. 31 loop
         if F (31 + I) = 0 then
            return I;
         end if;
      end loop;
      return 32;
   end Type_Text_Length;

end Adaflight.ESC_Info;
