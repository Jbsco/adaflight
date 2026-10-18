--  A barometer's bus instance, select pin and chip detection as steps that do
--  nothing, the shape the barometer detection's proof takes.
with Adaflight.Baro_Detect;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.Baro_Detect_Steps with SPARK_Mode is

   subtype Byte is Adaflight.Baro_Detect.Byte;

   procedure Step_Set_I2C_Instance (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Device : Byte; OK : out Boolean)
     with Global => null;

   procedure Step_Set_SPI_Instance (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Device : Byte; OK : out Boolean)
     with Global => null;

   procedure Step_Set_CS_Pin (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Tag : Byte)
     with Global => null;

   procedure Step_Detect_Chip
     (D        : in out Adaflight.Sensor_Bus_Steps.Bus_Line;
      Chip     : Adaflight.Baro_Detect.Driver;
      EOC_Tag  : Byte;
      XCLR_Tag : Byte;
      Found    : out Boolean;
      Variant  : out Byte)
     with Global => null;

end Adaflight.Baro_Detect_Steps;
