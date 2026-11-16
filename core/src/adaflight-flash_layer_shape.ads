pragma SPARK_Mode (On);
--  The flash layer over the W25N driver's shape, with the M25P16 driver's
--  identification first, and a device that does nothing, the shape the proof
--  covers.
with Adaflight.Flash_Device.Layer;
with Adaflight.Flash_Bus_Steps;
with Adaflight.M25P16_Shape;
with Adaflight.W25N_Shape;

package Adaflight.Flash_Layer_Shape is new Adaflight.Flash_Device.Layer
  (SPI_Device            => Adaflight.Flash_Bus_Steps.Flash_Line,
   Preinit_CS            => Adaflight.Flash_Bus_Steps.Step_Preinit_CS,
   CS_Free               => Adaflight.Flash_Bus_Steps.Step_CS_Free,
   Attach_Bus            => Adaflight.Flash_Bus_Steps.Step_Attach_Bus,
   Prepare_CS            => Adaflight.Flash_Bus_Steps.Step_Prepare_CS,
   Divider               => Adaflight.Flash_Bus_Steps.Step_Divider,
   Set_Divisor           => Adaflight.Flash_Bus_Steps.Step_Set_Divisor,
   Delay_Ms              => Adaflight.Flash_Bus_Steps.Step_Delay_Ms,
   Read_Id               => Adaflight.Flash_Bus_Steps.Step_Read_Id,
   Millis                => Adaflight.Flash_Bus_Steps.Step_Millis,
   Write_Failed          => Adaflight.Flash_Bus_Steps.Step_Write_Failed,
   Chip_Identify         => Adaflight.M25P16_Shape.Identify,
   Chip_Identify_Newer   => Adaflight.W25N_Shape.Identify,
   Chip_Configure        => Adaflight.W25N_Shape.Configure,
   Chip_Is_Ready         => Adaflight.W25N_Shape.Is_Ready,
   Chip_Wait_For_Ready   => Adaflight.W25N_Shape.Wait_For_Ready,
   Chip_Erase_Sector     => Adaflight.W25N_Shape.Erase_Sector,
   Chip_Erase_Completely => Adaflight.W25N_Shape.Erase_Completely,
   Chip_Program_Begin    => Adaflight.W25N_Shape.Page_Program_Begin,
   Chip_Program_Continue => Adaflight.W25N_Shape.Page_Program_Continue,
   Chip_Program          => Adaflight.W25N_Shape.Page_Program,
   Chip_Flush            => Adaflight.Flash_Bus_Steps.Step_Chip_Flush,
   Chip_Read             => Adaflight.W25N_Shape.Read_Bytes);
