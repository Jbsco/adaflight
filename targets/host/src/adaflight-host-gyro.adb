with Ada.Environment_Variables;
with Adaflight.Gyro_Detect;
with Adaflight.Host_Simulator;
with Adaflight.Sim_FDM;
with Adaflight.STM32.Gyro_Chip;
package body Adaflight.STM32.Gyro is
   --  The virtual gyro at 1 kHz with its rates in degrees per second, and
   --  the virtual accelerometer, the craft at rest and level. With the
   --  environment variable ADAFLIGHT_GYRO_CHIP set, the board's gyro code
   --  runs in its place over the chip model on the host's gyro bus.
   Rate_Hz : constant := 1_000;
   Chip    : constant Boolean := Ada.Environment_Variables.Exists ("ADAFLIGHT_GYRO_CHIP");
   --  The virtual accelerometer counts 256 for one g.
   Virtual_One_G : constant := 256;

   procedure Detect (Position : Natural; Hardware_LPF : Byte; High_Range : Boolean; R : out Report) is
      Build    : constant Gyro_Detect.Driver_Set := (Gyro_Detect.Virtual => True, others => False);
      Hardware : Byte := Gyro_Detect.Hardware_None;
      Found    : Boolean;
   begin
      if Chip then
         Gyro_Chip.Detect (Position, Hardware_LPF, High_Range, R);
         return;
      end if;
      R := (others => <>);
      if Position /= 0 then
         return;
      end if;
      Gyro_Detect.Detect_Sensor (Build, True, 0, Hardware, Found);
      R.Found := Found;
      R.Hardware := Hardware;
      R.Scale := (if Adaflight.Host_Simulator.Enabled then 2000.0 / 32768.0 else 1.0);
      R.Sample_Rate_Hz := Rate_Hz;
      R.Acc_Sample_Rate_Hz := Rate_Hz;
      R.Overflow_Protected := True;
      R.One_G := Virtual_One_G;
   end Detect;

   procedure Init
     (Position : Natural; Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : in out Report)
   is
      Acc_Build : constant Acc_Detect.Driver_Set := (Acc_Detect.Virtual => True, others => False);
   begin
      if Chip then
         Gyro_Chip.Init (Position, Hardware_LPF, High_Range, Acc_Configured, R);
      elsif Position = 0 and then R.Found then
         Acc_Detect.Detect (Acc_Build, Acc_Configured, 0, R.Acc_Hardware, R.Acc_Found);
      end if;
   end Init;

   procedure Set_Active (Position : Natural) is
   begin
      if Chip then
         Gyro_Chip.Set_Active (Position);
      end if;
   end Set_Active;

   procedure Read_Gyro (Position : Natural; Raw : out Axis_Values; OK : out Boolean) is
   begin
      if Chip then
         Gyro_Chip.Read_Gyro (Position, Raw, OK);
         return;
      end if;
      if Position /= 0 then
         Raw := (others => 0);
         OK := False;
         return;
      end if;
      if Adaflight.Host_Simulator.Enabled then
         declare
            G : constant Adaflight.Sim_FDM.Axes := Adaflight.Host_Simulator.Gyro;
         begin
            Raw := (G (1), G (2), G (3));
         end;
      else
         Raw := (others => 0);
      end if;
      OK := True;
   end Read_Gyro;

   procedure Read_Acc (Raw : out Axis_Values; OK : out Boolean) is
   begin
      if Chip then
         Gyro_Chip.Read_Acc (Raw, OK);
         return;
      end if;
      if Adaflight.Host_Simulator.Enabled then
         declare
            A : Adaflight.Sim_FDM.Axes;
         begin
            Adaflight.Host_Simulator.Take_Acc (OK, A);
            Raw := (A (1), A (2), A (3));
         end;
      else
         Raw := (0, 0, Virtual_One_G);
         OK := True;
      end if;
   end Read_Acc;

   function Mode return Read_Mode is (if Chip then Gyro_Chip.Mode else No_Interrupt);

   function Interrupt_Count return Interfaces.Unsigned_32 is (if Chip then Gyro_Chip.Interrupt_Count else 0);

   function Sync_Cycles return Interfaces.Unsigned_32 is (if Chip then Gyro_Chip.Sync_Cycles else 0);

   function Short_Period return Boolean is (Chip and then Gyro_Chip.Short_Period);
   --  The host's virtual gyro reports no temperature, as upstream's does.
   procedure Poll_Temperature (Now_Us : Adaflight.Scheduler.Time_Us) is
   begin
      if Chip then
         Gyro_Chip.Poll_Temperature (Now_Us);
      end if;
   end Poll_Temperature;

   function Temperature return Interfaces.Integer_16 is (if Chip then Gyro_Chip.Temperature else 0);

   --  The host's virtual gyro has no registers: a read of its one position
   --  answers the register's own address, so a dump shows what it asked for.
   procedure Dump_Register (Position : Natural; Register : Byte; Value : out Byte) is
   begin
      if Chip then
         Gyro_Chip.Dump_Register (Position, Register, Value);
      else
         Value := (if Position = 0 then Register else 0);
      end if;
   end Dump_Register;

end Adaflight.STM32.Gyro;
