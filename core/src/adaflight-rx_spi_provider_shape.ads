pragma SPARK_Mode (On);
--  The SPI receiver layer over counting units, the shape the proof covers.
with Adaflight.RX_SPI_Provider;
with Adaflight.RX_SPI_Steps;

package Adaflight.RX_SPI_Provider_Shape is new Adaflight.RX_SPI_Provider
  (Device_Init          => Adaflight.RX_SPI_Steps.Step_Ok,
   Family_Init          => Adaflight.RX_SPI_Steps.Step_Family_Ok,
   Exti_Configured      => Adaflight.RX_SPI_Steps.Step_Query,
   Exti_Init            => Adaflight.RX_SPI_Steps.Step,
   Dispatch_Enable      => Adaflight.RX_SPI_Steps.Step,
   Family_Data_Received => Adaflight.RX_SPI_Steps.Step_Received,
   Family_Process_Frame => Adaflight.RX_SPI_Steps.Step_Received,
   Family_Set_Channels  => Adaflight.RX_SPI_Steps.Step_Channels,
   Family_Stop          => Adaflight.RX_SPI_Steps.Step_Family,
   Last_Exti_Time       => Adaflight.RX_SPI_Steps.Step_Time);
