--  The SD card of the board: the card driver over the SPI bus the stored
--  configuration names with its select and detect pins, the FAT file system
--  over the card with no clock, and the flight log's card device. The main
--  task's poll advances the card, hands a finished block to the file system
--  and then polls the file system.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.FAT;
with Adaflight.MSP_Hardware_Out;
with Adaflight.SD_Card_Types;
package Adaflight.STM32.SD is
   --  The select pin as the stored configuration names it, driven high
   --  before the SPI buses start.
   procedure Preinit (C : Adaflight.Config_Groups.Configuration);
   --  The card driver and the file system started from the configuration.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  The main task's poll.
   procedure Poll;
   --  Whether the configuration names a card.
   function Configured return Boolean;
   --  Whether the detect pin reads a card, as of the last poll.
   function Inserted return Boolean;
   --  The card and file system state the MSP reports, and what the command
   --  line reports beside it: the card's metadata, the file system's state
   --  and its last error.
   function Summary return Adaflight.MSP_Hardware_Out.SD_Card_Values;
   function Card_Info return Adaflight.SD_Card_Types.Metadata;
   function File_System_State return Adaflight.FAT.Filesystem_State;
   function Last_Error return Adaflight.FAT.Error_Kind;

   --  The flight log's device: whether the file system takes a log, whether
   --  the card is full, the bytes its cache takes, the steps of a log start
   --  and end, a flush and the bytes of an iteration.
   function Log_Open_OK return Boolean;
   function Log_Full return Boolean;
   function Log_Free_Space return Natural;
   procedure Log_Begin (Done : out Boolean);
   procedure Log_End (Retain : Boolean; Done : out Boolean);
   procedure Log_Flush (Done : out Boolean);
   procedure Log_Write (Data : Byte_Array);
   function Log_Number return Interfaces.Integer_32;
end Adaflight.STM32.SD;
