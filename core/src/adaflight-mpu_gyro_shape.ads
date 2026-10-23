pragma SPARK_Mode (On);
--  The SPI gyro layer over a device that does nothing, with three chip
--  probes, the shape the proof covers.
with Adaflight.MPU_Gyro;
with Adaflight.Gyro_Bus_Steps;

package Adaflight.MPU_Gyro_Shape is new Adaflight.MPU_Gyro
  (SPI_Device       => Adaflight.Gyro_Bus_Steps.Gyro_Line,
   Chip_Count       => 3,
   Preinit_CS       => Adaflight.Gyro_Bus_Steps.Step_Preinit_CS,
   Attach_Bus       => Adaflight.Gyro_Bus_Steps.Step_Attach_Bus,
   Prepare_CS       => Adaflight.Gyro_Bus_Steps.Step_Prepare_CS,
   Release_CS       => Adaflight.Gyro_Bus_Steps.Step_Release_CS,
   Divider          => Adaflight.Gyro_Bus_Steps.Step_Divider,
   Set_Divisor      => Adaflight.Gyro_Bus_Steps.Step_Set_Divisor,
   Probe_Chip       => Adaflight.Gyro_Bus_Steps.Step_Probe_Chip,
   Register_Device  => Adaflight.Gyro_Bus_Steps.Step_Register_Device,
   Millis           => Adaflight.Gyro_Bus_Steps.Step_Millis,
   Delay_Ms         => Adaflight.Gyro_Bus_Steps.Step_Delay_Ms,
   Enable_Interrupt => Adaflight.Gyro_Bus_Steps.Step_Enable_Interrupt,
   Cycle_Count      => Adaflight.Gyro_Bus_Steps.Step_Cycle_Count,
   Start_Sequence   => Adaflight.Gyro_Bus_Steps.Step_Start_Sequence,
   Wait             => Adaflight.Gyro_Bus_Steps.Step_Wait,
   Fetch            => Adaflight.Gyro_Bus_Steps.Step_Fetch,
   Uses_DMA         => Adaflight.Gyro_Bus_Steps.Step_Uses_DMA,
   Read_Registers   => Adaflight.Gyro_Bus_Steps.Step_Read_Registers);
