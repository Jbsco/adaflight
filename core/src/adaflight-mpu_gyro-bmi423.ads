--  The BMI423 gyro over the SPI gyro layer. The chip starts in I2C mode: the
--  select pin low for 1 ms then high for 2 ms and a discarded identity read
--  select SPI. A register is 16 bits little-endian behind two dummy bytes.
--  Detection selects SPI and reads the identity, 0xAB in the low byte.
--  Initialization writes the soft reset and waits 2 ms, selects SPI again,
--  selects the 16-bit samples, writes the filter configuration, second order
--  filters on both sensors or the gyro's bypassed for the experimental
--  setting, before each sensor's configuration, the accelerometer at 16 g
--  and 800 Hz and the gyro at 2000 degrees per second and 6.4 kHz with the
--  bandwidth of the filter setting, which waits 55 ms, then the push-pull
--  active high interrupt pin in long pulse mode with the gyro data ready on
--  it, the other writes 1 ms apart, enables the interrupt when the board has
--  the pin, and sets a 10 MHz clock. The interrupt handler is the layer's,
--  the chip's own with no short period. The first gyro read after 1000
--  interrupts takes the DMA mode when the bus has it, in which each
--  interrupt starts the 15-byte read of both sensors and the reads decode
--  the accelerometer at byte 3 and the gyro at byte 9; the other modes read
--  a sensor's six little-endian bytes behind the address and the dummy bytes
--  with a blocking transfer, a gyro read in the mode without interrupts
--  repeats the first read once 1000 interrupts have come, and a read in the
--  first mode fails.
generic
   with procedure Read_Masked (D : in out SPI_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Buffer (D : in out SPI_Device; Register : Byte; Data : Byte_Array);
   with procedure Set_CS (D : in out SPI_Device; High : Boolean);
package Adaflight.MPU_Gyro.BMI423 with SPARK_Mode is

   Sensor_BMI423 : constant Byte := 20;

   Acc_One_G : constant := 2048;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   --  The scale of 2000 degrees per second over the 16-bit count, left as
   --  it was when the chip is another.
   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : in out Float)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_BMI423);

   --  The filter setting is the device's.
   procedure Gyro_Init (D : in out SPI_Device; S : State);

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean);

end Adaflight.MPU_Gyro.BMI423;
