with Adaflight.STM32.Gyro_Chip;
package body Adaflight.STM32.Gyro is
   procedure Start (Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : out Report)
     renames Gyro_Chip.Start;
   procedure Read_Gyro (Raw : out Axis_Values; OK : out Boolean) renames Gyro_Chip.Read_Gyro;
   procedure Read_Acc (Raw : out Axis_Values; OK : out Boolean) renames Gyro_Chip.Read_Acc;
   function Mode return Read_Mode renames Gyro_Chip.Mode;
   function Interrupt_Count return Interfaces.Unsigned_32 renames Gyro_Chip.Interrupt_Count;
   function Sync_Cycles return Interfaces.Unsigned_32 renames Gyro_Chip.Sync_Cycles;
   function Short_Period return Boolean renames Gyro_Chip.Short_Period;
   procedure Poll_Temperature (Now_Us : Adaflight.Scheduler.Time_Us) renames Gyro_Chip.Poll_Temperature;
   function Temperature return Interfaces.Integer_16 renames Gyro_Chip.Temperature;
   procedure Dump_Register (Position : Natural; Register : Byte; Value : out Byte) renames Gyro_Chip.Dump_Register;
end Adaflight.STM32.Gyro;
