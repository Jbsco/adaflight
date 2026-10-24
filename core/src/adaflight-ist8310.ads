--  The IST8310 compass. Detection gives an unset I2C address the chip's 0x0E
--  and reads the identity 0x10. Initialization registers the device and writes
--  16-sample averaging, the normal pulse duration and a single measurement,
--  each after the last one went through, with 6 ms after each of the first
--  two, and gives the 100 Hz output data rate. A read takes the bytes the last
--  call's read brought, then polls the status for data ready up to 15 times,
--  starts the six data bytes, and hands over the axes, X and Z scaled by 3 and
--  Y negated and scaled by 3, with the next measurement triggered. After 15
--  polls without data ready, or a trigger the bus refused, the read triggers
--  the next measurement and reports no new axes.
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
package Adaflight.IST8310 with SPARK_Mode is

   type Read_Phase is (Check_Status, Read_Data, Trigger);
   type Pending_Read is (None, Status_Read, Data_Read);
   type Axes is array (0 .. 2) of Interfaces.Integer_16;
   subtype Data_Bytes is Byte_Array (0 .. 5);

   Max_Retries : constant := 15;

   --  The read phase, the status and data bytes the reads brought, the read
   --  the bus still has to bring, the status polls so far, and the output data
   --  rate.
   type State is record
      Phase   : Read_Phase := Check_Status;
      Status  : Byte := 0;
      Buffer  : Data_Bytes := (others => 0);
      Pending : Pending_Read := None;
      Retries : Natural range 0 .. Max_Retries := 0;
      ODR_Hz  : Natural range 0 .. 100 := 0;
   end record;

   procedure Detect (D : in out Bus_Device; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean);

end Adaflight.IST8310;
