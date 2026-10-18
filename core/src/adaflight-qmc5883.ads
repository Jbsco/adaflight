--  The QMC5883L and QMC5883P compasses. Detection of the L resets it, waits
--  20 ms, reads the identity 0xFF and refuses a chip that does not stand by
--  after the reset, while a failed read of its mode passes; the P reads the
--  identity 0x80. A preset I2C address stays and an unset one takes the
--  variant's. Initialization registers the device and writes the variant's
--  configuration, the L's reset and continuous 200 Hz mode at 8 gauss, the
--  P's sign setting and continuous 100 Hz mode at 8 gauss with eightfold
--  oversampling, stopping at the first refused write. A read takes the bytes
--  the last call's read brought, then either starts the status read, starts
--  the six data bytes once the status reports data ready, clears an overrun
--  on the L by reading the unlock register, or hands over the data the last
--  call read. The P rejects all-zero and all-one readings and every eleventh
--  repeat of one reading.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Bus_Device is limited private;
   with function Is_I2C (D : Bus_Device) return Boolean;
   with function I2C_Address (D : Bus_Device) return Byte;
   with procedure Set_I2C_Address (D : in out Bus_Device; Address : Byte);
   with procedure Read_Registers (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Register (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean);
   with procedure Start_Read (D : in out Bus_Device; Register : Byte; Length : Positive; Started : out Boolean);
   with procedure Fetch (D : in out Bus_Device; Data : out Byte_Array);
   with procedure Register_Device (D : in out Bus_Device);
   with procedure Delay_Ms (D : in out Bus_Device; Ms : Natural);
package Adaflight.QMC5883 with SPARK_Mode is

   type Variant is (L, P);
   type Read_Phase is (Wait_Ready, Data_Started);
   type Pending_Read is (None, Status_Read, Data_Read, Unlock_Read);
   type Axes is array (0 .. 2) of Interfaces.Integer_16;
   subtype Data_Bytes is Byte_Array (0 .. 5);

   --  The variant, the data bytes and status the reads brought, the read
   --  phase and the read the bus still has to bring, the P's last reading
   --  and repeat count, and the output data rate.
   type State is record
      Kind        : Variant := L;
      Buffer      : Data_Bytes := (others => 0);
      Status      : Byte := 0;
      Phase       : Read_Phase := Wait_Ready;
      Pending     : Pending_Read := None;
      Last        : Axes := (others => 0);
      Stuck_Count : Natural range 0 .. 10 := 0;
      ODR_Hz      : Natural range 0 .. 200 := 0;
   end record;

   procedure Detect_L (D : in out Bus_Device; S : in out State; Found : out Boolean);

   procedure Detect_P (D : in out Bus_Device; S : in out State; Found : out Boolean);

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean);

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean);

end Adaflight.QMC5883;
