--  The AK9916 compass, the magnetometer of an ICM-20948 that a GPS module's
--  own controller may bridge to its I2C port. Detection needs an I2C bus,
--  gives an unset address the chip's 0x0C and reads the device identity 0x09
--  from the second identity register, since the first holds the company
--  identity the AK8975 and AK8963 drivers accept. Initialization resets the
--  chip, waits 1 ms and sets continuous 100 Hz measurement, checked by reading
--  the mode back, and gives the 100 Hz output data rate. A read takes the
--  status, the six data bytes and the second status in one blocking read.
--  Without data ready it counts, and after 25 such reads sets the mode again.
--  A sensor overflow drops the data, and otherwise the axes are 1.5 times the
--  signed words, clamped to 16 bits.
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
package Adaflight.AK9916 with SPARK_Mode is

   type Axes is array (0 .. 2) of Interfaces.Integer_16;

   No_Data_Retries : constant := 25;

   --  The reads without data ready since the last data or mode setting, and
   --  the output data rate.
   type State is record
      No_Data : Natural range 0 .. No_Data_Retries - 1 := 0;
      ODR_Hz  : Natural range 0 .. 100 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean);

end Adaflight.AK9916;
