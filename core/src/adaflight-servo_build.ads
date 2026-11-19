--  Whether this build has servos: their commands, settings and messages.
--  The core project takes the other spec when the build leaves them out.
--  A function, so that analysis reads no branch as dead.
package Adaflight.Servo_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Servo_Build;
