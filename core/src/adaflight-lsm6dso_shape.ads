pragma SPARK_Mode (On);
--  The LSM6DSO driver over the SPI gyro layer's shape, the shape the proof
--  covers.
with Adaflight.MPU_Gyro.LSM6DSO;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.LSM6DSO_Shape is new Adaflight.MPU_Gyro_Shape.LSM6DSO
  (Write_Register => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Delay_Us       => Adaflight.Gyro_Bus_Steps.Step_Delay_Us);
