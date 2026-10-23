pragma SPARK_Mode (On);
--  The flash layer over the M25P16 driver's shape and a device that does
--  nothing, the shape the proof covers.
with Adaflight.Flash_Device.Layer;
with Adaflight.Flash_Bus_Steps;
with Adaflight.M25P16_Shape;

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
   Chip_Identify         => Adaflight.M25P16_Shape.Identify,
   Chip_Configure        => Adaflight.M25P16_Shape.Configure,
   Chip_Is_Ready         => Adaflight.M25P16_Shape.Is_Ready,
   Chip_Wait_For_Ready   => Adaflight.M25P16_Shape.Wait_For_Ready,
   Chip_Erase_Sector     => Adaflight.M25P16_Shape.Erase_Sector,
   Chip_Erase_Completely => Adaflight.M25P16_Shape.Erase_Completely,
   Chip_Program_Begin    => Adaflight.M25P16_Shape.Page_Program_Begin,
   Chip_Program_Continue => Adaflight.M25P16_Shape.Page_Program_Continue,
   Chip_Program          => Adaflight.M25P16_Shape.Page_Program,
   Chip_Read             => Adaflight.M25P16_Shape.Read_Bytes);
