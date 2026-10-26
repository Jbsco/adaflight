--  The host's SPI buses, where no device answers.
package body Adaflight.STM32.SPI is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Running : array (Bus) of Boolean := (others => False);

   procedure Init (B : Bus; SCK, SDI, SDO : Pin) is
      pragma Unreferenced (SCK, SDI, SDO);
   begin
      Running (B) := True;
   end Init;

   function Started (B : Bus) return Boolean is (Running (B));

   function Divider (Hz : Interfaces.Unsigned_32) return Interfaces.Unsigned_16 is
      Clock   : Interfaces.Unsigned_32 := Bus_Clock_Hz / 2;
      Divisor : Interfaces.Unsigned_16 := 2;
   begin
      while Clock > Hz and then Divisor < 256 loop
         Divisor := Divisor * 2;
         Clock := Clock / 2;
      end loop;
      return Divisor;
   end Divider;

   function Clock_Of (Divisor : Interfaces.Unsigned_16) return Interfaces.Unsigned_32 is
     (Bus_Clock_Hz / Interfaces.Unsigned_32 (Interfaces.Unsigned_16'Max (1, Divisor)));

   procedure Set_Divisor (B : Bus; Divisor : Interfaces.Unsigned_16) is null;

   procedure Transfer (B : Bus; Tx : Byte_Array; Rx : out Byte_Array) is
      pragma Unreferenced (B, Tx);
   begin
      Rx := (others => 16#FF#);
   end Transfer;
end Adaflight.STM32.SPI;
