pragma SPARK_Mode (On);
--  The compass detection over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.Baro_Detect_Steps;
with Adaflight.Compass_Detect.Scan;
with Adaflight.Compass_Detect_Steps;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.Compass_Detect_Shape is new Adaflight.Compass_Detect.Scan
  (Bus_Device        => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Bus_Type          => Adaflight.Compass_Detect_Steps.Step_Bus_Type,
   Set_Interrupt_Pin => Adaflight.Compass_Detect_Steps.Step_Set_Interrupt_Pin,
   Set_I2C_Instance  => Adaflight.Baro_Detect_Steps.Step_Set_I2C_Instance,
   Set_I2C_Address   => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Set_SPI_Instance  => Adaflight.Baro_Detect_Steps.Step_Set_SPI_Instance,
   Set_CS_Pin        => Adaflight.Baro_Detect_Steps.Step_Set_CS_Pin,
   Set_MPU_Slave     => Adaflight.Compass_Detect_Steps.Step_Set_MPU_Slave,
   Detect_DroneCAN   => Adaflight.Compass_Detect_Steps.Step_Detect_DroneCAN,
   Detect_Chip       => Adaflight.Compass_Detect_Steps.Step_Detect_Chip);
