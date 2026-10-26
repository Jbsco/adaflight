--  The internal flash of the STM32F405: the configuration region at the
--  start of sector 1, 16 KB at 16#0800_4000#, which the image's layout keeps
--  free, read in place, and written by erasing the sector and programming
--  words.
with System;
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.Flash is
   Config_Sector  : constant := 1;
   Config_Address : constant := 16#0800_4000#;
   Config_Size    : constant := 8_192;
   --  The configuration region as the core reads it.
   Config : Byte_Array (0 .. Config_Size - 1)
     with Import, Address => System'To_Address (Config_Address);
   --  The sector erased and Data programmed from the region's start; OK when
   --  no programming error was flagged.
   procedure Write (Data : Byte_Array; OK : out Boolean)
     with Pre => Data'Length <= Config_Size;
end Adaflight.STM32.Flash;
