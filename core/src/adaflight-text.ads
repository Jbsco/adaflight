--  Text conversions for the command line, the display, and the log headers:
--  the digits of a number in a base, the fixed form of a float with three
--  decimals, a float read from its text, the character classes and case
--  folds over the basic letters, the comparison and the search that ignore
--  case, and the formatter with its conversions behind a width and a zero
--  flag. Every writer takes the caller's buffer and reports the length it
--  used, and the buffer sizes the contracts ask for hold the longest form.
with Ada.Characters.Latin_1;
with Interfaces;

package Adaflight.Text with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   subtype Number_Base is Positive range 2 .. 36;

   Max_Digits         : constant := 32;
   Max_Signed_Length  : constant := Max_Digits + 1;
   Max_Decimal_Length : constant := 11;
   Max_Fixed_Length   : constant := 12;
   Fixed_Limit        : constant := 2.0E6;

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');
   function Is_Upper (C : Character) return Boolean is (C in 'A' .. 'Z');
   function Is_Lower (C : Character) return Boolean is (C in 'a' .. 'z');
   function Is_Alnum (C : Character) return Boolean is
     (Is_Digit (C) or else Is_Upper (C) or else Is_Lower (C));
   function Is_Space (C : Character) return Boolean is
     (C = ' ' or else C = Ada.Characters.Latin_1.HT or else C = Ada.Characters.Latin_1.LF
      or else C = Ada.Characters.Latin_1.VT or else C = Ada.Characters.Latin_1.FF
      or else C = Ada.Characters.Latin_1.CR);

   function To_Lower (C : Character) return Character is
     (if Is_Upper (C) then Character'Val (Character'Pos (C) + 32) else C);
   function To_Upper (C : Character) return Character is
     (if Is_Lower (C) then Character'Val (Character'Pos (C) - 32) else C);

   --  The difference of the first pair of characters that differ after the
   --  case fold, over at most Count characters, with the end of a text read
   --  as a character of code zero: zero when the texts agree that far.
   function Compare_Ignoring_Case (A, B : String; Count : Natural) return Integer
     with Post => Compare_Ignoring_Case'Result in -255 .. 255;

   function Compare_Ignoring_Case (A, B : String) return Integer is
     (Compare_Ignoring_Case (A, B, Natural'Last));

   --  The position in Haystack where Needle first matches ignoring case, zero
   --  when it does not or when Haystack is empty; an empty needle matches at
   --  the start.
   function Find_Ignoring_Case (Haystack, Needle : String) return Natural
     with Post => Find_Ignoring_Case'Result = 0 or else Find_Ignoring_Case'Result in Haystack'Range;

   --  The digits of Value in Base, letters past nine in lower or upper case.
   procedure Put_Unsigned (Value : Unsigned_32; Base : Number_Base; Upper : Boolean;
                           Buffer : in out String; Length : out Natural)
     with Pre  => Buffer'Length >= Max_Digits,
          Post => Length in 1 .. Max_Digits;

   --  Value in decimal with a minus sign when negative.
   procedure Put_Integer (Value : Integer_32; Buffer : in out String; Length : out Natural)
     with Pre  => Buffer'Length >= Max_Decimal_Length,
          Post => Length in 1 .. Max_Decimal_Length;

   --  Value in Base with uppercase letters and a minus sign when negative; a
   --  base outside 2 to 36 reads as ten.
   procedure Put_Integer_In_Base (Value : Integer_32; Base : Integer; Buffer : in out String; Length : out Natural)
     with Pre  => Buffer'Length >= Max_Signed_Length,
          Post => Length in 1 .. Max_Signed_Length;

   --  Value with three decimals behind a leading space or minus sign, rounded
   --  half away from zero at the third decimal.
   procedure Put_Fixed (Value : Float; Buffer : in out String; Length : out Natural)
     with Pre  => Buffer'Length >= Max_Fixed_Length and then abs Value <= Fixed_Limit,
          Post => Length in 6 .. Max_Fixed_Length;

   --  A float read from text: blanks, a sign, digits, a fraction, an exponent
   --  of ten with its sign, reading up to the first character that fits none
   --  of them. Magnitudes past 3.0E38 saturate at Float'Last.
   function To_Float (S : String) return Float
     with Pre => S'Last < Integer'Last;

   --  An argument of the formatter: a number as its 32 bits, a character as
   --  its code, or a slice of the caller's text pool.
   type Argument is record
      Bits  : Unsigned_32 := 0;
      First : Positive := 1;
      Last  : Natural := 0;
   end record;

   type Argument_List is array (Positive range <>) of Argument;

   function Int_Argument (Value : Integer_32) return Argument is
     (Bits => Unsigned_32'Mod (Value), First => 1, Last => 0);
   function Unsigned_Argument (Value : Unsigned_32) return Argument is
     (Bits => Value, First => 1, Last => 0);
   function Char_Argument (C : Character) return Argument is
     (Bits => Character'Pos (C), First => 1, Last => 0);
   function Text_Argument (First : Positive; Last : Natural) return Argument is
     (Bits => 0, First => First, Last => Last);

   --  The template's text with each conversion filled from the next argument:
   --  d, u, x, and X for a number in decimal or hexadecimal, c for a
   --  character, s for a text slice, and %% for the sign itself, a number or
   --  text behind an optional zero flag and width, and an l modifier that
   --  changes nothing. A template that ends inside a conversion stops the
   --  output there, a conversion with no argument left or with a slice outside
   --  the pool writes nothing, and Output holds at most its own length.
   procedure Format (Template : String; Args : Argument_List; Pool : String;
                     Output : in out String; Length : out Natural)
     with Pre  => Template'Last < Integer'Last,
          Post => Length <= Output'Length;

end Adaflight.Text;
