package body Adaflight.Gyro_Bus_Steps with SPARK_Mode is

   procedure Step_Preinit_CS (D : in out Gyro_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Preinit_CS;

   procedure Step_Attach_Bus (D : in out Gyro_Line; Instance : Byte; OK : out Boolean) is
      pragma Unreferenced (D, Instance);
   begin
      OK := True;
   end Step_Attach_Bus;

   procedure Step_Prepare_CS (D : in out Gyro_Line; Index : Byte) is
      pragma Unreferenced (D, Index);
   begin
      null;
   end Step_Prepare_CS;

   procedure Step_Release_CS (D : in out Gyro_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Release_CS;

   procedure Step_Divider (D : in out Gyro_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Hz);
   begin
      Divisor := 0;
   end Step_Divider;

   procedure Step_Set_Divisor (D : in out Gyro_Line; Divisor : Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Divisor);
   begin
      null;
   end Step_Set_Divisor;

   procedure Step_Probe_Chip (D : in out Gyro_Line; Index : Positive; Sensor : out Byte) is
      pragma Unreferenced (D, Index);
   begin
      Sensor := 0;
   end Step_Probe_Chip;

   procedure Step_Register_Device (D : in out Gyro_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Register_Device;

   procedure Step_Millis (D : in out Gyro_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 1_000;
   end Step_Millis;

   procedure Step_Delay_Ms (D : in out Gyro_Line; Ms : Natural) is
      pragma Unreferenced (D, Ms);
   begin
      null;
   end Step_Delay_Ms;

   procedure Step_Enable_Interrupt (D : in out Gyro_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Enable_Interrupt;

   procedure Step_Cycle_Count (D : in out Gyro_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 1_000;
   end Step_Cycle_Count;

   procedure Step_Start_Sequence (D : in out Gyro_Line; Data : Byte_Array; Completion : Boolean) is
      pragma Unreferenced (D, Data, Completion);
   begin
      null;
   end Step_Start_Sequence;

   procedure Step_Wait (D : in out Gyro_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Wait;

   procedure Step_Fetch (D : in out Gyro_Line; Data : out Byte_Array) is
      pragma Unreferenced (D);
   begin
      Data := (others => 0);
   end Step_Fetch;

   function Step_Uses_DMA (D : Gyro_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Step_Uses_DMA;

   procedure Step_Read_Registers (D : in out Gyro_Line; Register : Byte; Data : in out Byte_Array; OK : out Boolean) is
      pragma Unreferenced (D, Register, Data);
   begin
      OK := True;
   end Step_Read_Registers;

end Adaflight.Gyro_Bus_Steps;
