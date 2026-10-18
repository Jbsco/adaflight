pragma SPARK_Mode (On);
--  The optical flow detection over a device that does nothing, the shape the
--  proof covers.
with Adaflight.Optical_Flow_Detect.Probe;
with Adaflight.Optical_Flow_Detect_Steps;

package Adaflight.Optical_Flow_Detect_Shape is new Adaflight.Optical_Flow_Detect.Probe
  (Device      => Adaflight.Optical_Flow_Detect_Steps.Flow_Line,
   Detect_Chip => Adaflight.Optical_Flow_Detect_Steps.Step_Detect_Chip,
   Reschedule  => Adaflight.Optical_Flow_Detect_Steps.Step_Reschedule);
