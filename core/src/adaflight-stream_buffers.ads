--  Serializer and deserializer over a caller owned byte array.
--
--  A Stream holds two indices into the array: the next position and the
--  end of the valid region. Writes require room by precondition, so no
--  write can run past the array. Reads past the end return zero and never
--  touch the array, as the protocols expect.

with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Stream_Buffers with SPARK_Mode, Pure is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Position is Natural range 0 .. Max_Buffer + 1;

   type Stream is record
      Next : Position := 0;
      Last : Position := 0;
   end record
     with Dynamic_Predicate => Stream.Next <= Stream.Last;

   --  Positions are within the array when Last is at most one past its
   --  last index.
   function Fits (S : Stream; B : Byte_Array) return Boolean is
     (S.Next >= B'First and then S.Last <= B'Last + 1);

   function Remaining (S : Stream) return Natural is (S.Last - S.Next);

   procedure Init (S : out Stream; First : Position; Last : Position)
     with Pre  => First <= Last,
          Post => S.Next = First and then S.Last = Last;

   procedure Write_U8 (B : in out Byte_Array; S : in out Stream; V : Byte)
     with Pre  => Fits (S, B) and then Remaining (S) >= 1,
          Post => S.Next = S.Next'Old + 1 and then S.Last = S.Last'Old;

   procedure Write_U16 (B : in out Byte_Array; S : in out Stream; V : Unsigned_16)
     with Pre  => Fits (S, B) and then Remaining (S) >= 2,
          Post => S.Next = S.Next'Old + 2 and then S.Last = S.Last'Old;

   procedure Write_U32 (B : in out Byte_Array; S : in out Stream; V : Unsigned_32)
     with Pre  => Fits (S, B) and then Remaining (S) >= 4,
          Post => S.Next = S.Next'Old + 4 and then S.Last = S.Last'Old;

   procedure Write_U16_Big_Endian (B : in out Byte_Array; S : in out Stream; V : Unsigned_16)
     with Pre  => Fits (S, B) and then Remaining (S) >= 2,
          Post => S.Next = S.Next'Old + 2 and then S.Last = S.Last'Old;

   procedure Write_U32_Big_Endian (B : in out Byte_Array; S : in out Stream; V : Unsigned_32)
     with Pre  => Fits (S, B) and then Remaining (S) >= 4,
          Post => S.Next = S.Next'Old + 4 and then S.Last = S.Last'Old;

   procedure Fill (B : in out Byte_Array; S : in out Stream; Value : Byte; Count : Natural)
     with Pre  => Fits (S, B) and then Remaining (S) >= Count,
          Post => S.Next = S.Next'Old + Count and then S.Last = S.Last'Old;

   procedure Write_Data (B : in out Byte_Array; S : in out Stream; Data : Byte_Array)
     with Pre  => Fits (S, B) and then Remaining (S) >= Data'Length,
          Post => S.Next = S.Next'Old + Data'Length and then S.Last = S.Last'Old;

   --  A string prefixed by its length in one byte, truncated at 255.
   procedure Write_Prefixed_String (B : in out Byte_Array; S : in out Stream; Text : String)
     with Pre  => Fits (S, B)
       and then Remaining (S) >= 1 + Natural'Min (Text'Length, 255),
          Post => S.Next = S.Next'Old + 1 + Natural'Min (Text'Length, 255) and then S.Last = S.Last'Old;

   procedure Write_String (B : in out Byte_Array; S : in out Stream; Text : String)
     with Pre  => Fits (S, B) and then Text'Length <= Max_Buffer and then Remaining (S) >= Text'Length,
          Post => S.Next = S.Next'Old + Text'Length and then S.Last = S.Last'Old;

   procedure Write_String_With_Terminator (B : in out Byte_Array; S : in out Stream; Text : String)
     with Pre  => Fits (S, B) and then Text'Length < Natural'Last
       and then Remaining (S) >= Text'Length + 1,
          Post => S.Next = S.Next'Old + Text'Length + 1 and then S.Last = S.Last'Old;

   procedure Read_U8 (B : Byte_Array; S : in out Stream; V : out Byte)
     with Pre  => Fits (S, B),
          Post => S.Last = S.Last'Old and then S.Next >= S.Next'Old and then S.Next <= S.Next'Old + 1;

   procedure Read_U16 (B : Byte_Array; S : in out Stream; V : out Unsigned_16)
     with Pre  => Fits (S, B),
          Post => S.Last = S.Last'Old and then S.Next >= S.Next'Old and then S.Next <= S.Next'Old + 2;

   procedure Read_U32 (B : Byte_Array; S : in out Stream; V : out Unsigned_32)
     with Pre  => Fits (S, B),
          Post => S.Last = S.Last'Old and then S.Next >= S.Next'Old and then S.Next <= S.Next'Old + 4;

   --  Copies what remains, up to Data'Length bytes, and zero fills the rest.
   procedure Read_Data (B : Byte_Array; S : in out Stream; Data : out Byte_Array)
     with Pre  => Fits (S, B),
          Post => S.Last = S.Last'Old and then S.Next >= S.Next'Old
            and then S.Next <= S.Next'Old + Data'Length;

   --  Moves the position forward, stopping at the end.
   procedure Advance (S : in out Stream; Count : Natural)
     with Post => S.Last = S.Last'Old
       and then (if Count >= S.Last'Old - S.Next'Old then S.Next = S.Last else S.Next = S.Next'Old + Count);

   --  Turns a written region into one to read from Base.
   procedure Switch_To_Reader (S : in out Stream; Base : Position)
     with Pre  => Base <= S.Next,
          Post => S.Next = Base and then S.Last = S.Next'Old;

   --  Integrity codes over the region from Start to the position, appended
   --  at the position.
   procedure Append_CRC16_CCITT (B : in out Byte_Array; S : in out Stream; Start : Natural)
     with Pre  => Fits (S, B) and then Start in B'First .. S.Next
       and then Remaining (S) >= 2,
          Post => S.Next = S.Next'Old + 2 and then S.Last = S.Last'Old;

   procedure Append_CRC8 (B : in out Byte_Array; S : in out Stream; Start : Natural; Poly : Byte)
     with Pre  => Fits (S, B) and then Start in B'First .. S.Next
       and then Remaining (S) >= 1,
          Post => S.Next = S.Next'Old + 1 and then S.Last = S.Last'Old;

   procedure Append_Xor (B : in out Byte_Array; S : in out Stream; Start : Natural)
     with Pre  => Fits (S, B) and then Start in B'First .. S.Next
       and then Remaining (S) >= 1,
          Post => S.Next = S.Next'Old + 1 and then S.Last = S.Last'Old;

end Adaflight.Stream_Buffers;
