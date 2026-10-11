--  The field encodings of the flight log: variable byte integers with the
--  zigzag mapping for signed values, fixed 16 and 32-bit words, the float as
--  its bit pattern, and the packed groups of three, four, and up to eight
--  fields with a selector that names each field's width. Every encoder
--  writes into a stream over a caller owned array and asks for the room its
--  longest form needs.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers; use Adaflight.Stream_Buffers;

package Adaflight.Blackbox_Encoding with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   subtype Integer_32 is Interfaces.Integer_32;
   subtype Integer_16 is Interfaces.Integer_16;

   Max_Values : constant := 64;
   subtype Value_Count is Natural range 0 .. Max_Values;
   subtype Value_Index is Natural range 0 .. Max_Values - 1;
   type Int32_Array is array (Value_Index range <>) of Integer_32;
   type Int16_Array is array (Value_Index range <>) of Integer_16;
   subtype Triple is Int32_Array (0 .. 2);
   subtype Quad is Int32_Array (0 .. 3);

   Max_VB          : constant := 5;
   Max_Tag2_3      : constant := 13;
   Max_Tag8_4S16   : constant := 10;
   Max_Tag8_Fields : constant := 8;

   --  Seven bits per byte, low bits first, the high bit set while more follow.
   procedure Write_Unsigned_VB (B : in out Byte_Array; S : in out Stream; Value : Unsigned_32)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_VB,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Max_VB;

   procedure Write_Signed_VB (B : in out Byte_Array; S : in out Stream; Value : Integer_32)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_VB,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Max_VB;

   procedure Write_Signed_VB_Array (B : in out Byte_Array; S : in out Stream; Values : Int32_Array)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_VB * Values'Length,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + Max_VB * Values'Length;

   procedure Write_Signed16_VB_Array (B : in out Byte_Array; S : in out Stream; Values : Int16_Array)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_VB * Values'Length,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + Max_VB * Values'Length;

   procedure Write_S16 (B : in out Byte_Array; S : in out Stream; Value : Integer_16)
     with Pre  => Fits (S, B) and then Remaining (S) >= 2,
          Post => S.Last = S.Last'Old and then S.Next = S.Next'Old + 2;

   --  A two-bit selector then three signed fields of 2, 4, 6 bits, or of 1 to
   --  4 bytes each behind a second selector.
   procedure Write_Tag2_3S32 (B : in out Byte_Array; S : in out Stream; Values : Triple)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Tag2_3,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Max_Tag2_3;

   --  The same with the 5-5-4 and 8-7-7 bit splits in place of the 4 and 6
   --  bit fields, returning the selector.
   procedure Write_Tag2_3S_Variable (B : in out Byte_Array; S : in out Stream; Values : Triple;
                                     Selector : out Natural)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Tag2_3,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Max_Tag2_3
                  and then Selector <= 3;

   --  A one-byte selector then four signed fields of 0, 4, 8 or 16 bits,
   --  packed by nibbles.
   procedure Write_Tag8_4S16 (B : in out Byte_Array; S : in out Stream; Values : Quad)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Tag8_4S16,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old + 1 .. S.Next'Old + Max_Tag8_4S16;

   --  Up to eight signed fields: one field goes bare, more take a header
   --  byte that marks the fields that are not zero, then those as signed
   --  variable bytes.
   procedure Write_Tag8_8SVB (B : in out Byte_Array; S : in out Stream; Values : Int32_Array; Count : Natural)
     with Pre  => Fits (S, B) and then Count <= Max_Tag8_Fields and then Count <= Values'Length
                  and then Remaining (S) >= 1 + Max_VB * Count,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + 1 + Max_VB * Count;

   procedure Write_U32 (B : in out Byte_Array; S : in out Stream; Value : Unsigned_32)
     with Pre  => Fits (S, B) and then Remaining (S) >= 4,
          Post => S.Last = S.Last'Old and then S.Next = S.Next'Old + 4;

   procedure Write_Float (B : in out Byte_Array; S : in out Stream; Value : Float)
     with Pre  => Fits (S, B) and then Remaining (S) >= 4,
          Post => S.Last = S.Last'Old and then S.Next = S.Next'Old + 4;

end Adaflight.Blackbox_Encoding;
