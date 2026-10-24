pragma SPARK_Mode (On);
--  The LPS barometer over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.LPS;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.LPS_Shape is new Adaflight.LPS
  (Bus_Device     => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Is_SPI         => Adaflight.Sensor_Bus_Steps.Step_Is_SPI,
   Prepare_SPI    => Adaflight.Sensor_Bus_Steps.Step_Prepare_SPI,
   Read_Registers => Adaflight.Sensor_Bus_Steps.Step_Read_Buffer,
   Write_Register => Adaflight.Sensor_Bus_Steps.Step_Write_Byte,
   Write_Plain    => Adaflight.Sensor_Bus_Steps.Step_Write_Byte,
   Read_Byte      => Adaflight.Sensor_Bus_Steps.Step_Read_Byte,
   Millis         => Adaflight.Sensor_Bus_Steps.Step_Millis);
