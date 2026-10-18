--  The BMP388 and BMP390 barometers. Detection waits 20 ms, enables the
--  interrupt of an end of conversion pin when the board has one, prepares
--  the select pin of an SPI chip, sets the I2C address to 0x76 when none was
--  given, and reads the chip identity, 0x50 or 0x60. A chip on SPI sends a
--  dummy byte before the registers of every read. A found chip gets the data
--  ready interrupt when the pin exists, its 21 bytes of calibration are read,
--  pressure oversampling of eight and temperature oversampling of one are
--  set, a forced measurement starts, and detection waits for the bus. The
--  chip reads both values at once, so only the pressure calls do work: a
--  start begins a forced measurement, a read starts the six data bytes while
--  the bus is free, and a sample takes them once the bus is done. The
--  interrupt reads the interrupt status. The calculation is the datasheet's
--  64-bit integer compensation, wrapping as two's complement arithmetic does,
--  with the pressure in hundredths of a pascal divided by 256 and the
--  temperature in hundredths of a degree.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus: its registers read or written within a call, a read or
--  a write started for the bus to finish while the driver polls it, the
--  bytes a finished read brought, the I2C address, the SPI select pin
--  prepared with the bus's clock limit or released, the end of conversion
--  pin's interrupt, the device's registration and a delay. A failed read
--  leaves the bytes it was given.
generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Release_SPI (D : in out Bus_Device);
   with procedure Enable_EOC_Interrupt (D : in out Bus_Device);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Start_Write (D : in out Bus_Device; Register : Byte; Value : Byte; Started : out Boolean);
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.BMP388 with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Calibration_Bytes is Byte_Array (0 .. 20);
   subtype Frame_Bytes is Byte_Array (0 .. 6);

   subtype Raw_Reading is Interfaces.Unsigned_32 range 0 .. 2 ** 24 - 1;

   --  The chip identity, whether the data frame starts after a dummy byte,
   --  the calibration as the chip stores it, the bytes of the last data read
   --  and the readings they hold.
   type State is record
      Chip_Id         : Byte := 0;
      Dummy_Byte      : Boolean := False;
      Calibration     : Calibration_Bytes := (others => 0);
      Sensor_Data     : Frame_Bytes := (others => 0);
      Raw_Pressure    : Raw_Reading := 0;
      Raw_Temperature : Raw_Reading := 0;
   end record;

   procedure Detect
     (D       : in out Bus_Device;
      S       : in out State;
      EOC_Pin : Boolean;
      Found   : out Boolean;
      Device  : out Barometer_Task.Device);

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean);

   --  The end of conversion pin's interrupt.
   procedure Interrupt (D : in out Bus_Device);

   procedure Calculate
     (S           : State;
      Pressure    : out Interfaces.Integer_32;
      Temperature : out Interfaces.Integer_32)
     with Global => null;

end Adaflight.BMP388;
