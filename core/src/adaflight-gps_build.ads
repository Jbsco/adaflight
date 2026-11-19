--  Whether this build has the GPS, with its rescue and holds: its commands,
--  settings and messages. The core project takes the other spec when the
--  build leaves it out. A function, so that analysis reads no branch as dead.
package Adaflight.GPS_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.GPS_Build;
