--  Whether this build has the gimbal control: its settings. The core project
--  takes the other spec when the build leaves it out. A function, so that
--  analysis reads no branch as dead.
package Adaflight.Gimbal_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Gimbal_Build;
