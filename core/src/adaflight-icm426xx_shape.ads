pragma SPARK_Mode (On);
--  The ICM426xx driver with an external clock over the SPI gyro layer's
--  shape, the shape the proof covers.
with Adaflight.MPU_Gyro.ICM426xx;
with Adaflight.MPU_Gyro_Shape;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.ICM426xx_Shape is new Adaflight.MPU_Gyro_Shape.ICM426xx
  (External_Clock => True,
   Write_Register => Adaflight.Gyro_Bus_Steps.Step_Write_Register,
   Read_Register  => Adaflight.Gyro_Bus_Steps.Step_Read_Register,
   Start_Clock_In => Adaflight.Gyro_Bus_Steps.Step_Start_Clock_In);
