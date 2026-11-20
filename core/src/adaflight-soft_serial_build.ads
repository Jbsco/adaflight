--  Whether this build has the software serial ports: their pins. The core
--  project takes the other spec when the build leaves them out. A function,
--  so that analysis reads no branch as dead.
package Adaflight.Soft_Serial_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Soft_Serial_Build;
