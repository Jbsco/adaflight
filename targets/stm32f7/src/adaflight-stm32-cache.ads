--  The core's caches, enabled before elaboration: code runs from flash over
--  the AXI bus at seven wait states, and the run-time library's start leaves
--  both Cortex-M7 caches off.
with System;
package Adaflight.STM32.Cache is
   pragma Linker_Options ("-Wl,--undefined=adaflight_cache_entry");

   procedure Enable
     with Export, Convention => C, External_Name => "adaflight_cache_enable";

   --  The data cache lines holding Length bytes from Address dropped, so a
   --  read after a flash erase or program sees the memory.
   procedure Invalidate_Data (Address : System.Address; Length : Natural);

end Adaflight.STM32.Cache;
