package body Adaflight.Compass_Detect_Steps with SPARK_Mode is

   function Step_Bus_Type (D : Adaflight.Sensor_Bus_Steps.Bus_Line) return Byte is
      pragma Unreferenced (D);
   begin
      return 0;
   end Step_Bus_Type;

   procedure Step_Set_Interrupt_Pin (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Set_Interrupt_Pin;

   procedure Step_Set_MPU_Slave (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Address : Byte) is
      pragma Unreferenced (D, Address);
   begin
      null;
   end Step_Set_MPU_Slave;

   procedure Step_Detect_DroneCAN (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Found : out Boolean) is
      pragma Unreferenced (D);
   begin
      Found := False;
   end Step_Detect_DroneCAN;

   procedure Step_Detect_Chip
     (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Chip : Adaflight.Compass_Detect.Driver; Found : out Boolean)
   is
      pragma Unreferenced (D, Chip);
   begin
      Found := False;
   end Step_Detect_Chip;

end Adaflight.Compass_Detect_Steps;
