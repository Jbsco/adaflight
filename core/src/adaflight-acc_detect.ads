--  Accelerometer detection: the accelerometer hardware of the sensor the
--  gyro's chip detection found. The build's drivers try the sensor in a fixed
--  order from the configured hardware's driver, and the first that accepts it
--  names the hardware. A configured hardware that finds nothing tries again
--  from the first driver, and the configured value none finds nothing.
with Interfaces;

package Adaflight.Acc_Detect with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;

   subtype Byte is Interfaces.Unsigned_8;

   type Driver is
     (MPU6050, MPU6000, MPU9250, MPU6500, MPU6500_SPI, ICM20649, ICM20689, ICM426xx, ICM456xx, ICM56686, BMI160,
      BMI270, BMI423, LSM6DSO, LSM6DSV16X, LSM6DSV32X, ICM40609D, LSM6DSK320X, Virtual);

   type Driver_Set is array (Driver) of Boolean;

   Hardware_Default : constant Byte := 0;
   Hardware_None    : constant Byte := 1;
   Hardware_Last    : constant Byte := 28;

   function Scan (Build : Driver_Set; Start : Byte; Sensor : Byte) return Byte
     with Global => null,
          Post   => Scan'Result /= Hardware_Default
                    and then Scan'Result <= Hardware_Last
                    and then (if Start = Hardware_None then Scan'Result = Hardware_None);

   procedure Detect
     (Build      : Driver_Set;
      Configured : Byte;
      Sensor     : Byte;
      Detected   : in out Byte;
      Found      : out Boolean)
     with Global => null,
          Post   => (if Found then Detected > Hardware_None and then Detected <= Hardware_Last
                     else Detected = Detected'Old)
                    and then (if Configured = Hardware_None then not Found);

end Adaflight.Acc_Detect;
