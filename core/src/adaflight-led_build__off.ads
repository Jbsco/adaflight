--  Whether this build has the LED strip: a build without it, whose command
--  line knows no LED commands, settings or resource.
package Adaflight.LED_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.LED_Build;
