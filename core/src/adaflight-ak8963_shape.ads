pragma SPARK_Mode (On);
--  The AK8963 compass over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.AK8963;
with Adaflight.MPU_Slave_Steps;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.AK8963_Shape is new Adaflight.AK8963
  (Bus_Device        => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Is_I2C            => Adaflight.Sensor_Bus_Steps.Step_Is_I2C,
   Is_SPI            => Adaflight.Sensor_Bus_Steps.Step_Is_SPI,
   Is_MPU_Slave      => Adaflight.MPU_Slave_Steps.Step_Is_MPU_Slave,
   I2C_Address       => Adaflight.Sensor_Bus_Steps.Step_I2C_Address,
   Set_I2C_Address   => Adaflight.Sensor_Bus_Steps.Step_Set_I2C_Address,
   Prepare_SPI       => Adaflight.Sensor_Bus_Steps.Step_Prepare_SPI,
   Release_SPI       => Adaflight.Sensor_Bus_Steps.Step_Release_SPI,
   Register_Device   => Adaflight.Sensor_Bus_Steps.Step_Register_Device,
   Read_Registers    => Adaflight.Sensor_Bus_Steps.Step_Read_Registers,
   Write_Register    => Adaflight.Sensor_Bus_Steps.Step_Write_Register,
   Master_DMA_Off    => Adaflight.MPU_Slave_Steps.Step_Master_DMA_Off,
   Master_Write      => Adaflight.MPU_Slave_Steps.Step_Master_Write,
   Master_Read       => Adaflight.MPU_Slave_Steps.Step_Master_Read,
   Mask_Interrupts   => Adaflight.MPU_Slave_Steps.Step_Mask_Interrupts,
   Unmask_Interrupts => Adaflight.MPU_Slave_Steps.Step_Unmask_Interrupts,
   Micros            => Adaflight.MPU_Slave_Steps.Step_Micros,
   Delay_Ms          => Adaflight.Sensor_Bus_Steps.Step_Delay_Ms,
   Delay_Us          => Adaflight.MPU_Slave_Steps.Step_Delay_Us);
