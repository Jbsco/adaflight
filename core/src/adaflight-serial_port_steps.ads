--  A serial port as steps that do nothing, the shape the serial device
--  drivers' proofs take.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Serial_Port_Steps with SPARK_Mode is

   type Port_Line is null record;

   procedure Step_Open_Port
     (D : in out Port_Line; Port : Interfaces.Integer_8; Baud : Interfaces.Unsigned_32; Opened : out Boolean)
     with Global => null;

   procedure Step_Bytes_Waiting (D : in out Port_Line; Count : out Natural)
     with Global => null;

   procedure Step_Read_Byte (D : in out Port_Line; B : out Byte)
     with Global => null;

   procedure Step_Write_Bytes (D : in out Port_Line; Data : Byte_Array)
     with Global => null;

   procedure Step_Millis (D : in out Port_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

end Adaflight.Serial_Port_Steps;
