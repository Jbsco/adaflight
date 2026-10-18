pragma SPARK_Mode (On);
--  The W25M stacked-die flash driver over a device and dies that do nothing,
--  the shape the proof covers.
with Adaflight.Flash_Device.W25M;
with Adaflight.Flash_Bus_Steps;

package Adaflight.W25M_Shape is new Adaflight.Flash_Device.W25M
  (SPI_Device           => Adaflight.Flash_Bus_Steps.Flash_Line,
   Send                 => Adaflight.Flash_Bus_Steps.Step_Send,
   Wait                 => Adaflight.Flash_Bus_Steps.Step_Wait,
   Die_Identify_NOR     => Adaflight.Flash_Bus_Steps.Step_Die_Identify,
   Die_Identify_NAND    => Adaflight.Flash_Bus_Steps.Step_Die_Identify,
   Die_Configure        => Adaflight.Flash_Bus_Steps.Step_Die_Configure,
   Die_Is_Ready         => Adaflight.Flash_Bus_Steps.Step_Die_Ready,
   Die_Wait_For_Ready   => Adaflight.Flash_Bus_Steps.Step_Die_Ready,
   Die_Erase_Sector     => Adaflight.Flash_Bus_Steps.Step_Die_Erase_Sector,
   Die_Erase_Completely => Adaflight.Flash_Bus_Steps.Step_Die_Erase_Completely,
   Die_Program_Begin    => Adaflight.Flash_Bus_Steps.Step_Die_Program_Begin,
   Die_Program_Continue => Adaflight.Flash_Bus_Steps.Step_Die_Program_Continue,
   Die_Program_Finish   => Adaflight.Flash_Bus_Steps.Step_Die_Program_Finish,
   Die_Read             => Adaflight.Flash_Bus_Steps.Step_Die_Read);
