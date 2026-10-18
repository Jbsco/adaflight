--  A flash chip's SPI device as steps that do nothing, the shape the flash
--  drivers' proofs take.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Flash_Device; use Adaflight.Flash_Device;

package Adaflight.Flash_Bus_Steps with SPARK_Mode is

   type Flash_Line is null record;

   procedure Step_Read_Write (D : in out Flash_Line; Tx : Byte_Array; Rx : out Byte_Array)
     with Global => null;

   procedure Step_Write (D : in out Flash_Line; Tx : Byte_Array)
     with Global => null;

   procedure Step_Run
     (D : in out Flash_Line; F : in out Device; Q : Sequence; First : Segment_Index; Data_1 : Byte_Array;
      Data_2 : Byte_Array)
     with Global => null;

   procedure Step_Run_Read
     (D : in out Flash_Line; F : in out Device; Q : Sequence; First : Segment_Index; Received : out Byte_Array)
     with Global => null;

   procedure Step_Wait (D : in out Flash_Line)
     with Global => null;

   function Step_Uses_DMA (D : Flash_Line) return Boolean
     with Global => null;

   procedure Step_Bus_Busy (D : in out Flash_Line; Busy : out Boolean)
     with Global => null;

   procedure Step_Divider (D : in out Flash_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Set_Divisor (D : in out Flash_Line; Divisor : Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Preinit_CS (D : in out Flash_Line; Tag : Byte)
     with Global => null;

   procedure Step_CS_Free (D : in out Flash_Line; Free : out Boolean)
     with Global => null;

   procedure Step_Attach_Bus (D : in out Flash_Line; Instance : Byte; OK : out Boolean)
     with Global => null;

   procedure Step_Prepare_CS (D : in out Flash_Line)
     with Global => null;

   procedure Step_Delay_Ms (D : in out Flash_Line; Ms : Natural)
     with Global => null;

   procedure Step_Read_Id (D : in out Flash_Line; Response : out Byte_Array)
     with Global => null;

end Adaflight.Flash_Bus_Steps;
