package body Adaflight.Baro_Detect_Steps with SPARK_Mode is

   procedure Step_Set_I2C_Instance (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Device : Byte; OK : out Boolean) is
      pragma Unreferenced (D, Device);
   begin
      OK := True;
   end Step_Set_I2C_Instance;

   procedure Step_Set_SPI_Instance (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Device : Byte; OK : out Boolean) is
      pragma Unreferenced (D, Device);
   begin
      OK := True;
   end Step_Set_SPI_Instance;

   procedure Step_Set_CS_Pin (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Set_CS_Pin;

   procedure Step_Detect_Chip
     (D        : in out Adaflight.Sensor_Bus_Steps.Bus_Line;
      Chip     : Adaflight.Baro_Detect.Driver;
      EOC_Tag  : Byte;
      XCLR_Tag : Byte;
      Found    : out Boolean;
      Variant  : out Byte)
   is
      pragma Unreferenced (D, Chip, EOC_Tag, XCLR_Tag);
   begin
      Found := False;
      Variant := 0;
   end Step_Detect_Chip;

end Adaflight.Baro_Detect_Steps;
