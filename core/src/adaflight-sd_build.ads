--  Whether this build has the SD card: its command, settings and resources.
--  The core project takes the other spec when the build leaves it out.
--  A function, so that analysis reads no branch as dead.
package Adaflight.SD_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.SD_Build;
