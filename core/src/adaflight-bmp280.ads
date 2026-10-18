--  The BMP280 and BME280 barometers. Detection reads the chip identity,
--  over I2C at address 0x76 and then 0x77 when no address was set, keeps
--  the 24 bytes of calibration and starts a forced measurement at eight
--  times pressure and once temperature oversampling. The device reads
--  pressure and temperature together: a start writes the measurement
--  control again, a read starts the six data bytes while the bus is free,
--  and a sample takes them once the bus is done, unless the bus reported an
--  error. The temperature calls do nothing. The calculation compensates the
--  20-bit readings with the calibration in the datasheet's 32-bit and
--  64-bit integer arithmetic, wrapping as two's complement arithmetic does,
--  and gives the pressure in pascal and the temperature in hundredths of a
--  degree; without a sample it gives a pressure of 0 and leaves the
--  temperature.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus: its registers read or written within a call, a read or
--  a write started for the bus to finish while the driver polls it, the
--  bytes a finished read brought, the I2C address, and the SPI select pin
--  prepared with the bus's clock limit or released. A failed read leaves
--  the bytes it was given.
generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Release_SPI (D : in out Bus_Device);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Start_Write (D : in out Bus_Device; Register : Byte; Value : Byte; Started : out Boolean);
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.BMP280 with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Calibration_Bytes is Byte_Array (0 .. 23);
   subtype Data_Bytes is Byte_Array (0 .. 5);

   subtype Raw_Reading is Interfaces.Integer_32 range 0 .. 2 ** 20 - 1;

   --  The chip identity, the calibration as the chip stores it, the data
   --  bytes of the last sample, the readings they hold, the fine
   --  temperature the pressure compensation uses, and whether a sample is
   --  ready.
   type State is record
      Chip_Id         : Byte := 0;
      Calibration     : Calibration_Bytes := (others => 0);
      Sensor_Data     : Data_Bytes := (others => 0);
      Raw_Pressure    : Raw_Reading := 0;
      Raw_Temperature : Raw_Reading := 0;
      T_Fine          : Interfaces.Integer_32 := 0;
      Sample_Valid    : Boolean := False;
   end record;

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device);

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean);

   procedure Calculate
     (S           : in out State;
      Pressure    : out Interfaces.Integer_32;
      Temperature : in out Interfaces.Integer_32);

end Adaflight.BMP280;
