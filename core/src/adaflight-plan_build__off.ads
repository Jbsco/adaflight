--  Whether this build has the flight plan: a build without it, whose
--  command line knows no waypoint command and whose OSD draws no map.
package Adaflight.Plan_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Plan_Build;
