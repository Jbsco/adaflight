--  Runs of sectors from a virtual FAT volume, as a block storage reads them:
--  each sector as the volume fills it, or from a file's reader where the
--  volume names a file. Read_File brings one sector of a file's bytes at
--  an offset in the files' own storage.
generic
   with procedure Read_File (File : Entry_Index; Offset : Unsigned_32; Data : out Sector);
package Adaflight.Virtual_FAT.Disk with SPARK_Mode is

   Max_Run : constant := 64;

   --  Count sectors from sector First into the start of Data. A sector
   --  number past 32 bits goes on from zero.
   procedure Read
     (V : in out Volume; First : Unsigned_32; Count : Natural; Data : in out Adaflight.Bytes.Byte_Array)
     with Pre  => Ready (V) and then Count <= Max_Run and then Data'First = 0
                  and then Data'Length >= Count * Sector_Size,
          Post => Ready (V) and then V.Count = V.Count'Old;

end Adaflight.Virtual_FAT.Disk;
