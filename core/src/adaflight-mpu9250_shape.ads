pragma SPARK_Mode (On);
--  The MPU9250 driver over the SPI gyro layer's shape, the shape the proof
--  covers.
with Adaflight.MPU_Gyro.MPU9250;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.MPU9250_Shape is new Adaflight.MPU_Gyro_Shape.MPU9250
  (Write_Buffer  => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Buffer   => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Read_Register => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Delay_Us      => Adaflight.Gyro_Bus_Steps.Step_Delay_Us,
   Failure       => Adaflight.Gyro_Bus_Steps.Step_Failure);
