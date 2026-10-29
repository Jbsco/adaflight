--  The internal flash: the configuration region at the start of sector 1,
--  which the image's layout keeps free, read in place, and written by
--  erasing the sector and programming words. The addresses come from the
--  generated memory package of the MCU.
with System;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.STM32.Memory;
package Adaflight.STM32.Flash is
   Config_Sector  : constant := Adaflight.STM32.Memory.Config_Sector;
   Config_Address : constant := Adaflight.STM32.Memory.Config_Address;
   Config_Size    : constant := Adaflight.STM32.Memory.Config_Size;
   --  The configuration region as the core reads it.
   Config : Byte_Array (0 .. Config_Size - 1)
     with Import, Address => System'To_Address (Config_Address);
   --  The sector erased and Data programmed from the region's start; OK when
   --  no programming error was flagged.
   procedure Write (Data : Byte_Array; OK : out Boolean)
     with Pre => Data'Length <= Config_Size;
end Adaflight.STM32.Flash;
