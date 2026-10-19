--  The card state, the operation results, the configuration, the metadata
--  and the controller's card information the SD card drivers share.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.SD_Card_Types with SPARK_Mode is

   Mode_Off  : constant Byte := 0;
   Mode_SPI  : constant Byte := 1;
   Mode_SDIO : constant Byte := 2;

   type Card_State is
     (Not_Present, Resetting, Initializing, Receiving_CID, Ready, Reading, Sending_Write, Waiting_For_Write,
      Writing_Multiple, Stopping_Multiple);

   type Operation_Status is (In_Progress, Busy, Success, Failure);

   --  The bus, the detect and select pin tags, 0 for none, whether the
   --  detect pin reads low for a card, and the mode.
   type Config is record
      Device          : Byte := 0;
      Detect_Tag      : Byte := 0;
      CS_Tag          : Byte := 0;
      Detect_Inverted : Boolean := False;
      Mode            : Byte := Mode_Off;
   end record;

   type Metadata is record
      Num_Blocks       : Interfaces.Unsigned_32 := 0;
      OEM_Id           : Interfaces.Unsigned_16 := 0;
      Manufacturer     : Byte := 0;
      Product_Name     : Byte_Array (0 .. 4) := (others => 0);
      Serial           : Interfaces.Unsigned_32 := 0;
      Revision_Major   : Byte := 0;
      Revision_Minor   : Byte := 0;
      Production_Year  : Interfaces.Unsigned_16 := 0;
      Production_Month : Byte := 0;
   end record;

   --  What an SDIO controller reports of its card: the kind, 0 for a
   --  standard capacity version 1 card, 1 for version 2 and 2 for high
   --  capacity, the capacity in blocks, and the identification register.
   type Card_Information is record
      Kind         : Byte := 0;
      Capacity     : Interfaces.Unsigned_64 := 0;
      Manufacturer : Byte := 0;
      OEM_Id       : Interfaces.Unsigned_16 := 0;
      Name_Head    : Interfaces.Unsigned_32 := 0;
      Name_Tail    : Byte := 0;
      Revision     : Byte := 0;
      Serial       : Interfaces.Unsigned_32 := 0;
      Date         : Interfaces.Unsigned_16 := 0;
   end record;

end Adaflight.SD_Card_Types;
