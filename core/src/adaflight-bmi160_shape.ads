pragma SPARK_Mode (On);
--  The BMI160 driver over the SPI gyro layer's shape, the shape the proof
--  covers.
with Adaflight.MPU_Gyro.BMI160;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.BMI160_Shape is new Adaflight.MPU_Gyro_Shape.BMI160
  (Write_Register => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Register  => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Write_Byte     => Adaflight.Gyro_Bus_Steps.Step_Write_Byte);
