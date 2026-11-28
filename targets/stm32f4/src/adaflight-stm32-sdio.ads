--  The SDIO controller of a card on the SDIO bus: its pins and clock, the
--  card's identification at 400 kHz and its four-bit transfers at its data
--  clock, block reads and writes, the card's transfer state, and its
--  identification and size. H7 builds drive SDMMC1; F4 and F7 builds have no
--  port yet and report no hardware.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SD_Card_Bus;
with Adaflight.SD_Card_Types;
package Adaflight.STM32.SDIO is
   Max_Write_Blocks : constant := 16;
   procedure Init_Hardware (OK : out Boolean);
   procedure Init_Card (OK : out Boolean);
   --  Whether the card is in its transfer state.
   procedure Check_Ready (Ready : out Boolean);
   procedure Card_Info (Info : out Adaflight.SD_Card_Types.Card_Information; OK : out Boolean);
   function Read_Pending return Boolean;
   function Write_Pending return Boolean;
   procedure Start_Read (Index : Interfaces.Unsigned_32; OK : out Boolean);
   --  The block the last read transferred.
   procedure Fetch_Block (Data : out Adaflight.SD_Card_Bus.Block);
   --  A transfer of Data'Length / 512 blocks from Index.
   procedure Start_Write (Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean)
     with Pre => Data'Length mod 512 = 0 and then Data'Length in 512 .. Max_Write_Blocks * 512;
end Adaflight.STM32.SDIO;
