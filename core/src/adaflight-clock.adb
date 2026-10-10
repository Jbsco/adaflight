package body Adaflight.Clock with SPARK_Mode is

   function Elapsed (Later : Interfaces.Unsigned_32; Earlier : Interfaces.Unsigned_32) return Interfaces.Integer_32 is
      D : constant Interfaces.Integer_64 := Interfaces.Integer_64 (Later) - Interfaces.Integer_64 (Earlier);
   begin
      if D > Interfaces.Integer_64 (Interfaces.Integer_32'Last) then
         return Interfaces.Integer_32 (D - 2 ** 32);
      elsif D < Interfaces.Integer_64 (Interfaces.Integer_32'First) then
         return Interfaces.Integer_32 (D + 2 ** 32);
      else
         return Interfaces.Integer_32 (D);
      end if;
   end Elapsed;

end Adaflight.Clock;
