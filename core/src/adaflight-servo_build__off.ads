--  Whether this build has servos: a build without them, whose command line
--  knows no servo commands, settings or resource.
package Adaflight.Servo_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (False);
end Adaflight.Servo_Build;
