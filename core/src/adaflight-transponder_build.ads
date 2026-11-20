--  Whether this build has the race transponder: its pin, its settings and
--  its messages. The core project takes the other spec when the build leaves
--  it out. A function, so that analysis reads no branch as dead.
package Adaflight.Transponder_Build with SPARK_Mode, Pure is
   function Enabled return Boolean is (True);
end Adaflight.Transponder_Build;
