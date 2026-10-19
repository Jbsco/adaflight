--  An SD card over an SDIO controller, which runs the card commands
--  itself. Initialization takes the detect pin, the DMA stream of the
--  controller, the write cache setting and the controller, then asks the controller to start the card, which it does
--  to the end: each poll moves the card from the reset through the
--  initialization, done when the controller reports the card ready and
--  gives its information, which names the version and the capacity class,
--  the block count and the identification for the metadata. A read starts
--  a block transfer and the poll takes the block when the transfer ends
--  with the card ready, within 100 ms, after which the poll repeats until
--  the card answers. A write starts the block transfer, the poll calls the
--  completion when the transfer ends and waits for the card to leave busy
--  within 250 ms. With the write cache, the blocks of a run collect in a
--  cache of 16 and go to the card in one transfer when the cache fills or
--  the run ends, each cached block answered success without a completion.
--  A run of writes takes its count and ends when a write leaves the run or
--  its count runs out. A failure asks the controller for a new
--  initialization: one refused counts the failure, up to eight in a row or
--  a missing card before the card counts as absent; one accepted leaves
--  the state as it was. An initialization past a second starts over. An
--  operation the controller refuses answers a failure; one in the wrong
--  state answers busy. A card whose mode is off takes no operation. A poll
--  repeats at most 64 times where the reference repeats until the
--  controller answers.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SD_Card_Bus; use Adaflight.SD_Card_Bus;
with Adaflight.SD_Card_Types; use Adaflight.SD_Card_Types;

generic
   type SDIO_Device is limited private;
   with procedure Init_Detect_Pin (D : in out SDIO_Device);
   with procedure Read_Detect_Pin (D : in out SDIO_Device; High : out Boolean);
   --  The DMA stream of the controller, 0 when the family takes one from
   --  the map and the map has none.
   with procedure Find_DMA (D : in out SDIO_Device; Identifier : out Natural);
   with function Cache_Writes (D : SDIO_Device) return Boolean;
   with procedure Init_Hardware (D : in out SDIO_Device; OK : out Boolean);
   with procedure Init_Card (D : in out SDIO_Device; OK : out Boolean);
   --  Whether the card is in its transfer state.
   with procedure Check_Ready (D : in out SDIO_Device; Ready : out Boolean);
   with procedure Card_Info (D : in out SDIO_Device; Info : out Card_Information; OK : out Boolean);
   with procedure Read_Pending (D : in out SDIO_Device; Pending : out Boolean);
   with procedure Write_Pending (D : in out SDIO_Device; Pending : out Boolean);
   with procedure Start_Read (D : in out SDIO_Device; Index : Interfaces.Unsigned_32; OK : out Boolean);
   --  The block the last read transferred.
   with procedure Fetch_Block (D : in out SDIO_Device; Index : Interfaces.Unsigned_32; Data : out Block);
   --  A transfer of Data'Length / 512 blocks from Index.
   with procedure Start_Write
     (D : in out SDIO_Device; Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean);
   with procedure Millis (D : in out SDIO_Device; Now : out Interfaces.Unsigned_32);
   --  The completion of a read or a write, with the block when it has one.
   with procedure Complete
     (D             : in out SDIO_Device;
      Write         : Boolean;
      Index         : Interfaces.Unsigned_32;
      Has_Buffer    : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Data          : Block);
package Adaflight.SD_Card_SDIO with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   Cache_Blocks : constant := 16;

   subtype Cache_Count is Natural range 0 .. Cache_Blocks;

   subtype Cache_Bytes is Byte_Array (0 .. Cache_Blocks * Block_Bytes - 1);

   --  The block a read or write works on and the completion's data.
   type Pending is record
      Index         : Interfaces.Unsigned_32 := 0;
      Has_Callback  : Boolean := False;
      Callback_Data : Interfaces.Unsigned_32 := 0;
   end record;

   type Card is record
      State           : Card_State := Not_Present;
      Enabled         : Boolean := False;
      Use_Cache       : Boolean := False;
      Has_Detect_Pin  : Boolean := False;
      Detect_Inverted : Boolean := False;
      Operation_Start : Interfaces.Unsigned_32 := 0;
      Failure_Count   : Byte := 0;
      Version         : Byte := 0;
      High_Capacity   : Boolean := False;
      Multi_Next      : Interfaces.Unsigned_32 := 0;
      Multi_Remain    : Interfaces.Unsigned_32 := 0;
      Op              : Pending;
      Data            : Block := (others => 0);
      Cached          : Cache_Count := 0;
      Cache           : Cache_Bytes := (others => 0);
      Meta            : Metadata;
   end record;

   procedure Init (D : in out SDIO_Device; S : in out Card; C : Config);

   procedure Is_Inserted (D : in out SDIO_Device; S : Card; Inserted : out Boolean);

   --  The card's state advanced; Ready when a block operation can start.
   procedure Poll (D : in out SDIO_Device; S : in out Card; Card_Ready : out Boolean);

   --  A read of a block, accepted when the controller took it; its bytes
   --  arrive in the card's data at the completion.
   procedure Read_Block
     (D             : in out SDIO_Device;
      S             : in out Card;
      Index         : Interfaces.Unsigned_32;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Accepted      : out Boolean);

   procedure Write_Block
     (D             : in out SDIO_Device;
      S             : in out Card;
      Index         : Interfaces.Unsigned_32;
      Data          : Block;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Status        : out Operation_Status);

   procedure Begin_Write_Blocks
     (D      : in out SDIO_Device;
      S      : in out Card;
      Index  : Interfaces.Unsigned_32;
      Count  : Interfaces.Unsigned_32;
      Status : out Operation_Status);

   function Is_Functional (S : Card) return Boolean is (S.State /= Not_Present);

   function Is_Initialized (S : Card) return Boolean is (S.State >= Ready);

   function Get_Metadata (S : Card) return Metadata is (S.Meta);

end Adaflight.SD_Card_SDIO;
