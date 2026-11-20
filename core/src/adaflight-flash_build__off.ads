--  Whether this build has the flash chip: a build without it, whose command
--  line knows no flash command, pin or setting.
package Adaflight.Flash_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Flash_Build;
