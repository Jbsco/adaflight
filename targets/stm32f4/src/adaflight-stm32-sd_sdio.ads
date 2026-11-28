--  The SD card over the SDIO controller: the SDIO card driver on
--  Adaflight.STM32.SDIO, and the completion its last poll reported. A build
--  without the SDIO card takes a body that never starts one.
with Interfaces;
with Adaflight.SD_Card_Bus;
with Adaflight.SD_Card_Types;
package Adaflight.STM32.SD_SDIO is
   type Completion is record
      Done   : Boolean := False;
      Write  : Boolean := False;
      OK     : Boolean := False;
      Index  : Interfaces.Unsigned_32 := 0;
      Buffer : Interfaces.Unsigned_32 := 0;
   end record;
   procedure Init (Setup : Adaflight.SD_Card_Types.Config);
   procedure Is_Inserted (Inserted : out Boolean);
   --  The card's state advanced; Card_Ready when a block operation can start.
   procedure Poll (Card_Ready : out Boolean);
   procedure Read_Block
     (Index : Interfaces.Unsigned_32; Has_Callback : Boolean; Callback_Data : Interfaces.Unsigned_32;
      Accepted : out Boolean);
   procedure Write_Block
     (Index         : Interfaces.Unsigned_32;
      Data          : Adaflight.SD_Card_Bus.Block;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Status        : out Adaflight.SD_Card_Types.Operation_Status);
   procedure Begin_Write_Blocks
     (Index : Interfaces.Unsigned_32; Count : Interfaces.Unsigned_32;
      Status : out Adaflight.SD_Card_Types.Operation_Status);
   function Is_Functional return Boolean;
   function Is_Initialized return Boolean;
   function Metadata return Adaflight.SD_Card_Types.Metadata;
   --  The block the last completed read brought.
   function Data return Adaflight.SD_Card_Bus.Block;
   --  The completion the driver reported since the last take, taken once.
   procedure Take_Completion (C : out Completion);
end Adaflight.STM32.SD_SDIO;
