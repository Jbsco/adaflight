--  Whether this build has the flight log: its settings, its storage and the
--  USB mass storage mode. The core project takes the other spec when the
--  build leaves it out. A function, so that analysis reads no branch as dead.
package Adaflight.Blackbox_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Blackbox_Build;
