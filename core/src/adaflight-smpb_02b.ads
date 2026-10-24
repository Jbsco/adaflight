--  The 2SMPB-02B barometer. Detection prepares the select pin and a 10 MHz
--  clock of an SPI chip, sets the I2C address to 0x70 when none was given,
--  and reads the chip identity, 0x5C, up to five times 50 ms apart. A chip
--  that never gives it gets its select pin returned to the preinit state and
--  the default address taken back. Otherwise detection reads the nine
--  coefficient registers, whatever the reads answer, scales them in single
--  precision, writes the IIR filter of 8 samples, whatever the write answers, and
--  gives the barometer task a 35 ms pressure delay; the chip measures the
--  temperature with the pressure. A pressure start sets the forced measurement
--  with 4 temperature and 32 pressure averages, a pressure read starts the six
--  data bytes while the bus is free, a pressure sample takes the bytes the
--  last read brought while the bus is free and compensates them, and the
--  temperature calls do nothing. The compensation solves the datasheet's
--  quadratics in single precision: the temperature from the root of its
--  discriminant over twice its quadratic coefficient, the raw pressure
--  likewise, and the pressure as the raw pressure over the temperature
--  polynomial. A negative discriminant or a zero quadratic coefficient gives
--  the reference a NaN or an infinity, which this unit keeps as a kind beside
--  the value, and the calculation gives the pressure in pascal and the
--  temperature in hundredths of a degree as the ARM processor converts them,
--  0 for a NaN and the saturated value past 32 bits.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's bus, as the QMP6988 driver takes it, with a byte read for the
--  identity and the select pin's preinit in place of its return.
generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Preinit_CS (D : in out Bus_Device);
   with procedure Read_Byte (D : in out Bus_Device; Register : Byte; Value : out Byte);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Check_Busy (D : in out Bus_Device; Busy : out Boolean; Error : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.SMPB_02B with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Data_Bytes is Byte_Array (0 .. 5);

   --  A 24-bit raw count past the midpoint, and the two 24-bit coefficients.
   subtype Raw_Delta is Interfaces.Integer_32 range -2 ** 23 .. 2 ** 23 - 1;

   --  Bounds of the scaled coefficients over every register value, widened
   --  past the single precision rounding.
   subtype Aa_Value is Float range -4.21E-04 .. 4.21E-04;
   subtype Ba_Value is Float range -168.01 .. -151.99;
   subtype Ap_Value is Float range -3.01E-05 .. 3.01E-05;
   subtype Bp_Value is Float range 19.99 .. 40.01;
   subtype A_T_Value is Float range -8.01E-11 .. 8.01E-11;
   subtype B_T_Value is Float range -8.21E-06 .. -4.99E-06;
   subtype C_T_Value is Float range 0.031 .. 0.049;

   --  The quadratic coefficients are zero or at least the scale of one
   --  register count.
   type Coefficients is record
      Aa : Aa_Value := 0.0;
      Ba : Ba_Value := -160.0;
      Ca : Raw_Delta := 0;
      Ap : Ap_Value := 0.0;
      Bp : Bp_Value := 30.0;
      Cp : Raw_Delta := 0;
      A_T : A_T_Value := 0.0;
      B_T : B_T_Value := -6.6E-06;
      C_T : C_T_Value := 4.0E-02;
   end record
     with Dynamic_Predicate =>
       (Coefficients.Aa = 0.0 or else abs Coefficients.Aa >= 1.28E-08)
       and then (Coefficients.Ap = 0.0 or else abs Coefficients.Ap >= 9.15E-10);

   --  A single precision result with the kinds the reference's arithmetic
   --  gives: finite, an infinity of either sign, or not a number.
   type Value_Kind is (Finite, Plus_Infinity, Minus_Infinity, Not_A_Number);

   type Real is record
      Kind  : Value_Kind := Finite;
      Value : Float := 0.0;
   end record;

   --  The chip identity the last identity read left, the coefficients, the
   --  data bytes of the last sample, and the compensated pressure in pascal
   --  and temperature in degrees.
   type State is record
      Chip_Id     : Byte := 0;
      Calibration : Coefficients;
      Sensor_Data : Data_Bytes := (others => 0);
      Pressure    : Real;
      Temperature : Real;
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

   --  The pressure and the temperature times 100 as the ARM processor
   --  converts a single to a signed 32-bit integer: toward zero, saturated,
   --  and 0 for a NaN.
   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32)
     with Global => null;

end Adaflight.SMPB_02B;
