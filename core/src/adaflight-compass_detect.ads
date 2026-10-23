--  Compass detection: the compass drivers in their fixed order, the build's
--  bus support and options, the bus configuration, and the hardware each
--  configured value starts the scan at.
with Interfaces;

package Adaflight.Compass_Detect with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;

   subtype Byte is Interfaces.Unsigned_8;

   type Driver is
     (HMC5883, LIS2MDL, LIS3MDL, AK9916, AK8975, AK8963, QMC5883L, QMC5883P, IST8310, MMC560X, BMM350, MPU925X,
      Virtual);

   subtype Scanned is Driver range HMC5883 .. BMM350;

   --  The bus types the build supports, the MPU slave bus a SPI MPU6500 or
   --  MPU9250 gyro driver brings, DroneCAN, the simulator's virtual compass,
   --  and the board's compass alignment.
   type Build is record
      I2C       : Boolean := True;
      SPI       : Boolean := True;
      MPU_Slave : Boolean := True;
      DroneCAN  : Boolean := False;
      Simulator : Boolean := False;
      Mag_Align : Byte := 0;
   end record;

   Hardware_Default  : constant Byte := 0;
   Hardware_None     : constant Byte := 1;
   Hardware_MPU925X  : constant Byte := 8;
   Hardware_DroneCAN : constant Byte := 12;
   Hardware_Last     : constant Byte := 14;

   Bus_I2C       : constant Byte := 1;
   Bus_SPI       : constant Byte := 2;
   Bus_MPU_Slave : constant Byte := 4;

   type Config is record
      Hardware      : Byte := Hardware_Default;
      Bus_Type      : Byte := Bus_I2C;
      I2C_Device    : Byte := 0;
      I2C_Address   : Byte := 0;
      SPI_Device    : Byte := 0;
      SPI_CS        : Byte := 0;
      Interrupt_Tag : Byte := 0;
   end record;

   --  Whether the configured hardware's case starts the scan at the driver.
   function Starts_At (Chip : Scanned; Hardware : Byte) return Boolean
     with Global => null,
          Post   => (if Starts_At'Result then Hardware > Hardware_None and then Hardware <= Hardware_Last
                     and then Hardware not in Hardware_MPU925X | Hardware_DroneCAN);

   --  The hardware a found driver names.
   function Named (Chip : Scanned) return Byte
     with Global => null,
          Post   => Named'Result > Hardware_None and then Named'Result <= Hardware_Last;

end Adaflight.Compass_Detect;
