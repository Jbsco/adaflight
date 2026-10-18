--  The DPS310 and SPL07-003 barometers. Detection prepares the select pin
--  of an SPI chip, sets the I2C address to 0x76 when none was given, and
--  reads the chip identity up to five times, 100 ms apart, until a read is
--  acknowledged with 0x10 for the DPS310 or 0x11 for the SPL07-003. A soft
--  reset, a 40 ms wait and a check that the coefficients and the sensor are
--  ready follow. The coefficients are read in chunks of nine registers, 18
--  registers for the DPS310 and 22 for the SPL07-003, and the pressure,
--  temperature, shift and continuous measurement settings are set by a read
--  and a write where bits are missing. The chip measures continuously: a
--  pressure read starts the six data bytes while the bus is free, and a
--  sample compensates the bytes the last read brought in single precision,
--  without asking the bus. The other calls do nothing. The calculation
--  gives the pressure in pascal and the temperature in hundredths of a
--  degree, each cut toward zero and held to the 32-bit range.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus, as the BMP280 driver takes it, without a started write.
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
package Adaflight.DPS310 with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Coefficient_12 is Interfaces.Integer_32 range -2 ** 11 .. 2 ** 11 - 1;
   subtype Coefficient_16 is Interfaces.Integer_32 range -2 ** 15 .. 2 ** 15 - 1;
   subtype Coefficient_20 is Interfaces.Integer_32 range -2 ** 19 .. 2 ** 19 - 1;

   type Coefficients is record
      C0  : Coefficient_12 := 0;
      C1  : Coefficient_12 := 0;
      C00 : Coefficient_20 := 0;
      C10 : Coefficient_20 := 0;
      C01 : Coefficient_16 := 0;
      C11 : Coefficient_16 := 0;
      C20 : Coefficient_16 := 0;
      C21 : Coefficient_16 := 0;
      C30 : Coefficient_16 := 0;
      C31 : Coefficient_12 := 0;
      C40 : Coefficient_12 := 0;
   end record;

   subtype Data_Bytes is Byte_Array (0 .. 5);

   --  Bounds the compensation cannot leave for any coefficients and
   --  readings.
   subtype Pressure_Value is Float range -1.1E10 .. 1.1E10;
   subtype Temperature_Value is Float range -1.0E6 .. 1.0E6;

   --  The chip identity, the coefficients, the data bytes of the last
   --  sample, and the last compensated pressure in pascal and temperature
   --  in degrees.
   type State is record
      Chip_Id     : Byte := 0;
      Calibration : Coefficients;
      Sensor_Data : Data_Bytes := (others => 0);
      Pressure    : Pressure_Value := 0.0;
      Temperature : Temperature_Value := 0.0;
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

end Adaflight.DPS310;
