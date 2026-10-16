package body Adaflight.Number_Text with SPARK_Mode is

   function Decimal (V : Interfaces.Unsigned_16; Width : Positive) return String is
      R     : String (1 .. 5) := (others => ' ');
      N     : Natural := Natural (V);
      First : Positive range 1 .. 5;
   begin
      for K in reverse 1 .. 5 loop
         R (K) := Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
         First := K;
         exit when N = 0;
      end loop;
      return R (Positive'Min (First, 6 - Width) .. 5);
   end Decimal;

end Adaflight.Number_Text;
