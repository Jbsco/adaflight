package body Adaflight.Bytes with SPARK_Mode is

   -----------------
   -- CRC16_CCITT --
   -----------------

   function CRC16_CCITT (CRC : Unsigned_16; A : Byte) return Unsigned_16 is
      C : Unsigned_16 := CRC xor Interfaces.Shift_Left (Unsigned_16 (A), 8);
   begin
      for I in 1 .. 8 loop
         if (C and 16#8000#) /= 0 then
            C := Interfaces.Shift_Left (C, 1) xor 16#1021#;
         else
            C := Interfaces.Shift_Left (C, 1);
         end if;
      end loop;
      return C;
   end CRC16_CCITT;

   ------------------------
   -- CRC16_CCITT_Update --
   ------------------------

   function CRC16_CCITT_Update (CRC : Unsigned_16; Data : Byte_Array) return Unsigned_16 is
      C : Unsigned_16 := CRC;
   begin
      for I in Data'Range loop
         C := CRC16_CCITT (C, Data (I));
      end loop;
      return C;
   end CRC16_CCITT_Update;

   ----------
   -- CRC8 --
   ----------

   function CRC8 (CRC : Byte; A : Byte; Poly : Byte) return Byte is
      C : Byte := CRC xor A;
   begin
      for I in 1 .. 8 loop
         if (C and 16#80#) /= 0 then
            C := Interfaces.Shift_Left (C, 1) xor Poly;
         else
            C := Interfaces.Shift_Left (C, 1);
         end if;
      end loop;
      return C;
   end CRC8;

   -----------------
   -- CRC8_Update --
   -----------------

   function CRC8_Update (CRC : Byte; Data : Byte_Array; Poly : Byte) return Byte is
      C : Byte := CRC;
   begin
      for I in Data'Range loop
         C := CRC8 (C, Data (I), Poly);
      end loop;
      return C;
   end CRC8_Update;

   ---------------------
   -- CRC8_Xor_Update --
   ---------------------

   function CRC8_Xor_Update (CRC : Byte; Data : Byte_Array) return Byte is
      C : Byte := CRC;
   begin
      for I in Data'Range loop
         C := C xor Data (I);
      end loop;
      return C;
   end CRC8_Xor_Update;

   ----------------
   -- FNV_Update --
   ----------------

   function FNV_Update (Hash : Unsigned_32; Data : Byte_Array) return Unsigned_32 is
      H : Unsigned_32 := Hash;
   begin
      for I in Data'Range loop
         H := H * FNV_Prime;
         H := H xor Unsigned_32 (Data (I));
      end loop;
      return H;
   end FNV_Update;

end Adaflight.Bytes;
