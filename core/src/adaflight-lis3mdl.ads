--  The LIS3MDL compass. Detection gives an unset I2C address the chip's 0x1E
--  and reads the identity 0x3D. Initialization registers the device and writes
--  the 4 gauss range, the temperature sensor with ultra-high-performance X and
--  Y at 80 Hz, the block data update, ultra-high-performance Z and continuous
--  conversion, whatever the writes answer, waits 100 ms and gives the 80 Hz
--  output data rate. A read alternates between starting the six data bytes,
--  with the bus's auto-increment bit in the address, and handing over the axes
--  they brought, each low byte first and divided by 4.
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
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.LIS3MDL with SPARK_Mode is

   type Axes is array (0 .. 2) of Interfaces.Integer_16;

   --  Whether the next read starts the data bytes, and the output data rate.
   type State is record
      Start_Next : Boolean := True;
      ODR_Hz     : Natural range 0 .. 80 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean);

end Adaflight.LIS3MDL;
