--  The external interrupt lines a shared vector serves: each vector's lines,
--  and the order a vector's handler calls the callbacks of its pending
--  lines, the highest line first.
with Interfaces; use Interfaces;

package Adaflight.EXTI_Lines with SPARK_Mode is

   type Line is range 0 .. 15;
   subtype Line_Mask is Unsigned_16;

   function Bit (L : Line) return Line_Mask is (Shift_Left (1, Natural (L)));

   --  The interrupt vectors of the lines: one each for lines 0 to 4, one for
   --  5 to 9 and one for 10 to 15.
   type Vector is (EXTI0, EXTI1, EXTI2, EXTI3, EXTI4, EXTI9_5, EXTI15_10);
   Lines_Of : constant array (Vector) of Line_Mask :=
     (EXTI0 => 16#0001#, EXTI1 => 16#0002#, EXTI2 => 16#0004#, EXTI3 => 16#0008#, EXTI4 => 16#0010#,
      EXTI9_5 => 16#03E0#, EXTI15_10 => 16#FC00#);

   --  The highest pending line, taken out of the pending lines.
   procedure Take_Highest (Pending : in out Line_Mask; Taken : out Line)
     with Global => null,
          Pre    => Pending /= 0,
          Post   => (Pending'Old and Bit (Taken)) /= 0
                    and then Pending = (Pending'Old and not Bit (Taken))
                    and then (for all L in Line => (if L > Taken then (Pending'Old and Bit (L)) = 0));

end Adaflight.EXTI_Lines;
