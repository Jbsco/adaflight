with Adaflight.Gyro_Detect;
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
      R.Scale := 1.0;
      R.Sample_Rate_Hz := Rate_Hz;
      R.Acc_Sample_Rate_Hz := Rate_Hz;
      R.Overflow_Protected := True;
      Acc_Detect.Detect (Acc_Build, Acc_Configured, 0, R.Acc_Hardware, R.Acc_Found);
   end Start;

   procedure Read_Gyro (Raw : out Axis_Values; OK : out Boolean) is
   begin
      Raw := (others => 0);
      OK := True;
   end Read_Gyro;

   procedure Read_Acc (Raw : out Axis_Values; OK : out Boolean) is
   begin
      Raw := (0, 0, Acc_One_G);
      OK := True;
   end Read_Acc;

   function Mode return Read_Mode is (No_Interrupt);

   function Interrupt_Count return Interfaces.Unsigned_32 is (0);

   function Sync_Cycles return Interfaces.Unsigned_32 is (0);

   function Short_Period return Boolean is (False);
end Adaflight.STM32.Gyro;
