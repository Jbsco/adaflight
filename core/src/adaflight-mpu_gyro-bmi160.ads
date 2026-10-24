--  The BMI160 gyro over the SPI gyro layer. Detection sends one 0xFF byte
--  to select SPI, waits 100 ms and reads the identity, 0xD1. Initialization
--  commands the gyro and the accelerometer into normal power mode, 100 and
--  5 ms apart, and checks the power status; when both are normal it sets the
--  accelerometer to 800 Hz with the second oversampling and the gyro to
--  3200 Hz with the oversampling of the filter setting, the ranges 8 g and
--  2000 degrees per second, 1 ms after each, sets the two offset enable
--  bits over the offset register, and enables the data ready interrupt on
--  the first interrupt pin, pushed, 1 ms after each; it then enables the
--  interrupt when the board has the pin and sets a 10 MHz clock, whether
--  the power status passed. The reference answers a second detection or
--  initialization from flags; here each call does its bus work. The
--  interrupt and the DMA read are the layer's: the first gyro read after
--  1000 interrupts takes the DMA mode when the bus has it, in which each
--  interrupt reads the twelve bytes of both sensors and the reads decode the
--  gyro at byte 2 and the accelerometer at byte 8; the other modes read a
--  sensor's six little-endian bytes with a blocking transfer; the reads
--  answer true in every mode.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Write_Byte (D : in out SPI_Device; Value : Byte);
package Adaflight.MPU_Gyro.BMI160 with SPARK_Mode is

   Sensor_BMI160 : constant Byte := 18;

   Acc_One_G : constant := 4096;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   --  The scale of 2000 degrees per second over the 16-bit count, left as
   --  it was when the chip is another.
   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : in out Float)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_BMI160);

   --  The filter setting is the gyro configuration's.
   procedure Gyro_Init (D : in out SPI_Device; S : State; Filter : Byte);

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean);

end Adaflight.MPU_Gyro.BMI160;
