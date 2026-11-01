with Adaflight.Maths;

package body Adaflight.Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   procedure Select_Mode (S : in out State; Number : Interfaces.Unsigned_8) is
   begin
      S.Selected := Natural (Number);
   end Select_Mode;

   procedure Set (S : in out State; M : Mode; I : Index; V : Integer_16) is
   begin
      if Selected (S, M) then
         S.Data (I) := V;
      end if;
   end Set;

   function Wrapped (V : Interfaces.Integer_32) return Integer_16 is
      Low : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32'Mod (V) and 16#FFFF#;
   begin
      return (if Low >= 16#8000# then Integer_16 (Interfaces.Integer_32 (Low) - 16#1_0000#) else Integer_16 (Low));
   end Wrapped;

   --  Past the half-even rounding's bound every float is an integer already.
   function Rounded (X : Float) return Integer_16 is
     (if abs X <= Float (Adaflight.Maths.Rounding_Bound) - 1.0
      then Wrapped (Interfaces.Integer_32 (Adaflight.Maths.Round_Half_Even (X)))
      else Wrapped (Interfaces.Integer_32 (X)));

   function Truncated (X : Float) return Integer_16 is
     (Wrapped (Interfaces.Integer_32 (Float'Truncation (X))));

end Adaflight.Debug;
