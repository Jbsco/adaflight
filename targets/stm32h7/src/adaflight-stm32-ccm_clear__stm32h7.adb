with Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;

package body Adaflight.STM32.CCM_Clear is

   CCM_Start : Character with Import, Convention => C, External_Name => "__ccmbss_start";
   CCM_End   : Character with Import, Convention => C, External_Name => "__ccmbss_end";
   DMA_Start : Character with Import, Convention => C, External_Name => "__dmabss_start";
   DMA_End   : Character with Import, Convention => C, External_Name => "__dmabss_end";

   procedure Zero (First, Last : System.Address) is
      Length : constant Integer_Address := To_Integer (Last) - To_Integer (First);
   begin
      if Length > 0 then
         declare
            Words : array (0 .. Natural (Length / 4) - 1) of Interfaces.Unsigned_32
              with Import, Volatile, Address => First;
         begin
            for W of Words loop
               W := 0;
            end loop;
         end;
      end if;
   end Zero;

   --  The data tightly coupled memory's zeroed data and the D2 RAM's DMA buffers.
   procedure Clear is
   begin
      Zero (CCM_Start'Address, CCM_End'Address);
      Zero (DMA_Start'Address, DMA_End'Address);
   end Clear;

   type Start_Hook is access procedure with Convention => C;
   Entry_Hook : constant Start_Hook := Clear'Access
     with Export, External_Name => "adaflight_ccm_clear_entry", Linker_Section => ".init_array.00000";

end Adaflight.STM32.CCM_Clear;
