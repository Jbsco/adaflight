package body Adaflight.Optical_Flow_Detect_Steps with SPARK_Mode is

   procedure Step_Detect_Chip
     (D           : in out Flow_Line;
      Chip        : Adaflight.Optical_Flow_Detect.Driver;
      Rangefinder : Adaflight.Optical_Flow_Detect.Byte;
      Found       : out Boolean;
      Reported    : out Adaflight.Optical_Flow_Detect.Delay_Ms)
   is
      pragma Unreferenced (D, Chip, Rangefinder);
   begin
      Found := False;
      Reported := 0;
   end Step_Detect_Chip;

   procedure Step_Reschedule (D : in out Flow_Line; Period_Us : Natural) is
      pragma Unreferenced (D, Period_Us);
   begin
      null;
   end Step_Reschedule;

end Adaflight.Optical_Flow_Detect_Steps;
