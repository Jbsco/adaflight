--  The common layer of the SPI gyros. Detection waits 35 ms, needs a bus
--  type, a select pin and a bus instance, waits until 100 ms after start,
--  sets a 1 MHz clock and asks the build's chips in turn; a chip that answers
--  registers the device, otherwise the select pin goes back to an input.
--  Initialization names the accelerometer, temperature and gyro data
--  registers of the MPU family and arms the data ready interrupt when the
--  board has the pin. Each interrupt notes its time, the sync time after a
--  short interval, starts the DMA read in DMA mode and counts. The first gyro
--  read picks the mode: DMA when more than 1000 interrupts came and the bus
--  has DMA, interrupt driven without DMA, or no interrupt. Reads then take
--  the six gyro or accelerometer bytes with a blocking transfer, or the bytes
--  the last DMA read brought, with the temperature in DMA mode.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The gyro's SPI device: the select pin before, during and after detection,
--  the bus instance, the clock divisor, the build's chip probes in order,
--  the device's registration, the millisecond clock, a delay, the data ready
--  interrupt, the cycle counter, transfers started with or without a
--  completion call and the wait for them, the receive buffer they fill,
--  whether the bus has DMA, and register reads within a call.
generic
   type SPI_Device is limited private;
   Chip_Count : Natural;
   with procedure Preinit_CS (D : in out SPI_Device; Tag : Byte);
   with procedure Attach_Bus (D : in out SPI_Device; Instance : Byte; OK : out Boolean);
   with procedure Prepare_CS (D : in out SPI_Device; Index : Byte);
   with procedure Release_CS (D : in out SPI_Device);
   with procedure Divider (D : in out SPI_Device; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16);
   with procedure Set_Divisor (D : in out SPI_Device; Divisor : Interfaces.Unsigned_16);
   with procedure Probe_Chip (D : in out SPI_Device; Index : Positive; Sensor : out Byte);
   with procedure Register_Device (D : in out SPI_Device);
   with procedure Millis (D : in out SPI_Device; Now : out Interfaces.Unsigned_32);
   with procedure Delay_Ms (D : in out SPI_Device; Ms : Natural);
   with procedure Enable_Interrupt (D : in out SPI_Device);
   with procedure Cycle_Count (D : in out SPI_Device; Now : out Interfaces.Unsigned_32);
   with procedure Start_Sequence (D : in out SPI_Device; Data : Byte_Array; Completion : Boolean);
   with procedure Wait (D : in out SPI_Device);
   with procedure Fetch (D : in out SPI_Device; Data : out Byte_Array);
   with function Uses_DMA (D : SPI_Device) return Boolean;
   with procedure Read_Registers (D : in out SPI_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
package Adaflight.MPU_Gyro with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   Bus_None      : constant Byte := 0;
   No_Sensor     : constant Byte := 0;
   Detect_Count  : constant := 1000;
   Rate_8_kHz    : constant Byte := 5;

   subtype Buffer_Bytes is Byte_Array (0 .. 15);
   type Axis_Values is array (0 .. 2) of Interfaces.Integer_16;

   type Read_Mode is (EXTI_Init, EXTI_Int_DMA, EXTI_Int, EXTI_No_Int);

   subtype Temperature_Scale is Float range 0.0 .. 0.25;
   subtype Temperature_Offset is Float range -100.0 .. 100.0;

   --  The gyro device configuration: its index, bus type, bus instance and
   --  select pin tag (0 for none).
   type Device_Config is record
      Index    : Interfaces.Integer_8 := 0;
      Bus_Type : Byte := 2;
      SPI_Bus  : Byte := 0;
      CS_Tag   : Byte := 0;
   end record;

   --  The detected sensor, the read mode, the interrupt count and times in
   --  cycles, the short interval and the longest DMA read, the data ready
   --  flag, the raw readings and temperature with its scale and zero, the
   --  data registers, the DMA read length, the transmit buffer, whether the
   --  board has the interrupt pin, and the hardware filter settings.
   type State is record
      Sensor           : Byte := No_Sensor;
      Mode             : Read_Mode := EXTI_Init;
      Detected_EXTI    : Interfaces.Unsigned_32 := 0;
      Last_EXTI        : Interfaces.Unsigned_32 := 0;
      Sync_EXTI        : Interfaces.Unsigned_32 := 0;
      Short_Period     : Interfaces.Integer_32 := 0;
      DMA_Max_Duration : Interfaces.Integer_32 := 0;
      Data_Ready       : Boolean := False;
      Raw              : Axis_Values := (others => 0);
      Acc_Raw          : Axis_Values := (others => 0);
      Temperature      : Interfaces.Integer_16 := 0;
      Temp_Scale       : Temperature_Scale := 0.0;
      Temp_Zero        : Temperature_Offset := 0.0;
      Acc_Data_Reg     : Byte := 0;
      Gyro_Data_Reg    : Byte := 0;
      Temp_Data_Reg    : Byte := 0;
      DMA_Read_Start   : Byte := 0;
      DMA_Length       : Natural range 0 .. 16 := 0;
      Tx               : Buffer_Bytes := (others => 0);
      Interrupt_Pin    : Boolean := False;
      Hardware_LPF     : Byte := 0;
      Rate_KHz         : Byte := 0;
   end record;

   procedure Preinit (D : in out SPI_Device; C : Device_Config);

   procedure Detect (D : in out SPI_Device; S : in out State; C : Device_Config; Found : out Boolean);

   procedure Init (D : in out SPI_Device; S : in out State);

   --  The data ready interrupt.
   procedure Interrupt (D : in out SPI_Device; S : in out State);

   --  The completion of a DMA read.
   procedure Transfer_Complete (D : in out SPI_Device; S : in out State);

   procedure Read_Gyro_SPI (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc_SPI (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean);

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean);

   --  The hardware filter setting: 0 for every setting of this build.
   function Gyro_DLPF (S : State) return Byte;

end Adaflight.MPU_Gyro;
