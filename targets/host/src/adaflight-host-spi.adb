package body Adaflight.STM32.SPI is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   procedure Init (SCK, SDI, SDO : Pin) is null;

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

   procedure Set_Divisor (Divisor : Interfaces.Unsigned_16) is null;

   --  No device answers on the host's bus.
   procedure Transfer (Tx : Byte_Array; Rx : out Byte_Array) is
      pragma Unreferenced (Tx);
   begin
      Rx := (others => 16#FF#);
   end Transfer;
end Adaflight.STM32.SPI;
