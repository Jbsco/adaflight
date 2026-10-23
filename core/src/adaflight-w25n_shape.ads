pragma SPARK_Mode (On);
--  The W25N flash driver over a device that does nothing, the shape the proof
--  covers.
with Adaflight.Flash_Device.W25N;
with Adaflight.Flash_Bus_Steps;

package Adaflight.W25N_Shape is new Adaflight.Flash_Device.W25N
  (SPI_Device     => Adaflight.Flash_Bus_Steps.Flash_Line,
   Send           => Adaflight.Flash_Bus_Steps.Step_Send,
   Exchange       => Adaflight.Flash_Bus_Steps.Step_Exchange,
   Run            => Adaflight.Flash_Bus_Steps.Step_Run_One,
   Run_Read       => Adaflight.Flash_Bus_Steps.Step_Run_Read,
   Wait           => Adaflight.Flash_Bus_Steps.Step_Wait,
   Uses_DMA       => Adaflight.Flash_Bus_Steps.Step_Uses_DMA,
   Bus_Busy       => Adaflight.Flash_Bus_Steps.Step_Bus_Busy,
   Divider        => Adaflight.Flash_Bus_Steps.Step_Divider,
   Set_Divisor    => Adaflight.Flash_Bus_Steps.Step_Set_Divisor,
   Millis         => Adaflight.Flash_Bus_Steps.Step_Millis,
   Report_Written => Adaflight.Flash_Bus_Steps.Step_Report_Written);
