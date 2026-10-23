--  The LPS22DF barometer. Detection waits 20 ms, prepares the select pin and
--  a 10 MHz clock of an SPI chip, sets the I2C address to 0x5D when none was
--  given, and reads the chip identity, 0xB4. A chip that does not give it gets
--  its bus released and the default address taken back. Otherwise detection
--  registers the device, sets the software reset and reads the second control
--  register until the reset bit clears, giving up when more than 10 ms have
--  passed, then turns on the low-pass filter and the block data update and
--  sets a continuous 10 Hz rate averaging 512 samples, whatever the writes
--  answer. The chip measures the temperature with the pressure: a pressure
--  read starts the five data bytes while the bus is free, a pressure sample
--  takes the bytes the last read brought while the bus is free, and the other
--  calls do nothing. The calculation gives the pressure in pascal from the
--  24-bit count times 100 over 16 in single precision, cut toward zero and
--  divided by 256, and the temperature as the 16-bit count taken unsigned.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus, as the DPS310 driver takes it, with the millisecond clock.
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
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
   with procedure Millis (D : in out Bus_Device; Now : out Interfaces.Unsigned_32);
package Adaflight.LPS22DF with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Data_Bytes is Byte_Array (0 .. 4);
   subtype Raw_Pressure_Count is Interfaces.Integer_32 range 0 .. 2 ** 24 - 1;
   subtype Raw_Temperature_Count is Interfaces.Integer_32 range 0 .. 2 ** 16 - 1;

   --  The chip identity the last identity read left, the data bytes of the
   --  last sample, and the raw pressure and temperature counts.
   type State is record
      Chip_Id         : Byte := 0;
      Sensor_Data     : Data_Bytes := (others => 0);
      Raw_Pressure    : Raw_Pressure_Count := 0;
      Raw_Temperature : Raw_Temperature_Count := 0;
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

   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32)
     with Global => null;

end Adaflight.LPS22DF;
