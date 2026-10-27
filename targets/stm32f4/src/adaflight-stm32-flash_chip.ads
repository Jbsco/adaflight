--  The flash chip of the board on the SPI bus the stored configuration
--  names with its select pin: the chip driver of the M25P16 family under
--  the flash layer, the flash file system over its partition with the
--  start of the free space found at initialization, each file system
--  call's operations carried out on the chip, the erase step of the main
--  task, and the readings the flight log, the MSP summary and the command
--  line take.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.Flash_Device;
with Adaflight.MSP_Hardware_Out;
package Adaflight.STM32.Flash_Chip is
   --  The select pin as the stored configuration names it, driven high
   --  before the SPI buses start.
   procedure Preinit (C : Adaflight.Config_Groups.Configuration);
   --  The chip identified on its bus and the file system over it.
   procedure Init (C : Adaflight.Config_Groups.Configuration);

   --  The flight log's device: whether a file system sits on the chip,
   --  whether the chip is ready, whether the volume is full, the bytes the
   --  write buffer takes, its usable size, the bytes of an iteration, a
   --  flush, the erase of the volume, and the end of a log.
   function Supported return Boolean;
   procedure Is_Ready (Ready : out Boolean);
   function Full return Boolean;
   function Free_Space return Natural;
   function Buffer_Usable return Natural;
   procedure Write (Data : Byte_Array);
   procedure Flush (Force : Boolean; Done : out Boolean);
   procedure Erase_Completely;
   procedure Close;
   --  The main task's erase step.
   procedure Erase_Step;

   --  The command line's tools: the verify of the whole flash, a seek, a
   --  synchronous write, a synchronous flush, and a read.
   procedure Verify (OK : out Boolean);
   procedure Seek (Address : Interfaces.Unsigned_32);
   procedure Write_Text (Data : String);
   procedure Flush_Sync;
   procedure Read_Text (Address : Interfaces.Unsigned_32; Length : Natural; Data : out String; Count : out Natural);

   --  The MSP summary, the chip's geometry, a partition and the file
   --  system's offset for the command line.
   function Summary return Adaflight.MSP_Hardware_Out.Flash_Values;
   function Geometry return Adaflight.Flash_Device.Geometry;
   function Partition_Count return Natural;
   procedure Partition
     (Index : Natural; Found : out Boolean; Kind : out Natural; First, Last : out Interfaces.Unsigned_16);
   function Offset return Interfaces.Unsigned_32;
end Adaflight.STM32.Flash_Chip;
