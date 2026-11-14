--  A flash that reads as zeros, the shape the log file list's proof takes.
with Interfaces;
with Adaflight.Virtual_FAT;

package Adaflight.Virtual_FAT_Steps with SPARK_Mode is

   procedure Read (Offset : Interfaces.Unsigned_32; Data : out Adaflight.Virtual_FAT.Flash_Read)
     with Global => null;

end Adaflight.Virtual_FAT_Steps;
