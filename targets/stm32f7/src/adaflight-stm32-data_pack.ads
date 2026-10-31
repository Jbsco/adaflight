--  A packed image's start: the cold tables and initialized data unpacked
--  into RAM from their compressed stream after .rodata, before elaboration.
--  The run-time library calls it through its .init_array entry once the
--  clocks run; a plain image's empty range leaves it with nothing to do.
package Adaflight.STM32.Data_Pack is
   pragma Linker_Options ("-Wl,--undefined=adaflight_data_pack_entry");

   procedure Unpack
     with Export, Convention => C, External_Name => "adaflight_data_pack_unpack";

end Adaflight.STM32.Data_Pack;
