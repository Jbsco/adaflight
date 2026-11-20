--  Whether this build has the compass: a build without it, whose command
--  line prints no compass line and knows no compass pin or setting.
package Adaflight.Compass_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Compass_Build;
