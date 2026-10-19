pragma SPARK_Mode (On);
--  The SD card driver over a bus that does nothing, the shape the proof
--  covers.
with Adaflight.SD_Card;
with Adaflight.Card_Bus_Steps;

package Adaflight.SD_Card_Shape is new Adaflight.SD_Card
  (SPI_Device      => Adaflight.Card_Bus_Steps.Card_Line,
   Preinit_CS      => Adaflight.Card_Bus_Steps.Step_Preinit_CS,
   Init_Detect_Pin => Adaflight.Card_Bus_Steps.Step_Init_Detect_Pin,
   Read_Detect_Pin => Adaflight.Card_Bus_Steps.Step_Read_Detect_Pin,
   Attach_Bus      => Adaflight.Card_Bus_Steps.Step_Attach_Bus,
   Prepare_CS      => Adaflight.Card_Bus_Steps.Step_Prepare_CS,
   Configure_CS    => Adaflight.Card_Bus_Steps.Step_Configure_CS,
   CS_High         => Adaflight.Card_Bus_Steps.Step_CS_High,
   Divider         => Adaflight.Card_Bus_Steps.Step_Divider,
   Set_Divisor     => Adaflight.Card_Bus_Steps.Step_Set_Divisor,
   Delay_Ms        => Adaflight.Card_Bus_Steps.Step_Delay_Ms,
   Delay_Us        => Adaflight.Card_Bus_Steps.Step_Delay_Us,
   Millis          => Adaflight.Card_Bus_Steps.Step_Millis,
   Start_Sequence  => Adaflight.Card_Bus_Steps.Step_Start_Sequence,
   Segment         => Adaflight.Card_Bus_Steps.Step_Segment,
   Wait            => Adaflight.Card_Bus_Steps.Step_Wait,
   Release         => Adaflight.Card_Bus_Steps.Step_Release,
   Bus_Busy        => Adaflight.Card_Bus_Steps.Step_Bus_Busy,
   Uses_DMA        => Adaflight.Card_Bus_Steps.Step_Uses_DMA,
   Read_Write      => Adaflight.Card_Bus_Steps.Step_Read_Write,
   Complete        => Adaflight.Card_Bus_Steps.Step_Complete);
