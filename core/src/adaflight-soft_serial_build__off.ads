--  Whether this build has the software serial ports: a build without them,
--  whose command line knows no software serial pin.
package Adaflight.Soft_Serial_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Soft_Serial_Build;
