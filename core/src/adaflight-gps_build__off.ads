--  Whether this build has the GPS, with its rescue and holds: a build
--  without it, whose command line knows no GPS command, lines or settings.
package Adaflight.GPS_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.GPS_Build;
