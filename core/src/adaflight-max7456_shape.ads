pragma SPARK_Mode (On);
--  The MAX7456 driver over an SPI device that does nothing, the shape the
--  proof covers.
with Adaflight.MAX7456;
with Adaflight.OSD_Chip_Steps;

package Adaflight.MAX7456_Shape is new Adaflight.MAX7456
  (SPI_Device       => Adaflight.OSD_Chip_Steps.Chip_Line,
   Preinit_CS       => Adaflight.OSD_Chip_Steps.Step_Preinit_CS,
   Attach_Bus       => Adaflight.OSD_Chip_Steps.Step_Attach_Bus,
   Check_CS_Free    => Adaflight.OSD_Chip_Steps.Step_Check_CS_Free,
   Prepare_CS       => Adaflight.OSD_Chip_Steps.Step_Prepare_CS,
   Release_CS       => Adaflight.OSD_Chip_Steps.Step_Release_CS,
   Claim_CS         => Adaflight.OSD_Chip_Steps.Step_Claim_CS,
   Divider          => Adaflight.OSD_Chip_Steps.Step_Divider,
   Clock_Of         => Adaflight.OSD_Chip_Steps.Step_Clock_Of,
   Set_Divisor      => Adaflight.OSD_Chip_Steps.Step_Set_Divisor,
   Write_Byte       => Adaflight.OSD_Chip_Steps.Step_Write_Byte,
   Write_Register   => Adaflight.OSD_Chip_Steps.Step_Write_Register,
   Read_Register    => Adaflight.OSD_Chip_Steps.Step_Read_Register,
   Write_Buffer     => Adaflight.OSD_Chip_Steps.Step_Write_Buffer,
   Start_Transfer   => Adaflight.OSD_Chip_Steps.Step_Start_Transfer,
   Check_Busy       => Adaflight.OSD_Chip_Steps.Step_Check_Busy,
   Uses_DMA         => Adaflight.OSD_Chip_Steps.Step_Uses_DMA,
   Transfer_Pending => Adaflight.OSD_Chip_Steps.Step_Transfer_Pending,
   Wait             => Adaflight.OSD_Chip_Steps.Step_Wait,
   Millis           => Adaflight.OSD_Chip_Steps.Step_Millis,
   Micros           => Adaflight.OSD_Chip_Steps.Step_Micros,
   Delay_Ms         => Adaflight.OSD_Chip_Steps.Step_Delay_Ms,
   Delay_Us         => Adaflight.OSD_Chip_Steps.Step_Delay_Us,
   Toggle_LED       => Adaflight.OSD_Chip_Steps.Step_Toggle_LED);
