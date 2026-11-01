with Adaflight.Gyro_Detect;
with Adaflight.Host_Simulator;
with Adaflight.Sim_FDM;
package body Adaflight.STM32.Gyro is
   --  The virtual gyro at 1 kHz with its rates in degrees per second, and
   --  the virtual accelerometer, the craft at rest and level.
   Rate_Hz : constant := 1_000;

   procedure Start (Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : out Report) is
      pragma Unreferenced (Hardware_LPF, High_Range);
      Build     : constant Gyro_Detect.Driver_Set := (Gyro_Detect.Virtual => True, others => False);
      Acc_Build : constant Acc_Detect.Driver_Set := (Acc_Detect.Virtual => True, others => False);
      Hardware  : Byte := Gyro_Detect.Hardware_None;
      Found     : Boolean;
   begin
      R := (others => <>);
      Gyro_Detect.Detect_Sensor (Build, True, 0, Hardware, Found);
      R.Found := Found;
      R.Hardware := Hardware;
      R.Scale := (if Adaflight.Host_Simulator.Enabled then 2000.0 / 32768.0 else 1.0);
      R.Sample_Rate_Hz := Rate_Hz;
      R.Acc_Sample_Rate_Hz := Rate_Hz;
      R.Overflow_Protected := True;
      Acc_Detect.Detect (Acc_Build, Acc_Configured, 0, R.Acc_Hardware, R.Acc_Found);
   end Start;

   --  A simulator's counts, the accelerometer's 256 a g raised to the chip families' 2048.
   function Scaled (Count : Interfaces.Integer_16) return Interfaces.Integer_16 is
     (Interfaces.Integer_16 (Integer'Max (-32_768, Integer'Min (32_767, Integer (Count) * 8))));

   procedure Read_Gyro (Raw : out Axis_Values; OK : out Boolean) is
   begin
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
      if Adaflight.Host_Simulator.Enabled then
         declare
            A : constant Adaflight.Sim_FDM.Axes := Adaflight.Host_Simulator.Acc;
         begin
            Raw := (Scaled (A (1)), Scaled (A (2)), Scaled (A (3)));
         end;
      else
         Raw := (0, 0, Acc_One_G);
      end if;
      OK := True;
   end Read_Acc;

   function Mode return Read_Mode is (No_Interrupt);

   function Interrupt_Count return Interfaces.Unsigned_32 is (0);

   function Sync_Cycles return Interfaces.Unsigned_32 is (0);

   function Short_Period return Boolean is (False);
   --  The host's virtual gyro reports no temperature, as upstream's does.
   procedure Poll_Temperature (Now_Us : Adaflight.Scheduler.Time_Us) is
      pragma Unreferenced (Now_Us);
   begin
      null;
   end Poll_Temperature;

   function Temperature return Interfaces.Integer_16 is (0);

end Adaflight.STM32.Gyro;
