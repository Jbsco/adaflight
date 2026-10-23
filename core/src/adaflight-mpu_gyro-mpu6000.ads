--  The MPU6000 gyro and accelerometer over the SPI gyro layer. Detection
--  resets the chip and its signal paths, 100 ms each, and accepts identity
--  0x68 with a known product revision. Initialization runs the layer's, sets
--  the gyro clock, the interfaces, the sample rate divider, the 2000 degrees
--  per second and 16 g ranges and the data ready interrupt, 15 microseconds
--  apart, then the filter, a 20 MHz clock and one gyro read, failing when the
--  low bytes of its first two axes read 0xFF.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
   with function Micros_To_Cycles (Micros : Interfaces.Unsigned_32) return Interfaces.Unsigned_32;
   with procedure Failure (D : in out SPI_Device);
package Adaflight.MPU_Gyro.MPU6000 with SPARK_Mode is

   Sensor_MPU6000 : constant Byte := 3;
   Gyro_Scale     : constant Float := 2000.0 / 32768.0;
   Acc_One_G      : constant := 2048;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   --  The gyro's scale and the short interrupt interval of the chip.
   procedure Gyro_Detect (S : in out State; Found : out Boolean; Scale : out Float);

   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_MPU6000);

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Divider_Drops : Byte);

end Adaflight.MPU_Gyro.MPU6000;
