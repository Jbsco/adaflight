pragma SPARK_Mode (On);
--  The barometer detection over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.Baro_Detect.Scan;
with Adaflight.Baro_Detect_Steps;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.Baro_Detect_Shape is new Adaflight.Baro_Detect.Scan
  (Bus_Device       => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Set_I2C_Instance => Adaflight.Baro_Detect_Steps.Step_Set_I2C_Instance,
   Set_I2C_Address  => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Set_SPI_Instance => Adaflight.Baro_Detect_Steps.Step_Set_SPI_Instance,
   Set_CS_Pin       => Adaflight.Baro_Detect_Steps.Step_Set_CS_Pin,
   Detect_Chip      => Adaflight.Baro_Detect_Steps.Step_Detect_Chip);
