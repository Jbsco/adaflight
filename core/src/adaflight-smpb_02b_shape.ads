pragma SPARK_Mode (On);
--  The 2SMPB-02B barometer over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.SMPB_02B;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.SMPB_02B_Shape is new Adaflight.SMPB_02B
  (Bus_Device      => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Is_I2C          => Adaflight.Sensor_Bus_Steps.Step_Is_I2C,
   Is_SPI          => Adaflight.Sensor_Bus_Steps.Step_Is_SPI,
   I2C_Address     => Adaflight.Sensor_Bus_Steps.Step_I2C_Address,
   Set_I2C_Address => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Prepare_SPI     => Adaflight.Sensor_Bus_Steps.Step_Prepare_SPI,
   Preinit_CS      => Adaflight.Sensor_Bus_Steps.Step_Release_SPI,
   Read_Byte       => Adaflight.Sensor_Bus_Steps.Step_Read_Byte,
   Read_Registers  => Adaflight.Sensor_Bus_Steps.Step_Read_Registers,
   Write_Register  => Adaflight.Sensor_Bus_Steps.Step_Write_Register,
   Start_Read      => Adaflight.Sensor_Bus_Steps.Step_Start_Read,
   Check_Busy      => Adaflight.Sensor_Bus_Steps.Step_Check_Busy,
   Fetch           => Adaflight.Sensor_Bus_Steps.Step_Fetch,
   Delay_Ms        => Adaflight.Sensor_Bus_Steps.Step_Delay_Ms);
