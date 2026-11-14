--  A flash that reads as zeros, the shape the proofs of the log file list
--  and of sector runs take.
with Interfaces;
with Adaflight.Virtual_FAT;

package Adaflight.Virtual_FAT_Steps with SPARK_Mode is

   procedure Read (Offset : Interfaces.Unsigned_32; Data : out Adaflight.Virtual_FAT.Flash_Read)
     with Global => null;

   procedure Read_Sector
     (File   : Adaflight.Virtual_FAT.Entry_Index;
      Offset : Interfaces.Unsigned_32;
      Data   : out Adaflight.Virtual_FAT.Sector)
     with Global => null;

end Adaflight.Virtual_FAT_Steps;
