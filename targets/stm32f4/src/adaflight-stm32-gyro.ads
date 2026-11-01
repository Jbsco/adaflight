--  The board's gyro on SPI1: the SPI gyro layer over the bus driver with the
--  MPU6000 and MPU6500 family drivers the board family builds, the data ready
--  line's interrupt, the start at boot, and the readings the main takes.
with Interfaces;
with Adaflight.Scheduler;
with Adaflight.Acc_Detect;
package Adaflight.STM32.Gyro is
   subtype Byte is Interfaces.Unsigned_8;
   type Axis_Values is array (0 .. 2) of Interfaces.Integer_16;
   type Read_Mode is (Interrupt_Init, Interrupt_DMA, Interrupt, No_Interrupt);
   --  The accelerometer's count for one g on both chip families.
   Acc_One_G : constant := 2048;
   --  What the start found: the gyro hardware code and the chip's sensor
   --  code, the scale in degrees per second per count, the sample rates, the
   --  overflow protection of the hardware, whether the initialization read
   --  failed, and the accelerometer hardware.
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
   end record;
   --  The detection and initialization with the hardware filter setting, the
   --  high range option and the configured accelerometer hardware.
   procedure Start (Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : out Report);
   procedure Read_Gyro (Raw : out Axis_Values; OK : out Boolean);
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
end Adaflight.STM32.Gyro;
