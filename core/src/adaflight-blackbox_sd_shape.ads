pragma SPARK_Mode (On);
--  The flight log on an SD card over the FAT file system's proof shape, the
--  shape the proof covers.
with Adaflight.Blackbox_SD;
with Adaflight.FAT_FS_Shape;

package Adaflight.Blackbox_SD_Shape is new Adaflight.Blackbox_SD (FS_Ops => Adaflight.FAT_FS_Shape);
