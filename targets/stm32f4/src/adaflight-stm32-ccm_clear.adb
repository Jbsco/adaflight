with Interfaces;
with System.Storage_Elements; use System.Storage_Elements;

package body Adaflight.STM32.CCM_Clear is

   CCM_Start : Character with Import, Convention => C, External_Name => "__ccmbss_start";
   CCM_End   : Character with Import, Convention => C, External_Name => "__ccmbss_end";

   procedure Clear is
      Length : constant Integer_Address := To_Integer (CCM_End'Address) - To_Integer (CCM_Start'Address);
   begin
      if Length > 0 then
         declare
            Words : array (0 .. Natural (Length / 4) - 1) of Interfaces.Unsigned_32
              with Import, Volatile, Address => CCM_Start'Address;
         begin
            for W of Words loop
               W := 0;
            end loop;
         end;
      end if;
   end Clear;

   type Start_Hook is access procedure with Convention => C;
   Entry_Hook : constant Start_Hook := Clear'Access
     with Export, External_Name => "adaflight_ccm_clear_entry", Linker_Section => ".init_array.00000";

end Adaflight.STM32.CCM_Clear;
