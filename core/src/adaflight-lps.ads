--  The ST LPS22, LPS25, LPS33 and LPS35 barometers on SPI. Detection fails
--  on another bus, prepares the select pin and a 10 MHz clock, and reads the
--  identity, 0xB1 or 0xBD. It then powers the chip down with block updates,
--  writes and reads back the second control register, the averages and the
--  data ready pin, failing when one reads back differently, starts the chip
--  at 25 Hz with block updates, the interrupt and the autozero reset, reads
--  the first control register back, gives the barometer task a combined
--  read, a 1 us temperature delay and a 41666 us pressure delay, and reads
--  samples until one is not zero or more than 500 ms pass by the millisecond
--  clock, which fails the detection with the task's values left set. A
--  sample reads the status and, when a pressure or temperature is ready, the
--  three pressure bytes, sign extended, and the two temperature bytes, and
--  zeros otherwise. Only the pressure sample call reads; the other calls do
--  nothing. The calculation gives the pressure as the raw count times 100
--  over 4096 and the temperature as the raw count times 10 over 48 plus
--  4250, in hundredths of a degree.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Barometer_Task;

--  The chip's SPI bus: the select pin and clock setup, a read of registers
--  by command byte, the plain write and the write and read back of the
--  verified setup, and the millisecond clock.
generic
   type Bus_Device is limited private;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Read_Registers (D : in out Bus_Device; Command : Byte; Data : out Byte_Array);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte);
   with procedure Write_Plain (D : in out Bus_Device; Register : Byte; Value : Byte);
   with procedure Read_Byte (D : in out Bus_Device; Register : Byte; Value : out Byte);
   with procedure Millis (D : in out Bus_Device; Now : out Interfaces.Unsigned_32);
package Adaflight.LPS with SPARK_Mode is
   use type Interfaces.Integer_32;

   --  The 24-bit pressure count, sign extended.
   subtype Raw_Pressure is Interfaces.Integer_32 range -2 ** 23 .. 2 ** 23 - 1;

   --  The chip identity the identity read left and the raw counts of the
   --  last sample.
   type State is record
      Chip_Id : Byte := 0;
      Raw_P   : Raw_Pressure := 0;
      Raw_T   : Interfaces.Unsigned_16 := 0;
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

   --  The pressure in pascal and the temperature in hundredths of a degree.
   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32)
     with Global => null;

end Adaflight.LPS;
