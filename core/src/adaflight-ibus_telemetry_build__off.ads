--  Whether this build has the iBus telemetry: a build without it, whose
--  command line knows none of its settings.
package Adaflight.IBus_Telemetry_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.IBus_Telemetry_Build;
