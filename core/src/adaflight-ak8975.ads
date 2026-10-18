--  The AK8975 compass. Detection gives an unset I2C address the chip's 0x0C
--  and reads the identity 0x48. Initialization registers the device, powers
--  down, reads the fuse ROM's sensitivity values, powers down again, reads both
--  status registers and starts a 16-bit single measurement, with the waits the
--  chip needs and whatever the writes and reads answer, and gives the 50 Hz
--  output data rate. A read polls the first status for data ready, starts the
--  six data bytes and the second status, starts the next measurement, drops
--  the data on a data error or overflow, and otherwise hands the axes over at
--  the next read, each scaled by its sensitivity, clamped to 16 bits and
--  negated.
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
   with procedure Start_Write (D : in out Bus_Device; Register : Byte; Value : Byte; Started : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.AK8975 with SPARK_Mode is

   type Read_Phase is (Read_Status_1, Wait_Status_1, Read_Status_2, Wait_Status_2, Wait_Start);
   type Pending_Read is (None, Status_Read, Data_Read);
   type Axes is array (0 .. 2) of Interfaces.Integer_16;
   subtype Data_Bytes is Byte_Array (0 .. 5);
   subtype Gain is Integer range 128 .. 383;
   type Gains is array (0 .. 2) of Gain;

   --  The read phase, the status and data bytes the reads brought, the read
   --  the bus still has to bring, the sensitivity gains and the output data
   --  rate.
   type State is record
      Phase       : Read_Phase := Read_Status_1;
      Status      : Byte := 0;
      Buffer      : Data_Bytes := (others => 0);
      Pending     : Pending_Read := None;
      Sensitivity : Gains := (others => 128);
      ODR_Hz      : Natural range 0 .. 50 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean);

end Adaflight.AK8975;
