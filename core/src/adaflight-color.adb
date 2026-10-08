package body Adaflight.Color with SPARK_Mode is

   ------------
   -- To_RGB --
   ------------

   subtype Level is Natural range 0 .. 255;
   subtype Sixtieths is Natural range 0 .. 60;

   --  Base plus the fraction Phase / 60 of the span up to Val.
   function Blend (Val : Level; Base : Level; Phase : Sixtieths) return Component
     with Pre => Base <= Val
   is
      Span   : constant Natural := Val - Base;
      Scaled : constant Natural := Span * Phase;
   begin
      pragma Assert (Scaled <= Span * 60);
      pragma Assert (Scaled / 60 <= Span);
      return Component (Scaled / 60 + Base);
   end Blend;

   function To_RGB (C : HSV) return RGB is
      Val  : constant Natural := Natural (C.V);
      Sat  : constant Natural := 255 - Natural (C.S);
      Base : Level;
      Sector : constant Natural := C.H / 60;
      Phase  : constant Natural := C.H mod 60;
   begin
      if Sat = 0 then
         return (R => C.V, G => C.V, B => C.V);
      end if;
      Base := ((255 - Sat) * Val) / 256;
      pragma Assert ((255 - Sat) * Val <= 255 * Val);
      pragma Assert (Base <= Val);
      case Sector is
         when 0 =>
            return (R => C.V,
                    G => Blend (Val, Base, Phase),
                    B => Component (Base));
         when 1 =>
            return (R => Blend (Val, Base, 60 - Phase),
                    G => C.V,
                    B => Component (Base));
         when 2 =>
            return (R => Component (Base),
                    G => C.V,
                    B => Blend (Val, Base, Phase));
         when 3 =>
            return (R => Component (Base),
                    G => Blend (Val, Base, 60 - Phase),
                    B => C.V);
         when 4 =>
            return (R => Blend (Val, Base, Phase),
                    G => Component (Base),
                    B => C.V);
         when others =>
            return (R => C.V,
                    G => Component (Base),
                    B => Blend (Val, Base, 60 - Phase));
      end case;
   end To_RGB;

end Adaflight.Color;
