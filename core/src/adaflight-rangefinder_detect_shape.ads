pragma SPARK_Mode (On);
--  The rangefinder detection over a device that does nothing, the shape the
--  proof covers.
with Adaflight.Rangefinder_Detect.Probe;
with Adaflight.Rangefinder_Detect_Steps;

package Adaflight.Rangefinder_Detect_Shape is new Adaflight.Rangefinder_Detect.Probe
  (Device      => Adaflight.Rangefinder_Detect_Steps.Rangefinder_Line,
   Detect_Chip => Adaflight.Rangefinder_Detect_Steps.Step_Detect_Chip,
   Reschedule  => Adaflight.Rangefinder_Detect_Steps.Step_Reschedule);
