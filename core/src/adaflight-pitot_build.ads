--  Whether this build has the pitot sensor: its settings and its messages.
--  The core project takes the other spec when the build leaves it out. A
--  function, so that analysis reads no branch as dead.
package Adaflight.Pitot_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Pitot_Build;
