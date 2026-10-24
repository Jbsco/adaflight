pragma SPARK_Mode (On);
--  The BMI423 driver over the SPI gyro layer's shape, the shape the proof
--  covers.
with Adaflight.MPU_Gyro.BMI423;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.BMI423_Shape is new Adaflight.MPU_Gyro_Shape.BMI423
  (Read_Masked  => Adaflight.Gyro_Bus_Steps.Step_Read_Masked,
   Write_Buffer => Adaflight.Gyro_Bus_Steps.Step_Write_Buffer,
   Set_CS       => Adaflight.Gyro_Bus_Steps.Step_Set_CS);
