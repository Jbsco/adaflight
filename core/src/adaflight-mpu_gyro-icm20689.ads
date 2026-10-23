--  The ICM20689 family over the SPI gyro layer: ICM-20601, ICM-20602,
--  ICM-20608-G and ICM-20689. Detection resets the chip, reads the identity
--  and, for a known chip, disables the I2C interface and resets the
--  accelerometer and temperature signal paths. Initialization sets an 8 MHz
--  clock, runs the layer's, selects the clock, waits 120 microseconds and
--  sets the 2000 degrees per second and 16 g ranges, the filter, the sample
--  rate divider and the data ready interrupt.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
package Adaflight.MPU_Gyro.ICM20689 with SPARK_Mode is

   Sensor_ICM20601 : constant Byte := 7;
   Sensor_ICM20602 : constant Byte := 8;
   Sensor_ICM20608 : constant Byte := 9;
   Sensor_ICM20689 : constant Byte := 11;
   Gyro_Scale      : constant Float := 2000.0 / 32768.0;
   Acc_One_G       : constant := 2048;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : out Float)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor in Sensor_ICM20602 | Sensor_ICM20689);

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Divider_Drops : Byte);

end Adaflight.MPU_Gyro.ICM20689;
