with Ada.Unchecked_Conversion;
with Adaflight.Powers; use Adaflight.Powers;

package body Adaflight.Exponentials with SPARK_Mode is

   function To_Bits is new Ada.Unchecked_Conversion (Float, Interfaces.Unsigned_32);

   Mantissa_Scale : constant Float := 2.0 ** (-23);

   --  Product of a power of two and the polynomial factor, bounded by the
   --  two input ranges alone.
   function Scaled (Scale : Float; Poly : Float) return Float is (Scale * Poly)
     with Pre  => Scale in 2.0 ** (-125) .. 2.0 ** 126 and then Poly in 0.99 .. 2.1,
          Post => Scaled'Result in 0.0 .. Exp_Result_Max;

   --  Mantissa bits as the float in [1.0, 2.0) they denote.
   function Mantissa_Value (Bits : Interfaces.Unsigned_32) return Float is
     (1.0 + Float (Bits and 16#7F_FFFF#) * Mantissa_Scale)
     with Post => Mantissa_Value'Result in 1.0 .. 2.0;

   --  Exponent field and mantissa factor of a positive float, from its bits.
   procedure Decompose (X : Positive_Signal; Exponent : out Float; M : out Float)
     with Post => Exponent in 0.0 .. 255.0 and then M in 1.0 .. 2.0
   is
      Bits : constant Interfaces.Unsigned_32 := To_Bits (X);
   begin
      Exponent := Float (Interfaces.Shift_Right (Bits, 23) and 16#FF#);
      M := Mantissa_Value (Bits);
   end Decompose;

   ----------------
   -- Exp_Approx --
   ----------------

   function Exp_Approx (X : Exp_Argument) return Float is
      Mapped    : constant Float := 12102203.1615614 * X + 1065353216.0;
      Clamped   : constant Float :=
        Float'Max (0.0, Float'Min (Mapped, 2139095040.0));
      Truncated : constant Float := Float'Truncation (Clamped);
      Bits      : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Truncated);
      Exponent  : constant Integer := Integer (Interfaces.Shift_Right (Bits, 23));
      B         : constant Float := Mantissa_Value (Bits);
      T4        : constant Float := -2.19061993049215080032874e-3 + B * 1.3555747234758484073940937e-2;
      T3        : constant Float := 0.166617139319965966118107 + B * T4;
      T2        : constant Float := 0.312146713032169896138863 + B * T3;
      Poly      : constant Float := 0.509871020343597804469416 + B * T2;
   begin
      pragma Assert (Exponent in 2 .. 253);
      pragma Assert (T4 in 0.01 .. 0.03);
      pragma Assert (T3 in 0.17 .. 0.23);
      pragma Assert (T2 in 0.48 .. 0.78);
      pragma Assert (Poly in 0.99 .. 2.1);
      return Scaled (Power_Of_Two (Exponent - 127), Poly);
   end Exp_Approx;

   ----------------
   -- Log_Approx --
   ----------------

   function Log_Approx (X : Positive_Signal) return Float is
      Exponent : Float;
      M        : Float;
   begin
      Decompose (X, Exponent, M);
      declare
         T4     : constant Float := -0.288739945 + M * 3.110401639e-2;
         T3     : constant Float := 1.130626167 + M * T4;
         T2     : constant Float := -2.461222105 + M * T3;
         T1     : constant Float := 3.529304993 + M * T2;
         Poly   : constant Float := M * T1;
         Offset : constant Float := -89.970756366 + 0.69314718055995 * Exponent;
      begin
         pragma Assert (T4 in -0.26 .. -0.22);
         pragma Assert (T3 in 0.6 .. 0.92);
         pragma Assert (T2 in -1.9 .. -0.6);
         pragma Assert (T1 in -0.3 .. 3.0);
         pragma Assert (Poly in -0.7 .. 6.0);
         pragma Assert (Offset in -90.0 .. 87.0);
         return Poly + Offset;
      end;
   end Log_Approx;

   ----------------
   -- Pow_Approx --
   ----------------

   function Pow_Approx (Base : Positive_Signal; Exponent : Float) return Float is
     (Exp_Approx (Exponent * Log_Approx (Base)));

end Adaflight.Exponentials;
