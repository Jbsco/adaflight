--  The board's gyros: the SPI gyro layer over the bus driver with the
--  drivers the board builds, each gyro's data ready line, its detection and
--  start at boot, and the readings the main takes.
with Interfaces;
with Adaflight.Scheduler;
with Adaflight.Acc_Detect;
package Adaflight.STM32.Gyro is
   subtype Byte is Interfaces.Unsigned_8;
   type Axis_Values is array (0 .. 2) of Interfaces.Integer_16;
   type Read_Mode is (Interrupt_Init, Interrupt_DMA, Interrupt, No_Interrupt);
   --  The accelerometer's count for one g on most chips.
   Acc_One_G : constant := 2048;
   --  What a gyro's detection and start found: the gyro hardware code and the chip's sensor
   --  code, the scale in degrees per second per count, the sample rates, the
   --  overflow protection of the hardware, whether the initialization read
   --  failed, and the accelerometer hardware with its count for one g.
   type Report is record
      Found              : Boolean := False;
      Init_Failed        : Boolean := False;
      Hardware           : Byte := 0;
      Sensor             : Byte := 0;
      Scale              : Float := 0.0;
      Sample_Rate_Hz     : Natural := 0;
      Acc_Sample_Rate_Hz : Natural := 0;
      Overflow_Protected : Boolean := False;
      Acc_Found          : Boolean := False;
      Acc_Hardware       : Byte := Acc_Detect.Hardware_None;
      One_G              : Positive := Acc_One_G;
   end record;
   --  The detection of the gyro at a position with the hardware filter
   --  setting and the high range option: a gyro the board does not have, or
   --  has without a bus, is not found.
   procedure Detect (Position : Natural; Hardware_LPF : Byte; High_Range : Boolean; R : out Report);
   --  The start of a detected gyro, with the configured accelerometer
   --  hardware for its accelerometer.
   procedure Init
     (Position : Natural; Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : in out Report);
   --  The gyro whose accelerometer, read mode, interrupt counts and
   --  temperature the operations below give: the first enabled one.
   procedure Set_Active (Position : Natural);
   procedure Read_Gyro (Position : Natural; Raw : out Axis_Values; OK : out Boolean);
   procedure Read_Acc (Raw : out Axis_Values; OK : out Boolean);
   function Mode return Read_Mode;
   --  What the scheduler's gyro lock reads: the interrupt count, the cycle
   --  count of the last sync and whether the chip syncs to a short period.
   function Interrupt_Count return Interfaces.Unsigned_32;
   function Sync_Cycles return Interfaces.Unsigned_32;
   function Short_Period return Boolean;
   --  The telemetry task's sensor poll: the chip temperature of the last
   --  burst read in whole degrees, the least value without a gyro.
   procedure Poll_Temperature (Now_Us : Adaflight.Scheduler.Time_Us);
   function Temperature return Interfaces.Integer_16;
   --  A register of the gyro at a position, for the command line's register
   --  dump: zero for a position without a gyro the start found.
   procedure Dump_Register (Position : Natural; Register : Byte; Value : out Byte);
end Adaflight.STM32.Gyro;
