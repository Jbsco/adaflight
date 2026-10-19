pragma SPARK_Mode (On);
--  The LSM6DSV16X driver over the SPI gyro layer's shape, the shape the
--  proof covers.
with Adaflight.MPU_Gyro.LSM6DSV16X;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.LSM6DSV16X_Shape is new Adaflight.MPU_Gyro_Shape.LSM6DSV16X
  (Write_Register => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Register  => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Delay_Us       => Adaflight.Gyro_Bus_Steps.Step_Delay_Us,
   Failure        => Adaflight.Gyro_Bus_Steps.Step_Failure);
