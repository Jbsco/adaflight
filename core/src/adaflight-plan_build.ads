--  Whether this build has the flight plan: its waypoint command and its map
--  on the OSD. The core project takes the other spec when the build leaves
--  it out. A function, so that analysis reads no branch as dead.
package Adaflight.Plan_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Plan_Build;
