pragma SPARK_Mode (On);
--  The ICM456xx driver over the SPI gyro layer's shape, the shape the proof
--  covers.
with Adaflight.MPU_Gyro.ICM456xx;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.ICM456xx_Shape is new Adaflight.MPU_Gyro_Shape.ICM456xx
  (Write_Register   => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Register    => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Write_Buffer     => Adaflight.Gyro_Bus_Steps.Step_Write_Buffer,
   Read_Masked      => Adaflight.Gyro_Bus_Steps.Step_Read_Masked,
   Delay_Us         => Adaflight.Gyro_Bus_Steps.Step_Delay_Us,
   Micros_To_Cycles => Adaflight.Gyro_Bus_Steps.Step_Micros_To_Cycles);
