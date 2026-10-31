--  The core's instruction cache, enabled before elaboration: code runs from
--  flash over the AXI bus at seven wait states, and the run-time library's
--  start leaves the Cortex-M7 caches off.
package Adaflight.STM32.Cache is
   pragma Linker_Options ("-Wl,--undefined=adaflight_cache_entry");

   procedure Enable
     with Export, Convention => C, External_Name => "adaflight_cache_enable";

end Adaflight.STM32.Cache;
