--  Whether this build has the rangefinders: their pins and settings, and the
--  optical flow sensors that bring one. The core project takes the other
--  spec when the build leaves them out. A function, so that analysis reads no
--  branch as dead.
package Adaflight.Rangefinder_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Rangefinder_Build;
