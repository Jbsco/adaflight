package body Adaflight.Bit_Arrays with SPARK_Mode is

   function Mask (Bit : Natural) return Word is
     (Interfaces.Shift_Left (Word'(1), Bit mod Word_Bits))
     with Inline;

   ---------
   -- Get --
   ---------

   function Get (A : Bit_Array; Bit : Natural) return Boolean is
     ((A (Bit / Word_Bits) and Mask (Bit)) /= 0);

   ---------
   -- Set --
   ---------

   procedure Set (A : in out Bit_Array; Bit : Natural) is
   begin
      A (Bit / Word_Bits) := A (Bit / Word_Bits) or Mask (Bit);
   end Set;

   -----------
   -- Clear --
   -----------

   procedure Clear (A : in out Bit_Array; Bit : Natural) is
   begin
      A (Bit / Word_Bits) := A (Bit / Word_Bits) and not Mask (Bit);
   end Clear;

   --------------
   -- Copy_Bit --
   --------------

   procedure Copy_Bit (A : in out Bit_Array; From : Natural; To : Natural) is
   begin
      if Get (A, From) then
         Set (A, To);
      else
         Clear (A, To);
      end if;
   end Copy_Bit;

   --------------
   -- Xor_Into --
   --------------

   procedure Xor_Into (Dest : out Bit_Array; Op1 : Bit_Array; Op2 : Bit_Array) is
   begin
      for I in Dest'Range loop
         Dest (I) := Op1 (I) xor Op2 (I);
      end loop;
   end Xor_Into;

end Adaflight.Bit_Arrays;
