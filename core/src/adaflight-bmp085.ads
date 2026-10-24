--  The BMP085 barometer on I2C with its clear and conversion-end pins.
--  Detection sets the clear pin up as an output driven high, sets the
--  conversion-end pin up with a rising-edge interrupt, waits 20 ms, gives an
--  unset I2C address the chip's 0x77, and reads the identity 0x55. A chip that
--  does not answer, or answers another identity, gets its conversion-end pin
--  and interrupt released, its clear pin driven low and the default address
--  taken back. Otherwise detection registers the device, reads the version
--  byte and the 22 calibration bytes, whatever they answer, gives the task its
--  6 ms and 27 ms delays, and tests the conversion-end pin, which is connected
--  when it reads low, then high 12 ms after a temperature start. A second
--  detection answers found at once. Temperature and pressure measurements
--  start with a write that clears the conversion flag, read while the bus is
--  free and, with the pin connected, the conversion flag set, and take the
--  bytes the last read brought while the bus is free, the pressure's 19 bits
--  from three bytes shifted right by 5. The calculation compensates with the
--  datasheet's integer arithmetic in 32 bits that wrap, with arithmetic
--  right shifts, and a division by zero, which the ARM processor answers
--  with zero, gives zero.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus and pins: the bus type and address, register reads, started
--  writes and reads with the busy check and the fetched bytes, the device's
--  registration, the delays, each pin by its tag with its owner, level,
--  configuration and release, and the interrupt's setup, enable and release.
generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Start_Write (D : in out Bus_Device; Register : Byte; Value : Byte; Started : out Boolean);
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
   with procedure Delay_Us (D : in out Bus_Device; Us : Natural);
   with procedure Init_Pin (D : in out Bus_Device; Tag : Byte; Owner : Byte);
   with procedure Config_Pin (D : in out Bus_Device; Tag : Byte);
   with procedure Pin_High (D : in out Bus_Device; Tag : Byte);
   with procedure Pin_Low (D : in out Bus_Device; Tag : Byte);
   with procedure Read_Pin (D : in out Bus_Device; Tag : Byte; High : out Boolean);
   with procedure Release_Pin (D : in out Bus_Device; Tag : Byte);
   with procedure Interrupt_Init (D : in out Bus_Device);
   with procedure Interrupt_Config (D : in out Bus_Device; Tag : Byte);
   with procedure Interrupt_Enable (D : in out Bus_Device; Tag : Byte);
   with procedure Interrupt_Release (D : in out Bus_Device; Tag : Byte);
package Adaflight.BMP085 with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   XCLR_Owner : constant Byte := 1;
   EOC_Owner  : constant Byte := 2;

   --  The clear and conversion-end pin tags, 0 for none.
   type Config is record
      XCLR_Tag : Byte := 0;
      EOC_Tag  : Byte := 0;
   end record;

   type Calibration is record
      AC1 : Interfaces.Integer_16 := 0;
      AC2 : Interfaces.Integer_16 := 0;
      AC3 : Interfaces.Integer_16 := 0;
      AC4 : Interfaces.Unsigned_16 := 0;
      AC5 : Interfaces.Unsigned_16 := 0;
      AC6 : Interfaces.Unsigned_16 := 0;
      B1  : Interfaces.Integer_16 := 0;
      B2  : Interfaces.Integer_16 := 0;
      MB  : Interfaces.Integer_16 := 0;
      MC  : Interfaces.Integer_16 := 0;
      MD  : Interfaces.Integer_16 := 0;
   end record;

   subtype Data_Bytes is Byte_Array (0 .. 2);
   subtype Raw_Pressure is Interfaces.Unsigned_32 range 0 .. 2 ** 19 - 1;

   --  Whether detection is done, the chip identity and version the reads
   --  gave, the calibration, whether the conversion-end pin is connected and
   --  whether a conversion ended since the last start, the fine temperature,
   --  the bytes of the last read and the raw temperature and pressure.
   type State is record
      Init_Done           : Boolean := False;
      Chip_Id             : Byte := 0;
      Version             : Byte := 0;
      Cal                 : Calibration;
      EOC_Connected       : Boolean := False;
      Conversion_Complete : Boolean := False;
      B5                  : Interfaces.Integer_32 := 0;
      Sensor_Data         : Data_Bytes := (others => 0);
      UT                  : Interfaces.Unsigned_16 := 0;
      UP                  : Raw_Pressure := 0;
   end record;

   procedure Detect
     (D      : in out Bus_Device;
      C      : Config;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device);

   --  The conversion-end interrupt.
   procedure Conversion_Ended (S : in out State)
     with Global => null;

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean);

   procedure Calculate
     (S : in out State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32)
     with Global => null;

end Adaflight.BMP085;
