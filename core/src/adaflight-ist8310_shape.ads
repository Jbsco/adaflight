pragma SPARK_Mode (On);
--  The IST8310 compass over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.IST8310;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.IST8310_Shape is new Adaflight.IST8310
  (Bus_Device      => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Is_I2C          => Adaflight.Sensor_Bus_Steps.Step_Is_I2C,
   I2C_Address     => Adaflight.Sensor_Bus_Steps.Step_I2C_Address,
   Set_I2C_Address => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Register_Device => Adaflight.Sensor_Bus_Steps.Step_Register_Device,
   Read_Registers  => Adaflight.Sensor_Bus_Steps.Step_Read_Registers,
   Write_Register  => Adaflight.Sensor_Bus_Steps.Step_Write_Register,
   Start_Read      => Adaflight.Sensor_Bus_Steps.Step_Start_Read,
   Start_Write     => Adaflight.Sensor_Bus_Steps.Step_Start_Write,
   Fetch           => Adaflight.Sensor_Bus_Steps.Step_Fetch,
   Delay_Ms        => Adaflight.Sensor_Bus_Steps.Step_Delay_Ms);
