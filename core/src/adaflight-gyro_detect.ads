--  Gyro detection: the gyro hardware of the detected sensor. The build's
--  drivers try the sensor in a fixed order and the first that accepts it
--  names the hardware. The L3GD20 driver and the virtual gyro accept any
--  sensor, and a build with the virtual gyro skips the chip detection.
with Interfaces;

package Adaflight.Gyro_Detect with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;

   subtype Byte is Interfaces.Unsigned_8;

   type Driver is
     (MPU6050, L3GD20, MPU6000, MPU6500, MPU6500_SPI, MPU9250, ICM20649, ICM20689, ICM426xx, ICM456xx, ICM56686,
      BMI160, BMI270, BMI423, LSM6DSO, LSM6DSV16X, LSM6DSV32X, LSM6DSK320X, ICM40609D, Virtual);

   type Driver_Set is array (Driver) of Boolean;

   Hardware_None    : constant Byte := 0;
   Hardware_Default : constant Byte := 1;
   Hardware_Last    : constant Byte := 29;

   function Hardware (Build : Driver_Set; Sensor : Byte) return Byte
     with Global => null,
          Post   => Hardware'Result /= Hardware_Default
                    and then Hardware'Result <= Hardware_Last
                    and then (if Build (L3GD20) or else Build (Virtual) then Hardware'Result /= Hardware_None);

   function Needs_Chip (Build : Driver_Set) return Boolean is (not Build (Virtual))
     with Global => null;

   procedure Detect_Sensor
     (Build         : Driver_Set;
      Chip_Found    : Boolean;
      Sensor        : Byte;
      Gyro_Hardware : in out Byte;
      Found         : out Boolean)
     with Global => null,
          Post   => (if Needs_Chip (Build) and then not Chip_Found
                     then not Found and then Gyro_Hardware = Gyro_Hardware'Old
                     else Gyro_Hardware = Hardware (Build, Sensor)
                          and then Found = (Gyro_Hardware /= Hardware_None));

end Adaflight.Gyro_Detect;
