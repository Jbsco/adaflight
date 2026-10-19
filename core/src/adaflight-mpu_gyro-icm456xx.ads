--  The ICM-45686 and ICM-45605 gyros over the SPI gyro layer. Detection
--  resets the chip and polls the reset bit 10 us apart for up to 20 ms,
--  wakes it and reads its identity up to 21 times, 1 ms apart.
--  Initialization sets a 24 MHz clock, runs the layer's, turns the sensors on
--  in low noise mode and waits 1 ms, sets the accelerometer to 16 g at 1600
--  Hz and waits 10 ms, enables the gyro's anti-alias filter and interpolator
--  and sets its low pass filter from the filter setting through the indirect
--  registers, falling back to the raw path and the bypass when an update
--  fails, sets the gyro to 2000 degrees per second at 6400 Hz and waits 35
--  ms, takes the short period of 156 us, sets the pulsed, push-pull, active
--  high interrupt on data ready and names the data registers. The
--  accelerometer initialization enables its anti-alias filter and
--  interpolator and sets its low pass filter the same way. An indirect
--  register access waits for the done bit 4 us apart for up to 5 ms, writes
--  the address and reads or writes the data 4 us apart; an update reads,
--  writes when the masked bits differ, reads back and tries three times; a
--  read while armed fails. The reads take the six little-endian bytes of the
--  gyro or the accelerometer with a blocking transfer, and the DMA mode is
--  never entered.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Write_Buffer (D : in out SPI_Device; Register : Byte; Data : Byte_Array);
   with procedure Read_Masked (D : in out SPI_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
   with function Micros_To_Cycles (Micros : Interfaces.Unsigned_32) return Interfaces.Unsigned_32;
package Adaflight.MPU_Gyro.ICM456xx with SPARK_Mode is

   Sensor_ICM45605 : constant Byte := 25;
   Sensor_ICM45686 : constant Byte := 26;

   Acc_One_G          : constant := 2048;
   Acc_Sample_Rate_Hz : constant := 1600;

   function Is_ICM456xx (Sensor : Byte) return Boolean is (Sensor in Sensor_ICM45605 .. Sensor_ICM45686);

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   procedure Gyro_Detect (S : State; Found : out Boolean)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (Is_ICM456xx (S.Sensor));

   --  The filter setting is the gyro configuration's; the scale is the
   --  gyro's.
   procedure Gyro_Init
     (D      : in out SPI_Device;
      S      : in out State;
      Filter : Byte;
      Armed  : Boolean;
      Scale  : out Float);

   procedure Acc_Init (D : in out SPI_Device; S : in out State; Armed : Boolean);

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean);

end Adaflight.MPU_Gyro.ICM456xx;
