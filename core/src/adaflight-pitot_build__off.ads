--  Whether this build has the pitot sensor: a build without it, whose
--  command line knows no pitot setting.
package Adaflight.Pitot_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Pitot_Build;
