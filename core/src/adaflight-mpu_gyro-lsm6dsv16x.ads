--  The LSM6DSV16X, LSM6DSV32X and LSM6DSK320X gyros over the SPI gyro layer.
--  The LSM6DSV16X probe reads the identity, 0x70, resets the chip and takes
--  the variant bit of control register 8 for the LSM6DSV32X; the LSM6DSK320X
--  probe reads its identity, 0x75. A reset clears the two rate fields with
--  their modes kept, sets the address increment, each write read back, waits
--  500 us, writes the reset bit, waits 10 ms and polls the register once a
--  millisecond for up to 10 more until the reset bit clears with the block
--  update set, then checks the identity again. Initialization sets a 10 MHz
--  clock and configures the chip in up to three attempts, each a reset and
--  the control registers written and read back: block update and increment,
--  high accuracy mode 1, the high accuracy modes of both sensors, the
--  accelerometer at 16 g, or 32 g on the LSM6DSV32X, with its second low
--  pass filter at a quarter of its rate, the gyro at 2000 degrees per second,
--  or 4000, with the first low pass filter bandwidth of the filter setting
--  and a bit the LSM6DSK320X needs, its filter on, the pulsed data ready on
--  the first interrupt pin, then after 500 us the gyro at 8 kHz and the
--  accelerometer at 1 kHz; when every attempt fails the failure call takes
--  over, otherwise the scale is 0.07 degrees per second per count, or 0.14,
--  and the layer's initialization runs. The interrupt and the DMA read are
--  the layer's; a DMA completion latches the twelve bytes of both sensors
--  behind a sequence count before the layer's completion. The reads take a
--  sensor's six little-endian bytes with a blocking transfer, or the latched
--  sample once one is ready, and fail before the first gyro read.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
   with procedure Failure (D : in out SPI_Device);
package Adaflight.MPU_Gyro.LSM6DSV16X with SPARK_Mode is

   Sensor_LSM6DSV16X  : constant Byte := 23;
   Sensor_LSM6DSK320X : constant Byte := 24;
   Sensor_LSM6DSV32X  : constant Byte := 29;

   type Latched_Values is array (0 .. 5) of Interfaces.Integer_16;

   --  The samples of the last DMA read, latched at its completion behind a
   --  sequence count.
   type Sample_Latch is record
      Sequence : Interfaces.Unsigned_32 := 0;
      Samples  : Latched_Values := (others => 0);
      Ready    : Boolean := False;
   end record;

   --  The chip probes of the layer's detection.
   procedure Detect_LSM6DSV16X (D : in out SPI_Device; Sensor : out Byte);

   procedure Detect_LSM6DSK320X (D : in out SPI_Device; Sensor : out Byte);

   procedure Gyro_Detect (S : State; Found : out Boolean)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is
     (S.Sensor in Sensor_LSM6DSV16X | Sensor_LSM6DSK320X | Sensor_LSM6DSV32X);

   --  The filter setting is the gyro configuration's; the scale is left when
   --  the configuration fails.
   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Filter : Byte; Scale : in out Float);

   --  The counts per g: 1024 on the LSM6DSV32X, 2048 on the others.
   function Acc_One_G (S : State) return Positive is
     (if S.Sensor = Sensor_LSM6DSV32X then 1024 else 2048)
     with Global => null;

   procedure Transfer_Complete (D : in out SPI_Device; S : in out State; L : in out Sample_Latch);

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; L : in out Sample_Latch; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; L : Sample_Latch; OK : out Boolean);

end Adaflight.MPU_Gyro.LSM6DSV16X;
