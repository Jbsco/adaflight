--  The core coupled memory's zeroed data, cleared before elaboration: the
--  run-time library's start clears the main RAM's .bss alone, and the
--  objects placed in .bss.ccm (the USB controller, the menu's state) would
--  otherwise start with whatever the memory held.
package Adaflight.STM32.CCM_Clear is
   pragma Linker_Options ("-Wl,--undefined=adaflight_ccm_clear_entry");

   procedure Clear
     with Export, Convention => C, External_Name => "adaflight_ccm_clear";

end Adaflight.STM32.CCM_Clear;
