--  The ICM-56686 gyro over the SPI gyro layer. Detection resets the chip and
--  polls the reset bit 10 us apart for up to 20 ms, wakes it and reads its
--  identity up to 21 times, 1 ms apart. Initialization sets a 24 MHz clock,
--  runs the layer's, and through the indirect registers selects 16-bit
--  little-endian data, turns on the gyro's sample rate converter and
--  prefilter, sets its low pass filter from the filter setting, bypasses its
--  notch, and turns on the accelerometer's converter and prefilter with its
--  low pass filter at an eighth of its rate, whatever each access answers;
--  it then sets the accelerometer to 16 g at 1600 Hz and the gyro to 2000
--  degrees per second at 6400 Hz, the pulsed, push-pull, active high
--  interrupt, turns the sensors on in low noise mode and waits 35 ms, takes
--  the temperature scale of 1/128 degree per count with its zero at 25
--  degrees, the short period of 156 us, names the data registers and enables
--  the data ready interrupt. An indirect access writes the address, and the
--  data for a write, then waits 4 us and polls the done bit 10 us apart for
--  up to 5 ms; a read then takes the data and waits again; a modification
--  reads first and writes the masked bits, or the masked value alone when
--  the read fails; a write while armed fails. The reads take the six
--  little-endian bytes of the gyro or the accelerometer with a blocking
--  transfer, and the DMA mode is never entered.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Write_Buffer (D : in out SPI_Device; Register : Byte; Data : Byte_Array);
   with procedure Read_Masked (D : in out SPI_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
   with function Micros_To_Cycles (Micros : Interfaces.Unsigned_32) return Interfaces.Unsigned_32;
package Adaflight.MPU_Gyro.ICM56686 with SPARK_Mode is

   Sensor_ICM56686 : constant Byte := 27;

   Acc_One_G          : constant := 2048;
   Acc_Sample_Rate_Hz : constant := 1600;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   procedure Gyro_Detect (S : State; Found : out Boolean)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor = Sensor_ICM56686);

   --  The filter setting is the gyro configuration's; the scale is the
   --  gyro's.
   procedure Gyro_Init
     (D      : in out SPI_Device;
      S      : in out State;
      Filter : Byte;
      Armed  : Boolean;
      Scale  : out Float);

   procedure Acc_Init (S : in out State)
     with Global => null;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean);

end Adaflight.MPU_Gyro.ICM56686;
