--  Barometer detection over the bus. Without the virtual barometer the bus
--  type's instance comes first, then the I2C address or the SPI select pin,
--  and a bus type the build lacks or an instance that refuses ends the
--  detection. The scan starts at the configured hardware's driver, or at the
--  first for the default, and the first built driver that finds its chip
--  names the hardware, which an unknown BMP5xx leaves at none.
generic
   type Bus_Device is limited private;
   with procedure Set_I2C_Instance (D : in out Bus_Device; Device : Byte; OK : out Boolean);
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Set_SPI_Instance (D : in out Bus_Device; Device : Byte; OK : out Boolean);
   with procedure Set_CS_Pin (D : in out Bus_Device; Tag : Byte);
   with procedure Detect_Chip
     (D        : in out Bus_Device;
      Chip     : Driver;
      EOC_Tag  : Byte;
      XCLR_Tag : Byte;
      Found    : out Boolean;
      Variant  : out Byte);
package Adaflight.Baro_Detect.Scan with SPARK_Mode is

   procedure Detect
     (D        : in out Bus_Device;
      B        : Build;
      C        : Bus_Config;
      Hardware : Byte;
      Detected : in out Byte;
      Found    : out Boolean)
     with Post => (if Found then Detected > Hardware_None and then Detected <= Hardware_Last
                   else Detected = Detected'Old)
                  and then (if Hardware = Hardware_None then not Found);

end Adaflight.Baro_Detect.Scan;
