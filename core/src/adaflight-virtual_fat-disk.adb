package body Adaflight.Virtual_FAT.Disk with SPARK_Mode is

   procedure Read
     (V : in out Volume; First : Unsigned_32; Count : Natural; Data : in out Adaflight.Bytes.Byte_Array)
   is
      Part : Sector;
      From : Source;
   begin
      for I in 0 .. Count - 1 loop
         pragma Loop_Invariant (Ready (V) and then V.Count = V.Count'Loop_Entry);
         Read (V, First + Unsigned_32 (I), Part, From);
         if From.Kind = From_File then
            Read_File (From.File, From.Offset, Part);
         end if;
         Data (I * Sector_Size .. I * Sector_Size + Sector_Size - 1) := Part;
      end loop;
   end Read;

end Adaflight.Virtual_FAT.Disk;
