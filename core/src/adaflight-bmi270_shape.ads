pragma SPARK_Mode (On);
--  The BMI270 driver over the SPI gyro layer's shape, the shape the proof
--  covers.
with Adaflight.MPU_Gyro.BMI270;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.BMI270_Shape is new Adaflight.MPU_Gyro_Shape.BMI270
  (Read_Masked    => Adaflight.Gyro_Bus_Steps.Step_Read_Masked,
   Write_Register => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Write_Buffer   => Adaflight.Gyro_Bus_Steps.Step_Write_Buffer,
   Set_CS         => Adaflight.Gyro_Bus_Steps.Step_Set_CS);
