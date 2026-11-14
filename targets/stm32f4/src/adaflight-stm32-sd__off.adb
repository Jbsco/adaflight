--  The SD card of a build without it: no card, no file system and no log.
package body Adaflight.STM32.SD is

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is null;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is null;

   procedure Poll is null;

   function Configured return Boolean is (False);

   function Inserted return Boolean is (False);

   function Summary return Adaflight.MSP_Hardware_Out.SD_Card_Values is (others => <>);

   function Card_Info return Adaflight.SD_Card_Types.Metadata is (others => <>);

   function File_System_State return Adaflight.FAT.Filesystem_State is (Adaflight.FAT.Unknown);

   function Last_Error return Adaflight.FAT.Error_Kind is (Adaflight.FAT.None);

   function Log_Open_OK return Boolean is (False);

   function Log_Full return Boolean is (False);

   function Log_Free_Space return Natural is (0);

   procedure Log_Begin (Done : out Boolean) is
   begin
      Done := False;
   end Log_Begin;

   procedure Log_End (Retain : Boolean; Done : out Boolean) is
      pragma Unreferenced (Retain);
   begin
      Done := False;
   end Log_End;

   procedure Log_Flush (Done : out Boolean) is
   begin
      Done := False;
   end Log_Flush;

   procedure Log_Flush_Complete (Done : out Boolean) is
   begin
      Done := False;
   end Log_Flush_Complete;

   procedure Log_Write (Data : Byte_Array) is null;

   function Log_Number return Interfaces.Integer_32 is (0);

   function Functional return Boolean is (False);

   procedure Raw_Start is null;

   procedure Raw_Ready (OK : out Boolean) is
   begin
      OK := False;
   end Raw_Ready;

   function Block_Count return Interfaces.Unsigned_32 is (0);

   procedure Raw_Read (Index : Interfaces.Unsigned_32; Data : out Byte_Array; OK : out Boolean) is
      pragma Unreferenced (Index);
   begin
      Data := (others => 0);
      OK := False;
   end Raw_Read;

   procedure Raw_Write (Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean) is
      pragma Unreferenced (Index, Data);
   begin
      OK := False;
   end Raw_Write;

end Adaflight.STM32.SD;
