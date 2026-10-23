--  A rangefinder's detection and task reschedule as steps that do nothing, the
--  shape the rangefinder detection's proof takes.
with Adaflight.Rangefinder_Detect;

package Adaflight.Rangefinder_Detect_Steps with SPARK_Mode is

   type Rangefinder_Line is null record;

   procedure Step_Detect_Chip
     (D        : in out Rangefinder_Line;
      Chip     : Adaflight.Rangefinder_Detect.Driver;
      Hardware : Adaflight.Rangefinder_Detect.Byte;
      Found    : out Boolean;
      Reported : out Adaflight.Rangefinder_Detect.Delay_Ms)
     with Global => null;

   procedure Step_Reschedule (D : in out Rangefinder_Line; Period_Us : Natural)
     with Global => null;

end Adaflight.Rangefinder_Detect_Steps;
