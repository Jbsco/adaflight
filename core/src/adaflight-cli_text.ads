--  Command line text: decimal numbers as the command line's C library
--  reads and prints them on a 32-bit target, letters compared without case,
--  and the board's serial port names.
with Interfaces; use Interfaces;
with Adaflight.Serial_Feature_Map;

package Adaflight.CLI_Text with SPARK_Mode is

   function Lower (Ch : Character) return Character is
     (if Ch in 'A' .. 'Z' then Character'Val (Character'Pos (Ch) + 32) else Ch);

   --  Whether two texts are equal without regard to case.
   function Same_Ignoring_Case (A, B : String) return Boolean is
     (A'Length = B'Length
      and then (for all I in 0 .. A'Length - 1 => Lower (A (A'First + I)) = Lower (B (B'First + I))));

   --  Whether a text contains a fragment without regard to case; an empty
   --  fragment is in every text.
   function Contains_Ignoring_Case (Text, Fragment : String) return Boolean;

   --  A decimal number after leading spaces and an optional sign, its value
   --  held at the 32-bit range, and the index after its last digit, or the
   --  text's first index and zero when no digit follows.
   procedure Parse_Signed (Text : String; Value : out Integer_32; Next : out Positive)
     with Pre  => Text'First >= 1 and then Text'Last < Positive'Last and then Text'First <= Text'Last + 1,
          Post => Next in Text'First .. Text'Last + 1,
          Always_Terminates;

   --  The same for an unsigned number: held at the unsigned 32-bit maximum,
   --  and a minus sign negates it modulo 2 ** 32.
   procedure Parse_Unsigned (Text : String; Value : out Unsigned_32; Next : out Positive)
     with Pre  => Text'First >= 1 and then Text'Last < Positive'Last and then Text'First <= Text'Last + 1,
          Post => Next in Text'First .. Text'Last + 1,
          Always_Terminates;

   --  A number as the C library's atoi reads it on a 32-bit target.
   function To_Integer (Text : String) return Integer_32
     with Pre => Text'First >= 1 and then Text'Last < Positive'Last and then Text'First <= Text'Last + 1;

   --  A number as the reference's fast float reader takes it: spaces and
   --  tabs, a sign, digits with an optional fraction, and an exponent held
   --  at 308. A number past the float range reads as the largest float, and
   --  zero with an exponent past the float range as zero.
   function Parse_Float (Text : String) return Float
     with Pre => Text'First >= 1 and then Text'Last < Positive'Last;

   --  A float in the reference's text form: rounded half away from zero to
   --  thousandths and held to the 32-bit range, then a space or a minus
   --  sign, the whole part and three decimals.
   function Float_Text (X : Float) return String
     with Post => Float_Text'Result'Length in 6 .. 23;

   --  A coordinate in degrees with up to seven decimals as ten-millionths of
   --  a degree: an optional sign, digits, and an optional point with digits,
   --  the decimals past seven ignored. OK is false for any other text and for
   --  a value past the 32-bit range.
   procedure Parse_Coordinate (Text : String; Value : out Integer_32; OK : out Boolean)
     with Pre => Text'First >= 1 and then Text'Last < Positive'Last;

   --  Ten-millionths of a degree as degrees with seven decimals.
   function Coordinate_Text (Value : Integer_32) return String
     with Post => Coordinate_Text'Result'First = 1 and then Coordinate_Text'Result'Length in 9 .. 12;

   --  A whole text as a decimal number with an optional sign, held at a
   --  million millions, and whether the text is one.
   procedure Parse_Whole (Text : String; Value : out Integer_64; OK : out Boolean)
     with Pre  => Text'First >= 1 and then Text'Last < Positive'Last,
          Post => Value in -10 ** 12 .. 10 ** 12;

   --  A number's decimal digits with its sign, without a leading space.
   function Decimal (V : Integer_64) return String
     with Post => Decimal'Result'Length in 1 .. 21;

   --  A text right-justified in a field, as the C library's %Nd and %Ns
   --  print it: spaces before it up to the width, or the text alone when it
   --  is longer.
   function Right_Justified (Text : String; Width : Natural) return String
     with Pre  => Text'Length <= 64 and then Width <= 64,
          Post => Right_Justified'Result'First = 1
                  and then Right_Justified'Result'Length = Natural'Max (Text'Length, Width);

   subtype Port_List is Serial_Feature_Map.Port_List;

   --  A serial port's name among the board's ports: NONE for no port, empty
   --  for an identifier the board does not have.
   function Port_Name (Id : Integer_64; Ports : Port_List) return String
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports;

   --  The port a name names among the board's ports, without regard to case.
   procedure Port_From_Name (Name : String; Ports : Port_List; Found : out Boolean; Id : out Integer_64)
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports;

end Adaflight.CLI_Text;
