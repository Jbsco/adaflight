package body Adaflight.Rangefinder_Detect_Steps with SPARK_Mode is

   procedure Step_Detect_Chip
     (D        : in out Rangefinder_Line;
      Chip     : Adaflight.Rangefinder_Detect.Driver;
      Hardware : Adaflight.Rangefinder_Detect.Byte;
      Found    : out Boolean;
      Reported : out Adaflight.Rangefinder_Detect.Delay_Ms)
   is
      pragma Unreferenced (D, Chip, Hardware);
   begin
      Found := False;
      Reported := 0;
   end Step_Detect_Chip;

   procedure Step_Reschedule (D : in out Rangefinder_Line; Period_Us : Natural) is
      pragma Unreferenced (D, Period_Us);
   begin
      null;
   end Step_Reschedule;

end Adaflight.Rangefinder_Detect_Steps;
