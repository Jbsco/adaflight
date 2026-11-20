--  Whether this build has the MAVLink telemetry: a build without it, whose
--  command line knows none of its settings.
package Adaflight.MAVLink_Telemetry_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.MAVLink_Telemetry_Build;
