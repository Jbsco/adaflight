--  The MS5611 barometer, which takes commands rather than register
--  addresses. Detection waits 10 ms, prepares the select pin of an SPI chip,
--  sets the I2C address to 0x77 when none was given, and reads the first
--  PROM byte, failing when the read fails or the byte is 0xFF. A reset with
--  a 2.8 ms wait follows, then the eight PROM words and their 4-bit check.
--  The temperature and the pressure each take a conversion start, an ADC
--  read started while the bus is free, and a sample of the 24-bit result
--  once the bus is done, at 10 ms per conversion. The calculation is the
--  datasheet's 64-bit integer compensation with its second order below 20
--  and -15 degrees, giving the pressure in pascal and the temperature in
--  hundredths of a degree.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus with commands sent as they are: reads and writes within a
--  call, a read or a write started for the bus to finish while the driver
--  polls it, the bytes a finished read brought, the I2C address, the SPI
--  select pin prepared with the bus's clock limit or released, the device's
--  registration, and delays in milliseconds and microseconds.
generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Release_SPI (D : in out Bus_Device);
   with procedure Raw_Read (D : in out Bus_Device; Command : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Raw_Write (D : in out Bus_Device; Command : Byte; Value : Byte; OK : out Boolean);
   with procedure Raw_Start_Read (D : in out Bus_Device; Command : Byte; Length : Positive; Started : out Boolean);
   with procedure Raw_Start_Write (D : in out Bus_Device; Command : Byte; Value : Byte; Started : out Boolean);
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
   with procedure Delay_Us (D : in out Bus_Device; Us : Natural);
package Adaflight.MS5611 with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Raw_Reading is Interfaces.Unsigned_32 range 0 .. 2 ** 24 - 1;
   type PROM_Words is array (0 .. 7) of Interfaces.Unsigned_16;
   subtype Data_Bytes is Byte_Array (0 .. 2);

   --  The PROM, the data bytes of the last sample, and the last
   --  temperature and pressure readings.
   type State is record
      PROM            : PROM_Words := (others => 0);
      Sensor_Data     : Data_Bytes := (others => 0);
      Raw_Temperature : Raw_Reading := 0;
      Raw_Pressure    : Raw_Reading := 0;
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

end Adaflight.MS5611;
