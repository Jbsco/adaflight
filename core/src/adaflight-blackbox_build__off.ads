--  Whether this build has the flight log: a build without it, whose command
--  line knows no flight log setting, no msc command and no mass storage pin.
package Adaflight.Blackbox_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Blackbox_Build;
