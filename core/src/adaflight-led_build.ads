--  Whether this build has the LED strip: its commands, settings and messages.
--  The core project takes the other spec when the build leaves it out.
--  A function, so that analysis reads no branch as dead.
package Adaflight.LED_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.LED_Build;
