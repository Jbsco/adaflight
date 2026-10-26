--  Compass detection over the bus. A configured DroneCAN compass is found only
--  through the DroneCAN stack. Otherwise the interrupt pin comes first, then
--  the bus: the I2C instance and address, the SPI instance and select pin, or
--  the MPU slave bus behind an MPU9250 gyro. A bus type the build lacks, an
--  instance that refuses, or an MPU slave bus without an MPU9250 ends the
--  detection. The scan starts at the configured hardware's driver, or at the
--  first for the default, sets the configured address again before each
--  driver while the bus is I2C, moves the AK8963 onto the MPU slave bus
--  behind an MPU9250, and puts the bus back when that probe fails. The MPU925x
--  passthrough is tried only when configured.
--  The simulator's virtual compass is found unless the configuration is none.
generic
   type Bus_Device is limited private;
   with function Bus_Type (D : Bus_Device) return Byte;
   with procedure Set_Interrupt_Pin (D : in out Bus_Device; Tag : Byte);
   with procedure Set_I2C_Instance (D : in out Bus_Device; Device : Byte; OK : out Boolean);
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Set_SPI_Instance (D : in out Bus_Device; Device : Byte; OK : out Boolean);
   with procedure Set_CS_Pin (D : in out Bus_Device; Tag : Byte);
   with procedure Set_MPU_Slave (D : in out Bus_Device; Address : Byte);
   with procedure Set_Bus_Type (D : in out Bus_Device; Bus : Byte);
   with procedure Detect_DroneCAN (D : in out Bus_Device; Found : out Boolean);
   with procedure Detect_Chip (D : in out Bus_Device; Chip : Driver; Found : out Boolean);
package Adaflight.Compass_Detect.Scan with SPARK_Mode is

   procedure Detect
     (D               : in out Bus_Device;
      B               : Build;
      C               : Config;
      Gyro_Is_MPU9250 : Boolean;
      Detected        : in out Byte;
      Alignment       : out Byte;
      Found           : out Boolean)
     with Post => (if Found then Detected /= Hardware_None and then Detected <= Hardware_Last
                   else Detected = Detected'Old)
                  and then (if C.Hardware = Hardware_None then not Found);

end Adaflight.Compass_Detect.Scan;
