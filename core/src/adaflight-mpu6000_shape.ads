pragma SPARK_Mode (On);
--  The MPU6000 driver over the SPI gyro layer's shape, the shape the proof
--  covers.
with Adaflight.MPU_Gyro.MPU6000;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.MPU6000_Shape is new Adaflight.MPU_Gyro_Shape.MPU6000
  (Write_Register   => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Register    => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Delay_Us         => Adaflight.Gyro_Bus_Steps.Step_Delay_Us,
   Micros_To_Cycles => Adaflight.Gyro_Bus_Steps.Step_Micros_To_Cycles,
   Failure          => Adaflight.Gyro_Bus_Steps.Step_Failure);
