--  The MPU6500 family over the SPI gyro layer: MPU6500, MPU9250, MPU9255,
--  ICM-20601, ICM-20602 and ICM-20608-G. Detection reads the identity, which
--  also names three ICM426xx chips for their own driver. Initialization runs
--  the layer's, resets the chip and its signal paths, selects the clock and
--  sets the ranges, the filter, the sample rate divider and the data ready
--  interrupt, 15 to 100 ms apart. It then disables the I2C interface and sets
--  a 20 MHz clock. The ICM-20601 takes its own range codes, with 4000 degrees
--  per second under the high range option.
generic
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Bus_Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
package Adaflight.MPU_Gyro.MPU6500 with SPARK_Mode is

   Sensor_MPU6500  : constant Byte := 5;
   Sensor_MPU9250  : constant Byte := 6;
   Sensor_ICM20601 : constant Byte := 7;
   Sensor_ICM20602 : constant Byte := 8;
   Sensor_ICM20608 : constant Byte := 9;
   Acc_One_G       : constant := 2048;

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   --  The gyro's scale, 4000 degrees per second on the high range ICM-20601.
   procedure Gyro_Detect (S : State; High_Range : Boolean; Found : out Boolean; Scale : out Float)
     with Global => null;

   function Acc_Detect (S : State) return Boolean is (S.Sensor in Sensor_MPU6500 .. Sensor_ICM20608);

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; High_Range : Boolean; Divider_Drops : Byte);

end Adaflight.MPU_Gyro.MPU6500;
