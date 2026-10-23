pragma SPARK_Mode (On);
--  The HMC5883L compass over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.HMC5883;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.HMC5883_Shape is new Adaflight.HMC5883
  (Bus_Device       => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Is_I2C           => Adaflight.Sensor_Bus_Steps.Step_Is_I2C,
   Is_SPI           => Adaflight.Sensor_Bus_Steps.Step_Is_SPI,
   I2C_Address      => Adaflight.Sensor_Bus_Steps.Step_I2C_Address,
   Set_I2C_Address  => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Register_Device  => Adaflight.Sensor_Bus_Steps.Step_Register_Device,
   Prepare_SPI      => Adaflight.Sensor_Bus_Steps.Step_Prepare_SPI,
   Read_Registers   => Adaflight.Sensor_Bus_Steps.Step_Read_Registers,
   Write_Register   => Adaflight.Sensor_Bus_Steps.Step_Write_Register,
   Start_Read       => Adaflight.Sensor_Bus_Steps.Step_Start_Read,
   Fetch            => Adaflight.Sensor_Bus_Steps.Step_Fetch,
   Delay_Ms         => Adaflight.Sensor_Bus_Steps.Step_Delay_Ms,
   Enable_Interrupt => Adaflight.Sensor_Bus_Steps.Step_Enable_EOC_Interrupt);
