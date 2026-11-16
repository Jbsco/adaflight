--  The gyro chip on the board's gyro bus: the SPI gyro layer over the bus
--  driver with the LSM6DSV16X family, ICM20689 family, MPU6000, MPU6500
--  family, BMI270 and ICM426xx drivers, each built where the board's
--  configuration names it and probed in that order, the LSM6DSV16X family
--  with one probe for its LSM6DSV chips and one for the LSM6DSK320X, the
--  data ready line's interrupt, the start at boot,
--  and the readings the main takes. The gyro detection's hardware code says
--  which of the ICM20689 and MPU6500 drivers starts a chip both know. The
--  LSM6DSV16X family and the BMI270 read through their own drivers, and the
--  BMI270's received bytes start one
--  place earlier in the layer's buffer. An ICM-42688-P takes the gyro
--  clock input where the board has one, and the other ICM426xx chips run
--  from their own clock. The operations are the board gyro unit's, which a
--  board image passes on to these.
with Interfaces;
with Adaflight.Scheduler;
with Adaflight.STM32.Gyro; use Adaflight.STM32.Gyro;
package Adaflight.STM32.Gyro_Chip is
   subtype Byte is Interfaces.Unsigned_8;
   procedure Start (Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : out Report);
   procedure Read_Gyro (Raw : out Axis_Values; OK : out Boolean);
   procedure Read_Acc (Raw : out Axis_Values; OK : out Boolean);
   function Mode return Read_Mode;
   function Interrupt_Count return Interfaces.Unsigned_32;
   function Sync_Cycles return Interfaces.Unsigned_32;
   function Short_Period return Boolean;
   procedure Poll_Temperature (Now_Us : Adaflight.Scheduler.Time_Us);
   function Temperature return Interfaces.Integer_16;
   procedure Dump_Register (Position : Natural; Register : Byte; Value : out Byte);
end Adaflight.STM32.Gyro_Chip;
