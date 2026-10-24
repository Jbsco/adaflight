--  The QMP6988 barometer. Detection waits 20 ms, prepares the select pin and
--  a 10 MHz clock of an SPI chip, sets the I2C address to 0x70 when none was
--  given, and reads the chip identity, 0x5C. A chip that does not give it gets
--  its select pin returned and the default address taken back. Otherwise
--  detection registers the device, sets the IIR filter, reads the 25
--  calibration bytes into a buffer that starts at zeros, and sets the power
--  mode and the sampling, whatever the writes and the read answer. The two
--  20-bit and the ten 16-bit coefficients are signed, each scaled in single
--  precision. The chip measures the temperature with the
--  pressure: a pressure start sets the forced measurement again, a pressure
--  read starts the six data bytes while the bus is free, a pressure sample
--  takes the bytes the last read brought while the bus is free, and the other
--  calls do nothing. The calculation compensates in single precision and
--  keeps the last pressure or temperature when the new one is exactly zero.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus, as the DPS310 driver takes it, with the select pin's return
--  to an input for the preinit owner in place of the preinit call.
generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Return_CS (D : in out Bus_Device);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.QMP6988 with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Data_Bytes is Byte_Array (0 .. 5);
   subtype Raw_Count is Interfaces.Integer_32 range 0 .. 2 ** 24 - 1;

   --  Bounds of each coefficient over every calibration byte, widened past
   --  the single precision rounding.
   subtype Offset_Value is Float range -32_769.0 .. 32_769.0;
   subtype A1_Value is Float range -6.74E-03 .. -5.86E-03;
   subtype A2_Value is Float range -1.40E-10 .. 1.02E-10;
   subtype Bt1_Value is Float range 0.0089 .. 0.192;
   subtype Bt2_Value is Float range -1.19E-06 .. 1.22E-06;
   subtype Bp1_Value is Float range 0.0139 .. 0.053;
   subtype B11_Value is Float range 6.9E-08 .. 3.51E-07;
   subtype Bp2_Value is Float range -9.81E-10 .. -2.79E-10;
   subtype B12_Value is Float range -4.71E-13 .. 1.06E-12;
   subtype B21_Value is Float range -9.91E-15 .. 1.42E-14;
   subtype Bp3_Value is Float range 5.09E-17 .. 2.1E-16;

   type Coefficients is record
      A0  : Offset_Value := 0.0;
      A1  : A1_Value := -6.3E-03;
      A2  : A2_Value := -1.9E-11;
      B00 : Offset_Value := 0.0;
      Bt1 : Bt1_Value := 0.1;
      Bt2 : Bt2_Value := 1.2E-08;
      Bp1 : Bp1_Value := 0.033;
      B11 : B11_Value := 2.1E-07;
      Bp2 : Bp2_Value := -6.3E-10;
      B12 : B12_Value := 2.9E-13;
      B21 : B21_Value := 2.1E-15;
      Bp3 : Bp3_Value := 1.3E-16;
   end record;

   --  The chip identity the last identity read left, the coefficients, the
   --  data bytes of the last sample, and the raw pressure and temperature.
   type State is record
      Chip_Id         : Byte := 0;
      Calibration     : Coefficients;
      Sensor_Data     : Data_Bytes := (others => 0);
      Raw_Pressure    : Raw_Count := 0;
      Raw_Temperature : Raw_Count := 0;
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

   --  The pressure in pascal and the temperature as the compensated value
   --  cut toward zero and divided by 256, each kept when its compensated
   --  value is zero.
   procedure Calculate
     (S : State; Pressure : in out Interfaces.Integer_32; Temperature : in out Interfaces.Integer_32)
     with Global => null;

end Adaflight.QMP6988;
