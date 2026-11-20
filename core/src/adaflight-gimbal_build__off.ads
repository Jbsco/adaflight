--  Whether this build has the gimbal control: a build without it, whose
--  command line knows no gimbal setting.
package Adaflight.Gimbal_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Gimbal_Build;
