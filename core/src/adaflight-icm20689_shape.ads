pragma SPARK_Mode (On);
--  The ICM20689 family driver over the SPI gyro layer's shape, the shape the
--  proof covers.
with Adaflight.MPU_Gyro.ICM20689;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.ICM20689_Shape is new Adaflight.MPU_Gyro_Shape.ICM20689
  (Write_Register => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Register  => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Delay_Us       => Adaflight.Gyro_Bus_Steps.Step_Delay_Us);
