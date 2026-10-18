--  The HMC5883L compass. Detection prepares the device on SPI, registered and
--  clocked at no more than 10 MHz, or gives an unset I2C address the chip's
--  0x1E, then reads the identity 0x48. Initialization writes eight-sample
--  averaging at 75 Hz in normal measurement, the 1.3 gauss gain and continuous
--  conversion whatever the writes answer, waits 100 ms, arms the data ready
--  interrupt when the board has its pin and gives the output data rate. A read
--  alternates between starting the six data bytes and handing over the axes
--  they brought, X, Z and Y, each high byte first.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
   with procedure Enable_Interrupt (D : in out Bus_Device);
package Adaflight.HMC5883 with SPARK_Mode is

   type Axes is array (0 .. 2) of Interfaces.Integer_16;

   --  Whether the next read starts the data bytes, and the output data rate.
   type State is record
      Start_Next : Boolean := True;
      ODR_Hz     : Natural range 0 .. 75 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; Interrupt_Pin : Boolean; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean);

end Adaflight.HMC5883;
