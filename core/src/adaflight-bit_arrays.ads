--  Bit arrays stored as 32-bit words, indexed by bit number.

with Interfaces;

package Adaflight.Bit_Arrays with SPARK_Mode, Pure is

   use type Interfaces.Unsigned_32;

   subtype Word is Interfaces.Unsigned_32;
   Word_Bits : constant := 32;

   Max_Words : constant := 2 ** 20;
   subtype Word_Index is Natural range 0 .. Max_Words;
   type Bit_Array is array (Word_Index range <>) of Word;

   function In_Range (A : Bit_Array; Bit : Natural) return Boolean is
     (Bit / Word_Bits in A'Range);

   function Get (A : Bit_Array; Bit : Natural) return Boolean
     with Pre => In_Range (A, Bit);

   procedure Set (A : in out Bit_Array; Bit : Natural)
     with Pre  => In_Range (A, Bit),
          Post => Get (A, Bit);

   procedure Clear (A : in out Bit_Array; Bit : Natural)
     with Pre  => In_Range (A, Bit),
          Post => not Get (A, Bit);

   procedure Copy_Bit (A : in out Bit_Array; From : Natural; To : Natural)
     with Pre  => In_Range (A, From) and then In_Range (A, To),
          Post => Get (A, To) = Get (A'Old, From);

   --  Exclusive or of two arrays of the same shape into Dest.
   procedure Xor_Into (Dest : out Bit_Array; Op1 : Bit_Array; Op2 : Bit_Array)
     with Pre => Dest'First = Op1'First and then Dest'Last = Op1'Last
       and then Op1'First = Op2'First and then Op1'Last = Op2'Last;

end Adaflight.Bit_Arrays;
