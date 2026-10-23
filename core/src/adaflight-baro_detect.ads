--  Barometer detection: the build's barometer drivers in their fixed order,
--  the bus configuration, and the hardware a detected chip names.
with Interfaces;

package Adaflight.Baro_Detect with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;

   subtype Byte is Interfaces.Unsigned_8;

   type Driver is (BMP085, MS5611, LPS, DPS310, BMP388, BMP280, QMP6988, SMPB_02B, LPS22DF, BMP5xx, Virtual);

   type Driver_Set is array (Driver) of Boolean;

   --  The drivers, the SPA06-003 name for the DPS310 driver's SPL07-003, and
   --  the bus types the build supports.
   type Build is record
      Drivers : Driver_Set := (others => False);
      SPA06   : Boolean := False;
      I2C     : Boolean := True;
      SPI     : Boolean := True;
   end record;

   Hardware_Default : constant Byte := 0;
   Hardware_None    : constant Byte := 1;
   Hardware_Last    : constant Byte := 14;

   Bus_I2C : constant Byte := 1;
   Bus_SPI : constant Byte := 2;

   type Bus_Config is record
      Bus_Type    : Byte := Bus_I2C;
      I2C_Device  : Byte := 0;
      I2C_Address : Byte := 0;
      SPI_Device  : Byte := 0;
      SPI_CS      : Byte := 0;
      EOC_Tag     : Byte := 0;
      XCLR_Tag    : Byte := 0;
   end record;

   --  Whether the configured hardware's case starts the scan at the driver.
   function Starts_At (Chip : Driver; Hardware : Byte) return Boolean
     with Global => null,
          Post   => (if Starts_At'Result then Hardware > Hardware_None and then Hardware <= Hardware_Last);

   --  The hardware a detected chip names from its variant, none for an
   --  unknown BMP5xx.
   function Named (Chip : Driver; Variant : Byte; SPA06 : Boolean) return Byte
     with Global => null,
          Post   => Named'Result in Hardware_None .. Hardware_Last;

end Adaflight.Baro_Detect;
