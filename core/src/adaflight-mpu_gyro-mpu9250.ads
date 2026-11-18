--  The MPU9250 and MPU9255 over the SPI gyro layer, with the chip's own
--  start. Detection resets the chip and reads its identity up to 21 times,
--  150 ms apart. Initialization runs the layer's, resets the chip, then
--  writes the clock, the 2000 degrees per second range, the filter, the sample
--  rate divider, the 16 g range, the interrupt pin and the data ready
--  interrupt, reading each back up to 21 times and writing it again while it
--  differs. It then sets a 20 MHz clock and reads the gyro once, failing when
--  the low bytes of its first two axes read 0xFF.
generic
   --  One register written from a one byte buffer, and one read into one.
   with procedure Write_Buffer (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Buffer (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
   with procedure Failure (D : in out SPI_Device);
package Adaflight.MPU_Gyro.MPU9250 with SPARK_Mode is

   Sensor_MPU9250 : constant Byte := 6;
   Gyro_Scale     : constant Float := 2000.0 / 32768.0;
   Acc_One_G      : constant := 2048;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   function Gyro_Detect (S : State) return Boolean is (S.Sensor = Sensor_MPU9250);
   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_MPU9250);

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Divider_Drops : Byte);

end Adaflight.MPU_Gyro.MPU9250;
