--  A sensor chip's bus as steps that do nothing, the shape the sensor
--  drivers' proofs take.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Sensor_Bus_Steps with SPARK_Mode is

   type Bus_Line is null record;

   function Step_Is_I2C (D : Bus_Line) return Boolean
     with Global => null;

   function Step_Is_SPI (D : Bus_Line) return Boolean
     with Global => null;

   function Step_I2C_Address (D : Bus_Line) return Byte
     with Global => null;

   procedure Step_Set_I2C_Address (D : in out Bus_Line; Address : Byte)
     with Global => null;

   procedure Step_Prepare_SPI (D : in out Bus_Line; Max_Clock_Hz : Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Release_SPI (D : in out Bus_Line)
     with Global => null;

   procedure Step_Enable_EOC_Interrupt (D : in out Bus_Line)
     with Global => null;

   procedure Step_Read_Registers (D : in out Bus_Line; Register : Byte; Data : in out Byte_Array; OK : out Boolean)
     with Global => null;

   procedure Step_Write_Register (D : in out Bus_Line; Register : Byte; Value : Byte; OK : out Boolean)
     with Global => null;

   procedure Step_Start_Read (D : in out Bus_Line; Register : Byte; Length : Positive; Started : out Boolean)
     with Global => null;

   procedure Step_Start_Write (D : in out Bus_Line; Register : Byte; Value : Byte; Started : out Boolean)
     with Global => null;

   procedure Step_Check_Busy (D : in out Bus_Line; Busy : out Boolean; Error : out Boolean)
     with Global => null;

   procedure Step_Fetch (D : in out Bus_Line; Data : out Byte_Array)
     with Global => null;

   procedure Step_Register_Device (D : in out Bus_Line)
     with Global => null;

   procedure Step_Delay_Ms (D : in out Bus_Line; Ms : Natural)
     with Global => null;

   procedure Step_Delay_Us (D : in out Bus_Line; Us : Natural)
     with Global => null;

   procedure Step_Millis (D : in out Bus_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

end Adaflight.Sensor_Bus_Steps;
