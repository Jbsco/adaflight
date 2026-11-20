--  Whether this build has the race transponder: a build without it, whose
--  command line knows no transponder pin or setting.
package Adaflight.Transponder_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Transponder_Build;
