--  An OSD chip's SPI device as steps that do nothing, the shape the OSD chip
--  driver's proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.OSD_Chip_Steps with SPARK_Mode is

   type Chip_Line is null record;

   procedure Step_Preinit_CS (D : in out Chip_Line; Tag : Byte; Push_Pull : Boolean)
     with Global => null;

   procedure Step_Attach_Bus (D : in out Chip_Line; Instance : Byte; OK : out Boolean)
     with Global => null;

   procedure Step_Check_CS_Free (D : in out Chip_Line; Free : out Boolean)
     with Global => null;

   procedure Step_Prepare_CS (D : in out Chip_Line)
     with Global => null;

   procedure Step_Release_CS (D : in out Chip_Line)
     with Global => null;

   procedure Step_Claim_CS (D : in out Chip_Line)
     with Global => null;

   procedure Step_Divider (D : in out Chip_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16)
     with Global => null;

   function Step_Clock_Of (D : Chip_Line; Divisor : Interfaces.Unsigned_16) return Interfaces.Unsigned_32
     with Global => null;

   procedure Step_Set_Divisor (D : in out Chip_Line; Divisor : Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Write_Byte (D : in out Chip_Line; Value : Byte)
     with Global => null;

   procedure Step_Write_Register (D : in out Chip_Line; Register : Byte; Value : Byte)
     with Global => null;

   procedure Step_Read_Register (D : in out Chip_Line; Register : Byte; Value : out Byte)
     with Global => null;

   procedure Step_Write_Buffer (D : in out Chip_Line; Data : Byte_Array)
     with Global => null;

   procedure Step_Start_Transfer (D : in out Chip_Line; Data : Byte_Array)
     with Global => null;

   procedure Step_Check_Busy (D : in out Chip_Line; Busy : out Boolean)
     with Global => null;

   function Step_Uses_DMA (D : Chip_Line) return Boolean
     with Global => null;

   function Step_Transfer_Pending (D : Chip_Line) return Boolean
     with Global => null;

   procedure Step_Wait (D : in out Chip_Line)
     with Global => null;

   procedure Step_Millis (D : in out Chip_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Micros (D : in out Chip_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Delay_Ms (D : in out Chip_Line; Ms : Natural)
     with Global => null;

   procedure Step_Delay_Us (D : in out Chip_Line; Us : Natural)
     with Global => null;

   procedure Step_Toggle_LED (D : in out Chip_Line)
     with Global => null;

end Adaflight.OSD_Chip_Steps;
