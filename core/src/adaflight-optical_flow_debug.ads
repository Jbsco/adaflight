--  The optical flow debug values as the reference records them after a
--  sample with new data: the flow rates after the mounting rotation, the
--  delayed gyro rates in radians per second, the compensated rates on the
--  axes within the gyro limit (zero on the others) and the rates kept, all
--  in thousandths. Each value comes from the sensor's taps and state, so
--  it stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.Optical_Flow;

package Adaflight.Optical_Flow_Debug with SPARK_Mode is

   --  After one processing of the driver's sample.
   procedure Record_Process (D : in out Debug.State; S : Optical_Flow.Sensor)
     with Global => null;

end Adaflight.Optical_Flow_Debug;
