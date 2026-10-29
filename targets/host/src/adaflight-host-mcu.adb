with GNAT.OS_Lib;
package body Adaflight.STM32.MCU is
   --  A fixed identifier for the host image.
   function UID return Identifier is ((16#00AD_A000#, 16#4F57_4E00#, 16#0000_0001#));

   --  A reset ends the process, which the caller starts again.
   procedure Reset is
   begin
      GNAT.OS_Lib.OS_Exit (0);
   end Reset;

   --  The host has no backup registers and no bootloader: the request ends
   --  the process with status 2 so the caller can tell it from a reset.
   procedure Init_Persistent is null;

   function Software_Reset return Boolean is (False);

   procedure Reset_To_Bootloader is
   begin
      GNAT.OS_Lib.OS_Exit (2);
   end Reset_To_Bootloader;

   procedure Check_Bootloader_Request is null;
end Adaflight.STM32.MCU;
