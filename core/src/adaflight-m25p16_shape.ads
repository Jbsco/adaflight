pragma SPARK_Mode (On);
--  The M25P16 flash driver over a device that does nothing, the shape the
--  proof covers.
with Adaflight.Flash_Device.M25P16;
with Adaflight.Flash_Bus_Steps;

package Adaflight.M25P16_Shape is new Adaflight.Flash_Device.M25P16
  (SPI_Device  => Adaflight.Flash_Bus_Steps.Flash_Line,
   Read_Write  => Adaflight.Flash_Bus_Steps.Step_Read_Write,
   Write       => Adaflight.Flash_Bus_Steps.Step_Write,
   Run         => Adaflight.Flash_Bus_Steps.Step_Run,
   Run_Read    => Adaflight.Flash_Bus_Steps.Step_Run_Read,
   Wait        => Adaflight.Flash_Bus_Steps.Step_Wait,
   Uses_DMA    => Adaflight.Flash_Bus_Steps.Step_Uses_DMA,
   Bus_Busy    => Adaflight.Flash_Bus_Steps.Step_Bus_Busy,
   Divider     => Adaflight.Flash_Bus_Steps.Step_Divider,
   Set_Divisor => Adaflight.Flash_Bus_Steps.Step_Set_Divisor);
