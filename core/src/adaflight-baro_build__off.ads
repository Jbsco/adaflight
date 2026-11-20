--  Whether this build has the barometer: a build without it, whose command
--  line prints no barometer line and knows no barometer pin or setting.
package Adaflight.Baro_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Baro_Build;
