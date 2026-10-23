--  The AK8963 compass, on I2C, on SPI, or on the MPU slave bus behind an
--  MPU9250 gyro's I2C master. Detection gives an unset I2C or slave address
--  the chip's 0x0C, prepares the bus, resets the chip, waits 4 ms and reads
--  the identity 0x48. SPI preparation sets the select pin and a 10 MHz clock.
--  Slave preparation turns the gyro's DMA off and sets the gyro's interrupt
--  pin to bypass, its I2C master to 400 kHz and its user control to master
--  mode. A chip that does not answer gets its bus released. Initialization
--  registers the device, powers down, reads the fuse ROM's sensitivity values,
--  powers down again, reads both status registers and starts a 16-bit single
--  measurement, whatever the writes and reads answer, and gives the 50 Hz
--  output data rate. A direct read polls the first status for data ready and
--  reads the six data bytes and the second status. A slave read queues the
--  status read through the gyro, completes it 8 ms later, queues the data read
--  when data is ready and completes it 8 ms later. A read that brings data
--  starts the next measurement, drops the data on an overflow and otherwise
--  scales each axis by its sensitivity and clamps it to 16 bits.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The compass's bus: its type, the I2C or slave address, the select pin and
--  clock of SPI, the device's registration, register reads and writes, the
--  gyro's DMA, register writes and reads through the gyro, interrupt masking
--  around a read, the microsecond clock and the delays.
generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function Is_SPI (D : Bus_Device) return Boolean;
   with function Is_MPU_Slave (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Prepare_SPI (D : in out Bus_Device; Max_Clock_Hz : Interfaces.Unsigned_32);
   with procedure Release_SPI (D : in out Bus_Device);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Master_DMA_Off (D : in out Bus_Device);
   with procedure Master_Write (D : in out Bus_Device; Register : Byte; Value : Byte);
   with procedure Master_Read (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Mask_Interrupts (D : in out Bus_Device);
   with procedure Unmask_Interrupts (D : in out Bus_Device);
   with procedure Micros (D : in out Bus_Device; Now : out Interfaces.Unsigned_32);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
   with procedure Delay_Us (D : in out Bus_Device; Us : Interfaces.Unsigned_32);
package Adaflight.AK8963 with SPARK_Mode is

   type Slave_Phase is (Check_Status, Waiting_For_Status, Waiting_For_Data);
   type Axes is array (0 .. 2) of Interfaces.Integer_16;
   subtype Queued_Length is Natural range 0 .. 7;
   subtype Gain is Integer range 128 .. 383;
   type Gains is array (0 .. 2) of Gain;

   --  The slave read's phase, whether a queued read waits, its length and
   --  start time, the sensitivity gains and the output data rate.
   type State is record
      Phase       : Slave_Phase := Check_Status;
      Waiting     : Boolean := False;
      Length      : Queued_Length := 0;
      Started_At  : Interfaces.Unsigned_32 := 0;
      Sensitivity : Gains := (others => 128);
      ODR_Hz      : Natural range 0 .. 50 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean);

end Adaflight.AK8963;
