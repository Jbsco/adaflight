pragma SPARK_Mode (On);
--  The SDIO card driver over a controller that does nothing, the shape the
--  proof covers.
with Adaflight.SD_Card_SDIO;
with Adaflight.SDIO_Steps;

package Adaflight.SD_Card_SDIO_Shape is new Adaflight.SD_Card_SDIO
  (SDIO_Device     => Adaflight.SDIO_Steps.Controller,
   Init_Detect_Pin => Adaflight.SDIO_Steps.Step_Init_Detect_Pin,
   Read_Detect_Pin => Adaflight.SDIO_Steps.Step_Read_Detect_Pin,
   Find_DMA        => Adaflight.SDIO_Steps.Step_Find_DMA,
   Cache_Writes    => Adaflight.SDIO_Steps.Step_Cache_Writes,
   Init_Hardware   => Adaflight.SDIO_Steps.Step_Init_Hardware,
   Init_Card       => Adaflight.SDIO_Steps.Step_Init_Card,
   Check_Ready     => Adaflight.SDIO_Steps.Step_Check_Ready,
   Card_Info       => Adaflight.SDIO_Steps.Step_Card_Info,
   Read_Pending    => Adaflight.SDIO_Steps.Step_Read_Pending,
   Write_Pending   => Adaflight.SDIO_Steps.Step_Write_Pending,
   Start_Read      => Adaflight.SDIO_Steps.Step_Start_Read,
   Fetch_Block     => Adaflight.SDIO_Steps.Step_Fetch_Block,
   Start_Write     => Adaflight.SDIO_Steps.Step_Start_Write,
   Millis          => Adaflight.SDIO_Steps.Step_Millis,
   Complete        => Adaflight.SDIO_Steps.Step_Complete);
