--  The flash chip of a build without one: no chip, no file system and no log.
package body Adaflight.STM32.Flash_Chip is

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is null;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is null;

   function Supported return Boolean is (False);

   procedure Is_Ready (Ready : out Boolean) is
   begin
      Ready := False;
   end Is_Ready;

   function Full return Boolean is (False);

   function Free_Space return Natural is (0);

   function Buffer_Usable return Natural is (0);

   procedure Write (Data : Byte_Array) is null;

   procedure Flush (Force : Boolean; Done : out Boolean) is
   begin
      Done := True;
   end Flush;

   procedure Erase_Completely is null;

   procedure Close is null;

   procedure Erase_Step is null;

   procedure Verify (OK : out Boolean) is
   begin
      OK := False;
   end Verify;

   procedure Seek (Address : Interfaces.Unsigned_32) is null;

   procedure Write_Text (Data : String) is null;

   procedure Flush_Sync is null;

   procedure Read_Text (Address : Interfaces.Unsigned_32; Length : Natural; Data : out String; Count : out Natural) is
   begin
      Data := (others => ' ');
      Count := 0;
   end Read_Text;

   function Summary return Adaflight.MSP_Hardware_Out.Flash_Values is (others => <>);

   function Geometry return Adaflight.Flash_Device.Geometry is (others => <>);

   function Partition_Count return Natural is (0);

   procedure Partition
     (Index : Natural; Found : out Boolean; Kind : out Natural; First, Last : out Interfaces.Unsigned_16) is
   begin
      Found := False;
      Kind := 0;
      First := 0;
      Last := 0;
   end Partition;

   function Offset return Interfaces.Unsigned_32 is (0);

end Adaflight.STM32.Flash_Chip;
