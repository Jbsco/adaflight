--  The BMM350 compass over I2C. Detection waits 3 ms and reads the chip
--  identity 0x33 at the configured address, or at 0x14 then 0x15 when none
--  is set. Initialization registers the device, soft resets the chip up to
--  three times until it answers its identity 24 ms later, reads the 32 trim
--  words of the one-time memory, each after its read command completes
--  within ten polls 300 us apart, and parses them into the offsets,
--  sensitivities, temperature coefficients and cross-axis terms, all zero
--  when the read fails. It powers the memory off, resets the magnet through
--  the bit and flux guide commands with the chip suspended first, then
--  enables the data ready interrupt, four-sample averaging at 100 Hz, the
--  offset update, the three axes and the normal power mode, each mode
--  change waited for in the status register. A read takes the twelve data
--  bytes behind the two dummy bytes, assembles the three axes and the
--  temperature as 24-bit values, compensates them with the trim and hands
--  over the axes in tenths of a microtesla rounded half to even and held
--  within 16 bits; an axis whose compensation divides by zero reads as the
--  limit of its sign, or as zero when undefined, as the target's conversion
--  of the reference's result does (finding F283).
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
   with procedure Delay_Us (D : in out Bus_Device; Us : Natural);
package Adaflight.BMM350 with SPARK_Mode is

   type Axes is array (0 .. 2) of Interfaces.Integer_16;

   OTP_Words : constant := 32;

   type Trim_Words is array (0 .. OTP_Words - 1) of Interfaces.Unsigned_16;

   subtype Offset_Trim is Float range -2048.0 .. 2048.0;
   subtype Temperature_Trim is Float range -26.0 .. 26.0;
   subtype Sensitivity_Trim is Float range -0.52 .. 0.52;
   subtype Temperature_Sensitivity is Float range -0.26 .. 0.26;
   subtype Offset_Coefficient is Float range -4.0 .. 4.0;
   subtype Scale_Coefficient is Float range -0.0081 .. 0.0081;
   subtype Reference_Temperature is Float range -42.0 .. 88.0;
   subtype Cross_Trim is Float range -0.16 .. 0.16;

   --  The chip's trim: the axis and temperature offsets and sensitivities,
   --  the temperature coefficients of the offsets and scales, the reference
   --  temperature and the cross-axis terms.
   type Compensation is record
      Offset_X    : Offset_Trim := 0.0;
      Offset_Y    : Offset_Trim := 0.0;
      Offset_Z    : Offset_Trim := 0.0;
      Offset_Temp : Temperature_Trim := 0.0;
      Sensit_X    : Sensitivity_Trim := 0.0;
      Sensit_Y    : Sensitivity_Trim := 0.0;
      Sensit_Z    : Sensitivity_Trim := 0.0;
      Sensit_Temp : Temperature_Sensitivity := 0.0;
      TCO_X       : Offset_Coefficient := 0.0;
      TCO_Y       : Offset_Coefficient := 0.0;
      TCO_Z       : Offset_Coefficient := 0.0;
      TCS_X       : Scale_Coefficient := 0.0;
      TCS_Y       : Scale_Coefficient := 0.0;
      TCS_Z       : Scale_Coefficient := 0.0;
      T0          : Reference_Temperature := 0.0;
      Cross_XY    : Cross_Trim := 0.0;
      Cross_YX    : Cross_Trim := 0.0;
      Cross_ZX    : Cross_Trim := 0.0;
      Cross_ZY    : Cross_Trim := 0.0;
   end record;

   --  The trim and the output data rate.
   type State is record
      Trim   : Compensation;
      ODR_Hz : Natural range 0 .. 100 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : State; Data : in out Axes; Got : out Boolean);

end Adaflight.BMM350;
