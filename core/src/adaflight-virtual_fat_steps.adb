package body Adaflight.Virtual_FAT_Steps with SPARK_Mode is

   procedure Read (Offset : Interfaces.Unsigned_32; Data : out Adaflight.Virtual_FAT.Flash_Read) is
      pragma Unreferenced (Offset);
   begin
      Data := (others => 0);
   end Read;

end Adaflight.Virtual_FAT_Steps;
