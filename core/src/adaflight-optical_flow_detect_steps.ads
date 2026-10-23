--  An optical flow sensor's detection and task reschedule as steps that do
--  nothing, the shape the optical flow detection's proof takes.
with Adaflight.Optical_Flow_Detect;

package Adaflight.Optical_Flow_Detect_Steps with SPARK_Mode is

   type Flow_Line is null record;

   procedure Step_Detect_Chip
     (D           : in out Flow_Line;
      Chip        : Adaflight.Optical_Flow_Detect.Driver;
      Rangefinder : Adaflight.Optical_Flow_Detect.Byte;
      Found       : out Boolean;
      Reported    : out Adaflight.Optical_Flow_Detect.Delay_Ms)
     with Global => null;

   procedure Step_Reschedule (D : in out Flow_Line; Period_Us : Natural)
     with Global => null;

end Adaflight.Optical_Flow_Detect_Steps;
