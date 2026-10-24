--  The Bosch BMP580 and BMP581 barometers on I2C or SPI. Detection waits
--  20 ms, sets up the data ready pin and its rising edge interrupt when one
--  is configured, prepares the select pin and a 10 MHz clock of an SPI chip,
--  sets the I2C address to 0x47 when none was given, and reads the chip
--  identity, 0x50 or 0x51, trying 0x46 when the default address gave another.
--  A chip that gives neither gets its select pin returned to the preinit
--  state and the default address taken back. Otherwise detection registers
--  the device, resets the chip and waits 5 ms, sets the pulsed, active high
--  interrupt on data ready when the pin is configured, the compensation with
--  the IIR output in the shadow registers, an IIR coefficient of 15 on both
--  values, 128 pressure and 4 temperature oversamples, and the normal mode at
--  50 Hz, whatever the writes answer, gives the barometer task a combined
--  read with a 15 ms pressure delay, and waits while the bus is busy. A chip
--  on SPI sends a dummy byte before its registers, which the reads skip. The
--  pressure read brings the six data bytes, kept on a failed read, and the
--  pressure sample takes the temperature from the first three and the
--  pressure from the last three; the other calls do nothing. The calculation
--  gives the temperature as the signed 24-bit count times 100 over 65536, in
--  hundredths of a degree, and the pressure as the count over 64, in pascal.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus, as the BMP388 driver takes it, without the started
--  transfers.
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
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.BMP5xx with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Frame_Bytes is Byte_Array (0 .. 5);
   subtype Raw_Count is Interfaces.Unsigned_32 range 0 .. 16_777_215;

   --  The chip identity the last identity read left, whether the chip sends
   --  a dummy byte, the data bytes of the last pressure read, and the raw
   --  counts of the last sample.
   type State is record
      Chip_Id         : Byte := 0;
      Dummy_Byte      : Boolean := False;
      Frame           : Frame_Bytes := (others => 0);
      Raw_Temperature : Raw_Count := 0;
      Raw_Pressure    : Raw_Count := 0;
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

   --  The pressure in pascal and the temperature in hundredths of a degree.
   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32)
     with Global => null;

end Adaflight.BMP5xx;
