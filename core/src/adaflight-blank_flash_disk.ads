pragma SPARK_Mode (On);
--  Sector runs of a virtual FAT volume whose files read as zeros.
with Adaflight.Virtual_FAT.Disk;
with Adaflight.Virtual_FAT_Steps;

package Adaflight.Blank_Flash_Disk is new Adaflight.Virtual_FAT.Disk
  (Read_File => Adaflight.Virtual_FAT_Steps.Read_Sector);
