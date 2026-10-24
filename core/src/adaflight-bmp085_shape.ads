pragma SPARK_Mode (On);
--  The BMP085 barometer over a bus and pins that do nothing, the shape the
--  proof covers.
with Adaflight.BMP085;
with Adaflight.Baro_Pin_Steps;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.BMP085_Shape is new Adaflight.BMP085
  (Bus_Device        => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Is_I2C            => Adaflight.Sensor_Bus_Steps.Step_Is_I2C,
   I2C_Address       => Adaflight.Sensor_Bus_Steps.Step_I2C_Address,
   Set_I2C_Address   => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Read_Registers    => Adaflight.Sensor_Bus_Steps.Step_Read_Registers,
   Start_Write       => Adaflight.Sensor_Bus_Steps.Step_Start_Write,
   Start_Read        => Adaflight.Sensor_Bus_Steps.Step_Start_Read,
   Check_Busy        => Adaflight.Sensor_Bus_Steps.Step_Check_Busy,
   Fetch             => Adaflight.Sensor_Bus_Steps.Step_Fetch,
   Register_Device   => Adaflight.Sensor_Bus_Steps.Step_Register_Device,
   Delay_Ms          => Adaflight.Sensor_Bus_Steps.Step_Delay_Ms,
   Delay_Us          => Adaflight.Sensor_Bus_Steps.Step_Delay_Us,
   Init_Pin          => Adaflight.Baro_Pin_Steps.Step_Init_Pin,
   Config_Pin        => Adaflight.Baro_Pin_Steps.Step_Config_Pin,
   Pin_High          => Adaflight.Baro_Pin_Steps.Step_Pin_High,
   Pin_Low           => Adaflight.Baro_Pin_Steps.Step_Pin_Low,
   Read_Pin          => Adaflight.Baro_Pin_Steps.Step_Read_Pin,
   Release_Pin       => Adaflight.Baro_Pin_Steps.Step_Release_Pin,
   Interrupt_Init    => Adaflight.Baro_Pin_Steps.Step_Interrupt_Init,
   Interrupt_Config  => Adaflight.Baro_Pin_Steps.Step_Interrupt_Pin,
   Interrupt_Enable  => Adaflight.Baro_Pin_Steps.Step_Interrupt_Pin,
   Interrupt_Release => Adaflight.Baro_Pin_Steps.Step_Interrupt_Pin);
