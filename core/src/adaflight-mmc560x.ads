--  The MMC560X compass. Detection gives an unset I2C address the chip's 0x30,
--  waits 10 ms for the chip to power up and reads the product identity 0x10.
--  Initialization registers the device, resets it and waits 20 ms, sets it and
--  waits 1 ms, then writes the 2 ms bandwidth, the 100 Hz rate, continuous
--  measurement with automatic set and reset, and high power continuous mode
--  with periodic set, stopping at the first refused write, and gives the 100 Hz
--  output data rate when every write went through. A read takes the nine
--  output bytes in one blocking read and hands over each axis's 18-bit count,
--  centered on zero and shifted right by 2.
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
package Adaflight.MMC560X with SPARK_Mode is

   type Axes is array (0 .. 2) of Interfaces.Integer_16;

   --  The output data rate.
   type State is record
      ODR_Hz : Natural range 0 .. 100 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; Data : in out Axes; Got : out Boolean);

end Adaflight.MMC560X;
