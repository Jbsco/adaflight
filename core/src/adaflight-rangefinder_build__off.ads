--  Whether this build has the rangefinders: a build without them, whose
--  command line knows no rangefinder or optical flow pin or setting.
package Adaflight.Rangefinder_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Rangefinder_Build;
