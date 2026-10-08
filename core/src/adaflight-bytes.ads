--  Byte arrays and the integrity codes computed over them.

with Interfaces;

package Adaflight.Bytes with SPARK_Mode, Pure is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Byte is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  Buffers are bounded far below the integer range so index arithmetic
   --  cannot overflow; no flight buffer approaches sixteen megabytes.
   Max_Buffer : constant := 2 ** 24;
   subtype Buffer_Index is Natural range 0 .. Max_Buffer;
   type Byte_Array is array (Buffer_Index range <>) of Byte;

   --  CRC-16 CCITT, polynomial 16#1021#, most significant bit first.
   function CRC16_CCITT (CRC : Unsigned_16; A : Byte) return Unsigned_16;
   function CRC16_CCITT_Update (CRC : Unsigned_16; Data : Byte_Array) return Unsigned_16;

   --  CRC-8 with a caller supplied polynomial, most significant bit first.
   DVB_S2_Polynomial : constant Byte := 16#D5#;
   Polynomial_BA     : constant Byte := 16#BA#;

   function CRC8 (CRC : Byte; A : Byte; Poly : Byte) return Byte;
   function CRC8_Update (CRC : Byte; Data : Byte_Array; Poly : Byte) return Byte;
   function CRC8_Xor_Update (CRC : Byte; Data : Byte_Array) return Byte;

   --  Fowler, Noll, and Vo hash, 32-bit variant 1a.
   FNV_Prime        : constant Unsigned_32 := 16777619;
   FNV_Offset_Basis : constant Unsigned_32 := 2166136261;

   function FNV_Update (Hash : Unsigned_32; Data : Byte_Array) return Unsigned_32;

end Adaflight.Bytes;
