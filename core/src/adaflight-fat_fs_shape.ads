pragma SPARK_Mode (On);
--  The FAT file system's card operations over a counting card, the shape
--  the proof covers.
with Adaflight.Counting_Steps;
with Adaflight.FAT_FS;

package Adaflight.FAT_FS_Shape is new Adaflight.FAT_FS
  (Card_State         => Adaflight.Counting_Steps.Card_Target,
   Read_Block         => Adaflight.Counting_Steps.Step_Read_Block,
   Write_Block        => Adaflight.Counting_Steps.Step_Write_Block,
   Begin_Write_Blocks => Adaflight.Counting_Steps.Step_Begin_Write_Blocks,
   Read_Clock         => Adaflight.Counting_Steps.Step_Read_Clock);
