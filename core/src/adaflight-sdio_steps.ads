--  An SD card's SDIO controller as steps that do nothing, the shape the
--  card driver's proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SD_Card_Bus;
with Adaflight.SD_Card_Types;

package Adaflight.SDIO_Steps with SPARK_Mode is

   type Controller is null record;

   procedure Step_Init_Detect_Pin (D : in out Controller)
     with Global => null;

   procedure Step_Read_Detect_Pin (D : in out Controller; High : out Boolean)
     with Global => null;

   procedure Step_Find_DMA (D : in out Controller; Identifier : out Natural)
     with Global => null;

   function Step_Cache_Writes (D : Controller) return Boolean
     with Global => null;

   procedure Step_Init_Hardware (D : in out Controller; OK : out Boolean)
     with Global => null;

   procedure Step_Init_Card (D : in out Controller; OK : out Boolean)
     with Global => null;

   procedure Step_Check_Ready (D : in out Controller; Ready : out Boolean)
     with Global => null;

   procedure Step_Card_Info (D : in out Controller; Info : out SD_Card_Types.Card_Information; OK : out Boolean)
     with Global => null;

   procedure Step_Read_Pending (D : in out Controller; Pending : out Boolean)
     with Global => null;

   procedure Step_Write_Pending (D : in out Controller; Pending : out Boolean)
     with Global => null;

   procedure Step_Start_Read (D : in out Controller; Index : Interfaces.Unsigned_32; OK : out Boolean)
     with Global => null;

   procedure Step_Fetch_Block (D : in out Controller; Index : Interfaces.Unsigned_32; Data : out SD_Card_Bus.Block)
     with Global => null;

   procedure Step_Start_Write
     (D : in out Controller; Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean)
     with Global => null;

   procedure Step_Millis (D : in out Controller; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Complete
     (D             : in out Controller;
      Write         : Boolean;
      Index         : Interfaces.Unsigned_32;
      Has_Buffer    : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Data          : SD_Card_Bus.Block)
     with Global => null;

end Adaflight.SDIO_Steps;
