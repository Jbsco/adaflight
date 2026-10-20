--  Numbers as decimal text, as the menus and the device status lines print
--  them.
with Interfaces;

package Adaflight.Number_Text with SPARK_Mode is

   --  A number in decimal, in as many places as it takes and at least the
   --  width, padded with spaces on the left.
   function Decimal (V : Interfaces.Unsigned_16; Width : Positive) return String
     with Pre  => Width <= 5,
          Post => Decimal'Result'Length in Width .. 5;

end Adaflight.Number_Text;
