--  A flash chip's quad SPI controller as steps that do nothing, the shape
--  the chip driver's proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Flash_Device;

package Adaflight.Quad_Bus_Steps with SPARK_Mode is

   type Quad_Line is null record;

   procedure Step_Transmit (D : in out Quad_Line; Instruction : Byte; Data : Byte_Array)
     with Global => null;

   procedure Step_Receive (D : in out Quad_Line; Instruction : Byte; Data : out Byte_Array)
     with Global => null;

   procedure Step_Instruction_With_Address
     (D : in out Quad_Line; Instruction : Byte; Address : Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Receive_With_Address
     (D           : in out Quad_Line;
      Instruction : Byte;
      Dummy       : Natural;
      Address     : Interfaces.Unsigned_32;
      Data        : out Byte_Array;
      OK          : out Boolean)
     with Global => null;

   procedure Step_Run
     (D      : in out Quad_Line;
      F      : in out Flash_Device.Device;
      Q      : Flash_Device.Sequence;
      First  : Flash_Device.Segment_Index;
      Data_1 : Byte_Array;
      Data_2 : Byte_Array)
     with Global => null;

   procedure Step_Wait (D : in out Quad_Line)
     with Global => null;

   procedure Step_Millis (D : in out Quad_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Report_Written (D : in out Quad_Line; Bytes : Interfaces.Unsigned_32)
     with Global => null;

end Adaflight.Quad_Bus_Steps;
