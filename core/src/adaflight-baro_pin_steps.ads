--  A barometer's pins and conversion-end interrupt as steps that do nothing,
--  the shape the BMP085 proof takes.
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Sensor_Bus_Steps; use Adaflight.Sensor_Bus_Steps;

package Adaflight.Baro_Pin_Steps with SPARK_Mode is

   procedure Step_Init_Pin (D : in out Bus_Line; Tag : Byte; Owner : Byte)
     with Global => null;

   procedure Step_Config_Pin (D : in out Bus_Line; Tag : Byte)
     with Global => null;

   procedure Step_Pin_High (D : in out Bus_Line; Tag : Byte)
     with Global => null;

   procedure Step_Pin_Low (D : in out Bus_Line; Tag : Byte)
     with Global => null;

   procedure Step_Read_Pin (D : in out Bus_Line; Tag : Byte; High : out Boolean)
     with Global => null;

   procedure Step_Release_Pin (D : in out Bus_Line; Tag : Byte)
     with Global => null;

   procedure Step_Interrupt_Init (D : in out Bus_Line)
     with Global => null;

   procedure Step_Interrupt_Pin (D : in out Bus_Line; Tag : Byte)
     with Global => null;

end Adaflight.Baro_Pin_Steps;
