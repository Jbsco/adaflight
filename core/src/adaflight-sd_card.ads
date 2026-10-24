--  An SD card over SPI. Initialization takes the detect pin, the bus and the
--  select pin, sets the 400 kHz clock, waits a second and clocks ten idle
--  bytes before it starts the card: each poll advances the card from the
--  reset command through the interface condition, which names the version,
--  the initialization command repeated until it answers, the operating
--  conditions for the capacity of a version 2 card, the card specific data
--  for the block count, the identification for the metadata and the 512
--  byte block length of a standard capacity card, then sets the 25 MHz
--  clock. A command waits for an idle byte, up to eight, sends its six
--  bytes and waits for the answer, up to eight bytes; a data block waits
--  for its token, up to eight bytes, and its two check bytes are
--  discarded. A read sends the read command and the poll takes the block
--  when its token comes, within 100 ms. A write sends the write command,
--  the token and the block, the whole block with DMA or 256 bytes at a
--  time, the poll finishes it with two check bytes and takes the card's
--  answer, calls the completion, and waits for the card to leave busy
--  within 250 ms; a run of writes sends its count and the multiple block
--  command, and ends with the stop token when a write leaves the run or
--  its count runs out. Each failure resets the card, up to eight in a row
--  before it counts as absent, and an initialization past a second starts
--  over. An operation the card refuses answers a failure; one in the
--  wrong state answers busy. A card whose mode is off takes no operation.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SD_Card_Bus; use Adaflight.SD_Card_Bus;
with Adaflight.SD_Card_Types; use Adaflight.SD_Card_Types;

generic
   type SPI_Device is limited private;
   with procedure Preinit_CS (D : in out SPI_Device; Tag : Byte);
   with procedure Init_Detect_Pin (D : in out SPI_Device);
   with procedure Read_Detect_Pin (D : in out SPI_Device; High : out Boolean);
   with procedure Attach_Bus (D : in out SPI_Device; Instance : Byte);
   with procedure Prepare_CS (D : in out SPI_Device);
   with procedure Configure_CS (D : in out SPI_Device);
   with procedure CS_High (D : in out SPI_Device);
   with procedure Divider (D : in out SPI_Device; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16);
   with procedure Set_Divisor (D : in out SPI_Device; Divisor : Interfaces.Unsigned_16);
   with procedure Delay_Ms (D : in out SPI_Device; Ms : Natural);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
   with procedure Millis (D : in out SPI_Device; Now : out Interfaces.Unsigned_32);
   with procedure Start_Sequence (D : in out SPI_Device);
   --  One segment: Length bytes, from Tx or idle bytes when Tx is empty,
   --  into Rx when Receive; the select pin negated after when Negate.
   with procedure Segment
     (D       : in out SPI_Device;
      Kind    : Segment_Kind;
      Negate  : Boolean;
      Length  : Positive;
      Tx      : Byte_Array;
      Rx      : in out Byte_Array;
      Receive : Boolean);
   with procedure Wait (D : in out SPI_Device);
   with procedure Release (D : in out SPI_Device);
   with procedure Bus_Busy (D : in out SPI_Device; Busy : out Boolean);
   with function Uses_DMA (D : SPI_Device) return Boolean;
   with procedure Read_Write (D : in out SPI_Device; Tx : Byte_Array);
   --  The completion of a read or a write, with the block when it has one.
   with procedure Complete
     (D          : in out SPI_Device;
      Write      : Boolean;
      Index      : Interfaces.Unsigned_32;
      Has_Buffer : Boolean;
      Data       : Interfaces.Unsigned_32);
package Adaflight.SD_Card with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   --  The block a read or write works on, the chunks of it sent without
   --  DMA, and the completion's data.
   type Pending is record
      Index         : Interfaces.Unsigned_32 := 0;
      Chunk         : Natural range 0 .. 2 := 0;
      Has_Callback  : Boolean := False;
      Callback_Data : Interfaces.Unsigned_32 := 0;
   end record;

   --  The bytes a wait may still take; a wait that runs out leaves -1.
   subtype Idle_Counter is Integer range -1 .. 127;

   type Card is record
      State           : Card_State := Not_Present;
      Enabled         : Boolean := False;
      Has_Detect_Pin  : Boolean := False;
      Detect_Inverted : Boolean := False;
      Operation_Start : Interfaces.Unsigned_32 := 0;
      Failure_Count   : Byte := 0;
      Version         : Byte := 0;
      High_Capacity   : Boolean := False;
      Multi_Next      : Interfaces.Unsigned_32 := 0;
      Multi_Remain    : Interfaces.Unsigned_32 := 0;
      Idle_Count      : Idle_Counter := 0;
      Op              : Pending;
      Data            : Block := (others => 0);
      Meta            : Metadata;
      CSD             : Byte_Array (0 .. 15) := (others => 0);
   end record;

   procedure Preinit (D : in out SPI_Device; C : Config);

   procedure Init (D : in out SPI_Device; S : in out Card; C : Config);

   procedure Is_Inserted (D : in out SPI_Device; S : Card; Inserted : out Boolean);

   --  The card's state advanced; Ready when a block operation can start.
   procedure Poll (D : in out SPI_Device; S : in out Card; Card_Ready : out Boolean);

   --  A read of a block, accepted when the card took the command; its
   --  bytes arrive in the card's data at the completion.
   procedure Read_Block
     (D             : in out SPI_Device;
      S             : in out Card;
      Index         : Interfaces.Unsigned_32;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Accepted      : out Boolean);

   procedure Write_Block
     (D             : in out SPI_Device;
      S             : in out Card;
      Index         : Interfaces.Unsigned_32;
      Data          : Block;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Status        : out Operation_Status);

   procedure Begin_Write_Blocks
     (D      : in out SPI_Device;
      S      : in out Card;
      Index  : Interfaces.Unsigned_32;
      Count  : Interfaces.Unsigned_32;
      Status : out Operation_Status);

   function Is_Functional (S : Card) return Boolean is (S.State /= Not_Present);

   function Is_Initialized (S : Card) return Boolean is (S.State >= Ready);

   function Get_Metadata (S : Card) return Metadata is (S.Meta);

end Adaflight.SD_Card;
