--  Whether this build has the OLED dashboard: a build without it, whose
--  command line knows no dashboard setting.
package Adaflight.Dashboard_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Dashboard_Build;
