--  An SD card's SPI bus as steps that do nothing, the shape the card
--  driver's proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SD_Card_Bus;

package Adaflight.Card_Bus_Steps with SPARK_Mode is

   type Card_Line is null record;

   procedure Step_Preinit_CS (D : in out Card_Line; Tag : Byte)
     with Global => null;

   procedure Step_Init_Detect_Pin (D : in out Card_Line)
     with Global => null;

   procedure Step_Read_Detect_Pin (D : in out Card_Line; High : out Boolean)
     with Global => null;

   procedure Step_Attach_Bus (D : in out Card_Line; Instance : Byte)
     with Global => null;

   procedure Step_Prepare_CS (D : in out Card_Line)
     with Global => null;

   procedure Step_Configure_CS (D : in out Card_Line)
     with Global => null;

   procedure Step_CS_High (D : in out Card_Line)
     with Global => null;

   procedure Step_Divider (D : in out Card_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Set_Divisor (D : in out Card_Line; Divisor : Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Delay_Ms (D : in out Card_Line; Ms : Natural)
     with Global => null;

   procedure Step_Delay_Us (D : in out Card_Line; Us : Natural)
     with Global => null;

   procedure Step_Millis (D : in out Card_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Start_Sequence (D : in out Card_Line)
     with Global => null;

   procedure Step_Segment
     (D       : in out Card_Line;
      Kind    : Adaflight.SD_Card_Bus.Segment_Kind;
      Negate  : Boolean;
      Length  : Positive;
      Tx      : Byte_Array;
      Rx      : in out Byte_Array;
      Receive : Boolean)
     with Global => null;

   procedure Step_Wait (D : in out Card_Line)
     with Global => null;

   procedure Step_Release (D : in out Card_Line)
     with Global => null;

   procedure Step_Bus_Busy (D : in out Card_Line; Busy : out Boolean)
     with Global => null;

   function Step_Uses_DMA (D : Card_Line) return Boolean
     with Global => null;

   procedure Step_Read_Write (D : in out Card_Line; Tx : Byte_Array)
     with Global => null;

   procedure Step_Complete
     (D          : in out Card_Line;
      Write      : Boolean;
      Index      : Interfaces.Unsigned_32;
      Has_Buffer : Boolean;
      Data       : Interfaces.Unsigned_32)
     with Global => null;

end Adaflight.Card_Bus_Steps;
