--  The LSM6DSO gyro over the SPI gyro layer. Detection reads the identity,
--  0x6C, once. Initialization sets the reset bit of the third control
--  register and waits 100 ms, enables the gyro data ready on both interrupt
--  pins, sets the accelerometer to 833 Hz at 16 g from its first filter and
--  the gyro to 6664 Hz at 2000 degrees per second, the block update and the
--  address increment, the I2C disable and the gyro's first filter, the
--  high performance accelerometer with the 335 Hz gyro filter, and the I3C
--  disable, each masked write reading the register first and skipped when
--  the read fails, waits 1 ms after each write, arms the data ready
--  interrupt when the board has the pin, and sets a 10 MHz clock; it leaves
--  the layer's data registers unnamed. The interrupt only marks data ready.
--  The reads take the six little-endian bytes of the gyro or the
--  accelerometer with a blocking transfer and fail when the transfer does.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
package Adaflight.MPU_Gyro.LSM6DSO with SPARK_Mode is

   Sensor_LSM6DSO : constant Byte := 21;
   Acc_One_G      : constant := 2048;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   --  The gyro's scale: 0.07 degrees per second per count.
   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : out Float)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_LSM6DSO);

   procedure Gyro_Init (D : in out SPI_Device; S : State);

   --  The data ready interrupt.
   procedure Interrupt (S : in out State)
     with Global => null;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean);

end Adaflight.MPU_Gyro.LSM6DSO;
