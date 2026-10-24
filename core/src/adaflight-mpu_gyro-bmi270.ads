--  The BMI270 gyro over the SPI gyro layer. The chip starts in I2C mode: the
--  select pin low for 1 ms then high for 10 ms selects SPI. A register reads
--  one dummy byte before its value. Detection selects SPI and reads the
--  identity, 0x24. Initialization writes the soft reset and waits 100 ms,
--  selects SPI again and loads the configuration file: advanced power save
--  off, loading open, the 328 bytes to the loading register, 10 ms, loading
--  closed. The experimental filter setting then sets the FIFO for gyro frames
--  without headers or downsampling and a watermark of one frame. The
--  accelerometer goes to 16 g and 800 Hz and the gyro to 2000 degrees per
--  second and 3.2 kHz, both in performance mode, the gyro with the filter
--  setting's oversampling, then the pin carries the data ready interrupt, or
--  the FIFO watermark in the experimental setting, push-pull and active
--  high, power save stays off with the FIFO self-wake, and the gyro,
--  accelerometer and temperature sensor start. The experimental setting
--  then flushes the FIFO and takes the interrupt-driven read mode. Each of
--  these writes waits 1 ms. Initialization then enables the interrupt when
--  the board has the pin and sets a 10 MHz clock. The interrupt handler is
--  the layer's, the chip's own with no short period. In the experimental
--  setting a gyro read takes the FIFO length and the first frame in one
--  10-byte transfer, keeps a whole frame unless all three words are -32768
--  and flushes the FIFO when bytes remain. Otherwise the first gyro read
--  picks the mode: DMA after 1000 interrupts when the bus has it, each
--  interrupt then starting the 14-byte read of both sensors, the gyro at
--  byte 8; interrupt driven without DMA; or no interrupt. The other reads
--  take a sensor's six little-endian bytes at byte 2 of an 8-byte transfer.
--  Reads report success except a FIFO read without a kept frame.
generic
   with procedure Read_Masked (D : in out SPI_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Write_Buffer (D : in out SPI_Device; Register : Byte; Data : Byte_Array);
   with procedure Set_CS (D : in out SPI_Device; High : Boolean);
package Adaflight.MPU_Gyro.BMI270 with SPARK_Mode is

   Sensor_BMI270 : constant Byte := 19;

   Acc_One_G : constant := 2048;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   --  The scale of 2000 degrees per second over the 16-bit count, left as
   --  it was when the chip is another.
   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : in out Float)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_BMI270);

   --  The filter setting is the device's.
   procedure Gyro_Init (D : in out SPI_Device; S : in out State);

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean);

end Adaflight.MPU_Gyro.BMI270;
