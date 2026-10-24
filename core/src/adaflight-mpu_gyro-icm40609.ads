--  The ICM-40609-D gyro over the SPI gyro layer. Detection selects register
--  bank 0, resets the chip, waits 1 ms and reads the identity, 0x3B.
--  Initialization sets a 24 MHz clock, runs the layer's with the chip's data
--  registers and the DMA read from the temperature, takes the temperature
--  scale of 1/132.48 degree per count with its zero at 25 degrees, turns the
--  sensors on in low noise mode with the RC oscillator and waits 200 us then
--  35 ms, selects big-endian data, sets the accelerometer to 16 g at 1 kHz
--  and waits 10 ms, sets the temperature filter to 4 kHz, the third order
--  user interface filters of both sensors and the second order decimator,
--  the low latency filter bandwidths, the anti-alias filters of both sensors
--  from the bandwidth of the filter setting, through the profile table of
--  the chip, the notch at 1.5 kHz with its widest bandwidth and the
--  coefficient of its cosine, the first order high pass filter at its second
--  bandwidth, each in its register bank with bank 0 selected after, the gyro
--  to 2000 degrees per second at 8 kHz, waits 35 ms, and routes the pulsed,
--  push-pull, active high data ready interrupt to the first pin, cleared on
--  the status read, with the 8 us pulse and no deassertion. The reads are
--  the layer's.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
package Adaflight.MPU_Gyro.ICM40609 with SPARK_Mode is

   Sensor_ICM40609 : constant Byte := 28;

   Acc_One_G          : constant := 2048;
   Acc_Sample_Rate_Hz : constant := 1000;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   procedure Gyro_Detect (S : State; Found : out Boolean)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_ICM40609);

   --  The filter setting is the gyro configuration's; the scale is the
   --  gyro's.
   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Filter : Byte; Scale : out Float);

end Adaflight.MPU_Gyro.ICM40609;
