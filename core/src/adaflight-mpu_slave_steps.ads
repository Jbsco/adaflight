--  A compass's access through a gyro's I2C master as steps that do nothing,
--  the shape the proof of a compass on the MPU slave bus takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Sensor_Bus_Steps; use Adaflight.Sensor_Bus_Steps;

package Adaflight.MPU_Slave_Steps with SPARK_Mode is

   function Step_Is_MPU_Slave (D : Bus_Line) return Boolean
     with Global => null;

   procedure Step_Master_DMA_Off (D : in out Bus_Line)
     with Global => null;

   procedure Step_Master_Write (D : in out Bus_Line; Register : Byte; Value : Byte)
     with Global => null;

   procedure Step_Master_Read (D : in out Bus_Line; Register : Byte; Data : in out Byte_Array; OK : out Boolean)
     with Global => null;

   procedure Step_Mask_Interrupts (D : in out Bus_Line)
     with Global => null;

   procedure Step_Unmask_Interrupts (D : in out Bus_Line)
     with Global => null;

   procedure Step_Micros (D : in out Bus_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Delay_Us (D : in out Bus_Line; Us : Interfaces.Unsigned_32)
     with Global => null;

end Adaflight.MPU_Slave_Steps;
