--  Whether this build has the SD card: a build without it, whose command
--  line knows no SD card command, lines, settings or resources.
package Adaflight.SD_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.SD_Build;
