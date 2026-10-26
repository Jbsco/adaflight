--  The host's configuration store: the region the board keeps in flash, held
--  in memory and in the file the environment variable ADAFLIGHT_EEPROM names,
--  adaflight-eeprom.bin in the working directory when unset.
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.Flash is
   Config_Size : constant := 8_192;
   Config : Byte_Array (0 .. Config_Size - 1) := (others => 16#FF#);
   --  The region erased and Data written from its start, and the file
   --  written with it.
   procedure Write (Data : Byte_Array; OK : out Boolean)
     with Pre => Data'Length <= Config_Size;
end Adaflight.STM32.Flash;
