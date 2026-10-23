--  A gyro's SPI device as steps that do nothing, the shape the gyro layer's
--  proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Gyro_Bus_Steps with SPARK_Mode is

   type Gyro_Line is null record;

   procedure Step_Preinit_CS (D : in out Gyro_Line; Tag : Byte)
     with Global => null;

   procedure Step_Attach_Bus (D : in out Gyro_Line; Instance : Byte; OK : out Boolean)
     with Global => null;

   procedure Step_Prepare_CS (D : in out Gyro_Line; Index : Byte)
     with Global => null;

   procedure Step_Release_CS (D : in out Gyro_Line)
     with Global => null;

   procedure Step_Divider (D : in out Gyro_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Set_Divisor (D : in out Gyro_Line; Divisor : Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Probe_Chip (D : in out Gyro_Line; Index : Positive; Sensor : out Byte)
     with Global => null;

   procedure Step_Register_Device (D : in out Gyro_Line)
     with Global => null;

   procedure Step_Millis (D : in out Gyro_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Delay_Ms (D : in out Gyro_Line; Ms : Natural)
     with Global => null;

   procedure Step_Enable_Interrupt (D : in out Gyro_Line)
     with Global => null;

   procedure Step_Cycle_Count (D : in out Gyro_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Start_Sequence (D : in out Gyro_Line; Data : Byte_Array; Completion : Boolean)
     with Global => null;

   procedure Step_Wait (D : in out Gyro_Line)
     with Global => null;

   procedure Step_Fetch (D : in out Gyro_Line; Data : out Byte_Array)
     with Global => null;

   function Step_Uses_DMA (D : Gyro_Line) return Boolean
     with Global => null;

   procedure Step_Read_Registers (D : in out Gyro_Line; Register : Byte; Data : in out Byte_Array; OK : out Boolean)
     with Global => null;

   procedure Step_Write_Register (D : in out Gyro_Line; Register : Byte; Value : Byte)
     with Global => null;

   procedure Step_Read_Register (D : in out Gyro_Line; Register : Byte; Value : out Byte)
     with Global => null;

   procedure Step_Delay_Us (D : in out Gyro_Line; Us : Natural)
     with Global => null;

   function Step_Micros_To_Cycles (Micros : Interfaces.Unsigned_32) return Interfaces.Unsigned_32
     with Global => null;

   procedure Step_Failure (D : in out Gyro_Line)
     with Global => null;

   procedure Step_Start_Clock_In (D : in out Gyro_Line; Started : out Boolean)
     with Global => null;

   procedure Step_Bus_Write_Register (D : in out Gyro_Line; Register : Byte; Value : Byte)
     with Global => null;

end Adaflight.Gyro_Bus_Steps;
