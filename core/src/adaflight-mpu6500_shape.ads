pragma SPARK_Mode (On);
--  The MPU6500 family driver over the SPI gyro layer's shape, the shape the
--  proof covers.
with Adaflight.MPU_Gyro.MPU6500;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.MPU6500_Shape is new Adaflight.MPU_Gyro_Shape.MPU6500
  (Write_Register     => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Register      => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Bus_Write_Register => Adaflight.Gyro_Bus_Steps.Step_Bus_Write_Register,
   Delay_Us           => Adaflight.Gyro_Bus_Steps.Step_Delay_Us);
