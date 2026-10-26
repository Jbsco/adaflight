with GNAT.OS_Lib;
package body Adaflight.STM32.MCU is
   --  A fixed identifier for the host image.
   function UID return Identifier is ((16#00AD_A000#, 16#4F57_4E00#, 16#0000_0001#));

   --  A reset ends the process, which the caller starts again.
   procedure Reset is
   begin
      GNAT.OS_Lib.OS_Exit (0);
   end Reset;
end Adaflight.STM32.MCU;
