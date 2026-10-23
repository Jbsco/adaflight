--  An ESC's signal pin and the board's clocks as steps that do nothing, the
--  shape the bootloader protocols' proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.ESC_Pin_Steps with SPARK_Mode is

   type Pin_Line is null record;

   procedure Step_Read_Micros (L : in out Pin_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Read_Millis (L : in out Pin_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Read_Pin (L : in out Pin_Line; ESC : Byte; High : out Boolean)
     with Global => null;

   procedure Step_Pin_Low (L : in out Pin_Line; ESC : Byte)
     with Global => null;

   procedure Step_Pin_High (L : in out Pin_Line; ESC : Byte)
     with Global => null;

   procedure Step_Pin_Input (L : in out Pin_Line; ESC : Byte)
     with Global => null;

   procedure Step_Pin_Output (L : in out Pin_Line; ESC : Byte)
     with Global => null;

end Adaflight.ESC_Pin_Steps;
