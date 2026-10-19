pragma SPARK_Mode (On);
--  The BMP5xx barometer over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.BMP5xx;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.BMP5xx_Shape is new Adaflight.BMP5xx
  (Bus_Device           => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Is_I2C               => Adaflight.Sensor_Bus_Steps.Step_Is_I2C,
   Is_SPI               => Adaflight.Sensor_Bus_Steps.Step_Is_SPI,
   I2C_Address          => Adaflight.Sensor_Bus_Steps.Step_I2C_Address,
   Set_I2C_Address      => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Prepare_SPI          => Adaflight.Sensor_Bus_Steps.Step_Prepare_SPI,
   Release_SPI          => Adaflight.Sensor_Bus_Steps.Step_Release_SPI,
   Enable_EOC_Interrupt => Adaflight.Sensor_Bus_Steps.Step_Enable_EOC_Interrupt,
   Read_Registers       => Adaflight.Sensor_Bus_Steps.Step_Read_Registers,
   Write_Register       => Adaflight.Sensor_Bus_Steps.Step_Write_Register,
   Check_Busy           => Adaflight.Sensor_Bus_Steps.Step_Check_Busy,
   Register_Device      => Adaflight.Sensor_Bus_Steps.Step_Register_Device,
   Delay_Ms             => Adaflight.Sensor_Bus_Steps.Step_Delay_Ms);
